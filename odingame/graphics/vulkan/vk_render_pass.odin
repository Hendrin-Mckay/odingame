package vulkan

import vk "vendor:vulkan"
import "core:log"
import "core:mem"
import "../gfx_interface"

// --- Render Pass Management ---

// vk_create_render_pass_internal creates a basic render pass for the swapchain
vk_create_render_pass_internal :: proc(
    logical_device: vk.Device,
    swapchain_format: vk.Format,
) -> (vk.RenderPass, gfx_interface.Gfx_Error) {
    // Color attachment
    color_attachment := vk.AttachmentDescription{
        format = swapchain_format,
        samples = { ._1 },
        loadOp = .CLEAR,
        storeOp = .STORE,
        stencilLoadOp = .DONT_CARE,
        stencilStoreOp = .DONT_CARE,
        initialLayout = .UNDEFINED,
        finalLayout = .PRESENT_SRC_KHR,
    }

    // Subpass
    color_attachment_ref := vk.AttachmentReference{
        attachment = 0,
        layout = .COLOR_ATTACHMENT_OPTIMAL,
    }

    subpass := vk.SubpassDescription{
        pipelineBindPoint = .GRAPHICS,
        colorAttachmentCount = 1,
        pColorAttachments = &color_attachment_ref,
    }

    // Subpass dependencies
    dependency := vk.SubpassDependency{
        srcSubpass = vk.SUBPASS_EXTERNAL,
        dstSubpass = 0,
        srcStageMask = { .COLOR_ATTACHMENT_OUTPUT },
        srcAccessMask = {},
        dstStageMask = { .COLOR_ATTACHMENT_OUTPUT },
        dstAccessMask = { .COLOR_ATTACHMENT_WRITE },
    }

    // Create render pass
    render_pass_info := vk.RenderPassCreateInfo{
        sType = .RENDER_PASS_CREATE_INFO,
        attachmentCount = 1,
        pAttachments = &color_attachment,
        subpassCount = 1,
        pSubpasses = &subpass,
        dependencyCount = 1,
        pDependencies = &dependency,
    }

    render_pass: vk.RenderPass
    result := vk.CreateRenderPass(logical_device, &render_pass_info, nil, &render_pass)
    if result != .SUCCESS {
        log.errorf("Failed to create render pass: %v", result)
        return 0, .Render_Pass_Creation_Failed
    }

    return render_pass, .None
}

// vk_destroy_render_pass_internal destroys a Vulkan render pass
vk_destroy_render_pass_internal :: proc(
    logical_device: vk.Device,
    render_pass: vk.RenderPass,
) {
    if render_pass != 0 {
        vk.DestroyRenderPass(logical_device, render_pass, nil)
    }
}

// vk_begin_render_pass_internal begins a render pass
vk_begin_render_pass_internal :: proc(
    command_buffer: vk.CommandBuffer,
    render_pass: vk.RenderPass,
    framebuffer: vk.Framebuffer,
    extent: vk.Extent2D,
    clear_values: []vk.ClearValue,
) {
    render_pass_begin := vk.RenderPassBeginInfo{
        sType = .RENDER_PASS_BEGIN_INFO,
        renderPass = render_pass,
        framebuffer = framebuffer,
        renderArea = vk.Rect2D{
            offset = { x = 0, y = 0 },
            extent = extent,
        },
        clearValueCount = u32(len(clear_values)),
        pClearValues = raw_data(clear_values),
    }

    vk.CmdBeginRenderPass(command_buffer, &render_pass_begin, .INLINE)
}

// vk_end_render_pass_internal ends the current render pass
vk_end_render_pass_internal :: proc(command_buffer: vk.CommandBuffer) {
    vk.CmdEndRenderPass(command_buffer)
}

// vk_create_framebuffer_internal creates a framebuffer for the given render pass and attachments
vk_create_framebuffer_internal :: proc(
    logical_device: vk.Device,
    render_pass: vk.RenderPass,
    attachments: []vk.ImageView,
    width, height: u32,
) -> (vk.Framebuffer, gfx_interface.Gfx_Error) {
    framebuffer_info := vk.FramebufferCreateInfo{
        sType = .FRAMEBUFFER_CREATE_INFO,
        renderPass = render_pass,
        attachmentCount = u32(len(attachments)),
        pAttachments = raw_data(attachments),
        width = width,
        height = height,
        layers = 1,
    }

    framebuffer: vk.Framebuffer
    result := vk.CreateFramebuffer(logical_device, &framebuffer_info, nil, &framebuffer)
    if result != .SUCCESS {
        log.errorf("Failed to create framebuffer: %v", result)
        return 0, .Framebuffer_Creation_Failed
    }

    return framebuffer, .None
}

// vk_destroy_framebuffer_internal destroys a Vulkan framebuffer
vk_destroy_framebuffer_internal :: proc(
    logical_device: vk.Device,
    framebuffer: vk.Framebuffer,
) {
    if framebuffer != 0 {
        vk.DestroyFramebuffer(logical_device, framebuffer, nil)
    }
}
