package graphics.api

import "../../common" // For Engine_Error
import "../types"    // For graphics specific types
import graphics "../" // To get Gfx_Window etc.

Window_Management_Interface :: struct {
	create_window: proc(device: graphics.Gfx_Device, title: string, width, height: int, vsync: bool, sdl_window_rawptr: rawptr) -> (graphics.Gfx_Window, common.Engine_Error),
	destroy_window: proc(window: graphics.Gfx_Window),
	present_window: proc(window: graphics.Gfx_Window) -> common.Engine_Error,
	resize_window: proc(window: graphics.Gfx_Window, width, height: int) -> common.Engine_Error,
	set_window_title: proc(window: graphics.Gfx_Window, title: string) -> common.Engine_Error,
	get_window_size: proc(window: graphics.Gfx_Window) -> (width, height: int),
	get_window_drawable_size: proc(window: graphics.Gfx_Window) -> (width, height: int),
}
