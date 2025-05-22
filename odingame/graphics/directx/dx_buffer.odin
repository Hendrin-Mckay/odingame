package directx

import "../gfx_interface"
import "core:log"

// --- Gfx_Device_Interface Buffer Management Stubs ---

dx_create_buffer_wrapper :: proc(device: gfx_interface.Gfx_Device, type: gfx_interface.Buffer_Type, size: int, data: rawptr = nil, dynamic: bool = false) -> (gfx_interface.Gfx_Buffer, gfx_interface.Gfx_Error) {
	log.warn("DirectX: create_buffer_wrapper not implemented.")
	// Real D3D11: ID3D11Device.CreateBuffer.
	// Usage flag (D3D11_USAGE_DYNAMIC or D3D11_USAGE_DEFAULT), BindFlags (VERTEX_BUFFER, INDEX_BUFFER, CONSTANT_BUFFER), CPUAccessFlags.
	return gfx_interface.Gfx_Buffer{}, .Not_Implemented
}

dx_update_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer, offset: int, data: rawptr, size: int) -> gfx_interface.Gfx_Error {
	log.warn("DirectX: update_buffer_wrapper not implemented.")
	// Real D3D11: ID3D11DeviceContext.Map (with D3D11_MAP_WRITE_DISCARD for dynamic buffers) then Memcpy, then Unmap.
	// Or UpdateSubresource for less frequent updates or default usage buffers.
	return .Not_Implemented
}

dx_destroy_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer) {
	log.warn("DirectX: destroy_buffer_wrapper not implemented.")
	// Real D3D11: ID3D11Buffer.Release().
	if buffer_internal, ok := buffer.variant.(Dx_Buffer_Variant); ok && buffer_internal != nil {
		// Placeholder for freeing variant data
		// free(buffer_internal, buffer_internal.allocator);
	}
}

dx_map_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer, offset, size: int) -> rawptr {
    log.warn("DirectX: map_buffer_wrapper not implemented.")
	// Real D3D11: ID3D11DeviceContext.Map. Offset/size might require careful handling depending on map type.
    return nil
}

dx_unmap_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer) {
    log.warn("DirectX: unmap_buffer_wrapper not implemented.")
	// Real D3D11: ID3D11DeviceContext.Unmap.
}

dx_set_vertex_buffer_wrapper :: proc(device: gfx_interface.Gfx_Device, buffer: gfx_interface.Gfx_Buffer, binding_index: u32 = 0, offset: u32 = 0) {
	log.warn("DirectX: set_vertex_buffer_wrapper not implemented.")
	// Real D3D11: ID3D11DeviceContext.IASetVertexBuffers.
	// `binding_index` is the input slot.
	// `offset` is `offset_in_bytes`. Stride is also needed, usually taken from InputLayout or set here.
}

dx_set_index_buffer_wrapper :: proc(device: gfx_interface.Gfx_Device, buffer: gfx_interface.Gfx_Buffer, offset: u32 = 0) {
	log.warn("DirectX: set_index_buffer_wrapper not implemented.")
	// Real D3D11: ID3D11DeviceContext.IASetIndexBuffer.
	// Format (16-bit or 32-bit) and offset are needed.
}
