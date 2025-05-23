# OdinGame API Documentation

This document provides detailed information about the OdinGame API, including modules, types, and functions.

## Table of Contents

- [Core Module](#core-module)
- [Graphics Module](#graphics-module)
- [Input Module](#input-module)
- [Types Module](#types-module)
- [Common Module](#common-module)

## Core Module

The Core module handles the game loop, window management, and basic game structure.

### Types

#### Game

```odin
Game :: struct {
    window:          ^Window,
    sprite_batch:    ^graphics.SpriteBatch,
    initialize_fn:   InitializeFn,
    load_content_fn: LoadContentFn,
    update_fn:       UpdateFn,
    draw_fn:         DrawFn,
    running:         bool,
    game_time:       GameTime,
    _previous_ticks: u64,
    _perf_frequency: u64,
}
```

The main game structure that holds the game state and callbacks.

#### GameTime

```odin
GameTime :: struct {
    elapsed_game_time: f64, // Seconds
    total_game_time:   f64, // Seconds
}
```

Provides timing information for the game loop.

#### Window

```odin
Window :: struct {
    gfx_device: graphics.Gfx_Device,
    gfx_window: graphics.Gfx_Window,
    title:      string,
    width:      int,
    height:     int,
}
```

Represents a game window.

### Functions

#### create_game

```odin
create_game :: proc(title: string, width, height: int, backend_type: graphics.Backend_Type = .Auto) -> ^Game
```

Creates a new game instance with the specified window title, width, and height.

**Parameters:**
- `title`: The title of the game window
- `width`: The width of the game window in pixels
- `height`: The height of the game window in pixels
- `backend_type`: The graphics backend to use (default: Auto)

**Returns:**
- A pointer to the created Game instance

#### run

```odin
run :: proc(game: ^Game) -> common.Engine_Error
```

Runs the game loop until the game is exited.

**Parameters:**
- `game`: The game instance to run

**Returns:**
- An Engine_Error indicating success or failure

#### exit_game

```odin
exit_game :: proc(game: ^Game)
```

Exits the game by setting the running flag to false.

**Parameters:**
- `game`: The game instance to exit

#### destroy_game

```odin
destroy_game :: proc(game: ^Game)
```

Cleans up resources used by the game.

**Parameters:**
- `game`: The game instance to destroy

## Graphics Module

The Graphics module handles rendering and graphics-related operations.

### Types

#### Backend_Type

```odin
Backend_Type :: enum {
    Auto,    // Automatically select the best backend
    OpenGL,  // Use OpenGL backend
    Vulkan,  // Use Vulkan backend
    DirectX, // Use DirectX backend (Windows only)
    Metal,   // Use Metal backend (macOS only)
}
```

Specifies the graphics backend to use.

#### Gfx_Device

```odin
Gfx_Device :: struct_variant {
    opengl: ^Gl_Device,
    vulkan: ^Vk_Device,
    directx: ^Dx_Device,
    metal: ^Mtl_Device,
}
```

Represents a graphics device for rendering.

#### Gfx_Window

```odin
Gfx_Window :: struct_variant {
    opengl: ^Gl_Window,
    vulkan: ^Vk_Window,
    directx: ^Dx_Window,
    metal: ^Mtl_Window,
}
```

Represents a window for rendering.

#### SpriteBatch

```odin
SpriteBatch :: struct {
    device: Gfx_Device,
    pipeline: Gfx_Pipeline,
    vertex_buffer: Gfx_Buffer,
    index_buffer: Gfx_Buffer,
    max_sprites: int,
    sprites_in_batch: int,
    vertices: []Vertex,
    indices: []u16,
    active: bool,
}
```

A utility for efficiently rendering multiple sprites in a single draw call.

### Functions

#### create_sprite_batch

```odin
create_sprite_batch :: proc(device: Gfx_Device, max_sprites: int = 1000) -> (^SpriteBatch, common.Engine_Error)
```

Creates a new sprite batch for efficient sprite rendering.

**Parameters:**
- `device`: The graphics device to use
- `max_sprites`: The maximum number of sprites that can be batched (default: 1000)

**Returns:**
- A pointer to the created SpriteBatch and an error code

#### begin

```odin
begin :: proc(batch: ^SpriteBatch)
```

Begins a sprite batch rendering session.

**Parameters:**
- `batch`: The sprite batch to begin

#### draw

```odin
draw :: proc(batch: ^SpriteBatch, texture: Gfx_Texture, position: types.Vector2, source_rect: types.Rectf = {}, color: types.Color = types.WHITE, rotation: f32 = 0, origin: types.Vector2 = {}, scale: types.Vector2 = {1, 1}, effects: Sprite_Effects = .None, layer_depth: f32 = 0)
```

Adds a sprite to the batch for rendering.

**Parameters:**
- `batch`: The sprite batch to draw with
- `texture`: The texture to draw
- `position`: The position to draw at
- `source_rect`: The source rectangle in the texture (default: entire texture)
- `color`: The color tint to apply (default: white)
- `rotation`: The rotation in radians (default: 0)
- `origin`: The origin point for rotation and scaling (default: top-left)
- `scale`: The scale to apply (default: {1, 1})
- `effects`: Sprite effects like flipping (default: None)
- `layer_depth`: The depth for sorting (default: 0)

#### end

```odin
end :: proc(batch: ^SpriteBatch)
```

Ends a sprite batch rendering session and submits the batch for drawing.

**Parameters:**
- `batch`: The sprite batch to end

#### load_texture

```odin
load_texture :: proc(device: Gfx_Device, path: string) -> (Gfx_Texture, common.Engine_Error)
```

Loads a texture from a file.

**Parameters:**
- `device`: The graphics device to use
- `path`: The path to the texture file

**Returns:**
- The loaded texture and an error code

## Input Module

The Input module handles user input from keyboard, mouse, and gamepads.

### Types

#### Key

```odin
Key :: enum {
    Unknown,
    A, B, C, /* ... other keys ... */,
    Escape, F1, F2, /* ... function keys ... */,
    Left, Right, Up, Down, /* ... arrow keys ... */,
}
```

Represents keyboard keys.

#### Mouse_Button

```odin
Mouse_Button :: enum {
    Left,
    Middle,
    Right,
    X1,
    X2,
}
```

Represents mouse buttons.

### Functions

#### is_key_down

```odin
is_key_down :: proc(key: Key) -> bool
```

Checks if a key is currently pressed.

**Parameters:**
- `key`: The key to check

**Returns:**
- True if the key is pressed, false otherwise

#### is_key_pressed

```odin
is_key_pressed :: proc(key: Key) -> bool
```

Checks if a key was pressed this frame.

**Parameters:**
- `key`: The key to check

**Returns:**
- True if the key was pressed this frame, false otherwise

#### is_mouse_button_down

```odin
is_mouse_button_down :: proc(button: Mouse_Button) -> bool
```

Checks if a mouse button is currently pressed.

**Parameters:**
- `button`: The mouse button to check

**Returns:**
- True if the button is pressed, false otherwise

#### get_mouse_position

```odin
get_mouse_position :: proc() -> types.Vector2
```

Gets the current mouse position.

**Returns:**
- The current mouse position as a Vector2

## Types Module

The Types module provides common types used throughout the framework.

### Types

#### Vector2

```odin
Vector2 :: struct { x, y: f32 }
```

Represents a 2D vector.

#### Color

```odin
Color :: struct { r, g, b, a: u8 }
```

Represents a color with red, green, blue, and alpha components.

#### Rectf

```odin
Rectf :: struct { x, y, w, h: f32 }
```

Represents a rectangle with floating-point coordinates.

#### Recti

```odin
Recti :: struct { x, y, w, h: i32 }
```

Represents a rectangle with integer coordinates.

### Constants

```odin
BLACK   :: Color{0, 0, 0, 255}
WHITE   :: Color{255, 255, 255, 255}
RED     :: Color{255, 0, 0, 255}
GREEN   :: Color{0, 255, 0, 255}
BLUE    :: Color{0, 0, 255, 255}
YELLOW  :: Color{255, 255, 0, 255}
MAGENTA :: Color{255, 0, 255, 255}
CYAN    :: Color{0, 255, 255, 255}
```

Predefined colors for convenience.

## Common Module

The Common module provides shared utilities and error handling.

### Types

#### Engine_Error

```odin
Engine_Error :: enum {
    None,
    Invalid_Parameter,
    Invalid_Operation,
    Not_Implemented,
    Resource_Not_Found,
    Out_Of_Memory,
    Graphics_Initialization_Failed,
    Device_Creation_Failed,
    Window_Creation_Failed,
    Shader_Compilation_Failed,
    Pipeline_Creation_Failed,
    Buffer_Creation_Failed,
    Texture_Creation_Failed,
    Invalid_Handle,
    Input_Initialization_Failed,
    Audio_Initialization_Failed,
    Sound_Loading_Failed,
    File_Not_Found,
    File_Access_Denied,
    File_Read_Error,
    File_Write_Error,
    Scene_Creation_Failed,
    Component_Creation_Failed,
}
```

Standardized error codes used throughout the engine.

### Functions

#### engine_error_to_string

```odin
engine_error_to_string :: proc(err: Engine_Error) -> string
```

Converts an Engine_Error to a human-readable string.

**Parameters:**
- `err`: The error to convert

**Returns:**
- A string description of the error
