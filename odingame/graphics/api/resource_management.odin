package graphics.api

import "../../common" // For Engine_Error
import "../types"    // For graphics specific types
import graphics "../" // To get Gfx_Shader etc.

Resource_Management_Interface :: struct {
	destroy_shader: proc(shader: graphics.Gfx_Shader),
	destroy_pipeline: proc(pipeline: graphics.Gfx_Pipeline),
	update_buffer: proc(buffer: graphics.Gfx_Buffer, offset: int, data: rawptr, size: int) -> common.Engine_Error,
	destroy_buffer: proc(buffer: graphics.Gfx_Buffer),
    map_buffer: proc(buffer: graphics.Gfx_Buffer, offset, size: int) -> rawptr,
    unmap_buffer: proc(buffer: graphics.Gfx_Buffer),
	update_texture: proc(
        device: graphics.Gfx_Device,
        texture: graphics.Gfx_Texture, 
        level: int,
        x: int, y: int, z: int,
        width: int, height: int, depth_dim: int,
        data: rawptr, 
        data_pitch: int, 
        data_slice_pitch: int,
    ) -> common.Engine_Error,
	destroy_texture: proc(texture: graphics.Gfx_Texture) -> common.Engine_Error,
	destroy_framebuffer: proc(framebuffer: graphics.Gfx_Framebuffer),
	destroy_vertex_array: proc(vao: graphics.Gfx_Vertex_Array),
}
