package graphics

import "../common" // For Engine_Error
import "../types" // For common types like Vector2, Color, etc.
import "core:math"

Gfx_Handle :: distinct u32

INVALID_HANDLE :: Gfx_Handle(0)

Buffer_Type :: enum {
	Vertex,
	Index,
	Uniform,
}

Texture_Format :: enum {
	R8,
	RGB8,
	RGBA8,
	SRGBA8, // sRGB with Alpha
	Depth24_Stencil8,
}

Texture_Usage :: enum_flags {
	Sampled,
	Storage,
	Color_Attachment,
	Depth_Stencil_Attachment,
}

Shader_Stage :: enum_flags {
	Vertex,
	Fragment,
	Compute,
}

Blend_Mode :: enum {
	None,
	Alpha,
	Additive,
	Multiplicative,
}

Depth_Func :: enum {
	Never,
	Less,
	Equal,
	Less_Equal,
	Greater,
	Not_Equal,
	Greater_Equal,
	Always,
}

Cull_Mode :: enum {
	None,
	Front,
	Back,
}

Primitive_Topology :: enum {
	Triangle_List,
	Triangle_Strip,
	Line_List,
	Point_List,
}

Clear_Options :: struct {
	color:          [4]f32,
	depth:          f32,
	stencil:        u8,
	clear_color:    bool,
	clear_depth:    bool,
	clear_stencil:  bool,
}

// Use types from the types package where possible
// Viewport defines a rectangular area of the render target that will be rendered to
// It includes position, size, and depth range parameters
Viewport :: struct {
	position: types.Vector2,  // x, y position in the render target
	size: types.Vector2,      // width and height of the viewport
	depth_range: [2]f32,      // min and max depth values (typically 0.0 to 1.0)
}

// Use Rectangle from types package for scissor
Scissor :: types.Recti

// --- Interfaces ---

Gfx_Device :: struct {
	variant: rawptr // Will hold the backend-specific device pointer
}

is_valid :: proc(d: Gfx_Device) -> bool {
	return d.variant != nil
}

Gfx_Window :: struct {
	variant: rawptr // Will hold the backend-specific window pointer
}

Gfx_Shader :: struct {
	variant: rawptr // Will hold the backend-specific shader pointer
}

Gfx_Pipeline :: struct {
	variant: rawptr // Will hold the backend-specific pipeline pointer
}

Gfx_Buffer :: struct {
	variant: rawptr // Will hold the backend-specific buffer pointer
}

Gfx_Texture :: struct {
	variant: rawptr // Will hold the backend-specific texture pointer
}

Gfx_Framebuffer :: struct {
	variant: rawptr // Will hold the backend-specific framebuffer pointer
}

Gfx_Render_Pass :: struct {
	variant: rawptr // Will hold the backend-specific render pass pointer
}

// Vertex attribute and buffer layout definitions
// Describes a single vertex attribute.
Vertex_Attribute :: struct {
	location:         u32,    // Shader location
	buffer_binding:   u32,    // Which buffer binding this attribute reads from (if multiple VBOs bound)
	format:           Vertex_Format, // Format of the attribute data (e.g., Float32_X2, Unorm8_X4)
	offset_in_bytes:  u32,    // Offset within the vertex structure to this attribute
}

// Describes the layout of data in a single vertex buffer.
Vertex_Buffer_Layout :: struct {
	binding:          u32,     // The binding point for this buffer (e.g., for glBindVertexBuffer)
	stride_in_bytes:  u32,     // Stride of the vertex data in this buffer.
	attributes:       []Vertex_Attribute, // Attributes sourced from this buffer.
	// step_rate:     Input_Step_Rate, // TODO: For instancing (.Vertex or .Instance)
}

Vertex_Format :: enum {
	Float32_X1,
	Float32_X2,
	Float32_X3,
	Float32_X4,
	Unorm8_X4, // For colors (u8 r,g,b,a normalized to 0-1 float)
	// Add more as needed: Sint16_X2, etc.
}

Gfx_Vertex_Array :: struct_variant { // e.g. opengl: ^Gl_Vertex_Array
	vulkan: ^rawptr // Will hold ^vulkan.Vk_Vertex_Array_Internal
}

// Gfx_Device_Interface defines the graphics API interface that all backends must implement
// This allows the engine to work with multiple graphics APIs (OpenGL, Vulkan, DirectX, Metal)
// while providing a consistent interface to the rest of the codebase
Gfx_Device_Interface :: struct {
	// Device Management
	// Creates a graphics device using the provided allocator
	create_device: proc(allocator: ^rawptr) -> (Gfx_Device, common.Engine_Error),
	// Destroys a graphics device and frees associated resources
	destroy_device: proc(device: Gfx_Device),

	// Window/Swapchain Management
	// Creates a window associated with the given device
	create_window: proc(device: Gfx_Device, title: string, width, height: int) -> (Gfx_Window, common.Engine_Error),
	// Destroys a window and frees associated resources
	destroy_window: proc(window: Gfx_Window),
	// Presents the current frame to the window (swap buffers)
	present_window: proc(window: Gfx_Window) -> common.Engine_Error,
	// Resizes the window to the specified dimensions
	resize_window: proc(window: Gfx_Window, width, height: int) -> common.Engine_Error,
	// Sets the window title
	set_window_title: proc(window: Gfx_Window, title: string) -> common.Engine_Error,
	// Gets the logical size of the window
	get_window_size: proc(window: Gfx_Window) -> (width, height: int),
	// Gets the drawable size of the window (may differ from logical size on high DPI displays)
	get_window_drawable_size: proc(window: Gfx_Window) -> (width, height: int),

	// Shader Management
	create_shader_from_source: proc(device: Gfx_Device, source: string, stage: Shader_Stage) -> (Gfx_Shader, common.Engine_Error),
	create_shader_from_bytecode: proc(device: Gfx_Device, bytecode: []u8, stage: Shader_Stage) -> (Gfx_Shader, common.Engine_Error),
	destroy_shader: proc(shader: Gfx_Shader),

    // Pipeline Management
    // TODO: Define pipeline state (blend, depth, stencil, rasterization, etc.)
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
	bind_texture_to_unit: proc(device: Gfx_Device, texture: Gfx_Texture, unit: int),
	get_texture_width: proc(texture: Gfx_Texture) -> int,
	get_texture_height: proc(texture: Gfx_Texture) -> int,

	// Drawing Commands
	begin_frame: proc(device: Gfx_Device), // Signifies start of a new frame
	end_frame: proc(device: Gfx_Device),   // Signifies end of a frame, may trigger command buffer submission

	clear_screen: proc(device: Gfx_Device, options: Clear_Options),
    set_viewport: proc(device: Gfx_Device, viewport: Viewport),
    set_scissor: proc(device: Gfx_Device, scissor: Scissor),
    disable_scissor: proc(device: Gfx_Device),
	set_pipeline: proc(device: Gfx_Device, pipeline: Gfx_Pipeline),
	set_vertex_buffer: proc(device: Gfx_Device, buffer: Gfx_Buffer, binding_index: u32 = 0, offset: u32 = 0),
	set_index_buffer: proc(device: Gfx_Device, buffer: Gfx_Buffer, offset: u32 = 0), // Assuming u16 or u32 indices based on buffer creation or a global setting
    // TODO: set_uniform_buffer, set_textures (need to define descriptor sets / binding points)
	draw: proc(device: Gfx_Device, vertex_count, instance_count, first_vertex, first_instance: u32),
	draw_indexed: proc(device: Gfx_Device, index_count, instance_count, first_index, base_vertex, first_instance: u32),

	// Framebuffer Management
	create_framebuffer: proc(device: Gfx_Device, width, height: int, color_format: Texture_Format, depth_format: Texture_Format) -> (Gfx_Framebuffer, common.Engine_Error),
	destroy_framebuffer: proc(framebuffer: Gfx_Framebuffer),

	// Render Pass Management
	create_render_pass: proc(device: Gfx_Device, framebuffer: Gfx_Framebuffer, clear_color, clear_depth: bool) -> (Gfx_Render_Pass, common.Engine_Error),
	begin_render_pass: proc(device: Gfx_Device, render_pass: Gfx_Render_Pass, clear_color: math.Color, clear_depth: f32),
	end_render_pass: proc(device: Gfx_Device, render_pass: Gfx_Render_Pass),

	// State Management
	set_blend_mode: proc(device: Gfx_Device, blend_mode: Blend_Mode),
	set_depth_test: proc(device: Gfx_Device, enabled: bool, write: bool, func: Depth_Func),
	set_cull_mode: proc(device: Gfx_Device, cull_mode: Cull_Mode),

	// Uniform & Resource Binding (associated with a bound pipeline)
	// These assume a pipeline is already bound with set_pipeline.
	set_uniform_mat4: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, mat: matrix[4,4]f32) -> common.Engine_Error,
	set_uniform_vec2: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, vec: [2]f32) -> common.Engine_Error,
	set_uniform_vec3: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, vec: [3]f32) -> common.Engine_Error,
	set_uniform_vec4: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, vec: [4]f32) -> common.Engine_Error,
	set_uniform_int: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, val: i32) -> common.Engine_Error,
	set_uniform_float: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, val: f32) -> common.Engine_Error,
	
	bind_texture_to_unit: proc(device: Gfx_Device, texture: Gfx_Texture, unit: u32) -> common.Engine_Error,
	// set_sampler (for controlling texture sampling parameters like filter, wrap) could be here too,
	// or part of texture creation/pipeline state. For now, keeping it simple.


	// Vertex Array Objects / Vertex Layouts

	// Creates a VAO. For OpenGL, this encapsulates VBO bindings, EBO binding, and vertex attribute pointers.
	// `vertex_buffer_layouts` describes how attributes are laid out in the provided `vertex_buffers`.
	// `vertex_buffers` are the actual VBOs to bind. The layout refers to these by index or a binding point.
	// For simple cases (like SpriteBatch), one layout, one VBO.
	create_vertex_array: proc(
		device: Gfx_Device, 
		vertex_buffer_layouts: []Vertex_Buffer_Layout, 
		vertex_buffers: []Gfx_Buffer, // VBOs
		index_buffer: Gfx_Buffer      // EBO (optional, Gfx_Buffer{} if none)
	) -> (Gfx_Vertex_Array, common.Engine_Error),
	
	destroy_vertex_array: proc(vao: Gfx_Vertex_Array),
	bind_vertex_array:    proc(device: Gfx_Device, vao: Gfx_Vertex_Array), // Pass Gfx_Vertex_Array{} to unbind.

	// Texture Utilities
	get_texture_width:  proc(texture: Gfx_Texture) -> int,
	get_texture_height: proc(texture: Gfx_Texture) -> int,

    // Utility
    get_error_string: proc(error: common.Engine_Error) -> string,
}

// Global instance of the interface, to be populated by a specific backend (e.g., OpenGL)
gfx_api: Gfx_Device_Interface

// Helper to get a default clear options
default_clear_options :: proc() -> Clear_Options {
    return Clear_Options{
        color = {0.1, 0.1, 0.1, 1.0},
        depth = 1.0,
        stencil = 0,
        clear_color = true,
        clear_depth = true,
        clear_stencil = false,
    }
}
