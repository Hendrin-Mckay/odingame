package vulkan

import vk "vendor:vulkan"
import sdl "vendor:sdl2" // For surface creation during physical device suitability check
import "core:log"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:slice"
import "../gfx_interface" // For Gfx_Device, Gfx_Error

// --- Device Specific Constants ---
REQUIRED_DEVICE_EXTENSIONS :: []string{
	vk.KHR_SWAPCHAIN_EXTENSION_NAME, // String "VK_KHR_swapchain"
	// Example for macOS portability if MoltenVK is used and SDK requires it:
	// #if OS == .Darwin
	// "VK_KHR_portability_subset", 
	// #endif
}


// --- Physical Device Selection ---

// find_queue_families finds suitable queue families on a given physical device for graphics and presentation.
find_queue_families :: proc(physical_device: vk.PhysicalDevice, surface: vk.SurfaceKHR) -> Queue_Family_Indices {
	indices: Queue_Family_Indices // Initializes with nil Maybe(u32)

	queue_family_count: u32
	vk.GetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, nil)
	if queue_family_count == 0 {
		log.warnf("Physical device %p has no queue families.", physical_device)
		return indices
	}
	queue_families_props := make([]vk.QueueFamilyProperties, queue_family_count)
	defer delete(queue_families_props)
	vk.GetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, queue_families_props[:])

	log.debugf("Found %d queue families on physical device %p:", queue_family_count, physical_device)
	for i, props in queue_families_props {
		log.debugf("  Family %d: Count=%d, Flags=%#x", i, props.queueCount, props.queueFlags)
		if props.queueFlags & vk.QUEUE_GRAPHICS_BIT != 0 {
			indices.graphics_family = Maybe(u32){u32(i), true}
			log.debugf("    -> Found suitable graphics family: %d", i)
		}

		// Check for presentation support to the given surface
		present_support: vk.Bool32
		// pAllocator for vk.GetPhysicalDeviceSurfaceSupportKHR is always nil
		vk.GetPhysicalDeviceSurfaceSupportKHR(physical_device, u32(i), surface, &present_support)
		if present_support == vk.TRUE {
			indices.present_family = Maybe(u32){u32(i), true}
			log.debugf("    -> Found suitable present family: %d (for surface %p)", i, surface)
		}

		if is_complete(indices) {
			break // Found all necessary queue families
		}
	}
	return indices
}

// check_device_extension_support checks if a physical device supports all required device extensions.
check_device_extension_support :: proc(physical_device: vk.PhysicalDevice, allocator: mem.Allocator) -> bool {
	available_ext_count: u32
	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &available_ext_count, nil)
	available_extensions := make([]vk.ExtensionProperties, available_ext_count, allocator)
	defer delete(available_extensions) // Ensure slice data is freed if make used allocator
	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &available_ext_count, available_extensions[:])
	
	log.debugf("Physical device %p supports %d extensions:", physical_device, available_ext_count)
	// for _, ext_prop in available_extensions {
	// 	log.debugf("  - %s", vk_fixed_string_to_odin_string(ext_prop.extensionName[:]))
	// }

	missing_count := 0
	for _, req_ext_name_str in REQUIRED_DEVICE_EXTENSIONS {
		found := false
		for _, ext_prop in available_extensions {
			if req_ext_name_str == vk_fixed_string_to_odin_string(ext_prop.extensionName[:]) {
				found = true
				break
			}
		}
		if !found {
			log.warnf("Physical device %p MISSING required extension: %s", physical_device, req_ext_name_str)
			missing_count += 1
		}
	}
	return missing_count == 0
}

// query_swapchain_support queries swapchain support details for a device and surface.
query_swapchain_support :: proc(physical_device: vk.PhysicalDevice, surface: vk.SurfaceKHR, allocator: mem.Allocator) -> (Swapchain_Support_Details, bool) {
	details: Swapchain_Support_Details
	
	// Capabilities
	res_caps := vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &details.capabilities)
	if res_caps != .SUCCESS {
		log.errorf("Failed to get surface capabilities for physical device %p, surface %p. Error: %v", physical_device, surface, res_caps)
		return details, false
	}

	// Formats
	format_count: u32
	vk.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, nil)
	if format_count > 0 {
		// details.formats = make([]vk.SurfaceFormatKHR, format_count, allocator)
		// defer delete(details.formats) // This would be problematic as details is returned
		// Instead, caller of query_swapchain_support that uses the details needs to manage this memory,
		// or we allocate with context.allocator if details are short-lived for suitability check.
		// For now, let's use context.allocator for this check, assuming it's temporary.
		// A better way: pass allocator or return dynamic array.
		formats_slice := make([]vk.SurfaceFormatKHR, format_count, context.allocator)
		defer delete(formats_slice) // if this function fails before returning details with a clone
		vk.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, formats_slice[:])
		details.formats = slice.clone(formats_slice[:], allocator) // Clone to the device's allocator for longer life
	} else {
		log.warnf("No surface formats found for physical device %p, surface %p.", physical_device, surface)
		return details, false // Typically at least one format should be available
	}

	// Present Modes
	present_mode_count: u32
	vk.GetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, nil)
	if present_mode_count > 0 {
		modes_slice := make([]vk.PresentModeKHR, present_mode_count, context.allocator)
		defer delete(modes_slice)
		vk.GetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, modes_slice[:])
		details.present_modes = slice.clone(modes_slice[:], allocator)
	} else {
		log.warnf("No surface present modes found for physical device %p, surface %p.", physical_device, surface)
		return details, false // Typically at least one present mode should be available (FIFO)
	}
	
	return details, true
}


// is_device_suitable checks if a physical device is suitable for the application's needs.
// This requires a temporary surface to check presentation capabilities.
is_device_suitable :: proc(physical_device: vk.PhysicalDevice, temp_surface: vk.SurfaceKHR, instance_allocator: mem.Allocator) -> (bool, Queue_Family_Indices) {
	// 1. Get basic properties and features
	// vk.GetPhysicalDeviceProperties(physical_device, &properties)
	// vk.GetPhysicalDeviceFeatures(physical_device, &features)
	// log.infof("Checking suitability for Physical Device: %s (ID: %v, Type: %v)", 
	// 	vk_fixed_string_to_odin_string(properties.deviceName[:]), properties.deviceID, properties.deviceType)

	// 2. Check for required queue families (graphics and present)
	indices := find_queue_families(physical_device, temp_surface)
	if !is_complete(indices) {
		log.debugf("Device %p: Incomplete queue families (Graphics: %v, Present: %v).", physical_device, indices.graphics_family, indices.present_family)
		return false, indices
	}

	// 3. Check for required device extensions (e.g., swapchain)
	if !check_device_extension_support(physical_device, instance_allocator) {
		log.debugf("Device %p: Does not support all required device extensions.", physical_device)
		return false, indices
	}
	
	// 4. Check for adequate swapchain support (at least one format and one present mode)
	// The allocator here is for the slices within Swapchain_Support_Details if they are stored long-term.
	// For a suitability check, they might be temporary.
	swapchain_support, ok_sc_support := query_swapchain_support(physical_device, temp_surface, instance_allocator)
	if !ok_sc_support || len(swapchain_support.formats) == 0 || len(swapchain_support.present_modes) == 0 {
		log.debugf("Device %p: Inadequate swapchain support (Formats: %d, Present Modes: %d).", 
			physical_device, len(swapchain_support.formats) if ok_sc_support else 0, len(swapchain_support.present_modes) if ok_sc_support else 0)
		// Clean up slices in swapchain_support if they were allocated
		delete(swapchain_support.formats)    // Safe even if nil or empty
		delete(swapchain_support.present_modes) // Safe even if nil or empty
		return false, indices
	}
	// Clean up slices as they are cloned by query_swapchain_support if returned successfully,
	// but here we only needed to check if they are non-empty.
	// If query_swapchain_support allocated them with `instance_allocator` and this function returns false,
	// they need to be freed. This is tricky. query_swapchain_support now clones to the passed allocator.
	// So, if we don't store `swapchain_support` itself, its internal slices need cleanup if this function returns false.
	// Let's assume for now that if `ok_sc_support` is true, the details are valid, and if we return false later,
	// the caller (select_physical_device) won't store these details.
	// If we return true, select_physical_device will store them.
	// This design means `Swapchain_Support_Details` should be stored by the caller if suitability is true.
	// For now, we don't need to free them here as they are only checked for emptiness.
	// The `query_swapchain_support` clones them to the `instance_allocator`.
	// This implies `Vk_PhysicalDevice_Info` might store them.
	// Let's simplify: query_swapchain_support will use context.allocator for its internal make,
	// and then clone to the passed allocator. The deferred deletes in query_swapchain_support handle its temps.
	// The returned details.formats/present_modes are on `instance_allocator`.
	// If this device is *not* selected, these slices need to be freed by the caller of is_device_suitable.
	// This is getting complicated.
	// Simpler: is_device_suitable will free them if it returns false.
	if !(len(swapchain_support.formats) > 0 && len(swapchain_support.present_modes) > 0) {
		delete(swapchain_support.formats)
		delete(swapchain_support.present_modes)
		return false, indices
	}
	// If suitable, the caller (select_physical_device_internal) will store these details.
	// So, don't delete them here if returning true.

	// 5. Check for desired features (e.g., samplerAnisotropy)
	// features_to_check: vk.PhysicalDeviceFeatures
	// vk.GetPhysicalDeviceFeatures(physical_device, &features_to_check)
	// if features_to_check.samplerAnisotropy == vk.FALSE { return false, indices }
	
	log.infof("Device %p is suitable.", physical_device)
	return true, indices
}


vk_select_physical_device_internal :: proc(vk_instance_info: ^Vk_Instance_Info, temp_surface: vk.SurfaceKHR) -> (^Vk_PhysicalDevice_Info, gfx_interface.Gfx_Error) {
	instance := vk_instance_info.instance
	allocator := vk_instance_info.allocator

	device_count: u32
	vk.EnumeratePhysicalDevices(instance, &device_count, nil)
	if device_count == 0 {
		log.error("Failed to find GPUs with Vulkan support.")
		return nil, .Device_Creation_Failed
	}

	physical_devices_handles := make([]vk.PhysicalDevice, device_count)
	defer delete(physical_devices_handles)
	vk.EnumeratePhysicalDevices(instance, &device_count, physical_devices_handles[:])

	log.infof("Found %d physical devices:", device_count)
	selected_pd_info: ^Vk_PhysicalDevice_Info = nil

	for pd_handle in physical_devices_handles {
		props: vk.PhysicalDeviceProperties
		vk.GetPhysicalDeviceProperties(pd_handle, &props)
		device_name := vk_fixed_string_to_odin_string(props.deviceName[:])
		log.infof("  Device: %s (ID: %v, Type: %v)", device_name, props.deviceID, props.deviceType)

		// The allocator passed to is_device_suitable is for temporary allocations within that check,
		// or for the swapchain_support_details if that device is chosen.
		suitable, queues := is_device_suitable(pd_handle, temp_surface, allocator)
		if suitable {
			// Store this device's info
			pd_info := new(Vk_PhysicalDevice_Info, allocator)
			pd_info.physical_device = pd_handle
			vk.GetPhysicalDeviceProperties(pd_handle, &pd_info.properties)
			vk.GetPhysicalDeviceFeatures(pd_handle, &pd_info.features) // Basic features
			// vk.GetPhysicalDeviceMemoryProperties(pd_handle, &pd_info.memory_properties) // For later
			pd_info.queue_families = queues
			
			// If suitable, query_swapchain_support was called inside is_device_suitable.
			// Its results (formats, modes) need to be stored if we don't want to query again.
			// For now, is_device_suitable only checks for non-emptiness. We'll query again when creating swapchain.
			// This means the slices allocated by query_swapchain_support inside is_device_suitable
			// with `allocator` must be freed if that path in is_device_suitable doesn't lead to selection.
			// This is complex.
			// Let's assume is_device_suitable does NOT store the swapchain details, just checks.
			// And `select_physical_device` does not store them either. They are queried fresh by swapchain creation.

			// Prioritize discrete GPU if available
			if props.deviceType == .DISCRETE_GPU {
				log.infof("Selecting discrete GPU: %s", device_name)
				if selected_pd_info != nil { free(selected_pd_info, allocator) } // Free previously selected non-discrete one
				selected_pd_info = pd_info
				break // Found a discrete GPU, use it.
			} else if selected_pd_info == nil { // First suitable device found (might be integrated)
				log.infof("Selecting first suitable GPU: %s (Type: %v)", device_name, props.deviceType)
				selected_pd_info = pd_info
			} else {
				// A suitable device was already selected, but it wasn't discrete. This one isn't either.
				// Keep the first one found unless a discrete one appears.
				// Free the current pd_info as it won't be used.
				free(pd_info, allocator)
			}
		}
	}

	if selected_pd_info == nil {
		log.error("Failed to find a suitable GPU.")
		return nil, .Device_Creation_Failed
	}
	
	log.infof("Selected Physical Device: %s", vk_fixed_string_to_odin_string(selected_pd_info.properties.deviceName[:]))
	return selected_pd_info, .None
}


// --- Logical Device Creation ---

vk_create_logical_device_internal :: proc(
	vk_instance_info: ^Vk_Instance_Info, 
	physical_device_info: ^Vk_PhysicalDevice_Info,
) -> (^Vk_Device_Internal, gfx_interface.Gfx_Error) {
	
	allocator := vk_instance_info.allocator // Use instance's allocator for the logical device too
	indices := physical_device_info.queue_families
	
	// --- Queue Create Infos ---
	// Need to handle cases where graphics and present families are the same.
	// Use a set to store unique queue family indices.
	unique_queue_families_map := make(map[u32]bool, allocator)
	defer delete(unique_queue_families_map)

	if indices.graphics_family != nil { unique_queue_families_map[indices.graphics_family.?] = true }
	if indices.present_family != nil  { unique_queue_families_map[indices.present_family.?] = true }
	
	// Create a slice of VkDeviceQueueCreateInfo from the unique families
	queue_create_infos_dyn := make([dynamic]vk.DeviceQueueCreateInfo, 0, len(unique_queue_families_map))
	defer delete(queue_create_infos_dyn)

	queue_priority: f32 = 1.0 // Default priority
	for queue_family_index, _ in unique_queue_families_map {
		info := vk.DeviceQueueCreateInfo {
			sType = .DEVICE_QUEUE_CREATE_INFO,
			queueFamilyIndex = queue_family_index,
			queueCount = 1, // Requesting one queue from each family
			pQueuePriorities = &queue_priority, // Pointer to single float priority
		}
		append(&queue_create_infos_dyn, info)
	}

	// --- Device Features ---
	// Request features needed by the application.
	// For now, request basic features available in physical_device_info.features.
	// If specific features like samplerAnisotropy are needed, check and enable them here.
	device_features_to_enable := physical_device_info.features // Copy all reported features
	// Example: if physical_device_info.features.samplerAnisotropy == vk.TRUE {
	//     device_features_to_enable.samplerAnisotropy = vk.TRUE
	// } else { // disable it or handle error if it's critical }

	// --- Logical Device Create Info ---
	device_create_info := vk.DeviceCreateInfo{
		sType = .DEVICE_CREATE_INFO,
		pQueueCreateInfos = rawptr(queue_create_infos_dyn.data), // Pointer to the start of the slice data
		queueCreateInfoCount = u32(len(queue_create_infos_dyn)),
		pEnabledFeatures = &device_features_to_enable,
	}

	// Device-level extensions (e.g., swapchain)
	// Convert REQUIRED_DEVICE_EXTENSIONS (slice of Odin strings) to array of cstrings
	enabled_dev_ext_count := u32(len(REQUIRED_DEVICE_EXTENSIONS))
	enabled_dev_ext_names_c := make_foreign_array_ptr([dynamic]cstring, int(enabled_dev_ext_count), allocator)
	defer free_foreign_array_ptr(enabled_dev_ext_names_c)
	for i, ext_name_str in REQUIRED_DEVICE_EXTENSIONS {
		enabled_dev_ext_names_c.data[i] = strings.clone_to_cstring(ext_name_str)
	}
	defer { // Defer freeing these cstrings
		for i := 0; i < int(enabled_dev_ext_count); i = i + 1 {
			if enabled_dev_ext_names_c.data[i] != nil {
				delete(enabled_dev_ext_names_c.data[i])
			}
		}
	}
	
	device_create_info.enabledExtensionCount = enabled_dev_ext_count
	device_create_info.ppEnabledExtensionNames = enabled_dev_ext_names_c.data

	// Device-level validation layers (typically not needed if instance-level layers are set,
	// but can be set for older Vulkan implementations). For modern Vulkan, instance layers cover device calls.
	// If ENABLE_VALIDATION_LAYERS is true, ppEnabledLayerNames can point to the same layer names
	// used for instance creation, assuming they are device-compatible.
	// However, it's often set to nil here.
	if ENABLE_VALIDATION_LAYERS {
		// This part is a bit tricky. The spec says:
		// "ppEnabledLayerNames is a pointer to an array of enabledLayerCount null-terminated UTF-8 strings containing the names of layers to enable for the created device.
		//  See the Layers section for further details. Enabling some layers may require enabling certain physical device features."
		// And for vkCreateInstance:
		// "Any given layer is either an instance layer or a device layer. Instance layers are enabled for the instance and all child Device objects. Device layers are enabled for a given Device object."
		// So, if Khronos validation is an instance layer, it should cover. If it also has device components, it might be listed.
		// For simplicity and modern practice, relying on instance-level validation is common.
		// Let's not set device layers explicitly unless proven necessary.
		// device_create_info.enabledLayerCount = u32(len(VALIDATION_LAYERS_CSTRS)) // If needed
		// device_create_info.ppEnabledLayerNames = VALIDATION_LAYERS_CSTRS_PTR // If needed
		device_create_info.enabledLayerCount = 0
		device_create_info.ppEnabledLayerNames = nil
	}


	// --- Create Logical Device ---
	logical_device_handle: vk.Device
	p_vk_allocator: ^vk.AllocationCallbacks = nil // Assuming nil for Vulkan allocators
	
	result := vk.CreateDevice(physical_device_info.physical_device, &device_create_info, p_vk_allocator, &logical_device_handle)
	if result != .SUCCESS {
		log.errorf("vkCreateDevice failed. Result: %v (%d)", result, int(result))
		return nil, .Device_Creation_Failed
	}
	log.info("Vulkan Logical Device created successfully.")

	// --- Store Logical Device Info ---
	vk_device_internal := new(Vk_Device_Internal, allocator)
	vk_device_internal.allocator = allocator
	vk_device_internal.vk_instance = vk_instance_info
	vk_device_internal.physical_device_info = physical_device_info // Store the selected physical device info
	vk_device_internal.logical_device = logical_device_handle

	// Get queue handles
	// The queue index within the family is 0 since we only requested one queue (queueCount=1) per family.
	vk.GetDeviceQueue(logical_device_handle, indices.graphics_family.?, 0, &vk_device_internal.graphics_queue)
	// If graphics and present families are different, get the present queue separately.
	// If they are the same, graphics_queue can also be used for presentation.
	if indices.graphics_family.? == indices.present_family.? {
		vk_device_internal.present_queue = vk_device_internal.graphics_queue
		log.info("Graphics and Present queues are from the same family.")
	} else {
		vk.GetDeviceQueue(logical_device_handle, indices.present_family.?, 0, &vk_device_internal.present_queue)
		log.info("Graphics and Present queues are from different families.")
	}
	
	if vk_device_internal.graphics_queue == nil { log.error("Failed to get graphics queue handle.") }
	if vk_device_internal.present_queue == nil  { log.error("Failed to get present queue handle.") }
	if vk_device_internal.graphics_queue == nil || vk_device_internal.present_queue == nil {
		// Cleanup: destroy logical device, free vk_device_internal
		vk.DestroyDevice(logical_device_handle, p_vk_allocator)
		free(vk_device_internal, allocator)
		return nil, .Device_Creation_Failed
	}
	
	log.info("Retrieved Graphics and Present queue handles.")
	return vk_device_internal, .None
}


// --- Gfx_Device_Interface Wrappers ---

// vk_create_device_wrapper is the main function to create a Vulkan Gfx_Device.
// It orchestrates instance creation, physical device selection, and logical device creation.
vk_create_device_wrapper :: proc(main_allocator_ptr: ^rawptr) -> (gfx_interface.Gfx_Device, gfx_interface.Gfx_Error) {
	// Use the provided allocator. If nil, fallback to context.allocator.
	allocator := context.allocator
	if main_allocator_ptr != nil && main_allocator_ptr^ != nil {
		allocator = main_allocator_ptr^.(mem.Allocator)
	}

	// 1. Create Vulkan Instance
	// TODO: Get app_name and engine_name from somewhere (e.g. game config)
	vk_instance_info, inst_err := vk_create_instance_internal("OdinGame App", "OdinGame Engine", allocator)
	if inst_err != .None {
		return gfx_interface.Gfx_Device{}, inst_err
	}

	// 2. Create a temporary SDL window and Vulkan surface to aid physical device selection.
	// This is because physical device suitability (especially queue family presentation support)
	// depends on a surface.
	// The window needs to be created using SDL_Vulkan_LoadLibrary and SDL_CreateWindow with VULKAN flag.
	// This implies SDL_Init(SDL_INIT_VIDEO) must have been called.
	// Let's assume it's called by the application layer (e.g. core.Game) *before* create_device.
	
	// Load SDL Vulkan library (must be done before creating Vulkan-enabled window)
	// This should ideally be done once globally.
	// For now, calling it here. If it fails, instance should be cleaned up.
	if sdl.Vulkan_LoadLibrary(nil) != 0 { // nil means default library
		err_msg := sdl.GetError()
		log.errorf("SDL_Vulkan_LoadLibrary failed: %s. Ensure Vulkan SDK is installed and discoverable.", err_msg)
		vk_destroy_instance_internal(vk_instance_info)
		return gfx_interface.Gfx_Device{}, .Initialization_Failed
	}
	log.info("SDL Vulkan library loaded successfully.")

	// Create a temporary, hidden SDL window for surface creation during device selection
	// SDL_WINDOW_HIDDEN | SDL_WINDOW_VULKAN
	temp_sdl_window_flags : sdl.WindowFlags = {.VULKAN, .HIDDEN}
	temp_sdl_window := sdl.CreateWindow("Temp Vulkan Surface Window", sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED, 100, 100, temp_sdl_window_flags)
	if temp_sdl_window == nil {
		log.errorf("Failed to create temporary SDL window for Vulkan surface: %s", sdl.GetError())
		sdl.Vulkan_UnloadLibrary() // Unload if loaded
		vk_destroy_instance_internal(vk_instance_info)
		return gfx_interface.Gfx_Device{}, .Initialization_Failed
	}
	
	var temp_surface: vk.SurfaceKHR
	if sdl.Vulkan_CreateSurface(temp_sdl_window, vk_instance_info.instance, &temp_surface) == sdl.FALSE {
		err_msg := sdl.GetError()
		log.errorf("SDL_Vulkan_CreateSurface failed for temporary window: %s", err_msg)
		sdl.DestroyWindow(temp_sdl_window)
		sdl.Vulkan_UnloadLibrary()
		vk_destroy_instance_internal(vk_instance_info)
		return gfx_interface.Gfx_Device{}, .Initialization_Failed
	}
	log.info("Temporary Vulkan surface created for physical device selection.")


	// 3. Select Physical Device
	physical_device_info, pd_err := vk_select_physical_device_internal(vk_instance_info, temp_surface)
	if pd_err != .None {
		// Cleanup temp surface and window
		vk.DestroySurfaceKHR(vk_instance_info.instance, temp_surface, nil)
		sdl.DestroyWindow(temp_sdl_window)
		sdl.Vulkan_UnloadLibrary()
		vk_destroy_instance_internal(vk_instance_info)
		return gfx_interface.Gfx_Device{}, pd_err
	}
	
	// Temp surface and window are no longer needed after physical device selection.
	// The actual window/surface for rendering will be created by create_window.
	vk.DestroySurfaceKHR(vk_instance_info.instance, temp_surface, nil)
	sdl.DestroyWindow(temp_sdl_window)
	log.info("Temporary Vulkan surface and SDL window destroyed.")
	// Note: SDL_Vulkan_UnloadLibrary() should be called only at the very end of the application,
	// as it unloads the library for all subsequent Vulkan calls.
	// For now, we keep it loaded. It will be unloaded when the Gfx_Device is destroyed.


	// 4. Create Logical Device
	vk_device_internal, ld_err := vk_create_logical_device_internal(vk_instance_info, physical_device_info)
	if ld_err != .None {
		// physical_device_info is just a pointer to struct, its members don't need deep free here
		// as it's owned by this scope if not passed on.
		// However, select_physical_device_internal allocates it. So, it should be freed.
		free(physical_device_info, allocator) 
		sdl.Vulkan_UnloadLibrary() // Unload if logical device fails
		vk_destroy_instance_internal(vk_instance_info)
		return gfx_interface.Gfx_Device{}, ld_err
	}

	// Successfully created the Vulkan device structure.
	// Wrap it in Gfx_Device.
	// The Vk_Device_Internal struct itself is allocated on the heap.
	// The Gfx_Device struct_variant will store a pointer to it (Vk_Device_Variant which is ^Vk_Device_Internal).
	
	log.infof("Vulkan Gfx_Device wrapper created successfully. Logical device: %p", vk_device_internal.logical_device)
	return gfx_interface.Gfx_Device{variant = Vk_Device_Variant(vk_device_internal)}, .None
}


vk_destroy_device_wrapper :: proc(device: gfx_interface.Gfx_Device) {
	if vk_dev, ok := device.variant.(Vk_Device_Variant); ok && vk_dev != nil {
		log.infof("Destroying Vulkan Gfx_Device (logical device: %p)", vk_dev.logical_device)
		
		// Wait for logical device to be idle before destroying (important!)
		if vk_dev.logical_device != nil {
			vk.DeviceWaitIdle(vk_dev.logical_device)
			log.info("Vulkan Logical Device finished waiting for idle.")
		}

		// Destroy logical device
		// pAllocator for DestroyDevice is always nil as per spec for vkCreateDevice.
		if vk_dev.logical_device != nil {
			vk.DestroyDevice(vk_dev.logical_device, nil)
			log.info("Vulkan Logical Device destroyed.")
		}
		
		// Free the physical device info struct that was allocated
		if vk_dev.physical_device_info != nil {
			// Check if any internal slices in physical_device_info need freeing, e.g., if we stored available_extensions
			// For now, it doesn't store heap-allocated slices that it owns beyond the struct itself.
			free(vk_dev.physical_device_info, vk_dev.allocator) 
			log.info("Vulkan PhysicalDevice_Info struct freed.")
		}
		
		// Destroy instance (which also handles debug messenger)
		// vk_instance is a pointer within vk_dev
		if vk_dev.vk_instance != nil {
			vk_destroy_instance_internal(vk_dev.vk_instance)
			// vk_instance_info is freed by vk_destroy_instance_internal
		}
		
		// Unload SDL Vulkan Library
		// This should be called when Vulkan is no longer needed by the application.
		sdl.Vulkan_UnloadLibrary()
		log.info("SDL Vulkan library unloaded.")

		// Free the Vk_Device_Internal struct itself
		free(vk_dev, vk_dev.allocator) 
		log.info("Vk_Device_Internal struct freed.")

	} else {
		log.errorf("vk_destroy_device_wrapper: Invalid Gfx_Device type or nil variant (%v).", device.variant)
	}
}
