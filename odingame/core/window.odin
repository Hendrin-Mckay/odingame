package core

import "vendor:sdl2" // Still needed for input events, window flags etc.
import "../graphics" // Import the new graphics interface package
import "../common" // For standardized error handling
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
) -> (^Window, common.Engine_Error) {

	if !is_valid(device) { // is_valid for Gfx_Device
		log.error("new_window: Provided Gfx_Device is invalid.")
		return nil, common.Engine_Error.Invalid_Handle
	}
	
	gfx_win_handle, err := graphics.gfx_api.create_window(device, title, width, height)
	if err != .None {
		log.errorf("new_window: gfx_api.create_window failed: %s", graphics.gfx_api.get_error_string(err))
		// Don't destroy device here, caller owns it.
		return nil, graphics.gfx_error_to_engine_error(err) // Convert Gfx_Error to Engine_Error
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


// Set the window title
// This implementation uses the graphics API to change the window title
set_title :: proc(win: ^Window, title: string) -> common.Engine_Error {
	if win == nil || win.gfx_window.variant == nil {
		log.error("set_title: Window is nil or invalid")
		return .Invalid_Handle
	}
	
	// Update the window title through the graphics API
	err := graphics.gfx_api.set_window_title(win.gfx_window, title)
	if err != .None {
		log.errorf("set_title: Failed to set window title: %s", graphics.gfx_api.get_error_string(err))
		return graphics.gfx_error_to_engine_error(err)
	}
	
	// Update the local title field
	win.title = title
	return .None
}

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
