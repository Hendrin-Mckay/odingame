package graphics.api

import "../../common" // For Engine_Error
import "../../core/math" // For matrix
import "../types"    // For graphics specific types
import graphics "../" // To get Gfx_Device etc.

State_Setting_Interface :: struct {
	set_viewport: proc(encoder_or_device_handle: rawptr, viewport: types.Viewport),
    set_scissor: proc(encoder_or_device_handle: rawptr, scissor: types.Scissor),
    disable_scissor: proc(encoder_or_device_handle: rawptr),
	set_pipeline: proc(encoder_or_device_handle: rawptr, pipeline: graphics.Gfx_Pipeline),
	set_vertex_buffer: proc(encoder_or_device_handle: rawptr, buffer: graphics.Gfx_Buffer, binding_index: u32 = 0, offset: u32 = 0),
	set_index_buffer: proc(encoder_or_device_handle: rawptr, buffer: graphics.Gfx_Buffer, offset: u32 = 0), 
	set_uniform_mat4: proc(encoder_or_device_handle: rawptr, pipeline: graphics.Gfx_Pipeline, name: string, mat: math.matrix[4,4]f32) -> common.Engine_Error,
	set_uniform_vec2: proc(encoder_or_device_handle: rawptr, pipeline: graphics.Gfx_Pipeline, name: string, vec: [2]f32) -> common.Engine_Error,
	set_uniform_vec3: proc(encoder_or_device_handle: rawptr, pipeline: graphics.Gfx_Pipeline, name: string, vec: [3]f32) -> common.Engine_Error,
	set_uniform_vec4: proc(encoder_or_device_handle: rawptr, pipeline: graphics.Gfx_Pipeline, name: string, vec: [4]f32) -> common.Engine_Error,
	set_uniform_int: proc(encoder_or_device_handle: rawptr, pipeline: graphics.Gfx_Pipeline, name: string, val: i32) -> common.Engine_Error,
	set_uniform_float: proc(encoder_or_device_handle: rawptr, pipeline: graphics.Gfx_Pipeline, name: string, val: f32) -> common.Engine_Error,
	bind_texture_to_unit: proc(encoder_or_device_handle: rawptr, texture: graphics.Gfx_Texture, unit: u32, stage: types.Shader_Stage) -> common.Engine_Error,
	set_blend_mode: proc(device: graphics.Gfx_Device, blend_mode: types.Blend_Mode),
	set_depth_test: proc(device: graphics.Gfx_Device, enabled: bool, write: bool, func: types.Depth_Func),
	set_cull_mode: proc(device: graphics.Gfx_Device, cull_mode: types.Cull_Mode),
	bind_vertex_array: proc(device: graphics.Gfx_Device, vao: graphics.Gfx_Vertex_Array),
}
