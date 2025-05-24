package vulkan

import vk "vendor:vulkan"
import "core:log"
import "core:mem"
import "../gfx_interface" // For Gfx_Device, Gfx_Shader, Shader_Stage
import "../../common" // For common.Engine_Error

// Vk_Shader_Internal holds the Vulkan-specific shader data.
Vk_Shader_Internal :: struct {
	module:        vk.ShaderModule,
	stage:         vk.ShaderStageFlagBits, // Store the stage for pipeline creation
	device_ref:    ^Vk_Device_Internal,    // Reference to the logical device for destruction
	allocator:     mem.Allocator,        // Allocator used for this struct
}

// Helper to map gfx_interface.Shader_Stage to vk.ShaderStageFlagBits
map_shader_stage_to_vk :: proc(stage: gfx_interface.Shader_Stage) -> (vk.ShaderStageFlagBits, bool) {
	#partial switch stage {
	case .Vertex:
		return .VERTEX_BIT, true
	case .Fragment:
		return .FRAGMENT_BIT, true
	case .Compute:
		return .COMPUTE_BIT, true
	// TODO: Add other stages like Geometry, Tessellation if needed
	}
	log.errorf("Unsupported shader stage: %v", stage)
	return vk.ShaderStageFlagBits(0), false // Invalid stage
}

// vk_create_shader_module creates a Vulkan shader module from SPIR-V bytecode.
// Assumes bytecode is valid SPIR-V.
vk_create_shader_module_internal :: proc(logical_device: vk.Device, bytecode: []u8) -> (vk.ShaderModule, common.Engine_Error) {
	if len(bytecode) == 0 {
		log.error("Shader bytecode is empty.")
		return vk.NULL_HANDLE, common.Engine_Error.Shader_Compilation_Failed // Or a more specific error
	}
	if len(bytecode) % 4 != 0 {
		log.error("Shader bytecode size is not a multiple of 4.")
		return vk.NULL_HANDLE, common.Engine_Error.Shader_Compilation_Failed
	}

	create_info := vk.ShaderModuleCreateInfo{
		sType = .SHADER_MODULE_CREATE_INFO,
		codeSize = uintptr(len(bytecode)),
		// pCode needs to point to an array of u32, so bytecode (slice of u8) needs careful casting.
		// The bytecode is assumed to be correctly aligned for u32 access.
		pCode = (^u32)(rawptr(bytecode.data)),
	}

	p_vk_allocator: ^vk.AllocationCallbacks = nil // Using nil for Vulkan allocation callbacks
	shader_module: vk.ShaderModule

	result := vk.CreateShaderModule(logical_device, &create_info, p_vk_allocator, &shader_module)
	if result != .SUCCESS {
		log.errorf("vkCreateShaderModule failed. Result: %v (%d)", result, int(result))
		// Log more details if possible, e.g., from validation layers if they provide info
		return vk.NULL_HANDLE, common.Engine_Error.Shader_Compilation_Failed
	}

	log.infof("Vulkan Shader Module created successfully: %p", shader_module)
	return shader_module, .None
}

// vk_create_shader_from_bytecode creates a Gfx_Shader from SPIR-V bytecode.
vk_create_shader_from_bytecode_internal :: proc(
	gfx_device: gfx_interface.Gfx_Device,
	bytecode: []u8,
	stage: gfx_interface.Shader_Stage,
) -> (gfx_interface.Gfx_Shader, common.Engine_Error) {
	
	vk_dev_internal, ok_dev := gfx_device.variant.(Vk_Device_Variant)
	if !ok_dev || vk_dev_internal == nil {
		log.error("vk_create_shader_from_bytecode: Invalid Gfx_Device (not Vulkan or nil variant).")
		return gfx_interface.Gfx_Shader{}, common.Engine_Error.Invalid_Handle
	}

	allocator := vk_dev_internal.allocator // Use device's allocator

	vk_stage, ok_stage := map_shader_stage_to_vk(stage)
	if !ok_stage {
		return gfx_interface.Gfx_Shader{}, common.Engine_Error.Shader_Compilation_Failed // Or a more specific error like .Invalid_Stage
	}

	shader_module, err := vk_create_shader_module_internal(vk_dev_internal.logical_device, bytecode)
	if err != .None {
		return gfx_interface.Gfx_Shader{}, err
	}

	// Allocate and populate Vk_Shader_Internal
	vk_shader_internal := new(Vk_Shader_Internal, allocator)
	vk_shader_internal.module = shader_module
	vk_shader_internal.stage = vk_stage
	vk_shader_internal.device_ref = vk_dev_internal
	vk_shader_internal.allocator = allocator
	
	log.infof("Vk_Shader_Internal created for stage %v, module %p", stage, shader_module)

	// Wrap it in Gfx_Shader
	// The Gfx_Shader struct_variant will store a pointer to Vk_Shader_Internal.
	// This requires Gfx_Shader in gfx_interface.odin to have a `vulkan: ^Vk_Shader_Internal` field.
	// We used a placeholder `vulkan: ^struct{}` before. Now we need to make sure it's compatible.
	// For now, this direct assignment will work if the placeholder is ^rawptr or similar.
	// It's better to update gfx_interface.odin properly.
	
	return gfx_interface.Gfx_Shader{variant = vk_shader_internal}, .None
}

// vk_destroy_shader_internal destroys a Vulkan shader module.
vk_destroy_shader_internal :: proc(shader: gfx_interface.Gfx_Shader) -> common.Engine_Error {
	if shader.variant == nil {
		log.error("vk_destroy_shader_internal: Gfx_Shader variant is nil.")
		return common.Engine_Error.Invalid_Handle
	}

	vk_shader_ptr, ok_shader := shader.variant.(^Vk_Shader_Internal)
	if !ok_shader || vk_shader_ptr == nil {
		log.errorf("vk_destroy_shader_internal: Invalid Gfx_Shader variant type (%T) or nil pointer.", shader.variant)
		return common.Engine_Error.Invalid_Handle
	}

	// It's safer to check device_ref before dereferencing vk_shader_ptr if it could be partially initialized.
	// However, if vk_shader_ptr is valid, vk_shader_internal can be obtained.
	vk_shader_internal := vk_shader_ptr^ 

	if vk_shader_internal.device_ref == nil {
		log.errorf("vk_destroy_shader_internal: Shader (module %p) has nil device_ref. Cannot destroy.", vk_shader_internal.module)
		// Freeing vk_shader_ptr might still be attempted if it's considered a memory leak otherwise,
		// but the primary issue is that the Vulkan resource cannot be cleaned up.
		// Depending on creation guarantees, a nil device_ref might imply vk_shader_ptr itself is from a bad state.
		// For now, we signal that the operation is invalid as it cannot proceed.
		return common.Engine_Error.Invalid_Operation // Or Invalid_Handle if device_ref is essential for identification
	}
	
	if vk_shader_internal.module != vk.NULL_HANDLE {
		log.infof("Destroying Vulkan Shader Module: %p (Stage: %v) on device %p", 
			vk_shader_internal.module, vk_shader_internal.stage, vk_shader_internal.device_ref.logical_device)
		p_vk_allocator: ^vk.AllocationCallbacks = nil
		vk.DestroyShaderModule(vk_shader_internal.device_ref.logical_device, vk_shader_internal.module, p_vk_allocator)
	} else {
		// This case might be acceptable if a shader object could exist without a module (e.g., failed creation earlier but struct was still made).
		log.warnf("vk_destroy_shader_internal: Shader module is vk.NULL_HANDLE. Nothing to destroy on GPU. Device_ref: %p", vk_shader_internal.device_ref)
	}
	
	// Free the Vk_Shader_Internal struct itself using its stored allocator
	log.infof("Freeing Vk_Shader_Internal struct (allocator: %p) for module %p", vk_shader_internal.allocator, vk_shader_internal.module)
	free(vk_shader_ptr, vk_shader_internal.allocator)
	// log.info("Vk_Shader_Internal struct freed.") // Covered by log.infof above

	return .None
}

// vk_create_shader_from_source_internal (GLSL to SPIR-V using shaderc)
vk_create_shader_from_source_internal :: proc(
    gfx_device: gfx_interface.Gfx_Device,
    glsl_source: string,
    shader_stage_gfx: gfx_interface.Shader_Stage,
) -> (gfx_interface.Gfx_Shader, common.Engine_Error) {

	vk_dev_internal, ok_dev := gfx_device.variant.(Vk_Device_Variant)
	if !ok_dev || vk_dev_internal == nil {
		log.error("vk_create_shader_from_source: Invalid Gfx_Device.")
		return gfx_interface.Gfx_Shader{}, common.Engine_Error.Invalid_Handle
	}
	allocator := vk_dev_internal.allocator

	// 1. Initialize Shaderc Compiler and Options
	compiler := shaderc.compiler_initialize()
	if compiler == nil {
		log.error("Failed to initialize shaderc compiler.")
		return gfx_interface.Gfx_Shader{}, common.Engine_Error.Shader_Compilation_Failed
	}
	defer shaderc.compiler_release(compiler)

	options := shaderc.compile_options_initialize()
	if options == nil {
		log.error("Failed to initialize shaderc compile options.")
		return gfx_interface.Gfx_Shader{}, common.Engine_Error.Shader_Compilation_Failed
	}
	defer shaderc.compile_options_release(options)

	// Set source language to GLSL
	shaderc.compile_options_set_source_language(options, .GLSL)
	// Optionally, set optimization level, e.g., for performance
	// shaderc.compile_options_set_optimization_level(options, .Performance)
    // For debugging, generate debug info
    shaderc.compile_options_set_generate_debug_info(options)


	// 2. Map gfx_interface.Shader_Stage to shaderc.Shader_Kind
	shader_kind_sc, ok_kind := map_gfx_stage_to_shaderc_kind(shader_stage_gfx)
	if !ok_kind {
		log.errorf("Unsupported shader stage for shaderc compilation: %v", shader_stage_gfx)
		return gfx_interface.Gfx_Shader{}, common.Engine_Error.Shader_Compilation_Failed
	}

	// 3. Compile GLSL to SPIR-V
	// Convert Odin string to C-string for shaderc
	source_cstring := strings.clone_to_cstring(glsl_source, context.temp_allocator) // Use temp allocator
	defer delete(source_cstring, context.temp_allocator)
	
	// Define input file name (can be a placeholder) and entry point
	// Shaderc uses these for error messages and some shader conventions.
	// TODO: make input_file_name more meaningful if possible, e.g. from a loaded file path
	input_file_name_cstr := "shader.glsl" 
	entry_point_name_cstr := "main" // Standard entry point for GLSL shaders

	log.infof("Compiling GLSL shader (stage: %v, input_name: %s, entry_point: %s) using shaderc...", 
		shader_stage_gfx, input_file_name_cstr, entry_point_name_cstr)

	result := shaderc.compile_into_spv(
		compiler,
		source_cstring,
		size_t(len(glsl_source)), // shaderc expects length of original string, not necessarily null-terminated cstring length
		shader_kind_sc,
		input_file_name_cstr,
		entry_point_name_cstr,
		options,
	)
	defer shaderc.result_release(result)

	// 4. Check Compilation Status
	status := shaderc.result_get_compilation_status(result)
	num_errors := shaderc.result_get_num_errors(result)
	num_warnings := shaderc.result_get_num_warnings(result)

	if num_warnings > 0 {
		log.warnf("Shaderc compilation generated %d warnings:", num_warnings)
		warning_msg_cstr := shaderc.result_get_error_message(result) // Errors and warnings are often in the same message buffer
		if warning_msg_cstr != nil {
			log.warn(string(warning_msg_cstr)) // Convert cstring to Odin string for logging
		}
	}

	if status != .Success || num_errors > 0 {
		log.errorf("Shaderc compilation failed with status %v and %d errors:", status, num_errors)
		error_msg_cstr := shaderc.result_get_error_message(result)
		if error_msg_cstr != nil {
			log.error(string(error_msg_cstr))
		}
		return gfx_interface.Gfx_Shader{}, common.Engine_Error.Shader_Compilation_Failed
	}

	log.info("Shaderc compilation successful.")

	// 5. Extract SPIR-V Bytecode
	bytecode_len := shaderc.result_get_length(result)
	bytecode_ptr := shaderc.result_get_bytes(result) // rawptr to const char* (effectively const u8*)

	if bytecode_ptr == nil || bytecode_len == 0 {
		log.error("Shaderc compilation succeeded but returned no bytecode.")
		return gfx_interface.Gfx_Shader{}, common.Engine_Error.Shader_Compilation_Failed
	}

	// Create an Odin slice from the raw SPIR-V bytecode.
	// This requires copying the data, as the memory from shaderc_result_get_bytes
	// is only valid until shaderc_result_release is called.
	spirv_bytecode_slice := make([]u8, int(bytecode_len), allocator) // Use device's allocator
	mem.copy(spirv_bytecode_slice, (^u8)(bytecode_ptr), int(bytecode_len))
	// Defer deletion if we don't pass ownership to vk_create_shader_from_bytecode_internal,
	// but that function will use it to create a module, so the copy is good.

	log.infof("Successfully compiled GLSL to SPIR-V bytecode (size: %d bytes).", bytecode_len)

	// 6. Call vk_create_shader_from_bytecode_internal with the new bytecode
	// The `spirv_bytecode_slice` is now owned by this scope, but will be consumed by the next call.
	// If `vk_create_shader_from_bytecode_internal` makes its own copy or the shader module creation consumes it,
	// then we might need to `defer delete(spirv_bytecode_slice)` if that call fails.
	// However, our `vk_create_shader_module_internal` uses the slice directly without copying it again.
	// The `Vk_Shader_Internal` doesn't store the bytecode slice itself, only the module.
	// So, the `spirv_bytecode_slice` can be temporary for the call to `vk_create_shader_module_internal`.
	// Let's use a temporary allocator for it for clarity, or ensure its lifetime is managed.
	// For simplicity, if `vk_create_shader_from_bytecode_internal` doesn't take ownership of the slice memory,
	// we should use a temporary allocation for `spirv_bytecode_slice` or ensure it's deleted.
	// The current `vk_create_shader_from_bytecode_internal` does not store the slice.
	// `vk_create_shader_module_internal` uses it.
	// Let's make a copy that will be passed and can be freed after module creation if needed.
	// For now, assume `vk_create_shader_from_bytecode_internal` handles it.
	// The current approach with `allocator` for `spirv_bytecode_slice` means it's heap-allocated.
	// If the call to `vk_create_shader_from_bytecode_internal` is successful, the data has been used.
	// If it fails, the slice should be deleted.
	
	gfx_shader, creation_err := vk_create_shader_from_bytecode_internal(gfx_device, spirv_bytecode_slice, shader_stage_gfx)
	if creation_err != .None {
		delete(spirv_bytecode_slice) // Clean up our copy if module creation failed
		log.errorf("Failed to create shader module from shaderc-compiled SPIR-V: %v", creation_err)
		return gfx_interface.Gfx_Shader{}, creation_err
	}
	
	// If successful, the bytecode has been consumed by vkCreateShaderModule.
	// The slice `spirv_bytecode_slice` can be deleted as its data is now part of the Vulkan module.
	// This is important if `allocator` is not a frame/temporary allocator.
	delete(spirv_bytecode_slice) 
	
	log.info("Successfully created Gfx_Shader from GLSL source via shaderc.")
	return gfx_shader, .None
}
