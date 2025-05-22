package metal

import "../gfx_interface"
import "core:log"

// --- Gfx_Device_Interface Vertex Array (Vertex Descriptor) Stubs ---

mtl_create_vertex_array_wrapper :: proc(
	device: gfx_interface.Gfx_Device, 
	vertex_buffer_layouts: []gfx_interface.Vertex_Buffer_Layout, 
	vertex_buffers: []gfx_interface.Gfx_Buffer,
	index_buffer: gfx_interface.Gfx_Buffer,
) -> (gfx_interface.Gfx_Vertex_Array, gfx_interface.Gfx_Error) {
	log.warn("Metal: create_vertex_array_wrapper not implemented.")
	// Real Metal: This would primarily involve creating and configuring an MTLVertexDescriptor object.
	// The descriptor would be populated based on Vertex_Buffer_Layout and Vertex_Attribute.
	// - For each layout in vertex_buffer_layouts:
	//   - MTLVertexDescriptor.layouts[binding_index].stride = layout.stride_in_bytes
	//   - For each attribute in layout.attributes:
	//     - MTLVertexDescriptor.attributes[location].format = map_vertex_format_to_mtl(attr.format)
	//     - MTLVertexDescriptor.attributes[location].offset = attr.offset_in_bytes
	//     - MTLVertexDescriptor.attributes[location].bufferIndex = attr.buffer_binding (maps to VBO slot)
	// The Gfx_Vertex_Array for Metal would store this configured MTLVertexDescriptor.
	// The actual MTLBuffer objects for vertices/indices are bound separately during render encoding.
	return gfx_interface.Gfx_Vertex_Array{}, .Not_Implemented
}

mtl_destroy_vertex_array_wrapper :: proc(vao: gfx_interface.Gfx_Vertex_Array) {
	log.warn("Metal: destroy_vertex_array_wrapper not implemented.")
	// Real Metal: Release MTLVertexDescriptor (ARC). Free Mtl_Vertex_Array_Internal.
	if vao_internal, ok := vao.variant.(Mtl_Vertex_Array_Variant); ok && vao_internal != nil {
		// Placeholder for freeing variant data
		// free(vao_internal, vao_internal.allocator);
	}
}

mtl_bind_vertex_array_wrapper :: proc(device: gfx_interface.Gfx_Device, vao: gfx_interface.Gfx_Vertex_Array) {
	log.warn("Metal: bind_vertex_array_wrapper not implemented.")
	// Real Metal: There isn't a direct "bind VAO" command like in OpenGL.
	// The MTLVertexDescriptor is typically used when creating a MTLRenderPipelineState.
	// At draw time:
	//   - Vertex buffers are bound using MTLRenderCommandEncoder.setVertexBuffer(offset:atIndex:).
	//   - The pipeline state (which was created with the vertex descriptor) is set.
	// This Gfx_Vertex_Array might be used to retrieve the preconfigured MTLVertexDescriptor
	// if needed during pipeline state creation, or to simplify setting multiple vertex buffers
	// if it also stored buffer references (though less common for just the descriptor part).
}
