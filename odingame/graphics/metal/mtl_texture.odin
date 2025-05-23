package metal

import "../gfx_interface"
import "../../common" // For common.Engine_Error
import "core:log"

// --- Gfx_Device_Interface Texture Management Stubs ---

mtl_create_texture_wrapper :: proc(device: gfx_interface.Gfx_Device, width, height: int, format: gfx_interface.Texture_Format, usage: gfx_interface.Texture_Usage, data: rawptr = nil) -> (gfx_interface.Gfx_Texture, common.Engine_Error) {
	log.warn("Metal: create_texture_wrapper not implemented.")
	// Real Metal:
	// 1. Create MTLTextureDescriptor with width, height, pixelFormat (map from Gfx_Texture_Format), usage flags.
	// 2. id<MTLDevice>.newTexture(descriptor: desc).
	// 3. If data is provided, id<MTLTexture>.replaceRegion to upload data.
	return gfx_interface.Gfx_Texture{}, common.Engine_Error.Not_Implemented
}

mtl_update_texture_wrapper :: proc(texture: gfx_interface.Gfx_Texture, x, y, width, height: int, data: rawptr) -> common.Engine_Error {
	log.warn("Metal: update_texture_wrapper not implemented.")
	// Real Metal: id<MTLTexture>.replaceRegion(region, mipmapLevel: 0, withBytes: data, bytesPerRow: ...)
	return common.Engine_Error.Not_Implemented
}

mtl_destroy_texture_wrapper :: proc(texture: gfx_interface.Gfx_Texture) {
	log.warn("Metal: destroy_texture_wrapper not implemented.")
	// Real Metal: Release id<MTLTexture> (ARC). Free Mtl_Texture_Internal.
	if tex_internal, ok := texture.variant.(Mtl_Texture_Variant); ok && tex_internal != nil {
		// Placeholder for freeing variant data
		// free(tex_internal, tex_internal.allocator);
	}
}

mtl_bind_texture_to_unit_wrapper :: proc(device: gfx_interface.Gfx_Device, texture: gfx_interface.Gfx_Texture, unit: u32) -> common.Engine_Error {
    log.warn("Metal: bind_texture_to_unit_wrapper not implemented.")
	// Real Metal: MTLRenderCommandEncoder.setFragmentTexture(texture, index: unit) or .setVertexTexture(...)
    return common.Engine_Error.Not_Implemented
}

mtl_get_texture_width_wrapper :: proc(texture: gfx_interface.Gfx_Texture) -> int {
    log.warn("Metal: get_texture_width_wrapper not implemented.")
	if tex_internal, ok := texture.variant.(Mtl_Texture_Variant); ok && tex_internal != nil {
		// return tex_internal.width;
	}
    return 0
}

mtl_get_texture_height_wrapper :: proc(texture: gfx_interface.Gfx_Texture) -> int {
    log.warn("Metal: get_texture_height_wrapper not implemented.")
	if tex_internal, ok := texture.variant.(Mtl_Texture_Variant); ok && tex_internal != nil {
		// return tex_internal.height;
	}
    return 0
}
