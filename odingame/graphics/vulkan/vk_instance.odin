package vulkan

import vk "vendor:vulkan"
import "core:log"
import "core:os"
import "core:fmt"
import "core:strings"
import "core:mem"
import "../../common" // For common.Engine_Error
// No direct import of vk_types here, but it's part of the same 'vulkan' package.
// vk_helpers is also part of this package.

// vk_create_instance_internal creates a Vulkan instance.
// It handles application info, validation layers, and required extensions.
vk_create_instance_internal :: proc(app_name: string, engine_name: string, allocator: mem.Allocator) -> (^Vk_Instance_Info, common.Engine_Error) {
	
	// --- Application Info ---
	app_info := vk.ApplicationInfo{
		sType = .APPLICATION_INFO,
		pApplicationName = strings.clone_to_cstring(app_name), // Must be C-string
		applicationVersion = vk.MAKE_VERSION(1, 0, 0),
		pEngineName = strings.clone_to_cstring(engine_name),   // Must be C-string
		engineVersion = vk.MAKE_VERSION(1, 0, 0),
		apiVersion = vk.API_VERSION_1_0, // Or higher if needed e.g. 1.1, 1.2, 1.3
	}
	defer delete(app_info.pApplicationName)
	defer delete(app_info.pEngineName)

	// --- Create Info Struct ---
	create_info := vk.InstanceCreateInfo{
		sType = .INSTANCE_CREATE_INFO,
		pApplicationInfo = &app_info,
	}

	// --- Extensions ---
	// Get required extensions (SDL surface, debug utils, etc.)
	// The returned slice from get_required_instance_extensions is allocated by `allocator` passed to it.
	// We must ensure it's eventually freed.
	required_extensions_odin, ok_ext := get_required_instance_extensions(allocator)
	if !ok_ext {
		log.error("Failed to get required Vulkan instance extensions.")
		return nil, common.Engine_Error.Graphics_Initialization_Failed
	}
	defer delete(required_extensions_odin) // Free the slice of Odin strings

	// Convert Odin strings to C-strings for Vulkan
	// This requires careful memory management.
	// Create a temporary array of cstrings.
	enabled_extension_count := u32(len(required_extensions_odin))
	enabled_extension_names_c := make_foreign_array_ptr([dynamic]cstring, int(enabled_extension_count), allocator)
	defer free_foreign_array_ptr(enabled_extension_names_c) // Frees the array of pointers and the cstrings themselves if allocated by helper

	for i, odin_str in required_extensions_odin {
		// clone_to_cstring allocates memory that needs to be freed.
		// The free_foreign_array_ptr should handle this if it's designed to free each cstring.
		// Let's assume it does, or manage manually.
		// For now, assume clone_to_cstring used by get_required_instance_extensions or a similar pattern.
		// The current get_required_instance_extensions clones them, and we defer delete(required_extensions_odin)
		// which should handle the Odin string data. For cstrings for Vulkan:
		enabled_extension_names_c.data[i] = strings.clone_to_cstring(odin_str)
	}
	// Defer freeing each cstring in the array
	defer {
		for i := 0; i < int(enabled_extension_count); i = i + 1 {
			if enabled_extension_names_c.data[i] != nil {
				delete(enabled_extension_names_c.data[i])
			}
		}
	}


	create_info.enabledExtensionCount = enabled_extension_count
	create_info.ppEnabledExtensionNames = enabled_extension_names_c.data
	
	log.info("Requesting Vulkan instance extensions:")
	for i := 0; i < int(enabled_extension_count); i += 1 {
		log.infof("  - %s", string(required_extensions_odin[i]))
	}


	// --- Validation Layers & Debug Messenger ---
	// If validation layers are enabled, set them up.
	// Also set up debug messenger create info to capture messages during instance creation/destruction.
	var debug_create_info vk.DebugUtilsMessengerCreateInfoEXT // Zero-initialize
	
	if ENABLE_VALIDATION_LAYERS {
		if !check_validation_layer_support() {
			log.error("Requested validation layers not available.")
			return nil, common.Engine_Error.Graphics_Initialization_Failed // Or a more specific error like .Validation_Layers_Not_Supported
		}
		// Convert VALIDATION_LAYERS (slice of Odin strings) to array of cstrings
		enabled_layer_count := u32(len(VALIDATION_LAYERS))
		enabled_layer_names_c := make_foreign_array_ptr([dynamic]cstring, int(enabled_layer_count), allocator)
		defer free_foreign_array_ptr(enabled_layer_names_c)
		for i, layer_name_str in VALIDATION_LAYERS {
			enabled_layer_names_c.data[i] = strings.clone_to_cstring(layer_name_str)
		}
		defer { // Defer freeing these cstrings
			for i := 0; i < int(enabled_layer_count); i = i + 1 {
				if enabled_layer_names_c.data[i] != nil {
					delete(enabled_layer_names_c.data[i])
				}
			}
		}

		create_info.enabledLayerCount = enabled_layer_count
		create_info.ppEnabledLayerNames = enabled_layer_names_c.data
		log.info("Enabling Vulkan validation layers:")
		for _, layer_name_cstr in enabled_layer_names_c.data {
			log.infof("  - %s", fmt.ptr_to_string(layer_name_cstr))
		}

		// Populate debug messenger create info to be passed in pNext of InstanceCreateInfo
		populate_debug_messenger_create_info(&debug_create_info)
		create_info.pNext = &debug_create_info // Attach debug messenger info for instance creation
	} else {
		create_info.enabledLayerCount = 0
		create_info.ppEnabledLayerNames = nil
		create_info.pNext = nil
	}

	// --- Create Vulkan Instance ---
	instance_handle: vk.Instance
	// Using nil for Vulkan allocation callbacks for simplicity.
	// Production apps might use custom allocators here.
	p_vk_allocator: ^vk.AllocationCallbacks = nil 
	
	result := vk.CreateInstance(&create_info, p_vk_allocator, &instance_handle)
	if result != .SUCCESS {
		// Convert result to string if possible for better error message
		log.errorf("vkCreateInstance failed. Result: %v (%d)", result, int(result))
		// It's possible the error was related to pNext if debug_utils wasn't enabled but create_info was passed.
		// If debug_utils is an extension, it must be in enabled_extension_names_c.
		return nil, common.Engine_Error.Graphics_Initialization_Failed
	}
	log.info("Vulkan Instance created successfully.")

	// --- Store Instance Info ---
	// Allocate Vk_Instance_Info struct using the passed allocator
	vk_instance_info := new(Vk_Instance_Info, allocator) 
	vk_instance_info.instance = instance_handle
	vk_instance_info.allocator = allocator // Store the allocator
	vk_instance_info.validation_layers_enabled = ENABLE_VALIDATION_LAYERS
	
	// --- Create Debug Messenger (if validation layers enabled) ---
	// This is done after instance creation because vkCreateDebugUtilsMessengerEXT requires a valid instance.
	if ENABLE_VALIDATION_LAYERS {
		// Note: debug_create_info was already populated.
		// We don't need to pass it in pNext for vkCreateDebugUtilsMessengerEXT itself.
		messenger, debug_res := create_debug_utils_messenger(instance_handle, &debug_create_info, p_vk_allocator)
		if debug_res == .SUCCESS {
			vk_instance_info.debug_messenger = messenger
			log.info("Vulkan Debug Messenger created successfully.")
		} else {
			// This is not fatal for the instance itself, but log a warning.
			log.warnf("Failed to create Vulkan Debug Messenger. Result: %v", debug_res)
			// Instance is still valid, so don't return error here.
		}
	}

	return vk_instance_info, .None
}

// vk_destroy_instance_internal destroys the Vulkan instance and related resources.
vk_destroy_instance_internal :: proc(vk_instance_info: ^Vk_Instance_Info) {
	if vk_instance_info == nil {
		return
	}
	p_vk_allocator: ^vk.AllocationCallbacks = nil // Assuming nil was used for creation

	// Destroy Debug Messenger first
	if vk_instance_info.debug_messenger != nil && vk_instance_info.validation_layers_enabled {
		destroy_debug_utils_messenger(vk_instance_info.instance, vk_instance_info.debug_messenger, p_vk_allocator)
		log.info("Vulkan Debug Messenger destroyed.")
		vk_instance_info.debug_messenger = nil
	}

	// Destroy Vulkan Instance
	if vk_instance_info.instance != nil {
		vk.DestroyInstance(vk_instance_info.instance, p_vk_allocator)
		log.info("Vulkan Instance destroyed.")
		vk_instance_info.instance = nil
	}
	
	// Free the Vk_Instance_Info struct itself using its stored allocator
	free(vk_instance_info, vk_instance_info.allocator)
}
