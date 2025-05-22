package vulkan

import vk "vendor:vulkan"
import "core:log"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:slice"

// --- Validation Layers ---
// Define the validation layers to request.
// This can be controlled by a global flag or build profile later.
ENABLE_VALIDATION_LAYERS :: true // Set to false for release builds if desired

// Standard Khronos validation layer
VALIDATION_LAYERS :: []string{
	"VK_LAYER_KHRONOS_validation",
}

// check_validation_layer_support checks if all requested validation layers are available.
check_validation_layer_support :: proc() -> bool {
	if !ENABLE_VALIDATION_LAYERS {
		return true // Validation layers are not requested
	}

	available_layer_count: u32
	vk.EnumerateInstanceLayerProperties(&available_layer_count, nil)
	available_layers := make([]vk.LayerProperties, available_layer_count)
	defer delete(available_layers)
	vk.EnumerateInstanceLayerProperties(&available_layer_count, available_layers[:])

	log.infof("Available Vulkan instance layers (%d):", available_layer_count)
	for layer_prop in available_layers {
		layer_name := string(layer_prop.layerName[:]) // Convert [N]u8 to string
		log.infof("  - %s (spec: %v.%v.%v, impl: %v)", 
			layer_name, 
			vk.VERSION_MAJOR(layer_prop.specVersion), vk.VERSION_MINOR(layer_prop.specVersion), vk.VERSION_PATCH(layer_prop.specVersion),
			layer_prop.implementationVersion)
	}
	
	missing_layers_count := 0
	for requested_layer_name_str in VALIDATION_LAYERS {
		layer_found := false
		for _, layer_prop in available_layers {
			// vk.LayerProperties.layerName is a fixed-size array of u8.
			// Need to convert it to a string carefully, considering null termination.
			available_layer_name_str := vk_fixed_string_to_odin_string(layer_prop.layerName[:])
			if requested_layer_name_str == available_layer_name_str {
				layer_found = true
				break
			}
		}
		if !layer_found {
			log.errorf("Requested validation layer not found: %s", requested_layer_name_str)
			missing_layers_count += 1
		}
	}
	if missing_layers_count > 0 {
		log.errorf("%d requested validation layers are missing.", missing_layers_count)
	}

	return missing_layers_count == 0
}

// vk_fixed_string_to_odin_string converts a Vulkan fixed-size u8 array (like layerName or extensionName)
// to an Odin string, stopping at the first null terminator.
vk_fixed_string_to_odin_string :: proc(fixed_arr: []u8) -> string {
	null_idx := -1
	for i in 0..<len(fixed_arr) {
		if fixed_arr[i] == 0 {
			null_idx = i
			break
		}
	}
	if null_idx == -1 { // No null terminator found, use the whole array
		return string(fixed_arr)
	}
	return string(fixed_arr[:null_idx])
}


// --- Debug Messenger ---

// vk_debug_callback is the function signature for Vulkan debug messages.
vk_debug_callback :: proc "system" (
	messageSeverity: vk.DebugUtilsMessageSeverityFlag_BitsEXT,
	messageType:     vk.DebugUtilsMessageTypeFlagsEXT,
	pCallbackData:   ^vk.DebugUtilsMessengerCallbackDataEXT,
	pUserData:       rawptr,
) -> vk.Bool32 {

	message_level_str: string
	#partial switch messageSeverity {
	case .VERBOSE_BIT_EXT: message_level_str = "VERBOSE"
	case .INFO_BIT_EXT:    message_level_str = "INFO"
	case .WARNING_BIT_EXT: message_level_str = "WARNING"
	case .ERROR_BIT_EXT:   message_level_str = "ERROR"
	case:                  message_level_str = "UNKNOWN_SEVERITY"
	}

	message_type_str: string
	#partial switch messageType {
	case .GENERAL_BIT_EXT:       message_type_str = "GENERAL"
	case .VALIDATION_BIT_EXT:    message_type_str = "VALIDATION"
	case .PERFORMANCE_BIT_EXT:   message_type_str = "PERFORMANCE"
	// case .DEVICE_ADDRESS_BINDING_BIT_EXT: message_type_str = "DEVICE_ADDRESS_BINDING"; // If using this specific flag
	case:                        message_type_str = "UNKNOWN_TYPE"
	}
	
	// pCallbackData.pMessage is a cstring.
	// Need to ensure it's properly converted to Odin string if used with Odin print functions.
	// For logging, direct cstring might be okay with some loggers.
	// Using fmt.ptr_to_string for safety if the logger doesn't handle cstrings well.
	message_str := fmt.ptr_to_string(pCallbackData.pMessage)

	log.infof("VK [%s][%s]: %s (ID: %s, Num: %d)", 
		message_level_str, 
		message_type_str, 
		message_str,
		pCallbackData.pMessageIdName, // Also a cstring
		pCallbackData.messageIdNumber,
	)
	
	// Optional: Break on severe errors when debugging
	// if messageSeverity >= .ERROR_BIT_EXT {
	//    #asm "int3" // Breakpoint
	// }

	return vk.FALSE // Must return vk.FALSE
}

// populate_debug_messenger_create_info fills a VkDebugUtilsMessengerCreateInfoEXT struct.
populate_debug_messenger_create_info :: proc(create_info: ^vk.DebugUtilsMessengerCreateInfoEXT) {
	create_info^ = vk.DebugUtilsMessengerCreateInfoEXT{
		sType = .DEBUG_UTILS_MESSENGER_CREATE_INFO_EXT,
		messageSeverity = vk.DebugUtilsMessageSeverityFlag_BitsEXT.VERBOSE_BIT_EXT |
		                  vk.DebugUtilsMessageSeverityFlag_BitsEXT.INFO_BIT_EXT | // Be verbose for now
		                  vk.DebugUtilsMessageSeverityFlag_BitsEXT.WARNING_BIT_EXT |
		                  vk.DebugUtilsMessageSeverityFlag_BitsEXT.ERROR_BIT_EXT,
		messageType = vk.DebugUtilsMessageTypeFlagsEXT.GENERAL_BIT_EXT |
		              vk.DebugUtilsMessageTypeFlagsEXT.VALIDATION_BIT_EXT |
		              vk.DebugUtilsMessageTypeFlagsEXT.PERFORMANCE_BIT_EXT,
		pfnUserCallback = vk_debug_callback,
		pUserData = nil, // Optional user data
	}
}

// Helper to create a debug utils messenger.
// Requires the vkCreateDebugUtilsMessengerEXT function to be loaded.
create_debug_utils_messenger :: proc(
	instance: vk.Instance, 
	create_info: ^vk.DebugUtilsMessengerCreateInfoEXT, 
	p_allocator: ^vk.AllocationCallbacks, // Can be nil
) -> (vk.DebugUtilsMessengerEXT, vk.Result) {
	
	messenger: vk.DebugUtilsMessengerEXT
	
	// Get the function pointer for vkCreateDebugUtilsMessengerEXT
	pfnCreateDebugUtilsMessengerEXT := cast(vk.PFN_vkCreateDebugUtilsMessengerEXT)vk.GetInstanceProcAddr(instance, "vkCreateDebugUtilsMessengerEXT")
	
	if pfnCreateDebugUtilsMessengerEXT != nil {
		return messenger, pfnCreateDebugUtilsMessengerEXT(instance, create_info, p_allocator, &messenger)
	} else {
		log.error("vkCreateDebugUtilsMessengerEXT function not found. Is VK_EXT_debug_utils enabled?")
		return messenger, .ERROR_EXTENSION_NOT_PRESENT
	}
}

// Helper to destroy a debug utils messenger.
// Requires the vkDestroyDebugUtilsMessengerEXT function to be loaded.
destroy_debug_utils_messenger :: proc(
	instance: vk.Instance, 
	messenger: vk.DebugUtilsMessengerEXT, 
	p_allocator: ^vk.AllocationCallbacks, // Can be nil
) {
	pfnDestroyDebugUtilsMessengerEXT := cast(vk.PFN_vkDestroyDebugUtilsMessengerEXT)vk.GetInstanceProcAddr(instance, "vkDestroyDebugUtilsMessengerEXT")
	if pfnDestroyDebugUtilsMessengerEXT != nil {
		pfnDestroyDebugUtilsMessengerEXT(instance, messenger, p_allocator)
	} else {
		log.error("vkDestroyDebugUtilsMessengerEXT function not found.")
	}
}

// --- Extension Helpers ---

// get_required_instance_extensions returns a list of required Vulkan instance extensions.
// This typically includes surface extensions and debug utils if validation is enabled.
// Needs SDL for window surface extensions.
get_required_instance_extensions :: proc(allocator: mem.Allocator) -> ([]string, bool) {
	// SDL provides a function to get necessary Vulkan instance extensions for surface creation.
	// sdl.Vulkan_GetInstanceExtensions returns a slice of cstrings. We need to convert them.
	
	// First, get the count of extensions required by SDL
	sdl_ext_count: u32
	if !sdl.Vulkan_GetInstanceExtensions(nil, &sdl_ext_count, nil) {
		log.errorf("SDL_Vulkan_GetInstanceExtensions failed to get count: %s", sdl.GetError())
		return nil, false
	}

	if sdl_ext_count == 0 {
		log.warn("SDL_Vulkan_GetInstanceExtensions reported 0 required extensions.")
		// This might be okay if no surface interaction is planned, but usually not for a graphics app.
	}

	// Allocate memory for the cstring pointers (char**)
	// Each element is a cstring (rawptr)
	sdl_extensions_cstrs := make_foreign_array_ptr([dynamic]cstring, int(sdl_ext_count), allocator)
	defer free_foreign_array_ptr(sdl_extensions_cstrs)
	
	if !sdl.Vulkan_GetInstanceExtensions(nil, &sdl_ext_count, sdl_extensions_cstrs.data) {
		log.errorf("SDL_Vulkan_GetInstanceExtensions failed to get extensions: %s", sdl.GetError())
		return nil, false
	}
	
	// Convert cstrings to Odin strings
	// Using a dynamic array for flexibility, then can convert to slice.
	odin_extensions_dyn := make([dynamic]string, 0, int(sdl_ext_count) + (ENABLE_VALIDATION_LAYERS ? 1 : 0))
	defer delete(odin_extensions_dyn) // Frees the dynamic array's buffer

	log.infof("SDL requires %d Vulkan instance extensions:", sdl_ext_count)
	for i := 0; i < int(sdl_ext_count); i = i + 1 {
		// sdl_extensions_cstrs[i] is a cstring
		if sdl_extensions_cstrs.data[i] != nil {
			ext_name := strings.clone_from_cstring(sdl_extensions_cstrs.data[i])
			append(&odin_extensions_dyn, ext_name) // Clone, as SDL owns the original cstring memory
			log.infof("  - %s", ext_name)
		} else {
			log.warn("SDL_Vulkan_GetInstanceExtensions returned a nil cstring in its list.")
		}
	}
	
	// Add VK_EXT_debug_utils if validation layers are enabled
	if ENABLE_VALIDATION_LAYERS {
		append(&odin_extensions_dyn, vk.EXT_DEBUG_UTILS_EXTENSION_NAME) // This is already a string "VK_EXT_debug_utils"
		log.info("  - VK_EXT_debug_utils (for validation)")
	}

	// Add other necessary extensions, e.g., for portability if on macOS/iOS (VK_KHR_portability_enumeration)
	// This depends on the target platforms and Vulkan SDK version.
	// For example, MoltenVK (Vulkan on Metal for macOS/iOS) might need this.
	// #if OS == .Darwin || OS == .iOS
	// append(&odin_extensions_dyn, "VK_KHR_portability_enumeration") 
	// log.info("  - VK_KHR_portability_enumeration (for macOS/iOS portability)")
	// #endif

	// Convert dynamic array to a slice for return. The slice will be valid as long as odin_extensions_dyn is.
	// To make it independent, we need to clone the dynamic array's content to a new slice.
	final_extensions_slice := slice.clone(odin_extensions_dyn[:], allocator)
	
	return final_extensions_slice, true
}


// --- General Vulkan Result Checking ---
// vk_check prints an error message if res is not vk.SUCCESS.
// Returns true if success, false otherwise.
vk_check :: proc(res: vk.Result, context_msg: string = "") -> bool {
	if res == .SUCCESS {
		return true
	}
	// Convert vk.Result enum to string if possible, or just print its integer value.
	// Odin's vk bindings might provide a way to stringify vk.Result.
	// For now, just log the integer value.
	// A more robust solution would map vk.Result values to human-readable strings.
	log.errorf("Vulkan Error: %s. Result code: %v (%d)", context_msg, res, int(res))
	return false
}
