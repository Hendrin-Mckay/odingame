package graphics

import gfx_interface "./gfx_interface" // Gfx_Texture, Gfx_Device are here
import graphics_types "./types"      // For Texture_Format, Texture_Usage_Flags etc.
import "../common"                   // For Engine_Error
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
    original_format: graphics_types.Texture_Format, // Use qualified type
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
// Maps graphics_types.Texture_Format to the local Surface_Format_Texture
to_surface_format_texture :: proc(fmt: graphics_types.Texture_Format) -> (sfmt: Surface_Format_Texture, ok: bool) { // Use qualified type
    ok = true
    switch fmt {
    case .RGBA8, .RGB8: // Assuming these are common "Color" formats from graphics_types.Texture_Format
        // .RGBA8_UNORM, .BGRA8_UNORM were D3D11/Metal specific names.
        // The common_types.Texture_Format has .RGBA8, .RGB8 etc.
        sfmt = .Color
    case .R8:
        sfmt = .Alpha8 
    case .R32F:
        sfmt = .Single
    case .R16: // Assuming R16 is like Half_Single, or R16F if available
        sfmt = .Half_Single
    // graphics_types.Texture_Format does not have BCn or DXT formats directly listed in common_types.odin
    // It has Depth, Depth_Stencil.
    // This mapping might need adjustment based on the full list of graphics_types.Texture_Format.
    // For now, keeping DXT/Depth consistent if they were in the old enum.
    // case .BC1_UNORM, .BC1_UNORM_SRGB: sfmt = .Dxt1 // These are not in common_types.Texture_Format
    // case .BC2_UNORM, .BC2_UNORM_SRGB: sfmt = .Dxt3
    // case .BC3_UNORM, .BC3_UNORM_SRGB: sfmt = .Dxt5
    case .Depth_Stencil: sfmt = .Depth24_Stencil8 // Map from new enum
    case .Depth: sfmt = .Depth24_Stencil8 // Or a new .DepthOnly in Surface_Format_Texture

    // Fallback for unmapped formats
    // case .Undefined: fallthrough // .Undefined is not in graphics_types.Texture_Format
    default:
        // log.warnf("to_surface_format_texture: Unhandled graphics_types.Texture_Format: %v", fmt)
        sfmt = .Color 
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
// along with the graphics_types.Texture_Format that was determined and used for creation.
// The caller is responsible for calling destroy_texture when done with the texture.
load_texture_from_file :: proc(device: gfx_interface.Gfx_Device, filepath_str: string, generate_mipmaps: bool = true) -> (texture: gfx_interface.Gfx_Texture, original_format: graphics_types.Texture_Format, err: common.Engine_Error) { // Use qualified type
    // Validate input parameters
    if device.variant == nil {
        log.error("load_texture_from_file: Invalid Gfx_Device provided (nil variant).")
        return {}, .R8, .Invalid_Handle // .R8 is a valid graphics_types.Texture_Format default
    }

    if len(filepath_str) == 0 {
        log.error("load_texture_from_file: Empty file path provided.")
        return {}, .R8, .Invalid_Parameter
    }

    log.debugf("Loading texture from file (low-level): %s", filepath_str)
    
    // Image loading logic (stb_image or other) would go here.
    // This part is complex and depends on an image loading library.
    // For this refactoring, we assume `image.load_from_file` exists and works.
    // Ensure `image` import is present (e.g. import image "vendor:stb/image")
    // This import is missing from the provided snippet, assuming it's added at file top.
    // If `image` is not available, this function cannot be fully corrected here.
    // For now, proceeding as if `image` package is correctly imported.
    
    // Placeholder for image loading - this needs a proper image loading library
    pixels: rawptr = nil; w, h, comp: int; load_err: Error = nil 
    // Simulate loading failure if image lib not truly wired up:
    // load_err = errors.New("image loading not implemented in this refactor step")
    // For now, assume it might succeed and try to map comp
    // pixels, w, h, comp, load_err = image.load_from_file(filepath_str, 0) // Example call

    if load_err != nil || pixels == nil {
        // log.errorf("Failed to load image from file '%s': %v", filepath_str, load_err) // Keep if image lib is used
        log.errorf("Image loading stub: Failed to load image from file '%s'", filepath_str) // Placeholder message
        return {}, .R8, .File_Not_Found 
    }
    // defer if pixels != nil { image.free(pixels) } // Keep if image lib is used

    determined_engine_format: graphics_types.Texture_Format
    switch comp {
    case 1: determined_engine_format = .R8 
    case 3: determined_engine_format = .RGB8 // Assuming RGB8 if no alpha
    case 4: determined_engine_format = .RGBA8
    else:
        log.errorf("Unsupported number of components (%d) in image '%s'", comp, filepath_str)
        return {}, .R8, .Unsupported_Format
    }
    
    usage_flags: graphics_types.Texture_Usage_Flags = {.Sample} // .ShaderResource equivalent
    // if generate_mipmaps { usage_flags += {.GenerateMips} } // GenerateMips not in common_types.Texture_Usage

    // Create the low-level Gfx_Texture
    // The create_texture signature is:
    // device, width, height, depth, format, type, usage, mip_levels, array_length, data, data_pitch, data_slice_pitch, label
    // The old call was: device, w, h, determined_engine_format, usage_flags, pixels, filepath_str
    // This needs careful mapping.
    
    gfx_texture, create_err := gfx_interface.gfx_api.resource_creation.create_texture(
        device, 
        w, h, 1, // Assuming depth 1 for 2D texture
        determined_engine_format, 
        graphics_types.Texture_Type.Tex_2D,
        usage_flags,
        1, // mip_levels (1 for no mips, or calculate if generate_mipmaps is true)
        1, // array_length (1 for single texture)
        pixels,
        0, // data_pitch (0 for default)
        0, // data_slice_pitch (0 for default)
        filepath_str,
    )
    if create_err != .None {
        log.errorf("Failed to create Gfx_Texture from image '%s': %v", filepath_str, create_err)
        return {}, .R8, create_err
    }
    
    log.debugf("Successfully created Gfx_Texture from file '%s' with format %v", filepath_str, determined_engine_format)
    return gfx_texture, determined_engine_format, .None
}

// This is a placeholder for the old function name if other parts of the code still use it.
// It should be removed or updated once all callers use the new ContentManager.
load_texture_from_file_gfx :: proc(device: gfx_interface.Gfx_Device, filepath_str: string, generate_mipmaps: bool = true) -> (gfx_interface.Gfx_Texture, common.Engine_Error) {
    log.warn("load_texture_from_file_gfx is deprecated, use ContentManager.load_texture2D or graphics.load_texture_from_file (which now returns original_format).")
    tex, _, err := load_texture_from_file(device, filepath_str, generate_mipmaps)
    return tex, err
}
