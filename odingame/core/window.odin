package core

import "vendor:sdl2" // Still needed for input events, window flags etc.
import "../graphics" // Import the new graphics interface package
import "core:log"

Window :: struct {
	// SDL window handle is now managed within Gfx_Window's Gl_Window variant.
	// No direct sdl_window field here.
	gfx_device: graphics.Gfx_Device, // The graphics device this window is associated with.
	gfx_window: graphics.Gfx_Window, // The API-agnostic graphics window handle.

	title:      string,
	width:      int,    // Logical width
	height:     int,    // Logical height
	// Flags like resizable, fullscreen etc. are handled at Gfx_Window creation or specific Gfx_Window procs.
	
	// Input related fields can remain, as SDL is still used for input.
	// (Assuming input system reads from a global list of windows or a specific one)
}

// Creates a new window using the provided graphics device.
// SDL must be initialized (at least video subsystem) before calling this,
// typically done in Game initialization.
// The graphics.gfx_api must also be initialized.
new_window :: proc(
	device: graphics.Gfx_Device, 
	title: string, 
	width, height: int,
	// flags: graphics.Window_Flags, // TODO: Add flags if Gfx_Window supports them (e.g. resizable)
) -> (^Window, error) {

	if !is_valid(device) { // is_valid for Gfx_Device
		log.error("new_window: Provided Gfx_Device is invalid.")
		return nil, graphics.Gfx_Error.Invalid_Handle // Or appropriate error
	}
	
	gfx_win_handle, err := graphics.gfx_api.create_window(device, title, width, height)
	if err != .None {
		log.errorf("new_window: gfx_api.create_window failed: %s", graphics.gfx_api.get_error_string(err))
		// Don't destroy device here, caller owns it.
		return nil, err // Propagate Gfx_Error as 'error' interface
	}

	win := new(Window)
	win.gfx_device = device
	win.gfx_window = gfx_win_handle
	win.title = title // Store title, though Gfx_Window might also store it.
	
	// Get actual size from Gfx_Window, as it might differ (e.g. HighDPI)
	// or use the requested size as logical size.
	// For now, assume requested width/height are the logical dimensions.
	win.width = width
	win.height = height
	
	log.infof("Core.Window created for Gfx_Window with title '%s'", title)
	return win, nil
}

// Helper to check if a Gfx_Device is valid (basic check)
// TODO: Move to a common utility or make it part of Gfx_Device itself if possible
is_valid :: proc(device: graphics.Gfx_Device) -> bool {
    return device.variant != nil // Basic check: if variant is not nil, assume it's initialized.
                                 // A more robust check might involve querying device status if API allows.
}


// set_title: Window title changes should ideally go through the graphics API if it manages the window.
// The Gfx_Window interface doesn't have set_title yet.
// If Gl_Window (inside Gfx_Window) exposes the SDL window, it could be done, but breaks abstraction.
// For now, title is set at creation. If dynamic title changes are needed,
// Gfx_Window_Interface should be extended.
/*
set_title :: proc(win: ^Window, title: string) {
	// This would require either Gfx_Window to have a set_title method,
	// or access to the underlying SDL window handle if Gl_Window exposes it.
	// e.g., if win.gfx_window.variant.(^graphics.Gl_Window).sdl_window is accessible:
	// sdl2.SetWindowTitle(win.gfx_window.variant.(^graphics.Gl_Window).sdl_window, title)
	// win.title = title
	log.warn("set_title on core.Window is not fully implemented via Gfx_Interface yet.")
}
*/

destroy_window :: proc(win: ^Window) {
	if win == nil {
		return
	}
	// Gfx_Device is owned by Game, not destroyed here.
	// Gfx_Window destruction handles its own resources (like SDL window via Gl_Window).
	graphics.gfx_api.destroy_window(win.gfx_window)
	
	log.infof("Core.Window for Gfx_Window with title '%s' destroyed.", win.title)
	// Fields in win (like gfx_device, gfx_window) become dangling if not zeroed, but struct is freed.
	free(win) 
}

// --- Functions to interact with Gfx_Window properties, if needed by core ---

get_window_width :: proc(win: ^Window) -> int {
    if win == nil || win.gfx_window.variant == nil { return 0 }
    // Use logical width stored in core.Window, assuming it's kept in sync
    // or query gfx_api if core.Window width/height are not the source of truth.
    // w, _ := graphics.gfx_api.get_window_size(win.gfx_window)
    // return w
    return win.width
}

get_window_height :: proc(win: ^Window) -> int {
    if win == nil || win.gfx_window.variant == nil { return 0 }
    // _, h := graphics.gfx_api.get_window_size(win.gfx_window)
    // return h
    return win.height
}

// get_drawable_size might be useful for viewport setup if not handled by renderer
get_drawable_width :: proc(win: ^Window) -> int {
    if win == nil || win.gfx_window.variant == nil { return 0 }
    w, _ := graphics.gfx_api.get_window_drawable_size(win.gfx_window)
    return w
}
get_drawable_height :: proc(win: ^Window) -> int {
    if win == nil || win.gfx_window.variant == nil { return 0 }
    _, h := graphics.gfx_api.get_window_drawable_size(win.gfx_window)
    return h
}
