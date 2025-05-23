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

query_swapchain_support :: proc(physical_device: vk.PhysicalDevice, surface: vk.SurfaceKHR, allocator: mem.Allocator) -> (vk_types.Swapchain_Support_Details, bool) {
	details: vk_types.Swapchain_Support_Details
	if vk.GetPhysicalDeviceSurfaceCapabilitiesKHR(physical_device, surface, &details.capabilities) != .SUCCESS { return details, false }
	format_count: u32
	vk.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, nil)
	if format_count > 0 {
		formats_slice := make([]vk.SurfaceFormatKHR, format_count, context.temp_allocator)
		defer delete(formats_slice)
		vk.GetPhysicalDeviceSurfaceFormatsKHR(physical_device, surface, &format_count, formats_slice[:])
		details.formats = slice.clone(formats_slice[:], allocator) 
	} else { return details, false }
	present_mode_count: u32
	vk.GetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, nil)
	if present_mode_count > 0 {
		modes_slice := make([]vk.PresentModeKHR, present_mode_count, context.temp_allocator)
		defer delete(modes_slice)
		vk.GetPhysicalDeviceSurfacePresentModesKHR(physical_device, surface, &present_mode_count, modes_slice[:])
		details.present_modes = slice.clone(modes_slice[:], allocator)
	} else { return details, false }
	return details, true
}

is_device_suitable :: proc(physical_device: vk.PhysicalDevice, temp_surface: vk.SurfaceKHR, instance_allocator: mem.Allocator) -> (bool, vk_types.Queue_Family_Indices) {
	indices := find_queue_families(physical_device, temp_surface)
	if !vk_types.is_complete(indices) { return false, indices }
	if !check_device_extension_support(physical_device, instance_allocator) { return false, indices }
	swapchain_support, ok_sc_support := query_swapchain_support(physical_device, temp_surface, instance_allocator)
    defer if !ok_sc_support || !(len(swapchain_support.formats) > 0 && len(swapchain_support.present_modes) > 0) {
        delete(swapchain_support.formats)   
        delete(swapchain_support.present_modes)
    }
	if !ok_sc_support || len(swapchain_support.formats) == 0 || len(swapchain_support.present_modes) == 0 {
		return false, indices
	}
	return true, indices
}

vk_select_physical_device_internal :: proc(vk_instance_info: ^vk_types.Vk_Instance_Info, temp_surface: vk.SurfaceKHR) -> (^vk_types.Vk_PhysicalDevice_Info, common.Engine_Error) {
	instance := vk_instance_info.instance
	allocator := vk_instance_info.allocator
	device_count: u32
	vk.EnumeratePhysicalDevices(instance, &device_count, nil)
	if device_count == 0 { return nil, common.Engine_Error.Device_Creation_Failed }
	physical_devices_handles := make([]vk.PhysicalDevice, device_count)
	defer delete(physical_devices_handles)
	vk.EnumeratePhysicalDevices(instance, &device_count, physical_devices_handles[:])
	selected_pd_info: ^vk_types.Vk_PhysicalDevice_Info = nil
	for pd_handle in physical_devices_handles {
		props: vk.PhysicalDeviceProperties
		vk.GetPhysicalDeviceProperties(pd_handle, &props)
		suitable, queues := is_device_suitable(pd_handle, temp_surface, allocator)
		if suitable {
			pd_info := new(vk_types.Vk_PhysicalDevice_Info, allocator)
			pd_info.physical_device = pd_handle
			pd_info.properties = props
			vk.GetPhysicalDeviceFeatures(pd_handle, &pd_info.features)
			pd_info.queue_families = queues
			if props.deviceType == .DISCRETE_GPU {
				if selected_pd_info != nil { free(selected_pd_info, allocator) } 
				selected_pd_info = pd_info
				break 
			} else if selected_pd_info == nil { 
				selected_pd_info = pd_info
			} else {
				free(pd_info, allocator)
			}
		}
	}
	if selected_pd_info == nil { return nil, common.Engine_Error.Device_Creation_Failed }
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
	if result != .SUCCESS { return nil, common.Engine_Error.Device_Creation_Failed }

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
		vk.DestroyDevice(logical_device_handle, p_vk_allocator)
		free(vk_device_internal, allocator)
		return nil, common.Engine_Error.Device_Creation_Failed
	}
    
    pool_sizes := [2]vk.DescriptorPoolSize{
        { type = .UNIFORM_BUFFER, descriptorCount = u32(vk_types.MAX_FRAMES_IN_FLIGHT * 10) }, // Max 10 UBOs total (example)
        { type = .COMBINED_IMAGE_SAMPLER, descriptorCount = u32(vk_types.MAX_FRAMES_IN_FLIGHT * 10) }, // Max 10 samplers total (example)
    }
    max_total_sets := u32(vk_types.MAX_FRAMES_IN_FLIGHT * 20)
    
    vk_device_internal.descriptor_pool, d_pool_err := vk_descriptors.vk_create_descriptor_pool_internal(vk_device_internal, pool_sizes[:], max_total_sets, {.FREE_DESCRIPTOR_SET_BIT})
    if d_pool_err != .None {
        vk.DestroyCommandPool(logical_device_handle, vk_device_internal.command_pool, p_vk_allocator)
        vk.DestroyDevice(logical_device_handle, p_vk_allocator)
        free(vk_device_internal, allocator)
        return nil, d_pool_err
    }

	vk.GetDeviceQueue(logical_device_handle, indices.graphics_family.?, 0, &vk_device_internal.graphics_queue)
	if indices.graphics_family.? == indices.present_family.? {
		vk_device_internal.present_queue = vk_device_internal.graphics_queue
	} else {
		vk.GetDeviceQueue(logical_device_handle, indices.present_family.?, 0, &vk_device_internal.present_queue)
	}
	
	if vk_device_internal.graphics_queue == nil || vk_device_internal.present_queue == nil {
        if vk_device_internal.descriptor_pool != vk.NULL_HANDLE {
            vk_descriptors.vk_destroy_descriptor_pool_internal(vk_device_internal, vk_device_internal.descriptor_pool)
        }
		vk.DestroyCommandPool(logical_device_handle, vk_device_internal.command_pool, p_vk_allocator)
		vk.DestroyDevice(logical_device_handle, p_vk_allocator)
		free(vk_device_internal, allocator)
		return nil, common.Engine_Error.Device_Creation_Failed
	}
	
	return vk_device_internal, .None
}

vk_create_device_wrapper :: proc(main_allocator_ptr: ^rawptr) -> (gfx_interface.Gfx_Device, common.Engine_Error) {
	allocator := context.allocator
	if main_allocator_ptr != nil && main_allocator_ptr^ != nil {
		allocator = main_allocator_ptr^.(mem.Allocator)
	}
	vk_instance_info, inst_err := vk_helpers.vk_create_instance_internal("OdinGame App", "OdinGame Engine", allocator)
	if inst_err != .None { return gfx_interface.Gfx_Device{}, inst_err }

	if sdl.Vulkan_LoadLibrary(nil) != 0 { 
		vk_helpers.vk_destroy_instance_internal(vk_instance_info)
		return gfx_interface.Gfx_Device{}, common.Engine_Error.Graphics_Initialization_Failed
	}
	temp_sdl_window_flags : sdl.WindowFlags = {.VULKAN, .HIDDEN}
	temp_sdl_window := sdl.CreateWindow("Temp Vulkan Surface Window", sdl.WINDOWPOS_UNDEFINED, sdl.WINDOWPOS_UNDEFINED, 100, 100, temp_sdl_window_flags)
	if temp_sdl_window == nil {
		sdl.Vulkan_UnloadLibrary() 
		vk_helpers.vk_destroy_instance_internal(vk_instance_info)
		return gfx_interface.Gfx_Device{}, common.Engine_Error.Graphics_Initialization_Failed
	}
	var temp_surface: vk.SurfaceKHR
	if sdl.Vulkan_CreateSurface(temp_sdl_window, vk_instance_info.instance, &temp_surface) == sdl.FALSE {
		sdl.DestroyWindow(temp_sdl_window)
		sdl.Vulkan_UnloadLibrary()
		vk_helpers.vk_destroy_instance_internal(vk_instance_info)
		return gfx_interface.Gfx_Device{}, common.Engine_Error.Graphics_Initialization_Failed
	}
	physical_device_info, pd_err := vk_select_physical_device_internal(vk_instance_info, temp_surface)
	if pd_err != .None {
		vk.DestroySurfaceKHR(vk_instance_info.instance, temp_surface, nil)
		sdl.DestroyWindow(temp_sdl_window)
		sdl.Vulkan_UnloadLibrary()
		vk_helpers.vk_destroy_instance_internal(vk_instance_info)
		return gfx_interface.Gfx_Device{}, pd_err
	}
	vk.DestroySurfaceKHR(vk_instance_info.instance, temp_surface, nil)
	sdl.DestroyWindow(temp_sdl_window)

	vk_device_internal_ptr, ld_err := vk_create_logical_device_internal_core(vk_instance_info, physical_device_info)
	if ld_err != .None {
		free(physical_device_info, allocator) 
		sdl.Vulkan_UnloadLibrary() 
		vk_helpers.vk_destroy_instance_internal(vk_instance_info)
		return gfx_interface.Gfx_Device{}, ld_err
	}
    
    created_gfx_device := gfx_interface.Gfx_Device{variant = vk_device_internal_ptr}
    for i in 0..<vk_types.MAX_FRAMES_IN_FLIGHT {
        ubo_gfx_buffer, ubo_err := vk_buffer.vk_create_buffer_internal(
            created_gfx_device, .Uniform, vk_types.DEFAULT_UBO_SIZE, nil, true,
        )
        if ubo_err != .None {
            log.errorf("Failed to create uniform buffer for frame %d (in wrapper): %v", i, ubo_err)
            for j in 0..<i { 
                if vk_device_internal_ptr.uniform_buffers[j].buffer != vk.NULL_HANDLE {
                    temp_handle_for_destroy := gfx_interface.Gfx_Buffer{variant = &vk_device_internal_ptr.uniform_buffers[j]}
                    vk_buffer.vk_destroy_buffer_internal(temp_handle_for_destroy)
                }
            }
            if vk_device_internal_ptr.descriptor_pool != vk.NULL_HANDLE {
                vk_descriptors.vk_destroy_descriptor_pool_internal(vk_device_internal_ptr, vk_device_internal_ptr.descriptor_pool)
            }
            if vk_device_internal_ptr.command_pool != vk.NULL_HANDLE {
                 vk.DestroyCommandPool(vk_device_internal_ptr.logical_device, vk_device_internal_ptr.command_pool, nil)
            }
            vk.DestroyDevice(vk_device_internal_ptr.logical_device, nil)
            free(physical_device_info, allocator)
            sdl.Vulkan_UnloadLibrary()
            vk_helpers.vk_destroy_instance_internal(vk_instance_info)
            free(vk_device_internal_ptr, allocator)
            return {}, ubo_err
        }
        ubo_info_ptr, ok_ubo_info := ubo_gfx_buffer.variant.(^vk_types.Vk_Uniform_Buffer_Info)
        if !ok_ubo_info || ubo_info_ptr == nil {
            log.errorf("vk_create_buffer_internal did not return Vk_Uniform_Buffer_Info for Uniform type at frame %d (in wrapper)", i)
            for j in 0..<i { if vk_device_internal_ptr.uniform_buffers[j].buffer != vk.NULL_HANDLE { 
                temp_handle_to_destroy := gfx_interface.Gfx_Buffer{variant = &vk_device_internal_ptr.uniform_buffers[j]}
                vk_buffer.vk_destroy_buffer_internal(temp_handle_to_destroy)
            }}
            if ubo_gfx_buffer.variant != nil { vk_buffer.vk_destroy_buffer_internal(ubo_gfx_buffer) }
            if vk_device_internal_ptr.descriptor_pool != vk.NULL_HANDLE { vk_descriptors.vk_destroy_descriptor_pool_internal(vk_device_internal_ptr, vk_device_internal_ptr.descriptor_pool) }
            if vk_device_internal_ptr.command_pool != vk.NULL_HANDLE { vk.DestroyCommandPool(vk_device_internal_ptr.logical_device, vk_device_internal_ptr.command_pool, nil) }
            vk.DestroyDevice(vk_device_internal_ptr.logical_device, nil)
            free(physical_device_info, allocator)
            sdl.Vulkan_UnloadLibrary()
            vk_helpers.vk_destroy_instance_internal(vk_instance_info)
            free(vk_device_internal_ptr, allocator)
            return {}, common.Engine_Error.Invalid_Operation
        }
        // Store the actual struct, not a pointer to it, as uniform_buffers is an array of structs.
        vk_device_internal_ptr.uniform_buffers[i] = ubo_info_ptr^ 
    }
	
	log.infof("Vulkan Gfx_Device wrapper created successfully. Logical device: %p", vk_device_internal_ptr.logical_device)
	return created_gfx_device, .None
}


vk_destroy_device_wrapper :: proc(device: gfx_interface.Gfx_Device) {
	if vk_dev, ok := device.variant.(vk_types.Vk_Device_Variant); ok && vk_dev != nil {
		if vk_dev.logical_device != nil {
			vk.DeviceWaitIdle(vk_dev.logical_device)
		}
        for i in 0..<vk_types.MAX_FRAMES_IN_FLIGHT {
            ubo_info_to_destroy_ptr := &vk_dev.uniform_buffers[i] 
            if ubo_info_to_destroy_ptr.buffer != vk.NULL_HANDLE {
                // Reconstruct Gfx_Buffer to pass to vk_destroy_buffer_internal
                // This requires vk_destroy_buffer_internal to correctly handle Vk_Uniform_Buffer_Info variant
                temp_gfx_buffer_for_destroy := gfx_interface.Gfx_Buffer{variant = ubo_info_to_destroy_ptr}
                vk_buffer.vk_destroy_buffer_internal(temp_gfx_buffer_for_destroy)
            }
        }
        if vk_dev.descriptor_pool != vk.NULL_HANDLE {
            vk_descriptors.vk_destroy_descriptor_pool_internal(vk_dev, vk_dev.descriptor_pool)
        }
		if vk_dev.command_pool != vk.NULL_HANDLE && vk_dev.logical_device != nil {
			vk.DestroyCommandPool(vk_dev.logical_device, vk_dev.command_pool, nil) 
		}
		if vk_dev.logical_device != nil {
			vk.DestroyDevice(vk_dev.logical_device, nil)
		}
		if vk_dev.physical_device_info != nil {
			free(vk_dev.physical_device_info, vk_dev.allocator) 
		}
		if vk_dev.vk_instance != nil {
			vk_helpers.vk_destroy_instance_internal(vk_dev.vk_instance)
		}
		sdl.Vulkan_UnloadLibrary()
		free(vk_dev, vk_dev.allocator) 
	} else {
		log.errorf("vk_destroy_device_wrapper: Invalid Gfx_Device type or nil variant (%v).", device.variant)
	}
}
