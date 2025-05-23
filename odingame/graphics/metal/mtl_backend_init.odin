package metal

import "../gfx_interface"
import "../../common"
import "core:log"
import "core:strings"
import "core:math"

// Initialize the Metal backend and set up the global graphics API
initialize_sdl_metal_backend :: proc(debug_mode: bool = false) -> common.Engine_Error {
    log.info("Initializing Metal backend...")
    
    // Metal is only available on Apple platforms
    when ODIN_OS != "darwin" {
        log.error("Metal is only available on Apple platforms")
        return .Not_Implemented
    } else {
        // Initialize the global gfx_api with Metal implementations
        gfx_interface.gfx_api = gfx_interface.Gfx_Device_Interface{
            // Device and window management
            create_device = mtl_create_device_wrapper,
            destroy_device = mtl_destroy_device_wrapper,
            create_window = mtl_create_window_wrapper,
            destroy_window = mtl_destroy_window_wrapper,
            present_window = mtl_present_window_wrapper,
            resize_window = mtl_resize_window_wrapper,
            get_window_size = mtl_get_window_size_wrapper,
            get_window_drawable_size = mtl_get_window_drawable_size_wrapper,
            
            // Shader management
            create_shader_from_source = mtl_create_shader_from_source_wrapper,
            create_shader_from_bytecode = mtl_create_shader_from_bytecode_wrapper,
            destroy_shader = mtl_destroy_shader_wrapper,
            
            // Pipeline management
            create_pipeline = mtl_create_pipeline_wrapper,
            destroy_pipeline = mtl_destroy_pipeline_wrapper,
            set_pipeline = mtl_set_pipeline_wrapper,
            
            // Buffer management
            create_buffer = mtl_create_buffer_wrapper,
            update_buffer = mtl_update_buffer_wrapper,
            destroy_buffer = mtl_destroy_buffer_wrapper,
            map_buffer = mtl_map_buffer_wrapper,
            unmap_buffer = mtl_unmap_buffer_wrapper,
            
            // Vertex/index buffer binding
            set_vertex_buffer = mtl_set_vertex_buffer_wrapper,
            set_index_buffer = mtl_set_index_buffer_wrapper,
            
            // Texture management
            create_texture = mtl_create_texture_wrapper,
            update_texture = mtl_update_texture_wrapper,
            destroy_texture = mtl_destroy_texture_wrapper,
            bind_texture_to_unit = mtl_bind_texture_to_unit_wrapper,
            get_texture_width = mtl_get_texture_width_wrapper,
            get_texture_height = mtl_get_texture_height_wrapper,
            
            // Drawing commands
            begin_frame = mtl_begin_frame_wrapper,
            end_frame = mtl_end_frame_wrapper,
            clear_screen = mtl_clear_screen_wrapper,
            set_viewport = mtl_set_viewport_wrapper,
            set_scissor = mtl_set_scissor_wrapper,
            disable_scissor = mtl_disable_scissor_wrapper,
            draw = mtl_draw_wrapper,
            draw_indexed = mtl_draw_indexed_wrapper,
            
            // Framebuffer management
            create_framebuffer = mtl_create_framebuffer_wrapper,
            destroy_framebuffer = mtl_destroy_framebuffer_wrapper,
            
            // Render pass management
            create_render_pass = mtl_create_render_pass_wrapper,
            begin_render_pass = mtl_begin_render_pass_wrapper,
            end_render_pass = mtl_end_render_pass_wrapper,
            
            // State management
            set_blend_mode = mtl_set_blend_mode_wrapper,
            set_depth_test = mtl_set_depth_test_wrapper,
            set_cull_mode = mtl_set_cull_mode_wrapper,
            
            // Uniform binding
            set_uniform_mat4 = mtl_set_uniform_mat4_wrapper,
            set_uniform_vec2 = mtl_set_uniform_vec2_wrapper,
            set_uniform_vec3 = mtl_set_uniform_vec3_wrapper,
            set_uniform_vec4 = mtl_set_uniform_vec4_wrapper,
            set_uniform_int = mtl_set_uniform_int_wrapper,
            set_uniform_float = mtl_set_uniform_float_wrapper,
            
            // Error handling
            get_error_string = mtl_get_error_string_wrapper,
        }
        
        log.info("Metal backend initialized and assigned to gfx_api")
        return .None
    }
}

// Wrapper for creating a Metal device
mtl_create_device_wrapper :: proc(allocator: ^rawptr) -> (gfx_interface.Gfx_Device, common.Engine_Error) {
    log.info("Creating Metal device...")
    // This is a stub implementation
    return gfx_interface.Gfx_Device{}, .Not_Implemented
}

// Wrapper for destroying a Metal device
mtl_destroy_device_wrapper :: proc(device: gfx_interface.Gfx_Device) {
    log.info("Destroying Metal device...")
    // This is a stub implementation
}

// Wrapper for creating a Metal window
mtl_create_window_wrapper :: proc(device: gfx_interface.Gfx_Device, title: string, width, height: int) -> (gfx_interface.Gfx_Window, common.Engine_Error) {
    log.infof("Creating Metal window: %s (%dx%d)", title, width, height)
    // This is a stub implementation
    return gfx_interface.Gfx_Window{}, .Not_Implemented
}

// Wrapper for destroying a Metal window
mtl_destroy_window_wrapper :: proc(window: gfx_interface.Gfx_Window) {
    log.info("Destroying Metal window...")
    // This is a stub implementation
}

// Wrapper for presenting a Metal window
mtl_present_window_wrapper :: proc(window: gfx_interface.Gfx_Window) -> common.Engine_Error {
    log.info("Presenting Metal window...")
    // This is a stub implementation
    return .Not_Implemented
}

// Wrapper for resizing a Metal window
mtl_resize_window_wrapper :: proc(window: gfx_interface.Gfx_Window, width, height: int) -> common.Engine_Error {
    log.infof("Resizing Metal window to %dx%d", width, height)
    // This is a stub implementation
    return .Not_Implemented
}

// Wrapper for getting window size
mtl_get_window_size_wrapper :: proc(window: gfx_interface.Gfx_Window) -> (width, height: int) {
    // This is a stub implementation
    return 0, 0
}

// Wrapper for getting window drawable size
mtl_get_window_drawable_size_wrapper :: proc(window: gfx_interface.Gfx_Window) -> (width, height: int) {
    // This is a stub implementation
    return 0, 0
}

// Wrapper for creating a shader from source
mtl_create_shader_from_source_wrapper :: proc(device: gfx_interface.Gfx_Device, vertex_source, fragment_source: string) -> (gfx_interface.Gfx_Shader, common.Engine_Error) {
    log.info("Creating Metal shader from source...")
    // This is a stub implementation
    return gfx_interface.Gfx_Shader{}, .Not_Implemented
}

// Wrapper for creating a shader from bytecode
mtl_create_shader_from_bytecode_wrapper :: proc(device: gfx_interface.Gfx_Device, vertex_bytecode, fragment_bytecode: []byte) -> (gfx_interface.Gfx_Shader, common.Engine_Error) {
    log.info("Creating Metal shader from bytecode...")
    // This is a stub implementation
    return gfx_interface.Gfx_Shader{}, .Not_Implemented
}

// Wrapper for destroying a shader
mtl_destroy_shader_wrapper :: proc(shader: gfx_interface.Gfx_Shader) {
    log.info("Destroying Metal shader...")
    // This is a stub implementation
}

// Wrapper for creating a pipeline
mtl_create_pipeline_wrapper :: proc(device: gfx_interface.Gfx_Device, shader: gfx_interface.Gfx_Shader, layout: gfx_interface.Vertex_Layout) -> (gfx_interface.Gfx_Pipeline, common.Engine_Error) {
    log.info("Creating Metal pipeline...")
    // This is a stub implementation
    return gfx_interface.Gfx_Pipeline{}, .Not_Implemented
}

// Wrapper for destroying a pipeline
mtl_destroy_pipeline_wrapper :: proc(pipeline: gfx_interface.Gfx_Pipeline) {
    log.info("Destroying Metal pipeline...")
    // This is a stub implementation
}

// Wrapper for setting a pipeline
mtl_set_pipeline_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline) {
    log.info("Setting Metal pipeline...")
    // This is a stub implementation
}

// Wrapper for creating a shader from source
mtl_create_shader_from_source_wrapper :: proc(device: gfx_interface.Gfx_Device, source: string, stage: gfx_interface.Shader_Stage) -> (gfx_interface.Gfx_Shader, common.Engine_Error) {
    log.info("Creating Metal shader from source...")
    // This is a stub implementation
    return gfx_interface.Gfx_Shader{}, .Not_Implemented
}

// Wrapper for creating a shader from bytecode
mtl_create_shader_from_bytecode_wrapper :: proc(device: gfx_interface.Gfx_Device, bytecode: []u8, stage: gfx_interface.Shader_Stage) -> (gfx_interface.Gfx_Shader, common.Engine_Error) {
    log.info("Creating Metal shader from bytecode...")
    // This is a stub implementation
    return gfx_interface.Gfx_Shader{}, .Not_Implemented
}

// Wrapper for destroying a shader
mtl_destroy_shader_wrapper :: proc(shader: gfx_interface.Gfx_Shader) {
    log.info("Destroying Metal shader...")
    // This is a stub implementation
}

// Wrapper for creating a pipeline
mtl_create_pipeline_wrapper :: proc(device: gfx_interface.Gfx_Device, shaders: []gfx_interface.Gfx_Shader) -> (gfx_interface.Gfx_Pipeline, common.Engine_Error) {
    log.info("Creating Metal pipeline...")
    // This is a stub implementation
    return gfx_interface.Gfx_Pipeline{}, .Not_Implemented
}

// Wrapper for destroying a pipeline
mtl_destroy_pipeline_wrapper :: proc(pipeline: gfx_interface.Gfx_Pipeline) {
    log.info("Destroying Metal pipeline...")
    // This is a stub implementation
}

// Wrapper for setting a pipeline
mtl_set_pipeline_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline) {
    log.info("Setting Metal pipeline...")
    // This is a stub implementation
}

// Buffer management wrapper functions
mtl_create_buffer_wrapper :: proc(device: gfx_interface.Gfx_Device, type: gfx_interface.Buffer_Type, size: int, data: rawptr = nil, is_dynamic: bool = false) -> (gfx_interface.Gfx_Buffer, common.Engine_Error) {
    log.infof("Creating Metal buffer: type=%v, size=%d, is_dynamic=%v", type, size, is_dynamic)
    // This is a stub implementation
    return gfx_interface.Gfx_Buffer{}, .Not_Implemented
}

mtl_update_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer, offset: int, data: rawptr, size: int) -> common.Engine_Error {
    log.infof("Updating Metal buffer: offset=%d, size=%d", offset, size)
    // This is a stub implementation
    return .Not_Implemented
}

mtl_destroy_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer) {
    log.info("Destroying Metal buffer")
    // This is a stub implementation
}

mtl_map_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer, offset, size: int) -> rawptr {
    log.infof("Mapping Metal buffer: offset=%d, size=%d", offset, size)
    // This is a stub implementation
    return nil
}

mtl_unmap_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer) {
    log.info("Unmapping Metal buffer")
    // This is a stub implementation
}

// Vertex/index buffer binding wrapper functions
mtl_set_vertex_buffer_wrapper :: proc(device: gfx_interface.Gfx_Device, buffer: gfx_interface.Gfx_Buffer, binding_index: u32 = 0, offset: u32 = 0) {
    log.infof("Setting Metal vertex buffer: binding=%d, offset=%d", binding_index, offset)
    // This is a stub implementation
}

mtl_set_index_buffer_wrapper :: proc(device: gfx_interface.Gfx_Device, buffer: gfx_interface.Gfx_Buffer, offset: u32 = 0) {
    log.infof("Setting Metal index buffer: offset=%d", offset)
    // This is a stub implementation
}

// Texture management wrapper functions
mtl_create_texture_wrapper :: proc(device: gfx_interface.Gfx_Device, width, height: int, format: gfx_interface.Texture_Format, usage: gfx_interface.Texture_Usage, data: rawptr = nil) -> (gfx_interface.Gfx_Texture, common.Engine_Error) {
    log.infof("Creating Metal texture: %dx%d, format=%v, usage=%v", width, height, format, usage)
    // This is a stub implementation
    return gfx_interface.Gfx_Texture{}, .Not_Implemented
}

mtl_update_texture_wrapper :: proc(texture: gfx_interface.Gfx_Texture, x, y, width, height: int, data: rawptr) -> common.Engine_Error {
    log.infof("Updating Metal texture: region=(%d,%d,%d,%d)", x, y, width, height)
    // This is a stub implementation
    return .Not_Implemented
}

mtl_destroy_texture_wrapper :: proc(texture: gfx_interface.Gfx_Texture) {
    log.info("Destroying Metal texture")
    // This is a stub implementation
}

mtl_bind_texture_to_unit_wrapper :: proc(device: gfx_interface.Gfx_Device, texture: gfx_interface.Gfx_Texture, unit: int) {
    log.infof("Binding Metal texture to unit %d", unit)
    // This is a stub implementation
}

mtl_get_texture_width_wrapper :: proc(texture: gfx_interface.Gfx_Texture) -> int {
    // This is a stub implementation
    return 0
}

mtl_get_texture_height_wrapper :: proc(texture: gfx_interface.Gfx_Texture) -> int {
    // This is a stub implementation
    return 0
}

// Drawing commands wrapper functions
mtl_begin_frame_wrapper :: proc(device: gfx_interface.Gfx_Device) {
    log.info("Beginning Metal frame")
    // This is a stub implementation
}

mtl_end_frame_wrapper :: proc(device: gfx_interface.Gfx_Device) {
    log.info("Ending Metal frame")
    // This is a stub implementation
}

mtl_clear_screen_wrapper :: proc(device: gfx_interface.Gfx_Device, options: gfx_interface.Clear_Options) {
    log.infof("Clearing Metal screen: color=%v, depth=%v, stencil=%v", options.clear_color, options.clear_depth, options.clear_stencil)
    // This is a stub implementation
}

mtl_set_viewport_wrapper :: proc(device: gfx_interface.Gfx_Device, viewport: gfx_interface.Viewport) {
    log.infof("Setting Metal viewport: x=%f, y=%f, width=%f, height=%f", viewport.position.x, viewport.position.y, viewport.size.x, viewport.size.y)
    // This is a stub implementation
}

mtl_set_scissor_wrapper :: proc(device: gfx_interface.Gfx_Device, scissor: gfx_interface.Scissor) {
    log.infof("Setting Metal scissor: x=%d, y=%d, width=%d, height=%d", scissor.x, scissor.y, scissor.w, scissor.h)
    // This is a stub implementation
}

mtl_disable_scissor_wrapper :: proc(device: gfx_interface.Gfx_Device) {
    log.info("Disabling Metal scissor")
    // This is a stub implementation
}

mtl_draw_wrapper :: proc(device: gfx_interface.Gfx_Device, vertex_count, instance_count, first_vertex, first_instance: u32) {
    log.infof("Metal draw: vertices=%d, instances=%d, first_vertex=%d, first_instance=%d", vertex_count, instance_count, first_vertex, first_instance)
    // This is a stub implementation
}

mtl_draw_indexed_wrapper :: proc(device: gfx_interface.Gfx_Device, index_count, instance_count, first_index, base_vertex, first_instance: u32) {
    log.infof("Metal draw indexed: indices=%d, instances=%d, first_index=%d, base_vertex=%d, first_instance=%d", index_count, instance_count, first_index, base_vertex, first_instance)
    // This is a stub implementation
}

// Framebuffer management wrapper functions
mtl_create_framebuffer_wrapper :: proc(device: gfx_interface.Gfx_Device, width, height: int, color_format: gfx_interface.Texture_Format, depth_format: gfx_interface.Texture_Format) -> (gfx_interface.Gfx_Framebuffer, common.Engine_Error) {
    log.infof("Creating Metal framebuffer: %dx%d, color_format=%v, depth_format=%v", width, height, color_format, depth_format)
    // This is a stub implementation
    return gfx_interface.Gfx_Framebuffer{}, .Not_Implemented
}

mtl_destroy_framebuffer_wrapper :: proc(framebuffer: gfx_interface.Gfx_Framebuffer) {
    log.info("Destroying Metal framebuffer")
    // This is a stub implementation
}

// Render pass management wrapper functions
mtl_create_render_pass_wrapper :: proc(device: gfx_interface.Gfx_Device, framebuffer: gfx_interface.Gfx_Framebuffer, clear_color, clear_depth: bool) -> (gfx_interface.Gfx_Render_Pass, common.Engine_Error) {
    log.infof("Creating Metal render pass: clear_color=%v, clear_depth=%v", clear_color, clear_depth)
    // This is a stub implementation
    return gfx_interface.Gfx_Render_Pass{}, .Not_Implemented
}

mtl_begin_render_pass_wrapper :: proc(device: gfx_interface.Gfx_Device, render_pass: gfx_interface.Gfx_Render_Pass, clear_color: math.Color, clear_depth: f32) {
    log.infof("Beginning Metal render pass: clear_color=(%v), clear_depth=%f", clear_color, clear_depth)
    // This is a stub implementation
}

mtl_end_render_pass_wrapper :: proc(device: gfx_interface.Gfx_Device, render_pass: gfx_interface.Gfx_Render_Pass) {
    log.info("Ending Metal render pass")
    // This is a stub implementation
}

// State management wrapper functions
mtl_set_blend_mode_wrapper :: proc(device: gfx_interface.Gfx_Device, blend_mode: gfx_interface.Blend_Mode) {
    log.infof("Setting Metal blend mode: %v", blend_mode)
    // This is a stub implementation
}

mtl_set_depth_test_wrapper :: proc(device: gfx_interface.Gfx_Device, enabled: bool, write: bool, func: gfx_interface.Depth_Func) {
    log.infof("Setting Metal depth test: enabled=%v, write=%v, func=%v", enabled, write, func)
    // This is a stub implementation
}

mtl_set_cull_mode_wrapper :: proc(device: gfx_interface.Gfx_Device, cull_mode: gfx_interface.Cull_Mode) {
    log.infof("Setting Metal cull mode: %v", cull_mode)
    // This is a stub implementation
}

// Uniform binding wrapper functions
mtl_set_uniform_mat4_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: math.Matrix4) {
    log.infof("Setting Metal uniform mat4: %s", name)
    // This is a stub implementation
}

mtl_set_uniform_vec2_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: math.Vector2) {
    log.infof("Setting Metal uniform vec2: %s = (%f, %f)", name, value.x, value.y)
    // This is a stub implementation
}

mtl_set_uniform_vec3_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: math.Vector3) {
    log.infof("Setting Metal uniform vec3: %s = (%f, %f, %f)", name, value.x, value.y, value.z)
    // This is a stub implementation
}

mtl_set_uniform_vec4_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: math.Vector4) {
    log.infof("Setting Metal uniform vec4: %s = (%f, %f, %f, %f)", name, value.x, value.y, value.z, value.w)
    // This is a stub implementation
}

mtl_set_uniform_int_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: int) {
    log.infof("Setting Metal uniform int: %s = %d", name, value)
    // This is a stub implementation
}

mtl_set_uniform_float_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: f32) {
    log.infof("Setting Metal uniform float: %s = %f", name, value)
    // This is a stub implementation
}

// Wrapper for getting an error string
mtl_get_error_string_wrapper :: proc(error: common.Engine_Error) -> string {
    return common.engine_error_to_string(error)
}
