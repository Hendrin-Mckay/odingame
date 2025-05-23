package directx11

import "../gfx_interface"
import "core:log"
import "core:mem"
import "core:strings"
import "../../common" // For common.Engine_Error

// Initialize the DirectX 11 backend and set up the global graphics API
initialize_d3d11_backend :: proc() -> common.Engine_Error {
    // Initialize the global gfx_api with DirectX 11 implementations
    gfx_interface.gfx_api = gfx_interface.Gfx_Device_Interface{
        // Device and window management
        create_device = create_device_impl,
        destroy_device = destroy_device_impl,
        create_window = create_window_impl,
        destroy_window = destroy_window_impl,
        
        // Frame management
        begin_frame = begin_frame_impl,
        end_frame = end_frame_impl,
        clear_screen = clear_screen_impl,
        
        // Viewport and scissor
        set_viewport = set_viewport_impl,
        set_scissor = set_scissor_impl,
        disable_scissor = disable_scissor_impl,
        
        // Shader management
        create_shader_from_source = create_shader_from_source_impl,
        create_shader_from_bytecode = create_shader_from_bytecode_impl,
        destroy_shader = destroy_shader_impl,
        
        // Pipeline management
        create_pipeline = create_pipeline_impl,
        destroy_pipeline = destroy_pipeline_impl,
        set_pipeline = set_pipeline_impl,
        
        // Buffer management
        create_buffer = create_buffer_impl,
        update_buffer = update_buffer_impl,
        destroy_buffer = destroy_buffer_impl,
        map_buffer = map_buffer_impl,
        unmap_buffer = unmap_buffer_impl,
        
        // Vertex/index buffer binding
        set_vertex_buffer = set_vertex_buffer_impl,
        set_index_buffer = set_index_buffer_impl,
        
        // Texture management
        create_texture = create_texture_impl,
        update_texture = update_texture_impl,
        destroy_texture = destroy_texture_impl,
        bind_texture_to_unit = bind_texture_to_unit_impl,
        get_texture_width = get_texture_width_impl,
        get_texture_height = get_texture_height_impl,
        
        // Framebuffer management
        create_framebuffer = create_framebuffer_impl,
        destroy_framebuffer = destroy_framebuffer_impl,
        
        // Render pass management
        create_render_pass = create_render_pass_impl,
        begin_render_pass = begin_render_pass_impl,
        end_render_pass = end_render_pass_impl,
        
        // State management
        set_blend_mode = set_blend_mode_impl,
        set_depth_test = set_depth_test_impl,
        set_cull_mode = set_cull_mode_impl,
        
        // Drawing
        draw = draw_impl,
        draw_indexed = draw_indexed_impl,
        
        // Uniforms
        set_uniform_mat4 = set_uniform_mat4_impl,
        set_uniform_vec2 = set_uniform_vec2_impl,
        set_uniform_vec3 = set_uniform_vec3_impl,
        set_uniform_vec4 = set_uniform_vec4_impl,
        set_uniform_int = set_uniform_int_impl,
        set_uniform_float = set_uniform_float_impl,
        
        // Error handling
        get_error_string = get_error_string_impl,
    }
    
    log.info("DirectX 11 backend initialized and assigned to gfx_api")
    return .None
}

// Get a string representation of the last DirectX 11 error
get_error_string_impl :: proc(error: common.Engine_Error) -> string {
    // In a real implementation, this would use DXGetErrorDescription or similar
	 return common.engine_error_to_string(error)
}
