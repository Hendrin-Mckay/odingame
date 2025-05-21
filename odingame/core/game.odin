package core

import "vendor:sdl2"
import "vendor:sdl2/image" // Already there, but confirm
import "../graphics"
import "../input"
import "core:fmt" // For error printing in run

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
    window:          ^Window,
    graphics_device: ^graphics.Device,
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

	game := new(Game)

	win, err_win := new_window(title, width, height)
	if err_win != nil {
		sdl2.image.Quit()
		sdl2.Quit()
		free(game) // Free partially allocated game
		return nil, err_win
	}
	game.window = win

	dev, err_dev := graphics.new_device(win)
	if err_dev != nil {
		destroy_window(win) 
		sdl2.image.Quit()
		sdl2.Quit()
		free(game) // Free partially allocated game
		return nil, err_dev
	}
	game.graphics_device = dev

	// Initialize SpriteBatch
	sb, sb_err := graphics.new_sprite_batch(dev, width, height)
	if sb_err != nil {
		graphics.destroy_device(dev)
		destroy_window(win)
		sdl2.image.Quit()
		sdl2.Quit()
		free(game) // Free partially allocated game
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

	graphics.destroy_sprite_batch(game.sprite_batch) // Destroy sprite batch
	graphics.destroy_device(game.graphics_device)
	destroy_window(game.window)
	
	game.sprite_batch = nil
	game.graphics_device = nil 
	game.window = nil

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
        } else if game.running { // Default draw if no user draw_fn and still running
            // graphics.clear(game.graphics_device, graphics.BLACK) // Example default
            // graphics.present(game.graphics_device, game.window)
        }
        
        // Yield CPU if necessary - VSync is preferred (set with GL_SetSwapInterval)
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
