package opengl

import "../gfx_interface"
import "../../common" // For standardized error handling
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import sdl "vendor:sdl2"
import gl "vendor:OpenGL/gl"

// --- OpenGL Specific Structs ---

Device :: struct {
    // SDL doesn't have a global "device" concept separate from a window's GL context.
    // This struct will mostly be a placeholder or manage global GL state/capabilities if needed.
    // The actual GL context will be tied to Window.
    main_allocator: ^rawptr,
    // We need to track initialized subsystems to properly call SDL_QuitSubSystem / SDL_Quit
    video_initialized: bool, 
}

Window :: struct {
    sdl_window:     ^sdl.Window,
    gl_context:     sdl.GLContext,
    width:          int,
    height:         int,
    title:          string,
    device_ref:     gfx_interface.Gfx_Device, // Reference back to the logical device
    main_allocator: ^rawptr,    // Allocator used for this struct
}

// --- Device Management ---

create_device :: proc(allocator: ^rawptr) -> (gfx_interface.Gfx_Device, common.Engine_Error) {
    // Initialize SDL video subsystem if not already initialized.
    // In a multi-window scenario, this should only happen once.
    if !sdl.WasInit(sdl.INIT_VIDEO) {
        if sdl.InitSubSystem(sdl.INIT_VIDEO) != 0 {
            log.errorf("SDL_InitSubSystem(SDL_INIT_VIDEO) failed: %s", sdl.GetError())
            return gfx_interface.Gfx_Device{}, common.Engine_Error.Graphics_Initialization_Failed
        }
    }

    // Create the Device wrapper
    device_ptr := new(Device, allocator^)
    device_ptr.main_allocator = allocator
    device_ptr.video_initialized = true // Mark that we initialized it (or it was already)


    log.info("Logical Gfx_Device (SDL/OpenGL) created.")
    return gfx_interface.Gfx_Device{device_ptr}, common.Engine_Error.None
}

destroy_device :: proc(device: gfx_interface.Gfx_Device) {
    if device_ptr, ok := device.variant.(^Device); ok {
        // SDL_GL_DeleteContext is called when destroying windows.
        // SDL_QuitSubSystem or SDL_Quit handles deinitialization.
        if device_ptr.video_initialized {
            // sdl.QuitSubSystem(sdl.INIT_VIDEO) // Be careful with this if other SDL systems are in use
            // log.info("SDL Video Subsystem quit.")
        }
        free(device_ptr, device_ptr.main_allocator^)
        log.info("Logical Gfx_Device (SDL/OpenGL) destroyed.")
    } else {
        log.errorf("destroy_device: Invalid device type %v", device.variant)
    }
}

// --- Window Management ---
create_window :: proc(device: gfx_interface.Gfx_Device, title: string, width, height: int) -> (gfx_interface.Gfx_Window, common.Engine_Error) {
    device_ptr, ok_device := device.variant.(^Device)
    if !ok_device {
        log.error("create_window: Invalid Gfx_Device type.")
        return gfx_interface.Gfx_Window{}, common.Engine_Error.Invalid_Handle
    }

    // Ensure SDL_GL attributes are set before creating window and context
    sdl.GL_SetAttribute(sdl.GLattr.CONTEXT_MAJOR_VERSION, 3)
    sdl.GL_SetAttribute(sdl.GLattr.CONTEXT_MINOR_VERSION, 3)
    sdl.GL_SetAttribute(sdl.GLattr.CONTEXT_PROFILE_MASK, cast(i32)sdl.GLprofile.CORE)
    sdl.GL_SetAttribute(sdl.GLattr.DOUBLEBUFFER, 1)

    sdl_win_flags: sdl.WindowFlags = {.OPENGL, .SHOWN}

    sdl_win := sdl.CreateWindow(title, sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, width, height, sdl_win_flags)
    if sdl_win == nil {
        log.errorf("SDL_CreateWindow failed: %s", sdl.GetError())
        return gfx_interface.Gfx_Window{}, common.Engine_Error.Window_Creation_Failed
    }

    gl_ctx := sdl.GL_CreateContext(sdl_win)
    if gl_ctx == nil {
        log.errorf("SDL_GL_CreateContext failed: %s", sdl.GetError())
        sdl.DestroyWindow(sdl_win)
        return gfx_interface.Gfx_Window{}, common.Engine_Error.Window_Creation_Failed
    }

    // Initialize OpenGL function pointers
    gl.load_up_to(3, 3, gl.set_proc_address)

    // Create the Window wrapper
    window_ptr := new(Window, device_ptr.main_allocator^)
    window_ptr.sdl_window = sdl_win
    window_ptr.gl_context = gl_ctx
    window_ptr.width = width
    window_ptr.height = height
    window_ptr.title = title
    window_ptr.device_ref = device
    window_ptr.main_allocator = device_ptr.main_allocator

    log.infof("Created OpenGL window: %s (%dx%d)", title, width, height)
    return gfx_interface.Gfx_Window{window_ptr}, .None
}

destroy_window :: proc(window: gfx_interface.Gfx_Window) {
    if window_ptr, ok := window.variant.(^Window); ok {
        if window_ptr.gl_context != nil {
            sdl.GL_DeleteContext(window_ptr.gl_context)
        }
        if window_ptr.sdl_window != nil {
            sdl.DestroyWindow(window_ptr.sdl_window)
        }
        free(window_ptr, window_ptr.main_allocator^)
        log.info("Destroyed OpenGL window")
    }
}

present_window :: proc(window: gfx_interface.Gfx_Window) -> gfx_interface.Gfx_Error {
    if window_ptr, ok := window.variant.(^Window); ok {
        sdl.GL_SwapWindow(window_ptr.sdl_window)
        return .None
    }
    return .Invalid_Handle
}

resize_window :: proc(window: gfx_interface.Gfx_Window, width, height: int) -> gfx_interface.Gfx_Error {
    if window_ptr, ok := window.variant.(^Window); ok {
        sdl.SetWindowSize(window_ptr.sdl_window, i32(width), i32(height))
        window_ptr.width = width
        window_ptr.height = height
        return .None
    }
    return .Invalid_Handle
}

get_window_size :: proc(window: gfx_interface.Gfx_Window) -> (w, h: int) {
    if window_ptr, ok := window.variant.(^Window); ok {
        var width, height: i32
        sdl.GetWindowSize(window_ptr.sdl_window, &width, &height)
        return int(width), int(height)
    }
    return 0, 0
}

get_window_drawable_size :: proc(window: gfx_interface.Gfx_Window) -> (w, h: int) {
    if window_ptr, ok := window.variant.(^Window); ok {
        var width, height: i32
        sdl.GL_GetDrawableSize(window_ptr.sdl_window, &width, &height)
        return int(width), int(height)
    }
    return 0, 0
}

// Set the window title
set_window_title :: proc(window: gfx_interface.Gfx_Window, title: string) -> common.Engine_Error {
    if window_ptr, ok := window.variant.(^Window); ok {
        sdl.SetWindowTitle(window_ptr.sdl_window, cstring(raw_data(title)))
        return .None
    }
    return .Invalid_Handle
}

// --- Frame Management ---
begin_frame :: proc(device: gfx_interface.Gfx_Device) -> gfx_interface.Gfx_Error {
    // Clear the default framebuffer
    gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
    return .None
}

end_frame :: proc(device: gfx_interface.Gfx_Device) -> gfx_interface.Gfx_Error {
    // Flush any pending OpenGL commands
    gl.Flush()
    return .None
}

clear_screen :: proc(device: gfx_interface.Gfx_Device, options: gfx_interface.Clear_Options) -> gfx_interface.Gfx_Error {
    if options.clear_color {
        gl.ClearColor(
            options.color[0], 
            options.color[1], 
            options.color[2], 
            options.color[3]
        )
        gl.Clear(gl.COLOR_BUFFER_BIT)
    }
    
    if options.clear_depth {
        gl.ClearDepth(f64(options.depth))
        gl.Clear(gl.DEPTH_BUFFER_BIT)
    }
    
    if options.clear_stencil {
        gl.ClearStencil(i32(options.stencil))
        gl.Clear(gl.STENCIL_BUFFER_BIT)
    }
    
    return .None
}

set_viewport :: proc(device: gfx_interface.Gfx_Device, viewport: gfx_interface.Viewport) -> gfx_interface.Gfx_Error {
    gl.Viewport(
        i32(viewport.x), 
        i32(viewport.y), 
        i32(viewport.width), 
        i32(viewport.height)
    )
    gl.DepthRange(f64(viewport.min_depth), f64(viewport.max_depth))
    return .None
}

set_scissor :: proc(device: gfx_interface.Gfx_Device, scissor: gfx_interface.Scissor) -> gfx_interface.Gfx_Error {
    gl.Scissor(
        scissor.x, 
        scissor.y, 
        scissor.width, 
        scissor.height
    )
    return .None
}

// --- Error Handling ---
get_error_string_impl :: proc(error: gfx_interface.Gfx_Error) -> string {
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
