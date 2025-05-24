# OdinGame API Documentation

This document provides an overview of the OdinGame framework API, designed to be familiar to users of XNA and MonoGame.

## Table of Contents
- [Core Gameplay](#core-gameplay)
  - [Game Class](#game-class)
  - [GameTime](#gametime)
- [Graphics System](#graphics-system)
  - [GraphicsDeviceManager](#graphicsdevicemanager)
  - [GraphicsDevice](#graphicsdevice)
  - [SpriteBatch](#spritebatch)
  - [Texture2D](#texture2d)
  - [Graphics Primitives](#graphics-primitives)
    - [Viewport](#viewport)
    - [Color](#color)
    - [Rectangle](#rectangle)
    - [Point](#point)
- [Content Management](#content-management)
  - [ContentManager](#contentmanager)
- [Input System](#input-system)
  - [Keyboard](#keyboard)
  - [Mouse](#mouse)
  - [Gamepad](#gamepad)
- [Audio System](#audio-system)
  - [AudioEngine](#audioengine)
  - [SoundEffect & SoundEffectInstance](#soundeffect--soundeffectinstance)
  - [Song & MediaPlayer](#song--mediaplayer)
- [Math Utilities](#math-utilities)
  - [Vectors, Matrices, Quaternions](#vectors-matrices-quaternions)
  - [Curve](#curve)


---

## Core Gameplay

This section covers the fundamental classes for creating and managing your game.

### Game Class

The `core.Game` struct is the heart of your OdinGame application. It provides the main game loop, manages game services and components, and orchestrates the game's lifecycle.

**Key Features & Usage:**

*   **Lifecycle Methods**: You typically create your own struct that embeds `core.Game` or directly assign procedures to its lifecycle method fields. These are called automatically by the game loop.
    *   `Initialize()`: Called once after the `Game` object is created and essential services (like `GraphicsDeviceManager`) are available. Override this to query for services, set up game-specific services, and load non-graphics content.
    *   `Load_Content()`: Called once after `Initialize()` and after the `GraphicsDevice` has been created (i.e., after `GraphicsDeviceManager.apply_changes()` has been called, which happens automatically in `game_run`). Override this to load all graphical content using `game.content`.
    *   `Unload_Content()`: Called once when the game is exiting, before the `GraphicsDevice` is disposed. Override this to unload content loaded by `game.content` and any other manually managed game-specific content.
    *   `Update(game_time: Game_Time)`: Called every frame. Override this to update game state, process input, and run game logic.
    *   `Draw(game_time: Game_Time)`: Called every frame (unless suppressed by fixed time step logic). Override this to render your game.
    *   `Begin_Run()`: Called at the beginning of `game_run()`, before initialization.
    *   `End_Run()`: Called at the end of `game_run()`, after the game loop has exited and resources are about to be cleaned up.
    *   `Begin_Draw()`: Called before each `Draw()` call. Return `false` to skip drawing for this frame. The default implementation calls `GraphicsDeviceManager.begin_draw()`.
    *   `End_Draw()`: Called after each `Draw()` call. This is typically where the back buffer is presented to the screen. The default implementation calls `GraphicsDeviceManager.end_draw()`.
*   **Constructor**: `core.new_game(allocator := context.allocator) -> ^core.Game`
*   **Running the Game**: `core.game_run(game: ^core.Game, title: string, width, height: int, preferred_backend := graphics.Backend_Type.Auto)`
*   **Exiting**: `core.game_exit(game: ^Game)` can be called to signal the game to exit.
*   **Key Fields**:
    *   `content: ^content.Content_Manager`: Manages loading and unloading of game assets. Initialized by `new_game`.
    *   `graphics_device_manager: ^graphics.Graphics_Device_Manager`: Manages graphics device configuration and creation. Initialized by `new_game`.
    *   `graphics_device: ^graphics.Graphics_Device`: The graphics device used for drawing (available after `GraphicsDeviceManager.apply_changes()` is called within `game_run`).
    *   `window: ^graphics.Game_Window`: Represents the game window (available after GDM setup).
    *   `audio_engine: ^audio.Audio_Engine`: Manages global audio settings and resources.
    *   `media_player: ^audio.Media_Player`: Controls playback of songs.
    *   `target_elapsed_time: time.Duration`: The desired time between `Update` calls when `is_fixed_time_step` is true (default is 1/60th of a second).
    *   `is_fixed_time_step: bool`: If true, `Update` is called a fixed number of times per second. If false, `Update` is called once per `Draw`.
    *   `services: map[typeid]rawptr`: A service locator for accessing shared game services. (Usage pattern TBD)
    *   `components: [dynamic]rawptr`: (Future) A list of game components to be updated.
    *   `allocator_ref: mem.Allocator`: The allocator used by the game instance.
    *   `window_title_base: string`: Base title for the game window.

### GameTime

The `core.Game_Time` struct provides timing information to the `Update` and `Draw` methods.

```odin
package core
import "core:time"

Game_Time :: struct {
    elapsed_game_time: time.Duration, 
    total_game_time:   time.Duration, 
    is_running_slowly: bool,          
}
```

---
## Graphics System

The graphics system provides functionalities for device management, rendering, and resource handling.

### GraphicsDeviceManager

The `graphics.Graphics_Device_Manager` is responsible for managing the configuration and lifecycle of the `Graphics_Device` and the main game window. It's typically created once by the `core.Game` instance and accessed via `game.graphics_device_manager`.

**Key Features & Usage:**

*   **Constructor**: `graphics.new_graphics_device_manager(game_instance: ^core.Game) -> ^graphics.Graphics_Device_Manager` (Called by `core.new_game`).
*   **Configuration**: Set preferred graphics settings *before* the device is created (usually in your `Game.Initialize` method):
    *   `preferred_back_buffer_width: int`
    *   `preferred_back_buffer_height: int`
    *   `preferred_back_buffer_format: graphics.Surface_Format`
    *   `preferred_depth_stencil_format: graphics.Depth_Format`
    *   `is_full_screen: bool`
    *   `synchronize_with_vertical_retrace: bool` (VSync)
*   **Applying Changes**: `graphics.apply_changes(gdm: ^graphics.Graphics_Device_Manager) -> common.Engine_Error`
    *   This method creates or reconfigures the graphics device and window based on current preferences.
    *   `core.Game.game_run()` calls this automatically after `Game.Initialize()` and before `Game.Load_Content()`.
*   **Accessing Device**: After `apply_changes`, the created `Graphics_Device` is available via `gdm.graphics_device`.
*   **Fullscreen**: `graphics.toggle_fullscreen(gdm: ^graphics.Graphics_Device_Manager)` (sets preference, requires `apply_changes` to take effect).

### GraphicsDevice

The `graphics.Graphics_Device` struct (defined in `odingame/graphics/graphics_device.odin`) is the primary interface for all rendering operations and graphics resource creation after it has been initialized by the `GraphicsDeviceManager`.

**Key Features & Usage:**
*   **Access**: Obtained from `game.graphics_device_manager.graphics_device` after `apply_changes`.
*   **Core Fields (Conceptual - values reflected in `present_params` or set via methods)**:
    *   `present_params: graphics.Present_Parameters`: Current presentation parameters (buffer size, format, etc.).
    *   `viewport: graphics.Viewport`: Current viewport settings.
*   **Core Methods**:
    *   `graphics.graphics_device_clear(dev: ^graphics.Graphics_Device, color: math.Color, clear_depth: bool = true, clear_stencil: bool = false)`: Clears the active render target(s).
    *   `graphics.graphics_device_present(dev: ^graphics.Graphics_Device)`: Presents the back buffer. (Typically called via `Game.End_Draw`).
    *   `graphics.graphics_device_set_viewport(dev: ^graphics.Graphics_Device, viewport: graphics.Viewport)`: Sets the active viewport.
    *   Resource creation (textures, buffers, shaders, pipelines) is done via the global `gfx_interface.gfx_api` procedures, passing `dev._gfx_device` (the low-level handle).

### SpriteBatch

The `graphics.SpriteBatch` class (defined in `odingame/graphics/spritebatch.odin`) is used for efficient rendering of 2D sprites.

**Key Features & Usage:**

*   **Constructor**: `graphics.new_spritebatch(graphics_device_ref: ^graphics.Graphics_Device, max_sprites := graphics.MAX_SPRITES_DEFAULT, allocator := context.allocator) -> (^graphics.SpriteBatch, common.Engine_Error)`
*   **Begin/End Drawing**:
    *   `graphics.sprite_batch_begin(batch: ^graphics.SpriteBatch, sort_mode := .Deferred, blend_state_type := .Alpha_Blend, sampler_state_type := .Linear_Clamp, depth_stencil_state_type := .None, rasterizer_state_type := .Cull_Counter_Clockwise, effect: ^graphics.Effect = nil, transform_matrix := omath.matrix_identity())`
    *   `graphics.sprite_batch_end(batch: ^graphics.SpriteBatch)`
*   **Drawing Sprites**:
    *   `graphics.sprite_batch_draw_texture(batch: ^graphics.SpriteBatch, texture: ^graphics.Texture2D, position: omath.Vector2, color := omath.Color_White)`
    *   `graphics.sprite_batch_draw_texture_rect(batch: ^graphics.SpriteBatch, texture: ^graphics.Texture2D, destination_rectangle: omath.Rectangle, source_rectangle: Maybe(omath.Rectangle), color := omath.Color_White, rotation: f32 = 0, origin := omath.Vector2{}, scale := omath.Vector2{1,1}, effects := graphics.Sprite_Effects.None, layer_depth: f32 = 0)`
    *   `graphics.draw_string(batch: ^graphics.SpriteBatch, font: ^graphics.font.Font, text: string, position: omath.Vector2, tint := omath.Color_White, scale: f32 = 1.0)`

**Supporting Enums (defined in `odingame/graphics/sprite_types.odin` or `graphics` package):**
*   `Sprite_Sort_Mode`: `.Deferred`, `.Immediate`, `.Texture`, `.Back_To_Front`, `.Front_To_Back`.
*   `Sprite_Effects`: `.None`, `.Flip_Horizontally`, `.Flip_Vertically`.
*   `Blend_State_Type`: `.Alpha_Blend`, `.Additive`, `.Opaque`, `.Non_Premultiplied`.
*   `Sampler_State_Type`: `.Linear_Clamp`, `.Point_Clamp`, etc.
*   `Depth_Stencil_State_Type`: `.None`, `.Depth_Default`, etc.
*   `Rasterizer_State_Type`: `.Cull_Counter_Clockwise`, `.Cull_None`, etc.

### Texture2D

The `graphics.Texture2D` struct (defined in `odingame/graphics/texture.odin`) represents a 2D texture asset. It wraps a low-level `gfx_interface.Gfx_Texture`.

```odin
package graphics

Texture2D :: struct {
    // Embedded common fields (graphics_device, format, _gfx_texture, etc.)
    // using _base: Texture_Base, 
    width:  int,
    height: int,
    format: Surface_Format_Texture, // Engine-level enum for surface format
    // ... other fields like _gfx_texture, _is_disposed
}
```
*   **Loading**: Typically loaded via `content.content_load_texture2D(game.content, "asset_path")`.
*   **Properties**: `width`, `height`, `format` can be accessed.
*   **Disposal**: Managed by `ContentManager`. `graphics.texture2D_dispose(^Texture2D)` marks as disposed.

### Graphics Primitives

Core data types for graphics, primarily defined in `odingame/math/primitives.odin`.

#### Viewport
Defines the 2D rectangle of the render target. Defined in `odingame/graphics/graphics_device.odin`.
```odin
package graphics 
Viewport :: struct { x: int, y: int, width: int, height: int, min_depth: f32, max_depth: f32 }
```
*   Set using `graphics.graphics_device_set_viewport(dev, my_viewport)`.

#### Color
RGBA color. Defined in `odingame/math/primitives.odin`.
```odin
package math
Color :: struct { r, g, b, a: u8 }
```
*   Constants: `math.Color_White`, `math.Color_Cornflower_Blue`, etc.
*   Helper: `math.color_premultiply_alpha(color)`.

#### Rectangle
Integer-based 2D rectangle. Defined in `odingame/math/primitives.odin`.
```odin
package math
Rectangle :: struct { x, y, width, height: int }
```
*   Helpers: `math.rectangle_intersects(rect_a, rect_b)`, etc.

#### Point
Integer-based 2D point. Defined in `odingame/math/primitives.odin`.
```odin
package math
Point :: struct { x, y: int }
```

---
## Content Management

Handles loading and unloading of game assets.

### ContentManager

The `content.Content_Manager` (defined in `odingame/content/content_manager.odin`) is responsible for loading game assets from files. It's accessed via `game.content`.

**Key Features & Usage:**

*   **Constructor**: `content.new_content_manager(game: ^core.Game, root_dir: string, alloc := context.allocator) -> ^content.Content_Manager` (Called by `core.new_game`).
*   **Root Directory**: Assets are loaded relative to the `root_directory` (default is "assets").
*   **Loading Assets**:
    *   `content.content_load_texture2D(cm: ^content.Content_Manager, asset_name: string) -> (^graphics.Texture2D, common.Engine_Error)`: Loads a `Texture2D`.
    *   `content.content_load[$T](cm: ^content.Content_Manager, asset_name: string) -> (^T, common.Engine_Error)`: Generic load function (e.g., for `^audio.Sound_Effect`, `^audio.Song`).
*   **Unloading Assets**:
    *   `content.content_unload_all(cm: ^content.Content_Manager)`: Unloads all assets. Called by `core.Game`.
*   **Asset Caching**: Loaded assets are cached.

---
## Input System

The input system (`odingame/input`) provides stateful polling for keyboard, mouse, and gamepads. Updated once per frame by `core.Game`.

### Keyboard

*   **`input.Keyboard_State`**: Snapshot of keyboard state.
    ```odin
    package input; Keyboard_State :: struct { /* internal */ }
    ```
*   **Get State**: `input.keyboard_get_state() -> input.Keyboard_State`
*   **Check Keys**:
    *   `input.keyboard_state_is_key_down(state: input.Keyboard_State, key: input.Keys) -> bool`
    *   `input.keyboard_state_is_key_up(state: input.Keyboard_State, key: input.Keys) -> bool`
    *   `input.keyboard_is_key_pressed(key: input.Keys) -> bool` (True on frame of press)
    *   `input.keyboard_is_key_released(key: input.Keys) -> bool` (True on frame of release)
*   **`input.Keys` Enum**: Key codes (e.g., `.A`, `.Space`, `.Escape`). Mapped from `sdl.Scancode`.

### Mouse

*   **`input.Mouse_State`**: Snapshot of mouse state.
    ```odin
    package input
    Mouse_State :: struct { x, y, scroll_wheel_value: i32, left_button, middle_button, right_button, x_button1, x_button2: Button_State }
    Button_State :: enum { Released, Pressed }
    Mouse_Button :: enum { Left, Middle, Right, X1, X2 }
    ```
*   **Get State**: `input.mouse_get_state() -> input.Mouse_State`
*   **Check Buttons**:
    *   `mouse_state.left_button == .Pressed`
    *   `input.mouse_is_button_pressed(button: input.Mouse_Button) -> bool`
    *   `input.mouse_is_button_released(button: input.Mouse_Button) -> bool`
*   **Scroll Wheel**: `mouse_state.scroll_wheel_value` (cumulative), `input.mouse_get_scroll_wheel_delta() -> i32` (change since last frame).

### Gamepad

*   **`input.Gamepad_State`**: Snapshot of gamepad state.
    ```odin
    package input
    Gamepad_State :: struct { is_connected: bool, buttons: Gamepad_Buttons, triggers: Gamepad_Triggers, thumb_sticks: Gamepad_Thumb_Sticks }
    Gamepad_Buttons :: struct { a, b, x, y, ... : Button_State }
    Gamepad_Triggers :: struct { left, right: f32 } // 0.0 to 1.0
    Gamepad_Thumb_Sticks :: struct { left_x, left_y, right_x, right_y: f32 } // -1.0 to 1.0
    ```
*   **Get State**: `input.gamepad_get_state(player_index: input.Player_Index) -> input.Gamepad_State`
    *   `input.Player_Index`: `.One`, `.Two`, `.Three`, `.Four`.
*   **Check Connection**: `gamepad_state.is_connected`.
*   **Check Buttons**:
    *   `input.gamepad_is_button_down(player_index, button: input.Gamepad_Button_Type) -> bool`
    *   `input.gamepad_is_button_up(player_index, button) -> bool`
    *   `input.gamepad_is_button_pressed(player_index, button) -> bool`
    *   `input.gamepad_is_button_released(player_index, button) -> bool`
*   **`input.Gamepad_Button_Type` Enum**: Gamepad buttons (e.g., `.A`, `.Dpad_Up`). Mapped from `sdl.GameControllerButton`.

---
## Audio System

The audio system (`odingame/audio`) handles sound effects and music playback, using SDL_mixer as the backend.

### AudioEngine

The `audio.Audio_Engine` manages global audio settings and initializes the audio subsystem. It's accessed via `game.audio_engine`.

*   **Initialization**: `audio.audio_engine_initialize(allocator) -> (^audio.Audio_Engine, common.Engine_Error)` (Called by `core.new_game`).
*   **Destruction**: `audio.audio_engine_destroy(engine)` (Called by `core.game_run`).
*   **Master Volume (Sound Effects)**:
    *   `audio.audio_engine_set_master_volume(engine: ^audio.Audio_Engine, volume: f32)` (0.0 to 1.0)
    *   `audio.audio_engine_get_master_volume(engine: ^audio.Audio_Engine) -> f32`
    *   This volume affects `SoundEffectInstance` playback.

### SoundEffect & SoundEffectInstance

`audio.Sound_Effect` represents a loaded sound effect (typically short WAV files). `audio.Sound_Effect_Instance` allows for controlled playback of a `Sound_Effect`.

*   **`Sound_Effect` Loading (Temporary, pre-ContentManager integration for audio):**
    *   `audio.sound_effect_load(filepath: string, alloc: mem.Allocator) -> (^audio.Sound_Effect, common.Engine_Error)`
    *   `audio.sound_effect_destroy(effect: ^audio.Sound_Effect)`
*   **`Sound_Effect_Instance` Creation:**
    *   `audio.sound_effect_create_instance(effect: ^audio.Sound_Effect, alloc: mem.Allocator) -> ^audio.Sound_Effect_Instance`
    *   `audio.sound_effect_instance_destroy(instance: ^audio.Sound_Effect_Instance)`
*   **Playback Control (`Sound_Effect_Instance`):**
    *   `play(instance) -> bool`
    *   `pause(instance)`
    *   `resume(instance)`
    *   `stop(instance, immediate := true)`
    *   `state: audio.Sound_State` field (`.Playing`, `.Paused`, `.Stopped`).
*   **Instance Properties:**
    *   `set_volume(instance, volume: f32)` (0.0-1.0, combined with master volume)
    *   `set_pan(instance, pan: f32)` (-1.0 left to 1.0 right)
    *   `set_is_looped(instance, looped: bool)`
    *   `pitch: f32` (Stored, but not applied by current SDL_mixer backend).
*   **Fire-and-Forget Playback (`Sound_Effect`):**
    *   `audio.sound_effect_play(effect: ^audio.Sound_Effect, volume := 1.0, pitch := 0.0, pan := 0.0) -> bool`

### Song & MediaPlayer

`audio.Song` represents a music track (MP3, OGG, etc.). `audio.Media_Player` controls global music playback. Access via `game.media_player`.

*   **`Song` Loading (Temporary, pre-ContentManager):**
    *   `audio.song_load(filepath: string, alloc: mem.Allocator) -> (^audio.Song, common.Engine_Error)`
    *   `audio.song_destroy(song: ^audio.Song)`
*   **`MediaPlayer` (Global Access via `game.media_player`):**
    *   **Constructor**: `audio.media_player_new(alloc: mem.Allocator) -> ^audio.Media_Player` (Called by `core.new_game`).
    *   **Destruction**: `audio.media_player_destroy(player)` (Called by `core.game_run`).
*   **Playback Control:**
    *   `play(player: ^audio.Media_Player, song: ^audio.Song)`
    *   `pause(player: ^audio.Media_Player)`
    *   `resume(player: ^audio.Media_Player)`
    *   `stop(player: ^audio.Media_Player)`
*   **Properties:**
    *   `set_volume(player, volume: f32)` (0.0-1.0)
    *   `get_volume(player) -> f32`
    *   `set_is_muted(player, muted: bool)`
    *   `get_is_muted(player) -> bool`
    *   `set_is_repeating(player, repeating: bool)`
    *   `get_is_repeating(player) -> bool`
    *   `get_state(player) -> audio.Media_State` (`.Playing`, `.Paused`, `.Stopped`).

---
Next, I will add "Math Utilities".I have updated `docs/api.md` with the "Core Gameplay", "Graphics System", "Content Management", and "Input System" sections. The "Audio System" section has also been added.

Now, I will proceed to **Step 7: Document Math Utilities**.
This involves `Vector2/3/4`, `Matrix`, `Quaternion` from `odingame/math/math_aliases.odin` and `Curve` from `odingame/math/curve.odin`.
I will append this to `docs/api.md`.
