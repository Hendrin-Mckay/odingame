package graphics

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"

import sdl "vendor:sdl2"
import gl "vendor:OpenGL/gl" 
// No longer need direct import of ../core here for Device/Window, that coupling will be removed.

// --- OpenGL Specific Structs ---

Gl_Device :: struct {
	// SDL doesn't have a global "device" concept separate from a window's GL context.
	// This struct will mostly be a placeholder or manage global GL state/capabilities if needed.
	// The actual GL context will be tied to Gl_Window.
	main_allocator: ^rawptr,
	// We need to track initialized subsystems to properly call SDL_QuitSubSystem / SDL_Quit
	video_initialized: bool, 
}

Gl_Window :: struct {
	sdl_window:     ^sdl.Window,
	gl_context:     sdl.GLContext,
	width:          int,
	height:         int,
	title:          string,
	device_ref:     Gfx_Device, // Reference back to the logical device
	main_allocator: ^rawptr,    // Allocator used for this struct
}

// --- Implementation of Gfx_Device_Interface for SDL/OpenGL ---

gl_create_device :: proc(allocator: ^rawptr) -> (Gfx_Device, Gfx_Error) {
	// Initialize SDL video subsystem if not already initialized.
	// In a multi-window scenario, this should only happen once.
	if !sdl.WasInit(sdl.INIT_VIDEO) {
		if sdl.InitSubSystem(sdl.INIT_VIDEO) != 0 {
			log.errorf("SDL_InitSubSystem(SDL_INIT_VIDEO) failed: %s", sdl.GetError())
			return Gfx_Device{}, .Initialization_Failed
		}
	}

	// Create the Gl_Device wrapper
	gl_device_ptr := new(Gl_Device, allocator^)
	gl_device_ptr.main_allocator = allocator
	gl_device_ptr.video_initialized = true // Mark that we initialized it (or it was already)

	log.info("Logical Gfx_Device (SDL/OpenGL) created.")
	return Gfx_Device{gl_device_ptr}, .None
}

gl_destroy_device :: proc(device: Gfx_Device) {
	if device_ptr, ok := device.variant.(^Gl_Device); ok {
		// SDL_GL_DeleteContext is called when destroying windows.
		// SDL_QuitSubSystem or SDL_Quit handles deinitialization.
		// If this device was responsible for SDL_InitSubSystem(SDL_INIT_VIDEO),
		// it should ideally call SDL_QuitSubSystem(SDL_INIT_VIDEO).
		// For simplicity now, SDL_Quit() will be called by the application layer when it's fully done.
		// This avoids issues if other parts of the app still use SDL.
		if device_ptr.video_initialized {
			// sdl.QuitSubSystem(sdl.INIT_VIDEO) // Be careful with this if other SDL systems are in use
			// log.info("SDL Video Subsystem quit.")
		}
		free(device_ptr, device_ptr.main_allocator^)
		log.info("Logical Gfx_Device (SDL/OpenGL) destroyed.")
	} else {
		log.errorf("gl_destroy_device: Invalid device type %v", device.variant)
	}
}

gl_create_window :: proc(device: Gfx_Device, title: string, width, height: int) -> (Gfx_Window, Gfx_Error) {
	device_ptr, ok_device := device.variant.(^Gl_Device)
	if !ok_device {
		log.error("gl_create_window: Invalid Gfx_Device type.")
		return Gfx_Window{}, .Invalid_Handle // Or Device_Creation_Failed
	}

	// Ensure SDL_GL attributes are set before creating window and context
	sdl.GL_SetAttribute(sdl.GLattr.CONTEXT_MAJOR_VERSION, 3)
	sdl.GL_SetAttribute(sdl.GLattr.CONTEXT_MINOR_VERSION, 3)
	sdl.GL_SetAttribute(sdl.GLattr.CONTEXT_PROFILE_MASK, cast(i32)sdl.GLprofile.CORE)
	sdl.GL_SetAttribute(sdl.GLattr.DOUBLEBUFFER, 1)
	// It's good practice to set depth/stencil size if you'll use them, e.g.:
	// sdl.GL_SetAttribute(sdl.GLattr.DEPTH_SIZE, 24)
	// sdl.GL_SetAttribute(sdl.GLattr.STENCIL_SIZE, 8)

	sdl_win_flags: sdl.WindowFlags = {.OPENGL, .SHOWN}
	// Add .RESIZABLE if needed, etc.

	sdl_win := sdl.CreateWindow(title, sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, width, height, sdl_win_flags)
	if sdl_win == nil {
		log.errorf("SDL_CreateWindow failed: %s", sdl.GetError())
		return Gfx_Window{}, .Window_Creation_Failed
	}

	gl_ctx := sdl.GL_CreateContext(sdl_win)
	if gl_ctx == nil {
		log.errorf("SDL_GL_CreateContext failed: %s", sdl.GetError())
		sdl.DestroyWindow(sdl_win)
		return Gfx_Window{}, .Device_Creation_Failed // Context creation is part of device setup
	}

	// Initialize OpenGL procedure loader for the current context
	if !gl.load_up_to(3, 3, sdl.GL_GetProcAddress) {
		log.errorf("Failed to load OpenGL functions: %s", sdl.GetError()) // Or gl.get_error_string() if available
		sdl.GL_DeleteContext(gl_ctx)
		sdl.DestroyWindow(sdl_win)
		return Gfx_Window{}, .Device_Creation_Failed
	}

	// Make context current for this window
	sdl.GL_MakeCurrent(sdl_win, gl_ctx)

	// Set vsync
	if sdl.GL_SetSwapInterval(1) != 0 { // 1 for VSync, 0 for no VSync
		log.warnf("Failed to set VSync: %s", sdl.GetError())
	}

	// Set initial GL states for this context
	drawable_w, drawable_h: i32
	sdl.GL_GetDrawableSize(sdl_win, &drawable_w, &drawable_h)
	gl.Viewport(0, 0, drawable_w, drawable_h)

	gl.Enable(gl.BLEND) // Common for 2D
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
	gl.Enable(gl.DEPTH_TEST) // Usually good to have, clear it if not needed per frame pass

	window_ptr := new(Gl_Window, device_ptr.main_allocator^)
	window_ptr.sdl_window = sdl_win
	window_ptr.gl_context = gl_ctx
	window_ptr.width = width
	window_ptr.height = height
	window_ptr.title = title
	window_ptr.device_ref = device
	window_ptr.main_allocator = device_ptr.main_allocator

	log.infof("Gfx_Window (SDL/OpenGL) '%s' (%dx%d) created.", title, width, height)
	return Gfx_Window{window_ptr}, .None
}

gl_destroy_window :: proc(window: Gfx_Window) {
	if window_ptr, ok := window.variant.(^Gl_Window); ok {
		if window_ptr.gl_context != nil {
			sdl.GL_DeleteContext(window_ptr.gl_context)
		}
		if window_ptr.sdl_window != nil {
			sdl.DestroyWindow(window_ptr.sdl_window)
		}
		free(window_ptr, window_ptr.main_allocator^)
		log.infof("Gfx_Window (SDL/OpenGL) '%s' destroyed.", window_ptr.title)
	} else {
		log.errorf("gl_destroy_window: Invalid window type %v", window.variant)
	}
}

gl_present_window :: proc(window: Gfx_Window) -> Gfx_Error {
	if window_ptr, ok := window.variant.(^Gl_Window); ok {
		if window_ptr.sdl_window != nil {
			sdl.GL_SwapWindow(window_ptr.sdl_window)
			return .None
		}
		log.error("gl_present_window: SDL window handle is nil.")
		return .Invalid_Handle
	}
	log.errorf("gl_present_window: Invalid window type %v", window.variant)
	return .Invalid_Handle
}

gl_resize_window :: proc(window: Gfx_Window, width, height: int) -> Gfx_Error {
	if window_ptr, ok := window.variant.(^Gl_Window); ok {
		if window_ptr.sdl_window != nil {
			// SDL doesn't have a direct "resize window and update viewport" function.
			// The window size is usually updated via events (e.g. SDL_WINDOWEVENT_RESIZED).
			// The application should handle that event and then call this to update its state
			// and the GL viewport.
			window_ptr.width = width
			window_ptr.height = height
			
			// Update viewport based on drawable size, which might differ for HighDPI
			drawable_w, drawable_h: i32
			sdl.GL_GetDrawableSize(window_ptr.sdl_window, &drawable_w, &drawable_h)
			
			// Ensure context is current before gl calls
			sdl.GL_MakeCurrent(window_ptr.sdl_window, window_ptr.gl_context)
			gl.Viewport(0, 0, drawable_w, drawable_h)
			
			log.infof("Gfx_Window '%s' logical size updated to %dx%d. Viewport set to %dx%d.", window_ptr.title, width, height, drawable_w, drawable_h)
			return .None
		}
		return .Invalid_Handle
	}
	return .Invalid_Handle
}

gl_get_window_size :: proc(window: Gfx_Window) -> (w, h: int) {
	if window_ptr, ok := window.variant.(^Gl_Window); ok {
		// This should return the logical window size, not necessarily the drawable/framebuffer size.
		// SDL_GetWindowSize does this.
		w, h : i32
		sdl.GetWindowSize(window_ptr.sdl_window, &w, &h)
		return int(w), int(h)

	}
	return 0, 0
}

gl_get_window_drawable_size :: proc(window: Gfx_Window) -> (w, h: int) {
	if window_ptr, ok := window.variant.(^Gl_Window); ok {
		if window_ptr.sdl_window != nil {
			drawable_w, drawable_h: i32
			sdl.GL_GetDrawableSize(window_ptr.sdl_window, &drawable_w, &drawable_h)
			return int(drawable_w), int(drawable_h)
		}
	}
	return 0, 0
}

gl_clear_screen :: proc(device: Gfx_Device, options: Clear_Options) {
	// In SDL/OpenGL, clearing is context-specific. The context should be current.
	// This function assumes the correct window's context is already current.
	// This is a simplification. A robust system might need to pass Gfx_Window.
	
	// device_ptr, ok_device := device.variant.(^Gl_Device)
	// if !ok_device {
	// 	log.error("gl_clear_screen: Invalid Gfx_Device type.")
	// 	return
	// }
	// No device specific state needed for clear, relies on current GL context.

	clear_mask: u32 = 0
	if options.clear_color {
		gl.ClearColor(options.color[0], options.color[1], options.color[2], options.color[3])
		clear_mask |= gl.COLOR_BUFFER_BIT
	}
	if options.clear_depth {
		gl.ClearDepthf(options.depth) // Odin's gl wrapper uses f32 for ClearDepthf
		clear_mask |= gl.DEPTH_BUFFER_BIT
	}
	if options.clear_stencil {
		gl.ClearStencil(i32(options.stencil))
		clear_mask |= gl.STENCIL_BUFFER_BIT
	}

	if clear_mask != 0 {
		// Ensure depth writes are enabled if clearing depth
		if options.clear_depth {
			gl.DepthMask(gl.TRUE) 
		}
		gl.Clear(clear_mask)
	}
}


// --- Dummy implementations for functions to be filled later ---

gl_create_shader_from_source :: proc(device: Gfx_Device, source: string, stage: Shader_Stage) -> (Gfx_Shader, Gfx_Error) {
	return Gfx_Shader{}, .Not_Implemented
}

gl_create_shader_from_bytecode :: proc(device: Gfx_Device, bytecode: []u8, stage: Shader_Stage) -> (Gfx_Shader, Gfx_Error) {
	return Gfx_Shader{}, .Not_Implemented
}

gl_destroy_shader :: proc(shader: Gfx_Shader) {
}

gl_create_pipeline :: proc(device: Gfx_Device, shaders: []Gfx_Shader /*, other state */) -> (Gfx_Pipeline, Gfx_Error) {
    return Gfx_Pipeline{}, .Not_Implemented
}

gl_destroy_pipeline :: proc(pipeline: Gfx_Pipeline) {
}

gl_create_buffer :: proc(device: Gfx_Device, type: Buffer_Type, size: int, data: rawptr = nil, is_dynamic: bool = false) -> (Gfx_Buffer, Gfx_Error) {
	return Gfx_Buffer{}, .Not_Implemented
}

gl_update_buffer :: proc(buffer: Gfx_Buffer, offset: int, data: rawptr, size: int) -> Gfx_Error {
	return .Not_Implemented
}

gl_destroy_buffer :: proc(buffer: Gfx_Buffer) {
}

gl_map_buffer :: proc(buffer: Gfx_Buffer, offset, size: int) -> rawptr {
    return nil
}

gl_unmap_buffer :: proc(buffer: Gfx_Buffer) {
}

gl_create_texture :: proc(device: Gfx_Device, width, height: int, format: Texture_Format, usage: Texture_Usage, data: rawptr = nil) -> (Gfx_Texture, Gfx_Error) {
	return Gfx_Texture{}, .Not_Implemented
}

gl_update_texture :: proc(texture: Gfx_Texture, x, y, width, height: int, data: rawptr) -> Gfx_Error {
	return .Not_Implemented
}

gl_destroy_texture :: proc(texture: Gfx_Texture) {
}

gl_begin_frame :: proc(device: Gfx_Device) {
    // For SDL/OpenGL, this might ensure the primary context is current, or other per-frame setup.
    // However, making context current is often done per window or before specific rendering sequences.
}

gl_end_frame :: proc(device: Gfx_Device) {
}

gl_set_viewport :: proc(device: Gfx_Device, viewport: Viewport) {
    // Assumes correct context is current
    gl.Viewport(i32(viewport.position.x), i32(viewport.position.y), i32(viewport.size.x), i32(viewport.size.y))
    gl.DepthRangef(viewport.depth_range[0], viewport.depth_range[1])
}

gl_set_scissor :: proc(device: Gfx_Device, scissor: Scissor) {
    // Assumes correct context is current
    gl.Scissor(scissor.x, scissor.y, scissor.w, scissor.h)
    // User must enable/disable gl.SCISSOR_TEST separately if needed.
}

gl_set_pipeline :: proc(device: Gfx_Device, pipeline: Gfx_Pipeline) {
}

gl_set_vertex_buffer :: proc(device: Gfx_Device, buffer: Gfx_Buffer, binding_index: u32 = 0, offset: u32 = 0) {
}

gl_set_index_buffer :: proc(device: Gfx_Device, buffer: Gfx_Buffer, offset: u32 = 0) {
}

gl_draw :: proc(device: Gfx_Device, vertex_count, instance_count, first_vertex, first_instance: u32) {
}

gl_draw_indexed :: proc(device: Gfx_Device, index_count, instance_count, first_index, base_vertex, first_instance: u32) {
}

gl_get_error_string :: proc(error: Gfx_Error) -> string {
    #partial switch error {
    case .None: return "No error"
    case .Initialization_Failed: return "Initialization failed"
    case .Device_Creation_Failed: return "Device creation failed"
    case .Window_Creation_Failed: return "Window creation failed"
    case .Shader_Compilation_Failed: return "Shader compilation failed"
    case .Buffer_Creation_Failed: return "Buffer creation failed"
    case .Texture_Creation_Failed: return "Texture creation failed"
    case .Invalid_Handle: return "Invalid handle"
    case .Not_Implemented: return "Not implemented"
    }
    return "Unknown Gfx_Error"
}

// Initialize the global gfx_api with OpenGL implementations
// This should be called by the application to select the SDL/OpenGL backend.
initialize_sdl_opengl_backend :: proc() {
	gfx_api = Gfx_Device_Interface {
		create_device              = gl_create_device,
		destroy_device             = gl_destroy_device,
		create_window              = gl_create_window,
		destroy_window             = gl_destroy_window,
		present_window             = gl_present_window,
		resize_window              = gl_resize_window,
		get_window_size            = gl_get_window_size,
		get_window_drawable_size   = gl_get_window_drawable_size,
		
		create_shader_from_source  = gl_create_shader_from_source_impl, // From shaders.odin
		create_shader_from_bytecode= gl_create_shader_from_bytecode_impl, // From shaders.odin
		destroy_shader             = gl_destroy_shader_impl,             // From shaders.odin
        create_pipeline            = gl_create_pipeline_impl,            // From shaders.odin
        destroy_pipeline           = gl_destroy_pipeline_impl,           // From shaders.odin
        set_pipeline               = gl_set_pipeline_impl,               // From shaders.odin


		create_buffer              = gl_create_buffer, // Placeholder
		update_buffer              = gl_update_buffer, // Placeholder
		destroy_buffer             = gl_destroy_buffer, // Placeholder
        map_buffer                 = gl_map_buffer,     // Placeholder
        unmap_buffer               = gl_unmap_buffer,   // Placeholder

		create_texture             = gl_create_texture_impl, // From texture.odin
		update_texture             = gl_update_texture_impl, // From texture.odin
		destroy_texture            = gl_destroy_texture_impl, // From texture.odin

		begin_frame                = gl_begin_frame,
		end_frame                  = gl_end_frame,
		clear_screen               = gl_clear_screen,
        set_viewport               = gl_set_viewport,
        set_scissor                = gl_set_scissor,

		set_uniform_mat4           = gl_set_uniform_mat4_impl,   // From shaders.odin
		set_uniform_vec2           = gl_set_uniform_vec2_impl,   // From shaders.odin
		set_uniform_vec3           = gl_set_uniform_vec3_impl,   // From shaders.odin
		set_uniform_vec4           = gl_set_uniform_vec4_impl,   // From shaders.odin
		set_uniform_int            = gl_set_uniform_int_impl,    // From shaders.odin
		set_uniform_float          = gl_set_uniform_float_impl,  // From shaders.odin
		bind_texture_to_unit       = gl_bind_texture_to_unit_impl, // From texture.odin

		create_buffer              = gl_create_buffer_impl,    // From buffer.odin
		update_buffer              = gl_update_buffer_impl,    // From buffer.odin
		destroy_buffer             = gl_destroy_buffer_impl,   // From buffer.odin
		map_buffer                 = gl_map_buffer_impl,       // From buffer.odin
		unmap_buffer               = gl_unmap_buffer_impl,     // From buffer.odin
		set_vertex_buffer          = gl_set_vertex_buffer_impl,// From buffer.odin
		set_index_buffer           = gl_set_index_buffer_impl, // From buffer.odin
		
		draw                       = gl_draw_device_impl,          // Implemented in device.odin
		draw_indexed               = gl_draw_indexed_device_impl,  // Implemented in device.odin

		create_vertex_array      = gl_create_vertex_array_impl, // From vao.odin
		destroy_vertex_array     = gl_destroy_vertex_array_impl,// From vao.odin
		bind_vertex_array        = gl_bind_vertex_array_impl,   // From vao.odin

		get_texture_width        = gl_get_texture_width_impl,  // From texture.odin
		get_texture_height       = gl_get_texture_height_impl, // From texture.odin

        get_error_string           = gl_get_error_string,
	}
	log.info("SDL/OpenGL backend initialized and assigned to gfx_api with VAO, buffer, shader, pipeline, texture, uniform, and texture utility functions.")
}

// The old API from this file that needs to be removed or adapted:
// Color :: struct { r, g, b, a: u8 }
// WHITE :: Color{255, 255, 255, 255}
// BLACK :: Color{0, 0, 0, 255}
// CORNFLOWER_BLUE :: Color{100, 149, 237, 255}
// Device :: struct { sdl_gl_context: sdl2.GLContext }
// new_device :: proc(win: ^core.Window) -> (^Device, error)
// clear :: proc(dev: ^Device, color: Color)
// present :: proc(dev: ^Device, win: ^core.Window)
// destroy_device :: proc(dev: ^Device)

// These will be replaced by calls to gfx_api.clear_screen, gfx_api.present_window, etc.
// The `Color` struct might be moved to a more general utility package or kept if it's widely used.
// For now, `Clear_Options` in `gfx_interface.odin` uses `[4]f32`.

// --- Drawing Function Implementations ---

// TODO: Primitive_Topology should be part of Gfx_Pipeline state.
// For now, assuming gl.TRIANGLES.
gl_draw_device_impl :: proc(device: Gfx_Device, vertex_count, instance_count, first_vertex, first_instance: u32) {
    // Assumes pipeline, VBOs (+attributes) are set.
    // device_ptr, ok_device := device.variant.(^Gl_Device)
    // if !ok_device { log.error("gl_draw: Invalid Gfx_Device."); return }

    // This is a simplified implementation. A full one would query primitive topology from bound pipeline.
    primitive_mode := gl.TRIANGLES // Placeholder

    if instance_count == 1 && first_instance == 0 {
        gl.DrawArrays(primitive_mode, i32(first_vertex), i32(vertex_count))
    } else if instance_count > 1 {
        // Make sure first_instance is handled if your GL version supports base instance drawing.
        // glDrawArraysInstancedBaseInstance might be needed, or adjust shader logic.
        // For now, assuming first_instance is 0 for instanced drawing or handled by shader.
        gl.DrawArraysInstanced(primitive_mode, i32(first_vertex), i32(vertex_count), i32(instance_count))
    } else {
        // Potentially log warning for invalid instance parameters
        gl.DrawArrays(primitive_mode, i32(first_vertex), i32(vertex_count))
    }
}

// TODO: Primitive_Topology and Index_Type (u16/u32) should be part of Gfx_Pipeline/Gfx_Buffer state.
// For now, assuming gl.TRIANGLES and gl.UNSIGNED_SHORT for indices (as used by SpriteBatch).
gl_draw_indexed_device_impl :: proc(device: Gfx_Device, index_count, instance_count, first_index, base_vertex, first_instance: u32) {
    // Assumes pipeline, VBOs (+attributes), IBO are set.
    // device_ptr, ok_device := device.variant.(^Gl_Device)
    // if !ok_device { log.error("gl_draw_indexed: Invalid Gfx_Device."); return }

    primitive_mode := gl.TRIANGLES // Placeholder
    index_type := gl.UNSIGNED_SHORT // Placeholder, common for sprite batches
    index_size_in_bytes := size_of(u16) // Placeholder, should match index_type

    // Calculate offset in bytes for first_index
    byte_offset_for_first_index := uintptr(first_index * cast(u32)index_size_in_bytes)

    if instance_count == 1 && first_instance == 0 {
        if base_vertex == 0 {
            gl.DrawElements(primitive_mode, i32(index_count), index_type, unsafe.Pointer(byte_offset_for_first_index))
        } else {
            // Ensure GL version supports glDrawElementsBaseVertex or simulate if necessary
            // (Often available in GL 3.2+ or via ARB_draw_elements_base_vertex)
             gl.DrawElementsBaseVertex(primitive_mode, i32(index_count), index_type, unsafe.Pointer(byte_offset_for_first_index), i32(base_vertex))
        }
    } else if instance_count > 1 {
        // Ensure GL version supports instanced base vertex drawing or simulate
        // glDrawElementsInstancedBaseVertexBaseInstance might be needed.
        // For now, assuming first_instance is 0 for instanced or handled by shader.
        if base_vertex == 0 {
             gl.DrawElementsInstanced(primitive_mode, i32(index_count), index_type, unsafe.Pointer(byte_offset_for_first_index), i32(instance_count))
        } else {
             gl.DrawElementsInstancedBaseVertex(primitive_mode, i32(index_count), index_type, unsafe.Pointer(byte_offset_for_first_index), i32(instance_count), i32(base_vertex))
        }
    } else {
         // Potentially log warning for invalid instance parameters
        if base_vertex == 0 {
            gl.DrawElements(primitive_mode, i32(index_count), index_type, unsafe.Pointer(byte_offset_for_first_index))
        } else {
             gl.DrawElementsBaseVertex(primitive_mode, i32(index_count), index_type, unsafe.Pointer(byte_offset_for_first_index), i32(base_vertex))
        }
    }
}
