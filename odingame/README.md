# Odingame Framework

## Overview

Odingame is a game development framework for the Odin programming language, inspired by XNA, MonoGame, and FNA. It aims to provide a simple and effective way to create 2D games in Odin.

This is an initial version focusing on the core functionalities.

## Core Features

- **Windowing:** Creation and management of the game window.
- **Graphics Device:** Abstracted graphics device operations via `Gfx_Device_Interface`, supporting multiple backends (OpenGL, Vulkan, with experimental DirectX/Metal planned).
- **SpriteBatch:** Efficient 2D sprite rendering with transformations (position, scale, rotation) using a retained batching system.
- **Texture Loading:** Loading `Gfx_Texture` assets from image files (e.g., PNG via SDL_image).
- **Input Handling:** Processing keyboard and mouse input.
- **Game Loop:** Structured `Initialize`, `LoadContent`, `Update`, `Draw` game loop.
- **Basic Math Types:** Essential math types like `Vector2`, `Matrix4f`, `Recti`, often aliasing `core:linalg` types.

## Core API Overview

The framework is organized into several packages (collections in Odin terms):

### `core.Game`
The heart of your game.
- `core.run(title, width, height, initialize_fn, load_content_fn, update_fn, draw_fn)`: Starts the game. You provide your game's specific logic through the function parameters.
- `core.exit(game: ^core.Game)`: Call this from your game logic to quit the game.
- **User-defined Functions:**
  - `InitializeFn: proc(game: ^core.Game)`: Called once at the start to initialize game-specific data.
  - `LoadContentFn: proc(game: ^core.Game)`: Called once after Initialize to load game assets.
  - `UpdateFn: proc(game: ^core.Game)`: Called every frame to update game logic. Note: `GameTime` is a member of `^core.Game`.
  - `DrawFn: proc(game: ^core.Game)`: Called every frame to draw the game. Note: `GameTime` is a member of `^core.Game`.
- `core.GameTime`: Provides `elapsed_game_time` (seconds) and `total_game_time` (seconds).

### `graphics` and `gfx_api`
Graphics operations are performed through a global interface `gfx_api: Gfx_Device_Interface`. This interface abstracts backend-specific implementations (OpenGL, Vulkan, etc.). The functions typically operate on handles like `Gfx_Device` and `Gfx_Window` obtained during initialization.

Example operations:
- `gfx_api.clear_screen(game.window.gfx_device, clear_options)`: Clears the screen.
- `gfx_api.present_window(game.window.gfx_window)`: Swaps the back buffer to the front.
- `gfx_api.create_texture(...)`, `gfx_api.destroy_buffer(...)`, etc.

### `graphics.SpriteBatch`
Used for drawing 2D sprites efficiently.
- `graphics.new_spritebatch(device: Gfx_Device, max_sprites: int = MAX_SPRITES_DEFAULT) -> (^SpriteBatch, common.Engine_Error)`: Creates a new sprite batcher.
- `graphics.begin_batch(sb: ^SpriteBatch, projection_view_matrix: math.Matrix4f)`: Prepares for drawing sprites, setting the transformation matrix.
- `graphics.draw_texture(sb: ^SpriteBatch, texture: Gfx_Texture, position: math.Vector2, tint: math.Color = WHITE, origin: math.Vector2 = {0,0}, scale: math.Vector2 = {1,1}, rotation: f32 = 0)`: Draws a full texture.
- `graphics.draw_texture_region(sb: ^SpriteBatch, texture: Gfx_Texture, src_rect: math.Rectangle, dst_rect: math.Rectangle, tint: math.Color = WHITE, origin: math.Vector2 = {0,0}, rotation: f32 = 0)`: Draws a region of a texture.
- `graphics.end_batch(sb: ^SpriteBatch)`: Flushes any batched sprites to the GPU.

### `Gfx_Texture`
Represents a 2D texture.
- `graphics.load_texture_from_file(device: Gfx_Device, filepath: string, generate_mipmaps: bool = true) -> (texture: Gfx_Texture, err: common.Engine_Error)`: Loads a texture from an image file.
- `graphics.destroy_texture(tex: ^Gfx_Texture)`: Releases a reference to the texture.

### `input`
Provides access to keyboard and mouse state.
- `input.is_key_down(key: input.Key) -> bool`
- `input.is_key_pressed(key: input.Key) -> bool` (true only on the frame it's first pressed)
- `input.is_key_released(key: input.Key) -> bool` (true only on the frame it's first released)
- `input.get_mouse_position() -> (x: i32, y: i32)`
- `input.is_mouse_button_down(button_index: int) -> bool` (0:left, 1:middle, 2:right)
- `input.is_mouse_button_pressed(button_index: int) -> bool`
- `input.get_mouse_scroll_delta() -> (dx: i32, dy: i32)`
- `input.is_quit_requested() -> bool`

### `types` and `core:math`
The `types` package provides common data structures like `Vector2`, `Color`, `Rectf`, `Recti`, `Matrix4f`, often aliasing or based on types from `core:math`. Users can directly leverage `core:math` for more advanced mathematical operations.

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
