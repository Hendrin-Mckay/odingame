package metal

import "../gfx_interface"
import "../../common" // For common.Engine_Error
import "core:log"

// --- Gfx_Device_Interface Buffer Management Stubs ---

mtl_create_buffer_wrapper :: proc(device: gfx_interface.Gfx_Device, type: gfx_interface.Buffer_Type, size: int, data: rawptr = nil, dynamic: bool = false) -> (gfx_interface.Gfx_Buffer, common.Engine_Error) {
	log.warn("Metal: create_buffer_wrapper not implemented.")
	// Real Metal: id<MTLDevice>.newBuffer(length: size, options: options) or newBuffer(bytes: data, length: size, options: options).
	// Options would include MTLResourceOptions (e.g. storageModeShared, storageModePrivate, cpuCacheModeWriteCombined).
	// `dynamic` would influence storageMode (e.g. shared or managed for CPU access).
	return gfx_interface.Gfx_Buffer{}, common.Engine_Error.Not_Implemented
}

mtl_update_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer, offset: int, data: rawptr, size: int) -> common.Engine_Error {
	log.warn("Metal: update_buffer_wrapper not implemented.")
	// Real Metal: For buffers with CPU access (e.g. shared or managed with CPU cache write combined),
	// get contents: id<MTLBuffer>.contents(). Then unsafe.copy to the memory region.
	// offset and size apply to the destination pointer from contents().
	return common.Engine_Error.Not_Implemented
}

mtl_destroy_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer) {
	log.warn("Metal: destroy_buffer_wrapper not implemented.")
	// Real Metal: Release id<MTLBuffer> (ARC). Free Mtl_Buffer_Internal.
	if buffer_internal, ok := buffer.variant.(Mtl_Buffer_Variant); ok && buffer_internal != nil {
		// Placeholder for freeing variant data
		// free(buffer_internal, buffer_internal.allocator);
	}
}

mtl_map_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer, offset, size: int) -> rawptr {
    log.warn("Metal: map_buffer_wrapper not implemented.")
	// Real Metal: id<MTLBuffer>.contents() gives direct CPU access if buffer created with appropriate storage mode.
	// Metal doesn't have explicit map/unmap like GL/Vulkan for shared/managed buffers.
	// If it's a private buffer, data transfer via command encoder (blit) would be needed.
	// This API implies CPU-accessible pointer, so .contents() is the closest.
	// Offset would be applied to the pointer returned by .contents().
    return nil
}

mtl_unmap_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer) {
    log.warn("Metal: unmap_buffer_wrapper not implemented.")
	// Real Metal: No explicit unmap if using .contents().
	// If using MTLStorageModeManaged, then didModifyRange might be needed.
}

mtl_set_vertex_buffer_wrapper :: proc(device: gfx_interface.Gfx_Device, buffer: gfx_interface.Gfx_Buffer, binding_index: u32 = 0, offset: u32 = 0) {
	log.warn("Metal: set_vertex_buffer_wrapper not implemented.")
	// Real Metal: MTLRenderCommandEncoder.setVertexBuffer(buffer, offset: offset, index: binding_index).
}

mtl_set_index_buffer_wrapper :: proc(device: gfx_interface.Gfx_Device, buffer: gfx_interface.Gfx_Buffer, offset: u32 = 0) {
	log.warn("Metal: set_index_buffer_wrapper not implemented.")
	// Real Metal: MTLRenderCommandEncoder.drawIndexedPrimitives uses indexType and indexBufferOffset.
	// This function would likely just note the buffer to be used by draw_indexed.
	// No direct "set index buffer" state on encoder apart from its use in draw calls.
}
