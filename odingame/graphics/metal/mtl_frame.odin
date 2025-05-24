package metal

import "core:log"
import "core:mem"
import "core:objc"
import "core:sys/darwin" // For system types if not in bindings

import "../gfx_interface"
import "../../common"
import "../../types" // For math.Color (now m.Color)
import "../../math"  // For m.Color
import "./mtl_types"
import "./mtl_bindings"


begin_frame_impl :: proc(
    device_handle: gfx_interface.Gfx_Device, 
    window_handle: gfx_interface.Gfx_Window,
) -> (
    err: common.Engine_Error, 
    frame_ctx: ^gfx_interface.Gfx_Frame_Context_Info,
) {
    // log.debug("Metal: begin_frame_impl called.")
    di := get_mtl_device_internal(device_handle)
    wi := get_mtl_window_internal(window_handle)

    if di == nil || di.device == nil || di.command_queue == nil {
        log.error("Metal: begin_frame_impl: Invalid MTL_Device_Internal state.")
        return .Invalid_Handle, nil
    }
    if wi == nil || wi.layer == nil {
        log.error("Metal: begin_frame_impl: Invalid MTL_Window_Internal state (layer is nil).")
        return .Invalid_Handle, nil
    }

    // 1. Obtain a drawable
    current_drawable := objc.msg_send(MTLDrawable_Handle, id(wi.layer), sel_nextDrawable)
    if current_drawable == nil {
        // This can happen if the window is not visible, resizing, etc.
        // It's not necessarily a fatal error for the frame, but drawing can't occur.
        log.warn("Metal: begin_frame_impl: Failed to get next drawable from CAMetalLayer. Skipping frame draw.")
        return .Swapchain_Out_Of_Date, nil // Or a specific error indicating no drawable
    }
    // objc_retain(id(current_drawable)) // nextDrawable is autoreleased, retain if held across autorelease pools

    // 2. Create a new command buffer for this frame
    command_buffer := objc.msg_send(MTLCommandBuffer_Handle, id(di.command_queue), sel_commandBuffer)
    if command_buffer == nil {
        log.error("Metal: begin_frame_impl: Failed to create MTLCommandBuffer.")
        objc_release(id(current_drawable)) // Release drawable if command buffer fails
        return .Device_Resource_Creation_Failed, nil
    }
    // objc_retain(id(command_buffer)) // commandBuffer is autoreleased

    // 3. Create a default MTLRenderPassDescriptor for the drawable's texture
    // This descriptor will be used by begin_render_pass_impl and modified by clear_screen_impl.
    rpd_alloc := objc.look_up_class("MTLRenderPassDescriptor")
    render_pass_descriptor := objc.msg_send(MTLRenderPassDescriptor_Handle, id(rpd_alloc), sel_renderPassDescriptor) // [MTLRenderPassDescriptor new] essentially
    if render_pass_descriptor == nil {
        log.error("Metal: begin_frame_impl: Failed to create MTLRenderPassDescriptor.")
        objc_release(id(command_buffer))
        objc_release(id(current_drawable))
        return .Device_Resource_Creation_Failed, nil
    }
    // objc_retain(id(render_pass_descriptor))

    // Configure color attachment 0 for the drawable's texture
    drawable_texture := objc.msg_send(MTLTexture_Handle, id(current_drawable), sel_texture)
    
    color_attachments_array := objc.msg_send(id, id(render_pass_descriptor), sel_colorAttachments)
    color_attachment_0 := objc.msg_send(id, color_attachments_array, sel_objectAtIndexedSubscript, NSUInteger(0))

    objc.msg_send(nil, color_attachment_0, sel_setTexture, drawable_texture)
    objc.msg_send(nil, color_attachment_0, sel_setLoadAction, MTLLoadAction.DontCare) // Default, clear_screen will change to .Clear
    objc.msg_send(nil, color_attachment_0, sel_setStoreAction, MTLStoreAction.Store)
    // Default clear color (transparent black), clear_screen_impl will set user's color.
    default_clear_color := MTLClearColor{0.0, 0.0, 0.0, 0.0}
    objc.msg_send(nil, color_attachment_0, sel_setClearColor, default_clear_color)

    // TODO: Configure depth and stencil attachments if a depth/stencil texture is associated with the window/framebuffer.
    // For now, assuming color only.

    // Store these in Gfx_Frame_Context_Info
    // This context info needs to be allocated. Game loop should manage its memory.
    // For now, assume it's passed in or we allocate it here (caller must free).
    // The interface returns ^Gfx_Frame_Context_Info, so we must allocate.
    ctx := new(gfx_interface.Gfx_Frame_Context_Info, di.allocator) // Use device's allocator
    ctx.mtl_current_drawable = current_drawable
    ctx.mtl_command_buffer = command_buffer
    ctx.mtl_main_render_pass_descriptor = render_pass_descriptor
    
    return .None, ctx
}

clear_screen_impl :: proc(
    device_handle: gfx_interface.Gfx_Device, 
    frame_ctx: ^gfx_interface.Gfx_Frame_Context_Info, 
    options: gfx_interface.Clear_Options,
) {
    if frame_ctx == nil || frame_ctx.mtl_main_render_pass_descriptor == nil {
        log.error("Metal: clear_screen_impl: Invalid frame context or render pass descriptor.")
        return
    }
    // di := get_mtl_device_internal(device_handle) // Not strictly needed if only RPD is modified

    rpd := frame_ctx.mtl_main_render_pass_descriptor
    color_attachments_array := objc.msg_send(id, id(rpd), sel_colorAttachments)
    color_attachment_0 := objc.msg_send(id, color_attachments_array, sel_objectAtIndexedSubscript, NSUInteger(0))

    if options.clear_color {
        clear_color_mtl := MTLClearColor{
            f64(options.color[0]), 
            f64(options.color[1]), 
            f64(options.color[2]), 
            f64(options.color[3]),
        }
        objc.msg_send(nil, color_attachment_0, sel_setClearColor, clear_color_mtl)
        objc.msg_send(nil, color_attachment_0, sel_setLoadAction, MTLLoadAction.Clear)
    } else {
        // If not clearing color, set load action to Load or DontCare.
        // If previous contents are needed, use Load. If not, DontCare.
        objc.msg_send(nil, color_attachment_0, sel_setLoadAction, MTLLoadAction.DontCare)
    }

    // TODO: Handle depth and stencil clear if options.clear_depth / options.clear_stencil are true
    // This would involve getting depthAttachment/stencilAttachment from RPD and setting their loadAction/clearDepth/clearStencil.
    // if options.clear_depth {
    //     depth_attachment := objc.msg_send(id, id(rpd), sel_depthAttachment)
    //     objc.msg_send(nil, depth_attachment, sel_setClearDepth, f64(options.depth))
    //     objc.msg_send(nil, depth_attachment, sel_setLoadAction, MTLLoadAction.Clear)
    // }
    // if options.clear_stencil {
    //     stencil_attachment := objc.msg_send(id, id(rpd), sel_stencilAttachment)
    //     objc.msg_send(nil, stencil_attachment, sel_setClearStencil, u32(options.stencil)) // Assuming stencil is u32 for clear
    //     objc.msg_send(nil, stencil_attachment, sel_setLoadAction, MTLLoadAction.Clear)
    // }
}

begin_render_pass_impl :: proc(
    device_handle: gfx_interface.Gfx_Device, 
    frame_ctx: ^gfx_interface.Gfx_Frame_Context_Info,
    // pass_desc: gfx_interface.Render_Pass_Desc, // For offscreen passes or specific targets
) -> rawptr /* encoder_handle */ {
    // log.debug("Metal: begin_render_pass_impl called.")
    if frame_ctx == nil || frame_ctx.mtl_command_buffer == nil || frame_ctx.mtl_main_render_pass_descriptor == nil {
        log.error("Metal: begin_render_pass_impl: Invalid frame context (command buffer or RPD is nil).")
        return nil
    }
    // di := get_mtl_device_internal(device_handle) // Not needed if command_buffer is from frame_ctx

    command_buffer := frame_ctx.mtl_command_buffer
    render_pass_descriptor := frame_ctx.mtl_main_render_pass_descriptor
    
    // Create Render Command Encoder
    render_encoder := objc.msg_send(MTLRenderCommandEncoder_Handle, id(command_buffer), 
                                   sel_renderCommandEncoderWithDescriptor, render_pass_descriptor)
    
    if render_encoder == nil {
        log.error("Metal: Failed to create MTLRenderCommandEncoder.")
        return nil
    }
    // objc_retain(id(render_encoder)) // Encoders are typically autoreleased

    // log.debugf("Metal: MTLRenderCommandEncoder created: %v", render_encoder)
    return rawptr(render_encoder)
}

end_render_pass_impl :: proc(encoder_handle: rawptr) {
    // log.debug("Metal: end_render_pass_impl called.")
    if encoder_handle == nil {
        log.warn("Metal: end_render_pass_impl: Encoder handle is nil.")
        return
    }
    render_encoder := MTLRenderCommandEncoder_Handle(encoder_handle)
    objc.msg_send(nil, id(render_encoder), sel_endEncoding)
    // log.debugf("Metal: MTLRenderCommandEncoder endEncoding called: %v", render_encoder)
    objc_release(id(render_encoder)) // Release if retained, or if it's best practice for encoders from command_buffer
}

end_frame_impl :: proc(
    device_handle: gfx_interface.Gfx_Device, 
    window_handle: gfx_interface.Gfx_Window, 
    frame_ctx: ^gfx_interface.Gfx_Frame_Context_Info,
) {
    // log.debug("Metal: end_frame_impl called.")
    if frame_ctx == nil || frame_ctx.mtl_command_buffer == nil || frame_ctx.mtl_current_drawable == nil {
        log.error("Metal: end_frame_impl: Invalid frame context (cmd buffer or drawable is nil).")
        // If frame_ctx itself is nil, it might mean begin_frame failed (e.g. no drawable).
        // In that case, there's nothing to present.
        return
    }
    // di := get_mtl_device_internal(device_handle) // Not needed
    // wi := get_mtl_window_internal(window_handle) // Not needed if drawable is in frame_ctx

    command_buffer := frame_ctx.mtl_command_buffer
    drawable := frame_ctx.mtl_current_drawable

    // 1. Present Drawable
    objc.msg_send(nil, id(command_buffer), sel_presentDrawable, drawable)
    // log.debugf("Metal: MTLCommandBuffer presentDrawable called for drawable: %v", drawable)

    // 2. Commit Command Buffer
    objc.msg_send(nil, id(command_buffer), sel_commit)
    // log.debugf("Metal: MTLCommandBuffer commit called: %v", command_buffer)

    // Optional: Wait for completion for synchronous behavior or debugging
    // objc.msg_send(nil, id(command_buffer), sel_waitUntilCompleted)
    // log.debug("Metal: MTLCommandBuffer waitUntilCompleted.")

    // 3. Release per-frame objects (drawable, command buffer, RPD)
    // These were allocated/retained in begin_frame_impl.
    // The Gfx_Frame_Context_Info struct itself will be freed by the game loop or caller of begin_frame.
    objc_release(id(frame_ctx.mtl_main_render_pass_descriptor))
    objc_release(id(frame_ctx.mtl_command_buffer))
    objc_release(id(frame_ctx.mtl_current_drawable))
    
    // Null out the pointers in frame_ctx to prevent double release if it's somehow reused (it shouldn't be).
    frame_ctx.mtl_main_render_pass_descriptor = nil
    frame_ctx.mtl_command_buffer = nil
    frame_ctx.mtl_current_drawable = nil
}
