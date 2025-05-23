package directx11

import "../gfx_interface"
import "core:log"
import "core:mem"

// --- Buffer Management ---

create_buffer_impl :: proc(
    device: gfx_interface.Gfx_Device,
    type: gfx_interface.Buffer_Type,
    size: int,
    data: rawptr = nil,
    dynamic: bool = false,
) -> (gfx_interface.Gfx_Buffer, gfx_interface.Gfx_Error) {
    log.warn("DirectX 11: create_buffer_impl not implemented")
    // Real implementation would:
    // 1. Create a D3D11_BUFFER_DESC with the appropriate usage and bind flags
    // 2. Create a D3D11_SUBRESOURCE_DATA if initial data is provided
    // 3. Call CreateBuffer on the device
    // 4. Store the buffer and description in D3D11_Buffer_Internal
    return gfx_interface.Gfx_Buffer{}, .Not_Implemented
}

update_buffer_impl :: proc(buffer: gfx_interface.Gfx_Buffer, offset: int, data: rawptr, size: int) -> gfx_interface.Gfx_Error {
    log.warn("DirectX 11: update_buffer_impl not implemented")
    // Real implementation would:
    // 1. Get the device context
    // 2. Call Map/Unmap or UpdateSubresource to update the buffer
    return .Not_Implemented
}

destroy_buffer_impl :: proc(buffer: gfx_interface.Gfx_Buffer) {
    log.warn("DirectX 11: destroy_buffer_impl not implemented")
    // Real implementation would:
    // 1. Release the buffer
    if buffer_internal, ok := buffer.variant.(D3D11_Buffer_Variant); ok && buffer_internal != nil {
        // free(buffer_internal, buffer_internal.allocator)
    }
}

map_buffer_impl :: proc(buffer: gfx_interface.Gfx_Buffer, offset: int, size: int, read: bool, write: bool) -> (rawptr, gfx_interface.Gfx_Error) {
    log.warn("DirectX 11: map_buffer_impl not implemented")
    // Real implementation would:
    // 1. Call Map on the device context with the appropriate flags
    // 2. Return the mapped pointer
    return nil, .Not_Implemented
}

unmap_buffer_impl :: proc(buffer: gfx_interface.Gfx_Buffer) -> gfx_interface.Gfx_Error {
    log.warn("DirectX 11: unmap_buffer_impl not implemented")
    // Real implementation would:
    // 1. Call Unmap on the device context
    return .Not_Implemented
}

// --- Vertex/Index Buffer Binding ---

set_vertex_buffer_impl :: proc(
    device: gfx_interface.Gfx_Device,
    buffer: gfx_interface.Gfx_Buffer,
    binding_index: u32 = 0,
    offset: u32 = 0,
    stride: u32 = 0,
) -> gfx_interface.Gfx_Error {
    log.warn("DirectX 11: set_vertex_buffer_impl not implemented")
    // Real implementation would:
    // 1. Get the device context
    // 2. Call IASetVertexBuffers with the buffer and stride
    return .Not_Implemented
}

set_index_buffer_impl :: proc(
    device: gfx_interface.Gfx_Device,
    buffer: gfx_interface.Gfx_Buffer,
    offset: u32 = 0,
    index_type: gfx_interface.Index_Type = .U16,
) -> gfx_interface.Gfx_Error {
    log.warn("DirectX 11: set_index_buffer_impl not implemented")
    // Real implementation would:
    // 1. Get the device context
    // 2. Call IASetIndexBuffer with the buffer and format
    return .Not_Implemented
}
