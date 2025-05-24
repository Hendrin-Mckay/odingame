package graphics

// engine_types provides Color, etc.
import engine_types "../types" 
// graphics_types provides Surface_Format, Depth_Format, Viewport, Present_Parameters, Clear_Options, Backend_Type, Gfx_Frame_Context_Info
import graphics_types "./types" 
// gfx_interface provides Gfx_Device, Gfx_Window, and the global gfx_api
import gfx_interface "./gfx_interface" 
import "core:log"


// --- Enums for Presentation ---
// Surface_Format, Depth_Format are now in graphics_types


// --- Core Graphics Structs ---
// Viewport, Present_Parameters are now in graphics_types

// Graphics_Adapter represents a display adapter (GPU). Placeholder for now.
Graphics_Adapter :: struct {
    name: string,
    // device_id: uint,
    // vendor_id: uint,
    // Other details like memory, supported features, etc.
}

// Graphics_Device is the main interface for drawing and resource creation.
Graphics_Device :: struct {
    adapter:          ^Graphics_Adapter,    
    present_params:   graphics_types.Present_Parameters,   // Use qualified type
    viewport:         graphics_types.Viewport,             // Use qualified type

    // Low-level backend handles (owned by this Graphics_Device instance)
    _gfx_device:      gfx_interface.Gfx_Device, 
    _gfx_window:      gfx_interface.Gfx_Window, 
    _backend_type:    graphics_types.Backend_Type, // Use qualified type

    _sdl_window:      rawptr, 
}


// --- Graphics_Device Helper Procedures ---

// graphics_device_clear clears the active render target(s) and/or depth/stencil buffer.
graphics_device_clear :: proc(dev: ^Graphics_Device, clear_color: engine_types.Color, clear_depth: bool = true, clear_stencil: bool = false) {
    if dev == nil || dev._gfx_device.variant == nil {
        log.error("graphics_device_clear: Invalid Graphics_Device or backend device.")
        return
    }
    
    options := graphics_types.Clear_Options {
        color       = {f32(clear_color.r)/255, f32(clear_color.g)/255, f32(clear_color.b)/255, f32(clear_color.a)/255},
        clear_color = true, 
        clear_depth = clear_depth,
        clear_stencil = clear_stencil,
        depth_value    = 1.0, 
        stencil_value  = 0,   
    }
    // The clear_screen API call now expects frame_ctx as the second argument.
    // For a direct clear like this, not tied to a specific frame's context from begin_frame,
    // passing nil might be acceptable if the backend handles it (e.g. for GL).
    // A proper solution might involve this function taking frame_ctx or it being retrieved from dev.
    // For now, passing nil as a placeholder.
    frame_ctx_placeholder: ^graphics_types.Gfx_Frame_Context_Info = nil
    gfx_interface.gfx_api.drawing_commands.clear_screen(dev._gfx_device, frame_ctx_placeholder, options)
}

// graphics_device_present presents the back buffer to the screen.
graphics_device_present :: proc(dev: ^Graphics_Device) {
    if dev == nil || dev._gfx_window.variant == nil {
        log.error("graphics_device_present: Invalid Graphics_Device or backend window.")
        return
    }
    // Assuming present_window is the correct API call now.
    // The old end_frame might be separate if needed for other synchronization.
    gfx_interface.gfx_api.window_management.present_window(dev._gfx_window)
}

// graphics_device_set_viewport sets the active viewport for rendering.
graphics_device_set_viewport :: proc(dev: ^Graphics_Device, viewport: graphics_types.Viewport) { // Parameter uses qualified type
    if dev == nil || dev._gfx_device.variant == nil {
        log.error("graphics_device_set_viewport: Invalid Graphics_Device.")
        return
    }
    dev.viewport = viewport // Store the qualified type
    
    // The gfx_api.state_setting.set_viewport expects graphics_types.Viewport.
    // No conversion needed if both `dev.viewport` and the parameter are already graphics_types.Viewport.
    // The Viewport struct in graphics_types (from common_types) is {x,y,width,height: i32}.
    // The set_viewport function in gl_device.odin (OpenGL backend) expects this.
    // The old Viewport in this file had min_depth/max_depth, which are not in the common_types.Viewport.
    // Depth range is typically set separately if needed (e.g. glDepthRangef).
    // The current graphics_types.Viewport does not include depth fields.
    
    // encoder_or_device_handle is rawptr. For OpenGL, it's often the device handle or nil.
    // Assuming dev._gfx_device (which is Gfx_Device, a rawptr wrapper) is suitable here.
    // Or, for GL, it might be nil if state is global. This depends on backend impl.
    // For now, pass dev._gfx_device.variant (the raw backend device pointer).
    encoder_handle := dev._gfx_device.variant 
    gfx_interface.gfx_api.state_setting.set_viewport(encoder_handle, viewport)
}

// graphics_device_destroy is an internal helper to release backend resources
_graphics_device_destroy_internal_handles :: proc(dev: ^Graphics_Device) {
    if dev == nil { return }
    log.debug("Destroying internal Graphics_Device handles...")
    if dev._gfx_window.variant != nil {
        gfx_interface.gfx_api.window_management.destroy_window(dev._gfx_window) // Use decomposed API
        dev._gfx_window = {}
    }
    if dev._gfx_device.variant != nil {
        gfx_interface.gfx_api.device_management.destroy_device(dev._gfx_device) // Use decomposed API
        dev._gfx_device = {}
    }
    log.debug("Internal Graphics_Device handles destroyed.")
}
