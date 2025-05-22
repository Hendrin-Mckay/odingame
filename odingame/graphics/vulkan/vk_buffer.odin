package vulkan

import vk "vendor:vulkan"
import "core:log"
import "core:mem"
import "../gfx_interface" // For Gfx_Device, Gfx_Error, Gfx_Buffer, Buffer_Type

// Vk_Buffer_Internal holds the Vulkan-specific buffer data.
Vk_Buffer_Internal :: struct {
	buffer:          vk.Buffer,
	memory:          vk.DeviceMemory,
	device_ref:      ^Vk_Device_Internal, // Reference to the logical device & physical device info
	size:            vk.DeviceSize,     // Size of the buffer in bytes
	allocator:       mem.Allocator,     // Allocator used for this struct
	mapped_ptr:      rawptr,            // Pointer to mapped memory, if currently mapped
	// For persistent mapping, one might store usage flags (host_visible, coherent, cached)
}

// find_memory_type_internal finds a suitable memory type index.
find_memory_type_internal :: proc(
	physical_device_handle: vk.PhysicalDevice,
	type_filter: u32, // Bitmask of allowed memory type indices from vk.MemoryRequirements
	properties: vk.MemoryPropertyFlags, // Required memory properties (e.g., HOST_VISIBLE, DEVICE_LOCAL)
) -> (
	memory_type_index: u32,
	found: bool,
) {
	mem_properties: vk.PhysicalDeviceMemoryProperties
	vk.GetPhysicalDeviceMemoryProperties(physical_device_handle, &mem_properties)

	for i := u32(0); i < mem_properties.memoryTypeCount; i = i + 1 {
		// Check if this memory type is allowed by the type_filter
		if (type_filter & (1 << i)) != 0 {
			// Check if this memory type has all the required properties
			if (mem_properties.memoryTypes[i].propertyFlags & properties) == properties {
				log.debugf("Found suitable memory type: Index %d, Flags %#x", i, mem_properties.memoryTypes[i].propertyFlags)
				return i, true
			}
		}
	}

	log.errorf("Failed to find suitable memory type. Filter: %#x, Required Properties: %#x", type_filter, properties)
	// Log available memory types for debugging
	for i := u32(0); i < mem_properties.memoryTypeCount; i = i + 1 {
		log.debugf("  Available Memory Type %d: Flags %#x, Heap Index %d", i, mem_properties.memoryTypes[i].propertyFlags, mem_properties.memoryTypes[i].heapIndex)
		log.debugf("    Heap %d: Size %v bytes, Flags %#x", mem_properties.memoryTypes[i].heapIndex, mem_properties.memoryHeaps[mem_properties.memoryTypes[i].heapIndex].size, mem_properties.memoryHeaps[mem_properties.memoryTypes[i].heapIndex].flags)
	}
	return 0, false
}


// vk_create_buffer_internal creates a Vulkan buffer, allocates memory, and optionally uploads initial data.
vk_create_buffer_internal :: proc(
	gfx_device: gfx_interface.Gfx_Device,
	buffer_type: gfx_interface.Buffer_Type,
	size_bytes: int, // Renamed from 'size' to avoid conflict with Vk_Buffer_Internal.size
	initial_data: rawptr,
	dynamic: bool, // Hint for memory properties, though currently all are host-visible
) -> (gfx_interface.Gfx_Buffer, gfx_interface.Gfx_Error) {

	vk_dev_internal, ok_dev := gfx_device.variant.(Vk_Device_Variant)
	if !ok_dev || vk_dev_internal == nil {
		log.error("vk_create_buffer: Invalid Gfx_Device (not Vulkan or nil variant).")
		return gfx_interface.Gfx_Buffer{}, .Invalid_Handle
	}
	logical_device := vk_dev_internal.logical_device
	physical_device := vk_dev_internal.physical_device_info.physical_device
	allocator := vk_dev_internal.allocator // Use device's allocator for the Vk_Buffer_Internal struct

	if size_bytes <= 0 {
		log.errorf("Buffer size must be positive. Requested: %d", size_bytes)
		return gfx_interface.Gfx_Buffer{}, .Buffer_Creation_Failed // Or Invalid_Parameter
	}

	// 1. Determine Buffer Usage
	usage_flags: vk.BufferUsageFlags
	#partial switch buffer_type {
	case .Vertex:
		usage_flags |= {.VERTEX_BUFFER_BIT}
	case .Index:
		usage_flags |= {.INDEX_BUFFER_BIT}
	case .Uniform:
		usage_flags |= {.UNIFORM_BUFFER_BIT}
	// case .Storage: usage_flags |= {.STORAGE_BUFFER_BIT} // For future
	// case .Staging: usage_flags |= {.TRANSFER_SRC_BIT}   // For future
	}
	// If initial_data is provided, buffer might also need TRANSFER_DST_BIT if we used a staging buffer.
	// For direct mapping, it's not strictly needed for the buffer itself.
	log.debugf("Creating buffer: Type %v, Size %d bytes, UsageFlags %#x", buffer_type, size_bytes, usage_flags)

	// 2. Create Buffer
	buffer_create_info := vk.BufferCreateInfo{
		sType = .BUFFER_CREATE_INFO,
		size = vk.DeviceSize(size_bytes),
		usage = usage_flags,
		sharingMode = .EXCLUSIVE, // Assuming not sharing buffers between queue families for now
		// flags can be .SPARSE_BINDING_BIT etc.
	}
	p_vk_allocator: ^vk.AllocationCallbacks = nil // Using nil for Vulkan allocation callbacks
	buffer_handle: vk.Buffer
	result := vk.CreateBuffer(logical_device, &buffer_create_info, p_vk_allocator, &buffer_handle)
	if result != .SUCCESS {
		log.errorf("vkCreateBuffer failed. Result: %v (%d)", result, int(result))
		return gfx_interface.Gfx_Buffer{}, .Buffer_Creation_Failed
	}
	log.debugf("Vulkan Buffer created successfully: %p", buffer_handle)

	// 3. Get Memory Requirements
	mem_reqs: vk.MemoryRequirements
	vk.GetBufferMemoryRequirements(logical_device, buffer_handle, &mem_reqs)
	log.debugf("Buffer memory requirements: Size %v, Alignment %v, TypeFilter %#x", mem_reqs.size, mem_reqs.alignment, mem_reqs.memoryTypeBits)

	// 4. Determine Memory Properties
	// For now, all buffers are host-visible and coherent for simplicity with initial data upload and mapping.
	// `dynamic` flag is a hint but not fully utilized yet to differentiate DEVICE_LOCAL.
	// TODO: Use `DEVICE_LOCAL_BIT` for static buffers and implement staging buffer uploads.
	mem_props: vk.MemoryPropertyFlags = {.HOST_VISIBLE_BIT, .HOST_COHERENT_BIT}
	// if !dynamic && initial_data != nil { 
	//    mem_props = {.DEVICE_LOCAL_BIT} // Ideal for static data, would require staging
	// }

	// 5. Find Suitable Memory Type
	memory_type_idx, found_mem_type := find_memory_type_internal(physical_device, mem_reqs.memoryTypeBits, mem_props)
	if !found_mem_type {
		log.error("Failed to find suitable memory type for buffer.")
		vk.DestroyBuffer(logical_device, buffer_handle, p_vk_allocator) // Cleanup created buffer
		return gfx_interface.Gfx_Buffer{}, .Buffer_Creation_Failed
	}

	// 6. Allocate Memory
	alloc_info := vk.MemoryAllocateInfo{
		sType = .MEMORY_ALLOCATE_INFO,
		allocationSize = mem_reqs.size, // Use reported size from mem_reqs
		memoryTypeIndex = memory_type_idx,
	}
	device_memory: vk.DeviceMemory
	result = vk.AllocateMemory(logical_device, &alloc_info, p_vk_allocator, &device_memory)
	if result != .SUCCESS {
		log.errorf("vkAllocateMemory failed for buffer. Result: %v (%d)", result, int(result))
		vk.DestroyBuffer(logical_device, buffer_handle, p_vk_allocator) // Cleanup
		return gfx_interface.Gfx_Buffer{}, .Buffer_Creation_Failed
	}
	log.debugf("Device memory allocated for buffer: %p (Size: %v, TypeIndex: %d)", device_memory, mem_reqs.size, memory_type_idx)

	// 7. Bind Buffer Memory
	// The offset for binding is usually 0.
	result = vk.BindBufferMemory(logical_device, buffer_handle, device_memory, 0)
	if result != .SUCCESS {
		log.errorf("vkBindBufferMemory failed. Result: %v (%d)", result, int(result))
		vk.FreeMemory(logical_device, device_memory, p_vk_allocator) // Cleanup
		vk.DestroyBuffer(logical_device, buffer_handle, p_vk_allocator) // Cleanup
		return gfx_interface.Gfx_Buffer{}, .Buffer_Creation_Failed
	}
	log.debug("Memory bound to buffer successfully.")

	// 8. Upload Initial Data (if provided)
	if initial_data != nil {
		log.debugf("Uploading initial data to buffer %p (%d bytes)...", buffer_handle, size_bytes)
		mapped_data_ptr: rawptr
		// Map the entire buffer for simplicity (offset 0, size buffer_create_info.size).
		map_result := vk.MapMemory(logical_device, device_memory, 0, buffer_create_info.size, 0, &mapped_data_ptr)
		if map_result == .SUCCESS && mapped_data_ptr != nil {
			mem.copy(mapped_data_ptr, initial_data, int(size_bytes))
			// HOST_COHERENT_BIT ensures writes are visible without explicit flush, assuming it's set.
			// If not coherent, would need:
			// flushed_range := vk.MappedMemoryRange{ sType = .MAPPED_MEMORY_RANGE, memory = device_memory, offset = 0, size = vk.WHOLE_SIZE }
			// vk.FlushMappedMemoryRanges(logical_device, 1, &flushed_range)
			vk.UnmapMemory(logical_device, device_memory)
			log.debug("Initial data uploaded and memory unmapped.")
		} else {
			log.errorf("vkMapMemory failed for initial data upload. Result: %v", map_result)
			// Cleanup everything as upload failed
			vk.FreeMemory(logical_device, device_memory, p_vk_allocator)
			vk.DestroyBuffer(logical_device, buffer_handle, p_vk_allocator)
			return gfx_interface.Gfx_Buffer{}, .Buffer_Creation_Failed
		}
	}

	// 9. Store Buffer Info
	vk_buffer_internal := new(Vk_Buffer_Internal, allocator)
	vk_buffer_internal.buffer = buffer_handle
	vk_buffer_internal.memory = device_memory
	vk_buffer_internal.device_ref = vk_dev_internal
	vk_buffer_internal.size = buffer_create_info.size // Store actual allocated size (could be mem_reqs.size)
	vk_buffer_internal.allocator = allocator
	vk_buffer_internal.mapped_ptr = nil // Not persistently mapped by default

	log.infof("Vulkan buffer created and initialized: Gfx_Buffer wrapping Vk_Buffer_Internal %p (Buffer: %p, Memory: %p, Size: %v)",
		vk_buffer_internal, buffer_handle, device_memory, vk_buffer_internal.size)
	
	return gfx_interface.Gfx_Buffer{variant = vk_buffer_internal}, .None
}

// vk_destroy_buffer_internal destroys a Vulkan buffer and frees its memory.
vk_destroy_buffer_internal :: proc(buffer_handle_gfx: gfx_interface.Gfx_Buffer) {
	vk_buffer_ptr, ok_buf := buffer_handle_gfx.variant.(^Vk_Buffer_Internal)
	if !ok_buf || vk_buffer_ptr == nil {
		log.errorf("vk_destroy_buffer: Invalid Gfx_Buffer type or nil variant (%v).", buffer_handle_gfx.variant)
		return
	}

	buffer_internal := vk_buffer_ptr^ // Dereference to get the struct
	logical_device := buffer_internal.device_ref.logical_device
	p_vk_allocator: ^vk.AllocationCallbacks = nil

	// Ensure buffer is unmapped if it was persistently mapped (not current design, but good practice)
	if buffer_internal.mapped_ptr != nil {
		log.warnf("Buffer %p was still mapped during destruction. Unmapping now.", buffer_internal.buffer)
		vk.UnmapMemory(logical_device, buffer_internal.memory)
		// vk_buffer_ptr.mapped_ptr = nil // Not strictly needed as we are freeing vk_buffer_ptr
	}

	if buffer_internal.buffer != vk.NULL_HANDLE {
		log.debugf("Destroying Vulkan Buffer: %p", buffer_internal.buffer)
		vk.DestroyBuffer(logical_device, buffer_internal.buffer, p_vk_allocator)
	}
	if buffer_internal.memory != vk.NULL_HANDLE {
		log.debugf("Freeing Vulkan DeviceMemory: %p", buffer_internal.memory)
		vk.FreeMemory(logical_device, buffer_internal.memory, p_vk_allocator)
	}
	
	log.infof("Vk_Buffer_Internal %p destroyed (Buffer: %p, Memory: %p)", 
		vk_buffer_ptr, buffer_internal.buffer, buffer_internal.memory)
	
	// Free the Vk_Buffer_Internal struct itself
	free(vk_buffer_ptr, buffer_internal.allocator)
}

// vk_map_buffer_internal maps a Vulkan buffer's memory for CPU access.
vk_map_buffer_internal :: proc(
	buffer_handle_gfx: gfx_interface.Gfx_Buffer,
	offset_bytes: int, // Renamed from offset
	size_bytes: int,   // Renamed from size
) -> rawptr {
	vk_buffer_ptr, ok_buf := buffer_handle_gfx.variant.(^Vk_Buffer_Internal)
	if !ok_buf || vk_buffer_ptr == nil {
		log.errorf("vk_map_buffer: Invalid Gfx_Buffer type or nil variant (%v).", buffer_handle_gfx.variant)
		return nil
	}
	buffer_internal := vk_buffer_ptr^
	logical_device := buffer_internal.device_ref.logical_device

	if buffer_internal.mapped_ptr != nil {
		// This implies either persistent mapping (which we aren't fully set up for managing access)
		// or a previous map call without a corresponding unmap.
		log.warnf("Buffer %p is already mapped (or was mapped without unmap). Returning existing mapped pointer + offset.", buffer_internal.buffer)
		return (^u8)(buffer_internal.mapped_ptr) + offset_bytes
	}
	
	// Validate offset and size against buffer_internal.size
	if offset_bytes < 0 || vk.DeviceSize(offset_bytes) >= buffer_internal.size {
		log.errorf("vk_map_buffer: Invalid offset %d for buffer of size %v.", offset_bytes, buffer_internal.size)
		return nil
	}
	map_size := vk.DeviceSize(size_bytes)
	if size_bytes == -1 { // Convention for mapping whole buffer (or from offset to end)
		map_size = buffer_internal.size - vk.DeviceSize(offset_bytes)
	}
	if vk.DeviceSize(offset_bytes) + map_size > buffer_internal.size {
		log.warnf("vk_map_buffer: Requested map size (%d bytes from offset %d) exceeds buffer size (%v bytes). Clamping size.", 
			size_bytes, offset_bytes, buffer_internal.size)
		map_size = buffer_internal.size - vk.DeviceSize(offset_bytes)
	}
	if map_size == 0 {
		log.warn("vk_map_buffer: Calculated map size is 0.")
		return nil
	}

	log.debugf("Mapping buffer %p (Memory: %p), Offset: %d, Size: %v", 
		buffer_internal.buffer, buffer_internal.memory, offset_bytes, map_size)
	
	mapped_data_ptr: rawptr
	result := vk.MapMemory(logical_device, buffer_internal.memory, vk.DeviceSize(offset_bytes), map_size, 0, &mapped_data_ptr)
	
	if result == .SUCCESS && mapped_data_ptr != nil {
		// Store the base mapped pointer if we were to support persistent mapping checks.
		// For now, map/unmap are treated as paired calls by the user for a specific operation.
		// vk_buffer_ptr.mapped_ptr = mapped_data_ptr; // If we wanted to track the base of this specific map.
		// However, `Gfx_Buffer` interface implies map gives a pointer, unmap takes no pointer.
		// So, the `mapped_ptr` in `Vk_Buffer_Internal` is more for if the buffer itself is "globally" mapped.
		// Let's assume vkMapMemory/vkUnmapMemory are always paired by the user of Gfx_Buffer.
		// We can store the most recent mapped pointer to ensure unmap is called on that.
		vk_buffer_ptr.mapped_ptr = mapped_data_ptr // Store the pointer returned by THIS map call.
		log.debugf("Buffer %p mapped successfully. Pointer: %p", buffer_internal.buffer, mapped_data_ptr)
		return mapped_data_ptr
	} else {
		log.errorf("vkMapMemory failed for buffer %p. Result: %v", buffer_internal.buffer, result)
		return nil
	}
}

// vk_unmap_buffer_internal unmaps a previously mapped Vulkan buffer.
vk_unmap_buffer_internal :: proc(buffer_handle_gfx: gfx_interface.Gfx_Buffer) {
	vk_buffer_ptr, ok_buf := buffer_handle_gfx.variant.(^Vk_Buffer_Internal)
	if !ok_buf || vk_buffer_ptr == nil {
		log.errorf("vk_unmap_buffer: Invalid Gfx_Buffer type or nil variant (%v).", buffer_handle_gfx.variant)
		return
	}
	buffer_internal := vk_buffer_ptr^
	logical_device := buffer_internal.device_ref.logical_device

	// HOST_COHERENT memory doesn't strictly need flushing before unmap,
	// but if it weren't coherent, vkFlushMappedMemoryRanges would be needed here before unmap.
	// vk.UnmapMemory itself makes host writes visible to device.

	if buffer_internal.mapped_ptr == nil && vk_buffer_ptr.mapped_ptr == nil { // Check both, struct might have been copied
		log.warnf("vk_unmap_buffer called on buffer %p that was not mapped (or already unmapped).", buffer_internal.buffer)
		return
	}
	
	log.debugf("Unmapping buffer %p (Memory: %p)", buffer_internal.buffer, buffer_internal.memory)
	vk.UnmapMemory(logical_device, buffer_internal.memory)
	vk_buffer_ptr.mapped_ptr = nil // Clear the stored mapped pointer
	log.debug("Buffer unmapped successfully.")
}
