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
import ocommon "../../odingame/common" // Added for common.Engine_Error
import "core:math/linalg" // For orthographic_rh_zo

// Global game variables
player_texture: ogfx.Gfx_Texture // Changed from ^ogfx.Texture2D
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
    // load_texture_from_file_gfx was defined in odingame/graphics/texture.odin
    tex, err := ogfx.load_texture_from_file_gfx(game.window.gfx_device, "examples/simple_game/sprite.png")
    if err != .None { // Now comparing with common.Engine_Error.None (implicitly, as .None is universal)
        fmt.eprintln("Failed to load texture 'examples/simple_game/sprite.png':", ocommon.engine_error_to_string(err))
        // Attempt to load the placeholder text file name (this will also likely fail with the new loader)
        _, err_txt := ogfx.load_texture_from_file_gfx(game.window.gfx_device, "examples/simple_game/sprite.png.txt")
        if err_txt != .None {
             fmt.eprintln("Also failed to load 'examples/simple_game/sprite.png.txt':", ocommon.engine_error_to_string(err_txt))
        } else {
            // This case should ideally not be hit. If it were, destroy the unwanted texture.
            // Assuming _ is the handle, which is not stored here.
            // This part of the logic might need rethinking if .txt could be valid.
            fmt.println("Note: Placeholder 'sprite.png.txt' was loaded but is not a usable texture (this is unexpected).")
        }
        // player_texture remains an uninitialized Gfx_Texture, draw function should handle this
    } else {
        player_texture = tex
        fmt.println("Loaded texture 'examples/simple_game/sprite.png' successfully!")
    }
    
    player_w: f32 = 0
    player_h: f32 = 0
    if ogfx.is_gfx_texture_valid(player_texture) { // Use new validity check
        player_w = f32(ogfx.gfx_api.get_texture_width(player_texture))
        player_h = f32(ogfx.gfx_api.get_texture_height(player_texture))
    }

    player_pos = omath.Vector2f{
        f32(ocore.get_window_width(game.window))/2 - player_w/2, 
        f32(ocore.get_window_height(game.window))/2 - player_h/2,
    }
}

game_update :: proc(game: ^ocore.Game, game_time: ocore.GameTime) {
    delta_time := f32(game_time.elapsed_game_time)
    move_amount := player_speed * delta_time

    // Input uses sdl2.Scancode directly via the oinput.Key alias
    if oinput.is_key_down(.LEFT) { // e.g. oinput.Key.LEFT which is sdl2.Scancode.LEFT
        player_pos.x -= move_amount
    }
    if oinput.is_key_down(.RIGHT) {
        player_pos.x += move_amount
    }
    if oinput.is_key_down(.UP) {
        player_pos.y -= move_amount
    }
    if oinput.is_key_down(.DOWN) {
        player_pos.y += move_amount
    }

    // Boundaries (simple wrap around for now)
    // Ensure player_pos does not go too far off screen before wrapping
    player_w := f32(0)
    player_h := f32(0)
    if ogfx.is_gfx_texture_valid(player_texture) {
        player_w = f32(ogfx.gfx_api.get_texture_width(player_texture))
        player_h = f32(ogfx.gfx_api.get_texture_height(player_texture))
    }

    window_w := f32(ocore.get_window_width(game.window))
    window_h := f32(ocore.get_window_height(game.window))

    if player_pos.x + player_w < 0 { player_pos.x = window_w }
    if player_pos.x > window_w { player_pos.x = -player_w }
    if player_pos.y + player_h < 0 { player_pos.y = window_h }
    if player_pos.y > window_h { player_pos.y = -player_h }


    if oinput.is_key_pressed(.ESCAPE) {
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
    ogfx.gfx_api.clear_screen(game.window.gfx_device, clear_options)

    // Begin SpriteBatch with an orthographic projection
    proj_matrix := linalg.orthographic_rh_zo(
        0, 
        f32(ocore.get_window_width(game.window)), 
        f32(ocore.get_window_height(game.window)), 
        0, 
        -1, 
        1,
    )
    ogfx.begin_batch(game.sprite_batch, proj_matrix)

    if ogfx.is_gfx_texture_valid(player_texture) {
        // Draw player sprite using the new SpriteBatch draw_texture method
        // `ocore.WHITE` should be a `ocore.Color` struct {r,g,b,a: u8}
        ogfx.draw_texture(game.sprite_batch, player_texture, player_pos, ocore.WHITE)
    } else {
        // Player texture not loaded or invalid
    }
    
    ogfx.end_batch(game.sprite_batch)

    // Present the window using gfx_api
    ogfx.gfx_api.present_window(game.window.gfx_window)
}

// --- Main ---
main :: proc() {
    // The core.run function will handle all SDL initialization and shutdown.
    ocore.run(
        "Simple Odingame Example", // Window Title
        800,                       // Window Width
        600,                       // Window Height
        game_initialize,
        game_load_content,
        game_update,
        game_draw,
    )
    fmt.println("Exited game.")
}
