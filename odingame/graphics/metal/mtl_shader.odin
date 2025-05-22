package metal

import "../gfx_interface"
import "core:log"

// --- Gfx_Device_Interface Shader and Pipeline Management Stubs ---

mtl_create_shader_from_source_wrapper :: proc(device: gfx_interface.Gfx_Device, source: string, stage: gfx_interface.Shader_Stage) -> (gfx_interface.Gfx_Shader, gfx_interface.Gfx_Error) {
	log.warn("Metal: create_shader_from_source_wrapper not implemented.")
	// Real Metal:
	// 1. Get id<MTLDevice> from Gfx_Device.
	// 2. Create id<MTLLibrary> from MSL source string: device.newLibrary(source: source, compileOptions: nil).
	// 3. Get id<MTLFunction> from library: library.newFunction(name: "vertex_main") or "fragment_main".
	//    The function name needs to be known or passed.
	// 4. Populate Mtl_Shader_Internal.
	return gfx_interface.Gfx_Shader{}, .Not_Implemented
}

mtl_create_shader_from_bytecode_wrapper :: proc(device: gfx_interface.Gfx_Device, bytecode: []u8, stage: gfx_interface.Shader_Stage) -> (gfx_interface.Gfx_Shader, gfx_interface.Gfx_Error) {
	log.warn("Metal: create_shader_from_bytecode_wrapper not implemented.")
	// Real Metal:
	// 1. Get id<MTLDevice>.
	// 2. Create id<MTLLibrary> from precompiled .metallib data: device.newLibrary(data: dispatch_data_create(bytecode...)).
	// 3. Get id<MTLFunction> from library.
	// 4. Populate Mtl_Shader_Internal.
	return gfx_interface.Gfx_Shader{}, .Not_Implemented
}

mtl_destroy_shader_wrapper :: proc(shader: gfx_interface.Gfx_Shader) {
	log.warn("Metal: destroy_shader_wrapper not implemented.")
	// Real Metal: Release MTLLibrary and MTLFunction (handled by ARC).
	// Free Mtl_Shader_Internal struct.
	if shader_internal, ok := shader.variant.(Mtl_Shader_Variant); ok && shader_internal != nil {
		// Placeholder for freeing variant data
		// free(shader_internal, shader_internal.allocator);
	}
}

mtl_create_pipeline_wrapper :: proc(device: gfx_interface.Gfx_Device, shaders: []gfx_interface.Gfx_Shader) -> (gfx_interface.Gfx_Pipeline, gfx_interface.Gfx_Error) {
	log.warn("Metal: create_pipeline_wrapper not implemented.")
	// Real Metal:
	// 1. Get id<MTLDevice>.
	// 2. Create MTLRenderPipelineDescriptor.
	// 3. Set vertexFunction and fragmentFunction from Gfx_Shader variants.
	// 4. Configure colorAttachment pixel formats, depth/stencil formats.
	// 5. Set vertexDescriptor (from Gfx_Vertex_Array or created here).
	// 6. device.newRenderPipelineState(descriptor: desc).
	// 7. Populate Mtl_Pipeline_Internal.
	return gfx_interface.Gfx_Pipeline{}, .Not_Implemented
}

mtl_destroy_pipeline_wrapper :: proc(pipeline: gfx_interface.Gfx_Pipeline) {
	log.warn("Metal: destroy_pipeline_wrapper not implemented.")
	// Real Metal: Release MTLRenderPipelineState (ARC). Free Mtl_Pipeline_Internal.
	if pipeline_internal, ok := pipeline.variant.(Mtl_Pipeline_Variant); ok && pipeline_internal != nil {
		// Placeholder for freeing variant data
		// free(pipeline_internal, pipeline_internal.allocator);
	}
}

mtl_set_pipeline_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline) {
	log.warn("Metal: set_pipeline_wrapper not implemented.")
	// Real Metal: MTLRenderCommandEncoder.setRenderPipelineState().
}


// --- Gfx_Device_Interface Uniform Setting Stubs ---
// In Metal, uniforms are typically passed via:
// 1. Setting bytes directly for small data: renderCommandEncoder.setVertexBytes / setFragmentBytes.
// 2. Using MTLBuffers for larger data (equivalent to Uniform Buffers).
// The current Gfx_Device_Interface for uniforms is more like GL's individual uniform setting.
// This would map to setBytes or require a system for managing small, dynamic constant data.

mtl_set_uniform_mat4_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, mat: matrix[4,4]f32) -> gfx_interface.Gfx_Error {
    log.warn("Metal: set_uniform_mat4_wrapper not implemented (use setVertexBytes/setFragmentBytes or MTLBuffers).")
    return .Not_Implemented
}
mtl_set_uniform_vec2_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [2]f32) -> gfx_interface.Gfx_Error {
    log.warn("Metal: set_uniform_vec2_wrapper not implemented (use setVertexBytes/setFragmentBytes or MTLBuffers).")
    return .Not_Implemented
}
mtl_set_uniform_vec3_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [3]f32) -> gfx_interface.Gfx_Error {
    log.warn("Metal: set_uniform_vec3_wrapper not implemented (use setVertexBytes/setFragmentBytes or MTLBuffers).")
    return .Not_Implemented
}
mtl_set_uniform_vec4_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [4]f32) -> gfx_interface.Gfx_Error {
    log.warn("Metal: set_uniform_vec4_wrapper not implemented (use setVertexBytes/setFragmentBytes or MTLBuffers).")
    return .Not_Implemented
}
mtl_set_uniform_int_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, val: i32) -> gfx_interface.Gfx_Error {
    log.warn("Metal: set_uniform_int_wrapper not implemented (use setVertexBytes/setFragmentBytes or MTLBuffers).")
    return .Not_Implemented
}
mtl_set_uniform_float_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, val: f32) -> gfx_interface.Gfx_Error {
    log.warn("Metal: set_uniform_float_wrapper not implemented (use setVertexBytes/setFragmentBytes or MTLBuffers).")
    return .Not_Implemented
}
