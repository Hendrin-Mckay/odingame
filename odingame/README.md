# Odingame Framework

## Overview

Odingame is a game development framework for the Odin programming language, inspired by XNA, MonoGame, and FNA. It aims to provide a simple and effective way to create 2D games in Odin.

This is an initial version focusing on the core functionalities.

## Core Features

- **Windowing:** Creation and management of the game window.
- **Graphics Device:** Basic OpenGL context initialization and control.
- **SpriteBatch:** Efficient 2D sprite rendering with transformations (position, scale, rotation - Note: current SpriteBatch is immediate mode).
- **Texture Loading:** Loading `Texture2D` assets from image files (e.g., PNG via SDL_image).
- **Input Handling:** Processing keyboard and mouse input.
- **Game Loop:** Structured `Initialize`, `LoadContent`, `Update`, `Draw` game loop.
- **Basic Math Types:** Essential math types like `Vector2f`, `Matrix4f`, `Recti`.

## Core API Overview

The framework is organized into several packages (collections in Odin terms):

### `core.Game`
The heart of your game.
- `core.run(title, width, height, initialize_fn, load_content_fn, update_fn, draw_fn)`: Starts the game. You provide your game's specific logic through the function parameters.
- `core.exit(game: ^core.Game)`: Call this from your game logic to quit the game.
- **User-defined Functions:**
  - `InitializeFn: proc(game: ^core.Game)`: Called once at the start to initialize game-specific data.
  - `LoadContentFn: proc(game: ^core.Game)`: Called once after Initialize to load game assets.
  - `UpdateFn: proc(game: ^core.Game, game_time: core.GameTime)`: Called every frame to update game logic.
  - `DrawFn: proc(game: ^core.Game, game_time: core.GameTime)`: Called every frame to draw the game.
- `core.GameTime`: Provides `elapsed_game_time` and `total_game_time`.

### `graphics.Device`
Manages the underlying graphics context.
- `graphics.clear(dev: ^graphics.Device, color: graphics.Color)`: Clears the screen to a specified color.
- `graphics.present(dev: ^graphics.Device, window: ^core.Window)`: Swaps the back buffer to the front, displaying the rendered frame.

### `graphics.SpriteBatch`
Used for drawing 2D sprites.
- `graphics.new_sprite_batch(dev: ^graphics.Device, window_width, window_height: int) -> (^graphics.SpriteBatch, error)`: Creates a new sprite batcher.
- `graphics.begin(sb: ^graphics.SpriteBatch, model_view_matrix: Maybe(math.Matrix4f))`: Prepares for drawing sprites. An optional custom model-view matrix can be supplied.
- `graphics.draw(sb: ^graphics.SpriteBatch, texture: ^graphics.Texture2D, position: math.Vector2f, source_rect: Maybe(math.Recti), color: graphics.Color, rotation_radians: f32, origin: math.Vector2f, scale: math.Vector2f)`: Draws a sprite with full transformation options.
- `graphics.draw_simple(sb: ^graphics.SpriteBatch, texture: ^graphics.Texture2D, position: math.Vector2f, color: graphics.Color)`: Simplified draw call.
- `graphics.end(sb: ^graphics.SpriteBatch)`: Flushes any batched sprites and finalizes drawing for the current batch.

### `graphics.Texture2D`
Represents a 2D texture.
- `graphics.texture_from_file(filepath: string) -> (^graphics.Texture2D, error)`: Loads a texture from an image file.

### `input`
Provides access to keyboard and mouse state.
- `input.is_key_down(key: input.Key) -> bool`
- `input.is_key_pressed(key: input.Key) -> bool` (true only on the frame it's first pressed)
- `input.is_key_released(key: input.Key) -> bool` (true only on the frame it's first released)
- `input.get_mouse_position() -> (x: i32, y: i32)`
- `input.is_mouse_button_down(button_index: int) -> bool` (0:left, 1:middle, 2:right)
- `input.is_mouse_button_pressed(button_index: int) -> bool`
- `input.get_mouse_scroll_delta() -> (dx: i32, dy: i32)`

### `math`
Contains basic math types.
- `math.Vector2f`, `math.Vector2i`
- `math.Rectf`, `math.Recti`
- `math.Matrix4f`
- Helper functions like `math.orthographic_projection`.

## How to Structure Your Game

1.  Create a `main.odin` file.
2.  Implement your game's logic within four main functions: `my_initialize`, `my_load_content`, `my_update`, and `my_draw`.
3.  In your `main` procedure, call `core.run("My Game Title", window_width, window_height, my_initialize, my_load_content, my_update, my_draw)`.

## Building an Odingame Project

- You will need the Odin compiler.
- Ensure you have SDL2 (and SDL2_image) development libraries installed and accessible by the Odin compiler.
- To build your game, you would typically run a command like:
  `odin build <path_to_your_game_main_odin_dir> -collection:odingame=<path_to_odingame_framework_dir>`
  (Replace paths as appropriate). For example, if `odingame` is a collection located at `../odingame_src`, you might use `-collection:odingame=../odingame_src`.

---
*This framework is currently in its early stages of development.*
