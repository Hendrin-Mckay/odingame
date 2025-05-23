package vulkan

import "../gfx_interface"
import "../../common"
import "core:log"
import "core:strings"
import "core:math"
import vk "vendor:vulkan"
import sdl "vendor:sdl2"

// Initialize the Vulkan backend and set up the global graphics API
initialize_sdl_vulkan_backend :: proc(debug_mode: bool = false) -> common.Engine_Error {
    log.info("Initializing Vulkan backend...")
    
    // Check for Vulkan support in SDL
    if sdl.Vulkan_LoadLibrary(nil) != 0 {
        log.errorf("Failed to load Vulkan library: %s", sdl.GetError())
        return .Graphics_Initialization_Failed
    }
    
    // Initialize the global gfx_api with Vulkan implementations
    gfx_interface.gfx_api = gfx_interface.Gfx_Device_Interface{
        // Device and window management
        create_device = vk_create_device_wrapper,
        destroy_device = vk_destroy_device_wrapper,
        create_window = vk_create_window_wrapper,
        destroy_window = vk_destroy_window_wrapper,
        present_window = vk_present_window_wrapper,
        resize_window = vk_resize_window_wrapper,
        get_window_size = vk_get_window_size_wrapper,
        get_window_drawable_size = vk_get_window_drawable_size_wrapper,
        
        // Shader management
        create_shader_from_source = vk_create_shader_from_source_wrapper,
        create_shader_from_bytecode = vk_create_shader_from_bytecode_wrapper,
        destroy_shader = vk_destroy_shader_wrapper,
        
        // Pipeline management
        create_pipeline = vk_create_pipeline_wrapper,
        destroy_pipeline = vk_destroy_pipeline_wrapper,
        set_pipeline = vk_set_pipeline_wrapper,
        
        // Buffer management
        create_buffer = vk_create_buffer_wrapper,
        update_buffer = vk_update_buffer_wrapper,
        destroy_buffer = vk_destroy_buffer_wrapper,
        map_buffer = vk_map_buffer_wrapper,
        unmap_buffer = vk_unmap_buffer_wrapper,
        
        // Vertex/index buffer binding
        set_vertex_buffer = vk_set_vertex_buffer_wrapper,
        set_index_buffer = vk_set_index_buffer_wrapper,
        
        // Texture management
        create_texture = vk_create_texture_wrapper,
        update_texture = vk_update_texture_wrapper,
        destroy_texture = vk_destroy_texture_wrapper,
        bind_texture_to_unit = vk_bind_texture_to_unit_wrapper,
        get_texture_width = vk_get_texture_width_wrapper,
        get_texture_height = vk_get_texture_height_wrapper,
        
        // Drawing commands
        begin_frame = vk_begin_frame_wrapper,
        end_frame = vk_end_frame_wrapper,
        clear_screen = vk_clear_screen_wrapper,
        set_viewport = vk_set_viewport_wrapper,
        set_scissor = vk_set_scissor_wrapper,
        disable_scissor = vk_disable_scissor_wrapper,
        draw = vk_draw_wrapper,
        draw_indexed = vk_draw_indexed_wrapper,
        
        // Framebuffer management
        create_framebuffer = vk_create_framebuffer_wrapper,
        destroy_framebuffer = vk_destroy_framebuffer_wrapper,
        
        // Render pass management
        create_render_pass = vk_create_render_pass_wrapper,
        begin_render_pass = vk_begin_render_pass_wrapper,
        end_render_pass = vk_end_render_pass_wrapper,
        
        // State management
        set_blend_mode = vk_set_blend_mode_wrapper,
        set_depth_test = vk_set_depth_test_wrapper,
        set_cull_mode = vk_set_cull_mode_wrapper,
        
        // Uniform binding
        set_uniform_mat4 = vk_set_uniform_mat4_wrapper,
        set_uniform_vec2 = vk_set_uniform_vec2_wrapper,
        set_uniform_vec3 = vk_set_uniform_vec3_wrapper,
        set_uniform_vec4 = vk_set_uniform_vec4_wrapper,
        set_uniform_int = vk_set_uniform_int_wrapper,
        set_uniform_float = vk_set_uniform_float_wrapper,
        
        // Error handling
        get_error_string = vk_get_error_string_wrapper,
    }
    
    log.info("Vulkan backend initialized and assigned to gfx_api")
    return .None
}

// Internal function declarations
// Device and window management
vk_create_device_internal :: proc(allocator: ^rawptr) -> (gfx_interface.Gfx_Device, common.Engine_Error)
vk_destroy_device_internal :: proc(device: gfx_interface.Gfx_Device)
vk_create_window_internal :: proc(device: gfx_interface.Gfx_Device, title: string, width, height: int) -> (gfx_interface.Gfx_Window, common.Engine_Error)
vk_destroy_window_internal :: proc(window: gfx_interface.Gfx_Window)
vk_present_window_internal :: proc(window: gfx_interface.Gfx_Window) -> common.Engine_Error
vk_resize_window_internal :: proc(window: gfx_interface.Gfx_Window, width, height: int) -> common.Engine_Error
vk_get_window_size_internal :: proc(window: gfx_interface.Gfx_Window) -> (width, height: int)
vk_get_window_drawable_size_internal :: proc(window: gfx_interface.Gfx_Window) -> (width, height: int)

// Shader management
vk_create_shader_from_source_internal :: proc(device: gfx_interface.Gfx_Device, vertex_source, fragment_source: string) -> (gfx_interface.Gfx_Shader, common.Engine_Error)
vk_create_shader_from_bytecode_internal :: proc(device: gfx_interface.Gfx_Device, vertex_bytecode, fragment_bytecode: []byte) -> (gfx_interface.Gfx_Shader, common.Engine_Error)
vk_destroy_shader_internal :: proc(shader: gfx_interface.Gfx_Shader)

// Pipeline management
vk_create_pipeline_internal :: proc(device: gfx_interface.Gfx_Device, shader: gfx_interface.Gfx_Shader, layout: gfx_interface.Vertex_Layout) -> (gfx_interface.Gfx_Pipeline, common.Engine_Error)
vk_destroy_pipeline_internal :: proc(pipeline: gfx_interface.Gfx_Pipeline)
vk_set_pipeline_internal :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline)

// Buffer management
vk_create_buffer_internal :: proc(device: gfx_interface.Gfx_Device, type: gfx_interface.Buffer_Type, size: int, data: rawptr = nil, is_dynamic: bool = false) -> (gfx_interface.Gfx_Buffer, common.Engine_Error)
vk_update_buffer_internal :: proc(buffer: gfx_interface.Gfx_Buffer, offset: int, data: rawptr, size: int) -> common.Engine_Error
vk_destroy_buffer_internal :: proc(buffer: gfx_interface.Gfx_Buffer)
vk_map_buffer_internal :: proc(buffer: gfx_interface.Gfx_Buffer, offset, size: int) -> rawptr
vk_unmap_buffer_internal :: proc(buffer: gfx_interface.Gfx_Buffer)

// Vertex/index buffer binding
vk_set_vertex_buffer_internal :: proc(device: gfx_interface.Gfx_Device, buffer: gfx_interface.Gfx_Buffer, binding_index: u32 = 0, offset: u32 = 0)
vk_set_index_buffer_internal :: proc(device: gfx_interface.Gfx_Device, buffer: gfx_interface.Gfx_Buffer, offset: u32 = 0)

// Texture management
vk_create_texture_internal :: proc(device: gfx_interface.Gfx_Device, width, height: int, format: gfx_interface.Texture_Format, usage: gfx_interface.Texture_Usage, data: rawptr = nil) -> (gfx_interface.Gfx_Texture, common.Engine_Error)
vk_update_texture_internal :: proc(texture: gfx_interface.Gfx_Texture, x, y, width, height: int, data: rawptr) -> common.Engine_Error
vk_destroy_texture_internal :: proc(texture: gfx_interface.Gfx_Texture)
vk_bind_texture_to_unit_internal :: proc(device: gfx_interface.Gfx_Device, texture: gfx_interface.Gfx_Texture, unit: int)
vk_get_texture_width_internal :: proc(texture: gfx_interface.Gfx_Texture) -> int
vk_get_texture_height_internal :: proc(texture: gfx_interface.Gfx_Texture) -> int

// Drawing commands
vk_begin_frame_internal :: proc(device: gfx_interface.Gfx_Device)
vk_end_frame_internal :: proc(device: gfx_interface.Gfx_Device)
vk_clear_screen_internal :: proc(device: gfx_interface.Gfx_Device, options: gfx_interface.Clear_Options)
vk_set_viewport_internal :: proc(device: gfx_interface.Gfx_Device, viewport: gfx_interface.Viewport)
vk_set_scissor_internal :: proc(device: gfx_interface.Gfx_Device, scissor: gfx_interface.Scissor)
vk_disable_scissor_internal :: proc(device: gfx_interface.Gfx_Device)
vk_draw_internal :: proc(device: gfx_interface.Gfx_Device, vertex_count, instance_count, first_vertex, first_instance: u32)
vk_draw_indexed_internal :: proc(device: gfx_interface.Gfx_Device, index_count, instance_count, first_index, base_vertex, first_instance: u32)

// Framebuffer management
vk_create_framebuffer_internal :: proc(device: gfx_interface.Gfx_Device, width, height: int, color_format: gfx_interface.Texture_Format, depth_format: gfx_interface.Texture_Format) -> (gfx_interface.Gfx_Framebuffer, common.Engine_Error)
vk_destroy_framebuffer_internal :: proc(framebuffer: gfx_interface.Gfx_Framebuffer)

// Render pass management
vk_create_render_pass_internal :: proc(device: gfx_interface.Gfx_Device, framebuffer: gfx_interface.Gfx_Framebuffer, clear_color, clear_depth: bool) -> (gfx_interface.Gfx_Render_Pass, common.Engine_Error)
vk_begin_render_pass_internal :: proc(device: gfx_interface.Gfx_Device, render_pass: gfx_interface.Gfx_Render_Pass, clear_color: math.Color, clear_depth: f32)
vk_end_render_pass_internal :: proc(device: gfx_interface.Gfx_Device, render_pass: gfx_interface.Gfx_Render_Pass)

// State management
vk_set_blend_mode_internal :: proc(device: gfx_interface.Gfx_Device, blend_mode: gfx_interface.Blend_Mode)
vk_set_depth_test_internal :: proc(device: gfx_interface.Gfx_Device, enabled: bool, write: bool, func: gfx_interface.Depth_Func)
vk_set_cull_mode_internal :: proc(device: gfx_interface.Gfx_Device, cull_mode: gfx_interface.Cull_Mode)

// Uniform binding
vk_set_uniform_mat4_internal :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: math.Matrix4)
vk_set_uniform_vec2_internal :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: math.Vector2)
vk_set_uniform_vec3_internal :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: math.Vector3)
vk_set_uniform_vec4_internal :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: math.Vector4)
vk_set_uniform_int_internal :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: int)
vk_set_uniform_float_internal :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: f32)

// Wrapper for creating a Vulkan device
vk_create_device_wrapper :: proc(allocator: ^rawptr) -> (gfx_interface.Gfx_Device, common.Engine_Error) {
    // This will be implemented in vk_device.odin
    log.info("Creating Vulkan device...")
    return vk_create_device_internal(allocator)
}

// Wrapper for destroying a Vulkan device
vk_destroy_device_wrapper :: proc(device: gfx_interface.Gfx_Device) {
    // This will be implemented in vk_device.odin
    log.info("Destroying Vulkan device...")
    vk_destroy_device_internal(device)
}

// Wrapper for creating a Vulkan window
vk_create_window_wrapper :: proc(device: gfx_interface.Gfx_Device, title: string, width, height: int) -> (gfx_interface.Gfx_Window, common.Engine_Error) {
    // This will be implemented in vk_device.odin
    log.infof("Creating Vulkan window: %s (%dx%d)", title, width, height)
    return vk_create_window_internal(device, title, width, height)
}

// Wrapper for destroying a Vulkan window
vk_destroy_window_wrapper :: proc(window: gfx_interface.Gfx_Window) {
    // This will be implemented in vk_device.odin
    log.info("Destroying Vulkan window...")
    vk_destroy_window_internal(window)
}

// Wrapper for presenting a Vulkan window
vk_present_window_wrapper :: proc(window: gfx_interface.Gfx_Window) -> common.Engine_Error {
    log.info("Presenting Vulkan window...")
    return vk_present_window_internal(window)
}

// Wrapper for resizing a Vulkan window
vk_resize_window_wrapper :: proc(window: gfx_interface.Gfx_Window, width, height: int) -> common.Engine_Error {
    log.infof("Resizing Vulkan window to %dx%d", width, height)
    return vk_resize_window_internal(window, width, height)
}

// Wrapper for getting window size
vk_get_window_size_wrapper :: proc(window: gfx_interface.Gfx_Window) -> (width, height: int) {
    return vk_get_window_size_internal(window)
}

// Wrapper for getting window drawable size
vk_get_window_drawable_size_wrapper :: proc(window: gfx_interface.Gfx_Window) -> (width, height: int) {
    return vk_get_window_drawable_size_internal(window)
}

// Wrapper for setting a Vulkan pipeline
vk_set_pipeline_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline) {
    // This will be implemented in vk_pipeline.odin
    log.info("Setting Vulkan pipeline...")
    vk_set_pipeline_internal(device, pipeline)
}

// Wrapper for destroying a Vulkan pipeline
vk_destroy_pipeline_wrapper :: proc(pipeline: gfx_interface.Gfx_Pipeline) {
    // This will be implemented in vk_pipeline.odin
    log.info("Destroying Vulkan pipeline...")
    vk_destroy_pipeline_internal(pipeline)
}

// Buffer management wrapper functions
vk_create_buffer_wrapper :: proc(device: gfx_interface.Gfx_Device, type: gfx_interface.Buffer_Type, size: int, data: rawptr = nil, is_dynamic: bool = false) -> (gfx_interface.Gfx_Buffer, common.Engine_Error) {
    log.infof("Creating Vulkan buffer: type=%v, size=%d, is_dynamic=%v", type, size, is_dynamic)
    return vk_create_buffer_internal(device, type, size, data, is_dynamic)
}

vk_update_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer, offset: int, data: rawptr, size: int) -> common.Engine_Error {
    log.infof("Updating Vulkan buffer: offset=%d, size=%d", offset, size)
    return vk_update_buffer_internal(buffer, offset, data, size)
}

vk_destroy_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer) {
    log.info("Destroying Vulkan buffer")
    vk_destroy_buffer_internal(buffer)
}

vk_map_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer, offset, size: int) -> rawptr {
    log.infof("Mapping Vulkan buffer: offset=%d, size=%d", offset, size)
    return vk_map_buffer_internal(buffer, offset, size)
}

vk_unmap_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer) {
    log.info("Unmapping Vulkan buffer")
    vk_unmap_buffer_internal(buffer)
}

// Vertex/index buffer binding wrapper functions
vk_set_vertex_buffer_wrapper :: proc(device: gfx_interface.Gfx_Device, buffer: gfx_interface.Gfx_Buffer, binding_index: u32 = 0, offset: u32 = 0) {
    log.infof("Setting Vulkan vertex buffer: binding=%d, offset=%d", binding_index, offset)
    vk_set_vertex_buffer_internal(device, buffer, binding_index, offset)
}

vk_set_index_buffer_wrapper :: proc(device: gfx_interface.Gfx_Device, buffer: gfx_interface.Gfx_Buffer, offset: u32 = 0) {
    log.infof("Setting Vulkan index buffer: offset=%d", offset)
    vk_set_index_buffer_internal(device, buffer, offset)
}

// Texture management wrapper functions
vk_create_texture_wrapper :: proc(device: gfx_interface.Gfx_Device, width, height: int, format: gfx_interface.Texture_Format, usage: gfx_interface.Texture_Usage, data: rawptr = nil) -> (gfx_interface.Gfx_Texture, common.Engine_Error) {
    log.infof("Creating Vulkan texture: %dx%d, format=%v, usage=%v", width, height, format, usage)
    return vk_create_texture_internal(device, width, height, format, usage, data)
}

vk_update_texture_wrapper :: proc(texture: gfx_interface.Gfx_Texture, x, y, width, height: int, data: rawptr) -> common.Engine_Error {
    log.infof("Updating Vulkan texture: region=(%d,%d,%d,%d)", x, y, width, height)
    return vk_update_texture_internal(texture, x, y, width, height, data)
}

vk_destroy_texture_wrapper :: proc(texture: gfx_interface.Gfx_Texture) {
    log.info("Destroying Vulkan texture")
    vk_destroy_texture_internal(texture)
}

vk_bind_texture_to_unit_wrapper :: proc(device: gfx_interface.Gfx_Device, texture: gfx_interface.Gfx_Texture, unit: int) {
    log.infof("Binding Vulkan texture to unit %d", unit)
    vk_bind_texture_to_unit_internal(device, texture, unit)
}

vk_get_texture_width_wrapper :: proc(texture: gfx_interface.Gfx_Texture) -> int {
    return vk_get_texture_width_internal(texture)
}

vk_get_texture_height_wrapper :: proc(texture: gfx_interface.Gfx_Texture) -> int {
    return vk_get_texture_height_internal(texture)
}

// Drawing commands wrapper functions
vk_begin_frame_wrapper :: proc(device: gfx_interface.Gfx_Device) {
    log.info("Beginning Vulkan frame")
    vk_begin_frame_internal(device)
}

vk_end_frame_wrapper :: proc(device: gfx_interface.Gfx_Device) {
    log.info("Ending Vulkan frame")
    vk_end_frame_internal(device)
}

vk_clear_screen_wrapper :: proc(device: gfx_interface.Gfx_Device, options: gfx_interface.Clear_Options) {
    log.infof("Clearing Vulkan screen: color=%v, depth=%v, stencil=%v", options.clear_color, options.clear_depth, options.clear_stencil)
    vk_clear_screen_internal(device, options)
}

vk_set_viewport_wrapper :: proc(device: gfx_interface.Gfx_Device, viewport: gfx_interface.Viewport) {
    log.infof("Setting Vulkan viewport: x=%f, y=%f, width=%f, height=%f", viewport.position.x, viewport.position.y, viewport.size.x, viewport.size.y)
    vk_set_viewport_internal(device, viewport)
}

vk_set_scissor_wrapper :: proc(device: gfx_interface.Gfx_Device, scissor: gfx_interface.Scissor) {
    log.infof("Setting Vulkan scissor: x=%d, y=%d, width=%d, height=%d", scissor.x, scissor.y, scissor.w, scissor.h)
    vk_set_scissor_internal(device, scissor)
}

vk_disable_scissor_wrapper :: proc(device: gfx_interface.Gfx_Device) {
    log.info("Disabling Vulkan scissor")
    vk_disable_scissor_internal(device)
}

vk_draw_wrapper :: proc(device: gfx_interface.Gfx_Device, vertex_count, instance_count, first_vertex, first_instance: u32) {
    log.infof("Vulkan draw: vertices=%d, instances=%d, first_vertex=%d, first_instance=%d", vertex_count, instance_count, first_vertex, first_instance)
    vk_draw_internal(device, vertex_count, instance_count, first_vertex, first_instance)
}

vk_draw_indexed_wrapper :: proc(device: gfx_interface.Gfx_Device, index_count, instance_count, first_index, base_vertex, first_instance: u32) {
    log.infof("Vulkan draw indexed: indices=%d, instances=%d, first_index=%d, base_vertex=%d, first_instance=%d", index_count, instance_count, first_index, base_vertex, first_instance)
    vk_draw_indexed_internal(device, index_count, instance_count, first_index, base_vertex, first_instance)
}

// Framebuffer management wrapper functions
vk_create_framebuffer_wrapper :: proc(device: gfx_interface.Gfx_Device, width, height: int, color_format: gfx_interface.Texture_Format, depth_format: gfx_interface.Texture_Format) -> (gfx_interface.Gfx_Framebuffer, common.Engine_Error) {
    log.infof("Creating Vulkan framebuffer: %dx%d, color_format=%v, depth_format=%v", width, height, color_format, depth_format)
    return vk_create_framebuffer_internal(device, width, height, color_format, depth_format)
}

vk_destroy_framebuffer_wrapper :: proc(framebuffer: gfx_interface.Gfx_Framebuffer) {
    log.info("Destroying Vulkan framebuffer")
    vk_destroy_framebuffer_internal(framebuffer)
}

// Render pass management wrapper functions
vk_create_render_pass_wrapper :: proc(device: gfx_interface.Gfx_Device, framebuffer: gfx_interface.Gfx_Framebuffer, clear_color, clear_depth: bool) -> (gfx_interface.Gfx_Render_Pass, common.Engine_Error) {
    log.infof("Creating Vulkan render pass: clear_color=%v, clear_depth=%v", clear_color, clear_depth)
    return vk_create_render_pass_internal(device, framebuffer, clear_color, clear_depth)
}

vk_begin_render_pass_wrapper :: proc(device: gfx_interface.Gfx_Device, render_pass: gfx_interface.Gfx_Render_Pass, clear_color: math.Color, clear_depth: f32) {
    log.infof("Beginning Vulkan render pass: clear_color=(%v), clear_depth=%f", clear_color, clear_depth)
    vk_begin_render_pass_internal(device, render_pass, clear_color, clear_depth)
}

vk_end_render_pass_wrapper :: proc(device: gfx_interface.Gfx_Device, render_pass: gfx_interface.Gfx_Render_Pass) {
    log.info("Ending Vulkan render pass")
    vk_end_render_pass_internal(device, render_pass)
}

// State management wrapper functions
vk_set_blend_mode_wrapper :: proc(device: gfx_interface.Gfx_Device, blend_mode: gfx_interface.Blend_Mode) {
    log.infof("Setting Vulkan blend mode: %v", blend_mode)
    vk_set_blend_mode_internal(device, blend_mode)
}

vk_set_depth_test_wrapper :: proc(device: gfx_interface.Gfx_Device, enabled: bool, write: bool, func: gfx_interface.Depth_Func) {
    log.infof("Setting Vulkan depth test: enabled=%v, write=%v, func=%v", enabled, write, func)
    vk_set_depth_test_internal(device, enabled, write, func)
}

vk_set_cull_mode_wrapper :: proc(device: gfx_interface.Gfx_Device, cull_mode: gfx_interface.Cull_Mode) {
    log.infof("Setting Vulkan cull mode: %v", cull_mode)
    vk_set_cull_mode_internal(device, cull_mode)
}

// Uniform binding wrapper functions
vk_set_uniform_mat4_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: math.Matrix4) {
    log.infof("Setting Vulkan uniform mat4: %s", name)
    vk_set_uniform_mat4_internal(device, pipeline, name, value)
}

vk_set_uniform_vec2_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: math.Vector2) {
    log.infof("Setting Vulkan uniform vec2: %s = (%f, %f)", name, value.x, value.y)
    vk_set_uniform_vec2_internal(device, pipeline, name, value)
}

vk_set_uniform_vec3_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: math.Vector3) {
    log.infof("Setting Vulkan uniform vec3: %s = (%f, %f, %f)", name, value.x, value.y, value.z)
    vk_set_uniform_vec3_internal(device, pipeline, name, value)
}

vk_set_uniform_vec4_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: math.Vector4) {
    log.infof("Setting Vulkan uniform vec4: %s = (%f, %f, %f, %f)", name, value.x, value.y, value.z, value.w)
    vk_set_uniform_vec4_internal(device, pipeline, name, value)
}

vk_set_uniform_int_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: int) {
    log.infof("Setting Vulkan uniform int: %s = %d", name, value)
    vk_set_uniform_int_internal(device, pipeline, name, value)
}

vk_set_uniform_float_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: f32) {
    log.infof("Setting Vulkan uniform float: %s = %f", name, value)
    vk_set_uniform_float_internal(device, pipeline, name, value)
}

// Wrapper for getting an error string
vk_get_error_string_wrapper :: proc(error: common.Engine_Error) -> string {
    return common.engine_error_to_string(error)
}
