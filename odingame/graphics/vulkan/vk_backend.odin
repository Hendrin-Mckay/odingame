package vulkan

import "../gfx_interface"
import gfx_types "../../graphics/types" // For Gfx_Pipeline_Desc, Vertex_Format
import "../../common" 
import "core:log"
import vk "vendor:vulkan" 
import sdl "vendor:sdl2" 
import "./vk_types"      
import "./vk_descriptors"
import "./vk_command"    
import "./vk_helpers"   // For vk_create_instance_internal etc.
import "./vk_pipeline"  // For vk_create_render_pass_internal, vk_create_pipeline_layout_internal, vk_create_pipeline_internal, vk_destroy_pipeline_internal
import "./vk_buffer"    // For vk_create_buffer_internal, vk_destroy_buffer_internal, vk_map_buffer_internal, vk_unmap_buffer_internal, vk_update_buffer_internal
import "./vk_shader"    // For shader creation/destruction internal functions
import "./vk_texture"   // For texture creation/destruction internal functions
import "./vk_vao"       // For VAO creation/destruction internal functions
import "./vk_window"    // For window creation/destruction internal functions
// Ensure vk_device is imported if its functions are directly used by vk_backend.odin for gfx_api assignments
import "./vk_device"    


// --- Shader Management Wrappers ---
vk_create_shader_from_bytecode_wrapper :: proc( device: gfx_interface.Gfx_Device, bytecode: []u8, stage: gfx_interface.Shader_Stage,) -> (gfx_interface.Gfx_Shader, common.Engine_Error) {
	return vk_shader.vk_create_shader_from_bytecode_internal(device, bytecode, stage)
}
vk_destroy_shader_wrapper :: proc(shader: gfx_interface.Gfx_Shader) -> common.Engine_Error {
	err := vk_shader.vk_destroy_shader_internal(shader)
	if err != .None {
		// The internal function already logs specifics. We could add context here if needed.
		// log.errorf("vk_destroy_shader_wrapper: Failed to destroy shader: %v", err)
		return err
	}
	return .None
}
vk_create_shader_from_source_wrapper :: proc( device: gfx_interface.Gfx_Device, source: string, stage: gfx_interface.Shader_Stage,) -> (gfx_interface.Gfx_Shader, common.Engine_Error) {
	return vk_shader.vk_create_shader_from_source_internal(device, source, stage)
}

// --- Helper to translate gfx_types.Vertex_Format to vk.Format ---
to_vk_vertex_format :: proc(format: gfx_types.Vertex_Format) -> (vk_format: vk.Format, ok: bool) {
    ok = true
    switch format {
    case .Float:  vk_format = .R32_SFLOAT;
    case .Float2: vk_format = .R32G32_SFLOAT;
    case .Float3: vk_format = .R32G32B32_SFLOAT;
    case .Float4: vk_format = .R32G32B32A32_SFLOAT;
    // Common normalized formats
    case .UByte4N: vk_format = .R8G8B8A8_UNORM; // Often used for colors
    case .Byte4N:  vk_format = .R8G8B8A8_SNORM;
    // Common integer formats (less common for vertex colors, more for custom data)
    case .Int:    vk_format = .R32_SINT;
    case .Int2:   vk_format = .R32G32_SINT;
    case .Int3:   vk_format = .R32G32B32_SINT;
    case .Int4:   vk_format = .R32G32B32A32_SINT;
    case .UInt:   vk_format = .R32_UINT;
    case .UInt2:  vk_format = .R32G32_UINT;
    case .UInt3:  vk_format = .R32G32B32_UINT;
    case .UInt4:  vk_format = .R32G32B32A32_UINT;
    // Short formats
    case .Short2:   vk_format = .R16G16_SINT;
    case .Short2N:  vk_format = .R16G16_SNORM;
    case .Short4:   vk_format = .R16G16B16A16_SINT;
    case .Short4N:  vk_format = .R16G16B16A16_SNORM;
    else:
        log.errorf("Vulkan: to_vk_vertex_format: Unsupported gfx_types.Vertex_Format: %v", format)
        ok = false
        vk_format = .UNDEFINED
    }
    return
}

// --- Pipeline Management Wrappers ---
vk_create_pipeline_wrapper :: proc( device: gfx_interface.Gfx_Device, desc: ^gfx_types.Gfx_Pipeline_Desc,) -> (gfx_interface.Gfx_Pipeline, common.Engine_Error) {
	vk_dev_internal, ok_dev := device.variant.(vk_types.Vk_Device_Variant)
	if !ok_dev || vk_dev_internal == nil { return gfx_interface.Gfx_Pipeline{}, common.Engine_Error.Invalid_Handle }
	if vk_dev_internal.primary_window_for_pipeline == nil { 
        log.error("Vulkan: vk_create_pipeline_wrapper: primary_window_for_pipeline is not set on Vulkan device internal.")
        return gfx_interface.Gfx_Pipeline{}, common.Engine_Error.Invalid_Operation 
    }
    if desc == nil {
        log.error("Vulkan: vk_create_pipeline_wrapper: Gfx_Pipeline_Desc is nil.")
        return gfx_interface.Gfx_Pipeline{}, common.Engine_Error.Invalid_Parameter
    }

	primary_window := vk_dev_internal.primary_window_for_pipeline
	render_pass_handle := primary_window.render_pass 
	if render_pass_handle == vk.NULL_HANDLE {
        log.error("Vulkan: vk_create_pipeline_wrapper: Primary window has no valid render pass.")
        return gfx_interface.Gfx_Pipeline{}, common.Engine_Error.Invalid_Operation
    }

    // Create Shader Slice from Gfx_Pipeline_Desc
    if desc.vertex_shader.variant == nil || desc.pixel_shader.variant == nil {
        log.error("Vulkan: vk_create_pipeline_wrapper requires valid vertex and pixel shaders in Gfx_Pipeline_Desc.")
        return gfx_interface.Gfx_Pipeline{}, .Invalid_Parameter
    }
    // Note: vk_create_pipeline_internal expects a slice of Gfx_Shader.
    // The Gfx_Pipeline_Desc holds individual shader fields.
    // This might need adjustment if vk_create_pipeline_internal expects more than just VS/PS.
    // For now, assuming it can take a slice of 2 (VS, PS).
    shaders_slice := []gfx_interface.Gfx_Shader{desc.vertex_shader, desc.pixel_shader};

    // Translate Vertex Layouts from Gfx_Pipeline_Desc
    // Using context.temp_allocator for these dynamic arrays for simplicity within this scope.
    // Ensure these are not used beyond the call to vk_create_pipeline_internal if it doesn't copy them.
    vertex_bindings_slice := make([dynamic]vk_types.Vk_Vertex_Input_Binding_Description, 0, len(desc.vertex_buffer_layouts), context.temp_allocator);
    defer if vertex_bindings_slice != nil { delete(vertex_bindings_slice); } // Check for nil if make fails
    
    // Estimate initial capacity for attributes. If one buffer layout has 4 attributes, then capacity = 4.
    // If multiple layouts, sum their attribute counts. For now, a small default.
    initial_attr_capacity := 0
    if len(desc.vertex_buffer_layouts) > 0 {
        for layout_desc in desc.vertex_buffer_layouts {
            initial_attr_capacity += len(layout_desc.layout.attributes)
        }
    }
    if initial_attr_capacity == 0 { initial_attr_capacity = 4 } // Default if no attributes

    vertex_attributes_slice := make([dynamic]vk_types.Vk_Vertex_Input_Attribute_Description, 0, initial_attr_capacity, context.temp_allocator);
    defer if vertex_attributes_slice != nil { delete(vertex_attributes_slice); }

    for layout_desc in desc.vertex_buffer_layouts {
        binding_description := vk_types.Vk_Vertex_Input_Binding_Description{
            binding = layout_desc.buffer_index, 
            stride  = layout_desc.layout.stride,
            inputRate = .VERTEX, // Default
        };
        // Map from gfx_types.Vertex_Step_Rate to vk_types.Vk_Vertex_Input_Rate
        switch layout_desc.layout.step_rate {
            case .Per_Vertex:   binding_description.inputRate = .VERTEX;
            case .Per_Instance: binding_description.inputRate = .INSTANCE;
        }
        append(&vertex_bindings_slice, binding_description);

        for attr in layout_desc.layout.attributes {
            vk_fmt, ok_format := to_vk_vertex_format(attr.format);
            if !ok_format {
                log.errorf("Vulkan: Unsupported vertex attribute format %v for location %d", attr.format, attr.location);
                return gfx_interface.Gfx_Pipeline{}, .Invalid_Parameter;
            }
            attribute_description := vk_types.Vk_Vertex_Input_Attribute_Description{
                location = attr.location,
                binding  = layout_desc.buffer_index, // Attributes for this binding
                format   = vk_fmt,
                offset   = attr.offset,
            };
            append(&vertex_attributes_slice, attribute_description);
        }
    }
	
    // Call vk_create_pipeline_internal with the new slices.
    // The old logic deriving vertex_bindings/attributes from active_vao is removed.
	gfx_pipeline, pipe_err := vk_pipeline.vk_create_pipeline_internal(
		device, 
        shaders_slice[:], // Pass the slice of shaders
        render_pass_handle, 
		vertex_bindings_slice[:], 
        vertex_attributes_slice[:],
	)
	if pipe_err != .None {
		return gfx_interface.Gfx_Pipeline{}, pipe_err
	}
	return gfx_pipeline, .None
}
vk_destroy_pipeline_wrapper :: proc(pipeline: gfx_interface.Gfx_Pipeline) -> common.Engine_Error {
	err := vk_pipeline.vk_destroy_pipeline_internal(pipeline)
	if err != .None {
		// Internal function already logs specifics.
		return err
	}
	return .None
}

vk_set_pipeline_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline_handle_gfx: gfx_interface.Gfx_Pipeline) -> common.Engine_Error {
	if device.variant == nil {
		log.error("vk_set_pipeline_wrapper: Gfx_Device variant is nil.")
		return common.Engine_Error.Invalid_Handle
	}
	vk_dev_internal, ok_dev := device.variant.(vk_types.Vk_Device_Variant)
	if !ok_dev || vk_dev_internal == nil { 
		log.errorf("vk_set_pipeline_wrapper: Invalid Gfx_Device variant type (%T) or nil pointer.", device.variant)
		return common.Engine_Error.Invalid_Handle
	}
	
	primary_window_ptr := vk_dev_internal.primary_window_for_pipeline
	if primary_window_ptr == nil { 
		log.error("vk_set_pipeline_wrapper: No primary window set on device.")
		return common.Engine_Error.Invalid_Operation
	}
	
	// vk_set_pipeline_internal now takes Gfx_Window, not Vk_Window_Internal directly
	primary_gfx_window := gfx_interface.Gfx_Window{variant = primary_window_ptr}
	err := vk_command.vk_set_pipeline_internal(primary_gfx_window, pipeline_handle_gfx)
	if err != .None {
		// log.errorf("vk_set_pipeline_wrapper: Error from vk_set_pipeline_internal: %v", err) // Internal logs
		return err
	}
    return .None
}


// --- Buffer Management Wrappers --- 
vk_create_buffer_wrapper :: proc( device: gfx_interface.Gfx_Device, type: gfx_interface.Buffer_Type, size: int, data: rawptr = nil, dynamic: bool = false,) -> (gfx_interface.Gfx_Buffer, common.Engine_Error) { 
    return vk_buffer.vk_create_buffer_internal(device, type, size, data, dynamic)
}
vk_destroy_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer) -> common.Engine_Error { 
    err := vk_buffer.vk_destroy_buffer_internal(buffer)
    if err != .None {
        // log.errorf("vk_destroy_buffer_wrapper: Failed to destroy buffer: %v", err) // Internal logs
        return err
    }
    return .None
}
vk_map_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer, offset, size: int) -> (rawptr, common.Engine_Error) { 
    mapped_ptr, err := vk_buffer.vk_map_buffer_internal(buffer, offset, size)
    if err != .None {
        // log.errorf("vk_map_buffer_wrapper: Failed to map buffer: %v", err) // Internal logs
        return nil, err
    }
    return mapped_ptr, .None
}
vk_unmap_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer) -> common.Engine_Error { 
    err := vk_buffer.vk_unmap_buffer_internal(buffer)
    if err != .None {
        // log.errorf("vk_unmap_buffer_wrapper: Failed to unmap buffer: %v", err) // Internal logs
        return err
    }
    return .None
}
vk_update_buffer_wrapper :: proc(buffer_handle_gfx: gfx_interface.Gfx_Buffer, offset: int, data: rawptr, size: int) -> common.Engine_Error { 
    return vk_buffer.vk_update_buffer_internal(buffer_handle_gfx, offset, data, size)
}

// --- Texture Management Wrappers --- 
vk_create_texture_wrapper :: proc( device: gfx_interface.Gfx_Device, width: int, height: int, format: gfx_interface.Texture_Format, usage: gfx_interface.Texture_Usage, data: rawptr = nil,) -> (gfx_interface.Gfx_Texture, common.Engine_Error) { 
    return vk_texture.vk_create_texture_internal(device, width, height, format, usage, data)
}
vk_destroy_texture_wrapper :: proc(texture: gfx_interface.Gfx_Texture) -> common.Engine_Error { 
    if texture.variant == nil {
        log.error("vk_destroy_texture_wrapper: Gfx_Texture variant is nil.")
        return common.Engine_Error.Invalid_Handle
    }
    vk_texture_internal_ptr, ok := texture.variant.(^vk_types.Vk_Texture_Internal)
    if !ok || vk_texture_internal_ptr == nil {
        log.errorf("vk_destroy_texture_wrapper: Invalid Gfx_Texture variant type (%T) or nil pointer.", texture.variant)
        return common.Engine_Error.Invalid_Handle
    }
    if vk_texture_internal_ptr.device_ref == nil {
         log.errorf("vk_destroy_texture_wrapper: Texture (image %p) has no internal device_ref. Cannot determine device for destruction.", vk_texture_internal_ptr.image)
        return common.Engine_Error.Invalid_Handle // Cannot proceed without a device context
    }
    // Construct the Gfx_Device handle from the texture's internal device reference.
    device_for_destroy := gfx_interface.Gfx_Device{variant = vk_texture_internal_ptr.device_ref}
    
    err := vk_texture.vk_destroy_texture_internal(device_for_destroy, texture)
    if err != .None {
        // log.errorf("vk_destroy_texture_wrapper: Failed to destroy texture: %v", err) // Internal function logs specifics
        return err
    }
    return .None
}
vk_update_texture_wrapper :: proc( texture: gfx_interface.Gfx_Texture, x: int, y: int, width: int, height: int, data: rawptr,) -> common.Engine_Error { 
    // This wrapper already correctly extracts device_ref for the internal call and propagates errors.
    // Adding a nil check for texture.variant for robustness.
    if texture.variant == nil {
        log.error("vk_update_texture_wrapper: Gfx_Texture variant is nil.")
        return common.Engine_Error.Invalid_Handle
    }
    vk_texture_internal_ptr, ok := texture.variant.(^vk_types.Vk_Texture_Internal)
    if !ok || vk_texture_internal_ptr == nil { 
        log.errorf("vk_update_texture_wrapper: Invalid Gfx_Texture variant type (%T) or nil pointer.", texture.variant)
        return common.Engine_Error.Invalid_Handle 
    }
    if vk_texture_internal_ptr.device_ref == nil { 
        log.errorf("vk_update_texture_wrapper: Texture (image %p) has no internal device_ref.", vk_texture_internal_ptr.image)
        return common.Engine_Error.Invalid_Handle 
    }
    device_for_update := gfx_interface.Gfx_Device{variant = vk_texture_internal_ptr.device_ref}
    return vk_texture.vk_update_texture_internal(device_for_update, texture, x, y, width, height, data)
}
vk_get_texture_width_wrapper :: proc(texture: gfx_interface.Gfx_Texture) -> int { 
    return vk_texture.vk_get_texture_width_internal(texture)
}
vk_get_texture_height_wrapper :: proc(texture: gfx_interface.Gfx_Texture) -> int { 
    return vk_texture.vk_get_texture_height_internal(texture)
}

// --- Frame Management and Drawing Command Wrappers ---
vk_begin_frame_wrapper :: proc(device: gfx_interface.Gfx_Device) -> common.Engine_Error {
	if device.variant == nil {
		log.error("vk_begin_frame_wrapper: Gfx_Device variant is nil.")
		return common.Engine_Error.Invalid_Handle
	}
	vk_dev, ok_dev := device.variant.(vk_types.Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { 
		log.errorf("vk_begin_frame_wrapper: Invalid Gfx_Device variant type (%T) or nil pointer.", device.variant)
		return common.Engine_Error.Invalid_Handle
	}
	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil { 
		log.error("vk_begin_frame_wrapper: No primary window set on device.")
		return common.Engine_Error.Invalid_Operation // Or Invalid_Handle if primary window is essential for device state
	}
	primary_gfx_window := gfx_interface.Gfx_Window{variant = primary_window_ptr}
	
	err, _, _ := vk_command.vk_begin_frame_internal(primary_gfx_window) // cmd_buf and img_idx not needed by wrapper
	if err != .None {
		// Specific error logging is done in vk_begin_frame_internal
		// log.errorf("vk_begin_frame_wrapper: Error from vk_begin_frame_internal: %v", err)
		return err
	}
	return .None
}
vk_end_frame_wrapper :: proc(device: gfx_interface.Gfx_Device) -> common.Engine_Error { 
	if device.variant == nil {
		log.error("vk_end_frame_wrapper: Gfx_Device variant is nil.")
		return common.Engine_Error.Invalid_Handle
	}
	vk_dev, ok_dev := device.variant.(vk_types.Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { 
		log.errorf("vk_end_frame_wrapper: Invalid Gfx_Device variant type (%T) or nil pointer.", device.variant)
		return common.Engine_Error.Invalid_Handle
	}
	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil { 
		log.error("vk_end_frame_wrapper: No primary window set on device.")
		return common.Engine_Error.Invalid_Operation
	}
	primary_gfx_window := gfx_interface.Gfx_Window{variant = primary_window_ptr}

    err := vk_command.vk_end_frame_internal(primary_gfx_window)
	if err != .None {
		// Specific error logging is done in vk_end_frame_internal
		// log.errorf("vk_end_frame_wrapper: Error from vk_end_frame_internal: %v", err)
		return err
	}
    return .None
}
vk_clear_screen_wrapper :: proc(device: gfx_interface.Gfx_Device, options: gfx_interface.Clear_Options) { 
	vk_dev, ok_dev := device.variant.(vk_types.Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { log.error("vk_clear_screen_wrapper: Invalid Gfx_Device."); return }
	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil { log.error("vk_clear_screen_wrapper: No primary window."); return }
	primary_gfx_window := gfx_interface.Gfx_Window{variant = primary_window_ptr}
    vk_command.vk_clear_screen_internal(primary_gfx_window, options)
}
vk_set_viewport_wrapper :: proc(device: gfx_interface.Gfx_Device, viewport: gfx_interface.Viewport) { 
	vk_dev, ok_dev := device.variant.(vk_types.Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { log.error("vk_set_viewport_wrapper: Invalid Gfx_Device."); return }
	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil || primary_window_ptr.active_command_buffer == vk.NULL_HANDLE { return }
	vk_command.vk_set_viewport_internal(primary_window_ptr.active_command_buffer, viewport)
}
vk_set_scissor_wrapper :: proc(device: gfx_interface.Gfx_Device, scissor: gfx_interface.Scissor) { 
	vk_dev, ok_dev := device.variant.(vk_types.Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { log.error("vk_set_scissor_wrapper: Invalid Gfx_Device."); return }
	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil || primary_window_ptr.active_command_buffer == vk.NULL_HANDLE { return }
	vk_command.vk_set_scissor_internal(primary_window_ptr.active_command_buffer, scissor)
}

vk_set_vertex_buffer_wrapper :: proc(device: gfx_interface.Gfx_Device, buffer: gfx_interface.Gfx_Buffer, binding_index: u32 = 0, offset: u32 = 0) { 
	vk_dev, ok_dev := device.variant.(vk_types.Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { log.error("vk_set_vertex_buffer_wrapper: Invalid Gfx_Device."); return }
	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil || primary_window_ptr.active_command_buffer == vk.NULL_HANDLE { return }
	vk_command.vk_set_vertex_buffer_internal(primary_window_ptr.active_command_buffer, buffer, binding_index, offset)
}

vk_draw_wrapper :: proc(device: gfx_interface.Gfx_Device, vertex_count, instance_count, first_vertex, first_instance: u32) {
	vk_dev, ok_dev := device.variant.(vk_types.Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { log.error("vk_draw_wrapper: Invalid Gfx_Device."); return }
	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil || primary_window_ptr.active_command_buffer == vk.NULL_HANDLE { return }
    
    vk_command.vk_cmd_bind_descriptor_sets_internal(primary_window_ptr) // Bind current sets for the window
	vk_command.vk_draw_internal(primary_window_ptr.active_command_buffer, vertex_count, instance_count, first_vertex, first_instance)
}

vk_draw_indexed_wrapper :: proc( device: gfx_interface.Gfx_Device, index_count: u32, instance_count: u32, first_index: u32, base_vertex: u32, first_instance: u32) {
    vk_dev, ok_dev := device.variant.(vk_types.Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { log.error("vk_draw_indexed_wrapper: Invalid Gfx_Device."); return }
	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil || primary_window_ptr.active_command_buffer == vk.NULL_HANDLE { return }

    vk_command.vk_cmd_bind_descriptor_sets_internal(primary_window_ptr) // Bind current sets for the window
	vk_command.vk_draw_indexed_internal(primary_window_ptr.active_command_buffer, index_count, instance_count, first_index, i32(base_vertex), first_instance)
}

// --- VAO Management Wrappers --- 
vk_create_vertex_array_wrapper :: proc( device: gfx_interface.Gfx_Device, vertex_buffer_layouts: []gfx_interface.Vertex_Buffer_Layout, vertex_buffers: []gfx_interface.Gfx_Buffer, index_buffer: gfx_interface.Gfx_Buffer,) -> (gfx_interface.Gfx_Vertex_Array, common.Engine_Error) { 
    return vk_vao.vk_create_vertex_array_internal(device, vertex_buffer_layouts, vertex_buffers, index_buffer)
}
vk_destroy_vertex_array_wrapper :: proc(vao: gfx_interface.Gfx_Vertex_Array) -> common.Engine_Error { 
    err := vk_vao.vk_destroy_vertex_array_internal(vao)
    if err != .None {
        // log.errorf("vk_destroy_vertex_array_wrapper: Error: %v", err) // Internal logs
        return err
    }
    return .None
}
vk_bind_vertex_array_wrapper :: proc(device: gfx_interface.Gfx_Device, vao_handle_gfx: gfx_interface.Gfx_Vertex_Array) { 
    vk_vao.vk_bind_vertex_array_internal(device, vao_handle_gfx)
}
vk_set_index_buffer_wrapper :: proc(device: gfx_interface.Gfx_Device, buffer_gfx: gfx_interface.Gfx_Buffer, offset: u32 = 0) { 
    vk_vao.vk_set_index_buffer_internal(device, buffer_gfx, offset)
}

// --- Uniform and Texture Binding Wrappers ---
vk_set_uniform_mat4_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, mat: matrix[4,4]f32) -> common.Engine_Error { 
    log.debugf("Vulkan: vk_set_uniform_mat4_wrapper called for pipeline %v, uniform '%s'.", pipeline.handle, name)
    // For now, assume binding 0 for the MVP matrix UBO. This needs to be more flexible.
    // The 'pipeline' parameter is not used by vk_set_uniform_mat4_internal, but kept in wrapper for API consistency.
    binding_index: u32 = 0 
    return vk_descriptors.vk_set_uniform_mat4_internal(device, binding_index, mat)
}
vk_set_uniform_vec2_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [2]f32) -> common.Engine_Error { 
    log.debugf("Vulkan: vk_set_uniform_vec2_wrapper called for pipeline %v, uniform '%s'. Value: %v", pipeline.handle, name, vec)
    binding_index: u32 = 1; // Placeholder: This needs a proper mechanism.
    // The `pipeline` parameter is not used in the internal function yet, but might be in a more complete implementation.
    return vk_descriptors.vk_set_uniform_vec2_internal(device, binding_index, vec)
}
vk_set_uniform_vec3_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [3]f32) -> common.Engine_Error { 
    log.debugf("Vulkan: vk_set_uniform_vec3_wrapper called for pipeline %v, uniform '%s'. Value: %v", pipeline.handle, name, vec)
    binding_index: u32 = 1; // Placeholder
    return vk_descriptors.vk_set_uniform_vec3_internal(device, binding_index, vec)
}
vk_set_uniform_vec4_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [4]f32) -> common.Engine_Error { 
    log.debugf("Vulkan: vk_set_uniform_vec4_wrapper called for pipeline %v, uniform '%s'. Value: %v", pipeline.handle, name, vec)
    binding_index: u32 = 1; // Placeholder
    return vk_descriptors.vk_set_uniform_vec4_internal(device, binding_index, vec)
}
vk_set_uniform_int_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, val: i32) -> common.Engine_Error { 
    log.debugf("Vulkan: vk_set_uniform_int_wrapper called for pipeline %v, uniform '%s'. Value: %v", pipeline.handle, name, val)
    binding_index: u32 = 1; // Placeholder
    return vk_descriptors.vk_set_uniform_int_internal(device, binding_index, val)
}
vk_set_uniform_float_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, val: f32) -> common.Engine_Error { 
    log.debugf("Vulkan: vk_set_uniform_float_wrapper called for pipeline %v, uniform '%s'. Value: %v", pipeline.handle, name, val)
    binding_index: u32 = 1; // Placeholder
    return vk_descriptors.vk_set_uniform_float_internal(device, binding_index, val)
}

vk_bind_texture_to_unit_wrapper :: proc(device: gfx_interface.Gfx_Device, texture: gfx_interface.Gfx_Texture, unit: u32) -> common.Engine_Error {
    // 'unit' here is the descriptor set binding for the texture.
    // This wrapper's signature might need to align with others (pipeline, name) if uniform texture management becomes more complex.
    // For now, it's kept simpler as per existing code.
    return vk_descriptors.vk_bind_texture_to_unit_internal(device, texture, unit)
}

vk_stub_get_error_string :: proc(error: common.Engine_Error) -> string { return common.engine_error_to_string(error) }

initialize_vulkan_backend :: proc() {
	gfx_interface.gfx_api = gfx_interface.Gfx_Device_Interface {
		create_device              = vk_device.vk_create_device_wrapper,
		destroy_device             = vk_device.vk_destroy_device_wrapper, 
		create_window              = vk_window.vk_create_window_wrapper,
		destroy_window             = vk_window.vk_destroy_window_wrapper, // To be updated
		present_window             = vk_window.vk_present_window_wrapper, 
		resize_window              = vk_window.vk_resize_window_wrapper,  
		get_window_size            = vk_window.vk_get_window_size_wrapper,
		get_window_drawable_size   = vk_window.vk_get_window_drawable_size_wrapper,
		
		create_shader_from_source  = vk_create_shader_from_source_wrapper,
		create_shader_from_bytecode= vk_create_shader_from_bytecode_wrapper,
		destroy_shader             = vk_destroy_shader_wrapper, // Ensure this matches the new signature
        create_pipeline            = vk_create_pipeline_wrapper, 
        destroy_pipeline           = vk_destroy_pipeline_wrapper, // Ensure this matches the new signature
        set_pipeline               = vk_set_pipeline_wrapper, // Signature updated

		create_buffer              = vk_create_buffer_wrapper,
		update_buffer              = vk_update_buffer_wrapper, 
		destroy_buffer             = vk_destroy_buffer_wrapper, // Signature updated
        map_buffer                 = vk_map_buffer_wrapper,     // Signature updated
        unmap_buffer               = vk_unmap_buffer_wrapper,   // Signature updated
		set_vertex_buffer          = vk_set_vertex_buffer_wrapper, 
		set_index_buffer           = vk_set_index_buffer_wrapper, 

		create_texture             = vk_create_texture_wrapper,
		update_texture             = vk_update_texture_wrapper, // Added nil variant check
		destroy_texture            = vk_destroy_texture_wrapper, // Signature updated
		bind_texture_to_unit       = vk_bind_texture_to_unit_wrapper, 
		get_texture_width          = vk_get_texture_width_wrapper,
		get_texture_height         = vk_get_texture_height_wrapper,

		begin_frame                = vk_begin_frame_wrapper, // Signature updated
		end_frame                  = vk_end_frame_wrapper,   // Signature updated

		clear_screen               = vk_clear_screen_wrapper, 
        set_viewport               = vk_set_viewport_wrapper, 
        set_scissor                = vk_set_scissor_wrapper,  
		draw                       = vk_draw_wrapper, 
		draw_indexed               = vk_draw_indexed_wrapper, 

		set_uniform_mat4           = vk_set_uniform_mat4_wrapper, 
		set_uniform_vec2           = vk_set_uniform_vec2_wrapper, 
		set_uniform_vec3           = vk_set_uniform_vec3_wrapper, 
		set_uniform_vec4           = vk_set_uniform_vec4_wrapper, 
		set_uniform_int            = vk_set_uniform_int_wrapper,    
		set_uniform_float          = vk_set_uniform_float_wrapper,  
		
		create_vertex_array      = vk_create_vertex_array_wrapper,
		destroy_vertex_array     = vk_destroy_vertex_array_wrapper, // Signature updated
		bind_vertex_array        = vk_bind_vertex_array_wrapper,
		
        get_error_string           = vk_stub_get_error_string, // This should point to a real error string function.
	}
	log.info("Vulkan graphics backend initialized and assigned to gfx_api.")
}
