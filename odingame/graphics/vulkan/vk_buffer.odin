package vulkan

import vk "vendor:vulkan"
import "core:log"
import "core:mem"
import "../gfx_interface" 
import "../../common" 
import "./vk_types" // For Vk_Device_Variant, Vk_Buffer_Internal, Vk_Uniform_Buffer_Info

// find_memory_type_internal (already defined, assuming it's correct from previous context)
find_memory_type_internal :: proc(
	physical_device_handle: vk.PhysicalDevice,
	type_filter: u32, 
	properties: vk.MemoryPropertyFlags, 
) -> (
	memory_type_index: u32,
	found: bool,
) {
	mem_properties: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(physical_device_handle, &mem_properties)
	for i := u32(0); i < mem_properties.memoryTypeCount; i = i + 1 {
		if (type_filter & (1 << i)) != 0 {
			if (mem_properties.memoryTypes[i].propertyFlags & properties) == properties {
				return i, true
			}
		}
	}
	log.errorf("Failed to find suitable memory type. Filter: %#x, Required Properties: %#x", type_filter, properties)
	return 0, false
}


vk_create_buffer_internal :: proc(
	gfx_device: gfx_interface.Gfx_Device,
	buffer_type: gfx_interface.Buffer_Type,
	size_bytes: int, 
	initial_data: rawptr,
	dynamic: bool, // This flag's meaning might need to be re-evaluated.
	              // For UBOs, we always want HOST_VISIBLE. For VBO/IBO, `dynamic` could mean HOST_VISIBLE.
) -> (gfx_interface.Gfx_Buffer, common.Engine_Error) {

	vk_dev_variant, ok_dev := gfx_device.variant.(vk_types.Vk_Device_Variant)
	if !ok_dev || vk_dev_variant == nil {
		return gfx_interface.Gfx_Buffer{}, common.Engine_Error.Invalid_Handle
	}
	vk_dev_internal := vk_dev_variant
	logical_device  := vk_dev_internal.logical_device
	physical_device := vk_dev_internal.physical_device_info.physical_device
	allocator       := vk_dev_internal.allocator
	p_vk_allocator: ^vk.AllocationCallbacks = nil

	if size_bytes <= 0 {
		return gfx_interface.Gfx_Buffer{}, common.Engine_Error.Invalid_Parameter
	}

	usage_flags: vk.BufferUsageFlags
	mem_props: vk.MemoryPropertyFlags

	is_uniform_buffer := false
	#partial switch buffer_type {
	case .Vertex:
		usage_flags |= {.VERTEX_BUFFER_BIT}
		// If dynamic, make it host visible for frequent updates. Otherwise, device local.
        // For now, keeping simple as before: all are HOST_VISIBLE.
        // if dynamic {
		// 	mem_props = {.HOST_VISIBLE_BIT, .HOST_COHERENT_BIT}
		// } else {
		// 	usage_flags |= {.TRANSFER_DST_BIT} // For initial upload via staging
		// 	mem_props = {.DEVICE_LOCAL_BIT}
		// }
        mem_props = {.HOST_VISIBLE_BIT, .HOST_COHERENT_BIT} 
	case .Index:
		usage_flags |= {.INDEX_BUFFER_BIT}
		// Similar memory strategy as Vertex buffers.
        // if dynamic {
		// 	mem_props = {.HOST_VISIBLE_BIT, .HOST_COHERENT_BIT}
		// } else {
		// 	usage_flags |= {.TRANSFER_DST_BIT}
		// 	mem_props = {.DEVICE_LOCAL_BIT}
		// }
        mem_props = {.HOST_VISIBLE_BIT, .HOST_COHERENT_BIT}
	case .Uniform:
		is_uniform_buffer = true
		usage_flags |= {.UNIFORM_BUFFER_BIT}
		// Uniform buffers are typically updated frequently from CPU, so HOST_VISIBLE and HOST_COHERENT.
		mem_props = {.HOST_VISIBLE_BIT, .HOST_COHERENT_BIT}
    case .Transfer_Src: // Added for staging buffers
        usage_flags |= {.TRANSFER_SRC_BIT}
        mem_props = {.HOST_VISIBLE_BIT, .HOST_COHERENT_BIT}
	}
    // If initial_data is provided and buffer is not HOST_VISIBLE (e.g. DEVICE_LOCAL),
    // it would require TRANSFER_DST_BIT for staging buffer copy.
    if initial_data != nil && !(.HOST_VISIBLE_BIT in mem_props) {
        usage_flags |= {.TRANSFER_DST_BIT}
    }


	buffer_create_info := vk.BufferCreateInfo{
		sType = .BUFFER_CREATE_INFO,
		size  = vk.DeviceSize(size_bytes),
		usage = usage_flags,
		sharingMode = .EXCLUSIVE,
	}
	
	buffer_handle: vk.Buffer
	result := vk.CreateBuffer(logical_device, &buffer_create_info, p_vk_allocator, &buffer_handle)
	if result != .SUCCESS {
		return gfx_interface.Gfx_Buffer{}, common.Engine_Error.Buffer_Creation_Failed
	}

	mem_reqs: vk.MemoryRequirements
	vk.GetBufferMemoryRequirements(logical_device, buffer_handle, &mem_reqs)

	memory_type_idx, found_mem_type := find_memory_type_internal(physical_device, mem_reqs.memoryTypeBits, mem_props)
	if !found_mem_type {
		vk.DestroyBuffer(logical_device, buffer_handle, p_vk_allocator)
		return gfx_interface.Gfx_Buffer{}, common.Engine_Error.Buffer_Creation_Failed
	}

	alloc_info := vk.MemoryAllocateInfo{
		sType           = .MEMORY_ALLOCATE_INFO,
		allocationSize  = mem_reqs.size,
		memoryTypeIndex = memory_type_idx,
	}
	device_memory: vk.DeviceMemory
	result = vk.AllocateMemory(logical_device, &alloc_info, p_vk_allocator, &device_memory)
	if result != .SUCCESS {
		vk.DestroyBuffer(logical_device, buffer_handle, p_vk_allocator)
		return gfx_interface.Gfx_Buffer{}, common.Engine_Error.Buffer_Creation_Failed
	}

	result = vk.BindBufferMemory(logical_device, buffer_handle, device_memory, 0)
	if result != .SUCCESS {
		vk.FreeMemory(logical_device, device_memory, p_vk_allocator)
		vk.DestroyBuffer(logical_device, buffer_handle, p_vk_allocator)
		return gfx_interface.Gfx_Buffer{}, common.Engine_Error.Buffer_Creation_Failed
	}

    mapped_data_ptr: rawptr = nil
	if is_uniform_buffer { // Persistently map UBOs
		map_result := vk.MapMemory(logical_device, device_memory, 0, mem_reqs.size, 0, &mapped_data_ptr)
		if map_result != .SUCCESS || mapped_data_ptr == nil {
			log.errorf("vkMapMemory failed for persistent mapping of UBO. Result: %v", map_result)
            vk.FreeMemory(logical_device, device_memory, p_vk_allocator)
            vk.DestroyBuffer(logical_device, buffer_handle, p_vk_allocator)
            return gfx_interface.Gfx_Buffer{}, common.Engine_Error.Buffer_Creation_Failed
		}
        log.debugf("Uniform Buffer %p persistently mapped to %p", buffer_handle, mapped_data_ptr)
        // If initial_data is provided for UBO, copy it now to the persistently mapped pointer
        if initial_data != nil {
            mem.copy(mapped_data_ptr, initial_data, int(size_bytes))
            // No unmap needed for persistently mapped coherent memory.
        }
	} else if initial_data != nil { // For non-UBOs with initial data (e.g. VBO/IBO)
		// This path assumes HOST_VISIBLE memory for VBO/IBO for simplicity of initial data upload.
        // If it were DEVICE_LOCAL, staging buffer would be needed here.
        temp_mapped_ptr: rawptr
		map_result := vk.MapMemory(logical_device, device_memory, 0, mem_reqs.size, 0, &temp_mapped_ptr)
		if map_result == .SUCCESS && temp_mapped_ptr != nil {
			mem.copy(temp_mapped_ptr, initial_data, int(size_bytes))
			vk.UnmapMemory(logical_device, device_memory)
		} else {
			log.errorf("vkMapMemory failed for initial data upload to non-UBO. Result: %v", map_result)
            vk.FreeMemory(logical_device, device_memory, p_vk_allocator)
            vk.DestroyBuffer(logical_device, buffer_handle, p_vk_allocator)
            return gfx_interface.Gfx_Buffer{}, common.Engine_Error.Buffer_Creation_Failed
		}
	}


	if is_uniform_buffer {
		ubo_info := new(vk_types.Vk_Uniform_Buffer_Info, allocator)
		ubo_info.buffer     = buffer_handle
		ubo_info.memory     = device_memory
		ubo_info.size       = mem_reqs.size
        ubo_info.mapped_ptr = mapped_data_ptr // Store the persistently mapped pointer
		ubo_info.device_ref = vk_dev_internal
		ubo_info.allocator  = allocator
		log.infof("Vulkan Uniform Buffer created: Gfx_Buffer wrapping Vk_Uniform_Buffer_Info %p", ubo_info)
		return gfx_interface.Gfx_Buffer{variant = ubo_info}, .None
	} else {
		vk_buffer_internal := new(vk_types.Vk_Buffer_Internal, allocator)
		vk_buffer_internal.buffer     = buffer_handle
		vk_buffer_internal.memory     = device_memory
		vk_buffer_internal.device_ref = vk_dev_internal
		vk_buffer_internal.size       = mem_reqs.size
		vk_buffer_internal.allocator  = allocator
		vk_buffer_internal.mapped_ptr = nil // Not persistently mapped for VBO/IBO by default
		log.infof("Vulkan Buffer created: Gfx_Buffer wrapping Vk_Buffer_Internal %p", vk_buffer_internal)
		return gfx_interface.Gfx_Buffer{variant = vk_buffer_internal}, .None
	}
}

vk_destroy_buffer_internal :: proc(buffer_handle_gfx: gfx_interface.Gfx_Buffer) {
    // Common cleanup logic for buffer and memory
    destroy_buffer_and_memory :: proc(buffer: vk.Buffer, memory: vk.DeviceMemory, device: vk.Device, p_vk_allocator: ^vk.AllocationCallbacks) {
        if buffer != vk.NULL_HANDLE {
            vk.DestroyBuffer(device, buffer, p_vk_allocator)
        }
        if memory != vk.NULL_HANDLE {
            vk.FreeMemory(device, memory, p_vk_allocator)
        }
    }

	p_vk_allocator: ^vk.AllocationCallbacks = nil
	
    // Try to assert as ^Vk_Buffer_Internal first
	if vk_buffer_ptr, ok_buf := buffer_handle_gfx.variant.(^vk_types.Vk_Buffer_Internal); ok_buf && vk_buffer_ptr != nil {
		if vk_buffer_ptr.device_ref != nil && vk_buffer_ptr.device_ref.logical_device != vk.NULL_HANDLE {
            logical_device := vk_buffer_ptr.device_ref.logical_device
            // If it was mapped for non-UBO (not persistent), ensure unmap (though current map_buffer is temporary)
            if vk_buffer_ptr.mapped_ptr != nil { // This implies a map call without unmap if not UBO
                log.warnf("Vk_Buffer_Internal %p was still mapped during destruction. Unmapping now.", vk_buffer_ptr.buffer)
                vk.UnmapMemory(logical_device, vk_buffer_ptr.memory)
            }
			destroy_buffer_and_memory(vk_buffer_ptr.buffer, vk_buffer_ptr.memory, logical_device, p_vk_allocator)
			log.infof("Vk_Buffer_Internal %p destroyed.", vk_buffer_ptr)
			free(vk_buffer_ptr, vk_buffer_ptr.allocator)
		} else {
            log.error("vk_destroy_buffer_internal: device_ref or logical_device is nil for Vk_Buffer_Internal.")
        }
		return
	}

    // Try to assert as ^Vk_Uniform_Buffer_Info
	if ubo_info_ptr, ok_ubo := buffer_handle_gfx.variant.(^vk_types.Vk_Uniform_Buffer_Info); ok_ubo && ubo_info_ptr != nil {
		if ubo_info_ptr.device_ref != nil && ubo_info_ptr.device_ref.logical_device != vk.NULL_HANDLE {
            logical_device := ubo_info_ptr.device_ref.logical_device
            if ubo_info_ptr.mapped_ptr != nil { // Persistently mapped
                vk.UnmapMemory(logical_device, ubo_info_ptr.memory)
                log.debugf("Unmapped persistently mapped UBO %p", ubo_info_ptr.buffer)
            }
			destroy_buffer_and_memory(ubo_info_ptr.buffer, ubo_info_ptr.memory, logical_device, p_vk_allocator)
			log.infof("Vk_Uniform_Buffer_Info %p destroyed.", ubo_info_ptr)
			free(ubo_info_ptr, ubo_info_ptr.allocator)
		} else {
            log.error("vk_destroy_buffer_internal: device_ref or logical_device is nil for Vk_Uniform_Buffer_Info.")
        }
		return
	}

	log.errorf("vk_destroy_buffer_internal: Invalid Gfx_Buffer variant type (%T) or nil pointer.", buffer_handle_gfx.variant)
}


vk_map_buffer_internal :: proc(
	buffer_handle_gfx: gfx_interface.Gfx_Buffer,
	offset_bytes: int, 
	size_bytes: int,   
) -> rawptr {
    // Handle Vk_Buffer_Internal (typically for VBO/IBO, temporary mapping)
	if vk_buffer_ptr, ok_buf := buffer_handle_gfx.variant.(^vk_types.Vk_Buffer_Internal); ok_buf && vk_buffer_ptr != nil {
        if vk_buffer_ptr.device_ref == nil { log.error("vk_map_buffer: nil device_ref in Vk_Buffer_Internal"); return nil }
        logical_device := vk_buffer_ptr.device_ref.logical_device

        if vk_buffer_ptr.mapped_ptr != nil { // Should not happen for non-persistent
            log.warnf("Vk_Buffer_Internal %p already has a mapped_ptr. This indicates an issue or previous unmap was missed.", vk_buffer_ptr.buffer)
            // return (^u8)(vk_buffer_ptr.mapped_ptr) + offset_bytes; // Risky, might be stale
        }
        
        actual_offset := vk.DeviceSize(offset_bytes)
        actual_size   := vk.DeviceSize(size_bytes)
        if size_bytes == -1 { actual_size = vk_buffer_ptr.size - actual_offset }
        // Basic validation
        if actual_offset >= vk_buffer_ptr.size || actual_offset + actual_size > vk_buffer_ptr.size {
            log.errorf("vk_map_buffer: Invalid map range for Vk_Buffer_Internal. Offset: %v, Size: %v, Buffer Size: %v", actual_offset, actual_size, vk_buffer_ptr.size)
            return nil
        }

        mapped_data: rawptr
        result := vk.MapMemory(logical_device, vk_buffer_ptr.memory, actual_offset, actual_size, 0, &mapped_data)
        if result == .SUCCESS && mapped_data != nil {
            vk_buffer_ptr.mapped_ptr = mapped_data // Store for unmap
            return mapped_data
        }
        log.errorf("vkMapMemory failed for Vk_Buffer_Internal %p: %v", vk_buffer_ptr.buffer, result)
        return nil
	}

    // Handle Vk_Uniform_Buffer_Info (already persistently mapped)
    if ubo_info_ptr, ok_ubo := buffer_handle_gfx.variant.(^vk_types.Vk_Uniform_Buffer_Info); ok_ubo && ubo_info_ptr != nil {
        if ubo_info_ptr.mapped_ptr == nil {
            log.errorf("Vk_Uniform_Buffer_Info %p is not mapped, but should be persistently mapped.", ubo_info_ptr.buffer)
            return nil
        }
        // For persistently mapped UBOs, just return the mapped pointer + offset.
        // Ensure requested range is valid.
        actual_offset := vk.DeviceSize(offset_bytes)
        actual_size   := vk.DeviceSize(size_bytes)
        if size_bytes == -1 { actual_size = ubo_info_ptr.size - actual_offset }

        if actual_offset >= ubo_info_ptr.size || actual_offset + actual_size > ubo_info_ptr.size {
             log.errorf("vk_map_buffer: Invalid map range for Vk_Uniform_Buffer_Info. Offset: %v, Size: %v, Buffer Size: %v", actual_offset, actual_size, ubo_info_ptr.size)
            return nil
        }
        return (^u8)(ubo_info_ptr.mapped_ptr) + int(actual_offset) // Pointer arithmetic
    }

	log.errorf("vk_map_buffer: Invalid Gfx_Buffer variant type (%T) or nil pointer.", buffer_handle_gfx.variant)
	return nil
}

vk_unmap_buffer_internal :: proc(buffer_handle_gfx: gfx_interface.Gfx_Buffer) {
    // Handle Vk_Buffer_Internal (temporary mapping)
	if vk_buffer_ptr, ok_buf := buffer_handle_gfx.variant.(^vk_types.Vk_Buffer_Internal); ok_buf && vk_buffer_ptr != nil {
        if vk_buffer_ptr.device_ref == nil { log.error("vk_unmap_buffer: nil device_ref in Vk_Buffer_Internal"); return }
        logical_device := vk_buffer_ptr.device_ref.logical_device

        if vk_buffer_ptr.mapped_ptr == nil {
            log.warnf("vk_unmap_buffer called on Vk_Buffer_Internal %p that was not mapped or already unmapped.", vk_buffer_ptr.buffer)
            return
        }
        vk.UnmapMemory(logical_device, vk_buffer_ptr.memory)
        vk_buffer_ptr.mapped_ptr = nil 
        return
	}

    // Handle Vk_Uniform_Buffer_Info (persistently mapped, unmap is a no-op from user perspective)
    if ubo_info_ptr, ok_ubo := buffer_handle_gfx.variant.(^vk_types.Vk_Uniform_Buffer_Info); ok_ubo && ubo_info_ptr != nil {
        // Persistently mapped buffers are typically unmapped only on destruction.
        // This call can be a no-op or log a warning if called explicitly by user on a UBO.
        log.debugf("vk_unmap_buffer called on persistently mapped Vk_Uniform_Buffer_Info %p. No explicit unmap action taken here.", ubo_info_ptr.buffer)
        return
    }

	log.errorf("vk_unmap_buffer: Invalid Gfx_Buffer variant type (%T) or nil pointer.", buffer_handle_gfx.variant)
}


// vk_update_buffer_internal updates a region of a Vulkan buffer.
// For UBOs, this means copying to the persistently mapped pointer.
// For other buffers, it uses a temporary map if HOST_VISIBLE, otherwise would need staging.
// Current implementation assumes HOST_VISIBLE for simplicity if not UBO.
vk_update_buffer_internal :: proc(
    buffer_handle_gfx: gfx_interface.Gfx_Buffer, 
    offset: int, 
    data: rawptr, 
    size: int,
) -> common.Engine_Error {
    if data == nil || size <= 0 { return common.Engine_Error.Invalid_Parameter }

    // Handle Vk_Uniform_Buffer_Info (persistently mapped)
    if ubo_info, ok_ubo := buffer_handle_gfx.variant.(^vk_types.Vk_Uniform_Buffer_Info); ok_ubo && ubo_info != nil {
        if ubo_info.mapped_ptr == nil {
            log.errorf("Vk_Uniform_Buffer_Info %p is not mapped. Cannot update.", ubo_info.buffer)
            return common.Engine_Error.Invalid_Operation // Should have been mapped on creation
        }
        if offset < 0 || vk.DeviceSize(offset + size) > ubo_info.size {
            log.errorf("Update region out of bounds for UBO %p.", ubo_info.buffer)
            return common.Engine_Error.Invalid_Parameter
        }
        dst_ptr := (^u8)(ubo_info.mapped_ptr) + offset
        mem.copy(dst_ptr, data, size)
        // No flush needed due to HOST_COHERENT memory property.
        return .None
    }

    // Handle Vk_Buffer_Internal (temporary map for update)
    if vk_buffer, ok_buf := buffer_handle_gfx.variant.(^vk_types.Vk_Buffer_Internal); ok_buf && vk_buffer != nil {
        if vk_buffer.device_ref == nil { return common.Engine_Error.Invalid_Handle }
        logical_device := vk_buffer.device_ref.logical_device

        if offset < 0 || vk.DeviceSize(offset + size) > vk_buffer.size {
             log.errorf("Update region out of bounds for buffer %p.", vk_buffer.buffer)
            return common.Engine_Error.Invalid_Parameter
        }
        
        // Assuming HOST_VISIBLE and HOST_COHERENT for simplicity for non-UBOs too
        mapped_ptr: rawptr
        map_res := vk.MapMemory(logical_device, vk_buffer.memory, vk.DeviceSize(offset), vk.DeviceSize(size), 0, &mapped_ptr)
        if map_res != .SUCCESS || mapped_ptr == nil {
            log.errorf("Failed to map buffer %p for update: %v", vk_buffer.buffer, map_res)
            return common.Engine_Error.Vulkan_Error
        }
        mem.copy(mapped_ptr, data, size)
        vk.UnmapMemory(logical_device, vk_buffer.memory)
        return .None
    }
    
    log.errorf("vk_update_buffer_internal: Invalid Gfx_Buffer variant type (%T) or nil pointer.", buffer_handle_gfx.variant)
    return common.Engine_Error.Invalid_Handle
}
