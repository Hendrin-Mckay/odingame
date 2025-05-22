package directx

import "../gfx_interface"
import "core:log"

// --- Gfx_Device_Interface Shader and Pipeline Management Stubs ---

dx_create_shader_from_source_wrapper :: proc(device: gfx_interface.Gfx_Device, source: string, stage: gfx_interface.Shader_Stage) -> (gfx_interface.Gfx_Shader, gfx_interface.Gfx_Error) {
	log.warn("DirectX: create_shader_from_source_wrapper not implemented.")
	// Real D3D11: Would compile HLSL source (e.g. D3DCompileFromFile or D3DCompile)
	// then create shader object (e.g. ID3D11Device.CreateVertexShader).
	return gfx_interface.Gfx_Shader{}, .Not_Implemented
}

dx_create_shader_from_bytecode_wrapper :: proc(device: gfx_interface.Gfx_Device, bytecode: []u8, stage: gfx_interface.Shader_Stage) -> (gfx_interface.Gfx_Shader, gfx_interface.Gfx_Error) {
	log.warn("DirectX: create_shader_from_bytecode_wrapper not implemented.")
	// Real D3D11: ID3D11Device.CreateVertexShader, CreatePixelShader etc. using provided bytecode.
	return gfx_interface.Gfx_Shader{}, .Not_Implemented
}

dx_destroy_shader_wrapper :: proc(shader: gfx_interface.Gfx_Shader) {
	log.warn("DirectX: destroy_shader_wrapper not implemented.")
	// Real D3D11: Release shader object (e.g. ID3D11VertexShader.Release()).
	if shader_internal, ok := shader.variant.(Dx_Shader_Variant); ok && shader_internal != nil {
		// Placeholder for freeing variant data
		// free(shader_internal, shader_internal.allocator);
	}
}

dx_create_pipeline_wrapper :: proc(device: gfx_interface.Gfx_Device, shaders: []gfx_interface.Gfx_Shader) -> (gfx_interface.Gfx_Pipeline, gfx_interface.Gfx_Error) {
	log.warn("DirectX: create_pipeline_wrapper not implemented.")
	// Real D3D11:
	// 1. Collect shader handles from Gfx_Shader variants.
	// 2. Create InputLayout based on vertex shader signature and Vertex_Buffer_Layout.
	// 3. Optionally create/compile BlendState, DepthStencilState, RasterizerState objects if they are part of pipeline.
	// 4. Populate Dx_Pipeline_Internal.
	// Note: D3D11 doesn't have a single "pipeline" object like Vulkan. It's a collection of states set on the context.
	// This Gfx_Pipeline for D3D11 would likely store these state objects or shader handles + input layout.
	return gfx_interface.Gfx_Pipeline{}, .Not_Implemented
}

dx_destroy_pipeline_wrapper :: proc(pipeline: gfx_interface.Gfx_Pipeline) {
	log.warn("DirectX: destroy_pipeline_wrapper not implemented.")
	// Real D3D11: Release InputLayout, and any other state objects (Blend, DepthStencil, Rasterizer)
	// that were created and stored in Dx_Pipeline_Internal.
	if pipeline_internal, ok := pipeline.variant.(Dx_Pipeline_Variant); ok && pipeline_internal != nil {
		// Placeholder for freeing variant data
		// free(pipeline_internal, pipeline_internal.allocator);
	}
}

dx_set_pipeline_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline) {
	log.warn("DirectX: set_pipeline_wrapper not implemented.")
	// Real D3D11:
	// 1. Get Dx_Pipeline_Internal from Gfx_Pipeline.
	// 2. Call ID3D11DeviceContext methods:
	//    - VSSetShader, PSSetShader, etc.
	//    - IASetInputLayout.
	//    - OMSetBlendState, OMSetDepthStencilState, RSSetState.
}


// --- Gfx_Device_Interface Uniform Setting Stubs ---
// In D3D11, uniforms are typically handled via Constant Buffers.
// These stubs would need to map to updating data within those constant buffers.

dx_set_uniform_mat4_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, mat: matrix[4,4]f32) -> gfx_interface.Gfx_Error {
    log.warn("DirectX: set_uniform_mat4_wrapper not implemented (use Constant Buffers).")
    return .Not_Implemented
}
dx_set_uniform_vec2_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [2]f32) -> gfx_interface.Gfx_Error {
    log.warn("DirectX: set_uniform_vec2_wrapper not implemented (use Constant Buffers).")
    return .Not_Implemented
}
dx_set_uniform_vec3_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [3]f32) -> gfx_interface.Gfx_Error {
    log.warn("DirectX: set_uniform_vec3_wrapper not implemented (use Constant Buffers).")
    return .Not_Implemented
}
dx_set_uniform_vec4_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [4]f32) -> gfx_interface.Gfx_Error {
    log.warn("DirectX: set_uniform_vec4_wrapper not implemented (use Constant Buffers).")
    return .Not_Implemented
}
dx_set_uniform_int_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, val: i32) -> gfx_interface.Gfx_Error {
    log.warn("DirectX: set_uniform_int_wrapper not implemented (use Constant Buffers).")
    return .Not_Implemented
}
dx_set_uniform_float_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, val: f32) -> gfx_interface.Gfx_Error {
    log.warn("DirectX: set_uniform_float_wrapper not implemented (use Constant Buffers).")
    return .Not_Implemented
}
