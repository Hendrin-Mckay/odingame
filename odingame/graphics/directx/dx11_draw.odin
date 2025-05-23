package directx11

import "../gfx_interface"
import "../../common" // For common.Engine_Error
import "core:log"

// --- Drawing ---

draw_impl :: proc(
    device: gfx_interface.Gfx_Device,
    vertex_count: i32,
    first_vertex: i32 = 0,
    instance_count: i32 = 1,
    first_instance: i32 = 0,
) -> common.Engine_Error {
    log.warn("DirectX 11: draw_impl not implemented")
    // Real implementation would:
    // 1. Get the device context
    // 2. Call Draw or DrawInstanced with the specified parameters
    return common.Engine_Error.Not_Implemented
}

draw_indexed_impl :: proc(
    device: gfx_interface.Gfx_Device,
    index_count: i32,
    first_index: i32 = 0,
    base_vertex: i32 = 0,
    instance_count: i32 = 1,
    first_instance: i32 = 0,
) -> common.Engine_Error {
    log.warn("DirectX 11: draw_indexed_impl not implemented")
    // Real implementation would:
    // 1. Get the device context
    // 2. Call DrawIndexed or DrawIndexedInstanced with the specified parameters
    return common.Engine_Error.Not_Implemented
}
