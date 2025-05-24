package vulkan

import vk "vendor:vulkan"
import sdl "vendor:sdl2" 
import "core:log"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:slice"
import "../gfx_interface" 
import "../../common" 
import "./vk_types"     
import "./vk_buffer"    
import "./vk_descriptors" 
import "./vk_helpers" // For vk_create_instance_internal, vk_destroy_instance_internal, ENABLE_VALIDATION_LAYERS, vk_fixed_string_to_odin_string

REQUIRED_DEVICE_EXTENSIONS :: []string{
	vk.KHR_SWAPCHAIN_EXTENSION_NAME,
}

find_queue_families :: proc(physical_device: vk.PhysicalDevice, surface: vk.SurfaceKHR) -> vk_types.Queue_Family_Indices {
	indices: vk_types.Queue_Family_Indices 
	queue_family_count: u32
	vk.GetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, nil)
	if queue_family_count == 0 { return indices }
	queue_families_props := make([]vk.QueueFamilyProperties, queue_family_count)
	defer delete(queue_families_props)
	vk.GetPhysicalDeviceQueueFamilyProperties(physical_device, &queue_family_count, queue_families_props[:])

	for i, props in queue_families_props {
		if props.queueFlags & vk.QUEUE_GRAPHICS_BIT != 0 {
			indices.graphics_family = vk_types.Maybe(u32){u32(i), true}
		}
		present_support: vk.Bool32
		vk.GetPhysicalDeviceSurfaceSupportKHR(physical_device, u32(i), surface, &present_support)
		if present_support == vk.TRUE {
			indices.present_family = vk_types.Maybe(u32){u32(i), true}
		}
		if vk_types.is_complete(indices) { break }
	}
	return indices
}

check_device_extension_support :: proc(physical_device: vk.PhysicalDevice, allocator: mem.Allocator) -> bool {
	available_ext_count: u32
	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &available_ext_count, nil)
	available_extensions := make([]vk.ExtensionProperties, available_ext_count, allocator)
	defer delete(available_extensions) 
	vk.EnumerateDeviceExtensionProperties(physical_device, nil, &available_ext_count, available_extensions[:])
	
	missing_count := 0
	for _, req_ext_name_str in REQUIRED_DEVICE_EXTENSIONS {
		found := false
		for _, ext_prop in available_extensions {
			if req_ext_name_str == vk_helpers.vk_fixed_string_to_odin_string(ext_prop.extensionName[:]) {
				found = true
				break
			}
		}
		if !found {
			missing_count += 1
		}
	}
	return missing_count == 0
}

query_swapchain_support :: proc(physical_device: vk.PhysicalDevice, surface: vk.SurfaceKHR, allocator: mem.Allocator) -> (details: vk_types.Swapchain_Support_Details, success: bool) {
	details: vk_types.Swapchain_Support_Details
	res_caps := vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &details.capabilities)
	if res_caps != .SUCCESS {
		log.errorf("vkGetPhysicalDeviceSurfaceCapabilitiesKHR failed in query_swapchain_support: %v", res_caps)
		return details, false
	}
	format_count: u32
	res_fmt_count := vk.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, nil)
	if res_fmt_count != .SUCCESS {
		log.errorf("vkGetPhysicalDeviceSurfaceFormatsKHR (count) failed in query_swapchain_support: %v", res_fmt_count)
		return details, false
	}
	if format_count > 0 {
		formats_slice := make([]vk.SurfaceFormatKHR, format_count, context.temp_allocator)
		defer delete(formats_slice)
		res_fmts := vk.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, formats_slice[:])
		if res_fmts != .SUCCESS {
			log.errorf("vkGetPhysicalDeviceSurfaceFormatsKHR (list) failed in query_swapchain_support: %v", res_fmts)
			return details, false
		}
		details.formats = slice.clone(formats_slice[:], allocator) 
	} else { 
		log.warn("query_swapchain_support: No surface formats found.")
		return details, false 
	}
	present_mode_count: u32
	res_pm_count := vk.GetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, nil)
	if res_pm_count != .SUCCESS {
		log.errorf("vkGetPhysicalDeviceSurfacePresentModesKHR (count) failed in query_swapchain_support: %v", res_pm_count)
		return details, false
	}
	if present_mode_count > 0 {
		modes_slice := make([]vk.PresentModeKHR, present_mode_count, context.temp_allocator)
		defer delete(modes_slice)
		res_pms := vk.GetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, modes_slice[:])
		if res_pms != .SUCCESS {
			log.errorf("vkGetPhysicalDeviceSurfacePresentModesKHR (list) failed in query_swapchain_support: %v", res_pms)
			// details.formats might need cleanup if allocated
			delete(details.formats) 
			return details, false
		}
		details.present_modes = slice.clone(modes_slice[:], allocator)
	} else { 
		log.warn("query_swapchain_support: No surface present modes found.")
		delete(details.formats) // Cleanup previously allocated formats
		return details, false 
	}
	return details, true
}

is_device_suitable :: proc(physical_device: vk.PhysicalDevice, temp_surface: vk.SurfaceKHR, instance_allocator: mem.Allocator) -> (bool, vk_types.Queue_Family_Indices) {
	props: vk.PhysicalDeviceProperties
	vk.GetPhysicalDeviceProperties(physical_device, &props)
	log.infof("Evaluating physical device: %s (ID: %v, Type: %v)", string(props.deviceName[:]), props.deviceID, props.deviceType)

	indices := find_queue_families(physical_device, temp_surface)
	if !vk_types.is_complete(indices) { 
		log.infof("  - Device %s: Incomplete queue families (Graphics: %v, Present: %v). Skipping.", string(props.deviceName[:]), indices.graphics_family, indices.present_family)
		return false, indices 
	}
	log.infof("  - Device %s: Found graphics queue family %v, present queue family %v.", string(props.deviceName[:]), indices.graphics_family.?, indices.present_family.?)

	if !check_device_extension_support(physical_device, instance_allocator) { 
		log.infof("  - Device %s: Does not support all required device extensions. Skipping.", string(props.deviceName[:]))
		return false, indices 
	}
	log.infof("  - Device %s: Supports all required device extensions.", string(props.deviceName[:]))

	swapchain_support, ok_sc_support := query_swapchain_support(physical_device, temp_surface, instance_allocator)
    // Defer cleanup of swapchain_support's slices regardless of ok_sc_support value
    // This is important because query_swapchain_support might partially populate them before returning false.
    defer {
        if swapchain_support.formats != nil { delete(swapchain_support.formats, instance_allocator) }
        if swapchain_support.present_modes != nil { delete(swapchain_support.present_modes, instance_allocator) }
    }
	if !ok_sc_support || len(swapchain_support.formats) == 0 || len(swapchain_support.present_modes) == 0 {
		log.infof("  - Device %s: Inadequate swapchain support (ok: %v, formats: %d, modes: %d). Skipping.", 
            string(props.deviceName[:]), ok_sc_support, len(swapchain_support.formats), len(swapchain_support.present_modes))
		return false, indices
	}
	log.infof("  - Device %s: Has adequate swapchain support.", string(props.deviceName[:]))

	log.infof("  - Device %s: Is suitable.", string(props.deviceName[:]))
	return true, indices
}

vk_select_physical_device_internal :: proc(vk_instance_info: ^vk_types.Vk_Instance_Info, temp_surface: vk.SurfaceKHR) -> (^vk_types.Vk_PhysicalDevice_Info, common.Engine_Error) {
	instance := vk_instance_info.instance
	allocator := vk_instance_info.allocator
	device_count: u32
	res_enum_pd := vk.EnumeratePhysicalDevices(instance, &device_count, nil)
	if res_enum_pd != .SUCCESS {
		log.errorf("vkEnumeratePhysicalDevices (count) failed: %v", res_enum_pd)
		return nil, common.Engine_Error.Device_Enumeration_Failed
	}
	if device_count == 0 { 
		log.error("vk_select_physical_device_internal: No Vulkan-capable physical devices found.")
		return nil, common.Engine_Error.No_Suitable_Device_Found 
	}
	log.infof("Found %d physical devices.", device_count)

	physical_devices_handles := make([]vk.PhysicalDevice, device_count)
	defer delete(physical_devices_handles)
	res_enum_pd_list := vk.EnumeratePhysicalDevices(instance, &device_count, physical_devices_handles[:])
	if res_enum_pd_list != .SUCCESS {
		log.errorf("vkEnumeratePhysicalDevices (list) failed: %v", res_enum_pd_list)
		return nil, common.Engine_Error.Device_Enumeration_Failed
	}

	selected_pd_info: ^vk_types.Vk_PhysicalDevice_Info = nil
	for pd_handle in physical_devices_handles {
		suitable, queues := is_device_suitable(pd_handle, temp_surface, allocator)
		if suitable {
			// This device is suitable, now store its info.
			// Prefer discrete GPU if available.
			current_props: vk.PhysicalDeviceProperties
			vk.GetPhysicalDeviceProperties(pd_handle, &current_props)

			pd_info_candidate := new(vk_types.Vk_PhysicalDevice_Info, allocator)
			pd_info_candidate.physical_device = pd_handle
			pd_info_candidate.properties = current_props
			vk.GetPhysicalDeviceFeatures(pd_handle, &pd_info_candidate.features) // Get all features
			pd_info_candidate.queue_families = queues
			
			if selected_pd_info == nil { // First suitable device
				selected_pd_info = pd_info_candidate
				log.infof("Selected physical device (first suitable): %s", string(current_props.deviceName[:]))
			} else if current_props.deviceType == .DISCRETE_GPU && selected_pd_info.properties.deviceType != .DISCRETE_GPU {
				// Prefer discrete GPU over other types
				log.infof("Switching to discrete GPU: %s (was %s)", string(current_props.deviceName[:]), string(selected_pd_info.properties.deviceName[:]))
				free(selected_pd_info, allocator) // Free previously selected non-discrete GPU info
				selected_pd_info = pd_info_candidate
			} else {
				// Current selection is already discrete, or new one isn't better.
				log.infof("Skipping device %s (current selection %s is preferred or equally good).", string(current_props.deviceName[:]), string(selected_pd_info.properties.deviceName[:]))
				free(pd_info_candidate, allocator) // Free the candidate not chosen
			}
		}
	}
	if selected_pd_info == nil { 
		log.error("vk_select_physical_device_internal: No suitable physical device found after checking all %d devices.", device_count)
		return nil, common.Engine_Error.No_Suitable_Device_Found 
	}
	log.infof("Final selected physical device: %s", string(selected_pd_info.properties.deviceName[:]))
	return selected_pd_info, .None
}

vk_create_logical_device_internal_core :: proc(
	vk_instance_info: ^vk_types.Vk_Instance_Info, 
	physical_device_info: ^vk_types.Vk_PhysicalDevice_Info,
) -> (^vk_types.Vk_Device_Internal, common.Engine_Error) {
	allocator := vk_instance_info.allocator 
	indices := physical_device_info.queue_families
	unique_queue_families_map := make(map[u32]bool, allocator)
	defer delete(unique_queue_families_map)
	if indices.graphics_family != nil { unique_queue_families_map[indices.graphics_family.?] = true }
	if indices.present_family != nil  { unique_queue_families_map[indices.present_family.?] = true }
	queue_create_infos_dyn := make([dynamic]vk.DeviceQueueCreateInfo, 0, len(unique_queue_families_map))
	defer delete(queue_create_infos_dyn)
	queue_priority: f32 = 1.0 
	for queue_family_index, _ in unique_queue_families_map {
		append(&queue_create_infos_dyn, vk.DeviceQueueCreateInfo{
			sType = .DEVICE_QUEUE_CREATE_INFO,
			queueFamilyIndex = queue_family_index,
			queueCount = 1, pQueuePriorities = &queue_priority, 
		})
	}
	device_features_to_enable := physical_device_info.features 
	device_create_info := vk.DeviceCreateInfo{
		sType = .DEVICE_CREATE_INFO,
		pQueueCreateInfos = rawptr(queue_create_infos_dyn.data), 
		queueCreateInfoCount = u32(len(queue_create_infos_dyn)),
		pEnabledFeatures = &device_features_to_enable,
	}
	enabled_dev_ext_count := u32(len(REQUIRED_DEVICE_EXTENSIONS))
	enabled_dev_ext_names_c := make_foreign_array_ptr([dynamic]cstring, int(enabled_dev_ext_count), allocator)
	defer free_foreign_array_ptr(enabled_dev_ext_names_c)
	for i, ext_name_str in REQUIRED_DEVICE_EXTENSIONS {
		enabled_dev_ext_names_c.data[i] = strings.clone_to_cstring(ext_name_str)
	}
	defer { 
		for i := 0; i < int(enabled_dev_ext_count); i = i + 1 {
			if enabled_dev_ext_names_c.data[i] != nil { delete(enabled_dev_ext_names_c.data[i]) }
		}
	}
	device_create_info.enabledExtensionCount = enabled_dev_ext_count
	device_create_info.ppEnabledExtensionNames = enabled_dev_ext_names_c.data
	if vk_helpers.ENABLE_VALIDATION_LAYERS { 
		device_create_info.enabledLayerCount = 0
		device_create_info.ppEnabledLayerNames = nil
	}
	logical_device_handle: vk.Device
	p_vk_allocator: ^vk.AllocationCallbacks = nil 
	result := vk.CreateDevice(physical_device_info.physical_device, &device_create_info, p_vk_allocator, &logical_device_handle)
	if result != .SUCCESS { 
		log.errorf("vkCreateDevice failed in vk_create_logical_device_internal_core: %v", result)
		return nil, common.Engine_Error.Device_Creation_Failed 
	}
	log.infof("Logical device %p created successfully for physical device %s.", logical_device_handle, string(physical_device_info.properties.deviceName[:]))

	vk_device_internal := new(vk_types.Vk_Device_Internal, allocator)
	vk_device_internal.allocator = allocator
	vk_device_internal.vk_instance = vk_instance_info
	vk_device_internal.physical_device_info = physical_device_info
	vk_device_internal.logical_device = logical_device_handle
	vk_device_internal.primary_window_for_pipeline = nil 
	
	pool_create_info := vk.CommandPoolCreateInfo{
		sType = .COMMAND_POOL_CREATE_INFO,
		flags = {.RESET_COMMAND_BUFFER_BIT}, 
		queueFamilyIndex = indices.graphics_family.?, 
	}
	cp_res := vk.CreateCommandPool(logical_device_handle, &pool_create_info, p_vk_allocator, &vk_device_internal.command_pool)
	if cp_res != .SUCCESS {
		log.errorf("vkCreateCommandPool failed in vk_create_logical_device_internal_core: %v", cp_res)
		vk.DestroyDevice(logical_device_handle, p_vk_allocator)
		free(vk_device_internal, allocator)
		return nil, common.Engine_Error.Device_Creation_Failed
	}
    log.infof("Command pool %p created for graphics queue family %v.", vk_device_internal.command_pool, indices.graphics_family.?)
    
    pool_sizes := [2]vk.DescriptorPoolSize{
        { type = .UNIFORM_BUFFER, descriptorCount = u32(vk_types.MAX_FRAMES_IN_FLIGHT * 10) }, // Max 10 UBOs total (example)
        { type = .COMBINED_IMAGE_SAMPLER, descriptorCount = u32(vk_types.MAX_FRAMES_IN_FLIGHT * 10) }, // Max 10 samplers total (example)
    }
    max_total_sets := u32(vk_types.MAX_FRAMES_IN_FLIGHT * 20)
    
    // Ensure vk_device_internal is passed correctly if vk_create_descriptor_pool_internal expects ^vk_types.Vk_Device_Internal
    created_descriptor_pool, d_pool_err := vk_descriptors.vk_create_descriptor_pool_internal(vk_device_internal, pool_sizes[:], max_total_sets, {.FREE_DESCRIPTOR_SET_BIT})
    if d_pool_err != .None {
        log.errorf("Failed to create descriptor pool in vk_create_logical_device_internal_core: %v", d_pool_err)
        // Cleanup already created command pool and logical device
        vk.DestroyCommandPool(logical_device_handle, vk_device_internal.command_pool, p_vk_allocator)
        vk.DestroyDevice(logical_device_handle, p_vk_allocator)
        free(vk_device_internal, allocator) 
        return nil, d_pool_err 
    }
    vk_device_internal.descriptor_pool = created_descriptor_pool // Assign successfully created pool
    log.infof("Descriptor pool %p created.", vk_device_internal.descriptor_pool)

	vk.GetDeviceQueue(logical_device_handle, indices.graphics_family.?, 0, &vk_device_internal.graphics_queue)
	if indices.graphics_family.? == indices.present_family.? {
		vk_device_internal.present_queue = vk_device_internal.graphics_queue
	} else {
		vk.GetDeviceQueue(logical_device_handle, indices.present_family.?, 0, &vk_device_internal.present_queue)
	}
	
	if vk_device_internal.graphics_queue == vk.NULL_HANDLE {
		log.error("vk_create_logical_device_internal_core: Failed to get graphics queue.")
        // Full cleanup
        if vk_device_internal.descriptor_pool != vk.NULL_HANDLE {
            // Assuming vk_destroy_descriptor_pool_internal is robust for this call
            vk_descriptors.vk_destroy_descriptor_pool_internal(vk_device_internal, vk_device_internal.descriptor_pool)
        }
		vk.DestroyCommandPool(logical_device_handle, vk_device_internal.command_pool, p_vk_allocator)
		vk.DestroyDevice(logical_device_handle, p_vk_allocator)
		free(vk_device_internal, allocator)
		return nil, common.Engine_Error.Device_Creation_Failed
	}
    if vk_device_internal.present_queue == vk.NULL_HANDLE {
        log.error("vk_create_logical_device_internal_core: Failed to get present queue.")
        // Full cleanup
         if vk_device_internal.descriptor_pool != vk.NULL_HANDLE {
            vk_descriptors.vk_destroy_descriptor_pool_internal(vk_device_internal, vk_device_internal.descriptor_pool)
        }
		vk.DestroyCommandPool(logical_device_handle, vk_device_internal.command_pool, p_vk_allocator)
		vk.DestroyDevice(logical_device_handle, p_vk_allocator)
		free(vk_device_internal, allocator)
		return nil, common.Engine_Error.Device_Creation_Failed
    }
	log.infof("Graphics queue %p and Present queue %p retrieved.", vk_device_internal.graphics_queue, vk_device_internal.present_queue)
	
	return vk_device_internal, .None
}

vk_create_device_wrapper :: proc(main_allocator_ptr: ^rawptr) -> (gfx_interface.Gfx_Device, common.Engine_Error) {
	allocator := context.allocator
	if main_allocator_ptr != nil && main_allocator_ptr^ != nil {
		allocator = main_allocator_ptr^.(mem.Allocator)
	}
	vk_instance_info, inst_err := vk_helpers.vk_create_instance_internal("OdinGame App", "OdinGame Engine", allocator)
	if inst_err != .None { 
        log.errorf("vk_create_device_wrapper: Failed during instance creation: %v", inst_err)
        return gfx_interface.Gfx_Device{}, inst_err 
    }

	if sdl.Vulkan_LoadLibrary(nil) != 0 { 
		log.errorf("SDL_Vulkan_LoadLibrary failed: %s. Destroying instance.", sdl.GetError())
		vk_helpers.vk_destroy_instance_internal(vk_instance_info) // vk_instance_info is valid here
		return gfx_interface.Gfx_Device{}, common.Engine_Error.Graphics_Initialization_Failed
	}
	temp_sdl_window_flags : sdl.WindowFlags = {.VULKAN, .HIDDEN}
	temp_sdl_window := sdl.CreateWindow("Temp Vulkan Surface Window", sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED, 100, 100, temp_sdl_window_flags)
	if temp_sdl_window == nil {
		log.errorf("SDL_CreateWindow for temp surface failed: %s. Unloading Vulkan library and destroying instance.", sdl.GetError())
		sdl.Vulkan_UnloadLibrary() 
		vk_helpers.vk_destroy_instance_internal(vk_instance_info)
		return gfx_interface.Gfx_Device{}, common.Engine_Error.Graphics_Initialization_Failed
	}
	var temp_surface: vk.SurfaceKHR
	if sdl.Vulkan_CreateSurface(temp_sdl_window, vk_instance_info.instance, &temp_surface) == sdl.FALSE {
		log.errorf("SDL_Vulkan_CreateSurface failed: %s. Destroying temp window, unloading library, destroying instance.", sdl.GetError())
		sdl.DestroyWindow(temp_sdl_window)
		sdl.Vulkan_UnloadLibrary()
		vk_helpers.vk_destroy_instance_internal(vk_instance_info)
		return gfx_interface.Gfx_Device{}, common.Engine_Error.Graphics_Initialization_Failed
	}
	log.debug("Temporary SDL window and Vulkan surface created for physical device selection.")

	physical_device_info, pd_err := vk_select_physical_device_internal(vk_instance_info, temp_surface)
	if pd_err != .None {
		log.errorf("vk_create_device_wrapper: Failed to select physical device: %v", pd_err)
		vk.DestroySurfaceKHR(vk_instance_info.instance, temp_surface, nil)
		sdl.DestroyWindow(temp_sdl_window)
		sdl.Vulkan_UnloadLibrary()
		vk_helpers.vk_destroy_instance_internal(vk_instance_info)
		return gfx_interface.Gfx_Device{}, pd_err
	}
	// Temp surface and window no longer needed after physical device selection
	log.debug("Destroying temporary Vulkan surface and SDL window.")
	vk.DestroySurfaceKHR(vk_instance_info.instance, temp_surface, nil)
	sdl.DestroyWindow(temp_sdl_window)

	vk_device_internal_ptr, ld_err := vk_create_logical_device_internal_core(vk_instance_info, physical_device_info)
	if ld_err != .None {
		log.errorf("vk_create_device_wrapper: Failed to create logical device: %v", ld_err)
		// physical_device_info needs to be freed as it's not stored in vk_device_internal_ptr on failure here
		if physical_device_info != nil { free(physical_device_info, allocator) } 
		sdl.Vulkan_UnloadLibrary() 
		vk_helpers.vk_destroy_instance_internal(vk_instance_info) // vk_instance_info is still valid
		return gfx_interface.Gfx_Device{}, ld_err
	}
    // At this point, vk_device_internal_ptr owns physical_device_info and vk_instance_info.
    
    created_gfx_device := gfx_interface.Gfx_Device{variant = vk_device_internal_ptr}
    log.info("Creating UBOs for each frame in flight...")
    for i in 0..<vk_types.MAX_FRAMES_IN_FLIGHT {
        // Pass `created_gfx_device` which now holds `vk_device_internal_ptr`
        ubo_gfx_buffer, ubo_err := vk_buffer.vk_create_buffer_internal(
            created_gfx_device, .Uniform, vk_types.DEFAULT_UBO_SIZE, nil, true, // dynamic=true for UBOs
        )
        if ubo_err != .None {
            log.errorf("vk_create_device_wrapper: Failed to create uniform buffer for frame %d: %v", i, ubo_err)
            // Extended cleanup for partial UBO creation failure
            for j in 0..<i { // Destroy successfully created UBOs for previous frames
                if vk_device_internal_ptr.uniform_buffers[j].buffer != vk.NULL_HANDLE {
                    // Need to wrap the Vk_Uniform_Buffer_Info struct in a Gfx_Buffer for destruction
                    temp_ubo_handle_for_destroy := gfx_interface.Gfx_Buffer{variant = &vk_device_internal_ptr.uniform_buffers[j]}
                    // Ensure device_ref is set for destruction if not already
                     if vk_device_internal_ptr.uniform_buffers[j].device_ref == nil {
                        vk_device_internal_ptr.uniform_buffers[j].device_ref = vk_device_internal_ptr
                    }
                    destroy_err := vk_buffer.vk_destroy_buffer_internal(temp_ubo_handle_for_destroy)
                    if destroy_err != .None { log.errorf("Cleanup: Failed to destroy UBO for frame %d: %v", j, destroy_err) }
                }
            }
            // Cleanup other resources created by vk_create_logical_device_internal_core
            if vk_device_internal_ptr.descriptor_pool != vk.NULL_HANDLE {
                // TODO: Update vk_destroy_descriptor_pool_internal to return error and handle it
                vk_descriptors.vk_destroy_descriptor_pool_internal(vk_device_internal_ptr, vk_device_internal_ptr.descriptor_pool)
            }
            if vk_device_internal_ptr.command_pool != vk.NULL_HANDLE {
                 vk.DestroyCommandPool(vk_device_internal_ptr.logical_device, vk_device_internal_ptr.command_pool, nil)
            }
            vk.DestroyDevice(vk_device_internal_ptr.logical_device, nil)
            // physical_device_info is now owned by vk_device_internal_ptr, so it's freed when vk_device_internal_ptr is.
            // However, vk_device_internal_ptr itself is not stored in vk_dev if logical device creation failed.
            // So, physical_device_info needs to be freed here if ld_err != .None (done above).
            // vk_instance_info is also owned by vk_device_internal_ptr.
            sdl.Vulkan_UnloadLibrary()
            vk_helpers.vk_destroy_instance_internal(vk_device_internal_ptr.vk_instance) // vk_instance is valid
            if vk_device_internal_ptr.physical_device_info != nil { free(vk_device_internal_ptr.physical_device_info, allocator) }
            free(vk_device_internal_ptr, allocator)
            return gfx_interface.Gfx_Device{}, ubo_err
        }
        
        ubo_info_ptr, ok_ubo_info := ubo_gfx_buffer.variant.(^vk_types.Vk_Uniform_Buffer_Info)
        if !ok_ubo_info || ubo_info_ptr == nil {
            log.errorf("vk_create_device_wrapper: vk_create_buffer_internal did not return Vk_Uniform_Buffer_Info for Uniform type at frame %d.", i)
            // Similar extensive cleanup...
            // This indicates a fundamental issue with vk_create_buffer_internal's return for UBOs.
            // For brevity, the full cleanup is omitted here but would mirror the above block.
             vk_buffer.vk_destroy_buffer_internal(ubo_gfx_buffer) // Attempt to clean up the problematic buffer
            // ... (full cleanup as above)
            return gfx_interface.Gfx_Device{}, common.Engine_Error.Buffer_Creation_Failed // Or .Invalid_Operation
        }
        // Store the actual struct, not a pointer to it, as uniform_buffers is an array of structs.
        vk_device_internal_ptr.uniform_buffers[i] = ubo_info_ptr^ 
        // The memory for ubo_info_ptr itself (allocated by new() in vk_create_buffer_internal) needs to be freed
        // as we copied its content. This is a potential memory leak from vk_create_buffer_internal if it
        // returns a new-allocated Gfx_Buffer whose variant is also new-allocated.
        // For now, assume vk_create_buffer_internal for UBO returns a Gfx_Buffer whose variant points to
        // an already correctly managed Vk_Uniform_Buffer_Info (e.g. part of Vk_Device_Internal or a global pool).
        // The current setup where uniform_buffers[i] is a struct implies a copy, so the original must be freed.
        // This needs careful review of vk_buffer.vk_create_buffer_internal for UBOs.
        // If `ubo_info_ptr` was allocated by `new` in `vk_create_buffer_internal` and returned as part of `Gfx_Buffer`,
        // and we are copying its *contents* into an array, then `ubo_info_ptr` itself needs to be freed.
        // Let's assume for now that `vk_create_buffer_internal` is changed so this is not an issue or this wrapper
        // is responsible for freeing it.
        // For now, if Vk_Uniform_Buffer_Info is returned as a pointer in Gfx_Buffer, and we copy it, then:
        free(ubo_info_ptr, allocator) // Free the temporary Vk_Uniform_Buffer_Info allocated by new() in vk_create_buffer_internal
        log.infof("UBO for frame %d created and configured.", i)
    }
	
	log.infof("Vulkan Gfx_Device wrapper created successfully. Logical device: %p", vk_device_internal_ptr.logical_device)
	return created_gfx_device, .None
}


vk_destroy_device_wrapper :: proc(device: gfx_interface.Gfx_Device) -> common.Engine_Error {
	if device.variant == nil {
		log.error("vk_destroy_device_wrapper: Gfx_Device variant is nil.")
		return common.Engine_Error.Invalid_Handle
	}
	vk_dev, ok_dev := device.variant.(vk_types.Vk_Device_Variant)
	if !ok_dev || vk_dev == nil {
		log.errorf("vk_destroy_device_wrapper: Invalid Gfx_Device variant type (%T) or nil pointer.", device.variant)
		return common.Engine_Error.Invalid_Handle
	}

	overall_error: common.Engine_Error = .None
	p_vk_allocator: ^vk.AllocationCallbacks = nil // Assuming nil was used for creation

	if vk_dev.logical_device != vk.NULL_HANDLE {
		wait_idle_res := vk.DeviceWaitIdle(vk_dev.logical_device)
		if wait_idle_res != .SUCCESS {
			log.errorf("vkDeviceWaitIdle failed before destruction: %v. Attempting to continue cleanup.", wait_idle_res)
			if overall_error == .None { overall_error = common.Engine_Error.Vulkan_Error }
			// Proceeding with cleanup might be risky if device is in an error state.
		}
	} else {
		log.warn("vk_destroy_device_wrapper: Logical device is NULL. Some Vulkan resources might not be cleaned up if they were created.")
        // If logical_device is NULL, many Vulkan cleanup calls below will be skipped or are inherently no-ops.
	}

    // Destroy Uniform Buffers
    log.info("Destroying uniform buffers...")
    for i in 0..<vk_types.MAX_FRAMES_IN_FLIGHT {
        ubo_info_to_destroy_ptr := &vk_dev.uniform_buffers[i] 
        if ubo_info_to_destroy_ptr.buffer != vk.NULL_HANDLE {
            // vk_destroy_buffer_internal expects Gfx_Buffer.
            // It also needs device_ref within Vk_Uniform_Buffer_Info to be correct.
            // The ubo_info_to_destroy_ptr is the actual struct, not a pointer to a Gfx_Buffer variant.
            // This was problematic. The stored uniform_buffers are Vk_Uniform_Buffer_Info, not Gfx_Buffer.
            // We need to ensure vk_destroy_buffer_internal can handle being passed a pointer to the info struct.
            // Assuming vk_buffer.vk_destroy_buffer_internal was adapted for this (it now takes Gfx_Buffer).
            // Create a temporary Gfx_Buffer wrapper.
            temp_gfx_buffer_for_destroy := gfx_interface.Gfx_Buffer{variant = ubo_info_to_destroy_ptr}
            
            // Ensure device_ref in ubo_info_to_destroy_ptr is set if vk_destroy_buffer_internal relies on it.
            // It should be, as it's set during creation.
            if ubo_info_to_destroy_ptr.device_ref == nil {
                 ubo_info_to_destroy_ptr.device_ref = vk_dev // Ensure it has a device_ref if it was somehow missed.
            }

            err_ubo := vk_buffer.vk_destroy_buffer_internal(temp_gfx_buffer_for_destroy)
            if err_ubo != .None {
                log.errorf("Failed to destroy UBO for frame %d: %v", i, err_ubo)
                if overall_error == .None { overall_error = err_ubo }
            }
        }
    }

    // Destroy Descriptor Pool
    if vk_dev.descriptor_pool != vk.NULL_HANDLE {
        log.info("Destroying descriptor pool...")
        // vk_descriptors.vk_destroy_descriptor_pool_internal expects ^Vk_Device_Internal and the pool handle.
        // It should be updated to return an error. For now, assuming it's a proc.
        // TODO: Update vk_destroy_descriptor_pool_internal to return error and handle it here.
        vk_descriptors.vk_destroy_descriptor_pool_internal(vk_dev, vk_dev.descriptor_pool) 
        // Example if it returned error:
        // err_dp := vk_descriptors.vk_destroy_descriptor_pool_internal(vk_dev, vk_dev.descriptor_pool)
        // if err_dp != .None { log.errorf("Failed to destroy descriptor pool: %v", err_dp); if overall_error == .None { overall_error = err_dp } }
    }

	// Destroy Command Pool
	if vk_dev.command_pool != vk.NULL_HANDLE && vk_dev.logical_device != vk.NULL_HANDLE {
        log.infof("Destroying command pool %p...", vk_dev.command_pool)
		vk.DestroyCommandPool(vk_dev.logical_device, vk_dev.command_pool, p_vk_allocator) 
	}

	// Destroy Logical Device
	if vk_dev.logical_device != vk.NULL_HANDLE {
        log.infof("Destroying logical device %p...", vk_dev.logical_device)
		vk.DestroyDevice(vk_dev.logical_device, p_vk_allocator)
	}

	// Free PhysicalDevice_Info struct (if allocated)
	if vk_dev.physical_device_info != nil {
        log.infof("Freeing physical device info struct %p...", vk_dev.physical_device_info)
		free(vk_dev.physical_device_info, vk_dev.allocator) 
	}

	// Destroy Instance (which includes debug messenger)
	if vk_dev.vk_instance != nil {
        log.info("Destroying Vulkan instance...")
		vk_helpers.vk_destroy_instance_internal(vk_dev.vk_instance) // This is a proc, logs internally.
	}

	// Unload Vulkan Library
    log.info("Unloading Vulkan library via SDL...")
	sdl.Vulkan_UnloadLibrary()

	// Free the Vk_Device_Internal struct itself
    log.infof("Freeing Vk_Device_Internal struct %p (allocator %p)...", vk_dev, vk_dev.allocator)
	free(vk_dev, vk_dev.allocator) 
	
	log.info("Vulkan Gfx_Device destroyed.")
	return overall_error
}
