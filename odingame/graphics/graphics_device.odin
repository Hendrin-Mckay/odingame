package graphics

import "../types" // For Color
import "../gfx_interface" // For Gfx_Device, Gfx_Window, Backend_Type
// import "../math" // If Viewport is not in types or here

// --- Enums for Presentation ---

Surface_Format :: enum {
    Color,          // Default color format (e.g., RGBA8)
    BGR_Color,      // For BGR formats if needed specifically
    HDR10,          // Placeholder for HDR
    // Add more as needed
}

Depth_Format :: enum {
    None,
    Depth16,
    Depth24,
    Depth24_Stencil8, // Common combined format
    Depth32_Float,
    // Add more as needed
}

// --- Core Graphics Structs ---

// Viewport defines the 2D rectangle of the render target to draw to.
Viewport :: struct {
    x:          int,
    y:          int,
    width:      int,
    height:     int,
    min_depth:  f32, // Typically 0.0
    max_depth:  f32, // Typically 1.0
}

// Present_Parameters describes the characteristics of the presentation buffer.
Present_Parameters :: struct {
    back_buffer_width:  int,
    back_buffer_height: int,
    back_buffer_format: Surface_Format, 
    depth_stencil_format: Depth_Format, 
    is_full_screen:    bool,
    vsync:             bool,
    // multi_sample_count: int, // Future
}

// Graphics_Adapter represents a display adapter (GPU). Placeholder for now.
Graphics_Adapter :: struct {
    name: string,
    // device_id: uint,
    // vendor_id: uint,
    // Other details like memory, supported features, etc.
}

// Graphics_Device is the main interface for drawing and resource creation.
Graphics_Device :: struct {
    adapter:          ^Graphics_Adapter,    // The adapter this device was created on.
    present_params:   Present_Parameters,   // Parameters for the presentation buffer.
    viewport:         Viewport,             // Current viewport settings.

    // Low-level backend handles (owned by this Graphics_Device instance)
    _gfx_device:      gfx_interface.Gfx_Device, // From existing backend work
    _gfx_window:      gfx_interface.Gfx_Window, // From existing backend work
    _backend_type:    gfx_interface.Backend_Type,

    // TEMP: SDL_Window handle, will be removed once GDM manages window and Game_Window struct is fleshed out
    // This is needed for now so GDM can pass it to create the _gfx_window.
    _sdl_window:      rawptr, // For ^sdl2.Window handle
}


// --- Graphics_Device Helper Procedures ---

// graphics_device_clear clears the active render target(s) and/or depth/stencil buffer.
graphics_device_clear :: proc(dev: ^Graphics_Device, clear_color: types.Color, clear_depth: bool = true, clear_stencil: bool = false) {
    if dev == nil || dev._gfx_device.variant == nil {
        log.error("graphics_device_clear: Invalid Graphics_Device or backend device.")
        return
    }
    
    // Convert types.Color to [4]f32 for the backend
    // Backend clear function might take Clear_Options struct directly.
    // For now, this is a simplified clear.
    // The gfx_interface.clear_screen expects Clear_Options.
    options := Clear_Options {
        color       = {f32(clear_color.r)/255, f32(clear_color.g)/255, f32(clear_color.b)/255, f32(clear_color.a)/255},
        clear_color = true, // Assuming if color is passed, we want to clear it
        clear_depth = clear_depth,
        clear_stencil = clear_stencil,
        depth       = 1.0, // Default depth clear value
        stencil     = 0,   // Default stencil clear value
    }
    // The Gfx_Window is needed by clear_screen in some backends (like D3D11 to get RTV).
    // This highlights that Graphics_Device needs access to its Gfx_Window for such operations.
    gfx_api.clear_screen(dev._gfx_device, dev._gfx_window, options)
}

// graphics_device_present presents the back buffer to the screen.
graphics_device_present :: proc(dev: ^Graphics_Device) {
    if dev == nil || dev._gfx_window.variant == nil {
        log.error("graphics_device_present: Invalid Graphics_Device or backend window.")
        return
    }
    // gfx_api.end_frame often includes presentation.
    // Or, if Present is separate:
    gfx_api.present_window(dev._gfx_window)
    // If end_frame is needed for other reasons (e.g. command buffer submission before present):
    // gfx_api.end_frame(dev._gfx_device, dev._gfx_window) // This might be redundant if present_window implies end_frame.
}

// graphics_device_set_viewport sets the active viewport for rendering.
graphics_device_set_viewport :: proc(dev: ^Graphics_Device, viewport: Viewport) {
    if dev == nil || dev._gfx_device.variant == nil {
        log.error("graphics_device_set_viewport: Invalid Graphics_Device.")
        return
    }
    dev.viewport = viewport
    
    // Convert our Viewport to gfx_interface.Viewport if they differ, or use directly.
    // Assuming gfx_interface.Viewport is compatible or the same.
    // The gfx_api.set_viewport expects a Gfx_Viewport.
    // Let's assume they are compatible for now, or a direct cast/conversion is trivial.
    // The gfx_interface.Viewport is:
    // Viewport :: struct { x, y: f32, width, height: f32, min_depth, max_depth: f32 }
    // Our Viewport here is:
    // Viewport :: struct { x, y, width, height: int, min_depth, max_depth: f32 }
    // So, conversion is needed.
    
    api_viewport := gfx_interface.Viewport {
        x         = f32(viewport.x),
        y         = f32(viewport.y),
        width     = f32(viewport.width),
        height    = f32(viewport.height),
        min_depth = viewport.min_depth,
        max_depth = viewport.max_depth,
    }
    gfx_api.set_viewport(dev._gfx_device, api_viewport)
}

// graphics_device_destroy is an internal helper to release backend resources
// This might be called by GraphicsDeviceManager when the device is being recreated or disposed of.
_graphics_device_destroy_internal_handles :: proc(dev: ^Graphics_Device) {
    if dev == nil { return }
    log.debug("Destroying internal Graphics_Device handles...")
    if dev._gfx_window.variant != nil {
        gfx_api.destroy_window(dev._gfx_window)
        dev._gfx_window = {}
    }
    if dev._gfx_device.variant != nil {
        gfx_api.destroy_device(dev._gfx_device)
        dev._gfx_device = {}
    }
    // Do not destroy _sdl_window here, it's managed by GDM or Game for now.
    log.debug("Internal Graphics_Device handles destroyed.")
}
