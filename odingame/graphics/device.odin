package graphics

// Import common engine types and error definitions
import "../common"
// Import graphics-specific types (enums, structs for pipeline descriptions, etc.)
import "./types" 
// Import the new composed API structure and its sub-interfaces
import "./api"
// Import math types if needed directly (e.g. matrix from core:math, or from a shared types package)
import "../../core/math" // For matrix[4,4]f32 etc.

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:runtime"
import "core:unsafe"

import sdl "vendor:sdl2"
import gl "vendor:OpenGL/gl"

// --- OpenGL Specific Structs ---
// These remain largely the same, as they are backend-specific implementation details.

Gl_Device :: struct {
	main_allocator: ^rawptr,
	video_initialized: bool, 
}

Gl_Window :: struct {
	sdl_window:     ^sdl.Window,
	gl_context:     sdl.GLContext,
	width:          int,
	height:         int,
	title:          string,
	device_ref:     Gfx_Device, 
	main_allocator: ^rawptr,
}

// --- Implementation of Gfx_Device_Interface parts for SDL/OpenGL ---
// Function signatures will be updated to use the new types from graphics.types

gl_create_device :: proc(allocator: ^rawptr) -> (Gfx_Device, common.Engine_Error) {
	if !sdl.WasInit(sdl.INIT_VIDEO) {
		if sdl.InitSubSystem(sdl.INIT_VIDEO) != 0 {
			log.errorf("SDL_InitSubSystem(SDL_INIT_VIDEO) failed: %s", sdl.GetError())
			return Gfx_Device{}, common.Engine_Error.Graphics_Initialization_Failed
		}
	}
	gl_device_ptr := new(Gl_Device, allocator^)
	gl_device_ptr.main_allocator = allocator
	gl_device_ptr.video_initialized = true
	log.info("Logical Gfx_Device (SDL/OpenGL) created.")
	return Gfx_Device{gl_device_ptr}, common.Engine_Error.None
}

gl_destroy_device :: proc(device: Gfx_Device) {
	if device_ptr, ok := device.variant.(^Gl_Device); ok {
		if device_ptr.video_initialized {
			// Consider SDL_QuitSubSystem(SDL_INIT_VIDEO) if appropriate for app lifecycle
		}
		free(device_ptr, device_ptr.main_allocator^)
		log.info("Logical Gfx_Device (SDL/OpenGL) destroyed.")
	} else {
		log.errorf("gl_destroy_device: Invalid device type %v", device.variant)
	}
}

gl_create_window :: proc(device: Gfx_Device, title: string, width, height: int, vsync: bool, sdl_window_rawptr: rawptr) -> (Gfx_Window, common.Engine_Error) {
	// sdl_window_rawptr is new, but for SDL backend, we create the window here.
	// This parameter might be more relevant for backends that attach to an existing window.
	// For SDL, we'll ignore sdl_window_rawptr and create a new one.
	_ = sdl_window_rawptr // Mark as used

	device_ptr, ok_device := device.variant.(^Gl_Device)
	if !ok_device {
		log.error("gl_create_window: Invalid Gfx_Device type.")
		return Gfx_Window{}, common.Engine_Error.Invalid_Handle
	}

	sdl.GL_SetAttribute(sdl.GLattr.CONTEXT_MAJOR_VERSION, 3)
	sdl.GL_SetAttribute(sdl.GLattr.CONTEXT_MINOR_VERSION, 3)
	sdl.GL_SetAttribute(sdl.GLattr.CONTEXT_PROFILE_MASK, cast(i32)sdl.GLprofile.CORE)
	sdl.GL_SetAttribute(sdl.GLattr.DOUBLEBUFFER, 1)
	// sdl.GL_SetAttribute(sdl.GLattr.DEPTH_SIZE, 24) // Optional: if depth buffer is always needed
	// sdl.GL_SetAttribute(sdl.GLattr.STENCIL_SIZE, 8) // Optional: if stencil buffer is always needed

	sdl_win_flags: sdl.WindowFlags = {.OPENGL, .SHOWN}
	// Add .RESIZABLE if needed by application

	sdl_win := sdl.CreateWindow(title, sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, width, height, sdl_win_flags)
	if sdl_win == nil {
		log.errorf("SDL_CreateWindow failed: %s", sdl.GetError())
		return Gfx_Window{}, common.Engine_Error.Window_Creation_Failed
	}

	gl_ctx := sdl.GL_CreateContext(sdl_win)
	if gl_ctx == nil {
		log.errorf("SDL_GL_CreateContext failed: %s", sdl.GetError())
		sdl.DestroyWindow(sdl_win)
		return Gfx_Window{}, common.Engine_Error.Device_Creation_Failed
	}

	if !gl.load_up_to(3, 3, sdl.GL_GetProcAddress) {
		log.errorf("Failed to load OpenGL functions: %s", gl.get_error_string())
		sdl.GL_DeleteContext(gl_ctx)
		sdl.DestroyWindow(sdl_win)
		return Gfx_Window{}, common.Engine_Error.Device_Creation_Failed
	}

	sdl.GL_MakeCurrent(sdl_win, gl_ctx)
	
	swap_interval := 0
	if vsync { swap_interval = 1 }
	if sdl.GL_SetSwapInterval(swap_interval) != 0 {
		log.warnf("Failed to set VSync (swap interval %d): %s", swap_interval, sdl.GetError())
	}

	drawable_w, drawable_h: i32
	sdl.GL_GetDrawableSize(sdl_win, &drawable_w, &drawable_h)
	gl.Viewport(0, 0, drawable_w, drawable_h)

	// Default GL states (can be overridden by pipeline)
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA) // Common alpha blending
	gl.Enable(gl.DEPTH_TEST)
	// gl.Enable(gl.CULL_FACE) // Optional: if backface culling is common
	
	window_ptr := new(Gl_Window, device_ptr.main_allocator^)
	window_ptr.sdl_window = sdl_win
	window_ptr.gl_context = gl_ctx
	window_ptr.width = width
	window_ptr.height = height
	window_ptr.title = title
	window_ptr.device_ref = device
	window_ptr.main_allocator = device_ptr.main_allocator

	log.infof("Gfx_Window (SDL/OpenGL) '%s' (%dx%d) created.", title, width, height)
	return Gfx_Window{window_ptr}, common.Engine_Error.None
}

gl_destroy_window :: proc(window: Gfx_Window) {
	if window_ptr, ok := window.variant.(^Gl_Window); ok {
		if window_ptr.gl_context != nil { sdl.GL_DeleteContext(window_ptr.gl_context) }
		if window_ptr.sdl_window != nil { sdl.DestroyWindow(window_ptr.sdl_window) }
		free(window_ptr, window_ptr.main_allocator^)
		log.infof("Gfx_Window (SDL/OpenGL) '%s' destroyed.", window_ptr.title)
	} else {
		log.errorf("gl_destroy_window: Invalid window type %v", window.variant)
	}
}

gl_present_window :: proc(window: Gfx_Window) -> common.Engine_Error {
	if window_ptr, ok := window.variant.(^Gl_Window); ok {
		if window_ptr.sdl_window != nil {
			sdl.GL_SwapWindow(window_ptr.sdl_window)
			return common.Engine_Error.None
		}
		log.error("gl_present_window: SDL window handle is nil.")
		return common.Engine_Error.Invalid_Handle
	}
	log.errorf("gl_present_window: Invalid window type %v", window.variant)
	return common.Engine_Error.Invalid_Handle
}

gl_resize_window :: proc(window: Gfx_Window, width, height: int) -> common.Engine_Error {
	if window_ptr, ok := window.variant.(^Gl_Window); ok {
		if window_ptr.sdl_window != nil {
			// Application is responsible for updating SDL window size via events.
			// This function updates internal tracking and GL viewport.
			window_ptr.width = width
			window_ptr.height = height
			
			drawable_w, drawable_h: i32
			sdl.GL_GetDrawableSize(window_ptr.sdl_window, &drawable_w, &drawable_h)
			
			sdl.GL_MakeCurrent(window_ptr.sdl_window, window_ptr.gl_context) // Ensure context is current
			gl.Viewport(0, 0, drawable_w, drawable_h)
			
			log.infof("Gfx_Window '%s' logical size %dx%d. Viewport %dx%d.", window_ptr.title, width, height, drawable_w, drawable_h)
			return common.Engine_Error.None
		}
		return common.Engine_Error.Invalid_Handle
	}
	return common.Engine_Error.Invalid_Handle
}

gl_set_window_title :: proc(window: Gfx_Window, title: string) -> common.Engine_Error {
    if window_ptr, ok := window.variant.(^Gl_Window); ok {
        if window_ptr.sdl_window != nil {
            sdl.SetWindowTitle(window_ptr.sdl_window, title)
            window_ptr.title = title // Update our stored title
            return common.Engine_Error.None
        }
        return common.Engine_Error.Invalid_Handle
    }
    return common.Engine_Error.Invalid_Handle
}


gl_get_window_size :: proc(window: Gfx_Window) -> (w, h: int) {
	if window_ptr, ok := window.variant.(^Gl_Window); ok {
		w_i32, h_i32 : i32
		sdl.GetWindowSize(window_ptr.sdl_window, &w_i32, &h_i32)
		return int(w_i32), int(h_i32)
	}
	return 0, 0
}

gl_get_window_drawable_size :: proc(window: Gfx_Window) -> (w, h: int) {
	if window_ptr, ok := window.variant.(^Gl_Window); ok {
		if window_ptr.sdl_window != nil {
			w_i32, h_i32: i32
			sdl.GL_GetDrawableSize(window_ptr.sdl_window, &w_i32, &h_i32)
			return int(w_i32), int(h_i32)
		}
	}
	return 0, 0
}

// Frame lifecycle and drawing commands now use types.Gfx_Frame_Context_Info
// For OpenGL, Gfx_Frame_Context_Info might not be strictly necessary for basic commands,
// but it's part of the interface for consistency with other backends (Metal, Vulkan).
// We can pass nil or an empty struct if no specific GL frame data is needed for a command.

gl_begin_frame :: proc(device: Gfx_Device, window: Gfx_Window) -> (common.Engine_Error, ^types.Gfx_Frame_Context_Info) {
    // For OpenGL, this might ensure the window's context is current.
    // The Gfx_Frame_Context_Info is less critical for OpenGL's global state model
    // compared to Metal/Vulkan, but we return an empty one for API consistency.
    // A more advanced GL backend might populate it if, e.g., per-frame UBOs were managed.
    if window_ptr, ok := window.variant.(^Gl_Window); ok {
        sdl.GL_MakeCurrent(window_ptr.sdl_window, window_ptr.gl_context)
        // Allocate a dummy context info if needed, or return nil if allowed by interface contract
        // For now, let's assume it's okay to return nil if not used, or a static empty one.
        // To be safe, let's allocate a minimal one if the interface expects a non-nil ptr.
        // However, the current Gfx_Frame_Context_Info is empty for GL.
        // So returning nil should be fine if the caller handles it.
        // Let's return a pointer to a static empty struct to be safe.
        // static_empty_info: types.Gfx_Frame_Context_Info // This would need careful handling in concurrent scenarios
        // For now, assume the interface allows nil if not used by backend, or it's heap allocated by caller.
        // The interface in drawing_commands.odin shows it returns ^types.Gfx_Frame_Context_Info.
        // So, we should provide one.
        // device_ptr, _ := device.variant.(^Gl_Device)
        // frame_info := new(types.Gfx_Frame_Context_Info, device_ptr.main_allocator^)
        // // Populate with SDL window dimensions for convenience, though not strictly GL frame context
        // frame_info.width = window_ptr.width
        // frame_info.height = window_ptr.height
        // drawable_w, drawable_h := gl_get_window_drawable_size(window)
        // frame_info.drawable_width = drawable_w
        // frame_info.drawable_height = drawable_h
        // frame_info.dpi_scale = f32(drawable_w) / f32(window_ptr.width) // Example DPI scale
        // return common.Engine_Error.None, frame_info 
        // Simpler: if Gfx_Frame_Context_Info is truly not used by GL for drawing, return nil or a global empty.
        // The definition in common_types.odin does have fields. So we should populate them.
        device_ptr, ok_device := device.variant.(^Gl_Device)
        if !ok_device { return common.Engine_Error.Invalid_Handle, nil }

        frame_info := new(types.Gfx_Frame_Context_Info, device_ptr.main_allocator^)
        frame_info.width = window_ptr.width
        frame_info.height = window_ptr.height
        drawable_w, drawable_h := gl_get_window_drawable_size(window)
        frame_info.drawable_width = drawable_w
        frame_info.drawable_height = drawable_h
        if window_ptr.width > 0 { // Avoid division by zero
            frame_info.dpi_scale = f32(drawable_w) / f32(window_ptr.width)
        } else {
            frame_info.dpi_scale = 1.0
        }
        return common.Engine_Error.None, frame_info

    }
    return common.Engine_Error.Invalid_Handle, nil
}

gl_clear_screen :: proc(device: Gfx_Device, frame_ctx: ^types.Gfx_Frame_Context_Info, options: types.Clear_Options) {
    // frame_ctx is not used by GL for this, but present for API consistency.
    _ = device, frame_ctx 
	clear_mask: u32 = 0
	if options.clear_color {
		gl.ClearColor(options.color[0], options.color[1], options.color[2], options.color[3])
		clear_mask |= gl.COLOR_BUFFER_BIT
	}
	if options.clear_depth {
		gl.ClearDepthf(options.depth_value) // Updated field name
		clear_mask |= gl.DEPTH_BUFFER_BIT
	}
	if options.clear_stencil {
		gl.ClearStencil(i32(options.stencil_value)) // Updated field name
		clear_mask |= gl.STENCIL_BUFFER_BIT
	}

	if clear_mask != 0 {
		if options.clear_depth { gl.DepthMask(gl.TRUE) }
		gl.Clear(clear_mask)
	}
}

gl_begin_render_pass :: proc(device: Gfx_Device, frame_ctx: ^types.Gfx_Frame_Context_Info) -> rawptr {
    // For OpenGL, a "render pass" is less explicit than Vulkan/Metal.
    // This might set up FBOs if frame_ctx indicated an offscreen pass.
    // For the main pass, it might just ensure context is current.
    // The rawptr returned could be the FBO handle or nil for default framebuffer.
    _ = device, frame_ctx
    // TODO: Implement FBO binding if applicable based on frame_ctx or a pass descriptor.
    // For now, assume default framebuffer, return nil as no specific GL object represents the "pass encoder".
    return nil 
}

gl_end_render_pass :: proc(encoder_handle: rawptr) {
    // If encoder_handle was an FBO, this might unbind it.
    _ = encoder_handle
    // TODO: Implement FBO unbinding if applicable.
}


gl_end_frame :: proc(device: Gfx_Device, window: Gfx_Window, frame_ctx: ^types.Gfx_Frame_Context_Info) {
    // For OpenGL, this is primarily where swap buffers happens (done by present_window).
    // Any per-frame resources in frame_ctx could be cleaned up here.
    _ = device, window // window is used by present_window, which is usually called after this
    if frame_ctx != nil {
        // If frame_info was allocated by gl_begin_frame, free it.
        // This depends on memory ownership strategy. Let's assume begin_frame's allocation is temporary.
        // device_ptr, ok_device := device.variant.(^Gl_Device)
        // if ok_device {
        //     free(frame_ctx, device_ptr.main_allocator^)
        // } 
        // This assumes frame_ctx is always allocated by begin_frame.
        // A safer model might be for the caller of begin_frame to manage this memory,
        // or use a frame allocator. For now, let's assume begin_frame allocates and end_frame frees.
        // Find the allocator:
        if gl_device_variant, ok := device.variant.(^Gl_Device); ok {
            free(frame_ctx, gl_device_variant.main_allocator^)
        }
    }
}


// --- Implementations for Resource Creation/Management (stubs for now, point to real ones) ---
// These need to be updated to use types from `graphics.types`

gl_create_shader_from_source_impl :: proc(device: Gfx_Device, source: string, stage: types.Shader_Stage) -> (Gfx_Shader, common.Engine_Error) {
	// Actual implementation would be in opengl/gl_shader.odin or similar
	log.warn("gl_create_shader_from_source_impl: Not yet implemented.")
	return Gfx_Shader{}, common.Engine_Error.Not_Implemented
}

gl_create_shader_from_bytecode_impl :: proc(device: Gfx_Device, bytecode: []u8, stage: types.Shader_Stage) -> (Gfx_Shader, common.Engine_Error) {
	log.warn("gl_create_shader_from_bytecode_impl: Not yet implemented.")
	return Gfx_Shader{}, common.Engine_Error.Not_Implemented
}

gl_destroy_shader_impl :: proc(shader: Gfx_Shader) {
	log.warn("gl_destroy_shader_impl: Not yet implemented.")
}

gl_create_pipeline_impl :: proc(device: Gfx_Device, desc: types.Gfx_Pipeline_Desc) -> (Gfx_Pipeline, common.Engine_Error) {
    log.warn("gl_create_pipeline_impl: Not yet implemented.")
	return Gfx_Pipeline{}, common.Engine_Error.Not_Implemented
}

gl_destroy_pipeline_impl :: proc(pipeline: Gfx_Pipeline) {
	log.warn("gl_destroy_pipeline_impl: Not yet implemented.")
}

gl_create_buffer_impl :: proc(device: Gfx_Device, type: types.Buffer_Type, size: int, data: rawptr = nil, is_dynamic: bool = false) -> (Gfx_Buffer, common.Engine_Error) {
	log.warn("gl_create_buffer_impl: Not yet implemented.")
	return Gfx_Buffer{}, common.Engine_Error.Not_Implemented 
}

gl_update_buffer_impl :: proc(buffer: Gfx_Buffer, offset: int, data: rawptr, size: int) -> common.Engine_Error {
	log.warn("gl_update_buffer_impl: Not yet implemented.")
	return common.Engine_Error.Not_Implemented
}

gl_destroy_buffer_impl :: proc(buffer: Gfx_Buffer) {
	log.warn("gl_destroy_buffer_impl: Not yet implemented.")
}

gl_map_buffer_impl :: proc(buffer: Gfx_Buffer, offset, size: int) -> rawptr {
    log.warn("gl_map_buffer_impl: Not yet implemented.")
    return nil
}

gl_unmap_buffer_impl :: proc(buffer: Gfx_Buffer) {
	log.warn("gl_unmap_buffer_impl: Not yet implemented.")
}

gl_create_texture_impl :: proc(
    device: Gfx_Device, width: int, height: int, depth: int,
    format: types.Texture_Format, type: types.Texture_Type, usage: types.Texture_Usage_Flags, 
    mip_levels: int, array_length: int, data: rawptr = nil, 
    data_pitch: int = 0, data_slice_pitch: int = 0, label: string = "") -> (Gfx_Texture, common.Engine_Error) {
	log.warnf("gl_create_texture_impl (label: %s): Not yet implemented.", label)
	return Gfx_Texture{}, common.Engine_Error.Not_Implemented
}

gl_update_texture_impl :: proc(
    device: Gfx_Device, texture: Gfx_Texture, level: int,
    x: int, y: int, z: int, width: int, height: int, depth_dim: int,
    data: rawptr, data_pitch: int, data_slice_pitch: int) -> common.Engine_Error {
	log.warn("gl_update_texture_impl: Not yet implemented.")
	return common.Engine_Error.Not_Implemented
}

gl_destroy_texture_impl :: proc(texture: Gfx_Texture) -> common.Engine_Error { // Signature changed
	log.warn("gl_destroy_texture_impl: Not yet implemented.")
    return common.Engine_Error.Not_Implemented
}

gl_create_framebuffer_impl :: proc(device: Gfx_Device, width: int, height: int, color_format: types.Texture_Format, depth_format: types.Texture_Format) -> (Gfx_Framebuffer, common.Engine_Error) {
    log.warn("gl_create_framebuffer_impl: Not yet implemented.")
    return Gfx_Framebuffer{}, common.Engine_Error.Not_Implemented
}

gl_destroy_framebuffer_impl :: proc(framebuffer: Gfx_Framebuffer) {
    log.warn("gl_destroy_framebuffer_impl: Not yet implemented.")
}

gl_create_render_pass_impl :: proc(device: Gfx_Device, framebuffer: Gfx_Framebuffer, clear_color: bool, clear_depth: bool) -> (Gfx_Render_Pass, common.Engine_Error) {
    log.warn("gl_create_render_pass_impl: Not yet implemented.")
    return Gfx_Render_Pass{}, common.Engine_Error.Not_Implemented
}


// --- Implementations for State Setting ---
// encoder_or_device_handle is rawptr. For GL, it's often ignored as state is global or on current context/program.
// Some functions might take Gfx_Device if they need to access GL device wrapper state.

gl_set_viewport_impl :: proc(encoder_or_device_handle: rawptr, viewport_desc: types.Viewport) {
    _ = encoder_or_device_handle
    // types.Viewport in common_types.odin uses x,y,width,height: i32
    gl.Viewport(viewport_desc.x, viewport_desc.y, viewport_desc.width, viewport_desc.height)
    // Depth range is not part of types.Viewport struct, if needed, it should be added or handled separately.
    // gl.DepthRangef(viewport_desc.min_depth, viewport_desc.max_depth) // Assuming min_depth/max_depth fields
}

gl_set_scissor_impl :: proc(encoder_or_device_handle: rawptr, scissor_desc: types.Scissor) {
    _ = encoder_or_device_handle
    // types.Scissor is types.Recti, which has x,y,w,h
    gl.Scissor(scissor_desc.x, scissor_desc.y, scissor_desc.w, scissor_desc.h)
    // Note: gl.Enable(gl.SCISSOR_TEST) must be called separately, usually via pipeline state.
}

gl_disable_scissor_impl :: proc(encoder_or_device_handle: rawptr) {
    _ = encoder_or_device_handle
    gl.Disable(gl.SCISSOR_TEST)
}


gl_set_pipeline_impl :: proc(encoder_or_device_handle: rawptr, pipeline: Gfx_Pipeline) {
	log.warn("gl_set_pipeline_impl: Not yet implemented.")
}

gl_set_vertex_buffer_impl :: proc(encoder_or_device_handle: rawptr, buffer: Gfx_Buffer, binding_index: u32 = 0, offset: u32 = 0) {
	log.warn("gl_set_vertex_buffer_impl: Not yet implemented.")
}

gl_set_index_buffer_impl :: proc(encoder_or_device_handle: rawptr, buffer: Gfx_Buffer, offset: u32 = 0) {
	log.warn("gl_set_index_buffer_impl: Not yet implemented.")
}

gl_set_uniform_mat4_impl :: proc(encoder_or_device_handle: rawptr, pipeline: Gfx_Pipeline, name: string, mat: math.matrix[4,4]f32) -> common.Engine_Error {
    log.warnf("gl_set_uniform_mat4_impl (name: %s): Not yet implemented.", name)
    return common.Engine_Error.Not_Implemented
}
gl_set_uniform_vec2_impl :: proc(encoder_or_device_handle: rawptr, pipeline: Gfx_Pipeline, name: string, vec: [2]f32) -> common.Engine_Error {
    log.warnf("gl_set_uniform_vec2_impl (name: %s): Not yet implemented.", name)
    return common.Engine_Error.Not_Implemented
}
gl_set_uniform_vec3_impl :: proc(encoder_or_device_handle: rawptr, pipeline: Gfx_Pipeline, name: string, vec: [3]f32) -> common.Engine_Error {
    log.warnf("gl_set_uniform_vec3_impl (name: %s): Not yet implemented.", name)
    return common.Engine_Error.Not_Implemented
}
gl_set_uniform_vec4_impl :: proc(encoder_or_device_handle: rawptr, pipeline: Gfx_Pipeline, name: string, vec: [4]f32) -> common.Engine_Error {
    log.warnf("gl_set_uniform_vec4_impl (name: %s): Not yet implemented.", name)
    return common.Engine_Error.Not_Implemented
}
gl_set_uniform_int_impl :: proc(encoder_or_device_handle: rawptr, pipeline: Gfx_Pipeline, name: string, val: i32) -> common.Engine_Error {
    log.warnf("gl_set_uniform_int_impl (name: %s): Not yet implemented.", name)
    return common.Engine_Error.Not_Implemented
}
gl_set_uniform_float_impl :: proc(encoder_or_device_handle: rawptr, pipeline: Gfx_Pipeline, name: string, val: f32) -> common.Engine_Error {
    log.warnf("gl_set_uniform_float_impl (name: %s): Not yet implemented.", name)
    return common.Engine_Error.Not_Implemented
}

gl_bind_texture_to_unit_impl :: proc(encoder_or_device_handle: rawptr, texture: Gfx_Texture, unit: u32, stage: types.Shader_Stage) -> common.Engine_Error {
    log.warnf("gl_bind_texture_to_unit_impl (unit: %d, stage: %v): Not yet implemented.", unit, stage)
    return common.Engine_Error.Not_Implemented
}

gl_set_blend_mode_impl :: proc(device: Gfx_Device, blend_mode: types.Blend_Mode) {
    // This is a legacy way to set blend mode. Modern approach is via pipeline state.
    // For GL, this would change global state.
    _ = device
    // Based on types.Blend_Mode definition in common_types.odin
    // This is a simplified mapping. Full blend state is more complex (src/dst factors, ops).
    // This should ideally be part of pipeline state.
    switch blend_mode {
        case .None:
            gl.Disable(gl.BLEND)
        case .Alpha:
            gl.Enable(gl.BLEND)
            gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
        case .Additive:
            gl.Enable(gl.BLEND)
            gl.BlendFunc(gl.SRC_ALPHA, gl.ONE)
        case .Multiply: // Typically gl.DST_COLOR, gl.ZERO or gl.DST_COLOR, gl.SRC_COLOR depending on effect
            gl.Enable(gl.BLEND)
            gl.BlendFunc(gl.DST_COLOR, gl.ZERO) // Common multiply mode
        case .Premultiplied_Alpha:
            gl.Enable(gl.BLEND)
            gl.BlendFunc(gl.ONE, gl.ONE_MINUS_SRC_ALPHA)
    }
    log.warn("gl_set_blend_mode_impl: Used legacy blend mode setting.")
}

gl_set_depth_test_impl :: proc(device: Gfx_Device, enabled: bool, write: bool, func: types.Depth_Func) {
    // Legacy state setting. Should be part of pipeline.
    _ = device
    if enabled {
        gl.Enable(gl.DEPTH_TEST)
        gl.DepthMask(write) // gl.TRUE or gl.FALSE
        
        gl_depth_func: u32
        switch func {
            case .Always: gl_depth_func = gl.ALWAYS
            case .Never: gl_depth_func = gl.NEVER
            case .Less: gl_depth_func = gl.LESS
            case .Equal: gl_depth_func = gl.EQUAL
            case .Less_Equal: gl_depth_func = gl.LEQUAL
            case .Greater: gl_depth_func = gl.GREATER
            case .Greater_Equal: gl_depth_func = gl.GEQUAL
            case .Not_Equal: gl_depth_func = gl.NOTEQUAL
        }
        gl.DepthFunc(gl_depth_func)
    } else {
        gl.Disable(gl.DEPTH_TEST)
    }
    log.warn("gl_set_depth_test_impl: Used legacy depth test setting.")
}

gl_set_cull_mode_impl :: proc(device: Gfx_Device, cull_mode: types.Cull_Mode) {
    // Legacy state setting. Should be part of pipeline.
    _ = device
    switch cull_mode {
        case .None:
            gl.Disable(gl.CULL_FACE)
        case .Front:
            gl.Enable(gl.CULL_FACE)
            gl.CullFace(gl.FRONT)
        case .Back:
            gl.Enable(gl.CULL_FACE)
            gl.CullFace(gl.BACK)
    }
    log.warn("gl_set_cull_mode_impl: Used legacy cull mode setting.")
}

gl_create_vertex_array_impl :: proc(
    device: Gfx_Device, 
    vertex_buffer_layouts: []types.Vertex_Buffer_Layout, 
    vertex_buffers: []Gfx_Buffer,
    index_buffer: Gfx_Buffer,
) -> (Gfx_Vertex_Array, common.Engine_Error) {
    log.warn("gl_create_vertex_array_impl: Not yet implemented.")
    return Gfx_Vertex_Array{}, common.Engine_Error.Not_Implemented
}

gl_destroy_vertex_array_impl :: proc(vao: Gfx_Vertex_Array) {
    log.warn("gl_destroy_vertex_array_impl: Not yet implemented.")
}

gl_bind_vertex_array_impl :: proc(device: Gfx_Device, vao: Gfx_Vertex_Array) {
    // If vao.variant is nil or some special "unbind" value, unbind current VAO.
    // This depends on how Gfx_Vertex_Array{} (empty struct) is handled.
    // For GL, binding VAO 0 unbinds the current one.
    // The Gfx_Vertex_Array.vulkan field is a pointer, so it could be nil.
    // We need to define what an "empty" or "null" Gfx_Vertex_Array means.
    // For now, assume if vao.vulkan (as a stand-in for variant) is nil, it means unbind.
    // This is a placeholder logic. Gfx_Vertex_Array needs a proper way to represent "no VAO".
    
    // The Gfx_Vertex_Array is a struct_variant. We need to access its GL part.
    // Let's assume the real gl_vao.odin would define a Gl_Vertex_Array struct
    // and Gfx_Vertex_Array would have an `opengl: ^Gl_Vertex_Array` field.
    // For this refactoring, the exact structure of Gfx_Vertex_Array's variant is not fully defined yet.
    // So, this is a placeholder.
    
    // if vao.variant == nil { // This comparison depends on how struct_variant empty state is checked
    //    gl.BindVertexArray(0)
    // } else {
    //    if gl_vao_ptr, ok := vao.variant.(^Gl_Vertex_Array_INTERNAL_STRUCT); ok { // Replace with actual type
    //        gl.BindVertexArray(gl_vao_ptr.id)
    //    } else {
    //        log.errorf("gl_bind_vertex_array_impl: Invalid VAO type %v", vao.variant)
    //    }
    // }
    _ = device
    log.warnf("gl_bind_vertex_array_impl (vao: %v): Not fully implemented, needs concrete Gfx_Vertex_Array variant.", vao)
    // Placeholder:
    // gl.BindVertexArray(0) // Default to unbinding for safety until fully implemented
}


// --- Utility Function Implementations ---
gl_get_texture_width_impl :: proc(texture: Gfx_Texture) -> int {
    log.warn("gl_get_texture_width_impl: Not yet implemented.")
    return 0
}

gl_get_texture_height_impl :: proc(texture: Gfx_Texture) -> int {
    log.warn("gl_get_texture_height_impl: Not yet implemented.")
    return 0
}

gl_get_error_string :: proc(error: common.Engine_Error) -> string {
    // This can use a common helper if one exists, or map GL errors if `error` was a GL error code.
    // Since `error` is common.Engine_Error, this should just convert enum to string.
    return common.engine_error_to_string(error)
}


// Initialize the global gfx_api with OpenGL implementations
initialize_sdl_opengl_backend :: proc() {
	// Populate the Device_Management_Interface part
	gfx_api.device_management = api.Device_Management_Interface {
		create_device  = gl_create_device,
		destroy_device = gl_destroy_device,
	}

	// Populate the Window_Management_Interface part
	gfx_api.window_management = api.Window_Management_Interface {
		create_window          = gl_create_window,
		destroy_window         = gl_destroy_window,
		present_window         = gl_present_window,
		resize_window          = gl_resize_window,
        set_window_title       = gl_set_window_title,
		get_window_size        = gl_get_window_size,
		get_window_drawable_size = gl_get_window_drawable_size,
	}
	
	// Populate the Resource_Creation_Interface part
	// These should point to actual implementations (e.g., from gl_shader.odin, gl_buffer.odin)
	// For now, using the stubs defined in this file, which will log warnings.
	gfx_api.resource_creation = api.Resource_Creation_Interface {
		create_shader_from_source   = gl_create_shader_from_source_impl,
		create_shader_from_bytecode = gl_create_shader_from_bytecode_impl,
		create_pipeline             = gl_create_pipeline_impl,
		create_buffer               = gl_create_buffer_impl,
		create_texture              = gl_create_texture_impl,
        create_framebuffer          = gl_create_framebuffer_impl,
        create_render_pass          = gl_create_render_pass_impl,
        create_vertex_array         = gl_create_vertex_array_impl,
	}

	// Populate the Resource_Management_Interface part
	gfx_api.resource_management = api.Resource_Management_Interface {
		destroy_shader     = gl_destroy_shader_impl,
		destroy_pipeline   = gl_destroy_pipeline_impl,
		update_buffer      = gl_update_buffer_impl,
		destroy_buffer     = gl_destroy_buffer_impl,
        map_buffer         = gl_map_buffer_impl,
        unmap_buffer       = gl_unmap_buffer_impl,
		update_texture     = gl_update_texture_impl,
		destroy_texture    = gl_destroy_texture_impl, // Ensure this matches signature
        destroy_framebuffer= gl_destroy_framebuffer_impl,
        destroy_vertex_array= gl_destroy_vertex_array_impl,
	}

	// Populate the Drawing_Commands_Interface part
	gfx_api.drawing_commands = api.Drawing_Commands_Interface {
		begin_frame        = gl_begin_frame,
		clear_screen       = gl_clear_screen,
		begin_render_pass  = gl_begin_render_pass,
		end_render_pass    = gl_end_render_pass,
		draw               = gl_draw_impl,          // Renamed from gl_draw_device_impl
		draw_indexed       = gl_draw_indexed_impl,  // Renamed from gl_draw_indexed_device_impl
		end_frame          = gl_end_frame,
	}

	// Populate the State_Setting_Interface part
	gfx_api.state_setting = api.State_Setting_Interface {
		set_viewport         = gl_set_viewport_impl,
        set_scissor          = gl_set_scissor_impl,
        disable_scissor      = gl_disable_scissor_impl,
		set_pipeline         = gl_set_pipeline_impl,
		set_vertex_buffer    = gl_set_vertex_buffer_impl,
		set_index_buffer     = gl_set_index_buffer_impl,
		set_uniform_mat4     = gl_set_uniform_mat4_impl,
		set_uniform_vec2     = gl_set_uniform_vec2_impl,
		set_uniform_vec3     = gl_set_uniform_vec3_impl,
		set_uniform_vec4     = gl_set_uniform_vec4_impl,
		set_uniform_int      = gl_set_uniform_int_impl,
		set_uniform_float    = gl_set_uniform_float_impl,
		bind_texture_to_unit = gl_bind_texture_to_unit_impl,
        set_blend_mode       = gl_set_blend_mode_impl, // Legacy
        set_depth_test       = gl_set_depth_test_impl, // Legacy
        set_cull_mode        = gl_set_cull_mode_impl,  // Legacy
        bind_vertex_array    = gl_bind_vertex_array_impl,
	}

	// Populate the Utilities_Interface part
	gfx_api.utilities = api.Utilities_Interface {
		get_texture_width  = gl_get_texture_width_impl,
		get_texture_height = gl_get_texture_height_impl,
		get_error_string   = gl_get_error_string,
	}

	log.info("SDL/OpenGL backend initialized and assigned to decomposed gfx_api.")
}


// --- Drawing Function Implementations (Renamed for clarity) ---
// These now take encoder_handle (rawptr) as first parameter, per interface.
// For GL, encoder_handle is typically nil or ignored for global context drawing.

gl_draw_impl :: proc(encoder_handle: rawptr, device: Gfx_Device, vertex_count, instance_count, first_vertex, first_instance: u32) {
    _ = encoder_handle, device // Mark as used, device might be needed for context checks in future
    
    // This is a simplified implementation. A full one would query primitive topology from bound pipeline.
    primitive_mode := gl.TRIANGLES // Placeholder, should come from pipeline state

    if instance_count <= 1 && first_instance == 0 { // Simplified condition
        gl.DrawArrays(primitive_mode, i32(first_vertex), i32(vertex_count))
    } else if instance_count > 1 {
        // Ensure GL version supports glDrawArraysInstanced or glDrawArraysInstancedBaseInstance
        // For now, assuming first_instance is 0 for instanced drawing or handled by shader.
        // If first_instance is non-zero, glDrawArraysInstancedBaseInstance would be needed.
        gl.DrawArraysInstanced(primitive_mode, i32(first_vertex), i32(vertex_count), i32(instance_count))
    } else {
        // Fallback or log warning for unusual instance parameters
        gl.DrawArrays(primitive_mode, i32(first_vertex), i32(vertex_count))
    }
}

gl_draw_indexed_impl :: proc(encoder_handle: rawptr, device: Gfx_Device, index_count, instance_count, first_index, base_vertex, first_instance: u32) {
    _ = encoder_handle, device // Mark as used

    // Primitive topology, index type, and index size should come from pipeline/buffer state.
    primitive_mode := gl.TRIANGLES          // Placeholder
    index_type := gl.UNSIGNED_SHORT       // Placeholder (e.g. u16)
    index_size_in_bytes := size_of(u16)   // Placeholder

    byte_offset_for_first_index := uintptr(first_index * cast(u32)index_size_in_bytes)

    // This logic can be quite complex depending on what GL features are assumed (BaseVertex, BaseInstance)
    // Simplified logic:
    if instance_count <= 1 && first_instance == 0 {
        if base_vertex == 0 {
            gl.DrawElements(primitive_mode, i32(index_count), index_type, unsafe.Pointer(byte_offset_for_first_index))
        } else {
             gl.DrawElementsBaseVertex(primitive_mode, i32(index_count), index_type, unsafe.Pointer(byte_offset_for_first_index), i32(base_vertex))
        }
    } else if instance_count > 1 {
        if base_vertex == 0 {
             gl.DrawElementsInstanced(primitive_mode, i32(index_count), index_type, unsafe.Pointer(byte_offset_for_first_index), i32(instance_count))
        } else {
             // Assumes GL_ARB_draw_elements_base_vertex and GL_ARB_instanced_arrays (or core versions)
             gl.DrawElementsInstancedBaseVertex(primitive_mode, i32(index_count), index_type, unsafe.Pointer(byte_offset_for_first_index), i32(instance_count), i32(base_vertex))
             // If first_instance is also needed: glDrawElementsInstancedBaseVertexBaseInstance
        }
    } else {
        // Fallback or log warning
        if base_vertex == 0 {
            gl.DrawElements(primitive_mode, i32(index_count), index_type, unsafe.Pointer(byte_offset_for_first_index))
        } else {
             gl.DrawElementsBaseVertex(primitive_mode, i32(index_count), index_type, unsafe.Pointer(byte_offset_for_first_index), i32(base_vertex))
        }
    }
}
