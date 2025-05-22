package directx

import "../gfx_interface"
import "core:log"

// --- Gfx_Device_Interface Vertex Array (Input Layout) Stubs ---

dx_create_vertex_array_wrapper :: proc(
	device: gfx_interface.Gfx_Device, 
	vertex_buffer_layouts: []gfx_interface.Vertex_Buffer_Layout, 
	vertex_buffers: []gfx_interface.Gfx_Buffer,
	index_buffer: gfx_interface.Gfx_Buffer,
) -> (gfx_interface.Gfx_Vertex_Array, gfx_interface.Gfx_Error) {
	log.warn("DirectX: create_vertex_array_wrapper not implemented.")
	// Real D3D11: This would primarily involve creating an ID3D11InputLayout object.
	// This requires:
	// 1. A compiled Vertex Shader (or its bytecode/signature).
	// 2. An array of D3D11_INPUT_ELEMENT_DESC that maps to Vertex_Buffer_Layout and Vertex_Attribute.
	// The Gfx_Vertex_Array for D3D11 would store the ID3D11InputLayout.
	// Vertex buffer and index buffer bindings are typically set on the context just before drawing,
	// along with the input layout.
	return gfx_interface.Gfx_Vertex_Array{}, .Not_Implemented
}

dx_destroy_vertex_array_wrapper :: proc(vao: gfx_interface.Gfx_Vertex_Array) {
	log.warn("DirectX: destroy_vertex_array_wrapper not implemented.")
	// Real D3D11: Release the ID3D11InputLayout object.
	if vao_internal, ok := vao.variant.(Dx_Vertex_Array_Variant); ok && vao_internal != nil {
		// Placeholder for freeing variant data
		// free(vao_internal, vao_internal.allocator);
	}
}

dx_bind_vertex_array_wrapper :: proc(device: gfx_interface.Gfx_Device, vao: gfx_interface.Gfx_Vertex_Array) {
	log.warn("DirectX: bind_vertex_array_wrapper not implemented.")
	// Real D3D11: This maps to ID3D11DeviceContext.IASetInputLayout().
	// If the Gfx_Vertex_Array also implies binding specific VBs/IB, that would happen here too,
	// though that's less typical for just IASetInputLayout.
}
