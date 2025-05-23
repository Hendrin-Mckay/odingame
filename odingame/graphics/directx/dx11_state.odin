package directx11

import "../gfx_interface"
import "core:log"

// --- State Management ---

set_blend_mode_impl :: proc(
    device: gfx_interface.Gfx_Device,
    enabled: bool,
    src_factor: gfx_interface.Blend_Factor = .Src_Alpha,
    dst_factor: gfx_interface.Blend_Factor = .One_Minus_Src_Alpha,
    blend_op: gfx_interface.Blend_Op = .Add,
) -> gfx_interface.Gfx_Error {
    log.warn("DirectX 11: set_blend_mode_impl not implemented")
    // Real implementation would:
    // 1. Create or get a cached blend state with the specified parameters
    // 2. Call OMSetBlendState on the device context
    return .Not_Implemented
}

set_depth_test_impl :: proc(
    device: gfx_interface.Gfx_Device,
    enabled: bool,
    write_enabled: bool = true,
    compare_op: gfx_interface.Compare_Op = .Less_Equal,
) -> gfx_interface.Gfx_Error {
    log.warn("DirectX 11: set_depth_test_impl not implemented")
    // Real implementation would:
    // 1. Create or get a cached depth stencil state with the specified parameters
    // 2. Call OMSetDepthStencilState on the device context
    return .Not_Implemented
}

set_cull_mode_impl :: proc(
    device: gfx_interface.Gfx_Device,
    mode: gfx_interface.Cull_Mode,
    front_face: gfx_interface.Front_Face = .Counter_Clockwise,
) -> gfx_interface.Gfx_Error {
    log.warn("DirectX 11: set_cull_mode_impl not implemented")
    // Real implementation would:
    // 1. Create or get a cached rasterizer state with the specified parameters
    // 2. Call RSSetState on the device context
    return .Not_Implemented
}
