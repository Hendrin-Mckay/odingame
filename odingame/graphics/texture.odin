package graphics

import "../gfx_interface" // For Gfx_Texture and Texture_Format
import "../common"       // For Engine_Error
import "core:log"
import "core:mem"
// For graphics_device.odin's Surface_Format, if we decide to use it directly.
// For now, define a local one to avoid cycles if texture.odin is imported by graphics_device.odin
// import . "./graphics_device" // This would make graphics_device.Surface_Format available

// Local Surface_Format enum for Texture2D.
// This should be consolidated with graphics_device.Surface_Format eventually.
// XNA SurfaceFormat has more options.
Surface_Format_Texture :: enum {
    Color,            // Typically R8G8B8A8_UNORM or B8G8R8A8_UNORM
    Bgr565,
    Bgra5551,
    Bgra4444,
    Normalized_Byte2, // Placeholder
    Normalized_Byte4, // Placeholder
    Rgba1010102,      // Placeholder
    Rg32,             // Placeholder (2x float32)
    Rgba64,           // Placeholder (4x half float)
    Alpha8,
    Single,           // R32_FLOAT
    Half_Single,      // R16_FLOAT
    Half_Vector2,     // Placeholder
    Half_Vector4,     // Placeholder
    Hdr_Blendable,    // Placeholder (e.g. R16G16B16A16_FLOAT)
    // Depth Formats (usually not set directly on Texture2D this way in XNA, but for completeness)
    Dxt1, // BC1
    Dxt3, // BC2
    Dxt5, // BC3
    Depth24_Stencil8, // For consistency if a texture can be a depth target
}

// Texture is a base conceptual type for texture resources.
// In XNA, Texture is an abstract base class. Here, we embed its common fields.
Texture_Base :: struct {
    graphics_device: ^Graphics_Device, // Reference to the Graphics_Device that created this texture
    format:          Surface_Format_Texture, 
    level_count:     int,                 // Number of mipmap levels
    
    _gfx_texture:    gfx_interface.Gfx_Texture, // Low-level backend handle
    _is_disposed:    bool,
    allocator:       mem.Allocator, // Allocator used for this struct instance
}

// Texture2D represents a 2D texture resource, aligning with XNA's Texture2D.
Texture2D :: struct {
    using _base: Texture_Base, // Embed common Texture fields

    width:  int,
    height: int,
}

// --- Texture2D Procedures ---

// new_texture2D is an internal constructor used by Content_Manager or other loading functions.
// It wraps a low-level Gfx_Texture with higher-level information.
_new_texture2D_from_gfx_texture :: proc(
    gd: ^Graphics_Device, 
    gfx_tex: gfx_interface.Gfx_Texture, 
    w, h: int, 
    original_format: gfx_interface.Texture_Format, // The format used to create gfx_tex
    num_mip_levels: int,
    alloc: mem.Allocator,
) -> ^Texture2D {
    tex2d := new(Texture2D, alloc)
    tex2d.graphics_device = gd
    tex2d._gfx_texture = gfx_tex 
    tex2d.width = w
    tex2d.height = h
    
    // Map gfx_interface.Texture_Format to our local Surface_Format_Texture
    mapped_format, ok_map := to_surface_format_texture(original_format)
    if !ok_map {
        log.warnf("Texture2D: Could not map gfx_interface.Texture_Format %v to Surface_Format_Texture. Defaulting to Color.", original_format)
        tex2d.format = .Color
    } else {
        tex2d.format = mapped_format
    }
    
    tex2d.level_count = num_mip_levels
    if tex2d.level_count == 0 { tex2d.level_count = 1 } // MipLevels = 0 in D3D11_TEXTURE2D_DESC means full chain
    
    tex2d._is_disposed = false
    tex2d.allocator = alloc
    return tex2d
}

// texture2D_dispose marks the texture as disposed.
// The actual GPU resource (_gfx_texture) is released by Content_Manager (if loaded by it)
// or when the Graphics_Device is destroyed if this Texture2D was created manually outside CM.
texture2D_dispose :: proc(tex: ^Texture2D) {
    if tex == nil || tex._is_disposed {
        return
    }
    // If this Texture2D instance directly "owns" the _gfx_texture (e.g. created manually, not via ContentManager),
    // then it should be destroyed here. Otherwise, this is just a soft dispose.
    // For now, assume ContentManager handles actual GPU resource release for assets it loads.
    // If a texture is created manually by game code, it must be manually destroyed using gfx_api.destroy_texture.
    log.debugf("Texture2D marked as disposed (GPU resource path: %v): %dx%d", tex._gfx_texture.variant, tex.width, tex.height)
    tex._is_disposed = true
    
    // If this Texture2D was responsible for the _gfx_texture's lifetime (e.g. manual creation),
    // then: gfx_api.destroy_texture(tex._gfx_texture)
    // However, in the ContentManager model, CM owns it.
}

// --- Accessors ---
get_internal_gfx_texture :: proc(tex: ^Texture2D) -> gfx_interface.Gfx_Texture {
    if tex != nil && !tex._is_disposed { return tex._gfx_texture }
    return {} 
}
get_texture_width :: proc(tex: ^Texture2D) -> int {
    if tex != nil { return tex.width }
    return 0
}
get_texture_height :: proc(tex: ^Texture2D) -> int {
    if tex != nil { return tex.height }
    return 0
}
get_texture_format :: proc(tex: ^Texture2D) -> Surface_Format_Texture {
    if tex != nil { return tex.format }
    // Return a sensible default or indicate error
    return .Color // Or a specific "Undefined" if added to Surface_Format_Texture
}
is_texture_disposed :: proc(tex: ^Texture2D) -> bool {
    return tex == nil || tex._is_disposed
}


// --- Format Conversion Helper ---
// Maps gfx_interface.Texture_Format to the local Surface_Format_Texture
to_surface_format_texture :: proc(fmt: gfx_interface.Texture_Format) -> (sfmt: Surface_Format_Texture, ok: bool) {
    ok = true
    switch fmt {
    case .RGBA8_UNORM, .BGRA8_UNORM: // Assuming these are common "Color" formats
        sfmt = .Color
    case .R8_UNORM:
        sfmt = .Alpha8 // Or a new .R8_UNORM in Surface_Format_Texture
    case .R32_FLOAT:
        sfmt = .Single
    case .R16_FLOAT:
        sfmt = .Half_Single
    // Add more mappings as gfx_interface.Texture_Format expands and Surface_Format_Texture gets more detailed.
    // For DXT/BC formats:
    case .BC1_UNORM, .BC1_UNORM_SRGB: sfmt = .Dxt1
    case .BC2_UNORM, .BC2_UNORM_SRGB: sfmt = .Dxt3
    case .BC3_UNORM, .BC3_UNORM_SRGB: sfmt = .Dxt5
    // Depth formats
    case .DEPTH24_STENCIL8: sfmt = .Depth24_Stencil8

    // Fallback for unmapped formats
    case .Undefined: fallthrough
    default:
        // log.warnf("to_surface_format_texture: Unhandled gfx_interface.Texture_Format: %v", fmt)
        sfmt = .Color // Default or indicate unmapped
        ok = false 
    }
    return
}


// --- Existing Low-Level Texture Loading (using gfx_api) ---
// This function, `load_texture_from_file`, returns a raw Gfx_Texture.
// ContentManager will use this and wrap it into the Texture2D struct.
// This function was previously in this file and is kept for that purpose.
// It uses SDL_image for pixel loading and gfx_api.create_texture for GPU upload.

// load_texture_from_file loads a texture from a file and returns a reference-counted Gfx_Texture
// along with the gfx_interface.Texture_Format that was determined and used for creation.
// The caller is responsible for calling destroy_texture when done with the texture.
load_texture_from_file :: proc(device: gfx_interface.Gfx_Device, filepath_str: string, generate_mipmaps: bool = true) -> (texture: gfx_interface.Gfx_Texture, original_format: gfx_interface.Texture_Format, err: common.Engine_Error) {
    // Validate input parameters
    // is_valid(device) is not defined here, check variant directly
    if device.variant == nil {
        log.error("load_texture_from_file: Invalid Gfx_Device provided (nil variant).")
        return {}, .Undefined, .Invalid_Handle
    }

    if len(filepath_str) == 0 {
        log.error("load_texture_from_file: Empty file path provided.")
        return {}, .Undefined, .Invalid_Parameter
    }

    log.debugf("Loading texture from file (low-level): %s", filepath_str)

    // Load image data using stb_image (assuming stb_image is used by the engine now, or SDL_image)
    // This part needs to align with the actual image loading mechanism.
    // The previous version used SDL_image. Let's assume that for now.
    // This function should ideally just take pixel data, width, height, format.
    // For now, reproduce simplified SDL_image loading path.
    
    // This function is becoming problematic as it duplicates image loading logic
    // that should be centralized or passed in.
    // For ContentManager, it would be better if this just took raw pixel data.
    // However, to keep it self-contained for now and matching previous role:
    
    // This function should ideally be private to the graphics package or part of platform utilities.
    // For now, it's a helper for ContentManager's internal loader.

    // If using SDL_image (as per previous core.game setup):
    // import sdl_image "vendor:sdl2/image"
    // surface := sdl_image.Load(filepath_str)
    // if surface == nil {
    //     log.errorf("Failed to load image from file '%s' with SDL_image: %s", filepath_str, sdl_image.GetError())
    //     return {}, .File_Not_Found // Or .Texture_Creation_Failed
    // }
    // defer sdl_image.FreeSurface(surface)
    // width  := int(surface.w)
    // height := int(surface.h)
    // data   := surface.pixels
    // Determine format from surface.format.format (SDL_PixelFormatEnum) -> gfx_interface.Texture_Format
    // This is complex. A simpler path is if gfx_api.create_texture can take a filename directly
    // or if a helper exists to get (pixels, w, h, gfx_fmt) from a file.
    
    // For now, let's assume a placeholder for getting pixel data and info.
    // This part is highly dependent on how image loading is actually implemented.
    // The existing `gfx_api.load_texture_from_file` in the original `texture.odin` (before this refactor)
    // was a high-level loader. This needs to be clarified.
    // Let's assume this `load_texture_from_file` is the ONE that loads pixels and creates Gfx_Texture.
    // It was defined in the `graphics` package, so it can call `gfx_api.create_texture`.

    // The previous implementation of this function used stb_image. Let's stick to that for now.
    // import image "vendor:stb/image" // Ensure this import is at the top
    
    pixels, w, h, comp, load_err := image.load_from_file(filepath_str, 0)
    if load_err != nil || pixels == nil {
        log.errorf("Failed to load image from file '%s' with stb_image: %v", filepath_str, load_err)
        return {}, .Undefined, .File_Not_Found 
    }
    defer if pixels != nil { image.free(pixels) }

    determined_engine_format: gfx_interface.Texture_Format
    switch comp {
    case 1: determined_engine_format = .R8_UNORM 
    case 3: determined_engine_format = .RGB8_UNORM 
    case 4: determined_engine_format = .RGBA8_UNORM
    else:
        log.errorf("Unsupported number of components (%d) in image '%s'", comp, filepath_str)
        return {}, .Undefined, .Unsupported_Format
    }
    
    usage_flags: gfx_interface.Texture_Usage_Flags = {.ShaderResource}
    if generate_mipmaps { usage_flags += {.GenerateMips} }

    // Create the low-level Gfx_Texture
    gfx_texture, create_err := gfx_api.create_texture(device, w, h, determined_engine_format, usage_flags, pixels, filepath_str)
    if create_err != .None {
        log.errorf("Failed to create Gfx_Texture from image '%s': %v", filepath_str, create_err)
        return {}, .Undefined, create_err
    }
    
    log.debugf("Successfully created Gfx_Texture from file '%s' with format %v", filepath_str, determined_engine_format)
    return gfx_texture, determined_engine_format, .None
}

// This is a placeholder for the old function name if other parts of the code still use it.
// It should be removed or updated once all callers use the new ContentManager.
load_texture_from_file_gfx :: proc(device: gfx_interface.Gfx_Device, filepath_str: string, generate_mipmaps: bool = true) -> (gfx_interface.Gfx_Texture, common.Engine_Error) {
    log.warn("load_texture_from_file_gfx is deprecated, use ContentManager.load_texture2D or graphics.load_texture_from_file (which now returns original_format).")
    // This old signature cannot return the original_format, so it's problematic for new ContentManager.
    // For now, just call the new one and discard the format.
    tex, _, err := load_texture_from_file(device, filepath_str, generate_mipmaps)
    return tex, err
}
