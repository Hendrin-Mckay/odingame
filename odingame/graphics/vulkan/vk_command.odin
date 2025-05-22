package vulkan

import vk "vendor:vulkan"
import "core:log"
import "core:mem"
import "../gfx_interface" 
// For Vk_Window_Internal, Vk_Device_Internal, Vk_Pipeline_Internal, Vk_Buffer_Internal
// we assume they are accessible if this file is part of the 'vulkan' package.

// vk_begin_frame_internal starts a new frame for rendering.
// - Waits for the previous frame (using fence).
// - Acquires a new swapchain image.
// - Resets and begins the command buffer for the current frame in flight.
// - Stores the active command buffer and acquired image index in Vk_Window_Internal.
// Returns true if successful, false if swapchain needs recreation (suboptimal/out of date).
vk_begin_frame_internal :: proc(
	window_handle_gfx: gfx_interface.Gfx_Window,
) -> (ok: bool, active_cmd_buf: vk.CommandBuffer, acquired_image_idx: u32) {

	vk_win, ok_win := window_handle_gfx.variant.(Vk_Window_Variant)
	if !ok_win || vk_win == nil {
		log.error("vk_begin_frame: Invalid Gfx_Window.")
		return false, nil, 0
	}
	vk_dev := vk_win.device_ref
	logical_device := vk_dev.logical_device
	current_frame_idx_u64 := u64(vk_win.current_frame_index) // For indexing arrays

	// 1. Wait for the fence of the frame we are about to render.
	// Timeout for waiting (1 second in nanoseconds).
	// Using vk.UINT64_MAX makes it wait indefinitely.
	timeout_ns: u64 = 1_000_000_000 
	wait_res := vk.WaitForFences(logical_device, 1, &vk_win.in_flight_fences[current_frame_idx_u64], vk.TRUE, timeout_ns)
	if wait_res != .SUCCESS {
		// This could be .TIMEOUT or an error.
		log.errorf("vkWaitForFences timed out or failed for frame %d. Result: %v", vk_win.current_frame_index, wait_res)
		// Depending on the error, might need to handle differently. For now, treat as critical.
		return false, nil, 0 
	}
	// No need to vk.ResetFences if reset happens at QueueSubmit (which it doesn't, it's signaled by QueueSubmit)
	// Fences are reset manually after waiting.
	vk.ResetFences(logical_device, 1, &vk_win.in_flight_fences[current_frame_idx_u64])
	log.debugf("Frame %d: In-flight fence waited and reset.", vk_win.current_frame_index)


	// 2. Acquire next available swapchain image
	var image_index_u32: u32
	// Semaphores are signaled when operations complete. image_available_semaphore is signaled when presentation engine finishes reading from image.
	acquire_res := vk.AcquireNextImageKHR(
		logical_device,
		vk_win.swapchain,
		timeout_ns, // Or UINT64_MAX to wait indefinitely
		vk_win.image_available_semaphores[current_frame_idx_u64], // Semaphore to signal when image is available
		vk.NULL_HANDLE, // Fence to signal (optional, using in_flight_fences for command buffer submission)
		&image_index_u32,
	)

	if acquire_res == .ERROR_OUT_OF_DATE_KHR {
		log.warn("vkAcquireNextImageKHR: Swapchain is out of date. Needs recreation.")
		vk_win.recreating_swapchain = true
		return false, nil, 0 // Indicate swapchain needs recreation
	} else if acquire_res == .SUBOPTIMAL_KHR {
		log.warn("vkAcquireNextImageKHR: Swapchain is suboptimal. Needs recreation (but can still present).")
		// Proceed with rendering for this frame, but flag for recreation.
		vk_win.recreating_swapchain = true 
	} else if acquire_res != .SUCCESS {
		log.errorf("vkAcquireNextImageKHR failed. Result: %v", acquire_res)
		return false, nil, 0 // Critical error
	}
	log.debugf("Frame %d: Acquired swapchain image %d.", vk_win.current_frame_index, image_index_u32)
	
	// Store acquired image index
	vk_win.acquired_image_index = image_index_u32

	// Check if a previous frame is using this image (i.e. there is its fence to wait on)
	if vk_win.images_in_flight[image_index_u32] != vk.NULL_HANDLE {
		fence_wait_res := vk.WaitForFences(logical_device, 1, &vk_win.images_in_flight[image_index_u32], vk.TRUE, timeout_ns)
        if fence_wait_res != .SUCCESS {
            log.errorf("vkWaitForFences for images_in_flight[%d] failed. Result: %v", image_index_u32, fence_wait_res)
            return false, nil, 0
        }
	}
	// Mark this image as now in use by the current frame
	vk_win.images_in_flight[image_index_u32] = vk_win.in_flight_fences[current_frame_idx_u64]


	// 3. Get and Reset Command Buffer for the current frame in flight
	active_cmd_buf := vk_win.command_buffers[current_frame_idx_u64]
	// vk.ResetCommandBuffer: Resets a command buffer to the initial state.
	// Flags can be .RELEASE_RESOURCES_BIT to free resources, but usually not needed for simple reset.
	reset_cmd_res := vk.ResetCommandBuffer(active_cmd_buf, 0) 
	if reset_cmd_res != .SUCCESS {
		log.errorf("vkResetCommandBuffer failed for frame %d. Result: %v", vk_win.current_frame_index, reset_cmd_res)
		return false, nil, 0
	}
	log.debugf("Frame %d: Command buffer %p reset.", vk_win.current_frame_index, active_cmd_buf)

	// 4. Begin Command Buffer Recording
	cmd_buf_begin_info := vk.CommandBufferBeginInfo{
		sType = .COMMAND_BUFFER_BEGIN_INFO,
		flags = {.ONE_TIME_SUBMIT_BIT}, // Optional: if command buffer is recorded and submitted only once.
		                                // For frame rendering, it's recorded each frame.
		// pInheritanceInfo = nil, // Only for secondary command buffers
	}
	begin_res := vk.BeginCommandBuffer(active_cmd_buf, &cmd_buf_begin_info)
	if begin_res != .SUCCESS {
		log.errorf("vkBeginCommandBuffer failed for frame %d. Result: %v", vk_win.current_frame_index, begin_res)
		return false, nil, 0
	}
	log.debugf("Frame %d: Command buffer %p recording begun.", vk_win.current_frame_index, active_cmd_buf)

	// Store the active command buffer in Vk_Window_Internal for other command functions to use
	vk_win.active_command_buffer = active_cmd_buf
	
	return true, active_cmd_buf, image_index_u32
}

// vk_end_frame_internal ends the current frame:
// - Ends render pass and command buffer recording.
// - Submits the command buffer.
// - Presents the swapchain image.
// - Updates current_frame_index.
// Returns true if successful, false if swapchain needs recreation.
vk_end_frame_internal :: proc(window_handle_gfx: gfx_interface.Gfx_Window) -> bool {
	vk_win, ok_win := window_handle_gfx.variant.(Vk_Window_Variant)
	if !ok_win || vk_win == nil {
		log.error("vk_end_frame: Invalid Gfx_Window.")
		return false
	}
	if vk_win.active_command_buffer == vk.NULL_HANDLE {
		log.error("vk_end_frame: No active command buffer to end.")
		// This might happen if begin_frame failed or wasn't called.
		return false 
	}
	
	vk_dev := vk_win.device_ref
	logical_device := vk_dev.logical_device
	graphics_queue := vk_dev.graphics_queue
	present_queue := vk_dev.present_queue
	current_frame_idx_u64 := u64(vk_win.current_frame_index)

	active_cmd_buf := vk_win.active_command_buffer
	acquired_image_idx_u32 := vk_win.acquired_image_index

	// 1. End Render Pass (if one was started and not ended by user)
	// Assuming vk_clear_screen or other drawing commands started a render pass.
	// The task description implies vk_clear_screen starts it.
	// If vk.CmdEndRenderPass is called here, it means all drawing within the frame
	// must happen before vk_end_frame.
	// This is a common pattern.
	vk.CmdEndRenderPass(active_cmd_buf)
	log.debugf("Frame %d: Render pass ended for command buffer %p.", vk_win.current_frame_index, active_cmd_buf)

	// 2. End Command Buffer Recording
	end_cmd_res := vk.EndCommandBuffer(active_cmd_buf)
	if end_cmd_res != .SUCCESS {
		log.errorf("vkEndCommandBuffer failed for frame %d. Result: %v", vk_win.current_frame_index, end_cmd_res)
		return false // This is a critical error for the current frame.
	}
	log.debugf("Frame %d: Command buffer %p recording ended.", vk_win.current_frame_index, active_cmd_buf)

	// 3. Submit Command Buffer
	submit_info := vk.SubmitInfo{
		sType = .SUBMIT_INFO,
		waitSemaphoreCount = 1,
		pWaitSemaphores = &vk_win.image_available_semaphores[current_frame_idx_u64],
		// Pipeline stages to wait for: wait at color attachment output stage.
		pWaitDstStageMask = &vk.PipelineStageFlags{.COLOR_ATTACHMENT_OUTPUT_BIT}, 
		commandBufferCount = 1,
		pCommandBuffers = &active_cmd_buf,
		signalSemaphoreCount = 1,
		pSignalSemaphores = &vk_win.render_finished_semaphores[current_frame_idx_u64],
	}
	
	// Submit to graphics queue.
	// The in_flight_fences[current_frame_index] will be signaled when this command buffer finishes execution.
	// We already waited for this fence in begin_frame and reset it.
	// No, the fence used here (in_flight_fences[current_frame_idx_u64]) is for this submission.
	// images_in_flight[acquired_image_idx_u32] is also set to this same fence.
	// This ensures that we don't try to render to an image that's still being rendered to from a previous submission
	// that outputted to the same image index.
	// The fence in_flight_fences[current_frame_idx_u64] ensures that we don't start recording commands for this frame_index
	// if the *previous* use of this frame_index's command buffer and semaphores hasn't finished.
	
	// Ensure the fence is reset before use in vk.QueueSubmit
	// vk.ResetFences(logical_device, 1, &vk_win.in_flight_fences[current_frame_idx_u64]) // Already done in begin_frame after wait.

	submit_res := vk.QueueSubmit(graphics_queue, 1, &submit_info, vk_win.in_flight_fences[current_frame_idx_u64])
	if submit_res != .SUCCESS {
		log.errorf("vkQueueSubmit failed for frame %d. Result: %v", vk_win.current_frame_index, submit_res)
		// This is critical. The fence might not be signaled.
		return false
	}
	log.debugf("Frame %d: Command buffer submitted to graphics queue. Fence %p.", vk_win.current_frame_index, vk_win.in_flight_fences[current_frame_idx_u64])


	// 4. Present Swapchain Image
	present_info := vk.PresentInfoKHR{
		sType = .PRESENT_INFO_KHR,
		waitSemaphoreCount = 1,
		pWaitSemaphores = &vk_win.render_finished_semaphores[current_frame_idx_u64], // Wait for rendering to finish
		swapchainCount = 1,
		pSwapchains = &vk_win.swapchain,
		pImageIndices = &acquired_image_idx_u32,
		// pResults = nil, // Optional: for checking results of multiple swapchains
	}

	present_res := vk.QueuePresentKHR(present_queue, &present_info)
	
	frame_recreation_needed := false
	if present_res == .ERROR_OUT_OF_DATE_KHR || present_res == .SUBOPTIMAL_KHR {
		log.warnf("vkQueuePresentKHR: Swapchain is out of date or suboptimal. Needs recreation. Result: %v", present_res)
		vk_win.recreating_swapchain = true
		frame_recreation_needed = true // Indicate to caller that swapchain needs attention
	} else if present_res != .SUCCESS {
		log.errorf("vkQueuePresentKHR failed. Result: %v", present_res)
		// This is a critical error.
		return false 
	}
	log.debugf("Frame %d: Image %d presented to queue.", vk_win.current_frame_index, acquired_image_idx_u32)

	// 5. Update current_frame_index for next frame
	vk_win.current_frame_index = (vk_win.current_frame_index + 1) % MAX_FRAMES_IN_FLIGHT
	
	// Clear active command buffer as it's now submitted
	vk_win.active_command_buffer = vk.NULL_HANDLE 

	return !frame_recreation_needed // Return true if successful, false if swapchain needs recreation.
}


// vk_clear_screen_internal begins a render pass and clears attachments.
vk_clear_screen_internal :: proc(
	// Assumes active_command_buffer and acquired_image_index are set in vk_win by begin_frame
	window_handle_gfx: gfx_interface.Gfx_Window, 
	options: gfx_interface.Clear_Options,
) {
	vk_win, ok_win := window_handle_gfx.variant.(Vk_Window_Variant)
	if !ok_win || vk_win == nil { log.error("vk_clear_screen: Invalid Gfx_Window."); return }
	
	active_cmd_buf := vk_win.active_command_buffer
	if active_cmd_buf == vk.NULL_HANDLE { log.error("vk_clear_screen: No active command buffer."); return }
	
	current_image_idx := vk_win.acquired_image_index
	if current_image_idx >= u32(len(vk_win.framebuffers)) {
		log.errorf("vk_clear_screen: acquired_image_index %d is out of bounds for framebuffers slice (len %d).",
			current_image_idx, len(vk_win.framebuffers))
		return
	}
	framebuffer := vk_win.framebuffers[current_image_idx]
	
	// Use the window's main render pass. Pipelines must be compatible with this.
	render_pass_to_begin := vk_win.render_pass 
	if render_pass_to_begin == vk.NULL_HANDLE {
		log.error("vk_clear_screen: Window's render_pass is NULL.")
		return
	}

	clear_value := vk.ClearValue{} // Union, default to all zeros
	if options.clear_color {
		// Vulkan expects color components in a specific order, usually RGBA.
		clear_value.color.float32[0] = options.color[0]
		clear_value.color.float32[1] = options.color[1]
		clear_value.color.float32[2] = options.color[2]
		clear_value.color.float32[3] = options.color[3]
	}
	// If depth/stencil were used, set clear_value.depthStencil here.
	// Our current render pass has only one color attachment.

	render_pass_begin_info := vk.RenderPassBeginInfo{
		sType = .RENDER_PASS_BEGIN_INFO,
		renderPass = render_pass_to_begin,
		framebuffer = framebuffer,
		renderArea = vk.Rect2D{
			offset = {0, 0},
			extent = vk_win.swapchain_extent,
		},
		clearValueCount = 1, // One clear value for the color attachment
		pClearValues = &clear_value,
	}

	vk.CmdBeginRenderPass(active_cmd_buf, &render_pass_begin_info, .INLINE) // .INLINE for primary cmd bufs
	log.debugf("Frame %d: Began render pass %p on framebuffer %p (image %d).", 
		vk_win.current_frame_index, render_pass_to_begin, framebuffer, current_image_idx)
}

// vk_set_viewport_internal sets the dynamic viewport state.
vk_set_viewport_internal :: proc(
	active_cmd_buf: vk.CommandBuffer, 
	viewport_data: gfx_interface.Viewport,
) {
	if active_cmd_buf == vk.NULL_HANDLE { log.error("vk_set_viewport: No active command buffer."); return }
	
	// Note: Vulkan's Y-axis for viewport is often top-down (positive Y down).
	// If gfx_interface.Viewport assumes Y-up, conversion might be needed here or at projection matrix level.
	// For now, direct mapping.
	vk_viewport := vk.Viewport{
		x = viewport_data.x,
		y = viewport_data.y, // If Y needs flipping: window_height - viewport_data.y - viewport_data.height
		width = viewport_data.width,
		height = viewport_data.height,
		minDepth = viewport_data.min_depth,
		maxDepth = viewport_data.max_depth,
	}
	vk.CmdSetViewport(active_cmd_buf, 0, 1, &vk_viewport) // firstViewport=0, viewportCount=1
}

// vk_set_scissor_internal sets the dynamic scissor state.
vk_set_scissor_internal :: proc(
	active_cmd_buf: vk.CommandBuffer, 
	scissor_data: gfx_interface.Scissor,
) {
	if active_cmd_buf == vk.NULL_HANDLE { log.error("vk_set_scissor: No active command buffer."); return }

	vk_scissor := vk.Rect2D{
		offset = {scissor_data.x, scissor_data.y},
		extent = {u32(scissor_data.width), u32(scissor_data.height)},
	}
	vk.CmdSetScissor(active_cmd_buf, 0, 1, &vk_scissor) // firstScissor=0, scissorCount=1
}

// vk_set_pipeline_internal binds a graphics pipeline.
vk_set_pipeline_internal :: proc(
	window_handle_gfx: gfx_interface.Gfx_Window, // To store active layout/renderpass
	pipeline_handle_gfx: gfx_interface.Gfx_Pipeline,
) {
	vk_win, ok_win := window_handle_gfx.variant.(Vk_Window_Variant)
	if !ok_win || vk_win == nil { log.error("vk_set_pipeline: Invalid Gfx_Window."); return }
	
	vk_pipe, ok_pipe := pipeline_handle_gfx.variant.(^Vk_Pipeline_Internal)
	if !ok_pipe || vk_pipe == nil { log.error("vk_set_pipeline: Invalid Gfx_Pipeline."); return }

	active_cmd_buf := vk_win.active_command_buffer
	if active_cmd_buf == vk.NULL_HANDLE { log.error("vk_set_pipeline: No active command buffer."); return }

	vk.CmdBindPipeline(active_cmd_buf, .GRAPHICS, vk_pipe.pipeline)
	log.debugf("Frame %d: Bound graphics pipeline %p.", vk_win.current_frame_index, vk_pipe.pipeline)

	// Store layout and render pass for subsequent commands (e.g. bind descriptor sets, draw)
	vk_win.active_pipeline_layout = vk_pipe.pipeline_layout
	// vk_win.active_render_pass = vk_pipe.render_pass; // Render pass is started by clear_screen
}

// vk_set_vertex_buffer_internal binds a vertex buffer.
vk_set_vertex_buffer_internal :: proc(
	active_cmd_buf: vk.CommandBuffer,
	buffer_handle_gfx: gfx_interface.Gfx_Buffer,
	binding_index: u32, // The binding point
	buffer_offset: u32, // Note: Gfx_Device_Interface uses 'offset', here using 'buffer_offset' to avoid conflict
) {
	if active_cmd_buf == vk.NULL_HANDLE { log.error("vk_set_vertex_buffer: No active command buffer."); return }

	vk_buffer_internal, ok_buf := buffer_handle_gfx.variant.(^Vk_Buffer_Internal)
	if !ok_buf || vk_buffer_internal == nil { log.error("vk_set_vertex_buffer: Invalid Gfx_Buffer."); return }

	offsets := [1]vk.DeviceSize{vk.DeviceSize(buffer_offset)}
	buffers_to_bind := [1]vk.Buffer{vk_buffer_internal.buffer}
	
	vk.CmdBindVertexBuffers(active_cmd_buf, binding_index, 1, &buffers_to_bind[0], &offsets[0])
	log.debugf("Bound vertex buffer %p to binding %d with offset %d.", vk_buffer_internal.buffer, binding_index, buffer_offset)
}


// vk_draw_internal performs a non-indexed draw.
vk_draw_internal :: proc(
	active_cmd_buf: vk.CommandBuffer,
	vertex_count: u32,
	instance_count: u32,
	first_vertex: u32,
	first_instance: u32,
) {
	if active_cmd_buf == vk.NULL_HANDLE { log.error("vk_draw: No active command buffer."); return }
	
	vk.CmdDraw(active_cmd_buf, vertex_count, instance_count, first_vertex, first_instance)
}

// vk_draw_indexed_internal performs an indexed draw.
vk_draw_indexed_internal :: proc(
	active_cmd_buf: vk.CommandBuffer,
	index_count: u32,
	instance_count: u32,
	first_index: u32,
	base_vertex: i32, // vk.CmdDrawIndexed takes base_vertex as i32
	first_instance: u32,
) {
	if active_cmd_buf == vk.NULL_HANDLE { 
		log.error("vk_draw_indexed_internal: No active command buffer.")
		return 
	}
	
	vk.CmdDrawIndexed(
		active_cmd_buf, 
		index_count, 
		instance_count, 
		first_index, 
		base_vertex, 
		first_instance,
	)
	// Log details of the draw call
	log.debugf("vk_draw_indexed_internal: vk.CmdDrawIndexed recorded. IndexCount: %d, InstanceCount: %d, FirstIndex: %d, BaseVertex: %d, FirstInstance: %d",
		index_count, instance_count, first_index, base_vertex, first_instance)
}

// TODO: vk_set_index_buffer_internal
// vk_set_index_buffer_internal :: proc(...) { vk.CmdBindIndexBuffer(...) }

// TODO: Uniform/Descriptor Set binding functions
// These would use vk_win.active_pipeline_layout for vk.CmdBindDescriptorSets
