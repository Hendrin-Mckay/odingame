package graphics

import gl "vendor:OpenGL/gl"
import "core:log"
import "core:mem"
import "core:unsafe" // For size_of

// --- OpenGL Specific Struct ---

Gl_Buffer :: struct {
	id:             u32,
	size:           int,
	type:           Buffer_Type,
	gl_target:      gl.GLenum, // e.g., gl.ARRAY_BUFFER, gl.ELEMENT_ARRAY_BUFFER
	gl_usage:       gl.GLenum, // e.g., gl.STATIC_DRAW, gl.DYNAMIC_DRAW
	main_allocator: ^rawptr,
}


// --- Implementation of Gfx_Device_Interface buffer functions ---

gl_create_buffer_impl :: proc(device: Gfx_Device, type: Buffer_Type, size: int, data: rawptr = nil, dynamic: bool = false) -> (Gfx_Buffer, Gfx_Error) {
	device_ptr, ok_device := device.variant.(^Gl_Device)
	if !ok_device {
		log.error("gl_create_buffer: Invalid Gfx_Device type.")
		return Gfx_Buffer{}, .Invalid_Handle
	}

	if size <= 0 {
		log.errorf("gl_create_buffer: Invalid buffer size %d.", size)
		return Gfx_Buffer{}, .Buffer_Creation_Failed
	}

	target: gl.GLenum
	#partial switch type {
	case .Vertex:
		target = gl.ARRAY_BUFFER
	case .Index:
		target = gl.ELEMENT_ARRAY_BUFFER
	case .Uniform:
		target = gl.UNIFORM_BUFFER
	// case: // Other buffer types if needed in future
	// 	log.errorf("Unsupported buffer type: %v", type)
	// 	return Gfx_Buffer{}, .Buffer_Creation_Failed
	}

	usage: gl.GLenum = gl.STATIC_DRAW
	if dynamic {
		usage = gl.DYNAMIC_DRAW
	}

	buf_id: u32
	gl.GenBuffers(1, &buf_id)
	if buf_id == 0 {
		log.errorf("glGenBuffers failed for type %v.", type)
		return Gfx_Buffer{}, .Buffer_Creation_Failed
	}

	gl.BindBuffer(target, buf_id)
	gl.BufferData(target, gl.GLsizeiptr(size), data, usage)
	gl.BindBuffer(target, 0) // Unbind

	gl_buffer_ptr := new(Gl_Buffer, device_ptr.main_allocator^)
	gl_buffer_ptr.id = buf_id
	gl_buffer_ptr.size = size
	gl_buffer_ptr.type = type
	gl_buffer_ptr.gl_target = target
	gl_buffer_ptr.gl_usage = usage
	gl_buffer_ptr.main_allocator = device_ptr.main_allocator

	log.infof("OpenGL Buffer ID %v (type %v, size %v, dynamic %v) created.", buf_id, type, size, dynamic)
	return Gfx_Buffer{gl_buffer_ptr}, .None
}

gl_update_buffer_impl :: proc(buffer: Gfx_Buffer, offset: int, data: rawptr, size: int) -> Gfx_Error {
	buf_ptr, ok := buffer.variant.(^Gl_Buffer)
	if !ok || buf_ptr.id == 0 {
		log.error("gl_update_buffer: Invalid or uninitialized Gfx_Buffer.")
		return .Invalid_Handle
	}

	if data == nil {
		log.error("gl_update_buffer: Data pointer is nil.")
		return .Buffer_Creation_Failed // Or Invalid_Argument
	}

	if offset < 0 || size <= 0 || (offset + size) > buf_ptr.size {
		log.errorf("gl_update_buffer: Invalid update region (offset:%d, size:%d) for buffer size %d.",
			offset, size, buf_ptr.size)
		return .Buffer_Creation_Failed // Or out_of_bounds error
	}

	gl.BindBuffer(buf_ptr.gl_target, buf_ptr.id)
	gl.BufferSubData(buf_ptr.gl_target, gl.GLintptr(offset), gl.GLsizeiptr(size), data)
	gl.BindBuffer(buf_ptr.gl_target, 0) // Unbind

	// log.debugf("OpenGL Buffer ID %v updated (offset %v, size %v).", buf_ptr.id, offset, size) // Can be spammy
	return .None
}

gl_destroy_buffer_impl :: proc(buffer: Gfx_Buffer) {
	if buf_ptr, ok := buffer.variant.(^Gl_Buffer); ok {
		if buf_ptr.id != 0 {
			gl.DeleteBuffers(1, &buf_ptr.id)
			log.infof("OpenGL Buffer ID %v (type %v) destroyed.", buf_ptr.id, buf_ptr.type)
		}
		free(buf_ptr, buf_ptr.main_allocator^)
	} else {
		log.errorf("gl_destroy_buffer: Invalid buffer type %v", buffer.variant)
	}
}


gl_map_buffer_impl :: proc(buffer: Gfx_Buffer, offset, size: int) -> rawptr {
    buf_ptr, ok := buffer.variant.(^Gl_Buffer)
    if !ok || buf_ptr.id == 0 {
        log.error("gl_map_buffer: Invalid or uninitialized Gfx_Buffer.")
        return nil
    }
    if offset < 0 || size <= 0 || (offset + size) > buf_ptr.size {
        log.errorf("gl_map_buffer: Invalid map region (offset:%d, size:%d) for buffer size %d.",
            offset, size, buf_ptr.size)
        return nil
    }
    // TODO: Specify access flags (gl.MAP_READ_BIT, gl.MAP_WRITE_BIT, etc.)
    // For simplicity, using gl.MAP_WRITE_BIT | gl.MAP_INVALIDATE_RANGE_BIT for common update patterns.
    // Be cautious with mapping; proper synchronization (fences) might be needed for advanced use.
    gl.BindBuffer(buf_ptr.gl_target, buf_ptr.id)
    mapped_ptr := gl.MapBufferRange(buf_ptr.gl_target, gl.GLintptr(offset), gl.GLsizeiptr(size), gl.MAP_WRITE_BIT | gl.MAP_INVALIDATE_RANGE_BIT)
    // gl.BindBuffer(buf_ptr.gl_target, 0) // DO NOT unbind while mapped. Unbind in unmap_buffer.
    if mapped_ptr == nil {
        log.errorf("glMapBufferRange failed for Buffer ID %v. Error: %v", buf_ptr.id, gl.GetError())
    }
    return mapped_ptr
}

gl_unmap_buffer_impl :: proc(buffer: Gfx_Buffer) {
    buf_ptr, ok := buffer.variant.(^Gl_Buffer)
    if !ok || buf_ptr.id == 0 {
        log.error("gl_unmap_buffer: Invalid or uninitialized Gfx_Buffer.")
        return
    }
    gl.BindBuffer(buf_ptr.gl_target, buf_ptr.id) // Ensure correct buffer is bound before unmapping
    if gl.UnmapBuffer(buf_ptr.gl_target) == gl.FALSE {
        log.errorf("glUnmapBuffer failed for Buffer ID %v. Data might be corrupted. Error: %v", buf_ptr.id, gl.GetError())
        // Consider how to handle this error; data might be corrupt.
    }
    gl.BindBuffer(buf_ptr.gl_target, 0) // Unbind after unmapping
}


// --- Vertex/Index Buffer Setting ---
// These are more complex due to vertex attributes and layouts.
// For SpriteBatch, we have a fixed layout: Pos (vec2), Color (vec4), Texcoord (vec2).

// Vertex_Attribute :: struct {
//  index:      u32,    // Attribute location
//  size:       i32,    // Number of components (1, 2, 3, 4)
//  type:       gl.GLenum, // e.g., gl.FLOAT
//  normalized: bool,
//  stride:     i32,    // Byte offset between consecutive generic vertex attributes
//  offset:     rawptr, // Byte offset of the first component
// }
// This might be part of a Gfx_Pipeline's state or set separately.

// For now, SpriteBatch specific vertex layout will be handled inside its flush method
// by direct GL calls, then refactored if a more general vertex layout system is built.
// Or, we can make set_vertex_buffer/set_index_buffer simpler for now.

gl_set_vertex_buffer_impl :: proc(device: Gfx_Device, buffer: Gfx_Buffer, binding_index: u32 = 0, offset: u32 = 0) {
	buf_ptr, ok := buffer.variant.(^Gl_Buffer)
	if !ok || buf_ptr.id == 0 || buf_ptr.type != .Vertex {
		log.error("gl_set_vertex_buffer: Invalid or non-vertex Gfx_Buffer.")
		gl.BindBuffer(gl.ARRAY_BUFFER, 0) // Unbind any existing VBO from the target
		return
	}
	
	// This simplified version just binds the buffer.
	// Vertex attribute setup (glVertexAttribPointer) is NOT handled here.
	// It's assumed to be handled by the pipeline or a separate vertex layout system.
	// For SpriteBatch, it will set its specific attributes after calling this.
	// binding_index and offset are not used in this simplified GL version directly with BindBuffer.
	// They are more relevant for APIs like Metal/Vulkan or if using glBindVertexBuffer.
	
	gl.BindBuffer(gl.ARRAY_BUFFER, buf_ptr.id)
	// log.debugf("Bound Vertex Buffer ID %v to gl.ARRAY_BUFFER.", buf_ptr.id)
}

gl_set_index_buffer_impl :: proc(device: Gfx_Device, buffer: Gfx_Buffer, offset: u32 = 0) {
	buf_ptr, ok := buffer.variant.(^Gl_Buffer)
	if !ok || buf_ptr.id == 0 || buf_ptr.type != .Index {
		log.error("gl_set_index_buffer: Invalid or non-index Gfx_Buffer.")
		gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, 0) // Unbind
		return
	}
	// offset is not used in this simplified GL version directly with BindBuffer for element array.
	// It's part of the glDrawElements call (first_index).
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, buf_ptr.id)
	// log.debugf("Bound Index Buffer ID %v to gl.ELEMENT_ARRAY_BUFFER.", buf_ptr.id)
}
