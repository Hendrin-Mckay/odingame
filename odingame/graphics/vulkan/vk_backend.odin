package vulkan

import "../gfx_interface"
import "core:log"

// --- Shader Management Wrappers ---

// vk_create_shader_from_bytecode_wrapper calls the internal implementation.
vk_create_shader_from_bytecode_wrapper :: proc(
	device: gfx_interface.Gfx_Device, 
	bytecode: []u8, 
	stage: gfx_interface.Shader_Stage,
) -> (gfx_interface.Gfx_Shader, gfx_interface.Gfx_Error) {
	return vk_create_shader_from_bytecode_internal(device, bytecode, stage)
}

// vk_destroy_shader_wrapper calls the internal implementation.
vk_destroy_shader_wrapper :: proc(shader: gfx_interface.Gfx_Shader) {
	vk_destroy_shader_internal(shader)
}

// vk_create_shader_from_source_wrapper calls the internal implementation.
vk_create_shader_from_source_wrapper :: proc(
	device: gfx_interface.Gfx_Device, 
	source: string, 
	stage: gfx_interface.Shader_Stage,
) -> (gfx_interface.Gfx_Shader, gfx_interface.Gfx_Error) {
	// This will call the vk_shader.odin internal function which attempts shaderc compilation.
	// If shaderc is not implemented/available, that internal function will return .Not_Implemented.
	return vk_create_shader_from_source_internal(device, source, stage)
}


// --- Stub Implementations for Vulkan ---
// These functions will be assigned to gfx_api for features not yet implemented in Vulkan.

// Stubs for functions other than device, window, and shader management (as per current task focus)
// vk_stub_create_shader_from_source, vk_stub_create_shader_from_bytecode, vk_stub_destroy_shader
// are now replaced by wrappers above.


// --- Pipeline Management Wrappers ---

vk_create_pipeline_wrapper :: proc(
	device: gfx_interface.Gfx_Device, 
	shaders: []gfx_interface.Gfx_Shader,
	// vertex_input_state is not part of Gfx_Device_Interface.create_pipeline yet.
	// The internal pipeline creation will use a default empty vertex input state.
) -> (gfx_interface.Gfx_Pipeline, gfx_interface.Gfx_Error) {
	
	vk_dev_internal, ok_dev := device.variant.(Vk_Device_Variant)
	if !ok_dev || vk_dev_internal == nil {
		log.error("vk_create_pipeline_wrapper: Invalid Gfx_Device (not Vulkan or nil variant).")
		return gfx_interface.Gfx_Pipeline{}, .Invalid_Handle
	}

	if vk_dev_internal.primary_window_for_pipeline == nil {
		log.error("vk_create_pipeline_wrapper: No primary window associated with the device. Cannot determine swapchain format for render pass.")
		// This indicates a design dependency: pipeline creation currently needs a window context for the render pass.
		return gfx_interface.Gfx_Pipeline{}, .Invalid_Handle // Or .Initialization_Failed / .Not_Ready
	}
	primary_window := vk_dev_internal.primary_window_for_pipeline
	swapchain_format := primary_window.swapchain_format 
	// Ensure primary_window is valid and its swapchain_format is initialized.
	// This would be vk.FORMAT_UNDEFINED if the window/swapchain isn't fully set up.
	if swapchain_format == .UNDEFINED {
		log.errorf("vk_create_pipeline_wrapper: Primary window (SDL: %s) has an undefined swapchain format.", sdl.GetWindowTitle(primary_window.sdl_window))
		return gfx_interface.Gfx_Pipeline{}, .Device_Creation_Failed // Indicate device/window not ready
	}

	log.infof("Creating Vulkan pipeline using swapchain format %v from primary window (SDL: %s)", 
		swapchain_format, sdl.GetWindowTitle(primary_window.sdl_window))

	// 1. Create Render Pass
	// The render pass is specific to the swapchain format.
	render_pass_handle, rp_err := vk_create_render_pass_internal(vk_dev_internal.logical_device, swapchain_format)
	if rp_err != .None {
		log.errorf("Failed to create render pass for pipeline: %s", gfx_interface.gfx_api.get_error_string(rp_err))
		return gfx_interface.Gfx_Pipeline{}, rp_err
	}
	// Defer its destruction only if subsequent steps fail and it's not passed to Vk_Pipeline_Internal.
	// If pipeline creation succeeds, Vk_Pipeline_Internal will own it.

	// 2. Create Pipeline Layout
	pipeline_layout_handle, pl_err := vk_create_pipeline_layout_internal(vk_dev_internal.logical_device)
	if pl_err != .None {
		log.errorf("Failed to create pipeline layout for pipeline: %s", gfx_interface.gfx_api.get_error_string(pl_err))
		// Cleanup render pass if layout creation failed
		vk.DestroyRenderPass(vk_dev_internal.logical_device, render_pass_handle, nil)
		return gfx_interface.Gfx_Pipeline{}, pl_err
	}
	// Defer its destruction similarly.

	// 3. Create the Graphics Pipeline
	// The vertex_input_state is handled internally by vk_create_pipeline_internal for now.

	// Get vertex input state from active VAO, if any
	vertex_bindings_slice: []Vk_Vertex_Input_Binding_Description
	vertex_attributes_slice: []Vk_Vertex_Input_Attribute_Description

	if primary_window.active_vao.variant != nil {
		if vk_vao_internal, ok_vao_internal := primary_window.active_vao.variant.(^Vk_Vertex_Array_Internal); ok_vao_internal && vk_vao_internal != nil {
			log.debugf("Using vertex input state from active VAO %p for pipeline creation.", vk_vao_internal)
			vertex_bindings_slice = vk_vao_internal.binding_descriptions[:]
			vertex_attributes_slice = vk_vao_internal.attribute_descriptions[:]
		} else {
			log.warnf("Active VAO variant is not of type ^Vk_Vertex_Array_Internal. Type: %T. Using empty vertex input state.", primary_window.active_vao.variant)
			// Fallthrough to use empty slices
		}
	} else {
		log.debug("No active VAO found. Using empty vertex input state for pipeline creation.")
		// Fallthrough to use empty slices (already initialized as nil/empty)
	}
	
	gfx_pipeline, pipe_err := vk_create_pipeline_internal(
		device, 
		shaders, 
		render_pass_handle, 
		pipeline_layout_handle,
		vertex_bindings_slice,    // Pass VAO bindings
		vertex_attributes_slice,  // Pass VAO attributes
	)

	if pipe_err != .None {
		log.errorf("Core graphics pipeline creation failed: %s", gfx_interface.gfx_api.get_error_string(pipe_err))
		// Cleanup render pass and pipeline layout as they were not successfully transferred to Vk_Pipeline_Internal
		vk.DestroyPipelineLayout(vk_dev_internal.logical_device, pipeline_layout_handle, nil)
		vk.DestroyRenderPass(vk_dev_internal.logical_device, render_pass_handle, nil)
		return gfx_interface.Gfx_Pipeline{}, pipe_err
	}

	// If successful, render_pass_handle and pipeline_layout_handle are now owned by the Vk_Pipeline_Internal
	// instance within gfx_pipeline.
	log.info("Vulkan pipeline wrapper created successfully.")
	return gfx_pipeline, .None
}

vk_destroy_pipeline_wrapper :: proc(pipeline: gfx_interface.Gfx_Pipeline) {
	vk_destroy_pipeline_internal(pipeline) // This will handle destroying pipeline, layout, and render_pass
}

// --- Buffer Management Wrappers ---

vk_create_buffer_wrapper :: proc(
	device: gfx_interface.Gfx_Device, 
	type: gfx_interface.Buffer_Type, 
	size: int, 
	data: rawptr = nil, 
	dynamic: bool = false,
) -> (gfx_interface.Gfx_Buffer, gfx_interface.Gfx_Error) {
	return vk_create_buffer_internal(device, type, size, data, dynamic)
}

vk_destroy_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer) {
	vk_destroy_buffer_internal(buffer)
}

vk_map_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer, offset, size: int) -> rawptr {
	return vk_map_buffer_internal(buffer, offset, size)
}

vk_unmap_buffer_wrapper :: proc(buffer: gfx_interface.Gfx_Buffer) {
	vk_unmap_buffer_internal(buffer)
}

// vk_update_buffer_wrapper: For Vulkan, if a buffer is not persistently mapped and HOST_COHERENT,
// this would involve mapping, copying data, and unmapping.
// If it's DEVICE_LOCAL, it would involve a staging buffer and command buffer operations.
// For now, this will be a simplified version or a stub.
// Let's assume it behaves like initial data upload: map, copy, unmap.
vk_update_buffer_wrapper :: proc(buffer_handle_gfx: gfx_interface.Gfx_Buffer, offset: int, data: rawptr, size: int) -> gfx_interface.Gfx_Error {
	vk_buffer_ptr, ok_buf := buffer_handle_gfx.variant.(^Vk_Buffer_Internal)
	if !ok_buf || vk_buffer_ptr == nil {
		log.errorf("vk_update_buffer: Invalid Gfx_Buffer type or nil variant (%v).", buffer_handle_gfx.variant)
		return .Invalid_Handle
	}
	buffer_internal := vk_buffer_ptr^
	logical_device := buffer_internal.device_ref.logical_device

	if data == nil || size <= 0 {
		log.error("vk_update_buffer: Invalid data or size for update.")
		return .Invalid_Handle // Or specific error code
	}
	if offset < 0 || vk.DeviceSize(offset + size) > buffer_internal.size {
		log.errorf("vk_update_buffer: Offset (%d) / Size (%d) out of bounds for buffer of size %v.", offset, size, buffer_internal.size)
		return .Invalid_Handle // Or specific error code
	}

	// Assuming HOST_VISIBLE and HOST_COHERENT memory for simplicity
	log.debugf("Updating buffer %p, Offset %d, Size %d", buffer_internal.buffer, offset, size)
	mapped_data_ptr: rawptr
	map_result := vk.MapMemory(logical_device, buffer_internal.memory, vk.DeviceSize(offset), vk.DeviceSize(size), 0, &mapped_data_ptr)
	if map_result == .SUCCESS && mapped_data_ptr != nil {
		mem.copy(mapped_data_ptr, data, size)
		// HOST_COHERENT ensures visibility. If not coherent, flush would be needed.
		vk.UnmapMemory(logical_device, buffer_internal.memory)
		log.debug("Buffer update successful via map/copy/unmap.")
		return .None
	} else {
		log.errorf("vkMapMemory failed for buffer update. Result: %v", map_result)
		return .Buffer_Creation_Failed // Or a more specific "Update_Failed"
	}
}


// --- Frame Management and Drawing Command Wrappers ---

// vk_begin_frame_wrapper: Operates on the device's primary window.
vk_begin_frame_wrapper :: proc(device: gfx_interface.Gfx_Device) {
	vk_dev, ok_dev := device.variant.(Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { log.error("vk_begin_frame_wrapper: Invalid Gfx_Device."); return }
	
	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil { 
		log.error("vk_begin_frame_wrapper: No primary window set on device for frame operations.")
		return 
	}
	primary_gfx_window := gfx_interface.Gfx_Window{variant = primary_window_ptr}
	
	ok, _, _ := vk_begin_frame_internal(primary_gfx_window)
	if !ok {
		log.warn("vk_begin_frame_wrapper: vk_begin_frame_internal indicated an issue (e.g. swapchain out of date).")
	}
}

// vk_end_frame_wrapper: Operates on the device's primary window.
vk_end_frame_wrapper :: proc(device: gfx_interface.Gfx_Device) {
	vk_dev, ok_dev := device.variant.(Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { log.error("vk_end_frame_wrapper: Invalid Gfx_Device."); return }

	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil { 
		log.error("vk_end_frame_wrapper: No primary window set on device for frame operations.")
		return 
	}
	primary_gfx_window := gfx_interface.Gfx_Window{variant = primary_window_ptr}

	if !vk_end_frame_internal(primary_gfx_window) {
		log.warn("vk_end_frame_wrapper: vk_end_frame_internal indicated an issue (e.g. swapchain out of date or present failed).")
	}
}

// vk_clear_screen_wrapper: Operates on the device's primary window.
// It uses the window's main render pass.
vk_clear_screen_wrapper :: proc(device: gfx_interface.Gfx_Device, options: gfx_interface.Clear_Options) {
	vk_dev, ok_dev := device.variant.(Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { log.error("vk_clear_screen_wrapper: Invalid Gfx_Device."); return }
	
	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil { log.error("vk_clear_screen_wrapper: No primary window."); return }
	if primary_window_ptr.active_command_buffer == vk.NULL_HANDLE { log.error("vk_clear_screen_wrapper: No active command buffer on primary window."); return }

	primary_gfx_window := gfx_interface.Gfx_Window{variant = primary_window_ptr}
	vk_clear_screen_internal(primary_gfx_window, options)
}


vk_set_viewport_wrapper :: proc(device: gfx_interface.Gfx_Device, viewport: gfx_interface.Viewport) {
	vk_dev, ok_dev := device.variant.(Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { log.error("vk_set_viewport_wrapper: Invalid Gfx_Device."); return }
	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil || primary_window_ptr.active_command_buffer == vk.NULL_HANDLE { 
		log.error("vk_set_viewport_wrapper: No primary window or active command buffer.")
		return 
	}
	vk_set_viewport_internal(primary_window_ptr.active_command_buffer, viewport)
}

vk_set_scissor_wrapper :: proc(device: gfx_interface.Gfx_Device, scissor: gfx_interface.Scissor) {
	vk_dev, ok_dev := device.variant.(Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { log.error("vk_set_scissor_wrapper: Invalid Gfx_Device."); return }
	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil || primary_window_ptr.active_command_buffer == vk.NULL_HANDLE { 
		log.error("vk_set_scissor_wrapper: No primary window or active command buffer.")
		return 
	}
	vk_set_scissor_internal(primary_window_ptr.active_command_buffer, scissor)
}

vk_set_pipeline_wrapper :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline) {
	vk_dev, ok_dev := device.variant.(Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { log.error("vk_set_pipeline_wrapper: Invalid Gfx_Device."); return }
	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil { 
		log.error("vk_set_pipeline_wrapper: No primary window for context.")
		return 
	}
	// active_command_buffer check is implicitly done by vk_set_pipeline_internal
	primary_gfx_window := gfx_interface.Gfx_Window{variant = primary_window_ptr}
	vk_set_pipeline_internal(primary_gfx_window, pipeline)
}

vk_set_vertex_buffer_wrapper :: proc(device: gfx_interface.Gfx_Device, buffer: gfx_interface.Gfx_Buffer, binding_index: u32 = 0, offset: u32 = 0) {
	vk_dev, ok_dev := device.variant.(Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { log.error("vk_set_vertex_buffer_wrapper: Invalid Gfx_Device."); return }
	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil || primary_window_ptr.active_command_buffer == vk.NULL_HANDLE { 
		log.error("vk_set_vertex_buffer_wrapper: No primary window or active command buffer.")
		return 
	}
	vk_set_vertex_buffer_internal(primary_window_ptr.active_command_buffer, buffer, binding_index, offset)
}

vk_draw_wrapper :: proc(device: gfx_interface.Gfx_Device, vertex_count, instance_count, first_vertex, first_instance: u32) {
	vk_dev, ok_dev := device.variant.(Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { log.error("vk_draw_wrapper: Invalid Gfx_Device."); return }
	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil || primary_window_ptr.active_command_buffer == vk.NULL_HANDLE { 
		log.error("vk_draw_wrapper: No primary window or active command buffer.")
		return 
	}
	vk_draw_internal(primary_window_ptr.active_command_buffer, vertex_count, instance_count, first_vertex, first_instance)
}

// Stubs for remaining functions
vk_stub_create_texture :: proc(device: gfx_interface.Gfx_Device, width, height: int, format: gfx_interface.Texture_Format, usage: gfx_interface.Texture_Usage, data: rawptr = nil) -> (gfx_interface.Gfx_Texture, gfx_interface.Gfx_Error) {
	log.warn("Vulkan: create_texture not implemented.")
	return gfx_interface.Gfx_Texture{}, .Not_Implemented
}
vk_stub_update_texture :: proc(texture: gfx_interface.Gfx_Texture, x, y, width, height: int, data: rawptr) -> gfx_interface.Gfx_Error {
	log.warn("Vulkan: update_texture not implemented.")
	return .Not_Implemented
}
vk_stub_destroy_texture :: proc(texture: gfx_interface.Gfx_Texture) {
	log.warn("Vulkan: destroy_texture not implemented.")
}
vk_stub_set_index_buffer :: proc(device: gfx_interface.Gfx_Device, buffer: gfx_interface.Gfx_Buffer, offset: u32 = 0) {
	log.warn("Vulkan: set_index_buffer not implemented.")
}
vk_stub_set_uniform_mat4 :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, mat: matrix[4,4]f32) -> gfx_interface.Gfx_Error {
    log.warn("Vulkan: set_uniform_mat4 not implemented.")
    return .Not_Implemented
}
vk_stub_set_uniform_vec2 :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [2]f32) -> gfx_interface.Gfx_Error {
    log.warn("Vulkan: set_uniform_vec2 not implemented.")
    return .Not_Implemented
}
vk_stub_set_uniform_vec3 :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [3]f32) -> gfx_interface.Gfx_Error {
    log.warn("Vulkan: set_uniform_vec3 not implemented.")
    return .Not_Implemented
}
vk_stub_set_uniform_vec4 :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, vec: [4]f32) -> gfx_interface.Gfx_Error {
    log.warn("Vulkan: set_uniform_vec4 not implemented.")
    return .Not_Implemented
}
vk_stub_set_uniform_int :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, val: i32) -> gfx_interface.Gfx_Error {
    log.warn("Vulkan: set_uniform_int not implemented.")
    return .Not_Implemented
}
vk_stub_set_uniform_float :: proc(device: gfx_interface.Gfx_Device, pipeline: gfx_interface.Gfx_Pipeline, name: string, val: f32) -> gfx_interface.Gfx_Error {
    log.warn("Vulkan: set_uniform_float not implemented.")
    return .Not_Implemented
}
vk_stub_bind_texture_to_unit :: proc(device: gfx_interface.Gfx_Device, texture: gfx_interface.Gfx_Texture, unit: u32) -> gfx_interface.Gfx_Error {
    log.warn("Vulkan: bind_texture_to_unit not implemented.")
    return .Not_Implemented
}
vk_stub_create_vertex_array :: proc(device: gfx_interface.Gfx_Device, layouts: []gfx_interface.Vertex_Buffer_Layout, vertex_buffers: []gfx_interface.Gfx_Buffer, index_buffer: gfx_interface.Gfx_Buffer) -> (gfx_interface.Gfx_Vertex_Array, gfx_interface.Gfx_Error) {
    log.warn("Vulkan: create_vertex_array not implemented.")
    return gfx_interface.Gfx_Vertex_Array{}, .Not_Implemented
}
vk_stub_destroy_vertex_array :: proc(vao: gfx_interface.Gfx_Vertex_Array) {
    log.warn("Vulkan: destroy_vertex_array not implemented.")
}
vk_stub_bind_vertex_array :: proc(device: gfx_interface.Gfx_Device, vao: gfx_interface.Gfx_Vertex_Array) {
    log.warn("Vulkan: bind_vertex_array not implemented.")
}
vk_stub_get_texture_width :: proc(texture: gfx_interface.Gfx_Texture) -> int {
    log.warn("Vulkan: get_texture_width not implemented.")
    return 0
}
vk_stub_get_texture_height :: proc(texture: gfx_interface.Gfx_Texture) -> int {
    log.warn("Vulkan: get_texture_height not implemented.")
    return 0
}
vk_stub_draw_indexed :: proc(device: gfx_interface.Gfx_Device, index_count, instance_count, first_index, base_vertex, first_instance: u32) {
	log.warn("Vulkan: draw_indexed not implemented.")
}

// --- VAO Management Wrappers ---

vk_create_vertex_array_wrapper :: proc(
    device: gfx_interface.Gfx_Device, 
    vertex_buffer_layouts: []gfx_interface.Vertex_Buffer_Layout, 
    vertex_buffers: []gfx_interface.Gfx_Buffer,
    index_buffer: gfx_interface.Gfx_Buffer,
) -> (gfx_interface.Gfx_Vertex_Array, gfx_interface.Gfx_Error) {
	return vk_create_vertex_array_internal(device, vertex_buffer_layouts, vertex_buffers, index_buffer)
}

vk_destroy_vertex_array_wrapper :: proc(vao: gfx_interface.Gfx_Vertex_Array) {
	vk_destroy_vertex_array_internal(vao)
}

// vk_bind_vertex_array_wrapper sets the active VAO on the primary window.
vk_bind_vertex_array_wrapper :: proc(device: gfx_interface.Gfx_Device, vao_handle_gfx: gfx_interface.Gfx_Vertex_Array) {
	vk_dev, ok_dev := device.variant.(Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { log.error("vk_bind_vertex_array_wrapper: Invalid Gfx_Device."); return }
	
	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil { 
		log.error("vk_bind_vertex_array_wrapper: No primary window set on device.")
		return 
	}
	// active_cmd_buf := primary_window_ptr.active_command_buffer // Not needed for just setting the VAO handle

	primary_window_ptr.active_vao = vao_handle_gfx
	
	if vao_handle_gfx.variant != nil {
		if _, ok_vao_internal_ptr := vao_handle_gfx.variant.(^Vk_Vertex_Array_Internal); ok_vao_internal_ptr {
			log.debugf("Set active VAO on window %p.", primary_window_ptr)
		} else {
			log.errorf("vk_bind_vertex_array_wrapper: Bound VAO has incorrect variant type: %T. Clearing active VAO.", vao_handle_gfx.variant)
			primary_window_ptr.active_vao = gfx_interface.Gfx_Vertex_Array{} // Clear if invalid type
		}
	} else {
		log.debugf("Cleared active VAO on window %p.", primary_window_ptr)
	}
	// Note: Actual vk.CmdBindVertexBuffers and vk.CmdBindIndexBuffer calls
	// are performed by vk_set_vertex_buffer_wrapper and vk_set_index_buffer_wrapper.
}

// vk_set_index_buffer_wrapper binds the given index buffer.
vk_set_index_buffer_wrapper :: proc(device: gfx_interface.Gfx_Device, buffer_gfx: gfx_interface.Gfx_Buffer, offset: u32 = 0) {
	vk_dev, ok_dev := device.variant.(Vk_Device_Variant)
	if !ok_dev || vk_dev == nil { log.error("vk_set_index_buffer_wrapper: Invalid Gfx_Device."); return }
	
	primary_window_ptr := vk_dev.primary_window_for_pipeline
	if primary_window_ptr == nil { log.error("vk_set_index_buffer_wrapper: No primary window for context."); return }
	
	active_cmd_buf := primary_window_ptr.active_command_buffer
	if active_cmd_buf == vk.NULL_HANDLE { log.error("vk_set_index_buffer_wrapper: No active command buffer."); return }

	vk_buffer_internal, ok_buf_internal := buffer_gfx.variant.(^Vk_Buffer_Internal)
	if !ok_buf_internal || vk_buffer_internal == nil {
		log.error("vk_set_index_buffer_wrapper: Invalid Gfx_Buffer provided.")
		return
	}

	// Determine index type. Default to UINT32.
	// If an active VAO is present and its index buffer matches this one, use the VAO's index type.
	index_type_to_bind := vk.IndexType.UINT32 // Default
	if active_vao_ptr, ok_vao := primary_window_ptr.active_vao.variant.(^Vk_Vertex_Array_Internal); ok_vao && active_vao_ptr != nil {
		// Check if the buffer being bound is the same as the one stored in the VAO
		if active_vao_ib_ptr, ok_vao_ib := active_vao_ptr.index_buffer_gfx.variant.(^Vk_Buffer_Internal); ok_vao_ib && active_vao_ib_ptr == vk_buffer_internal {
			index_type_to_bind = active_vao_ptr.index_type
			log.debugf("Using index type %v from active VAO for index buffer %p.", index_type_to_bind, vk_buffer_internal.buffer)
		} else {
			log.debugf("Binding index buffer %p, but it does not match active VAO's index buffer. Defaulting to index type UINT32.", vk_buffer_internal.buffer)
		}
	} else {
		log.debug("No active VAO or VAO has no index buffer. Defaulting to index type UINT32 for binding.")
	}
	
	vk.CmdBindIndexBuffer(active_cmd_buf, vk_buffer_internal.buffer, vk.DeviceSize(offset), index_type_to_bind)
	log.debugf("Bound index buffer %p with offset %d and type %v.", vk_buffer_internal.buffer, offset, index_type_to_bind)
}


vk_stub_get_error_string :: proc(error: gfx_interface.Gfx_Error) -> string {
    // This can use the same error string mapping as OpenGL backend, or a Vulkan specific one if needed.
    // For now, assume generic error strings.
    #partial switch error {
    case .None: return "No error (Vulkan)" // Add (Vulkan) for clarity during testing
    case .Initialization_Failed: return "Initialization failed (Vulkan)"
    case .Device_Creation_Failed: return "Device creation failed (Vulkan)"
    case .Window_Creation_Failed: return "Window creation failed (Vulkan)"
    case .Shader_Compilation_Failed: return "Shader compilation failed (Vulkan)"
    case .Buffer_Creation_Failed: return "Buffer creation failed (Vulkan)"
    case .Texture_Creation_Failed: return "Texture creation failed (Vulkan)"
    case .Invalid_Handle: return "Invalid handle (Vulkan)"
    case .Not_Implemented: return "Not implemented (Vulkan)"
    }
    return "Unknown Gfx_Error (Vulkan)"
}


// initialize_vulkan_backend populates the global gfx_api with Vulkan implementations.
initialize_vulkan_backend :: proc() {
	gfx_interface.gfx_api = gfx_interface.Gfx_Device_Interface {
		// Device and Window Management (Implemented)
		create_device              = vk_create_device_wrapper,
		destroy_device             = vk_destroy_device_wrapper,
		create_window              = vk_create_window_wrapper,
		destroy_window             = vk_destroy_window_wrapper,
		present_window             = vk_present_window_wrapper, // Basic stub for now
		resize_window              = vk_resize_window_wrapper,  // Basic stub for now
		get_window_size            = vk_get_window_size_wrapper,
		get_window_drawable_size   = vk_get_window_drawable_size_wrapper,
		
		// Shader Management (Implemented via wrappers)
		create_shader_from_source  = vk_create_shader_from_source_wrapper,
		create_shader_from_bytecode= vk_create_shader_from_bytecode_wrapper,
		destroy_shader             = vk_destroy_shader_wrapper,
        create_pipeline            = vk_create_pipeline_wrapper, // Now implemented
        destroy_pipeline           = vk_destroy_pipeline_wrapper, // Now implemented
        set_pipeline               = vk_stub_set_pipeline, // Still a stub

		// Buffer Management (Implemented via wrappers)
		create_buffer              = vk_create_buffer_wrapper,
		update_buffer              = vk_update_buffer_wrapper, // Basic implementation
		destroy_buffer             = vk_destroy_buffer_wrapper,
        map_buffer                 = vk_map_buffer_wrapper,
        unmap_buffer               = vk_unmap_buffer_wrapper,
		set_vertex_buffer          = vk_set_vertex_buffer_wrapper, 
		set_index_buffer           = vk_set_index_buffer_wrapper, // Now implemented

		// Texture Management (Stubs)
		create_texture             = vk_stub_create_texture,
		update_texture             = vk_stub_update_texture,
		destroy_texture            = vk_stub_destroy_texture,
		bind_texture_to_unit       = vk_stub_bind_texture_to_unit,
		get_texture_width          = vk_stub_get_texture_width,
		get_texture_height         = vk_stub_get_texture_height,

		// Frame Management (Stubs)
		begin_frame                = vk_stub_begin_frame,
		end_frame                  = vk_stub_end_frame,

		// Drawing Commands (Stubs)
		clear_screen               = vk_stub_clear_screen,
        set_viewport               = vk_stub_set_viewport,
        set_scissor                = vk_stub_set_scissor,
		draw                       = vk_stub_draw,
		draw_indexed               = vk_stub_draw_indexed,

		// Uniforms (Stubs)
		set_uniform_mat4           = vk_stub_set_uniform_mat4,
		set_uniform_vec2           = vk_stub_set_uniform_vec2,
		set_uniform_vec3           = vk_stub_set_uniform_vec3,
		set_uniform_vec4           = vk_stub_set_uniform_vec4,
		set_uniform_int            = vk_stub_set_uniform_int,
		set_uniform_float          = vk_stub_set_uniform_float,
		
		// VAO (Implemented via wrappers)
		create_vertex_array      = vk_create_vertex_array_wrapper,
		destroy_vertex_array     = vk_destroy_vertex_array_wrapper,
		bind_vertex_array        = vk_bind_vertex_array_wrapper,
		
        // Utility (Stub, could share with GL or have specific error codes)
        get_error_string           = vk_stub_get_error_string,
	}
	log.info("Vulkan graphics backend initialized and assigned to gfx_api (Device/Window/Swapchain setup complete, others stubbed).")
}
