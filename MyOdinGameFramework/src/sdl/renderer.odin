package sdl

// import "core:strings" // Not needed here unless converting strings for error messages
import "src:core"     // For logging
// Assuming SDL functions are available via `sdl.` prefix from sdl_context.odin or similar

// Renderer struct to manage SDL_Renderer
Renderer :: struct {
	sdl_renderer: rawptr, // stores ^SDL_Renderer
	// color type for convenience
}

// Define a Color struct for convenience
Color :: struct {r, g, b, a: u8}

// Common colors
COLOR_BLACK :: Color{0, 0, 0, 255}
COLOR_WHITE :: Color{255, 255, 255, 255}
COLOR_RED :: Color{255, 0, 0, 255}
COLOR_GREEN :: Color{0, 255, 0, 255}
COLOR_BLUE :: Color{0, 0, 255, 255}


// CreateRenderer creates a new SDL renderer for a given window.
// Returns a pointer to the Renderer struct or nil on failure.
CreateRenderer :: proc(window_ptr: rawptr, flags: u32 = SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC) -> (^Renderer, bool) {
	core.LogInfo("[Renderer] Creating renderer...")
	if window_ptr == nil {
		core.LogError("[Renderer] Cannot create renderer for a nil window pointer.")
		return nil, false
	}

	sdl_rnd_ptr := SDL_CreateRenderer(window_ptr, flags)

	if sdl_rnd_ptr == nil {
		error_msg := SDL_GetError()
		core.LogErrorFmt("[Renderer] Failed to create renderer: %s", error_msg)
		return nil, false
	}

	renderer_obj := new(Renderer)
	renderer_obj^ = Renderer{
		sdl_renderer = sdl_rnd_ptr,
	}

	core.LogInfo("[Renderer] Renderer created successfully.")
	return renderer_obj, true
}

// DestroyRenderer destroys an SDL renderer and frees the Renderer struct.
DestroyRenderer :: proc(renderer: ^Renderer) {
	if renderer == nil {
		core.LogWarning("[Renderer] Attempted to destroy a nil renderer.")
		return
	}
	core.LogInfo("[Renderer] Destroying renderer...")
	SDL_DestroyRenderer(renderer.sdl_renderer)
	free(renderer)
	core.LogInfo("[Renderer] Renderer destroyed.")
}

// Clear clears the renderer with a given color.
Clear :: proc(renderer: ^Renderer, color: Color) {
	if renderer == nil || renderer.sdl_renderer == nil {
		core.LogWarning("[Renderer] Attempted to clear with a nil renderer.")
		return
	}
	SDL_SetRenderDrawColor(renderer.sdl_renderer, color.r, color.g, color.b, color.a)
	SDL_RenderClear(renderer.sdl_renderer)
}

// Present updates the screen with any rendering performed since the previous call.
Present :: proc(renderer: ^Renderer) {
	if renderer == nil || renderer.sdl_renderer == nil {
		core.LogWarning("[Renderer] Attempted to present with a nil renderer.")
		return
	}
	SDL_RenderPresent(renderer.sdl_renderer)
}
