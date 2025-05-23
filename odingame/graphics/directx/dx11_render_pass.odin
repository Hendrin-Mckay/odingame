package directx11

import "../gfx_interface"
import "core:log"
import "core:mem"

// --- Render Pass Management ---

create_render_pass_impl :: proc(
    device: gfx_interface.Gfx_Device,
    color_attachment: gfx_interface.Texture_Descriptor,
    depth_stencil_attachment: Maybe(gfx_interface.Texture_Descriptor),
) -> (gfx_interface.Gfx_Render_Pass, gfx_interface.Gfx_Error) {
    log.warn("DirectX 11: create_render_pass_impl not implemented")
    // Real implementation would:
    // 1. Store the render pass configuration in D3D11_Render_Pass_Internal
    // 2. Create render target views and depth stencil views as needed
    return gfx_interface.Gfx_Render_Pass{}, .Not_Implemented
}

begin_render_pass_impl :: proc(
    device: gfx_interface.Gfx_Device,
    render_pass: gfx_interface.Gfx_Render_Pass,
    clear_color: Maybe(gfx_interface.Color) = nil,
    clear_depth: f32 = 1.0,
    clear_stencil: u32 = 0,
) -> gfx_interface.Gfx_Error {
    log.warn("DirectX 11: begin_render_pass_impl not implemented")
    // Real implementation would:
    // 1. Get the device context
    // 2. Set render targets using OMSetRenderTargets
    // 3. Clear render targets if clear values are provided
    return .Not_Implemented
}

end_render_pass_impl :: proc(device: gfx_interface.Gfx_Device) -> gfx_interface.Gfx_Error {
    log.warn("DirectX 11: end_render_pass_impl not implemented")
    // In DirectX 11, this is typically a no-op
    return .Not_Implemented
}

// --- Framebuffer Management ---

create_framebuffer_impl :: proc(
    device: gfx_interface.Gfx_Device,
    color_attachments: []gfx_interface.Gfx_Texture,
    depth_stencil_attachment: Maybe(gfx_interface.Gfx_Texture),
) -> (gfx_interface.Gfx_Framebuffer, gfx_interface.Gfx_Error) {
    log.warn("DirectX 11: create_framebuffer_impl not implemented")
    // Real implementation would:
    // 1. Create render target views for color attachments
    // 2. Create depth stencil view if depth attachment is provided
    // 3. Store the views in D3D11_Framebuffer_Internal
    return gfx_interface.Gfx_Framebuffer{}, .Not_Implemented
}

destroy_framebuffer_impl :: proc(framebuffer: gfx_interface.Gfx_Framebuffer) {
    log.warn("DirectX 11: destroy_framebuffer_impl not implemented")
    // Real implementation would:
    // 1. Release all render target views
    // 2. Release depth stencil view if it exists
    if fb_internal, ok := framebuffer.variant.(D3D11_Framebuffer_Variant); ok && fb_internal != nil {
        // free(fb_internal, fb_internal.allocator)
    }
}
