package graphics

Gfx_Error :: enum {
	None,
	Initialization_Failed,
	Device_Creation_Failed,
	Window_Creation_Failed,
	Shader_Compilation_Failed,
	Buffer_Creation_Failed,
	Texture_Creation_Failed,
	Invalid_Handle,
	Not_Implemented,
}

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

Viewport :: struct {
	x:      f32,
	y:      f32,
	width:  f32,
	height: f32,
	min_depth: f32,
	max_depth: f32,
}

Scissor :: struct {
	x:      i32,
	y:      i32,
	width:  i32,
	height: i32,
}

// --- Interfaces ---

Gfx_Device :: struct_variant {
	// Specific implementations will go here, e.g., opengl: ^Gl_Device
}

Gfx_Window :: struct_variant {
	// Specific implementations will go here, e.g., opengl: ^Gl_Window
}

Gfx_Shader :: struct_variant {
	// e.g. opengl: ^Gl_Shader
}

Gfx_Pipeline :: struct_variant {
    // e.g. opengl: ^Gl_Pipeline
}

Gfx_Buffer :: struct_variant {
	// e.g. opengl: ^Gl_Buffer
}

Gfx_Texture :: struct_variant {
	// e.g. opengl: ^Gl_Texture
}


Gfx_Device_Interface :: struct #ordered {
	// Device Management
	create_device: proc(allocator: ^rawptr) -> (Gfx_Device, Gfx_Error), // User provides allocator
	destroy_device: proc(device: Gfx_Device),

	// Window/Swapchain Management
	create_window: proc(device: Gfx_Device, title: string, width, height: int) -> (Gfx_Window, Gfx_Error),
	destroy_window: proc(window: Gfx_Window),
	present_window: proc(window: Gfx_Window) -> Gfx_Error,
	resize_window: proc(window: Gfx_Window, width, height: int) -> Gfx_Error,
	get_window_size: proc(window: Gfx_Window) -> (width, height: int),
    get_window_drawable_size: proc(window: Gfx_Window) -> (width, height: int), // For high DPI

	// Shader Management
	create_shader_from_source: proc(device: Gfx_Device, source: string, stage: Shader_Stage) -> (Gfx_Shader, Gfx_Error),
	create_shader_from_bytecode: proc(device: Gfx_Device, bytecode: []u8, stage: Shader_Stage) -> (Gfx_Shader, Gfx_Error),
	destroy_shader: proc(shader: Gfx_Shader),

    // Pipeline Management
    // TODO: Define pipeline state (blend, depth, stencil, rasterization, etc.)
    create_pipeline: proc(device: Gfx_Device, shaders: []Gfx_Shader /*, other pipeline state */) -> (Gfx_Pipeline, Gfx_Error),
    destroy_pipeline: proc(pipeline: Gfx_Pipeline),

	// Buffer Management
	create_buffer: proc(device: Gfx_Device, type: Buffer_Type, size: int, data: rawptr = nil, dynamic: bool = false) -> (Gfx_Buffer, Gfx_Error),
	update_buffer: proc(buffer: Gfx_Buffer, offset: int, data: rawptr, size: int) -> Gfx_Error,
	destroy_buffer: proc(buffer: Gfx_Buffer),
    map_buffer: proc(buffer: Gfx_Buffer, offset, size: int) -> rawptr,
    unmap_buffer: proc(buffer: Gfx_Buffer),


	// Texture Management
	create_texture: proc(device: Gfx_Device, width, height: int, format: Texture_Format, usage: Texture_Usage, data: rawptr = nil) -> (Gfx_Texture, Gfx_Error),
	update_texture: proc(texture: Gfx_Texture, x, y, width, height: int, data: rawptr) -> Gfx_Error,
	destroy_texture: proc(texture: Gfx_Texture),

	// Drawing Commands
	begin_frame: proc(device: Gfx_Device), // Signifies start of a new frame
	end_frame: proc(device: Gfx_Device),   // Signifies end of a frame, may trigger command buffer submission

	clear_screen: proc(device: Gfx_Device, options: Clear_Options),
    set_viewport: proc(device: Gfx_Device, viewport: Viewport),
    set_scissor: proc(device: Gfx_Device, scissor: Scissor),
	set_pipeline: proc(device: Gfx_Device, pipeline: Gfx_Pipeline),
	set_vertex_buffer: proc(device: Gfx_Device, buffer: Gfx_Buffer, binding_index: u32 = 0, offset: u32 = 0),
	set_index_buffer: proc(device: Gfx_Device, buffer: Gfx_Buffer, offset: u32 = 0), // Assuming u16 or u32 indices based on buffer creation or a global setting
    // TODO: set_uniform_buffer, set_textures (need to define descriptor sets / binding points)
	draw: proc(device: Gfx_Device, vertex_count, instance_count, first_vertex, first_instance: u32),
	draw_indexed: proc(device: Gfx_Device, index_count, instance_count, first_index, base_vertex, first_instance: u32),

	// Uniform & Resource Binding (associated with a bound pipeline)
	// These assume a pipeline is already bound with set_pipeline.
	set_uniform_mat4: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, mat: matrix[4,4]f32) -> Gfx_Error,
	set_uniform_vec2: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, vec: [2]f32) -> Gfx_Error,
	set_uniform_vec3: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, vec: [3]f32) -> Gfx_Error,
	set_uniform_vec4: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, vec: [4]f32) -> Gfx_Error,
	set_uniform_int: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, val: i32) -> Gfx_Error,
	set_uniform_float: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, val: f32) -> Gfx_Error,
	
	bind_texture_to_unit: proc(device: Gfx_Device, texture: Gfx_Texture, unit: u32) -> Gfx_Error,
	// set_sampler (for controlling texture sampling parameters like filter, wrap) could be here too,
	// or part of texture creation/pipeline state. For now, keeping it simple.


	// Vertex Array Objects / Vertex Layouts
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
	}

	// Creates a VAO. For OpenGL, this encapsulates VBO bindings, EBO binding, and vertex attribute pointers.
	// `vertex_buffer_layouts` describes how attributes are laid out in the provided `vertex_buffers`.
	// `vertex_buffers` are the actual VBOs to bind. The layout refers to these by index or a binding point.
	// For simple cases (like SpriteBatch), one layout, one VBO.
	create_vertex_array: proc(
		device: Gfx_Device, 
		vertex_buffer_layouts: []Vertex_Buffer_Layout, 
		vertex_buffers: []Gfx_Buffer, // VBOs
		index_buffer: Gfx_Buffer,      // EBO (optional, Gfx_Buffer{} if none)
	) -> (Gfx_Vertex_Array, Gfx_Error),
	
	destroy_vertex_array: proc(vao: Gfx_Vertex_Array),
	bind_vertex_array:    proc(device: Gfx_Device, vao: Gfx_Vertex_Array), // Pass Gfx_Vertex_Array{} to unbind.

	// Texture Utilities
	get_texture_width:  proc(texture: Gfx_Texture) -> int,
	get_texture_height: proc(texture: Gfx_Texture) -> int,

    // Utility
    get_error_string: proc(error: Gfx_Error) -> string,
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
