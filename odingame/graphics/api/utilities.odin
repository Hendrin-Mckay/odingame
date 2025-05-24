package graphics.api

import "../../common" // For Engine_Error
// No direct dependency on ../types or graphics.types for these utility function signatures themselves,
// but the Gfx_Texture handle comes from the parent graphics package.
import graphics "../" 

Utilities_Interface :: struct {
	get_texture_width: proc(texture: graphics.Gfx_Texture) -> int,
	get_texture_height: proc(texture: graphics.Gfx_Texture) -> int,
	get_error_string: proc(error: common.Engine_Error) -> string,
}
