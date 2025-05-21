package core

import "vendor:sdl2"

Window :: struct {
	sdl_window: ^sdl2.Window,
	title:      string,
	width:      int,
	height:     int,
}

// Creates a new window
new_window :: proc(title: string, width, height: int) -> (^Window, error) {
	// sdl2.Init if not already called by Game
	sdl_window := sdl2.CreateWindow(title, sdl2.WINDOWPOS_UNDEFINED, sdl2.WINDOWPOS_UNDEFINED, width, height, sdl2.WINDOW_OPENGL)
	if sdl_window == nil {
		return nil, sdl2.GetError()
	}
	// Maybe set OpenGL attributes here if needed, before context creation
	// sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_MAJOR_VERSION, 3)
	// sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_MINOR_VERSION, 3)
	// sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_PROFILE_MASK, cast(i32)sdl2.GLprofile.CORE)

	win := new(Window)
	win.sdl_window = sdl_window
	win.title = title
	win.width = width
	win.height = height
	return win, nil
}

set_title :: proc(win: ^Window, title: string) {
	sdl2.SetWindowTitle(win.sdl_window, title)
	win.title = title
}

destroy_window :: proc(win: ^Window) {
	if win == nil || win.sdl_window == nil {
		return
	}
	sdl2.DestroyWindow(win.sdl_window)
	win.sdl_window = nil
	free(win) // Release the Window struct itself
}
