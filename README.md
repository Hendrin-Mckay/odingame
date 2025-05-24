# OdinGame

A modern, cross-platform game development framework for the [Odin Programming Language](https://odin-lang.org/) that shares similarities with PyGame but with a focus on performance and modern graphics APIs.

## Features

- **Cross-Platform Support**: Windows, macOS, and Linux
- **Multiple Graphics Backends**:
  - OpenGL (fully implemented)
  - Vulkan (fully implemented)
  - DirectX (Windows only, stub implementation - **not yet functional**)
  - Metal (macOS only, stub implementation - **not yet functional**)
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
   git clone https://github.com/yourusername/odingame.git
   ```

2. Build the example:
   ```bash
   cd odingame/examples/basic
   odin build . -out:basic_example
   ```

### Basic Example

```odin
package main

import "../../odingame/core"
import "../../odingame/graphics"
import "../../odingame/types"

// Game state
Game_State :: struct {
    using game: ^core.Game,
    texture: graphics.Gfx_Texture,
}

// Initialize the game
initialize :: proc(game: ^core.Game) {
    state := new(Game_State)
    state.game = game
    game.user_data = state
}

// Load game content
load_content :: proc(game: ^core.Game) {
    state := cast(^Game_State)game.user_data
    
    // Load a texture
    texture, err := graphics.load_texture(game.window.gfx_device, "assets/sprite.png")
    if err != .None {
        core.exit_game(game)
        return
    }
    state.texture = texture
}

// Update game logic
update :: proc(game: ^core.Game, game_time: core.GameTime) {
    // Handle input and update game state here
}

// Draw the game
draw :: proc(game: ^core.Game, game_time: core.GameTime) {
    state := cast(^Game_State)game.user_data
    
    // Clear the screen
    graphics.clear(game.window.gfx_device, types.BLACK)
    
    // Begin drawing sprites
    graphics.begin(game.sprite_batch)
    
    // Draw a sprite at position (100, 100)
    graphics.draw(game.sprite_batch, state.texture, types.Vector2{100, 100})
    
    // End drawing sprites
    graphics.end(game.sprite_batch)
}

main :: proc() {
    // Create a new game with a 800x600 window
    game := core.create_game("My First OdinGame", 800, 600)
    
    // Set up game callbacks
    game.initialize_fn = initialize
    game.load_content_fn = load_content
    game.update_fn = update
    game.draw_fn = draw
    
    // Run the game
    core.run(game)
    
    // Clean up
    core.destroy_game(game)
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

You can also manually specify a backend using `graphics.Backend_Type` when creating a game.

## API Reference

See the [API Documentation](docs/api.md) for detailed information on all available functions and types.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.
