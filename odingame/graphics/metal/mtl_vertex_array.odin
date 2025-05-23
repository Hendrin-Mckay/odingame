package metal

import "../gfx_interface"
import "core:log"

// --- Gfx_Device_Interface Vertex Array Object (VAO) Stubs ---
// In Metal, the equivalent is MTLVertexDescriptor and MTLRenderPipelineDescriptor.vertexDescriptor.
// These are typically managed at the pipeline level, not as separate objects.

mtl_create_vertex_array_wrapper :: proc(device: gfx_interface.Gfx_Device) -> (gfx_interface.Gfx_Vertex_Array, gfx_interface.Gfx_Error) {
    log.warn("Metal: create_vertex_array_wrapper not implemented.")
    // Real Metal:
    // 1. In Metal, vertex descriptors are part of the pipeline state.
    // 2. This function might create a MTLVertexDescriptor and store it for later pipeline creation.
    // 3. Alternatively, it might be a no-op, and the vertex layout would be specified directly when creating the pipeline.
    return gfx_interface.Gfx_Vertex_Array{}, .Not_Implemented
}

mtl_destroy_vertex_array_wrapper :: proc(vao: gfx_interface.Gfx_Vertex_Array) {
    log.warn("Metal: destroy_vertex_array_wrapper not implemented.")
    // Real Metal: If MTLVertexDescriptor was created, release it.
    // If it's just a descriptor (value type), no explicit cleanup is needed.
    if vao_internal, ok := vao.variant.(Mtl_Vertex_Array_Variant); ok && vao_internal != nil {
        // Placeholder for freeing variant data
        // free(vao_internal, vao_internal.allocator);
    }
}

mtl_bind_vertex_array_wrapper :: proc(device: gfx_interface.Gfx_Device, vao: gfx_interface.Gfx_Vertex_Array) {
    log.warn("Metal: bind_vertex_array_wrapper not implemented.")
    // Real Metal:
    // 1. In Metal, the vertex descriptor is part of the pipeline state.
    // 2. This function might be a no-op, or it might store the current vertex layout
    //    to be used when creating the next pipeline.
    // 3. Alternatively, it might set the vertex descriptor on a command encoder.
}

// --- Helper Functions ---

// Converts Gfx_Vertex_Format to MTLVertexFormat
mtl_vertex_format :: proc(format: gfx_interface.Vertex_Format) -> u32 {
    // This is a placeholder. In a real implementation, you would map
    // your Gfx_Vertex_Format enum to MTLVertexFormat values.
    #partial switch format {
    case .Float:    return 0 // Replace with actual MTLVertexFormat enum value
    case .Float2:   return 0
    case .Float3:   return 0
    case .Float4:   return 0
    case .Int:      return 0
    case .Int2:     return 0
    case .Int3:     return 0
    case .Int4:     return 0
    case .UInt:     return 0
    case .UInt2:    return 0
    case .UInt3:    return 0
    case .UInt4:    return 0
    case .Short:    return 0
    case .UShort:   return 0
    case .Byte:     return 0
    case .UByte:    return 0
    case .Half:     return 0
    case .Half2:    return 0
    case .Half3:    return 0
    case .Half4:    return 0
    case .Fixed:    return 0
    case .Fixed2:   return 0
    case .Fixed3:   return 0
    case .Fixed4:   return 0
    case ._2101010: return 0
    case ._1010102: return 0
    case:           return 0
    }
}

// Creates a MTLVertexDescriptor from a vertex layout
mtl_create_vertex_descriptor :: proc(
    layout: []gfx_interface.Vertex_Attribute,
) -> rawptr {
    // This is a placeholder. In a real implementation, you would:
    // 1. Create a MTLVertexDescriptor
    // 2. Configure the vertex attributes and buffer layouts
    // 3. Return the descriptor
    return nil
}
