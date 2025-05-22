package vulkan

import "../gfx_interface"
import "core:log"

// --- Stub Implementations for Vulkan ---
// These functions will be assigned to gfx_api for features not yet implemented in Vulkan.

vk_stub_create_shader_from_source :: proc(device: gfx_interface.Gfx_Device, source: string, stage: gfx_interface.Shader_Stage) -> (gfx_interface.Gfx_Shader, gfx_interface.Gfx_Error) {
	log.warn("Vulkan: create_shader_from_source not implemented.")
	return gfx_interface.Gfx_Shader{}, .Not_Implemented
}
vk_stub_create_shader_from_bytecode :: proc(device: gfx_interface.Gfx_Device, bytecode: []u8, stage: gfx_interface.Shader_Stage) -> (gfx_interface.Gfx_Shader, gfx_interface.Gfx_Error) {
	log.warn("Vulkan: create_shader_from_bytecode not implemented.")
	return gfx_interface.Gfx_Shader{}, .Not_Implemented
}
vk_stub_destroy_shader :: proc(shader: gfx_interface.Gfx_Shader) {
	log.warn("Vulkan: destroy_shader not implemented.")
}
vk_stub_create_pipeline :: proc(device: gfx_interface.Gfx_Device, shaders: []gfx_interface.Gfx_Shader) -> (gfx_interface.Gfx_Pipeline, gfx_interface.Gfx_Error) {
	log.warn("Vulkan: create_pipeline not implemented.")
	return gfx_interface.Gfx_Pipeline{}, .Not_Implemented
}
vk_stub_destroy_pipeline :: proc(pipeline: gfx_interface.Gfx_Pipeline) {
	log.warn("Vulkan: destroy_pipeline not implemented.")
}
vk_stub_create_buffer :: proc(device: gfx_interface.Gfx_Device, type: gfx_interface.Buffer_Type, size: int, data: rawptr = nil, dynamic: bool = false) -> (gfx_interface.Gfx_Buffer, gfx_interface.Gfx_Error) {
	log.warn("Vulkan: create_buffer not implemented.")
	return gfx_interface.Gfx_Buffer{}, .Not_Implemented
}
vk_stub_update_buffer :: proc(buffer: gfx_interface.Gfx_Buffer, offset: int, data: rawptr, size: int) -> gfx_interface.Gfx_Error {
	log.warn("Vulkan: update_buffer not implemented.")
	return .Not_Implemented
}
vk_stub_destroy_buffer :: proc(buffer: gfx_interface.Gfx_Buffer) {
	log.warn("Vulkan: destroy_buffer not implemented.")
}
vk_stub_map_buffer :: proc(buffer: gfx_interface.Gfx_Buffer, offset, size: int) -> rawptr {
    log.warn("Vulkan: map_buffer not implemented.")
    return nil
}
vk_stub_unmap_buffer :: proc(buffer: gfx_interface.Gfx_Buffer) {
    log.warn("Vulkan: unmap_buffer not implemented.")
}
vk_stub_create_texture :: proc(device: gfx_interface.Gfx_Device, width, height: int, format: gfx_interface.Texture_Format, usage: gfx_interface.Texture_Usage, data: rawptr = nil) -> (gfx_interface.Gfx_Texture, gfx_interface.Gfx_Error) {
	log.warn("Vulkan: create_texture not implemented.")
	return gfx_interface.Gfx_Texture{}, .Not_Implemented
}
vk_stub_update_texture :: proc(texture: gfx_interface.Gfx_Texture, x, y, width, height: int, data: rawptr) -> gfx_interface.Gfx_Error {
	log.warn("Vulkan: update_texture not implemented.")
	return .Not_Implemented
}
vk_stub_destroy_texture :: proc(texture: gfx_interface.Gfx_Texture) {
	log.warn("Vulkan: destroy_texture not implemented.")
}
vk_stub_begin_frame :: proc(device: gfx_interface.Gfx_Device) {
	log.debug("Vulkan: begin_frame (stub).") // Debug as it might be called frequently
}
vk_stub_end_frame :: proc(device: gfx_interface.Gfx_Device) {
	log.debug("Vulkan: end_frame (stub).")
}
vk_stub_clear_screen :: proc(device: gfx_interface.Gfx_Device, options: gfx_interface.Clear_Options) {
	log.warn("Vulkan: clear_screen not implemented.")
}
vk_stub_set_viewport :: proc(device: gfx_interface.Gfx_Device, viewport: gfx_interface.Viewport) {
    log.warn("Vulkan: set_viewport not implemented.")
}
vk_stub_set_scissor :: proc(device: gfx_interface.Gfx_Device, scissor: gfx_interface.Scissor) {
    log.warn("Vulkan: set_scissor not implemented.")
}
vk_stub_set_pipeline :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline) {
	log.warn("Vulkan: set_pipeline not implemented.")
}
vk_stub_set_vertex_buffer :: proc(device: gfx_interface.Gfx_Device, buffer: gfx_interface.Gfx_Buffer, binding_index: u32 = 0, offset: u32 = 0) {
	log.warn("Vulkan: set_vertex_buffer not implemented.")
}
vk_stub_set_index_buffer :: proc(device: gfx_interface.Gfx_Device, buffer: gfx_interface.Gfx_Buffer, offset: u32 = 0) {
	log.warn("Vulkan: set_index_buffer not implemented.")
}
vk_stub_set_uniform_mat4 :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, mat: matrix[4,4]f32) -> gfx_interface.Gfx_Error {
    log.warn("Vulkan: set_uniform_mat4 not implemented.")
    return .Not_Implemented
}
vk_stub_set_uniform_vec2 :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [2]f32) -> gfx_interface.Gfx_Error {
    log.warn("Vulkan: set_uniform_vec2 not implemented.")
    return .Not_Implemented
}
vk_stub_set_uniform_vec3 :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [3]f32) -> gfx_interface.Gfx_Error {
    log.warn("Vulkan: set_uniform_vec3 not implemented.")
    return .Not_Implemented
}
vk_stub_set_uniform_vec4 :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [4]f32) -> gfx_interface.Gfx_Error {
    log.warn("Vulkan: set_uniform_vec4 not implemented.")
    return .Not_Implemented
}
vk_stub_set_uniform_int :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, val: i32) -> gfx_interface.Gfx_Error {
    log.warn("Vulkan: set_uniform_int not implemented.")
    return .Not_Implemented
}
vk_stub_set_uniform_float :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, val: f32) -> gfx_interface.Gfx_Error {
    log.warn("Vulkan: set_uniform_float not implemented.")
    return .Not_Implemented
}
vk_stub_bind_texture_to_unit :: proc(device: gfx_interface.Gfx_Device, texture: gfx_interface.Gfx_Texture, unit: u32) -> gfx_interface.Gfx_Error {
    log.warn("Vulkan: bind_texture_to_unit not implemented.")
    return .Not_Implemented
}
vk_stub_create_vertex_array :: proc(device: gfx_interface.Gfx_Device, layouts: []gfx_interface.Vertex_Buffer_Layout, vertex_buffers: []gfx_interface.Gfx_Buffer, index_buffer: gfx_interface.Gfx_Buffer) -> (gfx_interface.Gfx_Vertex_Array, gfx_interface.Gfx_Error) {
    log.warn("Vulkan: create_vertex_array not implemented.")
    return gfx_interface.Gfx_Vertex_Array{}, .Not_Implemented
}
vk_stub_destroy_vertex_array :: proc(vao: gfx_interface.Gfx_Vertex_Array) {
    log.warn("Vulkan: destroy_vertex_array not implemented.")
}
vk_stub_bind_vertex_array :: proc(device: gfx_interface.Gfx_Device, vao: gfx_interface.Gfx_Vertex_Array) {
    log.warn("Vulkan: bind_vertex_array not implemented.")
}
vk_stub_get_texture_width :: proc(texture: gfx_interface.Gfx_Texture) -> int {
    log.warn("Vulkan: get_texture_width not implemented.")
    return 0
}
vk_stub_get_texture_height :: proc(texture: gfx_interface.Gfx_Texture) -> int {
    log.warn("Vulkan: get_texture_height not implemented.")
    return 0
}
vk_stub_draw :: proc(device: gfx_interface.Gfx_Device, vertex_count, instance_count, first_vertex, first_instance: u32) {
	log.warn("Vulkan: draw not implemented.")
}
vk_stub_draw_indexed :: proc(device: gfx_interface.Gfx_Device, index_count, instance_count, first_index, base_vertex, first_instance: u32) {
	log.warn("Vulkan: draw_indexed not implemented.")
}
vk_stub_get_error_string :: proc(error: gfx_interface.Gfx_Error) -> string {
    // This can use the same error string mapping as OpenGL backend, or a Vulkan specific one if needed.
    // For now, assume generic error strings.
    #partial switch error {
    case .None: return "No error (Vulkan)" // Add (Vulkan) for clarity during testing
    case .Initialization_Failed: return "Initialization failed (Vulkan)"
    case .Device_Creation_Failed: return "Device creation failed (Vulkan)"
    case .Window_Creation_Failed: return "Window creation failed (Vulkan)"
    case .Shader_Compilation_Failed: return "Shader compilation failed (Vulkan)"
    case .Buffer_Creation_Failed: return "Buffer creation failed (Vulkan)"
    case .Texture_Creation_Failed: return "Texture creation failed (Vulkan)"
    case .Invalid_Handle: return "Invalid handle (Vulkan)"
    case .Not_Implemented: return "Not implemented (Vulkan)"
    }
    return "Unknown Gfx_Error (Vulkan)"
}


// initialize_vulkan_backend populates the global gfx_api with Vulkan implementations.
initialize_vulkan_backend :: proc() {
	gfx_interface.gfx_api = gfx_interface.Gfx_Device_Interface {
		// Device and Window Management (Implemented)
		create_device              = vk_create_device_wrapper,
		destroy_device             = vk_destroy_device_wrapper,
		create_window              = vk_create_window_wrapper,
		destroy_window             = vk_destroy_window_wrapper,
		present_window             = vk_present_window_wrapper, // Basic stub for now
		resize_window              = vk_resize_window_wrapper,  // Basic stub for now
		get_window_size            = vk_get_window_size_wrapper,
		get_window_drawable_size   = vk_get_window_drawable_size_wrapper,
		
		// Shader Management (Stubs)
		create_shader_from_source  = vk_stub_create_shader_from_source,
		create_shader_from_bytecode= vk_stub_create_shader_from_bytecode,
		destroy_shader             = vk_stub_destroy_shader,
        create_pipeline            = vk_stub_create_pipeline,
        destroy_pipeline           = vk_stub_destroy_pipeline,
        set_pipeline               = vk_stub_set_pipeline,

		// Buffer Management (Stubs)
		create_buffer              = vk_stub_create_buffer,
		update_buffer              = vk_stub_update_buffer,
		destroy_buffer             = vk_stub_destroy_buffer,
        map_buffer                 = vk_stub_map_buffer,
        unmap_buffer               = vk_stub_unmap_buffer,
		set_vertex_buffer          = vk_stub_set_vertex_buffer,
		set_index_buffer           = vk_stub_set_index_buffer,

		// Texture Management (Stubs)
		create_texture             = vk_stub_create_texture,
		update_texture             = vk_stub_update_texture,
		destroy_texture            = vk_stub_destroy_texture,
		bind_texture_to_unit       = vk_stub_bind_texture_to_unit,
		get_texture_width          = vk_stub_get_texture_width,
		get_texture_height         = vk_stub_get_texture_height,

		// Frame Management (Stubs)
		begin_frame                = vk_stub_begin_frame,
		end_frame                  = vk_stub_end_frame,

		// Drawing Commands (Stubs)
		clear_screen               = vk_stub_clear_screen,
        set_viewport               = vk_stub_set_viewport,
        set_scissor                = vk_stub_set_scissor,
		draw                       = vk_stub_draw,
		draw_indexed               = vk_stub_draw_indexed,

		// Uniforms (Stubs)
		set_uniform_mat4           = vk_stub_set_uniform_mat4,
		set_uniform_vec2           = vk_stub_set_uniform_vec2,
		set_uniform_vec3           = vk_stub_set_uniform_vec3,
		set_uniform_vec4           = vk_stub_set_uniform_vec4,
		set_uniform_int            = vk_stub_set_uniform_int,
		set_uniform_float          = vk_stub_set_uniform_float,
		
		// VAO (Stubs)
		create_vertex_array      = vk_stub_create_vertex_array,
		destroy_vertex_array     = vk_stub_destroy_vertex_array,
		bind_vertex_array        = vk_stub_bind_vertex_array,
		
        // Utility (Stub, could share with GL or have specific error codes)
        get_error_string           = vk_stub_get_error_string,
	}
	log.info("Vulkan graphics backend initialized and assigned to gfx_api (Device/Window/Swapchain setup complete, others stubbed).")
}
