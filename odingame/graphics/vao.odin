package graphics

import gl "vendor:OpenGL/gl"
import graphics_types "./types" // Import for graphics-specific types
import "../common"             // For common.Engine_Error
import "core:log"
import "core:mem"
import "core:unsafe" // For offset_of

// --- OpenGL Specific Struct ---

Gl_Vertex_Array :: struct {
	id:             u32,
	main_allocator: ^rawptr,
	// We could store copies/references to the Gfx_Buffer handles (VBOs/EBO)
	// associated with this VAO for debugging or state tracking, but the VAO ID itself is key.
}

// --- Helper to convert Vertex_Format to GL types ---
@(private="file")
get_gl_vertex_format_params :: proc(format: graphics_types.Vertex_Format) -> (size: i32, type: gl.GLenum, normalized: bool, err_msg: string) { // Use qualified type
	#partial switch format {
	// Assuming graphics_types.Vertex_Format has these exact members
	case .Float: return 1, gl.FLOAT, false, ""
	case .Float2: return 2, gl.FLOAT, false, ""
	case .Float3: return 3, gl.FLOAT, false, ""
	case .Float4: return 4, gl.FLOAT, false, ""
	case .UByte4N:  return 4, gl.UNSIGNED_BYTE, true, "" // For RGBA8 color (UByte4N maps to this)
	// Add other formats as needed from graphics_types.Vertex_Format
	// Example:
	// case .Byte4N: return 4, gl.BYTE, true, ""
	// case .Short2N: return 2, gl.SHORT, true, ""
	case: return 0, 0, false, "Unsupported vertex attribute format"
	}
	// return 0,0,false,""; // This line might be unreachable if all cases are handled or #partial exhaustive
}


// --- Implementation of Gfx_Device_Interface VAO functions ---

gl_create_vertex_array_impl :: proc(
	device: Gfx_Device, 
	vertex_buffer_layouts: []graphics_types.Vertex_Buffer_Layout, // Use qualified type
	vertex_buffers: []Gfx_Buffer, // VBOs
	index_buffer: Gfx_Buffer,      // EBO
) -> (Gfx_Vertex_Array, common.Engine_Error) { // Return common.Engine_Error
	
	device_ptr, ok_device := device.variant.(^Gl_Device)
	if !ok_device {
		log.error("gl_create_vertex_array: Invalid Gfx_Device type.")
		return Gfx_Vertex_Array{}, .Invalid_Handle // .Invalid_Handle is part of common.Engine_Error
	}

	if len(vertex_buffer_layouts) == 0 || len(vertex_buffers) == 0 {
		// While a VAO can be empty, it's usually an error in this context if no layouts/buffers are provided.
		// However, some use cases might only use an index buffer with a VAO (though rare for drawing without VBOs).
		// For typical drawing, at least one VBO and layout is expected.
		log.warn("gl_create_vertex_array: Called with no vertex buffer layouts or vertex buffers.")
		// Proceeding to create an empty VAO if that's intended, but it might not be useful.
	}
	if len(vertex_buffer_layouts) != len(vertex_buffers) && len(vertex_buffers) > 0 {
		// This check is simplified. A more robust system might map layouts to buffer binding points.
		// For now, assume a 1:1 correspondence if multiple buffers are given.
		// Or, better, layouts should specify which buffer binding they use, and vertex_buffers should be indexed by that.
		// The current Vertex_Attribute.buffer_binding is for this.
		log.errorf("gl_create_vertex_array: Mismatch between number of layouts (%d) and VBOs (%d) when VBOs are provided.",
			len(vertex_buffer_layouts), len(vertex_buffers))
		// This condition might be too strict if buffer_binding is used effectively to map attributes to VBOs.
		// For now, we'll iterate layouts and expect `vertex_buffers[layout.binding]` to be valid.
	}

	vao_id: u32
	gl.GenVertexArrays(1, &vao_id)
	if vao_id == 0 {
		log.error("glGenVertexArrays failed.")
		return Gfx_Vertex_Array{}, .Buffer_Creation_Failed 
	}

	gl.BindVertexArray(vao_id)

	for layout_idx := 0; layout_idx < len(vertex_buffer_layouts); layout_idx += 1 {
		layout := vertex_buffer_layouts[layout_idx]
		
		// The layout.binding refers to the conceptual "binding point".
		// We need to find the Gfx_Buffer that corresponds to this binding point.
		// For now, let's assume vertex_buffers is a flat list and layout.binding is an index into it.
		// This is a simplification. A real system might use a map or require buffers to be pre-bound to indexed binding points.
		if layout.binding >= u32(len(vertex_buffers)) {
			log.errorf("gl_create_vertex_array: Layout binding %d is out of range for supplied vertex_buffers (count %d).",
				layout.binding, len(vertex_buffers))
			gl.BindVertexArray(0)
			gl.DeleteVertexArrays(1, &vao_id)
			return Gfx_Vertex_Array{}, .Invalid_Handle // .Invalid_Handle from common.Engine_Error
		}

		vbo_gfx := vertex_buffers[layout.binding]
		vbo_gl, ok_vbo := vbo_gfx.variant.(^Gl_Buffer)
		if !ok_vbo || vbo_gl == nil || vbo_gl.id == 0 || vbo_gl.type != graphics_types.Buffer_Type.Vertex { // Use qualified type
			log.errorf("gl_create_vertex_array: Invalid Gfx_Buffer at index %d (binding %d) or not a Vertex buffer.",
				layout.binding, layout.binding)
			gl.BindVertexArray(0) // Unbind VAO before deleting
			gl.DeleteVertexArrays(1, &vao_id)
			return Gfx_Vertex_Array{}, .Invalid_Handle // .Invalid_Handle from common.Engine_Error
		}

		gl.BindBuffer(gl.ARRAY_BUFFER, vbo_gl.id)

		for attr_idx := 0; attr_idx < len(layout.attributes); attr_idx += 1 {
			attr := layout.attributes[attr_idx]
			
			// Ensure this attribute's declared buffer_binding matches the current layout's buffer_binding.
			// This is a sanity check if attributes can source from different VBOs within a more complex VAO.
			// For the current structure, attr.buffer_binding should equal layout.binding.
			if attr.buffer_binding != layout.binding {
				log.errorf("gl_create_vertex_array: Attribute location %d has buffer_binding %d which does not match its layout's VBO binding %d.",
					attr.location, attr.buffer_binding, layout.binding)
				// Cleanup and error out
				gl.BindBuffer(gl.ARRAY_BUFFER, 0)
				gl.BindVertexArray(0)
				gl.DeleteVertexArrays(1, &vao_id)
				return Gfx_Vertex_Array{}, .Invalid_Handle // .Invalid_Handle from common.Engine_Error
			}

			gl_size, gl_type, gl_normalized, fmt_err_msg := get_gl_vertex_format_params(attr.format)
			if fmt_err_msg != "" {
				log.errorf("gl_create_vertex_array: Attribute location %d: %s (format %v).", attr.location, fmt_err_msg, attr.format)
				// Cleanup (unbind VBO, unbind VAO, delete VAO) and error out
				gl.BindBuffer(gl.ARRAY_BUFFER, 0)
				gl.BindVertexArray(0)
				gl.DeleteVertexArrays(1, &vao_id)
				return Gfx_Vertex_Array{}, .Buffer_Creation_Failed // Or a format error from common.Engine_Error
			}

			gl.EnableVertexAttribArray(attr.location)
			// Note: Using unsafe.Pointer(uintptr(attr.offset_in_bytes)) for the offset.
			// This is standard for telling OpenGL the byte offset from the start of the vertex.
			if gl_type == gl.UNSIGNED_BYTE && !gl_normalized { // Or other integer types not meant to be normalized floats
				// Example for integer attributes if needed in future:
				// gl.VertexAttribIPointer(attr.location, gl_size, gl_type, layout.stride_in_bytes, unsafe.Pointer(uintptr(attr.offset_in_bytes)))
				log.warnf("gl_create_vertex_array: Integer vertex attribute (loc %d) without normalization not yet fully handled by VertexAttribIPointer, using VertexAttribPointer.", attr.location)
				gl.VertexAttribPointer(attr.location, gl_size, gl_type, gl_normalized, i32(layout.stride_in_bytes), unsafe.Pointer(uintptr(attr.offset_in_bytes)))

			} else {
				gl.VertexAttribPointer(attr.location, gl_size, gl_type, gl_normalized, i32(layout.stride_in_bytes), unsafe.Pointer(uintptr(attr.offset_in_bytes)))
			}
			// TODO: Add glVertexAttribDivisor for instancing if layout.step_rate == .Instance
		}
		// VBO is configured for this layout, but leave it bound if other layouts use the same VAO but different VBOs.
		// However, standard practice is one VBO per set of attributes in a simple VAO setup, or distinct binding points.
		// For now, the loop implies each layout might use a different VBO. The VBO is bound at the start of the layout loop.
	}


	// Bind Index Buffer (EBO) if provided
	if _, ok_ibo_check := index_buffer.variant.(^Gl_Buffer); ok_ibo_check { // Check if it's a valid Gfx_Buffer variant
		ebo_gl, ok_ebo := index_buffer.variant.(^Gl_Buffer)
		if ok_ebo && ebo_gl != nil && ebo_gl.id != 0 { // Check if it's a valid GL buffer
			if ebo_gl.type != graphics_types.Buffer_Type.Index { // Use qualified type
				log.errorf("gl_create_vertex_array: Provided index_buffer is not of type .Index (is %v).", ebo_gl.type)
				gl.BindVertexArray(0) // Unbind VAO before deleting
				gl.DeleteVertexArrays(1, &vao_id)
				return Gfx_Vertex_Array{}, .Invalid_Handle // .Invalid_Handle from common.Engine_Error
			}
			gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo_gl.id)
			log.infof("Bound EBO ID %v to VAO ID %v", ebo_gl.id, vao_id)
		} else if ok_ebo && (ebo_gl == nil || ebo_gl.id == 0) {
			// It's a Gfx_Buffer of type Gl_Buffer, but it's empty/invalid. This is fine if no index buffer is intended.
		} else if !ok_ebo && index_buffer.variant != nil {
            log.errorf("gl_create_vertex_array: Provided index_buffer is of an unknown Gfx_Buffer variant type.")
            // Similar cleanup
            gl.BindVertexArray(0); gl.DeleteVertexArrays(1, &vao_id); return Gfx_Vertex_Array{}, .Invalid_Handle // .Invalid_Handle from common.Engine_Error
        }
        // If index_buffer.variant is nil (Gfx_Buffer{}), it means no index buffer, which is okay.
	}


	gl.BindVertexArray(0) // Unbind VAO to prevent accidental modification
	gl.BindBuffer(gl.ARRAY_BUFFER, 0) // Unbind last VBO
	if _, ok_ibo_val := index_buffer.variant.(^Gl_Buffer); ok_ibo_val { // Only unbind EBO if it was potentially bound
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0) // Unbind EBO
	}


	gl_vao_ptr := new(Gl_Vertex_Array, device_ptr.main_allocator^)
	gl_vao_ptr.id = vao_id
	gl_vao_ptr.main_allocator = device_ptr.main_allocator

	log.infof("OpenGL VAO ID %v created.", vao_id)
	return Gfx_Vertex_Array{gl_vao_ptr}, .None
}

gl_destroy_vertex_array_impl :: proc(vao: Gfx_Vertex_Array) {
	if vao_ptr, ok := vao.variant.(^Gl_Vertex_Array); ok && vao_ptr != nil {
		if vao_ptr.id != 0 {
			gl.DeleteVertexArrays(1, &vao_ptr.id)
			log.infof("OpenGL VAO ID %v destroyed.", vao_ptr.id)
		}
		free(vao_ptr, vao_ptr.main_allocator^)
	} else if vao.variant != nil { // It's some other variant type, or nil Gl_Vertex_Array pointer
		log.errorf("gl_destroy_vertex_array: Invalid VAO type %v or nil pointer.", vao.variant)
	}
	// If vao.variant is nil, it's an empty Gfx_Vertex_Array, nothing to do.
}

gl_bind_vertex_array_impl :: proc(device: Gfx_Device, vao: Gfx_Vertex_Array) {
	// device_ptr, ok_device := device.variant.(^Gl_Device)
	// if !ok_device { log.error("gl_bind_vertex_array: Invalid Gfx_Device."); return }

	if vao_ptr, ok := vao.variant.(^Gl_Vertex_Array); ok && vao_ptr != nil && vao_ptr.id != 0 {
		gl.BindVertexArray(vao_ptr.id)
		// log.debugf("Bound VAO ID %v", vao_ptr.id) // Can be spammy
	} else {
		// Binding VAO ID 0 unbinds the current VAO.
		// This is the correct behavior for passing an empty/invalid Gfx_Vertex_Array.
		gl.BindVertexArray(0)
		// log.debug("Unbound VAO (bound ID 0)")
	}
}
