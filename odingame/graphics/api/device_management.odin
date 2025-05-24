package graphics.api

import "../../common" // For Engine_Error
import "../types"    // For graphics specific types like Gfx_Handle
// Note: Gfx_Device is defined in gfx_interface.odin (or will be in a central spot)
// For now, assume it's accessible or define it temporarily if needed by interface defs.
// However, Gfx_Device itself is just a handle wrapper, its definition might move too.
// For now, let's assume Gfx_Device from the parent graphics package is okay.
import graphics "../" // To get Gfx_Device

Device_Management_Interface :: struct {
	create_device: proc(allocator: ^rawptr) -> (graphics.Gfx_Device, common.Engine_Error),
	destroy_device: proc(device: graphics.Gfx_Device),
}
