package metal

import "../gfx_interface"
import "../../common" // For common.Engine_Error
import "core:log"

// --- Gfx_Device_Interface Render Pass and Framebuffer Stubs ---

// In Metal, render passes are defined by MTLRenderPassDescriptor and are transient objects
// created each frame. The Gfx_Render_Pass concept maps to a MTLRenderPassDescriptor.

mtl_create_render_pass_wrapper :: proc(
    device: gfx_interface.Gfx_Device,
    color_attachment: gfx_interface.Texture_Descriptor,
    depth_stencil_attachment: Maybe(gfx_interface.Texture_Descriptor),
) -> (gfx_interface.Gfx_Render_Pass, common.Engine_Error) {
    log.warn("Metal: create_render_pass_wrapper not implemented.")
    // Real Metal:
    // 1. Create a MTLRenderPassDescriptor
    // 2. Configure color attachments (MTLRenderPassColorAttachmentDescriptor)
    // 3. Configure depth/stencil attachments if provided
    // 4. Store configuration in Mtl_Render_Pass_Internal
    return gfx_interface.Gfx_Render_Pass{}, common.Engine_Error.Not_Implemented
}

mtl_begin_render_pass_wrapper :: proc(
    device: gfx_interface.Gfx_Device,
    render_pass: gfx_interface.Gfx_Render_Pass,
    clear_color: Maybe(gfx_interface.Color) = nil,
    clear_depth: f32 = 1.0,
    clear_stencil: u32 = 0,
) -> common.Engine_Error {
    log.warn("Metal: begin_render_pass_wrapper not implemented.")
    // Real Metal:
    // 1. Get the current drawable from the swapchain
    // 2. Create a MTLRenderPassDescriptor
    // 3. Configure clear colors, load/store actions
    // 4. Create a MTLRenderCommandEncoder from the command buffer
    // 5. Store the encoder in the device state
    return common.Engine_Error.Not_Implemented
}

mtl_end_render_pass_wrapper :: proc(device: gfx_interface.Gfx_Device) -> common.Engine_Error {
    log.warn("Metal: end_render_pass_wrapper not implemented.")
    // Real Metal:
    // 1. Call endEncoding on the current render command encoder
    // 2. Present the drawable if it's the main framebuffer
    // 3. Commit the command buffer
    return common.Engine_Error.Not_Implemented
}

// --- Framebuffer Management ---

mtl_create_framebuffer_wrapper :: proc(
    device: gfx_interface.Gfx_Device,
    color_attachments: []gfx_interface.Gfx_Texture,
    depth_stencil_attachment: Maybe(gfx_interface.Gfx_Texture),
) -> (gfx_interface.Gfx_Framebuffer, common.Engine_Error) {
    log.warn("Metal: create_framebuffer_wrapper not implemented.")
    // Real Metal:
    // 1. Create a MTLTexture for each attachment if needed
    // 2. Store the textures in Mtl_Framebuffer_Internal
    // 3. The actual MTLRenderPassDescriptor will be created at render time
    return gfx_interface.Gfx_Framebuffer{}, common.Engine_Error.Not_Implemented
}

mtl_destroy_framebuffer_wrapper :: proc(framebuffer: gfx_interface.Gfx_Framebuffer) {
    log.warn("Metal: destroy_framebuffer_wrapper not implemented.")
    // Real Metal: Release any MTLTextures and free the framebuffer
    if fb_internal, ok := framebuffer.variant.(Mtl_Framebuffer_Variant); ok && fb_internal != nil {
        // Placeholder for freeing variant data
        // free(fb_internal, fb_internal.allocator);
    }
}

// --- Helper Functions ---

// Converts Gfx_Texture_Format to MTLPixelFormat
mtl_pixel_format :: proc(format: gfx_interface.Texture_Format) -> u32 {
    // This is a placeholder. In a real implementation, you would map
    // your Gfx_Texture_Format enum to MTLPixelFormat values.
    #partial switch format {
    case .R8:       return 0 // Replace with actual MTLPixelFormat enum value
    case .RG8:      return 0
    case .RGB8:     return 0
    case .RGBA8:    return 0
    case .BGRA8:    return 0
    case .R16:      return 0
    case .RG16:     return 0
    case .RGB16:    return 0
    case .RGBA16:   return 0
    case .R16F:     return 0
    case .RG16F:    return 0
    case .RGB16F:   return 0
    case .RGBA16F:  return 0
    case .R32F:     return 0
    case .RG32F:    return 0
    case .RGB32F:   return 0
    case .RGBA32F:  return 0
    case .D16:      return 0
    case .D24:      return 0
    case .D32:      return 0
    case .D24_S8:   return 0
    case .D32_S8:   return 0
    case:           return 0
    }
}

// Creates a MTLRenderPassDescriptor for a framebuffer
mtl_create_render_pass_descriptor :: proc(
    framebuffer: gfx_interface.Gfx_Framebuffer,
) -> rawptr {
    // This is a placeholder. In a real implementation, you would:
    // 1. Create a MTLRenderPassDescriptor
    // 2. Configure color attachments
    // 3. Configure depth/stencil attachments
    // 4. Return the descriptor
    return nil
}
