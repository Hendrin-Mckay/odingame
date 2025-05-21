package graphics

import "vendor:sdl2"
import gl "vendor:OpenGL/gl" // Corrected import for gl functions
import "../core"

Color :: struct {
	r, g, b, a: u8,
}

// Common Colors
WHITE :: Color{255, 255, 255, 255}
BLACK :: Color{0, 0, 0, 255}
CORNFLOWER_BLUE :: Color{100, 149, 237, 255}


Device :: struct {
	sdl_gl_context: sdl2.GLContext,
}

new_device :: proc(win: ^core.Window) -> (^Device, error) {
	// Ensure SDL_GL attributes are set before creating context
	sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_MAJOR_VERSION, 3)
	sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_MINOR_VERSION, 3)
	sdl2.GL_SetAttribute(sdl2.GLattr.CONTEXT_PROFILE_MASK, cast(i32)sdl2.GLprofile.CORE)
	sdl2.GL_SetAttribute(sdl2.GLattr.DOUBLEBUFFER, 1)


	gl_context := sdl2.GL_CreateContext(win.sdl_window)
	if gl_context == nil {
		return nil, sdl2.GetError()
	}

	// Initialize OpenGL procedure loader for the current context
	// Using gl.load_up_to from vendor:OpenGL/gl
	if !gl.load_up_to(3, 3, sdl2.GL_GetProcAddress) {
		sdl2.GL_DeleteContext(gl_context) // Clean up context if GL loading fails
		return nil, sdl2.GetError() // Or a custom error like "Failed to load OpenGL functions"
	}


	dev := new(Device)
	dev.sdl_gl_context = gl_context

	// Set initial GL states
	gl.Viewport(0, 0, cast(i32)win.width, cast(i32)win.height)
	// Enable blending by default as it's common for 2D games
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	return dev, nil
}

clear :: proc(dev: ^Device, color: Color) {
	gl.ClearColor(f32(color.r)/255.0, f32(color.g)/255.0, f32(color.b)/255.0, f32(color.a)/255.0)
	gl.Clear(gl.COLOR_BUFFER_BIT)
}

present :: proc(dev: ^Device, win: ^core.Window) {
	sdl2.GL_SwapWindow(win.sdl_window)
}

destroy_device :: proc(dev: ^Device) {
	if dev == nil { // Removed dev.sdl_gl_context == nil check as it's implied if dev is nil
		return
	}
	if dev.sdl_gl_context != nil { // Check context specifically before deleting
		sdl2.GL_DeleteContext(dev.sdl_gl_context)
	}
	dev.sdl_gl_context = nil // Ensure it's nilled even if it was already
	free(dev) // Release the Device struct itself
}
