package opengl

import "../gfx_interface"
import "../../common" // For common.Engine_Error
import "core:log"
import "core:mem"
import "core:os"
import "core:image/png"
import "core:image"
import gl "vendor:OpenGL/gl"

// --- Texture Types ---

Texture_Format :: enum u32 {
    R8 = gl.R8,
    RGB8 = gl.RGB8,
    RGBA8 = gl.RGBA8,
    SRGBA8 = gl.SRGB8_ALPHA8,
    Depth24_Stencil8 = gl.DEPTH24_STENCIL8,
}

Texture_Wrap :: enum u32 {
    Repeat = gl.REPEAT,
    Mirrored_Repeat = gl.MIRRORED_REPEAT,
    Clamp_To_Edge = gl.CLAMP_TO_EDGE,
    Clamp_To_Border = gl.CLAMP_TO_BORDER,
}

Texture_Filter :: enum u32 {
    Nearest = gl.NEAREST,
    Linear = gl.LINEAR,
    Nearest_Mipmap_Nearest = gl.NEAREST_MIPMAP_NEAREST,
    Linear_Mipmap_Nearest = gl.LINEAR_MIPMAP_NEAREST,
    Nearest_Mipmap_Linear = gl.NEAREST_MIPMAP_LINEAR,
    Linear_Mipmap_Linear = gl.LINEAR_MIPMAP_LINEAR,
}

Texture :: struct {
    id: u32,
    width, height: int,
    format: Texture_Format,
    wrap_s, wrap_t: Texture_Wrap,
    min_filter, mag_filter: Texture_Filter,
    has_mipmaps: bool,
    is_render_target: bool,
}

// --- Texture Creation ---

create_texture_impl :: proc(
    device: gfx_interface.Gfx_Device,
    width, height: int,
    format: gfx_interface.Texture_Format,
    usage: gfx_interface.Texture_Usage,
    data: rawptr = nil,
) -> (gfx_interface.Gfx_Texture, common.Engine_Error) {
    // Convert format
    texture_format: Texture_Format
    switch format {
    case .R8:   texture_format = .R8
    case .RGB8: texture_format = .RGB8
    case .RGBA8, .SRGBA8: texture_format = .RGBA8
    case .Depth24_Stencil8: texture_format = .Depth24_Stencil8
    case:       return gfx_interface.Gfx_Texture{}, common.Engine_Error.Texture_Creation_Failed
    }
    
    // Create texture
    var texture_id: u32
    gl.GenTextures(1, &texture_id)
    if texture_id == 0 {
        return gfx_interface.Gfx_Texture{}, common.Engine_Error.Texture_Creation_Failed
    }
    
    // Bind and configure texture
    gl.BindTexture(gl.TEXTURE_2D, texture_id)
    
    // Set default texture parameters
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, i32(gl.CLAMP_TO_EDGE))
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, i32(gl.CLAMP_TO_EDGE))
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, i32(gl.LINEAR))
    gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, i32(gl.LINEAR))
    
    // Determine internal format and format
    internal_format: i32
    pixel_format: u32
    pixel_type: u32 = gl.UNSIGNED_BYTE
    
    switch texture_format {
    case .R8:
        internal_format = gl.R8
        pixel_format = gl.RED
    case .RGB8:
        internal_format = gl.RGB8
        pixel_format = gl.RGB
    case .RGBA8:
        internal_format = gl.RGBA8
        pixel_format = gl.RGBA
    case .SRGBA8:
        internal_format = gl.SRGB8_ALPHA8
        pixel_format = gl.RGBA
    case .Depth24_Stencil8:
        internal_format = gl.DEPTH24_STENCIL8
        pixel_format = gl.DEPTH_STENCIL
        pixel_type = gl.UNSIGNED_INT_24_8
    }
    
    // Allocate texture storage
    gl.TexImage2D(
        gl.TEXTURE_2D, 0, internal_format,
        i32(width), i32(height), 0,
        pixel_format, pixel_type, data
    )
    
    // Generate mipmaps if requested and we have data
    if .Generate_Mipmaps in usage && data != nil {
        gl.GenerateMipmap(gl.TEXTURE_2D)
    }
    
    // Create texture wrapper
    texture := new(Texture)
    texture.id = texture_id
    texture.width = width
    texture.height = height
    texture.format = texture_format
    texture.wrap_s = .Clamp_To_Edge
    texture.wrap_t = .Clamp_To_Edge
    texture.min_filter = .Linear
    texture.mag_filter = .Linear
    texture.has_mipmaps = .Generate_Mipmaps in usage
    texture.is_render_target = .Render_Target in usage
    
    log.debugf("Created texture (ID: %d, %dx%d, Format: %v)", 
        texture_id, width, height, texture_format)
    
    return gfx_interface.Gfx_Texture{texture}, .None
}

update_texture_impl :: proc(
    texture: gfx_interface.Gfx_Texture,
    x, y, width, height: int,
    format: gfx_interface.Texture_Format,
    data: rawptr,
) -> common.Engine_Error {
    if tex, ok := texture.variant.(^Texture); ok {
        gl.BindTexture(gl.TEXTURE_2D, tex.id)
        
        // Determine format
        pixel_format: u32
        pixel_type: u32 = gl.UNSIGNED_BYTE
        
        switch format {
        case .R8:   pixel_format = gl.RED
        case .RGB8: pixel_format = gl.RGB
        case .RGBA8, .SRGBA8: pixel_format = gl.RGBA
        case: return common.Engine_Error.Texture_Creation_Failed
        }
        
        gl.TexSubImage2D(
            gl.TEXTURE_2D, 0,
            i32(x), i32(y), i32(width), i32(height),
            pixel_format, pixel_type, data
        )
        
        // Regenerate mipmaps if needed
        if tex.has_mipmaps {
            gl.GenerateMipmap(gl.TEXTURE_2D)
        }
        
        return .None
    }
    return common.Engine_Error.Invalid_Handle
}

destroy_texture_impl :: proc(texture: gfx_interface.Gfx_Texture) {
    if tex, ok := texture.variant.(^Texture); ok {
        gl.DeleteTextures(1, &tex.id)
        free(tex)
    }
}

// --- Texture Binding ---

bind_texture_to_unit_impl :: proc(
    device: gfx_interface.Gfx_Device,
    texture: gfx_interface.Gfx_Texture,
    unit: u32,
) -> common.Engine_Error {
    if tex, ok := texture.variant.(^Texture); ok {
        gl.ActiveTexture(gl.TEXTURE0 + unit)
        gl.BindTexture(gl.TEXTURE_2D, tex.id)
        return .None
    }
    return common.Engine_Error.Invalid_Handle
}

// --- Texture Properties ---

get_texture_width_impl :: proc(texture: gfx_interface.Gfx_Texture) -> int {
    if tex, ok := texture.variant.(^Texture); ok {
        return tex.width
    }
    return 0
}

get_texture_height_impl :: proc(texture: gfx_interface.Gfx_Texture) -> int {
    if tex, ok := texture.variant.(^Texture); ok {
        return tex.height
    }
    return 0
}

// --- Texture Loading ---

load_texture_from_file :: proc(
    device: gfx_interface.Gfx_Device,
    filepath: string,
    generate_mipmaps: bool = true,
) -> (gfx_interface.Gfx_Texture, common.Engine_Error) {
    // Load image file
    img, err := image.load(filepath)
    if err != .None {
        log.errorf("Failed to load image: %s", filepath)
        return gfx_interface.Gfx_Texture{}, common.Engine_Error.Texture_Creation_Failed
    }
    defer image.destroy(img)
    
    // Convert to RGBA if needed
    rgba_img, ok := image.to_rgba(img)
    if !ok {
        log.errorf("Failed to convert image to RGBA: %s", filepath)
        return gfx_interface.Gfx_Texture{}, common.Engine_Error.Texture_Creation_Failed
    }
    defer image.destroy(rgba_img)
    
    // Create texture
    usage: gfx_interface.Texture_Usage
    if generate_mipmaps {
        usage = {.Sampled, .Generate_Mipmaps}
    } else {
        usage = {.Sampled}
    }
    
    return create_texture_impl(
        device,
        rgba_img.width, rgba_img.height,
        .RGBA8,
        usage,
        raw_data(rgba_img.pixels.buf[:]),
    )
}
