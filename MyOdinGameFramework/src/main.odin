package main

import "src:core"
import "src:sdl"
// import "core:time" // For delta_time

main :: proc() {
	core.LogInfo("MyOdinGameFramework starting...")

	if !sdl.InitSDL() {
		core.LogErrorAndExit("Failed to initialize SDL. Exiting.")
	}
	defer sdl.ShutdownSDL()
	core.LogInfo("[Main] SDL Initialized.")
	
	sdl.InitInputState() // Initialize the input system

	window_obj, ok := sdl.CreateWindow("My Odin Game Framework", 800, 600)
	if !ok {
		core.LogErrorAndExit("[Main] Failed to create window. Exiting.")
	}
	defer sdl.DestroyWindow(window_obj)
	core.LogInfoFmt("[Main] Window '%s' created.", window_obj.title)

	renderer_obj, renderer_ok := sdl.CreateRenderer(sdl.GetSDLWindow(window_obj))
	if !renderer_ok {
		core.LogErrorAndExit("[Main] Failed to create renderer. Exiting.")
	}
	defer sdl.DestroyRenderer(renderer_obj)
	core.LogInfo("[Main] Renderer created.")

	is_running := true
	core.LogInfo("[Main] Starting game loop...")

	// last_time := time.tick_now()
	// current_time: time.Tick
	// delta_time: f32

	for is_running {
		// current_time = time.tick_now()
		// delta_time = cast(f32)time.duration_seconds(time.tick_since(last_time))
		// last_time = current_time

		sdl.UpdateInputState() // Update input state (copy current to prev)
		
		if sdl.ProcessEvents() { // Process all SDL events and check for quit
			is_running = false
		}

		// Example: Check for ESC key press to quit
		if sdl.IsKeyPressed(sdl.SDL_SCANCODE_ESCAPE) {
			core.LogInfo("[Main] ESC key pressed. Shutting down.")
			is_running = false
		}
		if sdl.IsMouseButtonPressed(0) { // Left mouse button (0-indexed)
            mx, my := sdl.GetMousePosition()
			core.LogInfoFmt("[Main] Left mouse button pressed at: %d, %d", mx, my)
        }


		// --- Update Game State (Placeholder) ---
		// update_game_logic(delta_time) 

		// --- Rendering ---
		bg_color := sdl.COLOR_BLUE
		if sdl.IsKeyDown(sdl.SDL_SCANCODE_SPACE) {
			bg_color = sdl.COLOR_GREEN // Change background to green if SPACE is held
		}
		sdl.Clear(renderer_obj, bg_color) 
		sdl.Present(renderer_obj)

		// sdl.SDL_Delay(1) 
	}

	core.LogInfo("[Main] Game loop finished. Application closing.")
}
