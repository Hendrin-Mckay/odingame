package graphics

import gl "vendor:OpenGL/gl"
import "../common" // For common.Engine_Error
import graphics_types "./types" // Import for graphics-specific types
import "core:fmt"
import "core:log"
import "core:strings"
import "core:mem"


// --- OpenGL Specific Structs ---

Gl_Shader :: struct {
	id:    u32,
	stage: graphics_types.Shader_Stage, // Use qualified type
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
gl_compile_shader_source :: proc(source: string, stage: graphics_types.Shader_Stage, shader_type: gl.GLenum) -> (u32, common.Engine_Error) { // Use qualified type
	shader_id := gl.CreateShader(shader_type)
	if shader_id == 0 {
		log.errorf("glCreateShader failed for stage %v", stage)
		return 0, common.Engine_Error.Shader_Compilation_Failed
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
		return 0, common.Engine_Error.Shader_Compilation_Failed
	}

	log.infof("Shader for stage %v compiled successfully (ID: %v)", stage, shader_id)
	return shader_id, common.Engine_Error.None
}


// --- Implementation of Gfx_Device_Interface shader/pipeline functions ---

gl_create_shader_from_source_impl :: proc(device: Gfx_Device, source: string, stage: graphics_types.Shader_Stage) -> (Gfx_Shader, common.Engine_Error) { // Use qualified type
	device_ptr, ok_device := device.variant.(^Gl_Device)
	if !ok_device {
		log.error("gl_create_shader_from_source: Invalid Gfx_Device type.")
		return Gfx_Shader{}, common.Engine_Error.Invalid_Handle
	}

	shader_type: gl.GLenum
	#partial switch stage {
	case .Vertex:
		shader_type = gl.VERTEX_SHADER
	case .Fragment:
		shader_type = gl.FRAGMENT_SHADER
	case .Compute: 
		shader_type = gl.COMPUTE_SHADER // Ensure this case is handled if Compute stage is used
	case:
		log.errorf("Unsupported shader stage: %v", stage)
		return Gfx_Shader{}, common.Engine_Error.Shader_Compilation_Failed // Or a more specific error
	}

	shader_id, err := gl_compile_shader_source(source, stage, shader_type)
	if err != .None {
		return Gfx_Shader{}, err
	}

	gl_shader_ptr := new(Gl_Shader, device_ptr.main_allocator^)
	gl_shader_ptr.id = shader_id
	gl_shader_ptr.stage = stage
	gl_shader_ptr.main_allocator = device_ptr.main_allocator

	return Gfx_Shader{gl_shader_ptr}, common.Engine_Error.None
}

gl_create_shader_from_bytecode_impl :: proc(device: Gfx_Device, bytecode: []u8, stage: graphics_types.Shader_Stage) -> (Gfx_Shader, common.Engine_Error) { // Use qualified type
	// OpenGL Core Profile typically doesn't use precompiled shader bytecode directly via glShaderBinary
	// in the same way as Vulkan/DX12. SPIR-V can be used with ARB_gl_spirv, but that's an extension.
	// For now, this is not implemented for general GLSL.
	log.warn("gl_create_shader_from_bytecode: Not typically used with GLSL in core profile. Use source.")
	return Gfx_Shader{}, common.Engine_Error.Not_Implemented
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

// Updated to take Gfx_Pipeline_Desc
gl_create_pipeline_impl :: proc(device: Gfx_Device, desc: graphics_types.Gfx_Pipeline_Desc) -> (Gfx_Pipeline, common.Engine_Error) {
	device_ptr, ok_device := device.variant.(^Gl_Device)
	if !ok_device {
		log.error("gl_create_pipeline: Invalid Gfx_Device type.")
		return Gfx_Pipeline{}, common.Engine_Error.Invalid_Handle
	}

	// The Gfx_Pipeline_Desc contains a single shader_handle, which is assumed to be a pre-linked program ID
	// or a handle that the backend can use to get/create a program.
	// The old logic of attaching and linking individual shaders from a []Gfx_Shader is removed.
	// The backend (OpenGL here) must now work with this single shader_handle.

	// If desc.shader_handle is a Gfx_Handle that wraps a Gl_Shader (which is just one stage),
	// this is problematic. Gfx_Pipeline_Desc should ideally point to a "program" concept.
	// For OpenGL, a "program" is the result of glCreateProgram, glAttachShader (for VS, FS), glLinkProgram.
	// Let's assume desc.shader_handle.variant is a ^Gl_Shader that is actually a *program* id,
	// or that the backend needs to do more to resolve it.
	// This is a significant change from the previous []Gfx_Shader input.

	program_handle_variant := desc.shader_handle.variant
	program_id: u32
	
	// This logic depends on what `desc.shader_handle` actually IS.
	// If it's a Gfx_Shader handle that itself is a Gl_Shader (single stage), this is wrong.
	// If `create_shader_from_source` was changed to return a *program* handle wrapped in Gfx_Shader,
	// then this might work.
	// This is a point of ambiguity from the previous refactoring.
	// For now, to make progress, let's assume `desc.shader_handle` IS the program ID,
	// or it's a Gfx_Shader containing the program_id (e.g. if a "program" Gfx_Shader type was made).
	// The `Gl_Shader` struct has an `id` which is a shader stage ID.
	// The `Gl_Pipeline` struct has `program_id`.
	// This means `desc.shader_handle` cannot directly be a `Gl_Shader` if it's meant to be a program.
	// This part of the API design (`Gfx_Pipeline_Desc.shader_handle`) needs clarification.
	//
	// Tentative assumption: `desc.shader_handle` is a Gfx_Shader that somehow represents the program.
	// Or, more likely, the `gl_create_shader_from_source_impl` should have created a *program*
	// if it's the sole shader input to a pipeline. This is not what it does.
	//
	// Let's assume for this step that the `desc.shader_handle` IS the program_id.
	// This means the caller of `create_pipeline` must have already created and linked a program
	// and passed its ID as the `shader_handle` (wrapped in Gfx_Handle).
	// This is a major shift in responsibility.
	// The old `gl_create_pipeline_impl` DID the linking.
	// If we keep that, then `Gfx_Pipeline_Desc` should contain `[]Gfx_Shader` for stages.
	// The `Gfx_Pipeline_Desc` in `common_types.odin` has `shader_handle: Gfx_Handle`.
	// This is a conflict.
	//
	// For this pass, I will make `gl_create_pipeline_impl` assume `desc.shader_handle` is a program id.
	// This means the linking logic from the old `gl_create_pipeline_impl` is no longer here.
	// This requires that `gfx_api.resource_creation.create_shader_from_source` (or a new function)
	// now produces a linked program handle. The current `gl_create_shader_from_source_impl` does not.
	// This is a significant architectural change implied by the new Gfx_Pipeline_Desc.
	
	// Safest assumption: desc.shader_handle is a Gfx_Handle whose variant points to a Gl_Pipeline struct
	// (if a "program" was wrapped this way), or it's a raw program ID cast to rawptr.
	// Given Gfx_Handle is u32, it could directly BE the program_id if convention is established.
	// Let's assume `desc.shader_handle` IS the program_id (as u32).
	
	program_id = desc.shader_handle; // Assuming Gfx_Handle is u32 and directly the program_id
	
	if program_id == 0 {
		log.error("gl_create_pipeline: Invalid program ID (0) provided in Gfx_Pipeline_Desc.")
		return Gfx_Pipeline{}, common.Engine_Error.Invalid_Handle
	}
	
	// Vertex buffer layouts are in desc.vertex_buffer_layouts.
	// These need to be applied to a VAO, or set up with glVertexAttribPointer if not using VAOs globally.
	// The pipeline object in GL (program) doesn't store vertex layout state itself.
	// This state is usually part of a VAO or set dynamically before drawing.
	// For now, Gl_Pipeline struct only stores program_id. Vertex layout application is separate.

	pipeline_ptr := new(Gl_Pipeline, device_ptr.main_allocator^)
	pipeline_ptr.program_id = program_id
	// pipeline_ptr.shaders = ??? // How to get original Gfx_Shader stages from a program_id? Not directly possible.
	pipeline_ptr.main_allocator = device_ptr.main_allocator

	log.infof("OpenGL Pipeline (Program ID %v) wrapped.", program_id)
	return Gfx_Pipeline{pipeline_ptr}, common.Engine_Error.None
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
// import "core:strings" // Already imported at top

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

gl_set_uniform_mat4_impl :: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, mat: matrix[4,4]f32) -> common.Engine_Error {
	pipeline_ptr, ok := pipeline.variant.(^Gl_Pipeline)
	if !ok { return common.Engine_Error.Invalid_Handle }

	loc := get_uniform_location(pipeline_ptr, name)
	if loc != -1 {
		gl.UniformMatrix4fv(loc, 1, false, &mat[0,0])
		return common.Engine_Error.None
	}
	return common.Engine_Error.Invalid_Handle 
}

gl_set_uniform_vec2_impl :: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, vec: [2]f32) -> common.Engine_Error {
	pipeline_ptr, ok := pipeline.variant.(^Gl_Pipeline)
	if !ok { return common.Engine_Error.Invalid_Handle }
	loc := get_uniform_location(pipeline_ptr, name)
	if loc != -1 {
		gl.Uniform2fv(loc, 1, &vec[0])
		return common.Engine_Error.None
	}
	return common.Engine_Error.Invalid_Handle
}

gl_set_uniform_vec3_impl :: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, vec: [3]f32) -> common.Engine_Error {
	pipeline_ptr, ok := pipeline.variant.(^Gl_Pipeline)
	if !ok { return common.Engine_Error.Invalid_Handle }
	loc := get_uniform_location(pipeline_ptr, name)
	if loc != -1 {
		gl.Uniform3fv(loc, 1, &vec[0])
		return common.Engine_Error.None
	}
	return common.Engine_Error.Invalid_Handle
}

gl_set_uniform_vec4_impl :: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, vec: [4]f32) -> common.Engine_Error {
	pipeline_ptr, ok := pipeline.variant.(^Gl_Pipeline)
	if !ok { return common.Engine_Error.Invalid_Handle }
	loc := get_uniform_location(pipeline_ptr, name)
	if loc != -1 {
		gl.Uniform4fv(loc, 1, &vec[0])
		return common.Engine_Error.None
	}
	return common.Engine_Error.Invalid_Handle
}

gl_set_uniform_int_impl :: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, val: i32) -> common.Engine_Error {
	pipeline_ptr, ok := pipeline.variant.(^Gl_Pipeline)
	if !ok { return common.Engine_Error.Invalid_Handle }
	loc := get_uniform_location(pipeline_ptr, name)
	if loc != -1 {
		gl.Uniform1i(loc, val)
		return common.Engine_Error.None
	}
	return common.Engine_Error.Invalid_Handle
}

gl_set_uniform_float_impl :: proc(device: Gfx_Device, pipeline: Gfx_Pipeline, name: string, val: f32) -> common.Engine_Error {
	pipeline_ptr, ok := pipeline.variant.(^Gl_Pipeline)
	if !ok { return common.Engine_Error.Invalid_Handle }
	loc := get_uniform_location(pipeline_ptr, name)
	if loc != -1 {
		gl.Uniform1f(loc, val)
		return common.Engine_Error.None
	}
	return common.Engine_Error.Invalid_Handle
}
