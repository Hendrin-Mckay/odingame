package opengl

import "../gfx_interface"
import "../../common" // For common.Engine_Error
import "core:log"
import "core:mem"
import "core:slice"
import gl "vendor:OpenGL/gl"

// --- Framebuffer Types ---

Framebuffer_Attachment :: struct {
    texture: ^Texture, // This should be ^Gl_Texture if Texture is the OpenGL specific one
    level: i32,
    layer: i32,
}

Framebuffer :: struct {
    id: u32,
    width, height: int,
    color_attachments: [dynamic]Framebuffer_Attachment,
    depth_stencil_attachment: Maybe(Framebuffer_Attachment),
    is_complete: bool,
}

// --- Render Pass Types ---

Render_Pass :: struct {
    framebuffer: ^Framebuffer,
    clear_color: [4]f32, // This was gfx_interface.Color, ensure consistency or map
    clear_depth: f32,
    clear_stencil: u32,
    viewport: [4]i32, // x, y, width, height
}

// --- Framebuffer Management ---
create_framebuffer_impl :: proc(
    device: gfx_interface.Gfx_Device,
    width, height: int,
    color_attachments: []gfx_interface.Gfx_Texture,
    depth_stencil_attachment: Maybe(gfx_interface.Gfx_Texture),
) -> (gfx_interface.Gfx_Framebuffer, common.Engine_Error) {
    // Create framebuffer
    var fbo_id: u32
    gl.GenFramebuffers(1, &fbo_id)
    if fbo_id == 0 {
        return gfx_interface.Gfx_Framebuffer{}, common.Engine_Error.Framebuffer_Creation_Failed
    }
    
    gl.BindFramebuffer(gl.FRAMEBUFFER, fbo_id)
    
    // Create framebuffer wrapper
    framebuffer := new(Framebuffer)
    framebuffer.id = fbo_id
    framebuffer.width = width
    framebuffer.height = height
    framebuffer.color_attachments = make([dynamic]Framebuffer_Attachment, 0, len(color_attachments))
    framebuffer.is_complete = false
    
    // Attach color textures
    for color_attachment_gfx, i in color_attachments {
        // Assuming Gl_Texture is the correct variant type for OpenGL textures
        if tex, ok := color_attachment_gfx.variant.(^Gl_Texture); ok {
            gl.FramebufferTexture2D(
                gl.FRAMEBUFFER,
                gl.COLOR_ATTACHMENT0 + u32(i),
                gl.TEXTURE_2D,
                tex.id,
                0
            )
            
            attachment := Framebuffer_Attachment{
                texture = tex, // This should be ^Gl_Texture
                level = 0,
                layer = 0,
            }
            append(&framebuffer.color_attachments, attachment)
        } else {
            destroy_framebuffer_impl(gfx_interface.Gfx_Framebuffer{framebuffer})
            return gfx_interface.Gfx_Framebuffer{}, common.Engine_Error.Invalid_Handle
        }
    }
    
    // Attach depth/stencil texture if provided
    if depth_tex_gfx, ok_depth := depth_stencil_attachment.?(gfx_interface.Gfx_Texture); ok_depth {
        if tex, ok_tex_variant := depth_tex_gfx.variant.(^Gl_Texture); ok_tex_variant {
            attachment_point: u32
            
            // Assuming tex.format refers to the Gfx_Texture_Format stored in Gl_Texture
            switch tex.format {
            case .Depth24_Stencil8: // This enum member is from gfx_interface.Texture_Format
                attachment_point = gl.DEPTH_STENCIL_ATTACHMENT
            // Add other depth/stencil formats if necessary
            case .D16: attachment_point = gl.DEPTH_ATTACHMENT // Example
            case .D24: attachment_point = gl.DEPTH_ATTACHMENT // Example
            case .D32: attachment_point = gl.DEPTH_ATTACHMENT // Example
            case: // Default to depth if format is unknown but used as depth/stencil
                log.warnf("Unknown depth/stencil format %v, defaulting to DEPTH_ATTACHMENT", tex.format)
                attachment_point = gl.DEPTH_ATTACHMENT
            }
            
            gl.FramebufferTexture2D(
                gl.FRAMEBUFFER,
                attachment_point,
                gl.TEXTURE_2D,
                tex.id,
                0
            )
            
            attachment := Framebuffer_Attachment{
                texture = tex, // This should be ^Gl_Texture
                level = 0,
                layer = 0,
            }
            framebuffer.depth_stencil_attachment = attachment
        } else {
            destroy_framebuffer_impl(gfx_interface.Gfx_Framebuffer{framebuffer})
            return gfx_interface.Gfx_Framebuffer{}, common.Engine_Error.Invalid_Handle
        }
    }
    
    // Check framebuffer completeness
    status := gl.CheckFramebufferStatus(gl.FRAMEBUFFER)
    if status != gl.FRAMEBUFFER_COMPLETE {
        log.errorf("Framebuffer is not complete: 0x%x", status)
        destroy_framebuffer_impl(gfx_interface.Gfx_Framebuffer{framebuffer})
        return gfx_interface.Gfx_Framebuffer{}, common.Engine_Error.Framebuffer_Creation_Failed
    }
    
    framebuffer.is_complete = true
    
    // Unbind framebuffer
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
    
    log.debugf("Created framebuffer (ID: %d, %dx%d, %d color attachments)", 
        fbo_id, width, height, len(color_attachments))
    
    return gfx_interface.Gfx_Framebuffer{framebuffer}, common.Engine_Error.None
}

destroy_framebuffer_impl :: proc(framebuffer: gfx_interface.Gfx_Framebuffer) {
    if fb, ok := framebuffer.variant.(^Framebuffer); ok {
        if fb.id != 0 {
            gl.DeleteFramebuffers(1, &fb.id)
            fb.id = 0
        }
        
        if fb.color_attachments != nil {
            delete(fb.color_attachments)
        }
        
        free(fb) // Assuming fb was allocated with context.allocator or similar
    }
}

// --- Render Pass Management ---
create_render_pass_impl :: proc(
    device: gfx_interface.Gfx_Device,
    framebuffer_param: gfx_interface.Gfx_Framebuffer, // Renamed to avoid conflict
    clear_color_param: [4]f32 = {0, 0, 0, 1}, // Renamed
    clear_depth_param: f32 = 1.0, // Renamed
    clear_stencil_param: u32 = 0, // Renamed
) -> (gfx_interface.Gfx_Render_Pass, common.Engine_Error) {
    if fb, ok := framebuffer_param.variant.(^Framebuffer); ok && fb.is_complete {
        render_pass := new(Render_Pass)
        render_pass.framebuffer = fb
        render_pass.clear_color = clear_color_param
        render_pass.clear_depth = clear_depth_param
        render_pass.clear_stencil = clear_stencil_param
        render_pass.viewport = {0, 0, i32(fb.width), i32(fb.height)}
        
        return gfx_interface.Gfx_Render_Pass{render_pass}, common.Engine_Error.None
    }
    return gfx_interface.Gfx_Render_Pass{}, common.Engine_Error.Invalid_Handle
}

begin_render_pass_impl :: proc(
    device: gfx_interface.Gfx_Device,
    render_pass: gfx_interface.Gfx_Render_Pass,
) -> common.Engine_Error { // Added return type
    if pass, ok := render_pass.variant.(^Render_Pass); ok {
        fb := pass.framebuffer
        
        // Bind framebuffer
        gl.BindFramebuffer(gl.FRAMEBUFFER, fb.id)
        
        // Set viewport
        gl.Viewport(
            pass.viewport[0], pass.viewport[1],
            pass.viewport[2], pass.viewport[3]
        )
        
        // Clear color attachments
        if len(fb.color_attachments) > 0 {
             // Assuming pass.clear_color is [4]f32
            gl.ClearColor(
                pass.clear_color[0],
                pass.clear_color[1],
                pass.clear_color[2],
                pass.clear_color[3],
            )
            gl.Clear(gl.COLOR_BUFFER_BIT)
        }
        
        // Clear depth buffer if we have one
        if fb.depth_stencil_attachment != nil {
            gl.ClearDepthf(pass.clear_depth) // OpenGL uses ClearDepthf for float
            gl.Clear(gl.DEPTH_BUFFER_BIT)
        }
        
        // Clear stencil buffer if we have one
        if ds_attach, ds_ok := fb.depth_stencil_attachment.?(Framebuffer_Attachment); ds_ok {
             // Assuming Gl_Texture is the correct type for ds_attach.texture
            if ds_attach.texture.format == .Depth24_Stencil8 { // This enum is from gfx_interface
                gl.ClearStencil(i32(pass.clear_stencil))
                gl.Clear(gl.STENCIL_BUFFER_BIT)
            }
        }
        
        // Enable depth test by default
        gl.Enable(gl.DEPTH_TEST)
        
        return common.Engine_Error.None
    }
    return common.Engine_Error.Invalid_Handle
}

end_render_pass_impl :: proc(
    device: gfx_interface.Gfx_Device,
    render_pass: gfx_interface.Gfx_Render_Pass,
) -> common.Engine_Error { // Added return type
    // In OpenGL, ending a render pass is mostly about unbinding the framebuffer
    // and performing any necessary resolves (handled automatically for FBOs)
    gl.BindFramebuffer(gl.FRAMEBUFFER, 0)
    return common.Engine_Error.None
}

// --- Viewport and Scissor ---
set_viewport_impl :: proc(
    device: gfx_interface.Gfx_Device,
    x, y, width, height: i32,
) -> common.Engine_Error { // Added return type
    gl.Viewport(x, y, width, height)
    return common.Engine_Error.None
}

set_scissor_impl :: proc(
    device: gfx_interface.Gfx_Device,
    x, y, width, height: i32,
) -> common.Engine_Error { // Added return type
    gl.Scissor(x, y, width, height)
    gl.Enable(gl.SCISSOR_TEST)
    return common.Engine_Error.None
}

disable_scissor_impl :: proc(device: gfx_interface.Gfx_Device) -> common.Engine_Error { // Added return type
    gl.Disable(gl.SCISSOR_TEST)
    return common.Engine_Error.None
}

// --- State Management ---
set_blend_mode_impl :: proc(
    device: gfx_interface.Gfx_Device,
    enabled: bool,
    src_factor: gfx_interface.Blend_Factor = .Src_Alpha,
    dst_factor: gfx_interface.Blend_Factor = .One_Minus_Src_Alpha,
) -> common.Engine_Error { // Added blend_op and return type
    if enabled {
        gl.Enable(gl.BLEND)
        gl.BlendFunc(
            get_gl_blend_factor(src_factor),
            get_gl_blend_factor(dst_factor)
        )
        // blend_op is not directly used here as glBlendEquation is separate
        // For simplicity, assuming common Add operation, which is GL default.
        // if blend_op needs to be configurable:
        // gl.BlendEquation(get_gl_blend_op(blend_op))
    } else {
        gl.Disable(gl.BLEND)
    }
    return common.Engine_Error.None
}

set_depth_test_impl :: proc(
    device: gfx_interface.Gfx_Device,
    enabled: bool,
    write_mask: bool = true, // Renamed from write_enabled
    compare_op: gfx_interface.Compare_Op = .Less_Or_Equal, // Renamed from func
) -> common.Engine_Error { // Added return type
    if enabled {
        gl.Enable(gl.DEPTH_TEST)
        gl.DepthFunc(get_gl_compare_func(compare_op))
        gl.DepthMask(write_mask ? gl.TRUE : gl.FALSE)
    } else {
        gl.Disable(gl.DEPTH_TEST)
    }
    return common.Engine_Error.None
}

set_cull_mode_impl :: proc(
    device: gfx_interface.Gfx_Device,
    mode: gfx_interface.Cull_Mode,
) -> common.Engine_Error { // Added front_face and return type
    // front_face parameter is not directly used in this GL wrapper as glFrontFace is separate state.
    // Default CCW is assumed.
    switch mode {
    case .None:
        gl.Disable(gl.CULL_FACE)
    case .Front:
        gl.Enable(gl.CULL_FACE)
        gl.CullFace(gl.FRONT)
    case .Back:
        gl.Enable(gl.CULL_FACE)
        gl.CullFace(gl.BACK)
    case .Front_And_Back: // This is not a standard GL cull mode, usually means .BACK with correct winding.
        gl.Enable(gl.CULL_FACE)
        gl.CullFace(gl.FRONT_AND_BACK) // This is correct for GL
    }
    return common.Engine_Error.None
}

// --- Helper Functions ---
get_gl_blend_factor :: proc(factor: gfx_interface.Blend_Factor) -> u32 {
    switch factor {
    case .Zero:                 return gl.ZERO
    case .One:                  return gl.ONE
    case .Src_Color:            return gl.SRC_COLOR
    case .One_Minus_Src_Color:  return gl.ONE_MINUS_SRC_COLOR
    case .Dst_Color:            return gl.DST_COLOR
    case .One_Minus_Dst_Color:  return gl.ONE_MINUS_DST_COLOR
    case .Src_Alpha:            return gl.SRC_ALPHA
    case .One_Minus_Src_Alpha:  return gl.ONE_MINUS_SRC_ALPHA
    case .Dst_Alpha:            return gl.DST_ALPHA
    case .One_Minus_Dst_Alpha:  return gl.ONE_MINUS_DST_ALPHA
    case .Constant_Color:       return gl.CONSTANT_COLOR
    case .One_Minus_Constant_Color: return gl.ONE_MINUS_CONSTANT_COLOR
    case .Constant_Alpha:       return gl.CONSTANT_ALPHA
    case .One_Minus_Constant_Alpha: return gl.ONE_MINUS_CONSTANT_ALPHA
    case .Src_Alpha_Saturate:   return gl.SRC_ALPHA_SATURATE
    }
    return gl.ONE
}

get_gl_compare_func :: proc(op: gfx_interface.Compare_Op) -> u32 {
    switch op {
    case .Never:           return gl.NEVER
    case .Less:            return gl.LESS
    case .Equal:           return gl.EQUAL
    case .Less_Or_Equal:   return gl.LEQUAL
    case .Greater:         return gl.GREATER
    case .Not_Equal:       return gl.NOTEQUAL
    case .Greater_Or_Equal: return gl.GEQUAL
    case .Always:          return gl.ALWAYS
    }
    return gl.LEQUAL
}
