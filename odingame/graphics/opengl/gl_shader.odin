package opengl

import "../gfx_interface"
import "core:log"
import "core:mem"
import "core:strings"
import gl "vendor:OpenGL/gl"

// --- Shader Types ---

Shader_Type :: enum u32 {
    Vertex = gl.VERTEX_SHADER,
    Fragment = gl.FRAGMENT_SHADER,
    Geometry = gl.GEOMETRY_SHADER,
    Compute = gl.COMPUTE_SHADER,
}

Shader_Stage :: struct {
    id:         u32,
    type:       Shader_Type,
    source:     string,
    is_compiled: bool,
}

Shader_Program :: struct {
    id: u32,
    shaders: [dynamic]^Shader_Stage,
    uniforms: map[string]i32,
    is_linked: bool,
}

// --- Shader Creation ---

create_shader_from_source_impl :: proc(
    device: gfx_interface.Gfx_Device,
    source: string,
    stage: gfx_interface.Shader_Stage,
) -> (gfx_interface.Gfx_Shader, gfx_interface.Gfx_Error) {
    shader_type: Shader_Type
    
    switch stage {
    case .Vertex:
        shader_type = .Vertex
    case .Fragment:
        shader_type = .Fragment
    case .Compute:
        shader_type = .Compute
    case:
        log.errorf("Unsupported shader stage: %v", stage)
        return gfx_interface.Gfx_Shader{}, .Shader_Compilation_Failed
    }
    
    shader_id := gl.CreateShader(cast(u32)shader_type)
    if shader_id == 0 {
        log.error("Failed to create shader")
        return gfx_interface.Gfx_Shader{}, .Shader_Compilation_Failed
    }
    
    // Convert Odin string to C string for OpenGL
    c_source := strings.clone_to_cstring(source)
    defer delete(c_source)
    
    // Set shader source
    gl.ShaderSource(shader_id, 1, &c_source, nil)
    
    // Compile shader
    gl.CompileShader(shader_id)
    
    // Check compilation status
    var status: i32
    gl.GetShaderiv(shader_id, gl.COMPILE_STATUS, &status)
    if status == 0 {
        // Get error log
        var log_length: i32
        gl.GetShaderiv(shader_id, gl.INFO_LOG_LENGTH, &log_length)
        
        if log_length > 0 {
            log_buffer := make([]u8, log_length, context.temp_allocator)
            gl.GetShaderInfoLog(shader_id, log_length, nil, raw_data(log_buffer))
            log.errorf("Shader compilation failed: %s", string(log_buffer))
        }
        
        gl.DeleteShader(shader_id)
        return gfx_interface.Gfx_Shader{}, .Shader_Compilation_Failed
    }
    
    // Create shader stage
    shader_stage := new(Shader_Stage)
    shader_stage.id = shader_id
    shader_stage.type = shader_type
    shader_stage.source = source
    shader_stage.is_compiled = true
    
    return gfx_interface.Gfx_Shader{shader_stage}, .None
}

create_shader_from_bytecode_impl :: proc(
    device: gfx_interface.Gfx_Device,
    bytecode: []u8,
    stage: gfx_interface.Shader_Stage,
) -> (gfx_interface.Gfx_Shader, gfx_interface.Gfx_Error) {
    // Note: OpenGL doesn't support precompiled shader bytecode in the same way as other APIs.
    // We'll just convert the bytecode to a string and compile it as source.
    if len(bytecode) == 0 {
        return gfx_interface.Gfx_Shader{}, .Shader_Compilation_Failed
    }
    
    source := string(bytecode)
    return create_shader_from_source_impl(device, source, stage)
}

destroy_shader_impl :: proc(shader: gfx_interface.Gfx_Shader) {
    if shader_stage, ok := shader.variant.(^Shader_Stage); ok {
        if shader_stage.is_compiled {
            gl.DeleteShader(shader_stage.id)
            shader_stage.is_compiled = false
        }
        free(shader_stage)
    }
}

// --- Pipeline Management ---

create_pipeline_impl :: proc(
    device: gfx_interface.Gfx_Device,
    shaders: []gfx_interface.Gfx_Shader,
) -> (gfx_interface.Gfx_Pipeline, gfx_interface.Gfx_Error) {
    if len(shaders) == 0 {
        return gfx_interface.Gfx_Pipeline{}, .Shader_Compilation_Failed
    }
    
    // Create program
    program_id := gl.CreateProgram()
    if program_id == 0 {
        return gfx_interface.Gfx_Pipeline{}, .Shader_Compilation_Failed
    }
    
    // Attach shaders
    program := new(Shader_Program)
    program.id = program_id
    program.shaders = make([dynamic]^Shader_Stage, 0, len(shaders))
    program.uniforms = make(map[string]i32)
    
    for shader in shaders {
        if shader_stage, ok := shader.variant.(^Shader_Stage); ok && shader_stage.is_compiled {
            gl.AttachShader(program_id, shader_stage.id)
            append(&program.shaders, shader_stage)
        }
    }
    
    // Link program
    gl.LinkProgram(program_id)
    
    // Check link status
    var link_status: i32
    gl.GetProgramiv(program_id, gl.LINK_STATUS, &link_status)
    if link_status == 0 {
        // Get error log
        var log_length: i32
        gl.GetProgramiv(program_id, gl.INFO_LOG_LENGTH, &log_length)
        
        if log_length > 0 {
            log_buffer := make([]u8, log_length, context.temp_allocator)
            gl.GetProgramInfoLog(program_id, log_length, nil, raw_data(log_buffer))
            log.errorf("Program linking failed: %s", string(log_buffer))
        }
        
        // Clean up
        for shader_stage in program.shaders {
            gl.DetachShader(program_id, shader_stage.id)
        }
        gl.DeleteProgram(program_id)
        delete(program.shaders)
        delete(program.uniforms)
        free(program)
        
        return gfx_interface.Gfx_Pipeline{}, .Shader_Compilation_Failed
    }
    
    // Detach shaders (they're linked now)
    for shader_stage in program.shaders {
        gl.DetachShader(program_id, shader_stage.id)
    }
    
    program.is_linked = true
    return gfx_interface.Gfx_Pipeline{program}, .None
}

destroy_pipeline_impl :: proc(pipeline: gfx_interface.Gfx_Pipeline) {
    if program, ok := pipeline.variant.(^Shader_Program); ok {
        if program.is_linked {
            gl.DeleteProgram(program.id)
            program.is_linked = false
        }
        delete(program.shaders)
        delete(program.uniforms)
        free(program)
    }
}

set_pipeline_impl :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline) -> gfx_interface.Gfx_Error {
    if program, ok := pipeline.variant.(^Shader_Program); ok && program.is_linked {
        gl.UseProgram(program.id)
        return .None
    }
    return .Invalid_Handle
}

// --- Uniforms ---

set_uniform_mat4_impl :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, mat: matrix[4, 4]f32) -> gfx_interface.Gfx_Error {
    if program, ok := pipeline.variant.(^Shader_Program); ok && program.is_linked {
        location := get_uniform_location(program, name)
        if location >= 0 {
            gl.UniformMatrix4fv(location, 1, false, &mat[0, 0])
            return .None
        }
    }
    return .Invalid_Handle
}

set_uniform_vec2_impl :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [2]f32) -> gfx_interface.Gfx_Error {
    if program, ok := pipeline.variant.(^Shader_Program); ok && program.is_linked {
        location := get_uniform_location(program, name)
        if location >= 0 {
            gl.Uniform2f(location, vec.x, vec.y)
            return .None
        }
    }
    return .Invalid_Handle
}

set_uniform_vec3_impl :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [3]f32) -> gfx_interface.Gfx_Error {
    if program, ok := pipeline.variant.(^Shader_Program); ok && program.is_linked {
        location := get_uniform_location(program, name)
        if location >= 0 {
            gl.Uniform3f(location, vec.x, vec.y, vec.z)
            return .None
        }
    }
    return .Invalid_Handle
}

set_uniform_vec4_impl :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [4]f32) -> gfx_interface.Gfx_Error {
    if program, ok := pipeline.variant.(^Shader_Program); ok && program.is_linked {
        location := get_uniform_location(program, name)
        if location >= 0 {
            gl.Uniform4f(location, vec.x, vec.y, vec.z, vec.w)
            return .None
        }
    }
    return .Invalid_Handle
}

set_uniform_int_impl :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: i32) -> gfx_interface.Gfx_Error {
    if program, ok := pipeline.variant.(^Shader_Program); ok && program.is_linked {
        location := get_uniform_location(program, name)
        if location >= 0 {
            gl.Uniform1i(location, value)
            return .None
        }
    }
    return .Invalid_Handle
}

set_uniform_float_impl :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, value: f32) -> gfx_interface.Gfx_Error {
    if program, ok := pipeline.variant.(^Shader_Program); ok && program.is_linked {
        location := get_uniform_location(program, name)
        if location >= 0 {
            gl.Uniform1f(location, value)
            return .None
        }
    }
    return .Invalid_Handle
}

// --- Helper Functions ---

get_uniform_location :: proc(program: ^Shader_Program, name: string) -> i32 {
    if location, ok := program.uniforms[name]; ok {
        return location
    }
    
    cname := strings.clone_to_cstring(name)
    defer delete(cname)
    
    location := gl.GetUniformLocation(program.id, cname)
    if location >= 0 {
        program.uniforms[name] = location
    } else {
        log.warnf("Uniform '%s' not found in shader program", name)
    }
    
    return location
}
