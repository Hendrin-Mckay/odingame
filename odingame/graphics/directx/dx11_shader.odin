package directx11

import "../gfx_interface"
import "../../common" // For common.Engine_Error
import "core:log"
import "core:mem"
import "core:strings"

// --- Shader Management ---

create_shader_from_source_impl :: proc(
    device: gfx_interface.Gfx_Device,
    source: string,
    stage: gfx_interface.Shader_Stage,
) -> (gfx_interface.Gfx_Shader, common.Engine_Error) {
    log.warn("DirectX 11: create_shader_from_source_impl not implemented")
    // Real implementation would:
    // 1. Compile the shader source using D3DCompile
    // 2. Create the appropriate shader object based on the stage
    // 3. Store the shader and input layout in D3D11_Shader_Internal
    return gfx_interface.Gfx_Shader{}, common.Engine_Error.Not_Implemented
}

create_shader_from_bytecode_impl :: proc(
    device: gfx_interface.Gfx_Device,
    bytecode: []u8,
    stage: gfx_interface.Shader_Stage,
) -> (gfx_interface.Gfx_Shader, common.Engine_Error) {
    log.warn("DirectX 11: create_shader_from_bytecode_impl not implemented")
    // Real implementation would:
    // 1. Create the appropriate shader object from the bytecode
    // 2. Store the shader and input layout in D3D11_Shader_Internal
    return gfx_interface.Gfx_Shader{}, common.Engine_Error.Not_Implemented
}

destroy_shader_impl :: proc(shader: gfx_interface.Gfx_Shader) {
    log.warn("DirectX 11: destroy_shader_impl not implemented")
    // Real implementation would:
    // 1. Release the shader object
    // 2. Release the input layout if it exists
    if shader_internal, ok := shader.variant.(D3D11_Shader_Variant); ok && shader_internal != nil {
        // free(shader_internal, shader_internal.allocator)
    }
}

// --- Pipeline Management ---

create_pipeline_impl :: proc(
    device: gfx_interface.Gfx_Device,
    shaders: []gfx_interface.Gfx_Shader,
) -> (gfx_interface.Gfx_Pipeline, common.Engine_Error) {
    log.warn("DirectX 11: create_pipeline_impl not implemented")
    // Real implementation would:
    // 1. Create input layout from vertex shader reflection
    // 2. Create blend state, depth stencil state, and rasterizer state
    // 3. Store the pipeline state in D3D11_Pipeline_Internal
    return gfx_interface.Gfx_Pipeline{}, common.Engine_Error.Not_Implemented
}

destroy_pipeline_impl :: proc(pipeline: gfx_interface.Gfx_Pipeline) {
    log.warn("DirectX 11: destroy_pipeline_impl not implemented")
    // Real implementation would:
    // 1. Release all pipeline state objects
    if pipeline_internal, ok := pipeline.variant.(D3D11_Pipeline_Variant); ok && pipeline_internal != nil {
        // free(pipeline_internal, pipeline_internal.allocator)
    }
}

set_pipeline_impl :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline) -> common.Engine_Error {
    log.warn("DirectX 11: set_pipeline_impl not implemented")
    // Real implementation would:
    // 1. Set the input layout
    // 2. Set the shaders
    // 3. Set the blend state, depth stencil state, and rasterizer state
    return common.Engine_Error.Not_Implemented
}

// --- Uniforms ---

set_uniform_mat4_impl :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, mat: matrix[4, 4]f32) -> common.Engine_Error {
    log.warn("DirectX 11: set_uniform_mat4_impl not implemented")
    // Real implementation would:
    // 1. Update the constant buffer with the matrix data
    return common.Engine_Error.Not_Implemented
}

set_uniform_vec2_impl :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [2]f32) -> common.Engine_Error {
    log.warn("DirectX 11: set_uniform_vec2_impl not implemented")
    return common.Engine_Error.Not_Implemented
}

set_uniform_vec3_impl :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [3]f32) -> common.Engine_Error {
    log.warn("DirectX 11: set_uniform_vec3_impl not implemented")
    return common.Engine_Error.Not_Implemented
}

set_uniform_vec4_impl :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [4]f32) -> common.Engine_Error {
    log.warn("DirectX 11: set_uniform_vec4_impl not implemented")
    return common.Engine_Error.Not_Implemented
}

set_uniform_int_impl :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, val: i32) -> common.Engine_Error {
    log.warn("DirectX 11: set_uniform_int_impl not implemented")
    return common.Engine_Error.Not_Implemented
}

set_uniform_float_impl :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, val: f32) -> common.Engine_Error {
    log.warn("DirectX 11: set_uniform_float_impl not implemented")
    return common.Engine_Error.Not_Implemented
}
