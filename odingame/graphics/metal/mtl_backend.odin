package metal

import "../gfx_interface"
import "../../common" // For common.Engine_Error
import "core:log"

// initialize_metal_backend populates the global gfx_api with Metal stub implementations.
initialize_metal_backend :: proc() {
	gfx_interface.gfx_api = gfx_interface.Gfx_Device_Interface {
		// Device Management
		create_device              = mtl_create_device_wrapper,
		destroy_device             = mtl_destroy_device_wrapper,
		
		// Window Management
		create_window              = mtl_create_window_wrapper,
		destroy_window             = mtl_destroy_window_wrapper,
		present_window             = mtl_present_window_wrapper,
		resize_window              = mtl_resize_window_wrapper,
		get_window_size            = mtl_get_window_size_wrapper,
		get_window_drawable_size   = mtl_get_window_drawable_size_wrapper,
		
		// Shader Management
		create_shader_from_source  = mtl_create_shader_from_source_wrapper,
		create_shader_from_bytecode= mtl_create_shader_from_bytecode_wrapper,
		destroy_shader             = mtl_destroy_shader_wrapper,
        
		// Pipeline Management
		create_pipeline            = mtl_create_pipeline_wrapper,
        destroy_pipeline           = mtl_destroy_pipeline_wrapper,
        set_pipeline               = mtl_set_pipeline_wrapper,

		// Buffer Management
		create_buffer              = mtl_create_buffer_wrapper,
		update_buffer              = mtl_update_buffer_wrapper,
		destroy_buffer             = mtl_destroy_buffer_wrapper,
        map_buffer                 = mtl_map_buffer_wrapper,
        unmap_buffer               = mtl_unmap_buffer_wrapper,
		set_vertex_buffer          = mtl_set_vertex_buffer_wrapper,
		set_index_buffer           = mtl_set_index_buffer_wrapper,

		// Texture Management
		create_texture             = mtl_create_texture_wrapper,
		update_texture             = mtl_update_texture_wrapper,
		destroy_texture            = mtl_destroy_texture_wrapper,
		bind_texture_to_unit       = mtl_bind_texture_to_unit_wrapper,
		get_texture_width          = mtl_get_texture_width_wrapper,
		get_texture_height         = mtl_get_texture_height_wrapper,

		// Frame Management
		begin_frame                = mtl_begin_frame_wrapper,
		end_frame                  = mtl_end_frame_wrapper,

		// Drawing Commands
		clear_screen               = mtl_clear_screen_wrapper,
        set_viewport               = mtl_set_viewport_wrapper,
        set_scissor                = mtl_set_scissor_wrapper,
		draw                       = mtl_draw_wrapper,
		draw_indexed               = mtl_draw_indexed_wrapper,

		// Uniforms
		set_uniform_mat4           = mtl_set_uniform_mat4_wrapper,
		set_uniform_vec2           = mtl_set_uniform_vec2_wrapper,
		set_uniform_vec3           = mtl_set_uniform_vec3_wrapper,
		set_uniform_vec4           = mtl_set_uniform_vec4_wrapper,
		set_uniform_int            = mtl_set_uniform_int_wrapper,
		set_uniform_float          = mtl_set_uniform_float_wrapper,
		
		// VAO (Vertex Descriptors)
		create_vertex_array      = mtl_create_vertex_array_wrapper,
		destroy_vertex_array     = mtl_destroy_vertex_array_wrapper,
		bind_vertex_array        = mtl_bind_vertex_array_wrapper,
		
        // Utility
        get_error_string           = mtl_get_error_string_wrapper, // Ensure this points to a correctly defined function
	}
	log.info("Metal graphics backend initialized with stub functions and assigned to gfx_api.")
}

// If mtl_get_error_string_wrapper is defined elsewhere, ensure its signature is:
// mtl_get_error_string_wrapper :: proc(error: common.Engine_Error) -> string
// and it uses common.engine_error_to_string(error) or similar.
// If it's a simple stub defined here (not shown in original read_files), it would be:
/*
mtl_get_error_string_wrapper :: proc(error: common.Engine_Error) -> string {
    return common.engine_error_to_string(error)
}
*/
