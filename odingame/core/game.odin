package core

import "core:fmt"
import "core:log"
import "core:time"
import "core:slice" // For dynamic array operations on components (future)
import "vendor:sdl2"
import "vendor:sdl2/image"

// Import new placeholder packages and time
import "../content"
import "../graphics" // For Graphics_Device_Manager, Graphics_Device, Game_Window placeholders
import "./time"     // For Game_Time
import "../input"   // For input processing
import "../audio"   // For Audio_Engine, Media_Player
import "../common"  // For error types (though less used in this new structure initially)


// Game_Component placeholder (actual definition in game_component.odin)
// Forward declare or use a simple struct if full import causes cycles / too much change now.
// For this phase, assume Game_Component is defined in its own file and can be imported if needed,
// or we operate on it as a rawptr if its methods are not called directly by Game.
// For now, components array will be [dynamic]^game_component.Game_Component.
// This requires game_component.odin to exist with at least `Game_Component :: struct{}`.
// Let's assume it does.
// import "./game_component" // If methods like component.update() were called directly.

Game :: struct {
    // Service Locators / Managers
    // service_provider: ^Service_Container, // Replaces services map
    graphics_device_manager: ^graphics.Graphics_Device_Manager, 
    content:           ^content.Content_Manager,     // Integrated ContentManager

    // Core resources (populated by GDM)
    graphics_device:   ^graphics.Graphics_Device, 
    window:            ^graphics.Game_Window,    // Primary game window

    // Audio System
    audio_engine:      ^audio.Audio_Engine,
    media_player:      ^audio.Media_Player,

    // Game State & Logic
    // components:       [dynamic]^game_component.Game_Component, 
    components:       [dynamic]rawptr, 
    services:         map[typeid]rawptr,

    // New fields for GDM integration
    allocator_ref:    mem.Allocator, // To pass to GDM and other services
    window_title_base: string,      // Base title for the window

    target_elapsed_time: time.Duration,
    is_fixed_time_step: bool,
    is_running:        bool,
    _initialized:      bool, 
    _suppress_draw:    bool, // For fixed time step when updates are slow

    // Timing for game loop
    _accumulator:      time.Duration, // For fixed time step
    _previous_ticks:   u64,           // For calculating delta time
    _perf_frequency:   u64,           // For calculating delta time

    // Virtual methods (as procedure fields)
    Initialize:     proc(game: ^Game),
    Load_Content:   proc(game: ^Game),
    Unload_Content: proc(game: ^Game),
    Update:         proc(game: ^Game, game_time: Game_Time),
    Draw:           proc(game: ^Game, game_time: Game_Time),
    // New virtual methods from XNA
    Begin_Run:      proc(game: ^Game),
    End_Run:        proc(game: ^Game),
    Begin_Draw:     proc(game: ^Game) -> bool, // Returns true if drawing should occur
    End_Draw:       proc(game: ^Game),
}

// --- Default "Virtual" Method Implementations ---
_default_initialize :: proc(game: ^Game) { log.info("Game.Initialize (default)") }
_default_load_content :: proc(game: ^Game) { log.info("Game.Load_Content (default)") }
_default_unload_content :: proc(game: ^Game) { log.info("Game.Unload_Content (default)") }
_default_update :: proc(game: ^Game, game_time: Game_Time) { /*log.debug("Game.Update (default)")*/ }
_default_draw :: proc(game: ^Game, game_time: Game_Time) { /*log.debug("Game.Draw (default)")*/ }
_default_begin_run :: proc(game: ^Game) { log.info("Game.Begin_Run (default)") }
_default_end_run :: proc(game: ^Game) { log.info("Game.End_Run (default)") }
_default_begin_draw :: proc(game: ^Game) -> bool { /*log.debug("Game.Begin_Draw (default)");*/ return true }
_default_end_draw :: proc(game: ^Game) { /*log.debug("Game.End_Draw (default)")*/ }

// --- Constructor ---
new_game :: proc(allocator := context.allocator) -> ^Game {
    game := new(Game, allocator)

    game.Initialize     = _default_initialize
    game.Load_Content   = _default_load_content
    game.Unload_Content = _default_unload_content
    game.Update         = _default_update
    game.Draw           = _default_draw
    game.Begin_Run      = _default_begin_run
    game.End_Run        = _default_end_run
    game.Begin_Draw     = _default_begin_draw
    game.End_Draw       = _default_end_draw

    game.target_elapsed_time = time.Duration_Second / 60 // Default to 60 FPS
    game.is_fixed_time_step  = true
    game.is_running          = false
    game._initialized        = false
    game._suppress_draw      = false

    game.components = make([dynamic]rawptr, 0, 16, allocator) // Initial capacity 16
    game.services   = make(map[typeid]rawptr, allocator)
    
    game.allocator_ref = allocator // Store allocator for GDM and others
    
    // Initialize GraphicsDeviceManager
    game.graphics_device_manager = graphics.new_graphics_device_manager(game)
    // game.graphics_device and game.window will be populated by GDM.apply_changes()

    // Content manager would be initialized here too
    // game.content = content.new_content_manager(game, "./assets") // Example
    game.content = content.new_content_manager(game, "assets", game.allocator_ref) // Default root "assets"

    // Initialize Audio System
    ae, ae_err := audio.audio_engine_initialize(game.allocator_ref)
    if ae_err != .None {
        // Log error, but game might continue without audio
        log.errorf("Failed to initialize AudioEngine: %v", ae_err)
        game.audio_engine = nil
    } else {
        game.audio_engine = ae
    }
    game.media_player = audio.media_player_new(game.allocator_ref)


    log.info("New Game instance created.")
    return game
}

// --- Core Game Loop ---

// game_tick is called once per main loop iteration. It handles timing and calling Update based on fixed/variable step.
game_tick :: proc(game: ^Game) {
    current_ticks := sdl2.GetPerformanceCounter()
    delta_ticks := current_ticks - game._previous_ticks
    game._previous_ticks = current_ticks

    delta_duration := time.Duration( (f64(delta_ticks) * f64(time.Second)) / f64(game._perf_frequency) )
    
    // Prevent spiral of death and ensure non-negative delta.
    // Cap max elapsed time to avoid huge steps after pauses (e.g. debugging).
    MAX_ELAPSED_TIME :: time.Duration_Second / 10 // e.g., 100ms
    if delta_duration > MAX_ELAPSED_TIME {
        delta_duration = MAX_ELAPSED_TIME
    }
    if delta_duration < 0 { // Should not happen with u64 counters
        delta_duration = 0
    }

    game_time_update: Game_Time
    game_time_update.is_running_slowly = false // Will be set if fixed step and lagging

    if game.is_fixed_time_step {
        game._accumulator += delta_duration
        game_time_update.elapsed = game.target_elapsed_time

        max_updates_per_frame := 5 // Prevent extreme slowdowns from freezing the game entirely
        updates_this_frame := 0

        for game._accumulator >= game.target_elapsed_time && updates_this_frame < max_updates_per_frame {
            game.game_time.total += game.target_elapsed_time
            game_time_update.total = game.game_time.total
            
            if game.Update != nil { game.Update(game, game_time_update) }
            
            game._accumulator -= game.target_elapsed_time
            updates_this_frame += 1

            if game._accumulator < game.target_elapsed_time && updates_this_frame >= max_updates_per_frame {
                game_time_update.is_running_slowly = true // We're behind and had to do max updates
            }
        }
        // If accumulator is still large, it means we're very behind. Reset accumulator to prevent spiral.
        if game._accumulator >= game.target_elapsed_time {
             // log.warnf("Game is running very slowly. Accumulator was %v after max updates. Resetting.", game._accumulator)
             game._accumulator = 0 // Or cap it, e.g. game._accumulator = game.target_elapsed_time
             game_time_update.is_running_slowly = true
        }
        game._suppress_draw = game_time_update.is_running_slowly

    } else { // Variable time step
        game.game_time.total += delta_duration
        game_time_update.elapsed = delta_duration
        game_time_update.total = game.game_time.total
        if game.Update != nil { game.Update(game, game_time_update) }
        game._suppress_draw = false
    }
}


game_run_one_frame :: proc(game: ^Game) {
    // Handle SDL events (input is handled by input package, but quit event here)
    event: sdl2.Event
    for sdl2.PollEvent(&event) {
        if event.type == .QUIT {
            game_exit(game) // Sets game.is_running = false
        }
        // Pass event to input system if it needs raw events
        // input.process_event(&event) // Or similar
    }
    // Update input states (keyboard, mouse, etc.)
    input._update_input_states() // Assuming this is the way to poll current state after events

    // Tick the game logic (updates timers and calls Game.Update)
    game_tick(game)

    // Update Audio Engine (if it has any per-frame logic)
    if game.audio_engine != nil {
        audio.audio_engine_update(game.audio_engine)
    }

    // Draw if not suppressed
    if !game._suppress_draw {
        if game.Begin_Draw != nil && game.Begin_Draw(game) {
            if game.Draw != nil {
                // For Draw, elapsed time is the actual frame delta, not target_elapsed_time
                // Re-calculate actual delta for Draw's Game_Time
                // This is a bit simplified; XNA's GameTime for Draw uses same elapsed as Update if fixed.
                // For variable step, it's the same. If fixed, XNA's Draw GameTime uses target_elapsed_time.
                // Let's stick to target_elapsed_time for Draw if fixed, for consistency with Update calls.
                draw_game_time := Game_Time {
                    elapsed = game.is_fixed_time_step ? game.target_elapsed_time : game_time.elapsed, // game_time.elapsed is not defined here
                                                                                                     // Use the last calculated delta_duration for variable, or target for fixed
                    total   = game.game_time.total,
                    is_running_slowly = game._suppress_draw, // from game_tick
                }
                // Correction: elapsed for draw should be consistent with update's elapsed if fixed step
                current_ticks := sdl2.GetPerformanceCounter()
                raw_delta_for_draw := time.Duration( (f64(current_ticks - game._previous_ticks_for_draw_temp) * f64(time.Second)) / f64(game._perf_frequency) )
                // This is getting complicated. For now, let's use the same Game_Time as the last Update for Draw.
                // This means Draw might see a time that's slightly in the "future" if multiple updates happened.
                // Or, more simply, pass the game.target_elapsed_time if fixed, or last frame's actual delta if variable.
                // This is a common point of debate in game loop design.
                // For now, let's use the same Game_Time as the Update for Draw.
                // The game_tick already prepared a Game_Time suitable for Update.
                // We need to pass the correct `elapsed` for Draw.
                // If fixed time step, Draw's elapsed is target_elapsed_time.
                // If variable, it's the frame's delta_duration.
                // This is already reflected in the game_time_update used in game_tick.
                // However, game_time_update is local to game_tick.
                // Let's construct one for Draw.
                
                // Re-think Draw's GameTime:
                // The Draw method should reflect the state of the world *after* the last Update.
                // The elapsed time for drawing is effectively the time since the *last draw call*.
                // For simplicity and common practice, often Draw gets the same GameTime as the last Update in a frame.
                // Or, if interpolation is used, it might get an alpha value.
                // For now, we pass the current total time, and an elapsed time that's either
                // target_elapsed (if fixed) or the total frame delta (if variable).
                // The game_time structure in Game holds the total time.
                // Let's make a new Game_Time for Draw using the overall frame delta.
                
                // Simpler: Just use the game.target_elapsed_time or the actual delta_duration from the start of game_tick.
                // The 'game_time_update' in game_tick is what we need.
                // We need to pass the Game_Time that reflects the current state being drawn.
                // This is tricky. Let's pass a fresh Game_Time for Draw.
                // The `elapsed` for draw is often considered the time since the previous frame's draw.
                // For now, this Game_Time for Draw is a placeholder until rendering part is fleshed out.
                // We'll use the Game_Time from the last Update for now.
                // This requires game_tick to perhaps store the last_update_game_time.
                // OR, game.Update updates a game.current_game_time_for_update_and_draw.
                // For now:
                current_draw_time := Game_Time{
                    elapsed = game.is_fixed_time_step ? game.target_elapsed_time : delta_duration_from_game_tick_not_available_here,
                    total = game.game_time.total,
                    is_running_slowly = game._suppress_draw,
                }
                // This is still not quite right. The game_time passed to Update is the key.
                // For now, the Draw function will receive a Game_Time, but its `elapsed` field's exact meaning
                // in fixed timestep when multiple updates occur needs careful thought if shaders/physics depend on it.
                // Most XNA games use the same GameTime object for all Updates in a frame, and then for Draw.
                
                // Let's assume game_tick sets a global `current_frame_update_time: Game_Time` that Draw can use.
                // For now, this is a simplification:
    // The Game_Time for Draw should be consistent. If Update ran multiple times, 
    // Draw should represent the state after the last Update.
    // For fixed time step, elapsed is target_elapsed_time. For variable, it's the frame delta.
    // game_time_for_current_frame should be updated by game_tick or game_run_one_frame.
    game.Draw(game, game_time_for_current_frame) 

            }
if game.End_Draw != nil { game.End_Draw(game) } // End_Draw now handles presentation
        }
    }
    // Presentation is now handled by Game.End_Draw -> GraphicsDeviceManager.EndDraw -> GraphicsDevice.Present
}

// Temporary global for game_tick to communicate to game_run_one_frame's Draw call.
// This is not ideal and should be refactored (e.g. game_tick returns it, or Game struct stores it).
// Let's remove these and pass time properly or have Game store current frame's Game_Time.
// delta_duration_from_game_tick_not_available_here: time.Duration // REMOVED BAD HACK
game_time_for_current_frame: Game_Time // This will be updated by game_run loop


game_run :: proc(game: ^Game, title: string, width, height: int, preferred_backend := graphics.Backend_Type.Auto) {
    if game == nil {
        log.error("game_run: Game instance is nil.")
        return
    }

    // --- SDL Initialization ---
    if sdl2.Init(sdl2.INIT_VIDEO | sdl2.INIT_TIMER | sdl2.INIT_EVENTS | sdl2.INIT_GAMECONTROLLER) != 0 {
        log.errorf("SDL initialization failed: %s", sdl2.GetError())
        return // Or panic
    }
    defer sdl2.Quit()

    IMG_INIT_PNG :: 0x00000001; IMG_INIT_JPG :: 0x00000002
    if sdl2.image.Init(u32(IMG_INIT_PNG | IMG_INIT_JPG)) & u32(IMG_INIT_PNG | IMG_INIT_JPG) != u32(IMG_INIT_PNG | IMG_INIT_JPG) {
        log.errorf("SDL_image initialization failed: %s", sdl2.image.GetError())
        return
    }
    defer sdl2.image.Quit()
    
    game.window_title_base = title // Store base title for GDM

    // --- GraphicsDeviceManager Setup ---
    // User can configure GDM.preferred_* settings in their Game.Initialize override.
    // For now, set some defaults that might be overridden by Game.Initialize.
    if game.graphics_device_manager != nil {
        gdm := game.graphics_device_manager
        gdm.preferred_back_buffer_width = width
        gdm.preferred_back_buffer_height = height
        // gdm.preferred_backend_type = preferred_backend // GDM needs a way to know this, or Game tells it.
                                                       // For now, assume gfx_api.create_device handles backend choice.
                                                       // Or, GDM's apply_changes could take preferred_backend.
        // The actual backend selection is within gfx_api.create_device or graphics.initialize_graphics_backend
        // which GDM.apply_changes will invoke.
        // We need to ensure initialize_graphics_backend is called with the preference.
        // For now, let's assume Game.Initialize or GDM constructor handles preferred_backend.
        // The GDM.apply_changes will use its current settings.
        // The `core.run_with_options` in the example sets `game.preferred_backend_type_from_options`
        // which GDM can then read in its `apply_changes` or `create_device` phase.
        // This requires adding `preferred_backend_type_from_options` to Game struct or passing it around.
        // For now, the backend is selected by graphics.initialize_graphics_backend called by GDM.apply_changes.
        // GDM.apply_changes will need to call graphics.initialize_graphics_backend.
    }
    
    // --- Input System Init ---
    input._init_input_system() // Assuming this is still the way

    // --- Timing Init ---
    game._perf_frequency = sdl2.GetPerformanceFrequency()
    game._previous_ticks = sdl2.GetPerformanceCounter()
    game._accumulator = 0
    game.game_time.total = 0
    // game_time_for_current_frame needs to be initialized too
    game_time_for_current_frame.elapsed = game.is_fixed_time_step ? game.target_elapsed_time : 0
    game_time_for_current_frame.total = 0
    game_time_for_current_frame.is_running_slowly = false


    // --- Call Game Lifecycle Methods ---
    if game.Begin_Run != nil { game.Begin_Run(game) } // User can override
    
    if !game._initialized {
        if game.Initialize != nil { game.Initialize(game) } // User can override to set GDM preferences
        game._initialized = true
    }

    // Apply GraphicsDeviceManager changes (creates window and device)
    // This needs the `preferred_backend` which Game should store from options.
    // Let GDM.apply_changes handle backend initialization.
    // The Game struct needs a field for `initial_preferred_backend`.
    // For now, assume GDM.apply_changes can determine it or uses a default.
    // Let's modify apply_changes to take a preferred backend or GDM stores it from Game.
    // For this diff, assume GDM.apply_changes is self-sufficient for now.
    gdm_err := graphics.apply_changes(game.graphics_device_manager)
    if gdm_err != .None {
        log.errorf("Failed to apply graphics device manager changes: %v", gdm_err)
        // End_Run and SDL_Quit will be called by defer
        if game.End_Run != nil { game.End_Run(game) }
        return
    }
    // After apply_changes, Graphics_Device and Game_Window should be available
    game.graphics_device = game.graphics_device_manager.graphics_device
    // game.window = game.graphics_device_manager.graphics_device.window_ref // Assuming GD has a window_ref
    // For now, game.window is populated by GDM.apply_changes if GDM creates it,
    // or Game creates SDL window and GDM uses it. The current GDM creates SDL window.
    // Let's assume GDM now populates game.window field, which is ^graphics.Game_Window
    // This implies GDM's apply_changes needs to set game.window.
    // This part is messy and needs Graphics_Device to own Game_Window or GDM to manage it.
    // For now, game.window is populated by GDM.apply_changes (conceptual).
    if game.graphics_device != nil && game.graphics_device._sdl_window != nil {
        // If Game.window is distinct from GDM's internal window concept
        if game.window == nil { game.window = new(graphics.Game_Window, game.allocator_ref)}
        game.window.sdl_window = game.graphics_device._sdl_window
        game.window.width = game.graphics_device.present_params.back_buffer_width
        game.window.height = game.graphics_device.present_params.back_buffer_height
        // game.window.title = sdl2.GetWindowTitle(cast(^sdl2.Window)game.window.sdl_window) // If needed
    } else {
        log.error("GDM.apply_changes did not result in a valid graphics_device and SDL window handle.")
        if game.End_Run != nil { game.End_Run(game) }
        return
    }


    if game.Load_Content != nil { game.Load_Content(game) } // User can override

    game.is_running = true
    log.info("Game loop starting...")

    // Main Loop
    for game.is_running {
        prev_ticks_for_frame_delta := game._previous_ticks 
        
        game_run_one_frame(game) 
        
        // Update game_time_for_current_frame (used by Draw)
        current_ticks_for_frame_delta := sdl2.GetPerformanceCounter()
        delta_for_draw_hack := current_ticks_for_frame_delta - prev_ticks_for_frame_delta
        actual_frame_delta := time.Duration( (f64(delta_for_draw_hack) * f64(time.Second)) / f64(game._perf_frequency) )
        
        game_time_for_current_frame.elapsed = game.is_fixed_time_step ? game.target_elapsed_time : actual_frame_delta
        game_time_for_current_frame.total = game.game_time.total 
        game_time_for_current_frame.is_running_slowly = game._suppress_draw
    }

    log.info("Game loop ended.")
    if game.Unload_Content != nil { game.Unload_Content(game) } // User can override
    if game.End_Run != nil { game.End_Run(game) } // User can override

    // Cleanup
    if game.graphics_device_manager != nil {
        graphics.destroy_graphics_device_manager(game.graphics_device_manager)
        game.graphics_device_manager = nil
        game.graphics_device = nil // Was a reference from GDM
        // game.window's SDL part is destroyed by GDM if GDM created it.
        // If Game.window is a separate struct, free it if Game allocated it.
        // Current GDM.destroy frees its internal graphics_device which includes _gfx_window and _gfx_device.
        // The SDL_Window itself, if created by GDM, should be handled there too.
        // The current GDM.destroy_graphics_device_manager does not destroy the SDL window.
        // That is deferred in game_run. This is correct.
    }
    // Content manager would be destroyed here
    if game.content != nil { 
        content.destroy_content_manager(game.content)
        game.content = nil 
    }
    // Destroy Audio System
    if game.media_player != nil {
        audio.media_player_destroy(game.media_player)
        game.media_player = nil
    }
    if game.audio_engine != nil {
        audio.audio_engine_destroy(game.audio_engine)
        game.audio_engine = nil
    }
    
    delete(game.components)
    delete(game.services) // Services map might be deprecated if using a proper Service_Container
    // Game struct itself is usually freed by the caller of game_run (e.g. main in example)
}


game_exit :: proc(game: ^Game) {
    if game != nil {
        log.info("Game.Exit called.")
        game.is_running = false
    }
}

// --- Helper for old examples ---
// This `run` procedure is kept for compatibility with the old example structure for now.
// New games should use `new_game()` and then `game_run(my_game_instance, ...)`
// or directly create their own `Game` struct and call `game_run`.
// This will be removed once examples are updated.
run :: proc(
    title: string, 
    width, height: int,
    initialize_fn_old: proc(game_old_style: rawptr), // Placeholder for old signature
    load_content_fn_old: proc(game_old_style: rawptr),
    update_fn_old: proc(game_old_style: rawptr, game_time_old_style: rawptr),
    draw_fn_old: proc(game_old_style: rawptr, game_time_old_style: rawptr),
    preferred_backend_type := graphics.Backend_Type.Auto,
) {
    log.warn("Using DEPRECATED core.run function. Update to new Game structure and game_run.")
    
    // This is a temporary bridge. A proper solution would be for the example
    // to adopt the new Game struct and its methods.
    // For now, we create a new Game and try to map old callbacks if possible,
    // but this is very limited as the signatures don't match well.

    // game_instance := new_game()
    // game_instance.Initialize = proc(g: ^Game) { if initialize_fn_old != nil { initialize_fn_old(cast(rawptr)g) } }
    // game_instance.Load_Content = proc(g: ^Game) { if load_content_fn_old != nil { load_content_fn_old(cast(rawptr)g) } }
    // game_instance.Update = proc(g: ^Game, gt: Game_Time) { if update_fn_old != nil { update_fn_old(cast(rawptr)g, cast(rawptr)&gt) } }
    // game_instance.Draw = proc(g: ^Game, gt: Game_Time) { if draw_fn_old != nil { draw_fn_old(cast(rawptr)g, cast(rawptr)&gt) } }
    
    // game_run(game_instance, title, width, height, preferred_backend_type)
    // free(game_instance) // If new_game allocates it and main doesn't.

    fmt.eprintln("Deprecated core.run called. Functionality removed. Please update to use new Game object and game_run.")
}
// Remove run_with_options as it's also part of the old system.
// The new main entry point is game_run(game: ^Game, ...) after game is created with new_game().

// Public way to exit the game from user code (already defined as game_exit)
// exit :: proc(game: ^Game) { ... }


// --- Utility functions (previously in core.window or similar) ---
// These should eventually be methods on Game_Window or provided by Graphics_Device_Manager / Graphics_Device
get_window_width :: proc(window: ^graphics.Game_Window) -> int {
    if window != nil { return window.width }
    return 0
}
get_window_height :: proc(window: ^graphics.Game_Window) -> int {
    if window != nil { return window.height }
    return 0
}
// is_valid for Gfx_Device and Gfx_Window placeholder
is_valid :: proc(device: graphics.Gfx_Device) -> bool { return false } // Placeholder
// is_valid_window :: proc(window: graphics.Gfx_Window) -> bool { return false } // Placeholder

// Default clear options (placeholder, to be moved or part of Graphics_Device)
default_clear_options :: proc() -> graphics.Clear_Options {
    return graphics.Clear_Options{color = {0.1, 0.1, 0.1, 1.0}, clear_color=true, clear_depth=true, depth=1.0}
}
