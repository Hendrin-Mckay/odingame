package opengl

import "../gfx_interface"
import "../../common" // For common.Engine_Error
import "core:log"
import "core:mem"
import "core:os"
import gl "vendor:OpenGL/gl"

// --- Buffer Types ---

Buffer_Type :: enum u32 {
    Vertex = gl.ARRAY_BUFFER,
    Index = gl.ELEMENT_ARRAY_BUFFER,
    Uniform = gl.UNIFORM_BUFFER,
}

Buffer_Usage :: enum u32 {
    Static = gl.STATIC_DRAW,
    Dynamic = gl.DYNAMIC_DRAW,
    Stream = gl.STREAM_DRAW,
}

Buffer :: struct {
    id: u32,
    type: Buffer_Type,
    size: int,
    usage: Buffer_Usage,
    is_mapped: bool,
}

// --- Buffer Management ---

create_buffer_impl :: proc(
    device: gfx_interface.Gfx_Device,
    type: gfx_interface.Buffer_Type,
    size: int,
    data: rawptr = nil,
    usage: gfx_interface.Buffer_Usage = .Static,
) -> (gfx_interface.Gfx_Buffer, common.Engine_Error) {
    // Convert buffer type
    buffer_type: Buffer_Type
    switch type {
    case .Vertex:   buffer_type = .Vertex
    case .Index:    buffer_type = .Index
    case .Uniform:  buffer_type = .Uniform
    case:           return gfx_interface.Gfx_Buffer{}, common.Engine_Error.Buffer_Creation_Failed
    }
    
    // Convert usage
    buffer_usage: Buffer_Usage
    switch usage {
    case .Static:  buffer_usage = .Static
    case .Dynamic: buffer_usage = .Dynamic
    case .Stream:  buffer_usage = .Stream
    case:          return gfx_interface.Gfx_Buffer{}, common.Engine_Error.Buffer_Creation_Failed
    }
    
    // Create buffer
    var buffer_id: u32
    gl.GenBuffers(1, &buffer_id)
    if buffer_id == 0 {
        return gfx_interface.Gfx_Buffer{}, common.Engine_Error.Buffer_Creation_Failed
    }
    
    // Bind and initialize buffer
    gl.BindBuffer(cast(u32)buffer_type, buffer_id)
    gl.BufferData(cast(u32)buffer_type, size, data, cast(u32)buffer_usage)
    
    // Create buffer wrapper
    buffer := new(Buffer)
    buffer.id = buffer_id
    buffer.type = buffer_type
    buffer.size = size
    buffer.usage = buffer_usage
    buffer.is_mapped = false
    
    log.debugf("Created buffer (ID: %d, Type: %v, Size: %d, Usage: %v)", 
        buffer_id, buffer_type, size, buffer_usage)
    
    return gfx_interface.Gfx_Buffer{buffer}, .None
}

update_buffer_impl :: proc(
    buffer: gfx_interface.Gfx_Buffer,
    offset: int,
    size: int,
    data: rawptr,
) -> common.Engine_Error {
    if buffer_obj, ok := buffer.variant.(^Buffer); ok && !buffer_obj.is_mapped {
        gl.BindBuffer(cast(u32)buffer_obj.type, buffer_obj.id)
        gl.BufferSubData(cast(u32)buffer_obj.type, offset, size, data)
        return .None
    }
    return common.Engine_Error.Invalid_Handle
}

destroy_buffer_impl :: proc(buffer: gfx_interface.Gfx_Buffer) {
    if buffer_obj, ok := buffer.variant.(^Buffer); ok && !buffer_obj.is_mapped {
        gl.DeleteBuffers(1, &buffer_obj.id)
        free(buffer_obj)
    }
}

map_buffer_impl :: proc(
    buffer: gfx_interface.Gfx_Buffer,
    access: gfx_interface.Map_Access,
) -> (rawptr, common.Engine_Error) {
    if buffer_obj, ok := buffer.variant.(^Buffer); ok && !buffer_obj.is_mapped {
        gl.BindBuffer(cast(u32)buffer_obj.type, buffer_obj.id)
        
        var gl_access: u32
        switch access {
        case .Read:         gl_access = gl.READ_ONLY
        case .Write:        gl_access = gl.WRITE_ONLY
        case .Read_Write:   gl_access = gl.READ_WRITE
        case:               return nil, common.Engine_Error.Invalid_Handle
        }
        
        ptr := gl.MapBuffer(cast(u32)buffer_obj.type, gl_access)
        if ptr != nil {
            buffer_obj.is_mapped = true
            return ptr, .None
        }
    }
    return nil, common.Engine_Error.Invalid_Handle
}

unmap_buffer_impl :: proc(buffer: gfx_interface.Gfx_Buffer) -> common.Engine_Error {
    if buffer_obj, ok := buffer.variant.(^Buffer); ok && buffer_obj.is_mapped {
        gl.BindBuffer(cast(u32)buffer_obj.type, buffer_obj.id)
        if gl.UnmapBuffer(cast(u32)buffer_obj.type) {
            buffer_obj.is_mapped = false
            return .None
        }
    }
    return common.Engine_Error.Invalid_Handle
}

// --- Buffer Binding ---

set_vertex_buffer_impl :: proc(
    device: gfx_interface.Gfx_Device,
    binding: u32,
    buffer: gfx_interface.Gfx_Buffer,
    offset: int,
    stride: int,
) -> common.Engine_Error {
    if buffer_obj, ok := buffer.variant.(^Buffer); ok && buffer_obj.type == .Vertex {
        gl.BindVertexBuffer(binding, buffer_obj.id, offset, stride)
        return .None
    }
    return common.Engine_Error.Invalid_Handle
}

set_index_buffer_impl :: proc(
    device: gfx_interface.Gfx_Device,
    buffer: gfx_interface.Gfx_Buffer,
    offset: int,
    index_type: gfx_interface.Index_Type,
) -> common.Engine_Error {
    if buffer_obj, ok := buffer.variant.(^Buffer); ok && buffer_obj.type == .Index {
        gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, buffer_obj.id)
        return .None
    }
    return common.Engine_Error.Invalid_Handle
}

// --- Drawing ---
draw_impl :: proc(
    device: gfx_interface.Gfx_Device,
    vertex_count: u32,
    instance_count: u32 = 1,
    first_vertex: u32 = 0,
    first_instance: u32 = 0,
) -> common.Engine_Error {
    if instance_count == 1 {
        gl.DrawArrays(gl.TRIANGLES, i32(first_vertex), i32(vertex_count))
    } else {
        gl.DrawArraysInstanced(gl.TRIANGLES, i32(first_vertex), i32(vertex_count), i32(instance_count))
    }
    return .None
}

draw_indexed_impl :: proc(
    device: gfx_interface.Gfx_Device,
    index_count: u32,
    instance_count: u32 = 1,
    first_index: u32 = 0,
    vertex_offset: i32 = 0,
    first_instance: u32 = 0,
) -> common.Engine_Error {
    index_type_size := size_of(u16) // Assuming 16-bit indices
    
    if instance_count == 1 {
        gl.DrawElementsBaseVertex(
            gl.TRIANGLES,
            i32(index_count),
            gl.UNSIGNED_SHORT,
            rawptr(uintptr(first_index * u32(index_type_size))),
            vertex_offset
        )
    } else {
        gl.DrawElementsInstancedBaseVertex(
            gl.TRIANGLES,
            i32(index_count),
            gl.UNSIGNED_SHORT,
            rawptr(uintptr(first_index * u32(index_type_size))),
            i32(instance_count),
            vertex_offset
        )
    }
    
    return .None
}
