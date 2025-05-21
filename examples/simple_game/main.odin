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

// Global game variables
player_texture: ^ogfx.Texture2D
player_pos: omath.Vector2f
player_speed: f32 = 200.0 // pixels per second

// --- Game Functions ---

game_initialize :: proc(game: ^ocore.Game) {
    fmt.println("Game Initialize")
    // game specific initialization if any
}

game_load_content :: proc(game: ^ocore.Game) {
    fmt.println("Game Load Content")
    // Try loading sprite.png first, then sprite.png.txt as a fallback for this example
    tex, err := ogfx.texture_from_file("examples/simple_game/sprite.png") 
    if err != nil {
        fmt.eprintln("Failed to load texture 'examples/simple_game/sprite.png':", err)
        // Attempt to load the placeholder text file name, just to acknowledge it.
        // The actual texture_from_file will likely fail for a .txt, which is fine.
        tex_txt, err_txt := ogfx.texture_from_file("examples/simple_game/sprite.png.txt")
        if err_txt != nil {
             fmt.eprintln("Also failed to load 'examples/simple_game/sprite.png.txt':", err_txt)
        } else {
            // This case should ideally not be hit if .txt is not a valid image.
            // If it were, we'd free it as it's not the intended sprite.
            ogfx.destroy_texture(tex_txt) 
            fmt.println("Note: Placeholder 'sprite.png.txt' was loaded but is not a usable texture.")
        }
        // Player texture will remain nil, draw function should handle this
    } else {
        player_texture = tex
        fmt.println("Loaded texture 'examples/simple_game/sprite.png' successfully!")
    }
    
    // Initial position: center of the game window
    player_pos = omath.Vector2f{
        f32(game.window.width)/2, 
        f32(game.window.height)/2,
    }
    // Adjust position to center the sprite, if texture was loaded
    if player_texture != nil { 
         player_pos.x -= f32(player_texture.width)/2
         player_pos.y -= f32(player_texture.height)/2
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
    if player_texture != nil {
        player_w = f32(player_texture.width)
        player_h = f32(player_texture.height)
    }

    if player_pos.x + player_w < 0 { player_pos.x = f32(game.window.width) }
    if player_pos.x > f32(game.window.width) { player_pos.x = -player_w }
    if player_pos.y + player_h < 0 { player_pos.y = f32(game.window.height) }
    if player_pos.y > f32(game.window.height) { player_pos.y = -player_h }


    if oinput.is_key_pressed(.ESCAPE) {
        ocore.exit(game)
    }
}

game_draw :: proc(game: ^ocore.Game, game_time: ocore.GameTime) {
    ogfx.clear(game.graphics_device, ogfx.CORNFLOWER_BLUE)

    ogfx.begin(game.sprite_batch, nil) // Use default orthographic projection (identity model-view)

    if player_texture != nil && player_texture.gl_id != 0 {
        // Draw player sprite
        ogfx.draw_simple(game.sprite_batch, player_texture, player_pos, ogfx.WHITE)
    } else {
        // Optionally, print a message to screen or draw a placeholder rect
        // For now, just prints to console via game_load_content's error message
    }
    
    ogfx.end(game.sprite_batch)
    ogfx.present(game.graphics_device, game.window)
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
