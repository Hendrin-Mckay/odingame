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

// Global game variables
player_texture: ^ogfx.Texture2D // Changed to pointer to new Texture2D struct
player_pos: omath.Vector2f
player_speed: f32 = 200.0 // pixels per second

// --- Game Functions ---

game_initialize :: proc(game: ^ocore.Game) {
    fmt.println("Game Initialize")
    // game specific initialization if any
}

game_load_content :: proc(game: ^ocore.Game) {
    fmt.println("Game Load Content")
    // Use the new texture loading function which requires Gfx_Device
    // The asset path should be relative to the executable or an assets directory.
    // Assuming "assets/sprite.png" is the correct path relative to where the example is run from.
    // The README.md for OdinGame main project shows "assets/sprite.png" for its example.
    asset_path := "assets/sprite.png" 
    // If running from `odingame/examples/simple_game`, path might be "../../assets/sprite.png" if assets is at root.
    // For now, let's assume 'assets/sprite.png' will be found if CWD is odingame root.
    // For a more robust solution, the example could try multiple relative paths or require assets to be copied.
    // The original example used "examples/simple_game/sprite.png"
    
    // Corrected path assuming CWD is odingame root, or assets are copied to example dir.
    // For this test, let's use a path that is usually valid when running from example dir.
    // The original example likely assumed CWD was the example dir.
    // For now, to match the prior structure of the example:
    texture_file_path := "sprite.png" // Assumes sprite.png is next to the executable or found via search paths.
                                      // Or, more robustly: "examples/simple_game/sprite.png" if CWD is repo root.
                                      // Let's use "examples/simple_game/sprite.png" for consistency with prior code.
    // Content_Manager's root is "assets" by default in core.Game.
    // So, "sprite.png" will look for "assets/sprite.png".
    // If the example's assets are in "examples/simple_game/assets/", then Content_Manager root should be set accordingly,
    // or the asset path here should be "examples/simple_game/sprite.png".
    // For now, let's assume the asset is located at "assets/sprite.png" relative to executable,
    // and ContentManager root is "assets".
    asset_to_load := "sprite.png" // This will be searched as "assets/sprite.png"

    tex, err := ocontent.content_load_texture2D(game.content, asset_to_load)
    if err != .None { 
        fmt.eprintln("Failed to load texture '", asset_to_load, "': ", ocommon.engine_error_to_string(err))
        // player_texture remains nil
    } else {
        player_texture = tex // tex is ^ogfx.Texture2D
        fmt.println("Loaded texture '", asset_to_load, "' successfully!")
    }
    
    player_w: f32 = 0
    player_h: f32 = 0
    // Use the new Texture2D struct fields and check if pointer is nil
    if player_texture != nil && !ogfx.is_texture_disposed(player_texture) {
        player_w = f32(player_texture.width)
        player_h = f32(player_texture.height)
    }

    player_pos = omath.Vector2f{
        f32(ocore.get_window_width(game.window))/2 - player_w/2, 
        f32(ocore.get_window_height(game.window))/2 - player_h/2,
    }
}

game_update :: proc(game: ^ocore.Game, game_time: ocore.GameTime) {
    delta_time := f32(game_time.elapsed_game_time)
    move_amount := player_speed * delta_time

    // Input uses the new XNA-style input API
    kb_state := oinput.keyboard_get_state()

    if oinput.keyboard_state_is_key_down(kb_state, .Left) {
        player_pos.x -= move_amount
    }
    if oinput.keyboard_state_is_key_down(kb_state, .Right) {
        player_pos.x += move_amount
    }
    if oinput.keyboard_state_is_key_down(kb_state, .Up) {
        player_pos.y -= move_amount
    }
    if oinput.keyboard_state_is_key_down(kb_state, .Down) {
        player_pos.y += move_amount
    }
    
    // Example of using "is_key_pressed" for a one-shot action
    // if oinput.keyboard_is_key_pressed(.Space) {
    //    fmt.println("Space pressed this frame!")
    // }


    // Boundaries (simple wrap around for now)
    // Ensure player_pos does not go too far off screen before wrapping
    player_w := f32(0)
    player_h := f32(0)
    if player_texture != nil && !ogfx.is_texture_disposed(player_texture) {
        player_w = f32(player_texture.width)
        player_h = f32(player_texture.height)
    }

    window_w := f32(ocore.get_window_width(game.window))
    window_h := f32(ocore.get_window_height(game.window))

    if player_pos.x + player_w < 0 { player_pos.x = window_w }
    if player_pos.x > window_w { player_pos.x = -player_w }
    if player_pos.y + player_h < 0 { player_pos.y = window_h }
    if player_pos.y > window_h { player_pos.y = -player_h }

    // Use the new "is_key_pressed" which checks current vs previous state
    if oinput.keyboard_is_key_pressed(.Escape) { // Note: .Escape not .ESCAPE for Keys enum
        ocore.exit(game)
    }
}

game_draw :: proc(game: ^ocore.Game, game_time: ocore.GameTime) {
    // Clear screen using gfx_api
    // Cornflower Blue: R=100, G=149, B=237 -> normalized: 0.39, 0.58, 0.93
    clear_color := [4]f32{100/255, 149/255, 237/255, 1.0}
    clear_options := ogfx.Clear_Options{
        color = clear_color,
        clear_color = true,
        clear_depth = true, // Assuming depth buffer is used or available
        depth = 1.0,
    }
    ogfx.clear_screen(game.window.gfx_device, game.window.gfx_window, {.Cornflower_Blue}) // Use named color

    // Begin SpriteBatch with an orthographic projection
    proj_matrix := linalg.orthographic_rh_zo(
        0, 
        f32(ocore.get_window_width(game.window)), 
        f32(ocore.get_window_height(game.window)), 
        0, 
        -1, 
        1,
    )
    // For XNA-like SpriteBatch, Begin takes parameters. Using defaults for now.
    // The matrix is passed to Begin.
    ogfx.sprite_batch_begin(game.sprite_batch, transform_matrix = proj_matrix)

    if player_texture != nil && !ogfx.is_texture_disposed(player_texture) {
        // Draw player sprite using the new SpriteBatch draw_texture method
        // This now needs to take ^ogfx.Texture2D
        ogfx.sprite_batch_draw_texture(game.sprite_batch, player_texture, player_pos, ocore.WHITE)
    } else {
        // Player texture not loaded or invalid
    }
    
    ogfx.sprite_batch_end(game.sprite_batch)

    // Present the window using gfx_api
    ogfx.present_window(game.window.gfx_window) // Use the direct present_window from graphics package
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
