package directx11

import "../gfx_interface"
import "core:log"
import "core:mem"

// --- Texture Management ---

create_texture_impl :: proc(
    device: gfx_interface.Gfx_Device,
    width, height: int,
    format: gfx_interface.Texture_Format,
    usage: gfx_interface.Texture_Usage,
    data: rawptr = nil,
) -> (gfx_interface.Gfx_Texture, gfx_interface.Gfx_Error) {
    log.warn("DirectX 11: create_texture_impl not implemented")
    // Real implementation would:
    // 1. Create a D3D11_TEXTURE2D_DESC with the specified parameters
    // 2. Create a D3D11_SUBRESOURCE_DATA if initial data is provided
    // 3. Call CreateTexture2D on the device
    // 4. Create a shader resource view for the texture
    // 5. Store the texture and SRV in D3D11_Texture_Internal
    return gfx_interface.Gfx_Texture{}, .Not_Implemented
}

update_texture_impl :: proc(
    texture: gfx_interface.Gfx_Texture,
    x, y, width, height: int,
    data: rawptr,
) -> gfx_interface.Gfx_Error {
    log.warn("DirectX 11: update_texture_impl not implemented")
    // Real implementation would:
    // 1. Get the device context
    // 2. Call UpdateSubresource or Map/Unmap to update the texture
    return .Not_Implemented
}

destroy_texture_impl :: proc(texture: gfx_interface.Gfx_Texture) {
    log.warn("DirectX 11: destroy_texture_impl not implemented")
    // Real implementation would:
    // 1. Release the shader resource view
    // 2. Release the texture
    if tex_internal, ok := texture.variant.(D3D11_Texture_Variant); ok && tex_internal != nil {
        // free(tex_internal, tex_internal.allocator)
    }
}

bind_texture_to_unit_impl :: proc(
    device: gfx_interface.Gfx_Device,
    texture: gfx_interface.Gfx_Texture,
    unit: u32,
) -> gfx_interface.Gfx_Error {
    log.warn("DirectX 11: bind_texture_to_unit_impl not implemented")
    // Real implementation would:
    // 1. Get the device context
    // 2. Call PSSetShaderResources or VSSetShaderResources with the SRV
    return .Not_Implemented
}

get_texture_width_impl :: proc(texture: gfx_interface.Gfx_Texture) -> int {
    log.warn("DirectX 11: get_texture_width_impl not implemented")
    if tex_internal, ok := texture.variant.(D3D11_Texture_Variant); ok && tex_internal != nil {
        // return tex_internal.width
    }
    return 0
}

get_texture_height_impl :: proc(texture: gfx_interface.Gfx_Texture) -> int {
    log.warn("DirectX 11: get_texture_height_impl not implemented")
    if tex_internal, ok := texture.variant.(D3D11_Texture_Variant); ok && tex_internal != nil {
        // return tex_internal.height
    }
    return 0
}
