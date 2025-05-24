package metal

// This file acts as the entry point for the Metal backend, providing the
// Gfx_Device_Interface implementation.

import "../gfx_interface"
import "../../common" 
import "../../math"  // For m.Color if interface uses it, or types.Color
import "core:log"
import "core:os" 

// Import the Metal implementation files.
// These define the `..._impl` procedures.
// Assumed to be in the same `metal` package.
// Procedures from mtl_device.odin, mtl_window.odin, mtl_frame.odin, mtl_draw.odin
// are directly accessible as they are in the same `metal` package.

// Placeholder for unimplemented functions
_metal_ni_err :: proc() -> common.Engine_Error { log.warn("Metal: Function not implemented."); return .Not_Implemented }
_metal_ni_void :: proc() { log.warn("Metal: Function not implemented (void).") }
_metal_ni_ptr :: proc() -> rawptr { log.warn("Metal: Function not implemented (ptr)."); return nil }
_metal_ni_bool :: proc() -> bool { log.warn("Metal: Function not implemented (bool)."); return false }
_metal_ni_int2 :: proc() -> (int, int) { log.warn("Metal: Function not implemented (int, int)."); return 0, 0 }
_metal_ni_string :: proc() -> string { log.warn("Metal: Function not implemented (string)."); return "Not Implemented" }
_metal_ni_gfx_shader :: proc(_: gfx_interface.Gfx_Device, _: string, _: gfx_interface.Shader_Stage, _: string = "") -> (gfx_interface.Gfx_Shader, common.Engine_Error) { log.warn("Metal: Shader creation not implemented."); return gfx_interface.Gfx_Shader{}, .Not_Implemented }
_metal_ni_gfx_shader_bc :: proc(_: gfx_interface.Gfx_Device, _: []u8, _: gfx_interface.Shader_Stage, _: string = "") -> (gfx_interface.Gfx_Shader, common.Engine_Error) { log.warn("Metal: Shader creation from bytecode not implemented."); return gfx_interface.Gfx_Shader{}, .Not_Implemented }
_metal_ni_gfx_pipeline :: proc(_: gfx_interface.Gfx_Device, _: ^gfx_interface.Gfx_Pipeline_Desc) -> (gfx_interface.Gfx_Pipeline, common.Engine_Error) { log.warn("Metal: Pipeline creation not implemented."); return gfx_interface.Gfx_Pipeline{}, .Not_Implemented }
_metal_ni_gfx_buffer :: proc(_: gfx_interface.Gfx_Device, _: gfx_interface.Buffer_Type, _: int, _: rawptr, _: bool, _: string = "") -> (gfx_interface.Gfx_Buffer, common.Engine_Error) { log.warn("Metal: Buffer creation not implemented."); return gfx_interface.Gfx_Buffer{}, .Not_Implemented }
_metal_ni_gfx_texture :: proc(_: gfx_interface.Gfx_Device, _, _: int, _: gfx_interface.Texture_Format, _: gfx_interface.Texture_Usage_Flags, _: rawptr, _: string = "") -> (gfx_interface.Gfx_Texture, common.Engine_Error) { log.warn("Metal: Texture creation not implemented."); return gfx_interface.Gfx_Texture{}, .Not_Implemented }
_metal_ni_gfx_framebuffer :: proc(_: gfx_interface.Gfx_Device, _,_: int, _: gfx_interface.Texture_Format, _: gfx_interface.Texture_Format) -> (gfx_interface.Gfx_Framebuffer, common.Engine_Error) { log.warn("Metal: Framebuffer creation not implemented."); return gfx_interface.Gfx_Framebuffer{}, .Not_Implemented }
_metal_ni_gfx_render_pass :: proc(_: gfx_interface.Gfx_Device, _: gfx_interface.Gfx_Framebuffer, _, _: bool) -> (gfx_interface.Gfx_Render_Pass, common.Engine_Error) { log.warn("Metal: Render Pass creation not implemented."); return gfx_interface.Gfx_Render_Pass{}, .Not_Implemented }
_metal_ni_gfx_vao :: proc(_: gfx_interface.Gfx_Device, _: []gfx_interface.Vertex_Buffer_Layout, _: []gfx_interface.Gfx_Buffer, _: gfx_interface.Gfx_Buffer) -> (gfx_interface.Gfx_Vertex_Array, common.Engine_Error) { log.warn("Metal: VAO creation not implemented."); return gfx_interface.Gfx_Vertex_Array{}, .Not_Supported }
_metal_ni_destroy_shader :: proc(_: gfx_interface.Gfx_Shader) -> common.Engine_Error { log.warn("Metal: destroy_shader not impl."); return .Not_Implemented }
_metal_ni_destroy_pipeline :: proc(_: gfx_interface.Gfx_Pipeline) -> common.Engine_Error { log.warn("Metal: destroy_pipeline not impl."); return .Not_Implemented }
_metal_ni_destroy_buffer :: proc(_: gfx_interface.Gfx_Buffer) -> common.Engine_Error { log.warn("Metal: destroy_buffer not impl."); return .Not_Implemented }
_metal_ni_destroy_texture :: proc(_: gfx_interface.Gfx_Texture) -> common.Engine_Error { log.warn("Metal: destroy_texture not impl."); return .Not_Implemented }


metal_get_device_interface :: proc() -> gfx_interface.Gfx_Device_Interface {
    if ODIN_OS != "darwin" {
        log.fatal("Metal backend can only be initialized on Darwin (macOS, iOS).")
    }
    log.info("Metal: Populating Gfx_Device_Interface for Metal backend.")

    return gfx_interface.Gfx_Device_Interface {
        create_device = create_device_impl,
        destroy_device = destroy_device_impl,

        create_window = create_window_impl, 
        destroy_window = destroy_window_impl,
        present_window = proc(window: gfx_interface.Gfx_Window) -> common.Engine_Error {
            // This is tricky for Metal as presentation is part of end_frame.
            // A robust solution would require the game loop to manage a frame context
            // that end_frame can use. If this is called independently, it's an issue.
            log.warn("Metal: present_window called directly. Presentation is part of end_frame. This call is likely a no-op or error for Metal.")
            // One option: If a global/per-window command buffer and drawable are stored from last frame, try to use them. Highly unsafe.
            return .Not_Supported // Or .None if we want to silently ignore.
        },
        resize_window = proc(window: gfx_interface.Gfx_Window, width, height: int) -> common.Engine_Error { return _metal_ni_err() },
        set_window_title = proc(window: gfx_interface.Gfx_Window, title: string) -> common.Engine_Error { return _metal_ni_err() }, // SDL handles this
        get_window_size = proc(window: gfx_interface.Gfx_Window) -> (width, height: int) { 
            // This should query the CAMetalLayer's drawableSize if available from window.variant
            wi := get_mtl_window_internal(window)
            if wi != nil { return wi.width, wi.height } // Return stored logical size
            return _metal_ni_int2() 
        },
        get_window_drawable_size = proc(window: gfx_interface.Gfx_Window) -> (width, height: int) {
            wi := get_mtl_window_internal(window)
            if wi != nil && wi.layer != nil {
                cg_size := objc.msg_send(CGSize, id(wi.layer), sel_drawableSize)
                return int(cg_size.width), int(cg_size.height)
            }
            return _metal_ni_int2()
        },
        
        begin_frame = begin_frame_impl,
        clear_screen = clear_screen_impl,
        begin_render_pass = begin_render_pass_impl,
        end_render_pass = end_render_pass_impl,
        draw = draw_impl,
        draw_indexed = proc(encoder_handle: rawptr, device: gfx_interface.Gfx_Device, index_count, instance_count: u32, first_index: u32, base_vertex: i32, first_instance: u32, index_buffer: gfx_interface.Gfx_Buffer, index_buffer_offset: u32, index_type_is_32bit: bool) {
            // The Gfx_Buffer.variant should hold the MTLBuffer_Handle for Metal.
            draw_indexed_impl(encoder_handle, device, index_count, instance_count, first_index, base_vertex, first_instance, index_buffer.variant, index_buffer_offset, index_type_is_32bit)
        },
        end_frame = end_frame_impl,

        set_viewport = proc(encoder_or_device_handle: rawptr, viewport: gfx_interface.Viewport) { _metal_ni_void() },
        set_scissor = proc(encoder_or_device_handle: rawptr, scissor: gfx_interface.Scissor) { _metal_ni_void() },
        disable_scissor = proc(encoder_or_device_handle: rawptr) { _metal_ni_void() },
        set_pipeline = proc(encoder_or_device_handle: rawptr, pipeline: gfx_interface.Gfx_Pipeline) { _metal_ni_void() },
        set_vertex_buffer = proc(encoder_or_device_handle: rawptr, buffer: gfx_interface.Gfx_Buffer, binding_index: u32 = 0, offset: u32 = 0) { _metal_ni_void() },
        set_index_buffer = proc(encoder_or_device_handle: rawptr, buffer: gfx_interface.Gfx_Buffer, offset: u32 = 0) { _metal_ni_void() },

        create_shader_from_source = _metal_ni_gfx_shader,
		create_shader_from_bytecode = _metal_ni_gfx_shader_bc,
		destroy_shader = _metal_ni_destroy_shader,

        create_pipeline = _metal_ni_gfx_pipeline,
        destroy_pipeline = _metal_ni_destroy_pipeline,

        create_buffer = _metal_ni_gfx_buffer,
		update_buffer = proc(d,b: gfx_interface.Gfx_Device, off,dsz:int,data:rawptr) -> common.Engine_Error { return _metal_ni_err() }, // Signature mismatch with interface fix
		destroy_buffer = _metal_ni_destroy_buffer,
        map_buffer = proc(d: gfx_interface.Gfx_Device, b: gfx_interface.Gfx_Buffer, acc: gfx_interface.Buffer_Map_Access) -> (rawptr, common.Engine_Error) { return _metal_ni_ptr(), .Not_Implemented},
        unmap_buffer = proc(d: gfx_interface.Gfx_Device, b: gfx_interface.Gfx_Buffer) -> common.Engine_Error { return _metal_ni_err() },

        create_texture = _metal_ni_gfx_texture,
		update_texture = proc(d: gfx_interface.Gfx_Device, t: gfx_interface.Gfx_Texture, x,y,w,h:int, data:rawptr, dp:int) -> common.Engine_Error { return _metal_ni_err() },
		destroy_texture = _metal_ni_destroy_texture,
		
        set_uniform_mat4 = proc(eod: rawptr, p: gfx_interface.Gfx_Pipeline, n: string, m: matrix[4,4]f32) -> common.Engine_Error {return _metal_ni_err()},
		set_uniform_vec2 = proc(eod: rawptr, p: gfx_interface.Gfx_Pipeline, n: string, v: [2]f32) -> common.Engine_Error {return _metal_ni_err()},
		set_uniform_vec3 = proc(eod: rawptr, p: gfx_interface.Gfx_Pipeline, n: string, v: [3]f32) -> common.Engine_Error {return _metal_ni_err()},
		set_uniform_vec4 = proc(eod: rawptr, p: gfx_interface.Gfx_Pipeline, n: string, v: [4]f32) -> common.Engine_Error {return _metal_ni_err()},
		set_uniform_int = proc(eod: rawptr, p: gfx_interface.Gfx_Pipeline, n: string, val: i32) -> common.Engine_Error {return _metal_ni_err()},
		set_uniform_float = proc(eod: rawptr, p: gfx_interface.Gfx_Pipeline, n: string, val: f32) -> common.Engine_Error {return _metal_ni_err()},
        bind_texture_to_unit = proc(eod: rawptr, t: gfx_interface.Gfx_Texture, u: u32, st: gfx_interface.Shader_Stage) -> common.Engine_Error { return _metal_ni_err() },

        create_vertex_array = _metal_ni_gfx_vao,
		destroy_vertex_array = proc(vao: gfx_interface.Gfx_Vertex_Array) { _metal_ni_void() },
		bind_vertex_array = proc(d: gfx_interface.Gfx_Device, vao: gfx_interface.Gfx_Vertex_Array) { _metal_ni_void() },

        get_texture_width  = proc(t: gfx_interface.Gfx_Texture) -> int { return _metal_ni_int2().$0 },
	    get_texture_height = proc(t: gfx_interface.Gfx_Texture) -> int { return _metal_ni_int2().$1 },
        
        query_backend_type = proc(d: gfx_interface.Gfx_Device) -> gfx_interface.Backend_Type { return .Metal },
        get_error_string = proc(e: common.Engine_Error) -> string { return common.engine_error_to_string(e) },
	}
}
