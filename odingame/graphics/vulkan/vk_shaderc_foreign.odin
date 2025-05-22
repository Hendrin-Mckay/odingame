package vulkan

// Odin foreign bindings for libshaderc
// Based on shaderc/shaderc.h from Google's shaderc repository.

foreign import shaderc "system:shaderc_shared" // Or "system:shaderc" - depends on how libshaderc-dev names the .so
// If the above doesn't work, one might need to link explicitly via build flags, e.g. -L/path/to/libs -lshaderc_shared

@(default_calling_convention="c")
foreign shaderc {
	// --- Enums ---
	Source_Language :: enum i32 {
		GLSL,
		HLSL,
	}

	// Maps to gfx_interface.Shader_Stage and then to vk.ShaderStageFlagBits
	// This enum is for shaderc's understanding of the input.
	Shader_Kind :: enum i32 {
		Vertex_Shader,
		Fragment_Shader,
		Compute_Shader,
		Geometry_Shader,
		Tess_Control_Shader,
		Tess_Evaluation_Shader,

		GLSL_Vertex_Shader                  = Vertex_Shader,
		GLSL_Fragment_Shader                = Fragment_Shader,
		GLSL_Compute_Shader                 = Compute_Shader,
		GLSL_Geometry_Shader                = Geometry_Shader,
		GLSL_Tess_Control_Shader            = Tess_Control_Shader,
		GLSL_Tess_Evaluation_Shader         = Tess_Evaluation_Shader,

		GLSL_Infer_From_Source,
		GLSL_Default_Vertex_Shader,
		GLSL_Default_Fragment_Shader,
		GLSL_Default_Compute_Shader,
		GLSL_Default_Geometry_Shader,
		GLSL_Default_Tess_Control_Shader,
		GLSL_Default_Tess_Evaluation_Shader,
		SPIRV_Assembly,
		RayGen_Shader,
		AnyHit_Shader,
		ClosestHit_Shader,
		Miss_Shader,
		Intersection_Shader,
		Callable_Shader,
		// ... and more GLSL specific defaults for raytracing ...
		Task_Shader,
		Mesh_Shader,
	}

	Compilation_Status :: enum i32 {
		Success                          = 0,
		Invalid_Stage                    = 1, // error stage deduction
		Compilation_Error                = 2, // errors found during compilation
		Internal_Error                   = 3, // unexpected failure
		Null_Result_Object               = 4,
		Invalid_Assembly                 = 5,
		Validation_Error                 = 6, // TODO: Check exact name for this in newer shaderc.h if different
		Transformation_Error             = 7,
		Configuration_Error              = 8,
	}

	Optimization_Level :: enum i32 {
		Zero,        // no optimization
		Size,        // optimize towards reducing code size
		Performance, // optimize towards performance
	}

	// --- Opaque Structs (Handles) ---
	Compiler :: distinct rawptr // shaderc_compiler_t
	Compile_Options :: distinct rawptr // shaderc_compile_options_t
	Compilation_Result :: distinct rawptr // shaderc_compilation_result_t

	// --- Functions ---
	compiler_initialize :: proc() -> Compiler ---
	compiler_release :: proc(compiler: Compiler) ---

	compile_options_initialize :: proc() -> Compile_Options ---
	compile_options_release :: proc(options: Compile_Options) ---
	// compile_options_clone :: proc(options: Compile_Options) -> Compile_Options --- // Optional

	compile_options_add_macro_definition :: proc(
		options: Compile_Options,
		name: cstring, name_length: size_t,
		value: cstring, value_length: size_t,
	) ---
	compile_options_set_source_language :: proc(options: Compile_Options, lang: Source_Language) ---
	compile_options_set_generate_debug_info :: proc(options: Compile_Options) ---
	compile_options_set_optimization_level :: proc(options: Compile_Options, level: Optimization_Level) ---
	// compile_options_set_forced_version_profile :: proc(options: Compile_Options, version: i32, profile: Profile) --- // Profile enum needed
	// compile_options_set_include_callbacks :: proc(...) --- // For #include handling, complex
	compile_options_set_suppress_warnings :: proc(options: Compile_Options) ---
	// compile_options_set_target_env :: proc(options: Compile_Options, target: Target_Env, version: u32) --- // Target_Env, Env_Version enums needed
	// compile_options_set_target_spirv :: proc(options: Compile_Options, version: SPIRV_Version) --- // SPIRV_Version enum needed
	compile_options_set_warnings_as_errors :: proc(options: Compile_Options) ---
	// ... many other options functions ...

	compile_into_spv :: proc(
		compiler: Compiler,
		source_text: cstring,
		source_text_size: size_t,
		shader_kind: Shader_Kind,
		input_file_name: cstring,
		entry_point_name: cstring,
		additional_options: Compile_Options,
	) -> Compilation_Result ---
	
	// compile_into_spv_assembly :: proc(...) -> Compilation_Result ---
	// compile_into_preprocessed_text :: proc(...) -> Compilation_Result ---
	// assemble_into_spv :: proc(...) -> Compilation_Result ---

	result_release :: proc(result: Compilation_Result) ---
	result_get_length :: proc(result: Compilation_Result) -> size_t ---
	result_get_num_warnings :: proc(result: Compilation_Result) -> size_t ---
	result_get_num_errors :: proc(result: Compilation_Result) -> size_t ---
	result_get_compilation_status :: proc(result: Compilation_Result) -> Compilation_Status ---
	result_get_bytes :: proc(result: Compilation_Result) -> rawptr --- // ^u8 or ^u32 depending on context
	result_get_error_message :: proc(result: Compilation_Result) -> cstring ---
}

// Helper to map gfx_interface.Shader_Stage to shaderc.Shader_Kind
map_gfx_stage_to_shaderc_kind :: proc(stage: gfx_interface.Shader_Stage) -> (Shader_Kind, bool) {
	#partial switch stage {
		case .Vertex:   return .Vertex_Shader, true
		case .Fragment: return .Fragment_Shader, true
		case .Compute:  return .Compute_Shader, true
		// case .Geometry: return .Geometry_Shader, true // If gfx_interface adds Geometry
		// Add other mappings as gfx_interface.Shader_Stage expands
	}
	return Shader_Kind(-1), false // Invalid or unsupported stage
}
