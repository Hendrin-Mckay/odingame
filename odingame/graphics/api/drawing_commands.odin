package graphics.api

import "../../common" // For Engine_Error
import "../types"    // For graphics specific types
import graphics "../" // To get Gfx_Device etc.

Drawing_Commands_Interface :: struct {
	begin_frame: proc(device: graphics.Gfx_Device, window: graphics.Gfx_Window) -> (common.Engine_Error, ^types.Gfx_Frame_Context_Info), 
	clear_screen: proc(device: graphics.Gfx_Device, frame_ctx: ^types.Gfx_Frame_Context_Info, options: types.Clear_Options),
	begin_render_pass: proc(device: graphics.Gfx_Device, frame_ctx: ^types.Gfx_Frame_Context_Info) -> rawptr, 
	end_render_pass: proc(encoder_handle: rawptr),
	draw: proc(encoder_handle: rawptr, device: graphics.Gfx_Device, vertex_count, instance_count, first_vertex, first_instance: u32),
	draw_indexed: proc(encoder_handle: rawptr, device: graphics.Gfx_Device, index_count, instance_count, first_index, base_vertex, first_instance: u32),
	end_frame: proc(device: graphics.Gfx_Device, window: graphics.Gfx_Window, frame_ctx: ^types.Gfx_Frame_Context_Info),   
}
