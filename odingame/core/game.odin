package core

import "vendor:sdl2"
import "vendor:sdl2/image" // Already there, but confirm
import "../graphics"
import "../input"
import "core:fmt" // For error printing in run

// Basic Color struct and constants, can be moved to a separate core/colors.odin
Color :: struct { r, g, b, a: u8 }

WHITE :: Color{255, 255, 255, 255}
BLACK :: Color{0, 0, 0, 255}
RED :: Color{255, 0, 0, 255}
GREEN :: Color{0, 255, 0, 255}
BLUE :: Color{0, 0, 255, 255}
CORNFLOWER_BLUE :: Color{100, 149, 237, 255} // Used in simple_game

// User-defined game functions
InitializeFn :: proc(game: ^Game)
LoadContentFn :: proc(game: ^Game)
UpdateFn :: proc(game: ^Game, game_time: GameTime)
DrawFn :: proc(game: ^Game, game_time: GameTime)

GameTime :: struct {
    elapsed_game_time: f64, // Seconds
    total_game_time:   f64, // Seconds
}

Game :: struct {
    // Modules
    window:          ^Window, // Window now holds Gfx_Device and Gfx_Window
    // graphics_device field is removed, access via game.window.gfx_device
    sprite_batch:    ^graphics.SpriteBatch, 
    // Input state is managed globally in 'input' package

    // User-defined procedures
    initialize_fn:  InitializeFn,
    load_content_fn: LoadContentFn,
    update_fn:       UpdateFn,
    draw_fn:         DrawFn,

    // State
    running:         bool,
    
    // Timing
    game_time:       GameTime,
    _previous_ticks: u64,
    _perf_frequency: u64,
}

// This is an internal constructor
_new_game_for_run :: proc(title: string, width, height: int) -> (^Game, error) {
	// Initialize SDL
	if sdl2.Init(sdl2.INIT_VIDEO | sdl2.INIT_TIMER | sdl2.INIT_EVENTS) != 0 {
		return nil, sdl2.GetError()
	}

	// Initialize SDL_image for image loading (PNG, JPG, etc.)
	IMG_INIT_PNG :: 0x00000001
	IMG_INIT_JPG :: 0x00000002
	if sdl2.image.Init(u32(IMG_INIT_PNG | IMG_INIT_JPG)) & u32(IMG_INIT_PNG | IMG_INIT_JPG) != u32(IMG_INIT_PNG | IMG_INIT_JPG) {
		err_msg := sdl2.image.GetError() 
		sdl2.Quit()
		return nil, err_msg
	}

	game := new(Game) // Allocated with context.allocator by default

	// --- Initialize Graphics API ---
	// This is a new, crucial step. Must be called before any gfx_api functions.
	graphics.initialize_sdl_opengl_backend() 
	// We need an allocator for the graphics device. Game's context.allocator can be used.
	main_gfx_device, device_err := graphics.gfx_api.create_device(&context.allocator)
	if device_err != .None {
		log.errorf("_new_game_for_run: Failed to create Gfx_Device: %s", graphics.gfx_api.get_error_string(device_err))
		sdl2.image.Quit()
		sdl2.Quit()
		free(game)
		return nil, device_err // Propagate Gfx_Error
	}
	// --- End Initialize Graphics API ---

	// Create core.Window, passing the Gfx_Device
	// core.new_window now takes Gfx_Device
	win, err_win := new_window(main_gfx_device, title, width, height)
	if err_win != nil {
		log.errorf("_new_game_for_run: Failed to create core.Window: %v", err_win)
		graphics.gfx_api.destroy_device(main_gfx_device) // Clean up created device
		sdl2.image.Quit()
		sdl2.Quit()
		free(game)
		return nil, err_win
	}
	game.window = win
	// game.graphics_device is no longer a direct field of Game. Access via game.window.gfx_device.

	// Initialize SpriteBatch, passing the Gfx_Device from the window
	// new_sprite_batch now takes Gfx_Device. Width/height are not needed for SB construction anymore.
	sb, sb_err := graphics.new_spritebatch(game.window.gfx_device) // Max sprites defaults in new_spritebatch
	if sb_err != .None {
		log.errorf("_new_game_for_run: Failed to create SpriteBatch: %s", graphics.gfx_api.get_error_string(sb_err))
		// Full cleanup: destroy window (which destroys Gfx_Window), then device.
		destroy_window(game.window) // This calls gfx_api.destroy_window
		graphics.gfx_api.destroy_device(main_gfx_device)
		sdl2.image.Quit()
		sdl2.Quit()
		free(game)
		return nil, sb_err
	}
	game.sprite_batch = sb
	
	// Initialize input system
	input._init_input_system()
	
	// Note: Timing fields (_perf_frequency, _previous_ticks, game_time) are initialized in 'run'
	// before the main loop and user Initialize/LoadContent calls.
	// game.running is also set in 'run'.
	
	return game, nil
}
 
_destroy_game :: proc(game: ^Game) {
	if game == nil {
		return
	}
	
	// User unload content would be called here if it existed

	// Destroy SpriteBatch first, as it uses the graphics device.
	graphics.destroy_spritebatch(game.sprite_batch) 
	game.sprite_batch = nil
	
	// Store device handle before window is destroyed, as window owns it conceptually for access.
	// However, the device's lifecycle might outlive a single window if multiple windows were supported.
	// For this single-window game, game.window.gfx_device is the main device.
	device_to_destroy := game.window.gfx_device

	// Destroy core.Window (which in turn calls gfx_api.destroy_window for the Gfx_Window)
	destroy_window(game.window)
	game.window = nil
	
	// Now destroy the Gfx_Device
	if is_valid(device_to_destroy) { // Check if device handle is valid before destroying
		graphics.gfx_api.destroy_device(device_to_destroy)
	}

	sdl2.image.Quit()
	sdl2.Quit() 
	
	free(game) 
}

// run - main entry point for the game
run :: proc(
    title: string, 
    width, height: int,
    initialize_fn: InitializeFn,
    load_content_fn: LoadContentFn,
    update_fn: UpdateFn,
    draw_fn: DrawFn,
) {
    game, err := _new_game_for_run(title, width, height)
    if err != nil {
        fmt.eprintln("Failed to initialize game:", err)
        return
    }
    
    // Assign user functions
    game.initialize_fn = initialize_fn
    game.load_content_fn = load_content_fn
    game.update_fn = update_fn
    game.draw_fn = draw_fn

    // Initialize SDL performance frequency and initial ticks for the game loop
    game._perf_frequency = sdl2.GetPerformanceFrequency()
    game._previous_ticks = sdl2.GetPerformanceCounter()
    game.game_time.total_game_time = 0
    game.game_time.elapsed_game_time = 0 // Start with zero elapsed time for first frame logic

    // Call user Initialize
    if game.initialize_fn != nil {
        game.initialize_fn(game)
    }

    // Call user LoadContent
    if game.load_content_fn != nil {
        game.load_content_fn(game)
    }

    game.running = true // Start the loop

    // Main game loop
    for game.running {
        // --- Timing Calculations ---
        current_ticks := sdl2.GetPerformanceCounter()
        delta_ticks := current_ticks - game._previous_ticks
        game._previous_ticks = current_ticks

        game.game_time.elapsed_game_time = f64(delta_ticks) / f64(game._perf_frequency)
        // Ensure elapsed time is not excessively large (e.g. after breakpoint debugging)
        // or negative (if counter wraps, though GetPerformanceCounter is usually u64)
        // A simple cap for stability, more advanced methods exist.
        MAX_ELAPSED_TIME :: 1.0 / 10.0 // e.g., cap at 10 FPS equivalent if things go wild
        if game.game_time.elapsed_game_time > MAX_ELAPSED_TIME {
            game.game_time.elapsed_game_time = MAX_ELAPSED_TIME
        }
        if game.game_time.elapsed_game_time < 0 { // Should not happen with u64 counters unless they wrap around 0
            game.game_time.elapsed_game_time = 0
        }
        game.game_time.total_game_time += game.game_time.elapsed_game_time
        
        // --- Input ---
        input._update_input_states()
        if input.is_quit_requested() {
            game.running = false
            // No 'continue' or 'break' needed here, loop condition 'game.running' will handle it
        }

        // --- Update ---
        // Only run update if game is still running after input processing
        if game.running && game.update_fn != nil {
            game.update_fn(game, game.game_time)
        }
        
        // --- Draw ---
        // Only draw if game is still running (e.g. update didn't call exit)
        if game.running && game.draw_fn != nil {
            game.draw_fn(game, game.game_time)
        } else if game.running { 
            // Default draw behavior if no user draw_fn is provided
            // This now uses the gfx_api via the window's device and Gfx_Window handles.
            if game.window != nil && is_valid(game.window.gfx_device) && game.window.gfx_window.variant != nil {
                default_clear_opts := graphics.default_clear_options() // Get default clear options
                // Modify if needed, e.g. game.window.gfx_device.set_clear_color(...) if that existed,
                // or pass custom Clear_Options.
                graphics.gfx_api.clear_screen(game.window.gfx_device, default_clear_opts)
                
                // User draw calls would happen here conceptually if draw_fn was a simpler "render scene"
                // and game loop handled clear/present.
                
                err_present := graphics.gfx_api.present_window(game.window.gfx_window)
                if err_present != .None {
                    log.errorf("Game loop: Failed to present window: %s", graphics.gfx_api.get_error_string(err_present))
                    // Potentially set game.running = false or handle error
                }
            }
        }
        
        // Yield CPU if necessary - VSync is preferred (set with GL_SetSwapInterval via Gfx_Window creation)
        // sdl2.Delay(1) 
    }

    // Cleanup
    _destroy_game(game)
    // fmt.println("Game exited.") // For debugging
}

// Public way to exit the game from user code
exit :: proc(game: ^Game) {
    if game != nil {
        game.running = false
    }
}
