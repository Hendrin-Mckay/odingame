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
    user_data:       rawptr, // User-defined data to be passed to callbacks
    _previous_ticks: u64,
    _perf_frequency: u64,
}
```

The main game structure that holds the game state, callbacks, and user-defined data.

#### GameTime

```odin
GameTime :: struct {
    elapsed_game_time: f64, // Seconds
    total_game_time:   f64, // Seconds
}
```

Provides timing information (elapsed and total time in seconds) for the game loop.

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

Represents the game window and its associated graphics context.

### Callback Types

#### InitializeFn

```odin
InitializeFn :: proc(game: ^Game)
```
A callback function that is called once when the game is initialized.

**Parameters:**
- `game`: The game instance.

#### LoadContentFn

```odin
LoadContentFn :: proc(game: ^Game)
```
A callback function that is called once after initialization to load game assets.

**Parameters:**
- `game`: The game instance.

#### UpdateFn

```odin
UpdateFn :: proc(game: ^Game)
```
A callback function that is called every frame to update the game state.

**Parameters:**
- `game`: The game instance.

#### DrawFn

```odin
DrawFn :: proc(game: ^Game)
```
A callback function that is called every frame to draw the game.

**Parameters:**
- `game`: The game instance.

### Functions

#### run

```odin
run :: proc(title: string, width, height: int, initialize_fn: InitializeFn, load_content_fn: LoadContentFn, update_fn: UpdateFn, draw_fn: DrawFn)
```

Initializes and runs the game loop with the specified parameters and callback functions. The game loop continues until `exit` is called.

**Parameters:**
- `title`: The title of the game window.
- `width`: The width of the game window in pixels.
- `height`: The height of the game window in pixels.
- `initialize_fn`: The function to call for game initialization.
- `load_content_fn`: The function to call for loading game content.
- `update_fn`: The function to call for updating game logic each frame.
- `draw_fn`: The function to call for drawing the game each frame.

#### exit

```odin
exit :: proc(game: ^Game)
```

Signals the game to exit at the end of the current frame.

**Parameters:**
- `game`: The game instance to exit.

#### set_title

```odin
set_title :: proc(game: ^Game, title: string)
```

Sets the title of the game window.

**Parameters:**
- `game`: The game instance.
- `title`: The new title for the window.

#### get_window_width

```odin
get_window_width :: proc(game: ^Game) -> int
```

Gets the current width of the game window in screen coordinates.

**Parameters:**
- `game`: The game instance.

**Returns:**
- The width of the window in pixels.

#### get_window_height

```odin
get_window_height :: proc(game: ^Game) -> int
```

Gets the current height of the game window in screen coordinates.

**Parameters:**
- `game`: The game instance.

**Returns:**
- The height of the window in pixels.

#### get_drawable_width

```odin
get_drawable_width :: proc(game: ^Game) -> int
```

Gets the current width of the drawable area of the game window in pixels. This may differ from window width on high-DPI displays.

**Parameters:**
- `game`: The game instance.

**Returns:**
- The width of the drawable area in pixels.

#### get_drawable_height

```odin
get_drawable_height :: proc(game: ^Game) -> int
```

Gets the current height of the drawable area of the game window in pixels. This may differ from window height on high-DPI displays.

**Parameters:**
- `game`: The game instance.

**Returns:**
- The height of the drawable area in pixels.

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
Gfx_Device :: struct { 
    variant: rawptr 
}
```

Represents a graphics device. `variant` holds a backend-specific opaque pointer to the actual device implementation.

#### Gfx_Window

```odin
Gfx_Window :: struct {
    variant: rawptr, // Backend-specific pointer to the window
}
```

Represents a window for rendering. `variant` holds a backend-specific pointer to the actual window implementation.

#### Gfx_Handle

```odin
Gfx_Handle :: distinct u32
INVALID_HANDLE :: Gfx_Handle(max(u32))
```

A handle to a graphics resource. `INVALID_HANDLE` is used to represent an invalid or uninitialized handle.

#### Buffer_Type

```odin
Buffer_Type :: enum {
    Vertex,
    Index,
    Uniform,
}
```
Specifies the type of a buffer.

#### Texture_Format

```odin
Texture_Format :: enum {
    R8, RG8, RGBA8, // Unsigned normalized
    R16F, RG16F, RGBA16F, // Floating point
    Depth16, Depth24, Depth32F, Depth24Stencil8, // Depth/stencil formats
    // Add other common formats as needed
}
```
Specifies the pixel format of a texture.

#### Texture_Usage

```odin
Texture_Usage :: enum_flags {
    Sampled,         // Texture can be sampled in a shader
    Storage,         // Texture can be used for image load/store operations
    Color_Attachment, // Texture can be used as a color render target
    Depth_Stencil_Attachment, // Texture can be used as a depth/stencil render target
}
```
Specifies the intended usage of a texture. Multiple flags can be combined.

#### Shader_Stage

```odin
Shader_Stage :: enum_flags {
    Vertex,
    Fragment,
    Compute,
    // Add other stages as needed (Geometry, Tessellation)
}
```
Specifies the shader stage(s) a shader module is for.

#### Blend_Mode

```odin
Blend_Mode :: enum {
    None,
    Alpha,        // src_alpha * src_color + (1 - src_alpha) * dst_color
    Additive,     // src_color + dst_color
    Multiplicative, // src_color * dst_color
    // Add other common blend modes
}
```
Specifies how source and destination colors are blended.

#### Depth_Func

```odin
Depth_Func :: enum {
    Always,
    Never,
    Less,
    Equal,
    Less_Equal,
    Greater,
    Not_Equal,
    Greater_Equal,
}
```
Specifies the function used for depth testing.

#### Cull_Mode

```odin
Cull_Mode :: enum {
    None,
    Front,
    Back,
}
```
Specifies which faces of a polygon are culled.

#### Primitive_Topology

```odin
Primitive_Topology :: enum {
    Points,
    Lines,
    Line_Strip,
    Triangles,
    Triangle_Strip,
}
```
Specifies how vertex data is interpreted to form primitives.

#### Clear_Options

```odin
Clear_Options :: struct {
    color:          types.Color,
    depth:          f32,
    stencil:        u8,
    clear_color:    bool,
    clear_depth:    bool,
    clear_stencil:  bool,
}
```
Specifies options for clearing render targets.

#### Viewport

```odin
Viewport :: struct {
    x, y:      f32,
    width, height: f32,
    min_depth, max_depth: f32,
}
```
Defines the area of the render target to which primitives are drawn.

#### Scissor

```odin
Scissor :: types.Recti // Alias for types.Recti
```
Defines a rectangular area for scissor testing.

#### Gfx_Shader

```odin
Gfx_Shader :: struct {
    variant: rawptr, // Backend-specific pointer to the shader
}
```
Represents a compiled shader module. `variant` holds a backend-specific pointer.

#### Gfx_Pipeline

```odin
Gfx_Pipeline :: struct {
    variant: rawptr, // Backend-specific pointer to the pipeline
}
```
Represents a graphics pipeline state object. `variant` holds a backend-specific pointer.

#### Gfx_Buffer

```odin
Gfx_Buffer :: struct {
    variant: rawptr, // Backend-specific pointer to the buffer
}
```
Represents a buffer for storing vertex, index, or uniform data. `variant` holds a backend-specific pointer.

#### Gfx_Texture

```odin
Gfx_Texture :: struct {
    variant: rawptr, // Backend-specific pointer to the texture
}
```
Represents a texture. This is a handle to a reference-counted texture object. `variant` holds a backend-specific pointer.

#### Gfx_Framebuffer

```odin
Gfx_Framebuffer :: struct {
    variant: rawptr, // Backend-specific pointer to the framebuffer
}
```
Represents a framebuffer object, which is a collection of attachments for rendering. `variant` holds a backend-specific pointer.

#### Gfx_Render_Pass

```odin
Gfx_Render_Pass :: struct {
    variant: rawptr, // Backend-specific pointer to the render pass
}
```
Represents a render pass, defining the attachments and subpasses for a rendering operation. `variant` holds a backend-specific pointer.

#### Vertex_Attribute

```odin
Vertex_Attribute :: struct {
    location: u32,          // Shader location
    offset:   u32,          // Offset within the vertex
    format:   Vertex_Format, // Format of the attribute
}
```
Defines a single attribute of a vertex (e.g., position, normal, texcoord).

#### Vertex_Buffer_Layout

```odin
Vertex_Buffer_Layout :: struct {
    attributes:  []Vertex_Attribute,
    stride:      u32, // Size of a single vertex in bytes
    input_rate:  Vertex_Input_Rate, // Per-vertex or per-instance
}
```
Defines the layout of a vertex buffer, including its attributes and stride. (Note: `Vertex_Input_Rate` enum would need to be defined, assuming `.Vertex` and `.Instance`)

#### Vertex_Format

```odin
Vertex_Format :: enum {
    Float, Float2, Float3, Float4,
    Byte4_Norm, UByte4_Norm, // For colors or other normalized attributes
    // Add other formats as needed
}
```
Specifies the data type and components of a vertex attribute.

#### Gfx_Vertex_Array

```odin
Gfx_Vertex_Array :: struct {
    variant: rawptr, // Backend-specific, e.g., Vulkan Vertex Array Object (VAO)
}
```
Represents a vertex array object (VAO) or similar backend-specific construct that encapsulates vertex buffer bindings and attribute configurations. `variant` holds a backend-specific pointer.

#### Sprite_Vertex

```odin
Sprite_Vertex :: struct {
    pos:      math.Vector2, // Position of the vertex
    texcoord: math.Vector2, // Texture coordinate of the vertex
    color:    math.Color,   // Color of the vertex
}
```
Defines the structure of a single vertex used for rendering sprites. Each sprite is typically composed of four such vertices to form a quad.

#### SpriteBatch

```odin
SpriteBatch :: struct {
    device:                       Gfx_Device,
    vbo:                          Gfx_Buffer,      // Vertex Buffer Object for sprite vertices
    ebo:                          Gfx_Buffer,      // Element Buffer Object for sprite indices
    max_sprites_per_batch:        int,             // Maximum number of sprites that can be drawn in a single batch
    sprite_count:                 int,             // Current number of sprites accumulated in the batch
    vertices:                     []Sprite_Vertex, // Slice holding vertex data for the current batch
    indices:                      []u16,           // Slice holding index data for the current batch (typically 6 indices per sprite)
    default_white_texture:        ^Gfx_Texture,    // A 1x1 white texture, used when drawing shapes or if a texture is nil.
    current_texture:              ^Gfx_Texture,    // The texture currently bound for drawing. Flushes batch if changed.
    current_projection_view_matrix: math.Matrix4f,  // The projection-view matrix used for the current batch.
}
```

A utility for efficiently rendering multiple sprites (textured quads) in batches, minimizing draw calls. It handles vertex buffer management, texture binding, and transformation matrices.

### Gfx_Device_Interface

The `Gfx_Device_Interface` is a struct that defines the contract for all graphics backend implementations. It provides a consistent API for graphics operations across different backends like OpenGL, Vulkan, etc. The engine uses a global instance of this interface, `gfx_api`, which is populated by the selected backend during initialization.

```odin
Gfx_Device_Interface :: struct {
	// Device Management
	create_device: proc(allocator: ^rawptr) -> (Gfx_Device, common.Engine_Error),
	destroy_device: proc(device: Gfx_Device),

	// Window/Swapchain Management
	create_window: proc(device: Gfx_Device, title: string, width, height: int) -> (Gfx_Window, common.Engine_Error),
	destroy_window: proc(window: Gfx_Window),
	present_window: proc(window: Gfx_Window) -> common.Engine_Error,
	resize_window: proc(window: Gfx_Window, width, height: int) -> common.Engine_Error,
	set_window_title: proc(window: Gfx_Window, title: string) -> common.Engine_Error,
	get_window_size: proc(window: Gfx_Window) -> (width, height: int),
	get_window_drawable_size: proc(window: Gfx_Window) -> (width, height: int),

	// Shader Management
	create_shader_from_source: proc(device: Gfx_Device, source: string, stage: Shader_Stage) -> (Gfx_Shader, common.Engine_Error),
	create_shader_from_bytecode: proc(device: Gfx_Device, bytecode: []u8, stage: Shader_Stage) -> (Gfx_Shader, common.Engine_Error),
	destroy_shader: proc(shader: Gfx_Shader),

    // Pipeline Management
    create_pipeline: proc(device: Gfx_Device, shaders: []Gfx_Shader /*, other pipeline state */) -> (Gfx_Pipeline, common.Engine_Error),
    destroy_pipeline: proc(pipeline: Gfx_Pipeline),

	// Buffer Management
	create_buffer: proc(device: Gfx_Device, type: Buffer_Type, size: int, data: rawptr = nil, is_dynamic: bool = false) -> (Gfx_Buffer, common.Engine_Error),
	update_buffer: proc(buffer: Gfx_Buffer, offset: int, data: rawptr, size: int) -> common.Engine_Error,
	destroy_buffer: proc(buffer: Gfx_Buffer),
    map_buffer: proc(buffer: Gfx_Buffer, offset, size: int) -> rawptr,
    unmap_buffer: proc(buffer: Gfx_Buffer),

	// Texture Management
	create_texture: proc(device: Gfx_Device, width, height: int, format: Texture_Format, usage: Texture_Usage, data: rawptr = nil) -> (Gfx_Texture, common.Engine_Error),
	update_texture: proc(texture: Gfx_Texture, x, y, width, height: int, data: rawptr) -> common.Engine_Error,
	destroy_texture: proc(texture: Gfx_Texture),
	// bind_texture_to_unit: proc(device: Gfx_Device, texture: Gfx_Texture, unit: int), // Duplicated, see Uniform & Resource Binding
	// get_texture_width: proc(texture: Gfx_Texture) -> int, // Duplicated, see Texture Utilities
	// get_texture_height: proc(texture: Gfx_Texture) -> int, // Duplicated, see Texture Utilities

	// Drawing Commands
	begin_frame: proc(device: Gfx_Device),
	end_frame: proc(device: Gfx_Device),
	clear_screen: proc(device: Gfx_Device, options: Clear_Options),
    set_viewport: proc(device: Gfx_Device, viewport: Viewport),
    set_scissor: proc(device: Gfx_Device, scissor: Scissor),
    disable_scissor: proc(device: Gfx_Device),
	set_pipeline: proc(device: Gfx_Device, pipeline: Gfx_Pipeline),
	set_vertex_buffer: proc(device: Gfx_Device, buffer: Gfx_Buffer, binding_index: u32 = 0, offset: u32 = 0),
	set_index_buffer: proc(device: Gfx_Device, buffer: Gfx_Buffer, offset: u32 = 0),
	draw: proc(device: Gfx_Device, vertex_count, instance_count, first_vertex, first_instance: u32),
	draw_indexed: proc(device: Gfx_Device, index_count, instance_count, first_index, base_vertex, first_instance: u32),

	// Framebuffer Management
	create_framebuffer: proc(device: Gfx_Device, width, height: int, color_format: Texture_Format, depth_format: Texture_Format) -> (Gfx_Framebuffer, common.Engine_Error),
	destroy_framebuffer: proc(framebuffer: Gfx_Framebuffer),

	// Render Pass Management
	create_render_pass: proc(device: Gfx_Device, framebuffer: Gfx_Framebuffer, clear_color, clear_depth: bool) -> (Gfx_Render_Pass, common.Engine_Error),
	begin_render_pass: proc(device: Gfx_Device, render_pass: Gfx_Render_Pass, clear_color: types.Color, clear_depth: f32), // Changed from math.Color
	end_render_pass: proc(device: Gfx_Device, render_pass: Gfx_Render_Pass),

	// State Management
	set_blend_mode: proc(device: Gfx_Device, blend_mode: Blend_Mode),
	set_depth_test: proc(device: Gfx_Device, enabled: bool, write: bool, func: Depth_Func),
	set_cull_mode: proc(device: Gfx_Device, cull_mode: Cull_Mode),

	// Uniform & Resource Binding
	set_uniform_mat4: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, mat: matrix[4,4]f32) -> common.Engine_Error,
	set_uniform_vec2: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, vec: [2]f32) -> common.Engine_Error,
	set_uniform_vec3: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, vec: [3]f32) -> common.Engine_Error,
	set_uniform_vec4: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, vec: [4]f32) -> common.Engine_Error,
	set_uniform_int: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, val: i32) -> common.Engine_Error,
	set_uniform_float: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, val: f32) -> common.Engine_Error,
	bind_texture_to_unit: proc(device: Gfx_Device, texture: Gfx_Texture, unit: u32) -> common.Engine_Error,

	// Vertex Array Objects / Vertex Layouts
	create_vertex_array: proc(device: Gfx_Device, vertex_buffer_layouts: []Vertex_Buffer_Layout, vertex_buffers: []Gfx_Buffer, index_buffer: Gfx_Buffer) -> (Gfx_Vertex_Array, common.Engine_Error),
	destroy_vertex_array: proc(vao: Gfx_Vertex_Array),
	bind_vertex_array:    proc(device: Gfx_Device, vao: Gfx_Vertex_Array),

	// Texture Utilities
	get_texture_width:  proc(texture: Gfx_Texture) -> int,
	get_texture_height: proc(texture: Gfx_Texture) -> int,

    // Utility
    get_error_string: proc(error: common.Engine_Error) -> string,
}
```

#### Device Management

- `create_device: proc(allocator: ^rawptr) -> (Gfx_Device, common.Engine_Error)`
  Creates and initializes a new graphics device for a chosen backend, using the provided allocator.
- `destroy_device: proc(device: Gfx_Device)`
  Destroys a graphics device and frees all associated resources.

#### Window/Swapchain Management

- `create_window: proc(device: Gfx_Device, title: string, width, height: int) -> (Gfx_Window, common.Engine_Error)`
  Creates a new window associated with the given graphics device.
- `destroy_window: proc(window: Gfx_Window)`
  Destroys a window and frees its associated resources.
- `present_window: proc(window: Gfx_Window) -> common.Engine_Error`
  Presents the current backbuffer to the window (swaps the buffers).
- `resize_window: proc(window: Gfx_Window, width, height: int) -> common.Engine_Error`
  Resizes the window to the specified width and height.
- `set_window_title: proc(window: Gfx_Window, title: string) -> common.Engine_Error`
  Sets the title of the specified window.
- `get_window_size: proc(window: Gfx_Window) -> (width, height: int)`
  Gets the logical size of the window in screen coordinates.
- `get_window_drawable_size: proc(window: Gfx_Window) -> (width, height: int)`
  Gets the drawable size of the window in pixels, which may differ from logical size on high DPI displays.

#### Shader Management

- `create_shader_from_source: proc(device: Gfx_Device, source: string, stage: Shader_Stage) -> (Gfx_Shader, common.Engine_Error)`
  Compiles a shader from source code string for the specified shader stage.
- `create_shader_from_bytecode: proc(device: Gfx_Device, bytecode: []u8, stage: Shader_Stage) -> (Gfx_Shader, common.Engine_Error)`
  Creates a shader from pre-compiled bytecode for the specified shader stage.
- `destroy_shader: proc(shader: Gfx_Shader)`
  Destroys a shader object and frees its resources.

#### Pipeline Management

- `create_pipeline: proc(device: Gfx_Device, shaders: []Gfx_Shader /*, other pipeline state */) -> (Gfx_Pipeline, common.Engine_Error)`
  Creates a graphics pipeline state object using the provided shaders and other state information (TODO: define other states).
- `destroy_pipeline: proc(pipeline: Gfx_Pipeline)`
  Destroys a pipeline object and frees its resources.

#### Buffer Management

- `create_buffer: proc(device: Gfx_Device, type: Buffer_Type, size: int, data: rawptr = nil, is_dynamic: bool = false) -> (Gfx_Buffer, common.Engine_Error)`
  Creates a new buffer (vertex, index, uniform) with a given size and optional initial data.
- `update_buffer: proc(buffer: Gfx_Buffer, offset: int, data: rawptr, size: int) -> common.Engine_Error`
  Updates a region of a buffer with new data.
- `destroy_buffer: proc(buffer: Gfx_Buffer)`
  Destroys a buffer object and frees its memory.
- `map_buffer: proc(buffer: Gfx_Buffer, offset, size: int) -> rawptr`
  Maps a region of a buffer into client memory for direct access.
- `unmap_buffer: proc(buffer: Gfx_Buffer)`
  Unmaps a previously mapped buffer.

#### Texture Management

- `create_texture: proc(device: Gfx_Device, width, height: int, format: Texture_Format, usage: Texture_Usage, data: rawptr = nil) -> (Gfx_Texture, common.Engine_Error)`
  Creates a new 2D texture with specified dimensions, format, usage flags, and optional initial data.
- `update_texture: proc(texture: Gfx_Texture, x, y, width, height: int, data: rawptr) -> common.Engine_Error`
  Updates a rectangular region of a texture with new data.
- `destroy_texture: proc(texture: Gfx_Texture)`
  Destroys a texture object and frees its resources.

#### Drawing Commands

- `begin_frame: proc(device: Gfx_Device)`
  Signifies the start of a new frame for rendering.
- `end_frame: proc(device: Gfx_Device)`
  Signifies the end of a frame, potentially submitting command buffers.
- `clear_screen: proc(device: Gfx_Device, options: Clear_Options)`
  Clears the active render target(s) using the specified options.
- `set_viewport: proc(device: Gfx_Device, viewport: Viewport)`
  Sets the viewport for rendering.
- `set_scissor: proc(device: Gfx_Device, scissor: Scissor)`
  Sets the scissor rectangle for clipping.
- `disable_scissor: proc(device: Gfx_Device)`
  Disables scissor testing.
- `set_pipeline: proc(device: Gfx_Device, pipeline: Gfx_Pipeline)`
  Binds a graphics pipeline for subsequent drawing commands.
- `set_vertex_buffer: proc(device: Gfx_Device, buffer: Gfx_Buffer, binding_index: u32 = 0, offset: u32 = 0)`
  Binds a vertex buffer to a specific binding point.
- `set_index_buffer: proc(device: Gfx_Device, buffer: Gfx_Buffer, offset: u32 = 0)`
  Binds an index buffer for indexed drawing.
- `draw: proc(device: Gfx_Device, vertex_count, instance_count, first_vertex, first_instance: u32)`
  Records a non-indexed drawing command.
- `draw_indexed: proc(device: Gfx_Device, index_count, instance_count, first_index, base_vertex, first_instance: u32)`
  Records an indexed drawing command.

#### Framebuffer Management

- `create_framebuffer: proc(device: Gfx_Device, width, height: int, color_format: Texture_Format, depth_format: Texture_Format) -> (Gfx_Framebuffer, common.Engine_Error)`
  Creates a new framebuffer object with specified attachment formats (Note: This signature might simplify actual needs, often takes existing textures).
- `destroy_framebuffer: proc(framebuffer: Gfx_Framebuffer)`
  Destroys a framebuffer object and its attachments if owned.

#### Render Pass Management

- `create_render_pass: proc(device: Gfx_Device, framebuffer: Gfx_Framebuffer, clear_color, clear_depth: bool) -> (Gfx_Render_Pass, common.Engine_Error)`
  Creates a render pass object defining how a framebuffer's attachments are used.
- `begin_render_pass: proc(device: Gfx_Device, render_pass: Gfx_Render_Pass, clear_color: types.Color, clear_depth: f32)`
  Begins a render pass, optionally clearing attachments.
- `end_render_pass: proc(device: Gfx_Device, render_pass: Gfx_Render_Pass)`
  Ends the current render pass.

#### State Management

- `set_blend_mode: proc(device: Gfx_Device, blend_mode: Blend_Mode)`
  Sets the color blend mode for the pipeline.
- `set_depth_test: proc(device: Gfx_Device, enabled: bool, write: bool, func: Depth_Func)`
  Configures depth testing parameters.
- `set_cull_mode: proc(device: Gfx_Device, cull_mode: Cull_Mode)`
  Sets the polygon face culling mode.

#### Uniform & Resource Binding

- `set_uniform_mat4: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, mat: matrix[4,4]f32) -> common.Engine_Error`
  Sets a matrix 4x4 uniform variable in a shader for a bound pipeline.
- `set_uniform_vec2: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, vec: [2]f32) -> common.Engine_Error`
  Sets a 2-component vector uniform variable in a shader.
- `set_uniform_vec3: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, vec: [3]f32) -> common.Engine_Error`
  Sets a 3-component vector uniform variable in a shader.
- `set_uniform_vec4: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, vec: [4]f32) -> common.Engine_Error`
  Sets a 4-component vector uniform variable in a shader.
- `set_uniform_int: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, val: i32) -> common.Engine_Error`
  Sets an integer uniform variable in a shader.
- `set_uniform_float: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, val: f32) -> common.Engine_Error`
  Sets a float uniform variable in a shader.
- `bind_texture_to_unit: proc(device: Gfx_Device, texture: Gfx_Texture, unit: u32) -> common.Engine_Error`
  Binds a texture to a specific texture unit for sampling in shaders.

#### Vertex Array Objects / Vertex Layouts

- `create_vertex_array: proc(device: Gfx_Device, vertex_buffer_layouts: []Vertex_Buffer_Layout, vertex_buffers: []Gfx_Buffer, index_buffer: Gfx_Buffer) -> (Gfx_Vertex_Array, common.Engine_Error)`
  Creates a vertex array object (or equivalent) that defines vertex buffer bindings and attribute layouts.
- `destroy_vertex_array: proc(vao: Gfx_Vertex_Array)`
  Destroys a vertex array object.
- `bind_vertex_array: proc(device: Gfx_Device, vao: Gfx_Vertex_Array)`
  Binds a vertex array object for subsequent drawing commands (pass an empty Gfx_Vertex_Array to unbind).

#### Texture Utilities

- `get_texture_width: proc(texture: Gfx_Texture) -> int`
  Retrieves the width of the specified texture.
- `get_texture_height: proc(texture: Gfx_Texture) -> int`
  Retrieves the height of the specified texture.

#### Utility

- `get_error_string: proc(error: common.Engine_Error) -> string`
  Converts an engine error code into a human-readable string.

### Global API Instance and Helpers

#### gfx_api

```odin
gfx_api: Gfx_Device_Interface
```
A global instance of the `Gfx_Device_Interface`. This variable is populated by the chosen graphics backend (e.g., OpenGL, Vulkan) during engine initialization and provides access to all graphics functions.

#### default_clear_options

```odin
default_clear_options :: proc() -> Clear_Options
```
A helper procedure that returns a `Clear_Options` struct initialized with default values (e.g., dark grey color, depth 1.0, stencil 0, clear color and depth enabled).

### Functions

#### new_spritebatch

```odin
new_spritebatch :: proc(device: Gfx_Device, max_sprites: int = MAX_SPRITES_DEFAULT) -> (^SpriteBatch, common.Engine_Error)
```

Creates a new sprite batcher instance. `MAX_SPRITES_DEFAULT` is a compile-time constant (e.g., 2000).

**Parameters:**
- `device`: The graphics device to use for rendering.
- `max_sprites`: The maximum number of sprites that can be batched in a single draw call (default: `MAX_SPRITES_DEFAULT`).

**Returns:**
- A pointer to the created `SpriteBatch` and an `Engine_Error` if creation failed.

#### destroy_spritebatch

```odin
destroy_spritebatch :: proc(sb: ^SpriteBatch)
```

Destroys the sprite batcher and frees its associated graphics resources (VBO, EBO, default texture).

**Parameters:**
- `sb`: The sprite batch to destroy.

#### begin_batch

```odin
begin_batch :: proc(sb: ^SpriteBatch, projection_view_matrix: math.Matrix4f)
```

Begins a sprite batching session. This prepares the batcher for drawing and sets the transformation matrix for the batch. Must be called before any `draw_texture` or `draw_texture_region` calls.

**Parameters:**
- `sb`: The sprite batch instance.
- `projection_view_matrix`: The combined `math.Matrix4f` projection and view matrix to use for rendering sprites in this batch.

#### draw_texture

```odin
draw_texture :: proc(sb: ^SpriteBatch, texture: Gfx_Texture, position: math.Vector2, tint: math.Color = WHITE, origin: math.Vector2 = {0,0}, scale: math.Vector2 = {1,1}, rotation: f32 = 0)
```

Adds a full texture as a sprite to the current batch. The sprite is drawn at the given position, with specified tint, origin, scale, and rotation. If the batch becomes full or the texture changes from the current one, the current batch is flushed to the GPU. (Assumes `WHITE` is a predefined `math.Color` constant).

**Parameters:**
- `sb`: The sprite batch instance.
- `texture`: The `Gfx_Texture` to draw. If `nil`, the batcher's default white texture is used (effectively drawing a tinted rectangle).
- `position`: The 2D `math.Vector2` (x, y) screen position where the sprite's top-left corner (after origin and rotation) will be drawn.
- `tint`: The `math.Color` to tint the sprite (default: `WHITE`, no tint).
- `origin`: The `math.Vector2` (x, y) origin point for rotation and scaling, relative to the sprite's top-left corner (default: `{0,0}`, meaning top-left).
- `scale`: The `math.Vector2` (x, y) scale factor to apply to the sprite (default: `{1,1}`, no scale).
- `rotation`: The rotation angle in radians, counter-clockwise (default: `0`).

#### draw_texture_region

```odin
draw_texture_region :: proc(sb: ^SpriteBatch, texture: Gfx_Texture, src_rect: math.Rectangle, dst_rect: math.Rectangle, tint: math.Color = WHITE, origin: math.Vector2 = {0,0}, rotation: f32 = 0)
```

Adds a specific region of a texture as a sprite to the current batch. The specified source rectangle from the texture is drawn to the destination rectangle on the screen, with given tint, origin, and rotation. If the batch becomes full or the texture changes, the current batch is flushed. (Assumes `WHITE` is a predefined `math.Color` constant).

**Parameters:**
- `sb`: The sprite batch instance.
- `texture`: The `Gfx_Texture` containing the sprite region. If `nil`, a tinted rectangle defined by `dst_rect` is drawn using the default white texture.
- `src_rect`: The `math.Rectangle` (x, y, w, h) defining the source region within the texture to draw (in texture pixel coordinates).
- `dst_rect`: The `math.Rectangle` (x, y, w, h) defining the destination rectangle where on the screen the sprite will be drawn (in screen coordinates, specifying position and size).
- `tint`: The `math.Color` to tint the sprite (default: `WHITE`, no tint).
- `origin`: The `math.Vector2` (x, y) origin point for rotation and scaling, relative to the `dst_rect`'s top-left corner (default: `{0,0}`). The rotation and scaling will be applied around this point.
- `rotation`: The rotation angle in radians, counter-clockwise (default: `0`).

#### end_batch

```odin
end_batch :: proc(sb: ^SpriteBatch)
```

Ends the current sprite batching session. This flushes any remaining sprites in the batch to the GPU. Must be called after all drawing for the batch is complete and before starting a new batch or ending the frame.

**Parameters:**
- `sb`: The sprite batch instance.

#### load_texture_from_file

```odin
load_texture_from_file :: proc(device: Gfx_Device, filepath: string, generate_mipmaps: bool = true) -> (texture: Gfx_Texture, err: common.Engine_Error)
```

Loads a texture from an image file (e.g., PNG, JPG) and creates a `Gfx_Texture`. Optionally generates mipmaps for the texture.

**Parameters:**
- `device`: The graphics device to use for creating the texture.
- `filepath`: The path to the image file.
- `generate_mipmaps`: If true, mipmaps will be generated for the texture (default: true).

**Returns:**
- `texture`: The loaded `Gfx_Texture`.
- `err`: An `Engine_Error` if loading or texture creation failed.

#### create_texture_from_data

```odin
create_texture_from_data :: proc(device: Gfx_Device, width: int, height: int, format: Texture_Format, usage: Texture_Usage, data: rawptr = nil) -> (Gfx_Texture, common.Engine_Error)
```

Creates a `Gfx_Texture` from raw pixel data in memory. This is useful for procedural textures or textures loaded from custom formats.

**Parameters:**
- `device`: The graphics device to use.
- `width`: The width of the texture in pixels.
- `height`: The height of the texture in pixels.
- `format`: The `Texture_Format` of the pixel data.
- `usage`: The `Texture_Usage` flags specifying how the texture will be used.
- `data`: A pointer to the raw pixel data, or `nil` to create an uninitialized texture.

**Returns:**
- The created `Gfx_Texture` and an `Engine_Error` if creation failed.

#### destroy_texture

```odin
destroy_texture :: proc(tex: ^Gfx_Texture)
```

Releases a reference to a `Gfx_Texture`. The texture is fully destroyed and its resources are freed when its reference count reaches zero.

**Parameters:**
- `tex`: A pointer to the `Gfx_Texture` to release.

### Font Rendering

This section covers types and functions related to loading and rendering text. OdinGame supports both bitmap fonts (pre-rendered character sets in a texture atlas) and TrueType Fonts (TTF) for dynamic rendering.

#### Bitmap Font Types

##### `font.CharacterInfo`

```odin
font.CharacterInfo :: struct {
    x:        f32, // X position of the character in the font texture
    y:        f32, // Y position of the character in the font texture
    width:    f32, // Width of the character in the font texture
    height:   f32, // Height of the character in the font texture
    xoffset:  f32, // Offset to apply to the character's X position when rendering
    yoffset:  f32, // Offset to apply to the character's Y position when rendering
    xadvance: f32, // How far to advance the X position for the next character
}
```
Stores information about a single character in a bitmap font, including its location and dimensions in the font texture atlas, and rendering offsets.

##### `font.Font`

```odin
font.Font :: struct {
    texture:    Gfx_Texture,       // The texture atlas containing all characters
    char_width: int,               // Width of a single character cell in the atlas
    // char_height, char_infos map, etc. are also part of this struct
    // ... (other fields might include spacing, line height, etc.)
}
```
Represents a bitmap font, consisting of a texture atlas (`Gfx_Texture`) and metadata for each character. (Note: The definition here is summarized; actual implementation contains more detail like `char_height` and `char_infos` map).

#### Bitmap Font Functions

##### `load_default_font`

```odin
load_default_font :: proc(device: Gfx_Device, char_width: int, char_height: int) -> (^font.Font, common.Engine_Error)
```
Loads a built-in default bitmap font.

**Parameters:**
- `device`: The graphics device.
- `char_width`: The width of each character in the default font.
- `char_height`: The height of each character in the default font.

**Returns:**
- A pointer to the loaded `font.Font` and an error if loading failed.

##### `destroy_font`

```odin
destroy_font :: proc(font: ^font.Font)
```
Frees the resources associated with a `font.Font`, including its texture.

**Parameters:**
- `font`: The bitmap font to destroy.

##### `font.get_char_info`

```odin
font.get_char_info :: proc(font: ^font.Font, char: rune) -> ^font.CharacterInfo
```
Retrieves the `CharacterInfo` for a specific rune from a bitmap font.

**Parameters:**
- `font`: The bitmap font.
- `char`: The rune (character) to look up.

**Returns:**
- A pointer to the `font.CharacterInfo` for the rune, or `nil` if not found.

##### `draw_string`

```odin
draw_string :: proc(sb: ^SpriteBatch, font: ^font.Font, text: string, position: math.Vector2, tint: types.Color = WHITE, scale: f32 = 1.0)
```
Draws a string of text using the specified bitmap font and `SpriteBatch`. (Assumes `WHITE` is a predefined `types.Color` constant from the Types module).

**Parameters:**
- `sb`: The `SpriteBatch` to use for drawing.
- `font`: The `font.Font` to use for rendering the text.
- `text`: The string to draw.
- `position`: The `math.Vector2` screen position where the top-left of the text will start.
- `tint`: The `types.Color` to apply to the text (default: `WHITE`).
- `scale`: The uniform scale factor to apply to the text (default: `1.0`).

#### TrueType Font (TTF) Support

These types and functions allow for loading and rendering text using TrueType Font files.

##### `ttf.TTF_Font`

```odin
ttf.TTF_Font :: struct {
    sdl_font:  ^ttf.Font, // Internal pointer to the loaded TTF font data (e.g., from SDL_ttf)
    size:      i32,       // Point size the font was loaded at
    line_skip: i32,       // Recommended vertical spacing between lines of text
}
```
Represents a TrueType Font loaded at a specific size.

##### `ttf.load_ttf_font`

```odin
ttf.load_ttf_font :: proc(filename: string, point_size: i32) -> (font: ttf.TTF_Font, ok: bool)
```
Loads a TrueType Font from a `.ttf` file at a specified point size.

**Parameters:**
- `filename`: The path to the TTF font file.
- `point_size`: The point size to load the font at.

**Returns:**
- `font`: The loaded `ttf.TTF_Font`.
- `ok`: True if loading was successful, false otherwise.

##### `ttf.free_ttf_font`

```odin
ttf.free_ttf_font :: proc(font: ^ttf.TTF_Font)
```
Frees the resources associated with a loaded `ttf.TTF_Font`.

**Parameters:**
- `font`: A pointer to the TTF font to free.

##### `ttf.render_text_ttf`

```odin
ttf.render_text_ttf :: proc(device: ^Gfx_Device, font: ^ttf.TTF_Font, text: string, color: types.Color) -> (texture: Gfx_Texture, width: i32, height: i32, ok: bool)
```
Renders a string of text using a loaded TTF font into a new `Gfx_Texture`.

**Parameters:**
- `device`: A pointer to the graphics device.
- `font`: A pointer to the `ttf.TTF_Font` to use.
- `text`: The string to render.
- `color`: The `types.Color` to use for the rendered text.

**Returns:**
- `texture`: A new `Gfx_Texture` containing the rendered text.
- `width`: The width of the resulting texture.
- `height`: The height of the resulting texture.
- `ok`: True if rendering was successful, false otherwise.

## Input Module

The Input module handles user input from keyboard, mouse, and gamepads.

### Types

#### Key

`Key` is an alias for `sdl2.Scancode`. It represents physical key locations on a keyboard.
Examples: `Key.A`, `Key.Space`, `Key.Up`, `Key.Escape`.

### Functions

#### is_key_down

```odin
is_key_down :: proc(key: Key) -> bool
```

Checks if a key is currently held down.

**Parameters:**
- `key`: The `Key` (scancode) to check.

**Returns:**
- True if the key is currently held down, false otherwise.

#### is_key_up

```odin
is_key_up :: proc(key: Key) -> bool
```

Checks if a key is currently not held down.

**Parameters:**
- `key`: The `Key` (scancode) to check.

**Returns:**
- True if the key is currently up, false otherwise.

#### is_key_pressed

```odin
is_key_pressed :: proc(key: Key) -> bool
```

Checks if a key was pressed down this frame (was up last frame, is down this frame).

**Parameters:**
- `key`: The `Key` (scancode) to check.

**Returns:**
- True if the key was pressed this frame, false otherwise.

#### is_key_released

```odin
is_key_released :: proc(key: Key) -> bool
```

Checks if a key was released this frame (was down last frame, is up this frame).

**Parameters:**
- `key`: The `Key` (scancode) to check.

**Returns:**
- True if the key was released this frame, false otherwise.

#### is_mouse_button_down

```odin
is_mouse_button_down :: proc(button_index: int) -> bool
```

Checks if a mouse button is currently held down.

**Parameters:**
- `button_index`: The index of the mouse button (e.g., 0 for left, 1 for middle, 2 for right).

**Returns:**
- True if the button is currently held down, false otherwise.

#### is_mouse_button_up

```odin
is_mouse_button_up :: proc(button_index: int) -> bool
```

Checks if a mouse button is currently not held down.

**Parameters:**
- `button_index`: The index of the mouse button (e.g., 0 for left, 1 for middle, 2 for right).

**Returns:**
- True if the button is currently up, false otherwise.

#### is_mouse_button_pressed

```odin
is_mouse_button_pressed :: proc(button_index: int) -> bool
```

Checks if a mouse button was pressed down this frame.

**Parameters:**
- `button_index`: The index of the mouse button (e.g., 0 for left, 1 for middle, 2 for right).

**Returns:**
- True if the button was pressed this frame, false otherwise.

#### is_mouse_button_released

```odin
is_mouse_button_released :: proc(button_index: int) -> bool
```

Checks if a mouse button was released this frame.

**Parameters:**
- `button_index`: The index of the mouse button (e.g., 0 for left, 1 for middle, 2 for right).

**Returns:**
- True if the button was released this frame, false otherwise.

#### get_mouse_position

```odin
get_mouse_position :: proc() -> (x: i32, y: i32)
```

Gets the current mouse cursor position in window coordinates.

**Returns:**
- `x`: The x-coordinate of the mouse.
- `y`: The y-coordinate of the mouse.

#### get_mouse_scroll_delta

```odin
get_mouse_scroll_delta :: proc() -> (dx: i32, dy: i32)
```

Gets the amount the mouse wheel was scrolled this frame.

**Returns:**
- `dx`: The horizontal scroll delta.
- `dy`: The vertical scroll delta.

#### is_quit_requested

```odin
is_quit_requested :: proc() -> bool
```

Checks if a quit event (e.g., closing the window) has been requested.

**Returns:**
- True if a quit event has been requested, false otherwise.

## Types Module

The Types module provides common data structures and type aliases used throughout the OdinGame framework, often leveraging the `core:linalg` package for mathematical types.

### Types

#### Vector2

```odin
Vector2 :: struct { x, y: f32 } // Equivalent to linalg.Vector2f
```

Represents a 2D vector with single-precision floating-point components. This is typically used for positions, velocities, and texture coordinates.

#### Vector2f

```odin
Vector2f :: struct {x, y: f32} // Alias for linalg.Vector2f
```

Represents a 2D vector with single-precision floating-point components.

#### Vector2i

```odin
Vector2i :: struct {x, y: i32} // Alias for linalg.Vector2i
```

Represents a 2D vector with integer components. Useful for grid coordinates or screen pixel positions.

#### Vector3 / Vector3f

```odin
Vector3f :: struct {x, y, z: f32} // Alias for linalg.Vector3f
```
`Vector3` is an alias for `Vector3f`. Represents a 3D vector with single-precision floating-point components. Commonly used for 3D positions, directions, or colors.

#### Vector4 / Vector4f

```odin
Vector4f :: struct {x, y, z, w: f32} // Alias for linalg.Vector4f
```
`Vector4` is an alias for `Vector4f`. Represents a 4D vector with single-precision floating-point components. Often used for homogeneous coordinates or colors with an alpha channel.

#### Matrix4 / Matrix4f

```odin
Matrix4f :: matrix[4,4]f32 // Alias for linalg.Matrix4f
```
`Matrix4` is an alias for `Matrix4f`. Represents a 4x4 matrix of single-precision floating-point numbers, typically used for transformation matrices (translation, rotation, scale, projection) in 3D graphics.

#### Color

```odin
Color :: struct { r, g, b, a: u8 }
```

Represents a color with red, green, blue, and alpha components, each stored as an 8-bit unsigned integer (0-255).

#### Rectf

```odin
Rectf :: struct { x, y, w, h: f32 }
```

Represents a rectangle with floating-point coordinates for its position (x, y) and dimensions (width, height).

#### Recti

```odin
Recti :: struct { x, y, w, h: i32 }
```

Represents a rectangle with integer coordinates for its position (x, y) and dimensions (width, height).

### Constants

```odin
BLACK           :: Color{0, 0, 0, 255}
WHITE           :: Color{255, 255, 255, 255}
RED             :: Color{255, 0, 0, 255}
GREEN           :: Color{0, 255, 0, 255}
BLUE            :: Color{0, 0, 255, 255}
CORNFLOWER_BLUE :: Color{100, 149, 237, 255}
TRANSPARENT     :: Color{0, 0, 0, 0}
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
