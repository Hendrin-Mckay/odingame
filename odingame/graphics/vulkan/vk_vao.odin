package vulkan

import vk "vendor:vulkan"
import "core:log"
import "core:mem"
import "../gfx_interface" // For Gfx_Device, Gfx_Vertex_Array, Vertex_Format, Vertex_Buffer_Layout, Gfx_Buffer
import "../../common" // For common.Engine_Error

// --- Aliases for Vulkan Structs (for clarity or potential future extension) ---
Vk_Vertex_Input_Binding_Description :: vk.VertexInputBindingDescription
Vk_Vertex_Input_Attribute_Description :: vk.VertexInputAttributeDescription

// Vk_Vertex_Array_Internal stores the processed vertex input state descriptions
// and references to the associated graphics buffers.
Vk_Vertex_Array_Internal :: struct {
	// Processed Vulkan descriptions derived from gfx_interface.Vertex_Buffer_Layout
	binding_descriptions:    []Vk_Vertex_Input_Binding_Description,
	attribute_descriptions:  []Vk_Vertex_Input_Attribute_Description,

	// References to the Gfx_Buffer handles provided at creation.
	// The actual VkBuffer handles will be extracted from these when binding.
	vertex_buffers_gfx:      []gfx_interface.Gfx_Buffer, 
	vertex_buffer_offsets:   []vk.DeviceSize, // Offsets for vkCmdBindVertexBuffers

	index_buffer_gfx:        gfx_interface.Gfx_Buffer,
	index_buffer_offset:     vk.DeviceSize,   // Offset for vkCmdBindIndexBuffer
	index_type:              vk.IndexType,    // e.g., .UINT16 or .UINT32

	allocator_ref:           mem.Allocator, // Allocator used for this struct and its slices
}

// map_vertex_format_to_vk converts gfx_interface.Vertex_Format to vk.Format.
map_vertex_format_to_vk :: proc(format: gfx_interface.Vertex_Format) -> (vk_format: vk.Format, found: bool) {
	#partial switch format {
	case .Float32_X1: return .R32_SFLOAT, true
	case .Float32_X2: return .R32G32_SFLOAT, true
	case .Float32_X3: return .R32G32B32_SFLOAT, true
	case .Float32_X4: return .R32G32B32A32_SFLOAT, true
	case .Unorm8_X4:  return .R8G8B8A8_UNORM, true
	// Add other formats as needed:
	// case .Sint16_X2: return .R16G16_SINT, true
	}
	log.errorf("Unsupported gfx_interface.Vertex_Format: %v", format)
	return .UNDEFINED, false
}

// vk_create_vertex_array_internal translates gfx_interface layouts to Vulkan descriptions
// and stores them along with buffer references.
vk_create_vertex_array_internal :: proc(
	gfx_device: gfx_interface.Gfx_Device, // Needed to get allocator
	vertex_buffer_layouts: []gfx_interface.Vertex_Buffer_Layout,
	vertex_buffers: []gfx_interface.Gfx_Buffer, // Must match layouts in terms of binding points
	index_buffer_param: gfx_interface.Gfx_Buffer, // Using _param to avoid conflict if Gfx_Buffer is named 'index_buffer'
) -> (gfx_interface.Gfx_Vertex_Array, common.Engine_Error) {

	vk_dev_internal, ok_dev := gfx_device.variant.(Vk_Device_Variant)
	if !ok_dev || vk_dev_internal == nil {
		log.error("vk_create_vertex_array: Invalid Gfx_Device (not Vulkan or nil variant).")
		return gfx_interface.Gfx_Vertex_Array{}, common.Engine_Error.Invalid_Handle
	}
	allocator := vk_dev_internal.allocator

	// Allocate the main struct
	vk_vao_internal := new(Vk_Vertex_Array_Internal, allocator)
	vk_vao_internal.allocator_ref = allocator
	
	// --- Process Vertex Buffer Layouts ---
	// Use dynamic arrays for building up descriptions, then clone to vk_vao_internal.
	// These use context.temp_allocator or a temporary arena.
	temp_bindings    := make([dynamic]Vk_Vertex_Input_Binding_Description, 0, len(vertex_buffer_layouts), context.temp_allocator)
	defer delete(temp_bindings)
	temp_attributes  := make([dynamic]Vk_Vertex_Input_Attribute_Description, 0, 8, context.temp_allocator) // Pre-allocate for a few attributes
	defer delete(temp_attributes)

	// Store Gfx_Buffer handles and their offsets for vkCmdBindVertexBuffers
	// We need to ensure vertex_buffers maps correctly to vertex_buffer_layouts based on binding index.
	// The Gfx_Interface suggests vertex_buffers is an array, and layouts refer to these by index or binding point.
	// For simplicity, assume the i-th Gfx_Buffer in vertex_buffers corresponds to a layout that uses binding 'i'.
	// A more robust system would use a map or require layouts to specify which Gfx_Buffer index they use.
	// For now, assume layout.binding is the index into the vertex_buffers array if that's how it's intended.
	// Or, more commonly, layout.binding is the actual Vulkan binding number.
	
	// Let's assume layout.binding refers to the Vulkan binding point.
	// The vertex_buffers slice corresponds to these binding points if sorted or if user ensures consistency.
	// For this implementation, we'll iterate layouts and assume the Gfx_Buffer is found via its binding.
	
	// Store Gfx_Buffer handles and offsets
	// We need to determine the offsets for vkCmdBindVertexBuffers. The gfx_interface.Vertex_Buffer_Layout
	// itself does not provide buffer-level offsets, only attribute offsets *within* a vertex.
	// The `set_vertex_buffer` call in `Gfx_Device_Interface` takes an offset.
	// This implies that the VAO might not need to store these offsets if they are provided at bind time.
	// However, Vulkan's vkCmdBindVertexBuffers takes an array of offsets.
	// Let's assume the Gfx_Vertex_Array will store these intended offsets.
	// The `gfx_interface.create_vertex_array` does not take offsets per buffer.
	// This is a small design gap. For now, assume offsets are 0 for all vertex buffers bound via VAO.
	// The individual set_vertex_buffer will handle specific offsets if called outside VAO context (which is not typical for Vulkan).

	// Store Gfx_Buffer handles (vertex_buffers)
	if len(vertex_buffers) > 0 {
		vk_vao_internal.vertex_buffers_gfx = make([]gfx_interface.Gfx_Buffer, len(vertex_buffers), allocator)
		vk_vao_internal.vertex_buffer_offsets = make([]vk.DeviceSize, len(vertex_buffers), allocator) // Initialize all to 0
		for i, vb_gfx in vertex_buffers {
			vk_vao_internal.vertex_buffers_gfx[i] = vb_gfx
			// vk_vao_internal.vertex_buffer_offsets[i] = 0; // Default offset 0, already done by make
		}
	}


	for _, layout_desc in vertex_buffer_layouts {
		binding_desc := Vk_Vertex_Input_Binding_Description{
			binding = layout_desc.binding,
			stride = layout_desc.stride_in_bytes,
			// TODO: inputRate based on layout_desc.step_rate if added to gfx_interface
			inputRate = .VERTEX, // Default to per-vertex
		}
		append(&temp_bindings, binding_desc)

		for _, attr_desc_gfx in layout_desc.attributes {
			vk_fmt, ok_fmt := map_vertex_format_to_vk(attr_desc_gfx.format)
			if !ok_fmt {
				log.errorf("Failed to map vertex format %v to Vulkan format for VAO creation.", attr_desc_gfx.format)
				// Cleanup allocated vk_vao_internal
				free(vk_vao_internal.vertex_buffers_gfx)
				free(vk_vao_internal.vertex_buffer_offsets)
				free(vk_vao_internal)
				return gfx_interface.Gfx_Vertex_Array{}, common.Engine_Error.Invalid_Handle // Or .Shader_Compilation_Failed if format is for shaders
			}
			
			attribute := Vk_Vertex_Input_Attribute_Description{
				location = attr_desc_gfx.location,
				binding = attr_desc_gfx.buffer_binding, // Which binding description this attribute uses
				format = vk_fmt,
				offset = attr_desc_gfx.offset_in_bytes,
			}
			append(&temp_attributes, attribute)
		}
	}

	// Clone from temporary dynamic arrays to the struct's slices
	if len(temp_bindings) > 0 {
		vk_vao_internal.binding_descriptions = 추천slice.clone(temp_bindings[:], allocator)
	}
	if len(temp_attributes) > 0 {
		vk_vao_internal.attribute_descriptions = slice.clone(temp_attributes[:], allocator)
	}

	// --- Store Index Buffer Reference ---
	vk_vao_internal.index_buffer_gfx = index_buffer_param
	// The Gfx_Interface for create_vertex_array doesn't take an offset for the index buffer.
	// Assume offset 0 for now. The `set_index_buffer` interface call *does* take an offset.
	vk_vao_internal.index_buffer_offset = 0 
	// Index type: Assume UINT32 for now. A more robust solution would inspect buffer properties
	// or have it specified in Gfx_Buffer or Gfx_Vertex_Array creation.
	vk_vao_internal.index_type = .UINT32 
	// Example: if index_buffer_param has a property for element size:
	// if get_buffer_element_size(index_buffer_param) == 2 { vk_vao_internal.index_type = .UINT16 }

	log.infof("Vk_Vertex_Array_Internal %p created. Bindings: %d, Attributes: %d. VB count: %d, IB provided: %v",
		vk_vao_internal,
		len(vk_vao_internal.binding_descriptions),
		len(vk_vao_internal.attribute_descriptions),
		len(vk_vao_internal.vertex_buffers_gfx),
		vk_vao_internal.index_buffer_gfx.variant != nil,
	)
	
	return gfx_interface.Gfx_Vertex_Array{variant = vk_vao_internal}, .None
}

// vk_destroy_vertex_array_internal frees memory associated with Vk_Vertex_Array_Internal.
vk_destroy_vertex_array_internal :: proc(vao_handle: gfx_interface.Gfx_Vertex_Array) {
	vk_vao_ptr, ok_vao := vao_handle.variant.(^Vk_Vertex_Array_Internal)
	if !ok_vao || vk_vao_ptr == nil {
		log.errorf("vk_destroy_vertex_array: Invalid Gfx_Vertex_Array type or nil variant (%v).", vao_handle.variant)
		return
	}

	log.infof("Destroying Vk_Vertex_Array_Internal %p.", vk_vao_ptr)
	
	// Free the slices within the struct
	delete(vk_vao_ptr.binding_descriptions)
	delete(vk_vao_ptr.attribute_descriptions)
	delete(vk_vao_ptr.vertex_buffers_gfx) // This deletes the slice of Gfx_Buffer handles, not the buffers themselves
	delete(vk_vao_ptr.vertex_buffer_offsets)
	// index_buffer_gfx is not a slice

	// Free the struct itself
	free(vk_vao_ptr, vk_vao_ptr.allocator_ref)
}
