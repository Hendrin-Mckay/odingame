package directx

import "../gfx_interface"
import "core:log"

// initialize_directx_backend populates the global gfx_api with DirectX stub implementations.
initialize_directx_backend :: proc() {
	gfx_interface.gfx_api = gfx_interface.Gfx_Device_Interface {
		// Device Management
		create_device              = dx_create_device_wrapper,
		destroy_device             = dx_destroy_device_wrapper,
		
		// Window Management
		create_window              = dx_create_window_wrapper,
		destroy_window             = dx_destroy_window_wrapper,
		present_window             = dx_present_window_wrapper,
		resize_window              = dx_resize_window_wrapper,
		get_window_size            = dx_get_window_size_wrapper,
		get_window_drawable_size   = dx_get_window_drawable_size_wrapper,
		
		// Shader Management
		create_shader_from_source  = dx_create_shader_from_source_wrapper,
		create_shader_from_bytecode= dx_create_shader_from_bytecode_wrapper,
		destroy_shader             = dx_destroy_shader_wrapper,
        
		// Pipeline Management
		create_pipeline            = dx_create_pipeline_wrapper,
        destroy_pipeline           = dx_destroy_pipeline_wrapper,
        set_pipeline               = dx_set_pipeline_wrapper,

		// Buffer Management
		create_buffer              = dx_create_buffer_wrapper,
		update_buffer              = dx_update_buffer_wrapper,
		destroy_buffer             = dx_destroy_buffer_wrapper,
        map_buffer                 = dx_map_buffer_wrapper,
        unmap_buffer               = dx_unmap_buffer_wrapper,
		set_vertex_buffer          = dx_set_vertex_buffer_wrapper,
		set_index_buffer           = dx_set_index_buffer_wrapper,

		// Texture Management
		create_texture             = dx_create_texture_wrapper,
		update_texture             = dx_update_texture_wrapper,
		destroy_texture            = dx_destroy_texture_wrapper,
		bind_texture_to_unit       = dx_bind_texture_to_unit_wrapper,
		get_texture_width          = dx_get_texture_width_wrapper,
		get_texture_height         = dx_get_texture_height_wrapper,

		// Frame Management
		begin_frame                = dx_begin_frame_wrapper,
		end_frame                  = dx_end_frame_wrapper,

		// Drawing Commands
		clear_screen               = dx_clear_screen_wrapper,
        set_viewport               = dx_set_viewport_wrapper,
        set_scissor                = dx_set_scissor_wrapper,
		draw                       = dx_draw_wrapper,
		draw_indexed               = dx_draw_indexed_wrapper,

		// Uniforms
		set_uniform_mat4           = dx_set_uniform_mat4_wrapper,
		set_uniform_vec2           = dx_set_uniform_vec2_wrapper,
		set_uniform_vec3           = dx_set_uniform_vec3_wrapper,
		set_uniform_vec4           = dx_set_uniform_vec4_wrapper,
		set_uniform_int            = dx_set_uniform_int_wrapper,
		set_uniform_float          = dx_set_uniform_float_wrapper,
		
		// VAO (Input Layout)
		create_vertex_array      = dx_create_vertex_array_wrapper,
		destroy_vertex_array     = dx_destroy_vertex_array_wrapper,
		bind_vertex_array        = dx_bind_vertex_array_wrapper,
		
        // Utility
        get_error_string           = dx_get_error_string_wrapper,
	}
	log.info("DirectX graphics backend initialized with stub functions and assigned to gfx_api.")
}
