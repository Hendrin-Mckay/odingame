package vulkan

import "../gfx_interface"
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


// --- Shader Management Wrappers ---
vk_create_shader_from_bytecode_wrapper :: proc( device: gfx_interface.Gfx_Device, bytecode: []u8, stage: gfx_interface.Shader_Stage,) -> (gfx_interface.Gfx_Shader, common.Engine_Error) {
	return vk_shader.vk_create_shader_from_bytecode_internal(device, bytecode, stage)
}
vk_destroy_shader_wrapper :: proc(shader: gfx_interface.Gfx_Shader) {
	vk_shader.vk_destroy_shader_internal(shader)
}
vk_create_shader_from_source_wrapper :: proc( device: gfx_interface.Gfx_Device, source: string, stage: gfx_interface.Shader_Stage,) -> (gfx_interface.Gfx_Shader, common.Engine_Error) {
	return vk_shader.vk_create_shader_from_source_internal(device, source, stage)
}

// --- Pipeline Management Wrappers ---
vk_create_pipeline_wrapper :: proc( device: gfx_interface.Gfx_Device, shaders: []gfx_interface.Gfx_Shader,) -> (gfx_interface.Gfx_Pipeline, common.Engine_Error) {
	vk_dev_internal, ok_dev := device.variant.(vk_types.Vk_Device_Variant)
	if !ok_dev || vk_dev_internal == nil { return gfx_interface.Gfx_Pipeline{}, common.Engine_Error.Invalid_Handle }
	if vk_dev_internal.primary_window_for_pipeline == nil { return gfx_interface.Gfx_Pipeline{}, common.Engine_Error.Invalid_Handle }
	primary_window := vk_dev_internal.primary_window_for_pipeline
	swapchain_format := primary_window.swapchain_format 
	if swapchain_format == .UNDEFINED {
		log.errorf("vk_create_pipeline_wrapper: Primary window (SDL: %s) has an undefined swapchain format.", sdl.GetWindowTitle(primary_window.sdl_window))
		return gfx_interface.Gfx_Pipeline{}, common.Engine_Error.Device_Creation_Failed 
	}
	// render_pass_handle is now part of Vk_Window_Internal, created with the window/swapchain.
    // It's assumed to be compatible.
	render_pass_handle := primary_window.render_pass 
	if render_pass_handle == vk.NULL_HANDLE {
        log.error("vk_create_pipeline_wrapper: Primary window has no valid render pass.")
        return gfx_interface.Gfx_Pipeline{}, common.Engine_Error.Invalid_Operation
    }
	
	vertex_bindings_slice: []vk_types.Vk_Vertex_Input_Binding_Description
	vertex_attributes_slice: []vk_types.Vk_Vertex_Input_Attribute_Description
	if primary_window.active_vao.variant != nil {
		if vk_vao_internal, ok_vao_internal := primary_window.active_vao.variant.(^vk_types.Vk_Vertex_Array_Internal); ok_vao_internal && vk_vao_internal != nil {
			vertex_bindings_slice = vk_vao_internal.binding_descriptions[:]
			vertex_attributes_slice = vk_vao_internal.attribute_descriptions[:]
		}
	}
	
    // vk_create_pipeline_internal now creates its own pipeline_layout using a predefined descriptor set layout
	gfx_pipeline, pipe_err := vk_pipeline.vk_create_pipeline_internal(
		device, shaders, render_pass_handle, 
		vertex_bindings_slice, vertex_attributes_slice,
	)
	if pipe_err != .None {
		// vk_create_pipeline_internal should handle cleanup of its created pipeline_layout and dsl if it fails.
		return gfx_interface.Gfx_Pipeline{}, pipe_err
	}
	return gfx_pipeline, .None
}
vk_destroy_pipeline_wrapper :: proc(pipeline: gfx_interface.Gfx_Pipeline) {
	vk_pipeline.vk_destroy_pipeline_internal(pipeline) 
}

vk_set_pipeline_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline_handle_gfx: gfx_interface.Gfx_Pipeline) {
	vk_dev_internal, ok_dev := device.variant.(vk_types.Vk_Device_Variant)
	if !ok_dev || vk_dev_internal == nil { log.error("vk_set_pipeline_wrapper: Invalid Gfx_Device."); return }
	
	primary_window_ptr := vk_dev_internal.primary_window_for_pipeline
	if primary_window_ptr == nil { log.error("vk_set_pipeline_wrapper: No primary window."); return }
	
	vk_command.vk_set_pipeline_internal(primary_window_ptr, pipeline_handle_gfx) // Pass window internal

    // Descriptor Set Allocation moved to vk_set_pipeline_internal in vk_command.odin
}


// --- Buffer Management Wrappers --- 
vk_create_buffer_wrapper :: proc( device: gfx_interface.Gfx_Device, type: gfx_interface.Buffer_Type, size: int, data: rawptr = nil, dynamic: bool = false,) -> (gfx_interface.Gfx_Buffer, common.Engine_Error) { 
    return vk_buffer.vk_create_buffer_internal(device, type, size, data, dynamic)
}
vk_destroy_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer) { 
    vk_buffer.vk_destroy_buffer_internal(buffer)
}
vk_map_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer, offset, size: int) -> rawptr { 
    return vk_buffer.vk_map_buffer_internal(buffer, offset, size)
}
vk_unmap_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer) { 
    vk_buffer.vk_unmap_buffer_internal(buffer)
}
vk_update_buffer_wrapper :: proc(buffer_handle_gfx: gfx_interface.Gfx_Buffer, offset: int, data: rawptr, size: int) -> common.Engine_Error { 
    return vk_buffer.vk_update_buffer_internal(buffer_handle_gfx, offset, data, size)
}

// --- Texture Management Wrappers --- 
vk_create_texture_wrapper :: proc( device: gfx_interface.Gfx_Device, width: int, height: int, format: gfx_interface.Texture_Format, usage: gfx_interface.Texture_Usage, data: rawptr = nil,) -> (gfx_interface.Gfx_Texture, common.Engine_Error) { 
    return vk_texture.vk_create_texture_internal(device, width, height, format, usage, data)
}
vk_destroy_texture_wrapper :: proc(texture: gfx_interface.Gfx_Texture) { 
    // The internal function needs the device handle.
    // This wrapper needs to get it from the texture itself.
    vk_texture_internal_ptr, ok := texture.variant.(^vk_types.Vk_Texture_Internal)
    if !ok || vk_texture_internal_ptr == nil {
        log.errorf("vk_destroy_texture_wrapper: Invalid texture variant.")
        return
    }
    if vk_texture_internal_ptr.device_ref == nil {
         log.errorf("vk_destroy_texture_wrapper: Texture has no internal device_ref.")
        return
    }
    device_for_destroy := gfx_interface.Gfx_Device{variant = vk_texture_internal_ptr.device_ref}
    vk_texture.vk_destroy_texture_internal(device_for_destroy, texture)
}
vk_update_texture_wrapper :: proc( texture: gfx_interface.Gfx_Texture, x: int, y: int, width: int, height: int, data: rawptr,) -> common.Engine_Error { 
    vk_texture_internal_ptr, ok := texture.variant.(^vk_types.Vk_Texture_Internal)
    if !ok || vk_texture_internal_ptr == nil { return common.Engine_Error.Invalid_Handle }
    if vk_texture_internal_ptr.device_ref == nil { return common.Engine_Error.Invalid_Handle }
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
vk_begin_frame_wrapper :: proc(device: gfx_interface.Gfx_Device) {
	vk_dev, ok_dev := device.variant.(vk_types.Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { log.error("vk_begin_frame_wrapper: Invalid Gfx_Device."); return }
	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil { log.error("vk_begin_frame_wrapper: No primary window."); return }
	primary_gfx_window := gfx_interface.Gfx_Window{variant = primary_window_ptr}
	vk_command.vk_begin_frame_internal(primary_gfx_window)
}
vk_end_frame_wrapper :: proc(device: gfx_interface.Gfx_Device) { 
	vk_dev, ok_dev := device.variant.(vk_types.Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { log.error("vk_end_frame_wrapper: Invalid Gfx_Device."); return }
	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil { log.error("vk_end_frame_wrapper: No primary window."); return }
	primary_gfx_window := gfx_interface.Gfx_Window{variant = primary_window_ptr}
    vk_command.vk_end_frame_internal(primary_gfx_window)
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
vk_destroy_vertex_array_wrapper :: proc(vao: gfx_interface.Gfx_Vertex_Array) { 
    vk_vao.vk_destroy_vertex_array_internal(vao)
}
vk_bind_vertex_array_wrapper :: proc(device: gfx_interface.Gfx_Device, vao_handle_gfx: gfx_interface.Gfx_Vertex_Array) { 
    vk_vao.vk_bind_vertex_array_internal(device, vao_handle_gfx)
}
vk_set_index_buffer_wrapper :: proc(device: gfx_interface.Gfx_Device, buffer_gfx: gfx_interface.Gfx_Buffer, offset: u32 = 0) { 
    vk_vao.vk_set_index_buffer_internal(device, buffer_gfx, offset)
}

// --- Uniform and Texture Binding Wrappers ---
vk_set_uniform_mat4_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, mat: matrix[4,4]f32) -> common.Engine_Error { 
    // Assuming binding 0 for MVP matrix UBO for now
    return vk_descriptors.vk_set_uniform_mat4_internal(device, pipeline, 0, mat)
}
vk_set_uniform_vec2_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [2]f32) -> common.Engine_Error { 
    log.warn("Vulkan: set_uniform_vec2_wrapper not fully implemented yet.")
    return common.Engine_Error.Not_Implemented
}
vk_set_uniform_vec3_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [3]f32) -> common.Engine_Error { 
    log.warn("Vulkan: set_uniform_vec3_wrapper not fully implemented yet.")
    return common.Engine_Error.Not_Implemented
}
vk_set_uniform_vec4_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [4]f32) -> common.Engine_Error { 
    log.warn("Vulkan: set_uniform_vec4_wrapper not fully implemented yet.")
    return common.Engine_Error.Not_Implemented
}
vk_set_uniform_int_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, val: i32) -> common.Engine_Error { 
    log.warn("Vulkan: set_uniform_int_wrapper not fully implemented yet.")
    return common.Engine_Error.Not_Implemented
}
vk_set_uniform_float_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, val: f32) -> common.Engine_Error { 
    log.warn("Vulkan: set_uniform_float_wrapper not fully implemented yet.")
    return common.Engine_Error.Not_Implemented
}

vk_bind_texture_to_unit_wrapper :: proc(device: gfx_interface.Gfx_Device, texture: gfx_interface.Gfx_Texture, unit: u32) -> common.Engine_Error {
    // 'unit' here is the descriptor set binding for the texture.
    return vk_descriptors.vk_bind_texture_to_unit_internal(device, texture, unit)
}

vk_stub_get_error_string :: proc(error: common.Engine_Error) -> string { return common.engine_error_to_string(error) }

initialize_vulkan_backend :: proc() {
	gfx_interface.gfx_api = gfx_interface.Gfx_Device_Interface {
		create_device              = vk_device.vk_create_device_wrapper,
		destroy_device             = vk_device.vk_destroy_device_wrapper,
		create_window              = vk_window.vk_create_window_wrapper,
		destroy_window             = vk_window.vk_destroy_window_wrapper,
		present_window             = vk_window.vk_present_window_wrapper, 
		resize_window              = vk_window.vk_resize_window_wrapper,  
		get_window_size            = vk_window.vk_get_window_size_wrapper,
		get_window_drawable_size   = vk_window.vk_get_window_drawable_size_wrapper,
		
		create_shader_from_source  = vk_create_shader_from_source_wrapper,
		create_shader_from_bytecode= vk_create_shader_from_bytecode_wrapper,
		destroy_shader             = vk_destroy_shader_wrapper,
        create_pipeline            = vk_create_pipeline_wrapper, 
        destroy_pipeline           = vk_destroy_pipeline_wrapper, 
        set_pipeline               = vk_set_pipeline_wrapper, 

		create_buffer              = vk_create_buffer_wrapper,
		update_buffer              = vk_update_buffer_wrapper, 
		destroy_buffer             = vk_destroy_buffer_wrapper,
        map_buffer                 = vk_map_buffer_wrapper,
        unmap_buffer               = vk_unmap_buffer_wrapper,
		set_vertex_buffer          = vk_set_vertex_buffer_wrapper, 
		set_index_buffer           = vk_set_index_buffer_wrapper, 

		create_texture             = vk_create_texture_wrapper,
		update_texture             = vk_update_texture_wrapper,
		destroy_texture            = vk_destroy_texture_wrapper, 
		bind_texture_to_unit       = vk_bind_texture_to_unit_wrapper, 
		get_texture_width          = vk_get_texture_width_wrapper,
		get_texture_height         = vk_get_texture_height_wrapper,

		begin_frame                = vk_begin_frame_wrapper, 
		end_frame                  = vk_end_frame_wrapper,   

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
		destroy_vertex_array     = vk_destroy_vertex_array_wrapper,
		bind_vertex_array        = vk_bind_vertex_array_wrapper,
		
        get_error_string           = vk_stub_get_error_string, // This should point to a real error string function.
	}
	log.info("Vulkan graphics backend initialized and assigned to gfx_api.")
}
