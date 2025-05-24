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

Texture_Type :: enum { // Added
    Tex1D,
    Tex1D_Array,
    Tex2D,
    Tex2D_Array,
    Tex2D_Multisample, // Not fully supported by create_texture yet
    TexCube,
    TexCube_Array,
    Tex3D,
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
	variant: rawptr // Will hold the backend-specific render pass object (e.g. for Vulkan)
}

// Gfx_Frame_Context_Info holds transient, per-frame data needed by various rendering commands,
// especially for backends like Metal that use specific per-frame objects like drawables and command buffers.
Gfx_Frame_Context_Info :: struct {
    // Metal specific (rawptr to Metal handles)
    mtl_current_drawable: rawptr, 
    mtl_command_buffer:   rawptr,
    mtl_main_render_pass_descriptor: rawptr, // Descriptor for the main pass (to screen drawable)
    
    // Vulkan specific (conceptual)
    // vk_current_frame_index: u32,
    // vk_current_command_buffer: rawptr, 
    // vk_current_image_index: u32, // For swapchain image

    // Other backend specific data can be added here, possibly in a union if mutually exclusive.
    // For now, Metal fields are direct.
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
Vertex_Step_Rate :: enum {
    Per_Vertex,
    Per_Instance,
}

Vertex_Buffer_Layout :: struct {
	binding:          u32,     // The binding point for this buffer (e.g., for glBindVertexBuffer)
	stride_in_bytes:  u32,     // Stride of the vertex data in this buffer.
	attributes:       []Vertex_Attribute, // Attributes sourced from this buffer.
	step_rate:        Vertex_Step_Rate, // Added for instancing
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

// Gfx_Pipeline_Blend_State_Desc describes blending for a single render target.
Gfx_Pipeline_Blend_State_Desc :: struct {
    blend_enable:      bool,
    src_factor_rgb:    Blend_Factor, // Renamed from Blend_Mode
    dst_factor_rgb:    Blend_Factor,
    op_rgb:            Blend_Op,     // Renamed from Blend_Mode
    src_factor_alpha:  Blend_Factor,
    dst_factor_alpha:  Blend_Factor,
    op_alpha:          Blend_Op,
    color_write_mask:  Color_Write_Mask_Flags, // New enum for R,G,B,A flags
}

// Gfx_Pipeline_Depth_Stencil_State_Desc describes depth and stencil testing.
Gfx_Stencil_Op_Desc :: struct {
    fail_op:       Stencil_Op,
    depth_fail_op: Stencil_Op,
    pass_op:       Stencil_Op,
    compare_op:    Comparison_Func,
}

Gfx_Pipeline_Depth_Stencil_State_Desc :: struct {
    depth_test_enable:  bool,
    depth_write_enable: bool,
    depth_compare_op:   Comparison_Func, 
    stencil_enable:     bool,
    stencil_read_mask:  u8,
    stencil_write_mask: u8,
    front_face_stencil: Gfx_Stencil_Op_Desc, 
    back_face_stencil:  Gfx_Stencil_Op_Desc,
}

// Gfx_Pipeline_Rasterizer_State_Desc describes rasterization behavior.
Gfx_Pipeline_Rasterizer_State_Desc :: struct {
    fill_mode:          Fill_Mode, // New enum: Solid, Wireframe
    cull_mode:          Cull_Mode,
    front_face_winding: Winding_Order, // New enum: Clockwise, CounterClockwise
    depth_bias:         i32, // Or f32 depending on API needs
    depth_bias_clamp:   f32,
    slope_scaled_depth_bias: f32,
    depth_clip_enable:  bool,
    scissor_enable:     bool,
    // multisample_enable: bool, // Usually tied to render target
    // antialiased_line_enable: bool,
}


// Gfx_Pipeline_Desc describes the full state of a graphics pipeline.
Gfx_Pipeline_Desc :: struct {
    vertex_shader:   Gfx_Shader,
    pixel_shader:    Gfx_Shader, // Or fragment_shader
    // geometry_shader: Maybe(Gfx_Shader),
    // hull_shader:     Maybe(Gfx_Shader),
    // domain_shader:   Maybe(Gfx_Shader),
    vertex_layout:   Gfx_Vertex_Layout_Desc, // New encompassing struct for vertex layout
    primitive_topology: Primitive_Topology,
    
    blend_state: Gfx_Pipeline_Blend_State_Desc, // Single blend state for RT0 for now
    // For multiple render targets (MRT), blend_states would be a slice.
    
    depth_stencil_state: Gfx_Pipeline_Depth_Stencil_State_Desc,
    rasterizer_state: Gfx_Pipeline_Rasterizer_State_Desc,
    
    label: string, // Optional debug label for the pipeline
}

// Gfx_Vertex_Layout_Desc describes the complete vertex input layout.
Gfx_Vertex_Layout_Desc :: struct {
    attributes: []Vertex_Attribute, // Overall list of attributes
    buffers:    []Vertex_Buffer_Layout_Desc, // Description for each vertex buffer binding
}
// Vertex_Buffer_Layout_Desc describes a single vertex buffer binding.
Vertex_Buffer_Layout_Desc :: struct {
    binding: u32, // Corresponds to Vertex_Attribute.buffer_binding
    stride_in_bytes: u32,
    step_rate: Vertex_Step_Rate,
}


// New enums needed for Gfx_Pipeline_Desc
Blend_Factor :: enum { Zero, One, Src_Color, Inv_Src_Color, Src_Alpha, Inv_Src_Alpha, Dest_Alpha, Inv_Dest_Alpha, Dest_Color, Inv_Dest_Color, Src_Alpha_Sat, Blend_Factor_Color, Inv_Blend_Factor_Color }
Blend_Op :: enum { Add, Subtract, Rev_Subtract, Min, Max }
Color_Write_Mask_Flags :: enum_flags { R = 1, G = 2, B = 4, A = 8, All = (R|G|B|A) }
Comparison_Func :: enum { Never, Less, Equal, Less_Equal, Greater, Not_Equal, Greater_Equal, Always } 
Stencil_Op :: enum { Keep, Zero, Replace, Incr_Sat, Decr_Sat, Invert, Incr, Decr } // Added
Fill_Mode :: enum { Solid, Wireframe }
Winding_Order :: enum { Clockwise, CounterClockwise }


Gfx_Device_Interface :: struct {
	// Device Management
	create_device: proc(allocator: ^rawptr) -> (Gfx_Device, common.Engine_Error),
	destroy_device: proc(device: Gfx_Device),

	// Window/Swapchain Management
    create_window: proc(device: Gfx_Device, title: string, width, height: int, vsync: bool, sdl_window_rawptr: rawptr) -> (Gfx_Window, common.Engine_Error),
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
    create_texture: proc(
        device: Gfx_Device, 
        width: int, height: int, depth: int, // Added depth
        format: Texture_Format, 
        type: Texture_Type,                 // Added type
        usage: Texture_Usage_Flags, 
        mip_levels: int,                    // Added mip_levels
        array_length: int,                  // Added array_length
        data: rawptr = nil, 
        data_pitch: int = 0,                // Added data_pitch
        data_slice_pitch: int = 0,          // Added data_slice_pitch
        label: string = "",                 // Added label (was already there in some backend impls)
    ) -> (Gfx_Texture, common.Engine_Error),
	update_texture: proc(
        device: Gfx_Device, // Added device context for consistency, though Metal might use encoder from elsewhere
        texture: Gfx_Texture, 
        level: int,                         // Added level
        x: int, y: int, z: int,             // Added z offset
        width: int, height: int, depth_dim: int, // Added depth_dim for region
        data: rawptr, 
        data_pitch: int, 
        data_slice_pitch: int,              // Added data_slice_pitch
    ) -> common.Engine_Error,
	destroy_texture: proc(texture: Gfx_Texture) -> common.Engine_Error, // Changed to return error
	// bind_texture_to_unit: proc(device: Gfx_Device, texture: Gfx_Texture, unit: int), // Old signature
	get_texture_width: proc(texture: Gfx_Texture) -> int,
	get_texture_height: proc(texture: Gfx_Texture) -> int,

	// Drawing Commands & Frame Lifecycle
    // begin_frame now returns a context info struct which may contain frame-specific handles (e.g. Metal drawable, command buffer)
	begin_frame: proc(device: Gfx_Device, window: Gfx_Window) -> (common.Engine_Error, ^Gfx_Frame_Context_Info), 
	clear_screen: proc(device: Gfx_Device, frame_ctx: ^Gfx_Frame_Context_Info, options: Clear_Options), // Uses frame_ctx for Metal RPD
    
    // begin_render_pass now takes frame_ctx (for descriptor) and returns an encoder_handle (rawptr to backend encoder)
	begin_render_pass: proc(device: Gfx_Device, frame_ctx: ^Gfx_Frame_Context_Info /*, pass_desc: Render_Pass_Desc (target,etc)*/) -> rawptr, 
	end_render_pass: proc(encoder_handle: rawptr), // Takes encoder from begin_render_pass

    // Drawing commands now take an encoder_handle
	draw: proc(encoder_handle: rawptr, device: Gfx_Device, vertex_count, instance_count, first_vertex, first_instance: u32),
	draw_indexed: proc(encoder_handle: rawptr, device: Gfx_Device, index_count, instance_count, first_index, base_vertex, first_instance: u32),
    
    // end_frame now takes frame_ctx for presentation (Metal needs drawable & command buffer)
	end_frame: proc(device: Gfx_Device, window: Gfx_Window, frame_ctx: ^Gfx_Frame_Context_Info),   

    // Other state settings (can be on device or encoder depending on API)
    set_viewport: proc(encoder_or_device_handle: rawptr, viewport: Viewport), // Handle could be device or encoder
    set_scissor: proc(encoder_or_device_handle: rawptr, scissor: Scissor),
    disable_scissor: proc(encoder_or_device_handle: rawptr),
	set_pipeline: proc(encoder_or_device_handle: rawptr, pipeline: Gfx_Pipeline), // Takes encoder for Metal, device for GL
	set_vertex_buffer: proc(encoder_or_device_handle: rawptr, buffer: Gfx_Buffer, binding_index: u32 = 0, offset: u32 = 0),
	set_index_buffer: proc(encoder_or_device_handle: rawptr, buffer: Gfx_Buffer, offset: u32 = 0), 
    
    // Uniform & Resource Binding (associated with a bound pipeline, on encoder or device)
	set_uniform_mat4: proc(encoder_or_device_handle: rawptr, pipeline: Gfx_Pipeline, name: string, mat: matrix[4,4]f32) -> common.Engine_Error,
	set_uniform_vec2: proc(encoder_or_device_handle: rawptr, pipeline: Gfx_Pipeline, name: string, vec: [2]f32) -> common.Engine_Error,
	set_uniform_vec3: proc(encoder_or_device_handle: rawptr, pipeline: Gfx_Pipeline, name: string, vec: [3]f32) -> common.Engine_Error,
	set_uniform_vec4: proc(encoder_or_device_handle: rawptr, pipeline: Gfx_Pipeline, name: string, vec: [4]f32) -> common.Engine_Error,
	set_uniform_int: proc(encoder_or_device_handle: rawptr, pipeline: Gfx_Pipeline, name: string, val: i32) -> common.Engine_Error,
	set_uniform_float: proc(encoder_or_device_handle: rawptr, pipeline: Gfx_Pipeline, name: string, val: f32) -> common.Engine_Error,
	bind_texture_to_unit: proc(encoder_or_device_handle: rawptr, texture: Gfx_Texture, unit: u32, stage: Shader_Stage) -> common.Engine_Error, // Added Shader_Stage

	// Framebuffer Management (Offscreen rendering)
	create_framebuffer: proc(device: Gfx_Device, width, height: int, color_format: Texture_Format, depth_format: Texture_Format) -> (Gfx_Framebuffer, common.Engine_Error),
	destroy_framebuffer: proc(framebuffer: Gfx_Framebuffer),

	// Render Pass Management (For Vulkan-style render pass objects, less direct for Metal/GL main pass)
	create_render_pass: proc(device: Gfx_Device, framebuffer: Gfx_Framebuffer, clear_color, clear_depth: bool) -> (Gfx_Render_Pass, common.Engine_Error),
	// begin_render_pass and end_render_pass are now more general for the main swapchain pass.
	// The Gfx_Render_Pass object might be used for offscreen passes.

	// State Management (These might be part of Pipeline creation or dynamic on encoder/device)
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
