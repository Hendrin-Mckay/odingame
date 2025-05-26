package sdl

import "core:strings" // For cstring conversion if needed
import "src:core" // For logging
// Import the SDL foreign bindings, likely from the sdl_context.odin itself or a shared sdl_bindings.odin
// For now, we assume functions like SDL_CreateWindow are accessible via the `sdl.` prefix if they are in `sdl_context.odin`
// or directly if this file is part of the same `sdl` package and they are package-level visible.
// Since sdl_context.odin has `package sdl`, these will be available.

// Window struct to manage SDL_Window
Window :: struct {
	sdl_window: rawptr, // stores ^SDL_Window
	title:      string,
	width:      i32,
	height:     i32,
}

// CreateWindow creates a new SDL window.
// Returns a pointer to the Window struct or nil on failure.
CreateWindow :: proc(title: string, width, height: i32, flags: u32 = SDL_WINDOW_SHOWN | SDL_WINDOW_RESIZABLE) -> (^Window, bool) {
	core.LogInfoFmt("[Window] Creating window: '%s' (%dx%d)", title, width, height)

	// Odin strings need to be null-terminated for C functions
	title_cstr := strings.clone_to_cstring(title)
	defer delete(title_cstr) // Ensure memory is freed

	sdl_win_ptr := SDL_CreateWindow(title_cstr, width, height, flags)

	if sdl_win_ptr == nil {
		error_msg := SDL_GetError()
		core.LogErrorFmt("[Window] Failed to create window: %s", error_msg)
		return nil, false
	}

	// Allocate our Window struct
	// Using 'new' and 'free' for simplicity here. A custom allocator could be used.
	window_obj := new(Window)
	window_obj^ = Window{
		sdl_window = sdl_win_ptr,
		title      = strings.clone(title), // Clone the title string
		width      = width,
		height     = height,
	}

	core.LogInfoFmt("[Window] Window '%s' created successfully.", title)
	return window_obj, true
}

// DestroyWindow destroys an SDL window and frees the Window struct.
DestroyWindow :: proc(window: ^Window) {
	if window == nil {
		core.LogWarning("[Window] Attempted to destroy a nil window.")
		return
	}
	core.LogInfoFmt("[Window] Destroying window: '%s'", window.title)
	SDL_DestroyWindow(window.sdl_window)
	// Free the cloned title string and the Window struct itself
	delete(window.title) 
	free(window) 
	core.LogInfo("[Window] Window destroyed.")
}

// GetSDLWindow returns the raw SDL_Window pointer.
// Useful for functions like SDL_CreateRenderer.
GetSDLWindow :: proc(window: ^Window) -> rawptr {
    if window == nil {
        return nil
    }
    return window.sdl_window
}
