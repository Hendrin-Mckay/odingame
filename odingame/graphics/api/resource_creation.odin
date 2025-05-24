package graphics.api

import "../../common" // For Engine_Error
import "../types"    // For graphics specific types
import graphics "../" // To get Gfx_Shader etc.

Resource_Creation_Interface :: struct {
	create_shader_from_source: proc(device: graphics.Gfx_Device, source: string, stage: types.Shader_Stage) -> (graphics.Gfx_Shader, common.Engine_Error),
	create_shader_from_bytecode: proc(device: graphics.Gfx_Device, bytecode: []u8, stage: types.Shader_Stage) -> (graphics.Gfx_Shader, common.Engine_Error),
	create_pipeline: proc(device: graphics.Gfx_Device, desc: types.Gfx_Pipeline_Desc) -> (graphics.Gfx_Pipeline, common.Engine_Error),
	create_buffer: proc(device: graphics.Gfx_Device, type: types.Buffer_Type, size: int, data: rawptr = nil, is_dynamic: bool = false) -> (graphics.Gfx_Buffer, common.Engine_Error),
	create_texture: proc(
        device: graphics.Gfx_Device, 
        width: int, height: int, depth: int,
        format: types.Texture_Format, 
        type: types.Texture_Type,
        usage: types.Texture_Usage_Flags, 
        mip_levels: int,
        array_length: int,
        data: rawptr = nil, 
        data_pitch: int = 0,
        data_slice_pitch: int = 0,
        label: string = "",
    ) -> (graphics.Gfx_Texture, common.Engine_Error),
	create_framebuffer: proc(device: graphics.Gfx_Device, width, height: int, color_format: types.Texture_Format, depth_format: types.Texture_Format) -> (graphics.Gfx_Framebuffer, common.Engine_Error),
	create_render_pass: proc(device: graphics.Gfx_Device, framebuffer: graphics.Gfx_Framebuffer, clear_color, clear_depth: bool) -> (graphics.Gfx_Render_Pass, common.Engine_Error),
	create_vertex_array: proc(
		device: graphics.Gfx_Device, 
		vertex_buffer_layouts: []types.Vertex_Buffer_Layout, 
		vertex_buffers: []graphics.Gfx_Buffer,
		index_buffer: graphics.Gfx_Buffer,
	) -> (graphics.Gfx_Vertex_Array, common.Engine_Error),
}
