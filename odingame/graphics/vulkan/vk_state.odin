package vulkan

import vk "vendor:vulkan"
import "core:log"
import "core:mem"
import "../gfx_interface"

// --- State Management ---

// vk_set_viewport_internal sets the viewport for the current command buffer
vk_set_viewport_internal :: proc(
    command_buffer: vk.CommandBuffer,
    x, y, width, height: f32,
    min_depth: f32 = 0.0,
    max_depth: f32 = 1.0,
) {
    viewport := vk.Viewport{
        x = x,
        y = y,
        width = width,
        height = height,
        minDepth = min_depth,
        maxDepth = max_depth,
    }
    vk.CmdSetViewport(command_buffer, 0, 1, &viewport)
}

// vk_set_scissor_internal sets the scissor rectangle for the current command buffer
vk_set_scissor_internal :: proc(
    command_buffer: vk.CommandBuffer,
    x, y: i32,
    width, height: u32,
) {
    scissor := vk.Rect2D{
        offset = {x = x, y = y},
        extent = {width = width, height = height},
    }
    vk.CmdSetScissor(command_buffer, 0, 1, &scissor)
}

// vk_set_blend_state_internal configures the blend state for a pipeline
vk_set_blend_state_internal :: proc(
    logical_device: vk.Device,
    pipeline: vk.Pipeline,
    enable: bool = true,
    src_color: vk.BlendFactor = .SRC_ALPHA,
    dst_color: vk.BlendFactor = .ONE_MINUS_SRC_ALPHA,
    op_color: vk.BlendOp = .ADD,
    src_alpha: vk.BlendFactor = .ONE,
    dst_alpha: vk.BlendFactor = .ZERO,
    op_alpha: vk.BlendOp = .ADD,
) -> gfx_interface.Gfx_Error {
    // Note: In Vulkan, blend state is part of the pipeline state
    // This function is a no-op in Vulkan as blend state must be specified at pipeline creation
    // Consider removing this function or making it a helper for pipeline creation
    return .None
}

// vk_set_depth_state_internal configures the depth test state
vk_set_depth_state_internal :: proc(
    command_buffer: vk.CommandBuffer,
    test_enable: bool,
    write_enable: bool,
    compare_op: vk.CompareOp = .LESS,
) {
    // In Vulkan, depth test state is part of the pipeline state
    // This function uses dynamic state if VK_EXT_extended_dynamic_state is available
    // Otherwise, it's a no-op and the state must be set at pipeline creation
    #config VULKAN_EXTENDED_DYNAMIC_STATE, false
    when VULKAN_EXTENDED_DYNAMIC_STATE {
        vk.CmdSetDepthTestEnableEXT(command_buffer, test_enable)
        vk.CmdSetDepthWriteEnableEXT(command_buffer, write_enable)
        vk.CmdSetDepthCompareOpEXT(command_buffer, compare_op)
    } else {
        // Log a warning if trying to change depth state dynamically without the extension
        if test_enable || write_enable || compare_op != .LESS {
            log.warn("Depth state changes require VK_EXT_extended_dynamic_state")
        }
    }
}

// vk_set_cull_mode_internal sets the face culling mode
vk_set_cull_mode_internal :: proc(
    command_buffer: vk.CommandBuffer,
    cull_mode: vk.CullModeFlags,
    front_face: vk.FrontFace = .COUNTER_CLOCKWISE,
) {
    // In Vulkan, cull mode is part of the pipeline state
    // This function uses dynamic state if VK_EXT_extended_dynamic_state is available
    // Otherwise, it's a no-op and the state must be set at pipeline creation
    #config VULKAN_EXTENDED_DYNAMIC_STATE, false
    when VULKAN_EXTENDED_DYNAMIC_STATE {
        vk.CmdSetCullModeEXT(command_buffer, cull_mode)
        vk.CmdSetFrontFaceEXT(command_buffer, front_face)
    } else {
        // Log a warning if trying to change cull mode dynamically without the extension
        if cull_mode != {.BACK} || front_face != .COUNTER_CLOCKWISE {
            log.warn("Cull mode changes require VK_EXT_extended_dynamic_state")
        }
    }
}

// vk_set_line_width_internal sets the line width for line primitives
vk_set_line_width_internal :: proc(
    command_buffer: vk.CommandBuffer,
    width: f32,
) {
    vk.CmdSetLineWidth(command_buffer, width)
}

// vk_set_depth_bias_internal enables/disables depth bias
vk_set_depth_bias_internal :: proc(
    command_buffer: vk.CommandBuffer,
    enable: bool,
    constant_factor: f32 = 0.0,
    clamp: f32 = 0.0,
    slope_factor: f32 = 0.0,
) {
    vk.CmdSetDepthBias(
        command_buffer,
        constant_factor,
        clamp,
        slope_factor,
    )
}

// vk_set_stencil_state_internal configures the stencil test state
vk_set_stencil_state_internal :: proc(
    command_buffer: vk.CommandBuffer,
    enable: bool,
    front: vk.StencilOpState = {},
    back: vk.StencilOpState = {},
) {
    // In Vulkan, stencil state is part of the pipeline state
    // This function uses dynamic state if VK_EXT_extended_dynamic_state is available
    // Otherwise, it's a no-op and the state must be set at pipeline creation
    #config VULKAN_EXTENDED_DYNAMIC_STATE, false
    when VULKAN_EXTENDED_DYNAMIC_STATE {
        vk.CmdSetStencilTestEnableEXT(command_buffer, enable)
        if enable {
            vk.CmdSetStencilOpEXT(
                command_buffer,
                .FRONT,
                front.failOp,
                front.passOp,
                front.depthFailOp,
                front.compareOp,
            )
            vk.CmdSetStencilOpEXT(
                command_buffer,
                .BACK,
                back.failOp,
                back.passOp,
                back.depthFailOp,
                back.compareOp,
            )
        }
    } else {
        // Log a warning if trying to change stencil state dynamically without the extension
        if enable {
            log.warn("Stencil state changes require VK_EXT_extended_dynamic_state")
        }
    }
}
