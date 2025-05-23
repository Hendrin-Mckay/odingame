package metal

import "../gfx_interface"
import "../../common" // For common.Engine_Error
import "core:log"

// --- Gfx_Device_Interface Vertex Array Object (VAO) Stubs ---
// In Metal, the equivalent is MTLVertexDescriptor and MTLRenderPipelineDescriptor.vertexDescriptor.
// These are typically managed at the pipeline level, not as separate objects.

// The mtl_create_vertex_array_wrapper signature from the grep output was:
// mtl_create_vertex_array_wrapper :: proc(device: gfx_interface.Gfx_Device) -> (gfx_interface.Gfx_Vertex_Array, gfx_interface.Gfx_Error)
// The interface definition for create_vertex_array is:
// create_vertex_array: proc(device: Gfx_Device, layouts: []Vertex_Buffer_Layout, vertex_buffers: []Gfx_Buffer, index_buffer: Gfx_Buffer) -> (Gfx_Vertex_Array, common.Engine_Error),
// So, I will update the wrapper to match the interface, including parameters.

mtl_create_vertex_array_wrapper :: proc(
    device: gfx_interface.Gfx_Device, 
    vertex_buffer_layouts: []gfx_interface.Vertex_Buffer_Layout, 
    vertex_buffers: []gfx_interface.Gfx_Buffer,
    index_buffer: gfx_interface.Gfx_Buffer,
) -> (gfx_interface.Gfx_Vertex_Array, common.Engine_Error) {
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
    return gfx_interface.Gfx_Vertex_Array{}, common.Engine_Error.Not_Implemented
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
    // Updated cases to match gfx_interface.Vertex_Format
    case .Float32_X1: return 0 // MTLVertexFormatFloat
    case .Float32_X2: return 0 // MTLVertexFormatFloat2
    case .Float32_X3: return 0 // MTLVertexFormatFloat3
    case .Float32_X4: return 0 // MTLVertexFormatFloat4
    case .Unorm8_X4:  return 0 // MTLVertexFormatUChar4Normalized
    // case .Sint16_X2: return 0 // MTLVertexFormatShort2
    // Add other formats as they become supported
    // case .Float:    return 0 // Replace with actual MTLVertexFormat enum value - Old cases
    // case .Float2:   return 0
    // case .Float3:   return 0
    // case .Float4:   return 0
    // case .Int:      return 0
    // case .Int2:     return 0
    // case .Int3:     return 0
    // case .Int4:     return 0
    // case .UInt:     return 0
    // case .UInt2:    return 0
    // case .UInt3:    return 0
    // case .UInt4:    return 0
    // case .Short:    return 0
    // case .UShort:   return 0
    // case .Byte:     return 0
    // case .UByte:    return 0
    // case .Half:     return 0
    // case .Half2:    return 0
    // case .Half3:    return 0
    // case .Half4:    return 0
    // case .Fixed:    return 0 // These are less common in modern APIs
    // case .Fixed2:   return 0
    // case .Fixed3:   return 0
    // case .Fixed4:   return 0
    // case ._2101010: return 0 // e.g. MTLVertexFormatUInt1010102Normalized
    // case ._1010102: return 0
    case:           
        log.errorf("mtl_vertex_format: Unknown or unsupported gfx_interface.Vertex_Format: %v", format)
        return 0 // MTLVertexFormatInvalid
    }
}

// Creates a MTLVertexDescriptor from a vertex layout
mtl_create_vertex_descriptor :: proc(
    layout: []gfx_interface.Vertex_Attribute, // This should be []gfx_interface.Vertex_Buffer_Layout
                                             // as per the create_vertex_array interface
) -> rawptr {
    // This is a placeholder. In a real implementation, you would:
    // 1. Create a MTLVertexDescriptor
    // 2. Configure the vertex attributes and buffer layouts from []gfx_interface.Vertex_Buffer_Layout
    // 3. Return the descriptor
    return nil
}
