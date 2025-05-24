package graphics

import "../common"
import "core:log"
// Gfx_Device, Gfx_Window are defined within the graphics package (e.g. in types/common_types.odin or gfx_interface.odin)
// gfx_api is the global dispatch table, assumed to be initialized and available.

Game_Window :: struct {
    gfx_device: Gfx_Device, // Refers to graphics.Gfx_Device
    gfx_window: Gfx_Window, // Refers to graphics.Gfx_Window

    title:      string,
    width:      int,    // Logical width
    height:     int,    // Logical height
}

// new_window creates a new Game_Window using the provided graphics device.
// The graphics.gfx_api must be initialized before calling this.
new_window :: proc(
    device: Gfx_Device, 
    title: string, 
    width, height: int,
) -> (^Game_Window, common.Engine_Error) {

    // is_valid should be a function within the graphics package or on Gfx_Device itself
    // Assuming a top-level is_valid(Gfx_Device) exists in the graphics package:
    if !is_valid_device(device) { // Or however device validity is checked now
        log.error("graphics.new_window: Provided Gfx_Device is invalid.")
        return nil, common.Engine_Error.Invalid_Handle
    }
    
    // gfx_api is assumed to be a global or accessible variable in the graphics package
    gfx_win_handle, err := gfx_api.create_window(device, title, width, height)
    if err != .None {
        log.errorf("graphics.new_window: gfx_api.create_window failed: %s", gfx_api.get_error_string(err))
        return nil, err // Already common.Engine_Error
    }

    win := new(Game_Window)
    win.gfx_device = device
    win.gfx_window = gfx_win_handle
    win.title = title
    win.width = width
    win.height = height
    
    log.infof("Graphics.Game_Window created for Gfx_Window with title '%s'", title)
    return win, nil
}

// set_title sets the window title for a Game_Window.
set_title :: proc(win: ^Game_Window, title: string) -> common.Engine_Error {
    if win == nil || win.gfx_window.variant == nil { // Assuming Gfx_Window is a sum type with a variant
        log.error("graphics.set_title: Window is nil or Gfx_Window is invalid")
        return .Invalid_Handle
    }
    
    err := gfx_api.set_window_title(win.gfx_window, title)
    if err != .None {
        log.errorf("graphics.set_title: Failed to set window title: %s", gfx_api.get_error_string(err))
        return err 
    }
    
    win.title = title
    return .None
}

// destroy_window destroys a Game_Window.
destroy_window :: proc(win: ^Game_Window) {
    if win == nil {
        return
    }
    // Gfx_Device is owned elsewhere (e.g., Game struct), not destroyed here.
    // Gfx_Window destruction handles its own API-specific resources.
    gfx_api.destroy_window(win.gfx_window)
    
    log.infof("Graphics.Game_Window for Gfx_Window with title '%s' destroyed.", win.title)
    free(win) 
}

// Helper function to check device validity, assuming it's part of graphics package now.
is_valid_device :: proc(device: Gfx_Device) -> bool {
    // Placeholder: Actual implementation depends on Gfx_Device struct.
    // If Gfx_Device is a sum type struct:
    return device.variant != nil 
}

// --- Accessor Methods ---

// Access cached logical width
get_width :: proc(self: ^Game_Window) -> int {
    if self == nil { 
        log.warn("get_width called on nil Game_Window.")
        return 0 
    }
    return self.width
}

// Access cached logical height
get_height :: proc(self: ^Game_Window) -> int {
    if self == nil { 
        log.warn("get_height called on nil Game_Window.")
        return 0 
    }
    return self.height
}

// Access cached title
get_title :: proc(self: ^Game_Window) -> string {
    if self == nil { 
        log.warn("get_title called on nil Game_Window.")
        return "" 
    }
    return self.title
}

// Get drawable width from the graphics API
get_drawable_width :: proc(self: ^Game_Window) -> int {
    if self == nil || self.gfx_window.variant == nil {
        log.error("get_drawable_width: Game_Window is nil or has invalid gfx_window.")
        return 0
    }
    w, _ := gfx_api.get_window_drawable_size(self.gfx_window)
    return w
}

// Get drawable height from the graphics API
get_drawable_height :: proc(self: ^Game_Window) -> int {
    if self == nil || self.gfx_window.variant == nil {
        log.error("get_drawable_height: Game_Window is nil or has invalid gfx_window.")
        return 0
    }
    _, h := gfx_api.get_window_drawable_size(self.gfx_window) // Corrected to get h
    return h
}

// Access underlying Gfx_Window
get_gfx_window :: proc(self: ^Game_Window) -> Gfx_Window {
    if self == nil { 
        log.warn("get_gfx_window called on nil Game_Window.")
        return Gfx_Window{} 
    } // Return empty/invalid Gfx_Window
    return self.gfx_window
}

// Access associated Gfx_Device
get_gfx_device :: proc(self: ^Game_Window) -> Gfx_Device {
    if self == nil { 
        log.warn("get_gfx_device called on nil Game_Window.")
        return Gfx_Device{} 
    } // Return empty/invalid Gfx_Device
    return self.gfx_device
}
