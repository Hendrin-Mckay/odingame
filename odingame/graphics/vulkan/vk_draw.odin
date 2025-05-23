package vulkan

import vk "vendor:vulkan"
import "core:log"
import "core:mem"
import "../gfx_interface"

// --- Drawing Commands ---

// vk_begin_frame_internal starts a new frame
vk_begin_frame_internal :: proc(
    window: gfx_interface.Gfx_Window,
) -> (command_buffer: vk.CommandBuffer, image_index: u32, err: gfx_interface.Gfx_Error) {
    // Get the Vulkan window and device
    vk_win_internal, ok_win := window.variant.(^Vk_Window_Internal)
    if !ok_win || vk_win_internal == nil {
        log.error("vk_begin_frame: Invalid Gfx_Window (not Vulkan or nil variant).")
        return 0, 0, .Invalid_Handle
    }
    
    vk_dev_internal := vk_win_internal.device_ref
    if vk_dev_internal == nil {
        log.error("vk_begin_frame: Device reference is nil.")
        return 0, 0, .Invalid_Handle
    }

    // Wait for the previous frame to finish
    vk.WaitForFences(
        vk_dev_internal.logical_device,
        1,
        &vk_win_internal.in_flight_fences[vk_win_internal.current_frame],
        vk.TRUE,
        max(u64)
    )

    // Acquire the next image from the swapchain
    result := vk.AcquireNextImageKHR(
        vk_dev_internal.logical_device,
        vk_win_internal.swapchain,
        max(u64),
        vk_win_internal.image_available_semaphores[vk_win_internal.current_frame],
        0,
        &image_index
    )

    if result == .ERROR_OUT_OF_DATE_KHR {
        // Handle window resize
        return 0, 0, .Window_Resized
    } else if result != .SUCCESS && result != .SUBOPTIMAL_KHR {
        log.errorf("Failed to acquire swapchain image: %v", result)
        return 0, 0, .Device_Error
    }

    // Reset the fence for the current frame
    vk.ResetFences(
        vk_dev_internal.logical_device,
        1,
        &vk_win_internal.in_flight_fences[vk_win_internal.current_frame]
    )

    // Begin command buffer
    command_buffer = vk_win_internal.command_buffers[vk_win_internal.current_frame]
    vk.ResetCommandBuffer(command_buffer, {})

    begin_info := vk.CommandBufferBeginInfo{
        sType = .COMMAND_BUFFER_BEGIN_INFO,
    }

    if vk.BeginCommandBuffer(command_buffer, &begin_info) != .SUCCESS {
        log.error("Failed to begin recording command buffer")
        return 0, 0, .Device_Error
    }

    // Begin render pass
    clear_values := []vk.ClearValue{
        {color = {float32 = {0.0, 0.0, 0.0, 1.0}}},
    }

    render_pass_begin := vk.RenderPassBeginInfo{
        sType = .RENDER_PASS_BEGIN_INFO,
        renderPass = vk_win_internal.render_pass,
        framebuffer = vk_win_internal.swapchain_framebuffers[image_index],
        renderArea = vk.Rect2D{
            offset = {x = 0, y = 0},
            extent = vk_win_internal.swapchain_extent,
        },
        clearValueCount = u32(len(clear_values)),
        pClearValues = raw_data(clear_values),
    }

    vk.CmdBeginRenderPass(
        command_buffer,
        &render_pass_begin,
        .INLINE
    )

    // Set viewport and scissor
    viewport := vk.Viewport{
        x = 0.0,
        y = 0.0,
        width = f32(vk_win_internal.swapchain_extent.width),
        height = f32(vk_win_internal.swapchain_extent.height),
        minDepth = 0.0,
        maxDepth = 1.0,
    }
    vk.CmdSetViewport(command_buffer, 0, 1, &viewport)

    scissor := vk.Rect2D{
        offset = {x = 0, y = 0},
        extent = vk_win_internal.swapchain_extent,
    }
    vk.CmdSetScissor(command_buffer, 0, 1, &scissor)

    return command_buffer, image_index, .None
}

// vk_end_frame_internal ends the current frame and presents it
vk_end_frame_internal :: proc(
    window: gfx_interface.Gfx_Window,
    command_buffer: vk.CommandBuffer,
    image_index: u32,
) -> gfx_interface.Gfx_Error {
    // Get the Vulkan window and device
    vk_win_internal, ok_win := window.variant.(^Vk_Window_Internal)
    if !ok_win || vk_win_internal == nil {
        log.error("vk_end_frame: Invalid Gfx_Window (not Vulkan or nil variant).")
        return .Invalid_Handle
    }
    
    vk_dev_internal := vk_win_internal.device_ref
    if vk_dev_internal == nil {
        log.error("vk_end_frame: Device reference is nil.")
        return .Invalid_Handle
    }

    // End render pass
    vk.CmdEndRenderPass(command_buffer)

    // End command buffer
    if vk.EndCommandBuffer(command_buffer) != .SUCCESS {
        log.error("Failed to record command buffer")
        return .Device_Error
    }

    // Submit command buffer
    wait_semaphores := []vk.Semaphore{
        vk_win_internal.image_available_semaphores[vk_win_internal.current_frame],
    }
    wait_stages := []vk.PipelineStageFlags{{
        .COLOR_ATTACHMENT_OUTPUT_BIT,
    }}
    signal_semaphores := []vk.Semaphore{
        vk_win_internal.render_finished_semaphores[vk_win_internal.current_frame],
    }
    command_buffers := []vk.CommandBuffer{command_buffer}

    submit_info := vk.SubmitInfo{
        sType = .SUBMIT_INFO,
        waitSemaphoreCount = u32(len(wait_semaphores)),
        pWaitSemaphores = raw_data(wait_semaphores),
        pWaitDstStageMask = raw_data(wait_stages),
        commandBufferCount = u32(len(command_buffers)),
        pCommandBuffers = raw_data(command_buffers),
        signalSemaphoreCount = u32(len(signal_semaphores)),
        pSignalSemaphores = raw_data(signal_semaphores),
    }

    if vk.QueueSubmit(
        vk_dev_internal.graphics_queue,
        1,
        &submit_info,
        vk_win_internal.in_flight_fences[vk_win_internal.current_frame],
    ) != .SUCCESS {
        log.error("Failed to submit draw command buffer")
        return .Device_Error
    }

    // Present the frame
    swapchains := []vk.SwapchainKHR{vk_win_internal.swapchain}
    image_indices := []u32{image_index}
    present_info := vk.PresentInfoKHR{
        sType = .PRESENT_INFO_KHR,
        waitSemaphoreCount = u32(len(signal_semaphores)),
        pWaitSemaphores = raw_data(signal_semaphores),
        swapchainCount = u32(len(swapchains)),
        pSwapchains = raw_data(swapchains),
        pImageIndices = raw_data(image_indices),
        pResults = nil, // Optional
    }

    result := vk.QueuePresentKHR(vk_dev_internal.present_queue, &present_info)
    if result == .ERROR_OUT_OF_DATE_KHR || result == .SUBOPTIMAL_KHR {
        return .Window_Resized
    } else if result != .SUCCESS {
        log.errorf("Failed to present swapchain image: %v", result)
        return .Device_Error
    }

    // Update the current frame index
    vk_win_internal.current_frame = (vk_win_internal.current_frame + 1) % MAX_FRAMES_IN_FLIGHT

    return .None
}

// vk_draw_internal records a draw command
vk_draw_internal :: proc(
    command_buffer: vk.CommandBuffer,
    vertex_count: u32,
    instance_count: u32,
    first_vertex: u32,
    first_instance: u32,
) {
    vk.CmdDraw(command_buffer, vertex_count, instance_count, first_vertex, first_instance)
}

// vk_draw_indexed_internal records an indexed draw command
vk_draw_indexed_internal :: proc(
    command_buffer: vk.CommandBuffer,
    index_count: u32,
    instance_count: u32,
    first_index: u32,
    vertex_offset: i32,
    first_instance: u32,
) {
    vk.CmdDrawIndexed(
        command_buffer,
        index_count,
        instance_count,
        first_index,
        vertex_offset,
        first_instance
    )
}

// vk_bind_vertex_buffers_internal binds vertex buffers to command buffer
vk_bind_vertex_buffers_internal :: proc(
    command_buffer: vk.CommandBuffer,
    first_binding: u32,
    buffers: []vk.Buffer,
    offsets: []vk.DeviceSize,
) {
    vk.CmdBindVertexBuffers(
        command_buffer,
        first_binding,
        u32(len(buffers)),
        raw_data(buffers),
        raw_data(offsets)
    )
}

// vk_bind_index_buffer_internal binds an index buffer to command buffer
vk_bind_index_buffer_internal :: proc(
    command_buffer: vk.CommandBuffer,
    buffer: vk.Buffer,
    offset: vk.DeviceSize,
    index_type: vk.IndexType = .UINT16,
) {
    vk.CmdBindIndexBuffer(command_buffer, buffer, offset, index_type)
}

// vk_bind_pipeline_internal binds a pipeline to command buffer
vk_bind_pipeline_internal :: proc(
    command_buffer: vk.CommandBuffer,
    pipeline_bind_point: vk.PipelineBindPoint,
    pipeline: vk.Pipeline,
) {
    vk.CmdBindPipeline(command_buffer, pipeline_bind_point, pipeline)
}

// vk_bind_descriptor_sets_internal binds descriptor sets to command buffer
vk_bind_descriptor_sets_internal :: proc(
    command_buffer: vk.CommandBuffer,
    pipeline_bind_point: vk.PipelineBindPoint,
    layout: vk.PipelineLayout,
    first_set: u32,
    descriptor_sets: []vk.DescriptorSet,
    dynamic_offsets: []u32 = nil,
) {
    vk.CmdBindDescriptorSets(
        command_buffer,
        pipeline_bind_point,
        layout,
        first_set,
        u32(len(descriptor_sets)),
        raw_data(descriptor_sets),
        u32(len(dynamic_offsets)),
        raw_data(dynamic_offsets) if len(dynamic_offsets) > 0 else nil,
    )
}
