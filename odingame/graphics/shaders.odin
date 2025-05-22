package graphics

import gl "vendor:OpenGL/gl"
import "core:fmt"
import "core:log"
import "core:strings"
import "core:mem"


// --- OpenGL Specific Structs ---

Gl_Shader :: struct {
	id:    u32,
	stage: Shader_Stage, // Store the stage for reference, though GL combines them in a program
	// We might store the source or path for debugging/recompilation if needed in future.
	main_allocator: ^rawptr, 
}

Gl_Pipeline :: struct {
	program_id:     u32,
	shaders:        []Gfx_Shader, // Keep track of attached shaders for potential reflection/debugging
	main_allocator: ^rawptr,
}


// --- Helper Functions (OpenGL specific, not directly part of the interface) ---

@(private="file")
gl_compile_shader_source :: proc(source: string, stage: Shader_Stage, shader_type: gl.GLenum) -> (u32, Gfx_Error) {
	shader_id := gl.CreateShader(shader_type)
	if shader_id == 0 {
		log.errorf("glCreateShader failed for stage %v", stage)
		return 0, .Shader_Compilation_Failed
	}

	// Odin strings are not necessarily null-terminated. OpenGL expects a C-string.
	// We need to ensure the source string is null-terminated for OpenGL.
	// A common way is to make a temporary C-string.
	c_source := strings.clone_to_cstring(source)
	defer delete(c_source) // Ensure C-string is freed

	csource_ptr := &c_source
	gl.ShaderSource(shader_id, 1, csource_ptr, nil)
	gl.CompileShader(shader_id)

	compile_status: i32
	gl.GetShaderiv(shader_id, gl.COMPILE_STATUS, &compile_status)
	if compile_status == gl.FALSE {
		info_log_length: i32
		gl.GetShaderiv(shader_id, gl.INFO_LOG_LENGTH, &info_log_length)

		info_log_buffer := make([]u8, info_log_length)
		defer delete(info_log_buffer)

		gl.GetShaderInfoLog(shader_id, info_log_length, nil, rawptr(info_log_buffer))
		log.errorf("Shader compilation failed for stage %v: %s", stage, string(info_log_buffer))
		gl.DeleteShader(shader_id)
		return 0, .Shader_Compilation_Failed
	}

	log.infof("Shader for stage %v compiled successfully (ID: %v)", stage, shader_id)
	return shader_id, .None
}


// --- Implementation of Gfx_Device_Interface shader/pipeline functions ---

gl_create_shader_from_source_impl :: proc(device: Gfx_Device, source: string, stage: Shader_Stage) -> (Gfx_Shader, Gfx_Error) {
	device_ptr, ok_device := device.variant.(^Gl_Device)
	if !ok_device {
		log.error("gl_create_shader_from_source: Invalid Gfx_Device type.")
		return Gfx_Shader{}, .Invalid_Handle
	}

	shader_type: gl.GLenum
	#partial switch stage {
	case .Vertex:
		shader_type = gl.VERTEX_SHADER
	case .Fragment:
		shader_type = gl.FRAGMENT_SHADER
	// case .Compute: // TODO: Add if compute shaders are needed
	// 	shader_type = gl.COMPUTE_SHADER
	case:
		log.errorf("Unsupported shader stage: %v", stage)
		return Gfx_Shader{}, .Shader_Compilation_Failed // Or a more specific error
	}

	shader_id, err := gl_compile_shader_source(source, stage, shader_type)
	if err != .None {
		return Gfx_Shader{}, err
	}

	gl_shader_ptr := new(Gl_Shader, device_ptr.main_allocator^)
	gl_shader_ptr.id = shader_id
	gl_shader_ptr.stage = stage
	gl_shader_ptr.main_allocator = device_ptr.main_allocator

	return Gfx_Shader{gl_shader_ptr}, .None
}

gl_create_shader_from_bytecode_impl :: proc(device: Gfx_Device, bytecode: []u8, stage: Shader_Stage) -> (Gfx_Shader, Gfx_Error) {
	// OpenGL Core Profile typically doesn't use precompiled shader bytecode directly via glShaderBinary
	// in the same way as Vulkan/DX12. SPIR-V can be used with ARB_gl_spirv, but that's an extension.
	// For now, this is not implemented for general GLSL.
	log.warn("gl_create_shader_from_bytecode: Not typically used with GLSL in core profile. Use source.")
	return Gfx_Shader{}, .Not_Implemented
}

gl_destroy_shader_impl :: proc(shader: Gfx_Shader) {
	if shader_ptr, ok := shader.variant.(^Gl_Shader); ok {
		if shader_ptr.id != 0 {
			gl.DeleteShader(shader_ptr.id)
			log.infof("OpenGL Shader ID %v (stage %v) destroyed.", shader_ptr.id, shader_ptr.stage)
		}
		free(shader_ptr, shader_ptr.main_allocator^)
	} else {
		log.errorf("gl_destroy_shader: Invalid shader type %v", shader.variant)
	}
}

gl_create_pipeline_impl :: proc(device: Gfx_Device, shaders: []Gfx_Shader) -> (Gfx_Pipeline, Gfx_Error) {
	device_ptr, ok_device := device.variant.(^Gl_Device)
	if !ok_device {
		log.error("gl_create_pipeline: Invalid Gfx_Device type.")
		return Gfx_Pipeline{}, .Invalid_Handle
	}

	if len(shaders) == 0 {
		log.error("gl_create_pipeline: No shaders provided to create pipeline.")
		return Gfx_Pipeline{}, .Shader_Compilation_Failed // Or a more specific error
	}

	program_id := gl.CreateProgram()
	if program_id == 0 {
		log.error("glCreateProgram failed.")
		return Gfx_Pipeline{}, .Shader_Compilation_Failed // Or a more specific error
	}

	attached_gl_shaders := make([]^Gl_Shader, 0, len(shaders))
	defer delete(attached_gl_shaders) // Should be empty by the end due to moving ownership or just clearing

	for gfx_shader in shaders {
		shader_ptr, ok := gfx_shader.variant.(^Gl_Shader)
		if !ok || shader_ptr.id == 0 {
			log.errorf("gl_create_pipeline: Invalid shader found in list %v.", gfx_shader.variant)
			// Detach any already attached shaders and delete program before returning
			for attached_shader_ptr in attached_gl_shaders {
				gl.DetachShader(program_id, attached_shader_ptr.id)
			}
			gl.DeleteProgram(program_id)
			return Gfx_Pipeline{}, .Invalid_Handle
		}
		gl.AttachShader(program_id, shader_ptr.id)
		append(&attached_gl_shaders, shader_ptr) // Keep track for detaching if link fails
		log.infof("Attached shader ID %v (stage %v) to program ID %v.", shader_ptr.id, shader_ptr.stage, program_id)
	}

	gl.LinkProgram(program_id)

	link_status: i32
	gl.GetProgramiv(program_id, gl.LINK_STATUS, &link_status)
	if link_status == gl.FALSE {
		info_log_length: i32
		gl.GetProgramiv(program_id, gl.INFO_LOG_LENGTH, &info_log_length)

		info_log_buffer := make([]u8, info_log_length)
		defer delete(info_log_buffer)
		
		gl.GetProgramInfoLog(program_id, info_log_length, nil, rawptr(info_log_buffer))
		log.errorf("Shader program linking failed (Program ID %v): %s", program_id, string(info_log_buffer))

		// Detach shaders before deleting program
		for shader_ptr in attached_gl_shaders {
			gl.DetachShader(program_id, shader_ptr.id)
		}
		gl.DeleteProgram(program_id)
		return Gfx_Pipeline{}, .Shader_Compilation_Failed
	}

	log.infof("Shader program ID %v linked successfully.", program_id)

	// Shaders can be detached and deleted after successful linking,
	// as the program object now contains the linked code.
	// However, the Gfx_Shader handles might still be alive and managed by the user.
	// The Gfx_Pipeline will own its copy of Gfx_Shader variants for record keeping.
	// Destroying the Gfx_Shader handles via gfx_api.destroy_shader should be safe.
	// The actual GL shader objects are okay to delete IF they are not needed elsewhere.
	// For simplicity, we assume Gfx_Shader handles passed in are "consumed" by pipeline creation
	// in terms of their GL objects if no longer needed independently.
	// Let's not delete the gl shader objects here, but let gl_destroy_shader handle it.
	// The caller can destroy the individual Gfx_Shader handles if they are no longer needed.

	// Store copies of the Gfx_Shader variants (not the Gl_Shader pointers themselves)
	// This is if Gfx_Pipeline needs to know what it was made from.
	// The actual Gl_Shader structs behind the variants passed in are still owned by caller.
	// This might need a more robust ownership model if shaders are reused across many pipelines.
	// For now, let's assume they are not reused or caller manages their lifetime.
	
	// Create a copy of the Gfx_Shader array for the pipeline to own.
	// This is tricky because Gfx_Shader is a struct_variant.
	// We'll just store the program_id for now.
	// TODO: Revisit how Gfx_Pipeline stores references to its Gfx_Shaders if needed for reflection.
	// For now, the Gfx_Pipeline doesn't store the Gfx_Shader array.

	pipeline_ptr := new(Gl_Pipeline, device_ptr.main_allocator^)
	pipeline_ptr.program_id = program_id
	pipeline_ptr.main_allocator = device_ptr.main_allocator
	// pipeline_ptr.shaders = shaders // This would be a shallow copy of the slice. Need deep copy if variant data is complex.

	return Gfx_Pipeline{pipeline_ptr}, .None
}

gl_destroy_pipeline_impl :: proc(pipeline: Gfx_Pipeline) {
	if pipeline_ptr, ok := pipeline.variant.(^Gl_Pipeline); ok {
		if pipeline_ptr.program_id != 0 {
			gl.DeleteProgram(pipeline_ptr.program_id)
			log.infof("OpenGL Program ID %v destroyed.", pipeline_ptr.program_id)
		}
		// If pipeline_ptr.shaders stored Gfx_Shader that it owned, they'd be destroyed here too.
		free(pipeline_ptr, pipeline_ptr.main_allocator^)
	} else {
		log.errorf("gl_destroy_pipeline: Invalid pipeline type %v", pipeline.variant)
	}
}

gl_set_pipeline_impl :: proc(device: Gfx_Device, pipeline: Gfx_Pipeline) {
	// device_ptr, ok_device := device.variant.(^Gl_Device)
	// if !ok_device {
	// 	log.error("gl_set_pipeline: Invalid Gfx_Device type.")
	// 	return
	// }
	// No device specific state needed for set_pipeline, relies on current GL context.

	if pipeline_ptr, ok := pipeline.variant.(^Gl_Pipeline); ok {
		if pipeline_ptr.program_id != 0 {
			gl.UseProgram(pipeline_ptr.program_id)
		} else {
			gl.UseProgram(0) // Unbind current program
		}
	} else {
		// This case could mean an uninitialized Gfx_Pipeline or an invalid one.
		// Binding program 0 is safest if intent is unclear.
		gl.UseProgram(0)
		log.warn("gl_set_pipeline: Invalid or uninitialized pipeline, unbinding current program.")
	}
}

// Note: The old load_shader_program, compile_shader, check_shader_error, check_program_error
// are effectively replaced by the logic within gl_create_shader_from_source_impl and gl_create_pipeline_impl.
// They can be removed from the project or kept as internal helpers if desired, but the new
// interface functions are the public API now.
// For this refactor, we'll assume they are removed to avoid confusion.
// The existing ShaderProgram struct is also replaced by Gfx_Pipeline / Gl_Pipeline.
// Uniform setting functions (set_uniform_*) will need to be adapted later to work with Gfx_Pipeline.
// For now, this file focuses on shader/pipeline creation and management.
// The uniform functions would be part of a different sub-task or a later step.
// e.g. gfx_api.set_uniform_int(pipeline, name, value), etc.
// These would internally get the Gl_Pipeline, then its program_id, then glGetUniformLocation + glUniform*.
// This will be added to the Gfx_Device_Interface later.

// The functions like `gl_create_shader_from_source_impl` need to be assigned
// to the `gfx_api` in `device.odin`. That will be the next step.
// This file now defines the types and implementations.
// We also need to ensure `initialize_sdl_opengl_backend` in device.odin is updated.
// I will do that in the next step.


// --- Uniform Setting Implementations ---
import "core:strings" // For strings.clone_to_cstring

@(private="file")
get_uniform_location :: proc(pipeline_ptr: ^Gl_Pipeline, name_str: string) -> i32 {
	// TODO: Cache uniform locations in Gl_Pipeline struct after first query for performance.
	// For now, always query.
	if pipeline_ptr == nil || pipeline_ptr.program_id == 0 {
		log.errorf("get_uniform_location: Invalid pipeline program ID for uniform '%s'.", name_str)
		return -1
	}
	// Convert Odin string to C-string for OpenGL
	name_cstr := strings.clone_to_cstring(name_str)
	defer delete(name_cstr)

	loc := gl.GetUniformLocation(pipeline_ptr.program_id, name_cstr)
	// if loc == -1 { // It's okay for a uniform to not be found (e.g., optimized out). Don't log error here.
	// 	log.debugf("Uniform '%s' (c: %s) not found in program ID %v.", name_str, name_cstr, pipeline_ptr.program_id)
	// }
	return loc
}

gl_set_uniform_mat4_impl :: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, mat: matrix[4,4]f32) -> Gfx_Error {
	pipeline_ptr, ok := pipeline.variant.(^Gl_Pipeline)
	if !ok { return .Invalid_Handle }

	loc := get_uniform_location(pipeline_ptr, name)
	if loc != -1 {
		gl.UniformMatrix4fv(loc, 1, false, &mat[0,0])
		return .None
	}
	return .Invalid_Handle 
}

gl_set_uniform_vec2_impl :: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, vec: [2]f32) -> Gfx_Error {
	pipeline_ptr, ok := pipeline.variant.(^Gl_Pipeline)
	if !ok { return .Invalid_Handle }
	loc := get_uniform_location(pipeline_ptr, name)
	if loc != -1 {
		gl.Uniform2fv(loc, 1, &vec[0])
		return .None
	}
	return .Invalid_Handle
}

gl_set_uniform_vec3_impl :: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, vec: [3]f32) -> Gfx_Error {
	pipeline_ptr, ok := pipeline.variant.(^Gl_Pipeline)
	if !ok { return .Invalid_Handle }
	loc := get_uniform_location(pipeline_ptr, name)
	if loc != -1 {
		gl.Uniform3fv(loc, 1, &vec[0])
		return .None
	}
	return .Invalid_Handle
}

gl_set_uniform_vec4_impl :: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, vec: [4]f32) -> Gfx_Error {
	pipeline_ptr, ok := pipeline.variant.(^Gl_Pipeline)
	if !ok { return .Invalid_Handle }
	loc := get_uniform_location(pipeline_ptr, name)
	if loc != -1 {
		gl.Uniform4fv(loc, 1, &vec[0])
		return .None
	}
	return .Invalid_Handle
}

gl_set_uniform_int_impl :: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, val: i32) -> Gfx_Error {
	pipeline_ptr, ok := pipeline.variant.(^Gl_Pipeline)
	if !ok { return .Invalid_Handle }
	loc := get_uniform_location(pipeline_ptr, name)
	if loc != -1 {
		gl.Uniform1i(loc, val)
		return .None
	}
	return .Invalid_Handle
}

gl_set_uniform_float_impl :: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, val: f32) -> Gfx_Error {
	pipeline_ptr, ok := pipeline.variant.(^Gl_Pipeline)
	if !ok { return .Invalid_Handle }
	loc := get_uniform_location(pipeline_ptr, name)
	if loc != -1 {
		gl.Uniform1f(loc, val)
		return .None
	}
	return .Invalid_Handle
}
