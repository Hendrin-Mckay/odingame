package vulkan

import vk "vendor:vulkan"
import "core:log"
import "core:mem" // Added for mem.Allocator, if used by helpers
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

// --- Memory Helpers ---

// find_memory_type_internal finds a suitable memory type index.
// - physical_device: Handle to the physical device.
// - type_filter: Bitmask where each set bit indicates a memory type index that is supported for the resource.
// - properties: Required memory property flags (e.g., .DEVICE_LOCAL_BIT, .HOST_VISIBLE_BIT).
// Returns the found memory type index and true on success, or 0 and false on failure.
find_memory_type_internal :: proc(
	physical_device: vk.PhysicalDevice, 
	type_filter: u32, 
	properties: vk.MemoryPropertyFlags,
) -> (
	memory_type_index: u32, 
	ok: bool,
) {
	mem_properties: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(physical_device, &mem_properties)

	for i := u32(0); i < mem_properties.memoryTypeCount; i = i + 1 {
		// Check if the i-th bit is set in type_filter (i.e., this memory type is allowed for the buffer/image)
		if (type_filter & (1 << i)) != 0 {
			// Check if this memory type has all the required properties
			if (mem_properties.memoryTypes[i].propertyFlags & properties) == properties {
				log.debugf("Found suitable memory type. Index: %d, Flags: %v", i, mem_properties.memoryTypes[i].propertyFlags)
				return i, true
			}
		}
	}

	log.errorf("Failed to find suitable memory type. Filter: %#b, Required Properties: %v", type_filter, properties)
	// Log available memory types for debugging
	// for i := u32(0); i < mem_properties.memoryTypeCount; i = i + 1 {
	// 	log.debugf("Available Memory Type %d: HeapIndex: %d, Flags: %v", 
	// 		i, mem_properties.memoryTypes[i].heapIndex, mem_properties.memoryTypes[i].propertyFlags)
	// }
	// for i := u32(0); i < mem_properties.memoryHeapCount; i = i + 1 {
	// 	log.debugf("Available Memory Heap %d: Size: %v, Flags: %v",
	// 		i, mem_properties.memoryHeaps[i].size, mem_properties.memoryHeaps[i].flags)
	// }
	return 0, false
}

// vk_create_image_internal creates a Vulkan image and allocates its memory.
// - device_internal: Reference to our internal Vulkan device struct.
// - width, height, depth: Dimensions of the image.
// - format: Vulkan format of the image.
// - tiling: Tiling mode (OPTIMAL or LINEAR).
// - usage: How the image will be used (e.g., SAMPLED_BIT, COLOR_ATTACHMENT_BIT).
// - mem_properties: Required memory properties for the image memory (e.g., DEVICE_LOCAL_BIT).
// Returns the created vk.Image, vk.DeviceMemory, and a Gfx_Error.
// On failure, vk.NULL_HANDLEs and an error code are returned. Resources are cleaned up.
vk_create_image_internal :: proc(
	device_internal: ^vk_types.Vk_Device_Internal, // Use vk_types.Vk_Device_Internal
	width: u32, 
	height: u32, 
	depth: u32, // Typically 1 for 2D images/textures
	format: vk.Format, 
	tiling: vk.ImageTiling, 
	usage: vk.ImageUsageFlags, 
	mem_properties: vk.MemoryPropertyFlags,
	// allocator: mem.Allocator, // Odin allocator, if needed for any host-side allocations by this helper
) -> (
	image: vk.Image, 
	image_memory: vk.DeviceMemory, 
	err: gfx_interface.Gfx_Error,
) {
	logical_device  := device_internal.logical_device
	physical_device := device_internal.physical_device_info.physical_device
	p_vk_allocator: ^vk.AllocationCallbacks = nil // Using nil for Vulkan allocators

	image_create_info := vk.ImageCreateInfo{
		sType = .IMAGE_CREATE_INFO,
		imageType = .TYPE_2D, // Assuming 2D for now, could be parameter
		extent = vk.Extent3D{width = width, height = height, depth = depth},
		mipLevels = 1,    // No mipmapping for now
		arrayLayers = 1,  // Not an array texture
		format = format,
		tiling = tiling,
		initialLayout = .UNDEFINED, // Or .PREINITIALIZED if data is uploaded immediately with linear tiling
		usage = usage,
		sharingMode = .EXCLUSIVE, // No concurrent queue access for now
		samples = .SAMPLE_COUNT_1_BIT, // No multisampling for now
		// flags = 0, // Optional flags (e.g., for sparse images, cube compatible)
	}

	create_res := vk.CreateImage(logical_device, &image_create_info, p_vk_allocator, &image)
	if create_res != .SUCCESS {
		log.errorf("vkCreateImage failed. Result: %v", create_res)
		return vk.NULL_HANDLE, vk.NULL_HANDLE, .Texture_Creation_Failed
	}
	log.debugf("Vulkan image %p created successfully. Dim: %dx%dx%d, Fmt: %v, Usage: %v", image, width, height, depth, format, usage)

	// Get memory requirements for the image
	mem_reqs: vk.MemoryRequirements
	vk.GetImageMemoryRequirements(logical_device, image, &mem_reqs)
	log.debugf("Image %p memory requirements: Size: %v, Alignment: %v, TypeFilter: %#b", image, mem_reqs.size, mem_reqs.alignment, mem_reqs.memoryTypeBits)

	// Find a suitable memory type
	mem_type_idx, ok_mem_type := find_memory_type_internal(physical_device, mem_reqs.memoryTypeBits, mem_properties)
	if !ok_mem_type {
		log.errorf("Failed to find suitable memory type for image %p.", image)
		vk.DestroyImage(logical_device, image, p_vk_allocator) // Cleanup created image
		return vk.NULL_HANDLE, vk.NULL_HANDLE, .Texture_Creation_Failed // Or a more specific memory error
	}

	// Allocate memory
	alloc_info := vk.MemoryAllocateInfo{
		sType = .MEMORY_ALLOCATE_INFO,
		allocationSize = mem_reqs.size,
		memoryTypeIndex = mem_type_idx,
	}
	alloc_res := vk.AllocateMemory(logical_device, &alloc_info, p_vk_allocator, &image_memory)
	if alloc_res != .SUCCESS {
		log.errorf("vkAllocateMemory for image %p failed. Result: %v", image, alloc_res)
		vk.DestroyImage(logical_device, image, p_vk_allocator) // Cleanup created image
		return vk.NULL_HANDLE, vk.NULL_HANDLE, .Texture_Creation_Failed // Or specific memory error
	}
	log.debugf("Device memory %p allocated for image %p. Size: %v, TypeIndex: %d", image_memory, image, mem_reqs.size, mem_type_idx)

	// Bind image to memory
	// The fourth parameter is memoryOffset, which must be a multiple of mem_reqs.alignment.
	// Usually 0 if the memory is dedicated to this image.
	bind_res := vk.BindImageMemory(logical_device, image, image_memory, 0)
	if bind_res != .SUCCESS {
		log.errorf("vkBindImageMemory for image %p with memory %p failed. Result: %v", image, image_memory, bind_res)
		vk.FreeMemory(logical_device, image_memory, p_vk_allocator) // Cleanup allocated memory
		vk.DestroyImage(logical_device, image, p_vk_allocator)    // Cleanup created image
		return vk.NULL_HANDLE, vk.NULL_HANDLE, .Texture_Creation_Failed
	}
	log.debugf("Successfully bound memory %p to image %p.", image_memory, image)

	return image, image_memory, .None
}

// vk_create_image_view_internal creates a Vulkan image view.
// - device_logical: The logical device.
// - image: The Vulkan image for which to create a view.
// - format: The format of the image view (should match the image's format).
// - aspect_flags: Specifies which aspects of the image are included in the view (e.g., .COLOR_BIT, .DEPTH_BIT).
// Returns the created vk.ImageView and a Gfx_Error.
// On failure, vk.NULL_HANDLE and an error code are returned.
vk_create_image_view_internal :: proc(
	device_logical: vk.Device,
	image: vk.Image,
	format: vk.Format,
	aspect_flags: vk.ImageAspectFlags,
	// allocator: mem.Allocator, // Odin allocator, if needed for any host-side allocations by this helper
) -> (
	image_view: vk.ImageView,
	err: gfx_interface.Gfx_Error,
) {
	p_vk_allocator: ^vk.AllocationCallbacks = nil // Using nil for Vulkan allocators

	view_create_info := vk.ImageViewCreateInfo{
		sType = .IMAGE_VIEW_CREATE_INFO,
		image = image,
		viewType = .TYPE_2D, // Assuming 2D views for now
		format = format,
		// components = { // Identity mapping for components (r,g,b,a = r,g,b,a)
		// 	r = .IDENTITY, g = .IDENTITY, b = .IDENTITY, a = .IDENTITY,
		// },
		subresourceRange = vk.ImageSubresourceRange{
			aspectMask = aspect_flags,
			baseMipLevel = 0,
			levelCount = 1,    // No mipmapping for now
			baseArrayLayer = 0,
			layerCount = 1,    // Not an array texture view
		},
	}
	// Default components swizzle (vk.ComponentSwizzle.IDENTITY) is usually fine.
	// If specific swizzling is needed, set components.r, .g, .b, .a.

	create_res := vk.CreateImageView(device_logical, &view_create_info, p_vk_allocator, &image_view)
	if create_res != .SUCCESS {
		log.errorf("vkCreateImageView failed. Result: %v", create_res)
		return vk.NULL_HANDLE, .Texture_Creation_Failed // Or a more specific view creation error
	}
	log.debugf("Vulkan image view %p created successfully for image %p. Format: %v, Aspect: %v", image_view, image, format, aspect_flags)

	return image_view, .None
}

// vk_create_sampler_internal creates a Vulkan sampler with common settings.
// - device_logical: The logical device.
// - physical_device_info: Information about the physical device, including properties and features.
// Returns the created vk.Sampler and a Gfx_Error.
// On failure, vk.NULL_HANDLE and an error code are returned.
vk_create_sampler_internal :: proc(
	device_logical: vk.Device,
	physical_device_info: ^vk_types.Vk_PhysicalDevice_Info, // For features and limits
	// allocator: mem.Allocator, // Odin allocator, if needed for any host-side allocations by this helper
) -> (
	sampler: vk.Sampler,
	err: gfx_interface.Gfx_Error,
) {
	p_vk_allocator: ^vk.AllocationCallbacks = nil

	sampler_create_info := vk.SamplerCreateInfo{
		sType = .SAMPLER_CREATE_INFO,
		magFilter = .LINEAR,
		minFilter = .LINEAR,
		addressModeU = .REPEAT,
		addressModeV = .REPEAT,
		addressModeW = .REPEAT,
		borderColor = .INT_OPAQUE_BLACK, // Border color for CLAMP_TO_BORDER
		unnormalizedCoordinates = vk.FALSE, // Usually false (normalized: 0.0 to 1.0)
		
		// Mipmapping properties (disabled for now)
		mipmapMode = .LINEAR, // Or .NEAREST
		mipLodBias = 0.0,
		minLod = 0.0,
		maxLod = 0.0, // Set to a value like vk.LOD_CLAMP_NONE or number of mips if using mipmapping
		
		// Anisotropy
		anisotropyEnable = vk.FALSE,
		maxAnisotropy = 1.0, // Default if anisotropy is disabled
	}

	// Enable anisotropy if supported and desired
	// The task description implies checking physical_device_info.properties, but features is more direct for enable.
	if physical_device_info.features.samplerAnisotropy {
		sampler_create_info.anisotropyEnable = vk.TRUE
		sampler_create_info.maxAnisotropy = physical_device_info.properties.limits.maxSamplerAnisotropy
		log.debugf("Anisotropic filtering enabled for sampler. Max Anisotropy: %f", sampler_create_info.maxAnisotropy)
	} else {
		log.debug("Anisotropic filtering not supported or not enabled by features for sampler.")
	}

	// Comparison function for percentage-closer filtering (PCF) on shadow maps (disabled for now)
	sampler_create_info.compareEnable = vk.FALSE
	sampler_create_info.compareOp = .ALWAYS // Or other compare op if compareEnable is TRUE

	create_res := vk.CreateSampler(device_logical, &sampler_create_info, p_vk_allocator, &sampler)
	if create_res != .SUCCESS {
		log.errorf("vkCreateSampler failed. Result: %v", create_res)
		return vk.NULL_HANDLE, .Texture_Creation_Failed // Or a more specific sampler creation error
	}
	log.debugf("Vulkan sampler %p created successfully.", sampler)

	return sampler, .None
}

// --- Command Buffer Helpers ---

// vk_begin_single_time_commands_internal allocates and begins a new command buffer
// for short-lived, one-time submit operations (e.g., resource transitions, copies).
// - device_internal: Reference to our internal Vulkan device struct.
// Returns the allocated and begun command buffer, and a Gfx_Error.
// On failure, vk.NULL_HANDLE and an error code are returned.
vk_begin_single_time_commands_internal :: proc(
	device_internal: ^vk_types.Vk_Device_Internal,
) -> (
	cmd_buffer: vk.CommandBuffer, // vk.CommandBuffer is vk.Command_Buffer_Handle
	err: gfx_interface.Gfx_Error,
) {
	logical_device := device_internal.logical_device
	// Assuming device_internal.command_pool is the correct pool for graphics/transfer operations.
	// If a dedicated transfer pool exists and is preferred, that should be used.
	command_pool   := device_internal.command_pool 
	p_vk_allocator: ^vk.AllocationCallbacks = nil

	if command_pool == vk.NULL_HANDLE {
		log.error("vk_begin_single_time_commands_internal: Device command pool is NULL.")
		return vk.NULL_HANDLE, .Invalid_Handle 
	}

	alloc_info := vk.CommandBufferAllocateInfo{
		sType = .COMMAND_BUFFER_ALLOCATE_INFO,
		level = .PRIMARY,
		commandPool = command_pool,
		commandBufferCount = 1,
	}

	alloc_res := vk.AllocateCommandBuffers(logical_device, &alloc_info, &cmd_buffer)
	if alloc_res != .SUCCESS {
		log.errorf("vkAllocateCommandBuffers for single-time command failed. Result: %v", alloc_res)
		return vk.NULL_HANDLE, .Buffer_Creation_Failed // Or a more generic error
	}
	log.debugf("Single-time command buffer %p allocated.", cmd_buffer)

	// Begin command buffer recording
	begin_info := vk.CommandBufferBeginInfo{
		sType = .COMMAND_BUFFER_BEGIN_INFO,
		flags = {.ONE_TIME_SUBMIT_BIT},
	}
	begin_res := vk.BeginCommandBuffer(cmd_buffer, &begin_info)
	if begin_res != .SUCCESS {
		log.errorf("vkBeginCommandBuffer for single-time command buffer %p failed. Result: %v", cmd_buffer, begin_res)
		// Free the allocated command buffer as we failed to begin it.
		vk.FreeCommandBuffers(logical_device, command_pool, 1, &cmd_buffer)
		return vk.NULL_HANDLE, .Device_Operation_Failed 
	}
	log.debugf("Single-time command buffer %p recording begun.", cmd_buffer)

	return cmd_buffer, .None
}

// vk_end_single_time_commands_internal ends, submits, and frees a single-time command buffer.
// - device_internal: Reference to our internal Vulkan device struct.
// - cmd_buffer: The command buffer to end and submit.
// Returns a Gfx_Error if any step fails.
vk_end_single_time_commands_internal :: proc(
	device_internal: ^vk_types.Vk_Device_Internal,
	cmd_buffer: vk.CommandBuffer,
) -> (
	err: gfx_interface.Gfx_Error,
) {
	logical_device := device_internal.logical_device
	graphics_queue := device_internal.graphics_queue
	command_pool   := device_internal.command_pool
	p_vk_allocator: ^vk.AllocationCallbacks = nil

	if cmd_buffer == vk.NULL_HANDLE {
		log.error("vk_end_single_time_commands_internal: Provided command buffer is NULL.")
		return .Invalid_Handle
	}
	if graphics_queue == vk.NULL_HANDLE {
		log.error("vk_end_single_time_commands_internal: Device graphics queue is NULL.")
		return .Invalid_Handle 
	}
	if command_pool == vk.NULL_HANDLE {
		log.error("vk_end_single_time_commands_internal: Device command pool is NULL.")
		return .Invalid_Handle 
	}
	
	// End command buffer recording
	end_res := vk.EndCommandBuffer(cmd_buffer)
	if end_res != .SUCCESS {
		log.errorf("vkEndCommandBuffer for single-time command buffer %p failed. Result: %v", cmd_buffer, end_res)
		// Command buffer is in a bad state, but still try to free it.
		vk.FreeCommandBuffers(logical_device, command_pool, 1, &cmd_buffer)
		return .Device_Operation_Failed
	}
	log.debugf("Single-time command buffer %p recording ended.", cmd_buffer)

	// Submit the command buffer
	submit_info := vk.SubmitInfo{
		sType = .SUBMIT_INFO,
		commandBufferCount = 1,
		pCommandBuffers = &cmd_buffer,
	}
	// Submit to the graphics queue. No semaphores or fences for simple single-time commands.
	// A fence could be used for more fine-grained synchronization if needed.
	submit_res := vk.QueueSubmit(graphics_queue, 1, &submit_info, vk.NULL_HANDLE)
	if submit_res != .SUCCESS {
		log.errorf("vkQueueSubmit for single-time command buffer %p failed. Result: %v", cmd_buffer, submit_res)
		vk.FreeCommandBuffers(logical_device, command_pool, 1, &cmd_buffer)
		return .Device_Operation_Failed
	}
	log.debugf("Single-time command buffer %p submitted to graphics queue %p.", cmd_buffer, graphics_queue)

	// Wait for the queue to become idle (ensures command buffer completes)
	wait_res := vk.QueueWaitIdle(graphics_queue)
	if wait_res != .SUCCESS {
		log.errorf("vkQueueWaitIdle for graphics queue %p after single-time command submission failed. Result: %v", graphics_queue, wait_res)
		// Even if wait fails, the command buffer was submitted. Still try to free it.
		vk.FreeCommandBuffers(logical_device, command_pool, 1, &cmd_buffer)
		return .Device_Operation_Failed // Or a specific timeout/wait error
	}
	log.debugf("Graphics queue %p idle after single-time command.", graphics_queue)

	// Free the command buffer
	vk.FreeCommandBuffers(logical_device, command_pool, 1, &cmd_buffer)
	log.debugf("Single-time command buffer %p freed.", cmd_buffer)

	return .None
}

// vk_copy_buffer_to_image_internal copies data from a buffer to an image.
// - device_internal: Reference to our internal Vulkan device struct.
// - buffer: The source Vulkan buffer.
// - image: The destination Vulkan image.
// - width, height: Dimensions of the image region to copy.
// Assumes image is already in a layout suitable for transfer destination (e.g., .TRANSFER_DST_OPTIMAL).
// Returns a Gfx_Error if any step fails.
vk_copy_buffer_to_image_internal :: proc(
	device_internal: ^vk_types.Vk_Device_Internal,
	buffer: vk.Buffer,
	image: vk.Image,
	width: u32,
	height: u32,
	depth: u32, // Typically 1 for 2D images
) -> (
	err: gfx_interface.Gfx_Error,
) {
	cmd_buffer, begin_err := vk_begin_single_time_commands_internal(device_internal)
	if begin_err != .None {
		log.errorf("vk_copy_buffer_to_image: Failed to begin single-time command buffer. Error: %v", begin_err)
		return begin_err
	}

	region := vk.BufferImageCopy{
		bufferOffset = 0,      // Offset in the buffer
		bufferRowLength = 0,   // Tightly packed (no row padding)
		bufferImageHeight = 0, // Tightly packed (no slice padding)
		imageSubresource = vk.ImageSubresourceLayers{
			aspectMask = {.COLOR_BIT}, // Assuming color data
			mipLevel = 0,
			baseArrayLayer = 0,
			layerCount = 1,
		},
		imageOffset = vk.Offset3D{x = 0, y = 0, z = 0},
		imageExtent = vk.Extent3D{width = width, height = height, depth = depth},
	}

	vk.CmdCopyBufferToImage(
		cmd_buffer,
		buffer,
		image,
		.TRANSFER_DST_OPTIMAL, // Image must be in this layout for vkCmdCopyBufferToImage
		1, // Region count
		&region,
	)
	log.debugf("Buffer %p to Image %p: vk.CmdCopyBufferToImage recorded. Extent: %dx%dx%d", buffer, image, width, height, depth)

	end_err := vk_end_single_time_commands_internal(device_internal, cmd_buffer)
	if end_err != .None {
		log.errorf("vk_copy_buffer_to_image: Failed to end single-time command buffer. Error: %v", end_err)
		return end_err
	}

	log.infof("Buffer %p to Image %p: Copied successfully. Extent: %dx%dx%d", buffer, image, width, height, depth)
	return .None
}

// vk_transition_image_layout_internal transitions an image from an old layout to a new layout.
// - device_internal: Reference to our internal Vulkan device struct.
// - image: The image to transition.
// - format: The format of the image (used to determine aspect mask for depth/stencil).
// - old_layout: The current layout of the image.
// - new_layout: The desired new layout of the image.
// - mip_levels: The number of mip levels in the image (typically 1 if not using mipmapping).
// Returns a Gfx_Error if any step fails.
vk_transition_image_layout_internal :: proc(
	device_internal: ^vk_types.Vk_Device_Internal,
	image: vk.Image,
	format: vk.Format, // Format might be needed for aspect mask with depth/stencil
	old_layout: vk.ImageLayout,
	new_layout: vk.ImageLayout,
	mip_levels: u32, // Number of mip levels to transition
) -> (
	err: gfx_interface.Gfx_Error,
) {
	cmd_buffer, begin_err := vk_begin_single_time_commands_internal(device_internal)
	if begin_err != .None {
		log.errorf("vk_transition_image_layout: Failed to begin single-time command buffer. Error: %v", begin_err)
		return begin_err
	}

	barrier := vk.ImageMemoryBarrier{
		sType = .IMAGE_MEMORY_BARRIER,
		oldLayout = old_layout,
		newLayout = new_layout,
		srcQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED, // Not transferring queue ownership
		dstQueueFamilyIndex = vk.QUEUE_FAMILY_IGNORED,
		image = image,
		subresourceRange = vk.ImageSubresourceRange{
			// aspectMask will be set below
			baseMipLevel = 0,
			levelCount = mip_levels,
			baseArrayLayer = 0,
			layerCount = 1,
		},
		// srcAccessMask and dstAccessMask will be set below
		// srcStage and dstStage will be set below
	}

	// Determine aspectMask based on new_layout or format
	if new_layout == .DEPTH_STENCIL_ATTACHMENT_OPTIMAL {
		barrier.subresourceRange.aspectMask = {.DEPTH_BIT}
		// Check if format has a stencil component
		// This is a simplified check; a robust check would involve inspecting format properties.
		// Example formats that have stencil: .D24_UNORM_S8_UINT, .D32_SFLOAT_S8_UINT
		if format == .D24_UNORM_S8_UINT || format == .D32_SFLOAT_S8_UINT || format == .D16_UNORM_S8_UINT {
			barrier.subresourceRange.aspectMask |= {.STENCIL_BIT}
		}
	} else {
		barrier.subresourceRange.aspectMask = {.COLOR_BIT}
	}

	source_stage: vk.PipelineStageFlags
	destination_stage: vk.PipelineStageFlags

	// Determine access masks and pipeline stages based on layouts
	// This is a critical part and needs to be correct for synchronization.
	// The following are common examples; more specific transitions might need different flags.
	if old_layout == .UNDEFINED && new_layout == .TRANSFER_DST_OPTIMAL {
		barrier.srcAccessMask = {} // Or .HOST_WRITE_BIT if coming from host write
		barrier.dstAccessMask = {.TRANSFER_WRITE_BIT}
		source_stage = {.TOP_OF_PIPE_BIT} // Or .HOST_BIT
		destination_stage = {.TRANSFER_BIT}
	} else if old_layout == .TRANSFER_DST_OPTIMAL && new_layout == .SHADER_READ_ONLY_OPTIMAL {
		barrier.srcAccessMask = {.TRANSFER_WRITE_BIT}
		barrier.dstAccessMask = {.SHADER_READ_BIT}
		source_stage = {.TRANSFER_BIT}
		destination_stage = {.FRAGMENT_SHADER_BIT} // Or .VERTEX_SHADER_BIT if sampled in vertex shader
	} else if old_layout == .UNDEFINED && new_layout == .COLOR_ATTACHMENT_OPTIMAL {
        barrier.srcAccessMask = {}
        barrier.dstAccessMask = {.COLOR_ATTACHMENT_READ_BIT, .COLOR_ATTACHMENT_WRITE_BIT}
        source_stage = {.TOP_OF_PIPE_BIT}
        destination_stage = {.COLOR_ATTACHMENT_OUTPUT_BIT}
    } else if old_layout == .UNDEFINED && new_layout == .DEPTH_STENCIL_ATTACHMENT_OPTIMAL {
		barrier.srcAccessMask = {}
		barrier.dstAccessMask = {.DEPTH_STENCIL_ATTACHMENT_READ_BIT, .DEPTH_STENCIL_ATTACHMENT_WRITE_BIT}
		source_stage = {.TOP_OF_PIPE_BIT}
		destination_stage = {.EARLY_FRAGMENT_TESTS_BIT, .LATE_FRAGMENT_TESTS_BIT}
	}
    // Add more transitions as needed, e.g., to .GENERAL for storage images, or from .SHADER_READ_ONLY_OPTIMAL
	else {
		log.errorf("vk_transition_image_layout: Unsupported layout transition from %v to %v", old_layout, new_layout)
		// Attempt to free the command buffer even if we don't submit.
		vk.FreeCommandBuffers(device_internal.logical_device, device_internal.command_pool, 1, &cmd_buffer)
		return .Not_Implemented 
	}

	vk.CmdPipelineBarrier(
		cmd_buffer,
		source_stage, destination_stage,
		0, // No dependency flags
		0, nil, // No memory barriers
		0, nil, // No buffer memory barriers
		1, &barrier, // One image memory barrier
	)
	log.debugf("Image %p: Pipeline barrier for layout transition %v -> %v recorded.", image, old_layout, new_layout)

	end_err := vk_end_single_time_commands_internal(device_internal, cmd_buffer)
	if end_err != .None {
		log.errorf("vk_transition_image_layout: Failed to end single-time command buffer. Error: %v", end_err)
		// Command buffer is freed by vk_end_single_time_commands_internal on error typically,
		// but if not, it's a leak. The error from end_err is propagated.
		return end_err
	}
	
	log.infof("Image %p: Layout transitioned successfully from %v to %v.", image, old_layout, new_layout)
	return .None
}
