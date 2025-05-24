package metal

import "core:log"
import "core:objc"
// import "core:sys/darwin" // Not strictly needed if types are from bindings

import "../gfx_interface"
// import "../../common" // Not strictly needed for draw calls if no errors returned
import "./mtl_types"    // For get_mtl_device_internal if needed
import "./mtl_bindings"   // For Metal handles and selectors

// --- Drawing Function Implementations for Metal ---

draw_impl :: proc(
    encoder_handle: rawptr, // MTLRenderCommandEncoder_Handle
    device_handle: gfx_interface.Gfx_Device, // Gfx_Device, mainly for consistency or potential allocator/debug access
    vertex_count: u32, 
    instance_count: u32, 
    first_vertex: u32, 
    first_instance: u32,
) {
    if encoder_handle == nil {
        log.error("Metal: draw_impl: Encoder handle is nil.")
        return
    }
    if vertex_count == 0 {
        // log.debug("Metal: draw_impl: vertex_count is 0, skipping draw call.")
        return
    }
    if instance_count == 0 { // Should default to 1 if not instanced
        instance_count = 1 
    }

    render_encoder := MTLRenderCommandEncoder_Handle(encoder_handle)
    
    // TODO: Get primitive_type from currently bound pipeline state.
    // For now, assume TriangleList which maps to MTLPrimitiveTypeTriangle.
    primitive_type := MTLPrimitiveType.Triangle 

    // log.debugf("Metal: draw_impl - Encoder: %v, Vertices: %d, Instances: %d, FirstVertex: %d, FirstInstance: %d",
    //           render_encoder, vertex_count, instance_count, first_vertex, first_instance)

    objc.msg_send(nil, id(render_encoder), sel_drawPrimitives_vertexStart_vertexCount_instanceCount_baseInstance,
        primitive_type,
        NSUInteger(first_vertex),
        NSUInteger(vertex_count),
        NSUInteger(instance_count),
        NSUInteger(first_instance),
    )
}

draw_indexed_impl :: proc(
    encoder_handle: rawptr, // MTLRenderCommandEncoder_Handle
    device_handle: gfx_interface.Gfx_Device,
    index_count: u32, 
    instance_count: u32, 
    first_index: u32, 
    base_vertex: i32, // Can be negative
    first_instance: u32,
    index_buffer_handle: rawptr, // This will be the MTLBuffer_Handle from Gfx_Buffer.variant
    index_buffer_offset: u32,    // Offset in bytes into the index buffer
    index_type_is_32bit: bool,   // True if indices are u32, false if u16
) {
    if encoder_handle == nil {
        log.error("Metal: draw_indexed_impl: Encoder handle is nil.")
        return
    }
    if index_buffer_handle == nil {
        log.error("Metal: draw_indexed_impl: Index buffer handle is nil.")
        return
    }
    if index_count == 0 {
        // log.debug("Metal: draw_indexed_impl: index_count is 0, skipping draw call.")
        return
    }
     if instance_count == 0 { // Should default to 1 if not instanced
        instance_count = 1
    }

    render_encoder := MTLRenderCommandEncoder_Handle(encoder_handle)
    mtl_index_buffer := MTLBuffer_Handle(index_buffer_handle)

    // TODO: Get primitive_type from currently bound pipeline state.
    primitive_type := MTLPrimitiveType.Triangle 

    index_type_mtl: NSUInteger
    if index_type_is_32bit {
        index_type_mtl = 1 // MTLIndexType.UInt32 (Assuming 0 for UInt16, 1 for UInt32 based on common Metal bindings)
                           // Need to define MTLIndexType enum in mtl_bindings.odin
                           // MTLIndexTypeUInt16 = 0, MTLIndexTypeUInt32 = 1
        // Let's assume these values for now and add the enum to bindings later.
    } else {
        index_type_mtl = 0 // MTLIndexType.UInt16
    }
    
    // log.debugf("Metal: draw_indexed_impl - Encoder: %v, Indices: %d, Instances: %d, IdxBuf: %v, IdxType: %v",
    //           render_encoder, index_count, instance_count, mtl_index_buffer, index_type_mtl)


    objc.msg_send(nil, id(render_encoder), sel_drawIndexedPrimitives_indexCount_indexType_indexBuffer_indexBufferOffset_instanceCount_baseVertex_baseInstance,
        primitive_type,
        NSUInteger(index_count),
        index_type_mtl, // MTLIndexType
        mtl_index_buffer,
        NSUInteger(index_buffer_offset),
        NSUInteger(instance_count),
        NSInteger(base_vertex), // baseVertex can be negative
        NSUInteger(first_instance),
    )
}
