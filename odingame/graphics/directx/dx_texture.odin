package directx

import "../gfx_interface"
import "core:log"

// --- Gfx_Device_Interface Texture Management Stubs ---

dx_create_texture_wrapper :: proc(device: gfx_interface.Gfx_Device, width, height: int, format: gfx_interface.Texture_Format, usage: gfx_interface.Texture_Usage, data: rawptr = nil) -> (gfx_interface.Gfx_Texture, gfx_interface.Gfx_Error) {
	log.warn("DirectX: create_texture_wrapper not implemented.")
	// Real D3D11: ID3D11Device.CreateTexture2D, then ID3D11Device.CreateShaderResourceView.
	// Potentially CreateRenderTargetView or CreateDepthStencilView depending on usage.
	return gfx_interface.Gfx_Texture{}, .Not_Implemented
}

dx_update_texture_wrapper :: proc(texture: gfx_interface.Gfx_Texture, x, y, width, height: int, data: rawptr) -> gfx_interface.Gfx_Error {
	log.warn("DirectX: update_texture_wrapper not implemented.")
	// Real D3D11: ID3D11DeviceContext.UpdateSubresource or Map/Memcpy/Unmap for dynamic textures.
	return .Not_Implemented
}

dx_destroy_texture_wrapper :: proc(texture: gfx_interface.Gfx_Texture) {
	log.warn("DirectX: destroy_texture_wrapper not implemented.")
	// Real D3D11: Release ID3D11Texture2D, ID3D11ShaderResourceView, etc.
	if tex_internal, ok := texture.variant.(Dx_Texture_Variant); ok && tex_internal != nil {
		// Placeholder for freeing variant data
		// free(tex_internal, tex_internal.allocator);
	}
}

dx_bind_texture_to_unit_wrapper :: proc(device: gfx_interface.Gfx_Device, texture: gfx_interface.Gfx_Texture, unit: u32) -> gfx_interface.Gfx_Error {
    log.warn("DirectX: bind_texture_to_unit_wrapper not implemented.")
	// Real D3D11: ID3D11DeviceContext.PSSetShaderResources (or VSSetShaderResources, etc.)
	// `unit` maps to the slot parameter.
    return .Not_Implemented
}

dx_get_texture_width_wrapper :: proc(texture: gfx_interface.Gfx_Texture) -> int {
    log.warn("DirectX: get_texture_width_wrapper not implemented.")
	if tex_internal, ok := texture.variant.(Dx_Texture_Variant); ok && tex_internal != nil {
		// return tex_internal.width;
	}
    return 0
}

dx_get_texture_height_wrapper :: proc(texture: gfx_interface.Gfx_Texture) -> int {
    log.warn("DirectX: get_texture_height_wrapper not implemented.")
	if tex_internal, ok := texture.variant.(Dx_Texture_Variant); ok && tex_internal != nil {
		// return tex_internal.height;
	}
    return 0
}
