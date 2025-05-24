package graphics.types

import "../types" // For types.Recti

// Gfx_Handle and INVALID_HANDLE
Gfx_Handle :: u32
INVALID_HANDLE: Gfx_Handle : 0

// Buffer_Type
Buffer_Type :: enum {
	Vertex,
	Index,
	Uniform,
}

// Texture_Format, Texture_Type, Texture_Usage (Texture_Usage_Flags)
Texture_Format :: enum {
	R8,
	RG8,
	RGB8,
	RGBA8,

	R16,
	RG16,
	RGB16,
	RGBA16,

	R32F,
	RG32F,
	RGB32F,
	RGBA32F,

	Depth,
	Depth_Stencil,
}

Texture_Type :: enum {
	Tex_2D,
	Tex_3D,
	Tex_Cube,
	Tex_Array,
}

Texture_Usage_Flags :: distinct bit_set[Texture_Usage; u8]
Texture_Usage :: enum {
	Sample,
	Render_Target,
	Depth_Stencil_Attachment,
}

// Shader_Stage
Shader_Stage :: enum {
	Vertex,
	Fragment,
	Compute,
}

// Blend_Mode
Blend_Mode :: enum {
	None,
	Alpha,
	Additive,
	Multiply,
	Premultiplied_Alpha,
}

// Depth_Func
Depth_Func :: enum {
	Always,
	Never,
	Less,
	Equal,
	Less_Equal,
	Greater,
	Greater_Equal,
	Not_Equal,
}

// Cull_Mode
Cull_Mode :: enum {
	None,
	Front,
	Back,
}

// Primitive_Topology
Primitive_Topology :: enum {
	Points,
	Lines,
	Line_Strip,
	Triangles,
	Triangle_Strip,
}

// Clear_Options
Clear_Options :: struct {
	color:          [4]f32,
	depth_value:    f32,
	stencil_value:  u8,
	clear_color:    bool,
	clear_depth:    bool,
	clear_stencil:  bool,
}

// Viewport
Viewport :: struct {
	x:      i32,
	y:      i32,
	width:  i32,
	height: i32,
}

// Scissor
Scissor :: types.Recti

// Gfx_Frame_Context_Info
Gfx_Frame_Context_Info :: struct {
	width:           i32,
	height:          i32,
	drawable_width:  i32,
	drawable_height: i32,
	dpi_scale:       f32,
}

// Vertex_Attribute, Vertex_Step_Rate, Vertex_Buffer_Layout, Vertex_Format
Vertex_Format :: enum {
	Float,
	Float2,
	Float3,
	Float4,
	Byte4,
	Byte4N,
	UByte4,
	UByte4N,
	Short2,
	Short2N,
	Short4,
	Short4N,
	UInt,
	UInt2,
	UInt3,
	UInt4,
	Int,
	Int2,
	Int3,
	Int4,
}

Vertex_Step_Rate :: enum {
	Per_Vertex,
	Per_Instance,
}

Vertex_Attribute :: struct {
	name:     string, // For reflection/debugging
	format:   Vertex_Format,
	location: u32, // Corresponds to shader location
	offset:   u32, // Offset in bytes within the buffer
}

Vertex_Buffer_Layout :: struct {
	attributes:  [dynamic]Vertex_Attribute,
	stride:      u32, // Stride in bytes between elements
	step_rate:   Vertex_Step_Rate,
	step_func:   string, // (Optional) For GL, e.g., "glVertexAttribDivisor"
}


// Gfx_Pipeline_Blend_State_Desc, Gfx_Stencil_Op_Desc, Gfx_Pipeline_Depth_Stencil_State_Desc, Gfx_Pipeline_Rasterizer_State_Desc, Gfx_Pipeline_Desc
Blend_Factor :: enum {
	Zero,
	One,
	Src_Color,
	One_Minus_Src_Color,
	Dst_Color,
	One_Minus_Dst_Color,
	Src_Alpha,
	One_Minus_Src_Alpha,
	Dst_Alpha,
	One_Minus_Dst_Alpha,
	Constant_Color,
	One_Minus_Constant_Color,
	Constant_Alpha,
	One_Minus_Constant_Alpha,
	Src_Alpha_Saturate,
}

Blend_Op :: enum {
	Add,
	Subtract,
	Reverse_Subtract,
	Min,
	Max,
}

Color_Write_Mask_Flags :: distinct bit_set[Color_Write_Mask; u8]
Color_Write_Mask :: enum {
	Red,
	Green,
	Blue,
	Alpha,
	All, // Utility for R | G | B | A
}

Gfx_Pipeline_Blend_State_Desc :: struct {
	enabled:            bool,
	src_factor_rgb:     Blend_Factor,
	dst_factor_rgb:     Blend_Factor,
	op_rgb:             Blend_Op,
	src_factor_alpha:   Blend_Factor,
	dst_factor_alpha:   Blend_Factor,
	op_alpha:           Blend_Op,
	write_mask:         Color_Write_Mask_Flags,
	blend_color:        [4]f32,
}

Comparison_Func :: enum {
	Never,
	Less,
	Equal,
	Less_Equal,
	Greater,
	Not_Equal,
	Greater_Equal,
	Always,
}

Stencil_Op :: enum {
	Keep,
	Zero,
	Replace,
	Increment_Clamp,
	Decrement_Clamp,
	Invert,
	Increment_Wrap,
	Decrement_Wrap,
}

Gfx_Stencil_Op_Desc :: struct {
	fail_op:      Stencil_Op,
	depth_fail_op: Stencil_Op,
	pass_op:      Stencil_Op,
	compare_func: Comparison_Func,
}

Gfx_Pipeline_Depth_Stencil_State_Desc :: struct {
	depth_test_enabled:  bool,
	depth_write_enabled: bool,
	depth_compare_func:  Comparison_Func, // Renamed from depth_func for consistency
	stencil_test_enabled: bool,
	stencil_read_mask:   u8,
	stencil_write_mask:  u8,
	front_face:          Gfx_Stencil_Op_Desc,
	back_face:           Gfx_Stencil_Op_Desc,
}

Fill_Mode :: enum {
	Fill,
	Line,
}

Winding_Order :: enum {
	Clockwise,
	Counter_Clockwise,
}

Gfx_Pipeline_Rasterizer_State_Desc :: struct {
	cull_mode:         Cull_Mode,
	winding_order:     Winding_Order, // Added
	fill_mode:         Fill_Mode,     // Added
	depth_bias:        i32,
	depth_bias_slope_scale: f32,
	depth_bias_clamp:  f32,
	scissor_test_enabled: bool,
	// Removed wireframe as Fill_Mode covers it
}

Gfx_Vertex_Layout_Desc :: struct { // New struct to group vertex layout info
	attributes: [dynamic]Vertex_Attribute,
	stride:     u32,
	step_rate:  Vertex_Step_Rate,
}

Vertex_Buffer_Layout_Desc :: struct { // New, more descriptive name for pipeline
    buffer_index: u32, // Index of the vertex buffer binding point
    layout: Gfx_Vertex_Layout_Desc,
}

Gfx_Pipeline_Desc :: struct {
	shader_handle:         Gfx_Handle,
	// Use an array of buffer layouts for potentially multiple vertex buffers
	vertex_buffer_layouts: [dynamic]Vertex_Buffer_Layout_Desc, 
	primitive_topology:    Primitive_Topology,
	blend_state:           Gfx_Pipeline_Blend_State_Desc,
	depth_stencil_state:   Gfx_Pipeline_Depth_Stencil_State_Desc,
	rasterizer_state:      Gfx_Pipeline_Rasterizer_State_Desc,
	// uniform_layout:     Gfx_Uniform_Layout_Desc, // Future: for explicit uniform bindings
	debug_name:            string, // Optional: for debugging/profiling
}
