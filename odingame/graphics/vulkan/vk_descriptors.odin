package vulkan

import vk "vendor:vulkan"
import "../../common"
import "../gfx_interface"
import "./vk_types"
import "core:log"
import "core:mem"
import "core:strings" // For uniform name comparison if used, not for this simplified version

// Vk_Descriptor_Set_Layout_Binding_Info describes a single binding within a descriptor set layout.
Vk_Descriptor_Set_Layout_Binding_Info :: struct {
	binding         : u32,
	descriptor_type : vk.DescriptorType,
	descriptor_count: u32, 
	stage_flags     : vk.ShaderStageFlags,
}

vk_create_descriptor_set_layout_internal :: proc(
	device_internal: ^vk_types.Vk_Device_Internal,
	bindings: []Vk_Descriptor_Set_Layout_Binding_Info,
) -> (vk.DescriptorSetLayout, common.Engine_Error) {
	if device_internal == nil || device_internal.logical_device == vk.NULL_HANDLE {
		return vk.NULL_HANDLE, common.Engine_Error.Invalid_Handle
	}
	logical_device := device_internal.logical_device
	p_vk_allocator: ^vk.AllocationCallbacks = nil
    
    vk_bindings_temp := make([]vk.DescriptorSetLayoutBinding, len(bindings), context.temp_allocator)
	// defer delete(vk_bindings_temp) // This will be an issue if vk_bindings_temp is stack allocated based on len(bindings)

	for i, binding_info in bindings {
		vk_bindings_temp[i] = vk.DescriptorSetLayoutBinding{
			binding            = binding_info.binding,
			descriptorType     = binding_info.descriptor_type,
			descriptorCount    = binding_info.descriptor_count,
			stageFlags         = binding_info.stage_flags,
			pImmutableSamplers = nil, 
		}
	}
	layout_info := vk.DescriptorSetLayoutCreateInfo{
		sType        = .DESCRIPTOR_SET_LAYOUT_CREATE_INFO,
		bindingCount = u32(len(bindings)),
		pBindings    = rawptr(vk_bindings_temp.data) if len(bindings) > 0 else nil,
	}
	descriptor_set_layout: vk.DescriptorSetLayout
	if vk.CreateDescriptorSetLayout(logical_device, &layout_info, p_vk_allocator, &descriptor_set_layout) != .SUCCESS {
		return vk.NULL_HANDLE, common.Engine_Error.Vulkan_Error 
	}
	return descriptor_set_layout, .None
}

vk_destroy_descriptor_set_layout_internal :: proc( device_internal: ^vk_types.Vk_Device_Internal, layout: vk.DescriptorSetLayout) -> common.Engine_Error {
    if device_internal == nil {
        log.error("vk_destroy_descriptor_set_layout_internal: device_internal is nil.")
        return common.Engine_Error.Invalid_Handle
    }
    if device_internal.logical_device == vk.NULL_HANDLE {
        log.error("vk_destroy_descriptor_set_layout_internal: device_internal.logical_device is nil.")
        return common.Engine_Error.Invalid_Handle
    }
    if layout == vk.NULL_HANDLE {
        // Not an error to try to destroy a NULL handle, just a no-op.
        // log.info("vk_destroy_descriptor_set_layout_internal: layout is vk.NULL_HANDLE. Nothing to destroy.")
        return common.Engine_Error.None 
    }
    
    log.infof("Destroying Vulkan DescriptorSetLayout: %p on device %p", layout, device_internal.logical_device)
    p_vk_allocator: ^vk.AllocationCallbacks = nil
    vk.DestroyDescriptorSetLayout(device_internal.logical_device, layout, p_vk_allocator)
    return common.Engine_Error.None
}

vk_create_descriptor_pool_internal :: proc(
	device_internal: ^vk_types.Vk_Device_Internal,
	pool_sizes_param: []vk.DescriptorPoolSize, 
	max_sets: u32,
    flags: vk.DescriptorPoolCreateFlags = {},
) -> (vk.DescriptorPool, common.Engine_Error) {
	if device_internal == nil || device_internal.logical_device == vk.NULL_HANDLE { return vk.NULL_HANDLE, common.Engine_Error.Invalid_Handle }
	if len(pool_sizes_param) == 0 || max_sets == 0 { return vk.NULL_HANDLE, common.Engine_Error.Invalid_Parameter }
	logical_device := device_internal.logical_device
	p_vk_allocator: ^vk.AllocationCallbacks = nil
	pool_info := vk.DescriptorPoolCreateInfo{
		sType         = .DESCRIPTOR_POOL_CREATE_INFO,
		poolSizeCount = u32(len(pool_sizes_param)),
		pPoolSizes    = rawptr(pool_sizes_param.data),
		maxSets       = max_sets,
        flags         = flags, 
	}
	descriptor_pool: vk.DescriptorPool
	if vk.CreateDescriptorPool(logical_device, &pool_info, p_vk_allocator, &descriptor_pool) != .SUCCESS {
		return vk.NULL_HANDLE, common.Engine_Error.Vulkan_Error
	}
	return descriptor_pool, .None
}

vk_destroy_descriptor_pool_internal :: proc( device_internal: ^vk_types.Vk_Device_Internal, pool: vk.DescriptorPool,) {
    if device_internal == nil || device_internal.logical_device == vk.NULL_HANDLE || pool == vk.NULL_HANDLE { return }
    vk.DestroyDescriptorPool(device_internal.logical_device, pool, nil)
}

vk_allocate_descriptor_sets_internal :: proc(
	device_internal: ^vk_types.Vk_Device_Internal,
	descriptor_pool: vk.DescriptorPool, 
	set_layouts_param: []vk.DescriptorSetLayout, 
) -> ([]vk.DescriptorSet, common.Engine_Error) {
	if device_internal == nil || device_internal.logical_device == vk.NULL_HANDLE { return nil, common.Engine_Error.Invalid_Handle }
	if descriptor_pool == vk.NULL_HANDLE || len(set_layouts_param) == 0 { return nil, common.Engine_Error.Invalid_Parameter }
	logical_device := device_internal.logical_device
	allocator      := device_internal.allocator 
	alloc_info := vk.DescriptorSetAllocateInfo{
		sType              = .DESCRIPTOR_SET_ALLOCATE_INFO,
		descriptorPool     = descriptor_pool,
		descriptorSetCount = u32(len(set_layouts_param)),
		pSetLayouts        = rawptr(set_layouts_param.data),
	}
	descriptor_sets_slice := make([]vk.DescriptorSet, len(set_layouts_param), allocator)
	if vk.AllocateDescriptorSets(logical_device, &alloc_info, rawptr(descriptor_sets_slice.data)) != .SUCCESS {
		delete(descriptor_sets_slice, allocator) 
		return nil, common.Engine_Error.Vulkan_Error
	}
	return descriptor_sets_slice, .None
}

vk_free_descriptor_sets_internal :: proc(
    device_internal: ^vk_types.Vk_Device_Internal,
    descriptor_pool: vk.DescriptorPool,
    descriptor_sets: []vk.DescriptorSet,
) -> common.Engine_Error {
    if device_internal == nil || device_internal.logical_device == vk.NULL_HANDLE { return common.Engine_Error.Invalid_Handle }
	if descriptor_pool == vk.NULL_HANDLE || len(descriptor_sets) == 0 { return common.Engine_Error.Invalid_Parameter }
    if vk.FreeDescriptorSets(device_internal.logical_device, descriptor_pool, u32(len(descriptor_sets)), rawptr(descriptor_sets.data)) != .SUCCESS {
        return common.Engine_Error.Vulkan_Error
    }
    return .None
}

vk_update_descriptor_set_uniform_buffer_internal :: proc(
	device_internal: ^vk_types.Vk_Device_Internal,
	descriptor_set: vk.DescriptorSet,
	binding: u32,
	uniform_buffer_info: ^vk_types.Vk_Uniform_Buffer_Info, 
) {
	if device_internal == nil || descriptor_set == vk.NULL_HANDLE || uniform_buffer_info == nil { return }
	logical_device := device_internal.logical_device
	buffer_info := vk.DescriptorBufferInfo{
		buffer = uniform_buffer_info.buffer, offset = 0, range  = uniform_buffer_info.size, 
	}
	write_descriptor_set := vk.WriteDescriptorSet{
		sType = .WRITE_DESCRIPTOR_SET, dstSet = descriptor_set, dstBinding = binding, dstArrayElement  = 0, 
		descriptorCount  = 1, descriptorType = .UNIFORM_BUFFER, pBufferInfo = &buffer_info,
	}
	vk.UpdateDescriptorSets(logical_device, 1, &write_descriptor_set, 0, nil)
}

vk_update_descriptor_set_texture_internal :: proc(
	device_internal: ^vk_types.Vk_Device_Internal,
	descriptor_set: vk.DescriptorSet,
	binding: u32,
	texture_internal: ^vk_types.Vk_Texture_Internal, 
) {
	if device_internal == nil || descriptor_set == vk.NULL_HANDLE || texture_internal == nil { return }
    if texture_internal.image_view == vk.NULL_HANDLE || texture_internal.sampler == vk.NULL_HANDLE { return }
	logical_device := device_internal.logical_device
	image_info := vk.DescriptorImageInfo{
		sampler = texture_internal.sampler, imageView = texture_internal.image_view, imageLayout = texture_internal.current_layout, 
	}
	write_descriptor_set := vk.WriteDescriptorSet{
		sType = .WRITE_DESCRIPTOR_SET, dstSet = descriptor_set, dstBinding = binding, dstArrayElement = 0, 
		descriptorCount = 1, descriptorType = .COMBINED_IMAGE_SAMPLER, pImageInfo = &image_info,
	}
	vk.UpdateDescriptorSets(logical_device, 1, &write_descriptor_set, 0, nil)
}

// --- Higher-level uniform and texture binding functions ---

// vk_set_uniform_mat4_internal: Updates a UBO with a matrix and updates the current descriptor set.
// Assumes binding 0 for this UBO.
vk_set_uniform_mat4_internal :: proc(
    gfx_device_handle: gfx_interface.Gfx_Device, 
    // gfx_pipeline_handle: gfx_interface.Gfx_Pipeline, // Needed to get descriptor set layout info if not predefined
    // name: string, // For named uniforms; for now, assume fixed binding
    binding_for_ubo: u32, // The binding point in the descriptor set for this UBO
    mat: matrix[4,4]f32,
) -> common.Engine_Error {
    
    vk_dev_internal, ok_dev := gfx_device_handle.variant.(^vk_types.Vk_Device_Internal)
    if !ok_dev || vk_dev_internal == nil { return common.Engine_Error.Invalid_Handle }

    // Need the current window to get the current frame's UBO and descriptor set
    current_window_internal := vk_dev_internal.primary_window_for_pipeline
    if current_window_internal == nil {
        log.error("vk_set_uniform_mat4_internal: No primary window set on device, cannot determine current frame context.")
        return common.Engine_Error.Invalid_Operation
    }
    frame_idx := current_window_internal.current_frame_index

    // Get the UBO for the current frame
    ubo_info := &vk_dev_internal.uniform_buffers[frame_idx]
    if ubo_info.buffer == vk.NULL_HANDLE || ubo_info.mapped_ptr == nil {
        log.errorf("vk_set_uniform_mat4_internal: Frame %d UBO is invalid or not mapped.", frame_idx)
        return common.Engine_Error.Invalid_Handle
    }

    // Copy data to UBO (assuming mat4 is the only thing in this UBO for this binding for simplicity)
    // A more robust system would handle offsets within a larger UBO.
    if ubo_info.size < size_of(matrix[4,4]f32) {
        log.errorf("vk_set_uniform_mat4_internal: UBO size (%d) is too small for mat4 (%d).", 
            ubo_info.size, size_of(matrix[4,4]f32))
        return common.Engine_Error.Invalid_Parameter
    }
    mem.copy(ubo_info.mapped_ptr, &mat[0,0], size_of(matrix[4,4]f32))

    // Get current descriptor set for the frame
    current_descriptor_set := current_window_internal.current_descriptor_sets[frame_idx]
    if current_descriptor_set == vk.NULL_HANDLE {
        log.errorf("vk_set_uniform_mat4_internal: Frame %d has no valid descriptor set.", frame_idx)
        // This implies descriptor sets weren't allocated, possibly when pipeline was set.
        return common.Engine_Error.Invalid_Operation
    }

    // Update the descriptor set
    vk_update_descriptor_set_uniform_buffer_internal(vk_dev_internal, current_descriptor_set, binding_for_ubo, ubo_info)
    
    return .None
}

// vk_bind_texture_to_unit_internal: Updates the current descriptor set for a texture.
// Assumes 'unit' is the descriptor set binding for the texture.
vk_bind_texture_to_unit_internal :: proc(
    gfx_device_handle: gfx_interface.Gfx_Device, 
    gfx_texture_handle: gfx_interface.Gfx_Texture, 
    binding_for_texture: u32,
) -> common.Engine_Error {

    vk_dev_internal, ok_dev := gfx_device_handle.variant.(^vk_types.Vk_Device_Internal)
    if !ok_dev || vk_dev_internal == nil { return common.Engine_Error.Invalid_Handle }

    texture_internal_ptr, ok_tex := gfx_texture_handle.variant.(^vk_types.Vk_Texture_Internal)
    if !ok_tex || texture_internal_ptr == nil { return common.Engine_Error.Invalid_Handle }
    
    current_window_internal := vk_dev_internal.primary_window_for_pipeline
    if current_window_internal == nil {
        log.error("vk_bind_texture_to_unit_internal: No primary window set on device.")
        return common.Engine_Error.Invalid_Operation
    }
    frame_idx := current_window_internal.current_frame_index
    current_descriptor_set := current_window_internal.current_descriptor_sets[frame_idx]
    if current_descriptor_set == vk.NULL_HANDLE {
        log.errorf("vk_bind_texture_to_unit_internal: Frame %d has no valid descriptor set.", frame_idx)
        return common.Engine_Error.Invalid_Operation
    }

    // Ensure texture is in a layout suitable for sampling
    if texture_internal_ptr.current_layout != .SHADER_READ_ONLY_OPTIMAL &&
       texture_internal_ptr.current_layout != .GENERAL { // GENERAL can also be used for sampling
        log.warnf("vk_bind_texture_to_unit_internal: Texture %p is not in SHADER_READ_ONLY_OPTIMAL or GENERAL layout (current: %v). Attempting to use anyway.", 
            texture_internal_ptr.image, texture_internal_ptr.current_layout)
        // A robust implementation might attempt a transition here or error.
        // For now, we proceed, but this could lead to validation errors or incorrect rendering.
    }

    vk_update_descriptor_set_texture_internal(vk_dev_internal, current_descriptor_set, binding_for_texture, texture_internal_ptr)

    return .None
}

// --- Additional uniform setting internal functions ---

vk_set_uniform_vec2_internal :: proc(
    gfx_device_handle: gfx_interface.Gfx_Device, 
    binding_for_ubo: u32, 
    val: [2]f32,
) -> common.Engine_Error {
    vk_dev_internal, ok_dev := gfx_device_handle.variant.(^vk_types.Vk_Device_Internal)
    if !ok_dev || vk_dev_internal == nil { return common.Engine_Error.Invalid_Handle }

    current_window_internal := vk_dev_internal.primary_window_for_pipeline
    if current_window_internal == nil {
        log.error("vk_set_uniform_vec2_internal: No primary window set on device.")
        return common.Engine_Error.Invalid_Operation
    }
    frame_idx := current_window_internal.current_frame_index
    ubo_info := &vk_dev_internal.uniform_buffers[frame_idx]

    if ubo_info.buffer == vk.NULL_HANDLE || ubo_info.mapped_ptr == nil {
        log.errorf("vk_set_uniform_vec2_internal: Frame %d UBO is invalid or not mapped.", frame_idx)
        return common.Engine_Error.Invalid_Handle
    }
    if ubo_info.size < size_of([2]f32) {
        log.errorf("vk_set_uniform_vec2_internal: UBO size (%d) is too small for vec2 (%d).", 
            ubo_info.size, size_of([2]f32))
        return common.Engine_Error.Invalid_Parameter
    }
    mem.copy(ubo_info.mapped_ptr, &val[0], size_of([2]f32))

    current_descriptor_set := current_window_internal.current_descriptor_sets[frame_idx]
    if current_descriptor_set == vk.NULL_HANDLE {
        log.errorf("vk_set_uniform_vec2_internal: Frame %d has no valid descriptor set.", frame_idx)
        return common.Engine_Error.Invalid_Operation
    }
    vk_update_descriptor_set_uniform_buffer_internal(vk_dev_internal, current_descriptor_set, binding_for_ubo, ubo_info)
    return .None
}

vk_set_uniform_vec3_internal :: proc(
    gfx_device_handle: gfx_interface.Gfx_Device, 
    binding_for_ubo: u32, 
    val: [3]f32,
) -> common.Engine_Error {
    vk_dev_internal, ok_dev := gfx_device_handle.variant.(^vk_types.Vk_Device_Internal)
    if !ok_dev || vk_dev_internal == nil { return common.Engine_Error.Invalid_Handle }

    current_window_internal := vk_dev_internal.primary_window_for_pipeline
    if current_window_internal == nil {
        log.error("vk_set_uniform_vec3_internal: No primary window set on device.")
        return common.Engine_Error.Invalid_Operation
    }
    frame_idx := current_window_internal.current_frame_index
    ubo_info := &vk_dev_internal.uniform_buffers[frame_idx]

    if ubo_info.buffer == vk.NULL_HANDLE || ubo_info.mapped_ptr == nil {
        log.errorf("vk_set_uniform_vec3_internal: Frame %d UBO is invalid or not mapped.", frame_idx)
        return common.Engine_Error.Invalid_Handle
    }
    if ubo_info.size < size_of([3]f32) {
        log.errorf("vk_set_uniform_vec3_internal: UBO size (%d) is too small for vec3 (%d).", 
            ubo_info.size, size_of([3]f32))
        return common.Engine_Error.Invalid_Parameter
    }
    mem.copy(ubo_info.mapped_ptr, &val[0], size_of([3]f32))

    current_descriptor_set := current_window_internal.current_descriptor_sets[frame_idx]
    if current_descriptor_set == vk.NULL_HANDLE {
        log.errorf("vk_set_uniform_vec3_internal: Frame %d has no valid descriptor set.", frame_idx)
        return common.Engine_Error.Invalid_Operation
    }
    vk_update_descriptor_set_uniform_buffer_internal(vk_dev_internal, current_descriptor_set, binding_for_ubo, ubo_info)
    return .None
}

vk_set_uniform_vec4_internal :: proc(
    gfx_device_handle: gfx_interface.Gfx_Device, 
    binding_for_ubo: u32, 
    val: [4]f32,
) -> common.Engine_Error {
    vk_dev_internal, ok_dev := gfx_device_handle.variant.(^vk_types.Vk_Device_Internal)
    if !ok_dev || vk_dev_internal == nil { return common.Engine_Error.Invalid_Handle }

    current_window_internal := vk_dev_internal.primary_window_for_pipeline
    if current_window_internal == nil {
        log.error("vk_set_uniform_vec4_internal: No primary window set on device.")
        return common.Engine_Error.Invalid_Operation
    }
    frame_idx := current_window_internal.current_frame_index
    ubo_info := &vk_dev_internal.uniform_buffers[frame_idx]

    if ubo_info.buffer == vk.NULL_HANDLE || ubo_info.mapped_ptr == nil {
        log.errorf("vk_set_uniform_vec4_internal: Frame %d UBO is invalid or not mapped.", frame_idx)
        return common.Engine_Error.Invalid_Handle
    }
    if ubo_info.size < size_of([4]f32) {
        log.errorf("vk_set_uniform_vec4_internal: UBO size (%d) is too small for vec4 (%d).", 
            ubo_info.size, size_of([4]f32))
        return common.Engine_Error.Invalid_Parameter
    }
    mem.copy(ubo_info.mapped_ptr, &val[0], size_of([4]f32))

    current_descriptor_set := current_window_internal.current_descriptor_sets[frame_idx]
    if current_descriptor_set == vk.NULL_HANDLE {
        log.errorf("vk_set_uniform_vec4_internal: Frame %d has no valid descriptor set.", frame_idx)
        return common.Engine_Error.Invalid_Operation
    }
    vk_update_descriptor_set_uniform_buffer_internal(vk_dev_internal, current_descriptor_set, binding_for_ubo, ubo_info)
    return .None
}

vk_set_uniform_int_internal :: proc(
    gfx_device_handle: gfx_interface.Gfx_Device, 
    binding_for_ubo: u32, 
    val: i32,
) -> common.Engine_Error {
    vk_dev_internal, ok_dev := gfx_device_handle.variant.(^vk_types.Vk_Device_Internal)
    if !ok_dev || vk_dev_internal == nil { return common.Engine_Error.Invalid_Handle }

    current_window_internal := vk_dev_internal.primary_window_for_pipeline
    if current_window_internal == nil {
        log.error("vk_set_uniform_int_internal: No primary window set on device.")
        return common.Engine_Error.Invalid_Operation
    }
    frame_idx := current_window_internal.current_frame_index
    ubo_info := &vk_dev_internal.uniform_buffers[frame_idx]

    if ubo_info.buffer == vk.NULL_HANDLE || ubo_info.mapped_ptr == nil {
        log.errorf("vk_set_uniform_int_internal: Frame %d UBO is invalid or not mapped.", frame_idx)
        return common.Engine_Error.Invalid_Handle
    }
    if ubo_info.size < size_of(i32) {
        log.errorf("vk_set_uniform_int_internal: UBO size (%d) is too small for int (%d).", 
            ubo_info.size, size_of(i32))
        return common.Engine_Error.Invalid_Parameter
    }
    mem.copy(ubo_info.mapped_ptr, &val, size_of(i32)) // For single values, pass address directly

    current_descriptor_set := current_window_internal.current_descriptor_sets[frame_idx]
    if current_descriptor_set == vk.NULL_HANDLE {
        log.errorf("vk_set_uniform_int_internal: Frame %d has no valid descriptor set.", frame_idx)
        return common.Engine_Error.Invalid_Operation
    }
    vk_update_descriptor_set_uniform_buffer_internal(vk_dev_internal, current_descriptor_set, binding_for_ubo, ubo_info)
    return .None
}

vk_set_uniform_float_internal :: proc(
    gfx_device_handle: gfx_interface.Gfx_Device, 
    binding_for_ubo: u32, 
    val: f32,
) -> common.Engine_Error {
    vk_dev_internal, ok_dev := gfx_device_handle.variant.(^vk_types.Vk_Device_Internal)
    if !ok_dev || vk_dev_internal == nil { return common.Engine_Error.Invalid_Handle }

    current_window_internal := vk_dev_internal.primary_window_for_pipeline
    if current_window_internal == nil {
        log.error("vk_set_uniform_float_internal: No primary window set on device.")
        return common.Engine_Error.Invalid_Operation
    }
    frame_idx := current_window_internal.current_frame_index
    ubo_info := &vk_dev_internal.uniform_buffers[frame_idx]

    if ubo_info.buffer == vk.NULL_HANDLE || ubo_info.mapped_ptr == nil {
        log.errorf("vk_set_uniform_float_internal: Frame %d UBO is invalid or not mapped.", frame_idx)
        return common.Engine_Error.Invalid_Handle
    }
    if ubo_info.size < size_of(f32) {
        log.errorf("vk_set_uniform_float_internal: UBO size (%d) is too small for float (%d).", 
            ubo_info.size, size_of(f32))
        return common.Engine_Error.Invalid_Parameter
    }
    mem.copy(ubo_info.mapped_ptr, &val, size_of(f32)) // For single values, pass address directly

    current_descriptor_set := current_window_internal.current_descriptor_sets[frame_idx]
    if current_descriptor_set == vk.NULL_HANDLE {
        log.errorf("vk_set_uniform_float_internal: Frame %d has no valid descriptor set.", frame_idx)
        return common.Engine_Error.Invalid_Operation
    }
    vk_update_descriptor_set_uniform_buffer_internal(vk_dev_internal, current_descriptor_set, binding_for_ubo, ubo_info)
    return .None
}
