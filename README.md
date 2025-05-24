# OdinGame

A modern, cross-platform game development framework for the [Odin Programming Language](https://odin-lang.org/) that shares similarities with XNA/FNA/MONOGAME but with a focus on performance and modern graphics APIs.

## Features

- **Cross-Platform Support**: Windows, macOS, and Linux
- **Multiple Graphics Backends**:
  - OpenGL (fully implemented)
  - Vulkan (fully implemented)
  - DirectX (Windows only, experimental support)
  - Metal (macOS only, experimental support)
- **Automatic Backend Selection**: Chooses the best available graphics API for the current platform
- **Sprite Rendering**: Efficient 2D sprite batching system
- **Input Handling**: Keyboard, mouse, and gamepad support
- **Window Management**: Create and manage game windows with support for high DPI displays
- **Asset Loading**: Load textures, sounds, and other assets
- **Game Loop**: Simple game loop with fixed timestep

## Getting Started

### Prerequisites

- [Odin Compiler](https://odin-lang.org/docs/install/) (latest version recommended)
- Graphics drivers supporting OpenGL 3.3+ or Vulkan 1.0+

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/Hendrin-Mckay/odingame.git
   ```

2. Build the example:
   ```bash
   cd odingame/examples/simple_game
   odin build . -out:simple_game_example
   ```

### Basic Example

```odin
package main

import "core:math"
import "../../odingame/core"
import "../../odingame/graphics" // For graphics.gfx_api, graphics.default_clear_options() etc.
import "../../odingame/types"

// Game state
Game_State :: struct {
    using game: ^core.Game, // Provides easy access to game fields like sprite_batch, window
    texture: graphics.Gfx_Texture,
}

// Initialize the game
initialize :: proc(game: ^core.Game) {
    state := new(Game_State)
    state.game = game
    game.user_data = state // Store our game state in the user_data pointer
}

// Load game content
load_content :: proc(game: ^core.Game) {
    state := cast(^Game_State)game.user_data
    
    // Load a texture
    texture, err := graphics.load_texture_from_file(game.window.gfx_device, "assets/sprite.png")
    if err != .None {
        core.exit(game) // Use core.exit to signal game termination
        return
    }
    state.texture = texture
}

// Update game logic (game_time is now accessed via game.game_time)
update :: proc(game: ^core.Game) {
    // Handle input and update game state here
    // Example: if input.is_key_pressed(.Escape) { core.exit(game) }
}

// Draw the game (game_time is now accessed via game.game_time)
draw :: proc(game: ^core.Game) {
    state := cast(^Game_State)game.user_data
    
    // Clear the screen using the Gfx_Device_Interface
    opts := graphics.default_clear_options()
    opts.color = [4]f32{0.1, 0.1, 0.1, 1.0} // Dark gray, matching default_clear_options for this example
    // For pure black, you could use: opts.color = types.BLACK_F32VEC4 or [4]f32{0,0,0,1}
    // Ensure types.BLACK_F32VEC4 is defined in your types module if you use it, e.g. types.BLACK_F32VEC4 :: [4]f32{0,0,0,1}
    graphics.gfx_api.clear_screen(game.window.gfx_device, opts)
    
    // Define a simple orthographic projection matrix
    projection_matrix := math.orthographic_projection_2d(
        0,                                 // left
        f32(game.window.width),            // right
        f32(game.window.height),           // bottom
        0,                                 // top
        -1,                                // near
        1,                                 // far
    )
    
    // Begin drawing sprites
    graphics.begin_batch(game.sprite_batch, projection_matrix)
    
    // Draw a sprite at position (100, 100)
    graphics.draw_texture(game.sprite_batch, state.texture, types.Vector2{100, 100})
    
    // End drawing sprites
    graphics.end_batch(game.sprite_batch)
}

main :: proc() {
    // Run the game by directly passing callback functions
    core.run(
        "My First OdinGame", 
        800, 
        600, 
        initialize, 
        load_content, 
        update, 
        draw,
    )
}
```

## Architecture

OdinGame is designed with a modular architecture that separates different concerns:

- **Core**: Game loop, window management, and basic game structure
- **Graphics**: Rendering system with multiple backend support (OpenGL, Vulkan, DirectX, Metal)
- **Input**: Input handling for keyboard, mouse, and gamepads
- **Types**: Common types used throughout the framework (Vector2, Color, etc.)
- **Common**: Shared utilities and error handling

### Graphics Backend Selection

OdinGame automatically selects the best available graphics backend for the current platform:

1. On Windows: DirectX > Vulkan > OpenGL
2. On macOS: Metal > OpenGL
3. On Linux: Vulkan > OpenGL

The preferred backend can also be influenced by passing `Backend_Settings` to `core.run` or by an explicit call to `graphics.initialize_graphics_backend` before `core.run` if more control over fallback order is needed.

## API Reference

See the [API Documentation](docs/api.md) for detailed information on all available functions and types.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the GNU Lesser General Public License v2.1 (LGPL-2.1) - see the LICENSE file for details.
