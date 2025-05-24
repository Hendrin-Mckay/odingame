package main

import "core:fmt" 
// Adjust import path based on how odingame will be structured as a library
// Assuming odingame is a collection or directly accessible via relative paths for now
// If odingame is in a parent dir: import "../../odingame/core" etc.
// For now, let's assume it's setup to be found via a collection path like "odingame:core"
// This might require setting up ODIN_ROOT or specific collection configurations when building.
// For the subtask, assume the following paths work if odingame is in the root of the repo:
import ocore "../../odingame/core"
import ogfx "../../odingame/graphics"
import oinput "../../odingame/input"
import omath "../../odingame/math"
import ocommon "../../odingame/common" 
import "core:math/linalg" 
import "core:os" // For command line arguments
import ocontent "../../odingame/content" // Import Content_Manager package

// MyGame struct to hold game state
MyGame :: struct {
    using game:    ^ocore.Game,     // Access to core game object
    texture:       ^ogfx.Texture2D, // Player's texture
    pos:           omath.Vector2f,  // Player's position
    player_speed:  f32,             // Player's movement speed
}

// Player speed constant (can be part of MyGame or remain global if truly constant)
// For this refactor, player_speed is moved into MyGame.
// PLAYER_SPEED :: 200.0 // pixels per second // Example if it were a constant

// --- Game Functions ---

game_initialize :: proc(game: ^ocore.Game) {
    fmt.println("Game Initialize")
    // Allocate and initialize MyGame state
    game.user_data = new(MyGame)
    state := (^MyGame)(game.user_data)
    state.game = game // Set the 'using game' field
    state.player_speed = 200.0 // Initialize player_speed from the former global
    // state.texture will be loaded in game_load_content
    // state.pos will be initialized in game_load_content after texture is loaded
}

game_load_content :: proc(game: ^ocore.Game) {
    fmt.println("Game Load Content")
    state := (^MyGame)(game.user_data)

    // Asset path (assuming "assets/sprite.png" relative to where content manager looks)
    asset_to_load := "sprite.png" 

    tex, err := ocontent.content_load_texture2D(state.content, asset_to_load) // Use state.content
    if err != .None { 
        fmt.eprintln("Failed to load texture '", asset_to_load, "': ", ocommon.engine_error_to_string(err))
        state.texture = nil // Ensure texture is nil on failure
    } else {
        state.texture = tex
        fmt.println("Loaded texture '", asset_to_load, "' successfully!")
    }
    
    player_w: f32 = 0
    player_h: f32 = 0
    if state.texture != nil && !ogfx.is_texture_disposed(state.texture) {
        player_w = f32(state.texture.width)
        player_h = f32(state.texture.height)
    }

    // Initialize player position using window dimensions from state.window
    state.pos = omath.Vector2f{
        f32(ocore.get_window_width(state.window))/2 - player_w/2, 
        f32(ocore.get_window_height(state.window))/2 - player_h/2,
    }
}

game_update :: proc(game: ^ocore.Game, game_time: ocore.GameTime) {
    state := (^MyGame)(game.user_data)
    delta_time := f32(game_time.elapsed_game_time)
    move_amount := state.player_speed * delta_time // Use state.player_speed

    // Input uses the new XNA-style input API
    // kb_state is obtained via oinput, which doesn't depend on game state directly here.
    // However, if input handling needed game instance, it would be state.input_system or similar.
    kb_state := oinput.keyboard_get_state() 

    if oinput.keyboard_state_is_key_down(kb_state, .Left) {
        state.pos.x -= move_amount // Use state.pos
    }
    if oinput.keyboard_state_is_key_down(kb_state, .Right) {
        state.pos.x += move_amount // Use state.pos
    }
    if oinput.keyboard_state_is_key_down(kb_state, .Up) {
        state.pos.y -= move_amount // Use state.pos
    }
    if oinput.keyboard_state_is_key_down(kb_state, .Down) {
        state.pos.y += move_amount // Use state.pos
    }
    
    // Example of using "is_key_pressed" for a one-shot action
    // if oinput.keyboard_is_key_pressed(.Space) { // Assuming oinput.keyboard_is_key_pressed takes state.input if needed
    //    fmt.println("Space pressed this frame!")
    // }

    // Boundaries (simple wrap around for now)
    player_w := f32(0)
    player_h := f32(0)
    if state.texture != nil && !ogfx.is_texture_disposed(state.texture) { // Use state.texture
        player_w = f32(state.texture.width)
        player_h = f32(state.texture.height)
    }

    // Access window through state.window due to 'using game'
    window_w := f32(ocore.get_window_width(state.window)) 
    window_h := f32(ocore.get_window_height(state.window))

    if state.pos.x + player_w < 0 { state.pos.x = window_w } // Use state.pos
    if state.pos.x > window_w { state.pos.x = -player_w }    // Use state.pos
    if state.pos.y + player_h < 0 { state.pos.y = window_h } // Use state.pos
    if state.pos.y > window_h { state.pos.y = -player_h }    // Use state.pos

    // Use the new "is_key_pressed" which checks current vs previous state
    // oinput.keyboard_is_key_pressed might need state.input if it depends on game instance state.
    // For now, assuming .Escape is a global key state.
    if oinput.keyboard_is_key_pressed(.Escape) { 
        ocore.exit(state.game) // Pass state.game or just state (if 'using game' propagates for ocore.exit)
                               // Safest is state.game as ocore.exit expects ^ocore.Game
    }
}

game_draw :: proc(game: ^ocore.Game, game_time: ocore.GameTime) {
    state := (^MyGame)(game.user_data)

    // Clear screen using gfx_api (via state.graphics_device)
    // Cornflower Blue: R=100, G=149, B=237 -> normalized: 0.39, 0.58, 0.93
    // clear_color := [4]f32{100/255, 149/255, 237/255, 1.0} // This variable is not used if using named color
    // clear_options := ogfx.Clear_Options{ // This variable is not used by graphics_device_clear
    //     color = clear_color,
    //     clear_color = true,
    //     clear_depth = true, 
    //     depth = 1.0,
    // }
    ogfx.graphics_device_clear(state.graphics_device, ocore.Cornflower_Blue, clear_depth=true, clear_stencil=false)

    // Begin SpriteBatch with an orthographic projection (using state.window and state.sprite_batch)
    proj_matrix := linalg.orthographic_rh_zo(
        0, 
        f32(ocore.get_window_width(state.window)), 
        f32(ocore.get_window_height(state.window)), 
        0, 
        -1, 
        1,
    )
    ogfx.sprite_batch_begin(state.sprite_batch, transform_matrix = proj_matrix)

    if state.texture != nil && !ogfx.is_texture_disposed(state.texture) { // Use state.texture
        // Draw player sprite using state.texture and state.pos
        ogfx.sprite_batch_draw_texture(state.sprite_batch, ogfx.get_internal_gfx_texture(state.texture), state.pos, ocore.WHITE)
    } else {
        // Player texture not loaded or invalid
    }
    
    ogfx.sprite_batch_end(state.sprite_batch)

    // Present the window using gfx_api (via state.window)
    ogfx.present_window(state.window.gfx_window)
}

// --- Main ---
main :: proc() {
    preferred_backend := ocore.Graphics_Backend_Type.OpenGL // Default
    
    // Basic command line argument parsing for --backend
    for arg, i in os.args {
        if arg == "--backend" {
            if i + 1 < len(os.args) {
                backend_str := strings.to_lower(os.args[i+1])
                if backend_str == "dx11" || backend_str == "directx11" {
                    preferred_backend = .DirectX11
                } else if backend_str == "metal" { // Added Metal option
                    preferred_backend = .Metal
                } else if backend_str == "opengl" {
                    preferred_backend = .OpenGL
                } else {
                    fmt.eprintf("Warning: Unknown backend '%s' specified. Defaulting to OpenGL.\n", os.args[i+1])
                }
            } else {
                fmt.eprintln("Warning: --backend flag requires an argument (e.g., opengl, dx11). Defaulting to OpenGL.")
            }
            break // Stop after processing --backend
        }
    }
    fmt.printf("Attempting to initialize with backend: %v\n", preferred_backend)

    ocore.run_with_options(ocore.Game_Run_Options{
        title = "Simple Odingame Example",
        width = 800,
        height = 600,
        initialize_fn = game_initialize,
        load_content_fn = game_load_content,
        update_fn = game_update,
        draw_fn = game_draw,
        preferred_backend = preferred_backend,
    })
    // The core.run function will handle all SDL initialization and shutdown.
    // ocore.run(
    //     "Simple Odingame Example", // Window Title
    //     800,                       // Window Width
    //     600,                       // Window Height
        game_initialize,
        game_load_content,
        game_update,
        game_draw,
    )
    fmt.println("Exited game.")
}
