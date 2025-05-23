package graphics

import gl "vendor:OpenGL/gl"
import "vendor:stb/image"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:strings"

// Gfx_Texture is the handle used by the game code to reference a texture.
// It automatically manages reference counting when copied or destroyed.
Gfx_Texture :: struct {
    variant: union {^Gl_Texture},
    
    // This struct has custom copy and destroy behavior
    _: struct {},
}

// --- Reference counting utilities ---

// make_texture creates a new Gfx_Texture with proper reference counting
make_texture :: proc(device: Gfx_Device, width, height: int, format: Texture_Format, usage: Texture_Usage, data: rawptr = nil) -> (Gfx_Texture, Gfx_Error) {
    return gfx_api.create_texture(device, width, height, format, usage, data)
}

// destroy_texture destroys a texture, releasing its resources when the reference count reaches zero
destroy_texture :: proc(tex: ^Gfx_Texture) {
    if tex == nil {
        return
    }
    gfx_api.destroy_texture(tex^)
}

// clone_texture creates a new reference to an existing texture
clone_texture :: proc(tex: Gfx_Texture) -> Gfx_Texture {
    if tex.variant == nil {
        return {}
    }
    
    if t, ok := tex.variant.(^Gl_Texture); ok {
        core.add_ref(t)
    }
    
    return tex
}

// get_ref_count gets the current reference count of a texture (for debugging)
get_texture_ref_count :: proc(tex: Gfx_Texture) -> int {
    if tex.variant == nil {
        return 0
    }
    
    if t, ok := tex.variant.(^Gl_Texture); ok {
        return core.get_ref_count(t)
    }
    
    return -1
}

// --- OpenGL Specific Struct ---

Gl_Texture :: struct {
    using base: core.RefCounted,
    
    // Texture data
    id:             u32,
    width:          int,
    height:         int,
    format:         Texture_Format, // Store the interface format for reference
    gl_internal_fmt: gl.GLenum,
    gl_fmt:         gl.GLenum,
    gl_type:        gl.GLenum,
    main_allocator: ^rawptr,
    
    // Optional debug name
    debug_name:     string,
}

// --- Helper to map interface format to GL formats/types ---

@(private="file")
get_gl_texture_formats :: proc(format: Texture_Format) -> (internal_format, gl_format, gl_type: gl.GLenum, err: Gfx_Error) {
	#partial switch format {
	case .R8:
		return gl.R8, gl.RED, gl.UNSIGNED_BYTE, .None
	case .RGB8:
		// Some drivers might have issues with gl.RGB8, gl.RGB, gl.UNSIGNED_BYTE for glTexImage2D source data if not aligned properly.
		// Using GL_RGB directly for data format is common.
		return gl.RGB8, gl.RGB, gl.UNSIGNED_BYTE, .None
	case .RGBA8:
		return gl.RGBA8, gl.RGBA, gl.UNSIGNED_BYTE, .None
	case .SRGBA8:
		return gl.SRGB8_ALPHA8, gl.RGBA, gl.UNSIGNED_BYTE, .None
	// case .Depth24_Stencil8: // TODO when framebuffers/render targets are added
	// 	return gl.DEPTH24_STENCIL8, gl.DEPTH_STENCIL, gl.UNSIGNED_INT_24_8, .None
	case:
		log.errorf("Unsupported texture format: %v", format)
		return 0, 0, 0, .Texture_Creation_Failed // Or a more specific error "Unsupported_Format"
	}
	return 0,0,0, .None // Should not be reached
}


// --- Implementation of Gfx_Device_Interface texture functions ---

// gl_create_texture_impl creates a new OpenGL texture with the specified parameters.
// The caller is responsible for destroying the texture when it's no longer needed.
gl_create_texture_impl :: proc(device: Gfx_Device, width, height: int, format: Texture_Format, usage: Texture_Usage, data: rawptr = nil) -> (texture: Gfx_Texture, err: Gfx_Error) {
	// Validate inputs
	if width <= 0 || height <= 0 {
		log.errorf("Invalid texture dimensions %dx%d", width, height)
		return {}, .Invalid_Argument
	}

	// Get OpenGL format enums
	internal_fmt, gl_fmt, gl_type, fmt_err := get_gl_texture_formats(format)
	if fmt_err != .None {
		log.errorf("Unsupported texture format: %v", format)
		return {}, fmt_err
	}

	// Create OpenGL texture
	tex_id: u32
	gl.GenTextures(1, &tex_id)
	if tex_id == 0 {
		log.error("Failed to generate OpenGL texture: glGenTextures failed")
		return {}, .Texture_Creation_Failed
	}

	// Set up error handling for texture operations
	gl_error := gl.GetError()
	if gl_error != gl.NO_ERROR {
		log.errorf("OpenGL error before texture creation: 0x%x", gl_error)
		gl.DeleteTextures(1, &tex_id)
		return {}, .OpenGL_Error
	}

	// Bind the texture for configuration
	gl.BindTexture(gl.TEXTURE_2D, tex_id)

	// Set texture parameters
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	
	// Set appropriate min/mag filters based on usage
	if .GenerateMipmaps in usage && data != nil {
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR)
	} else {
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	}
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	// Handle pixel unpack alignment for non-power-of-two textures
	if (gl_fmt == gl.RGB || gl_fmt == gl.RGBA) && (width % 4 != 0) {
		bytes_per_pixel: int = gl_fmt == gl.RGB ? 3 : 4
		if (width * bytes_per_pixel) % 4 != 0 {
			gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)
		}
	}

	// Allocate texture storage and upload data
	gl.TexImage2D(gl.TEXTURE_2D, 0, internal_fmt, i32(width), i32(height), 0, gl_fmt, gl_type, data)

	// Check for OpenGL errors after texture creation
	gl_error = gl.GetError()
	if gl_error != gl.NO_ERROR {
		log.errorf("Failed to create texture (glTexImage2D): 0x%x", gl_error)
		gl.DeleteTextures(1, &tex_id)
		return {}, .OpenGL_Error
	}

	// Generate mipmaps if requested and data was provided
	if .GenerateMipmaps in usage && data != nil {
		gl.GenerateMipmap(gl.TEXTURE_2D)
		gl_error = gl.GetError()
		if gl_error != gl.NO_ERROR {
			log.errorf("Failed to generate mipmaps: 0x%x", gl_error)
			gl.DeleteTextures(1, &tex_id)
			return {}, .OpenGL_Error
		}
	}

	// Restore default unpack alignment if it was changed
	gl.PixelStorei(gl.UNPACK_ALIGNMENT, 4)

	// Create the texture wrapper
	device_ptr, ok_device := device.variant.(^Gl_Device)
	if !ok_device {
		log.error("Invalid Gfx_Device type for texture creation")
		gl.DeleteTextures(1, &tex_id)
		return {}, .Invalid_Handle
	}

	gl_texture := new(Gl_Texture, device_ptr.main_allocator^)
	
	// Initialize reference counting
	core.init_refcount(gl_texture, destroy_gl_texture)
	
	// Set up texture data
	gl_texture.id = tex_id
	gl_texture.width = width
	gl_texture.height = height
	gl_texture.format = format
	gl_texture.gl_internal_fmt = internal_fmt
	gl_texture.gl_fmt = gl_fmt
	gl_texture.gl_type = gl_type
	gl_texture.main_allocator = device_ptr.main_allocator
	
	// Set debug name if available
	when ODIN_DEBUG {
		gl_texture.debug_name = fmt.tprintf("Texture_%dx%d_%v", width, height, tex_id)
	}

	log.debugf("Created OpenGL texture %dx%d (ID: %v, format: %v)", width, height, tex_id, format)
	return Gfx_Texture{gl_texture}, .None

	gl.BindTexture(gl.TEXTURE_2D, 0) // Unbind

	// Restore default unpack alignment if changed
	if gl_fmt == gl.RGB && (width % 4 != 0) {
		if (width * 3) % 4 != 0 {
			gl.PixelStorei(gl.UNPACK_ALIGNMENT, 4) // Default is 4
		}
	}


	gl_texture_ptr := new(Gl_Texture, device_ptr.main_allocator^)
	gl_texture_ptr.id = tex_id
	gl_texture_ptr.width = width
	gl_texture_ptr.height = height
	gl_texture_ptr.format = format
	gl_texture_ptr.gl_internal_fmt = internal_fmt
	gl_texture_ptr.gl_fmt = gl_fmt
	gl_texture_ptr.gl_type = gl_type
	gl_texture_ptr.main_allocator = device_ptr.main_allocator

	log.infof("OpenGL Texture ID %v (%dx%d, format %v) created.", tex_id, width, height, format)
	return Gfx_Texture{gl_texture_ptr}, .None
}

gl_update_texture_impl :: proc(texture: Gfx_Texture, x, y, width, height int, data: rawptr) -> Gfx_Error {
	tex_ptr, ok := texture.variant.(^Gl_Texture)
	if !ok || tex_ptr.id == 0 {
		log.error("gl_update_texture: Invalid or uninitialized Gfx_Texture.")
		return .Invalid_Handle
	}

	if data == nil {
		log.error("gl_update_texture: Data pointer is nil.")
		return .Texture_Creation_Failed // Or a more specific error like Invalid_Argument
	}

	if x < 0 || y < 0 || width <= 0 || height <= 0 || (x + width) > tex_ptr.width || (y + height) > tex_ptr.height {
		log.errorf("gl_update_texture: Invalid update region (x:%d,y:%d, w:%d,h:%d) for texture size %dx%d.",
			x, y, width, height, tex_ptr.width, tex_ptr.height)
		return .Texture_Creation_Failed // Or out_of_bounds error
	}

	gl.BindTexture(gl.TEXTURE_2D, tex_ptr.id)

	// Handle pixel unpack alignment for sub-image updates too
	if tex_ptr.gl_fmt == gl.RGB && (width % 4 != 0) {
		if (width * 3) % 4 != 0 {
			gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)
		}
	}

	gl.TexSubImage2D(gl.TEXTURE_2D, 0, i32(x), i32(y), i32(width), i32(height), tex_ptr.gl_fmt, tex_ptr.gl_type, data)

	// Consider if mipmaps need to be regenerated after partial update.
	// Generally, yes, if mipmapping is used.
	// Check if min_filter is a mipmap filter
	min_filter_param : i32
	gl.GetTexParameteriv(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, &min_filter_param)
	if min_filter_param == gl.LINEAR_MIPMAP_LINEAR || min_filter_param == gl.LINEAR_MIPMAP_NEAREST ||
	   min_filter_param == gl.NEAREST_MIPMAP_LINEAR || min_filter_param == gl.NEAREST_MIPMAP_NEAREST {
		gl.GenerateMipmap(gl.TEXTURE_2D)
	}

	gl.BindTexture(gl.TEXTURE_2D, 0) // Unbind

	// Restore default unpack alignment if changed
	if tex_ptr.gl_fmt == gl.RGB && (width % 4 != 0) {
		if (width * 3) % 4 != 0 {
			gl.PixelStorei(gl.UNPACK_ALIGNMENT, 4) // Default is 4
		}
	}

	log.infof("OpenGL Texture ID %v updated region (x:%d,y:%d, w:%d,h:%d).", tex_ptr.id, x, y, width, height)
	return .None
}

// Internal cleanup function called when reference count reaches zero
destroy_gl_texture :: proc(tex: ^Gl_Texture) {
    if tex == nil {
        return
    }
    
    if tex.id != 0 {
        gl.DeleteTextures(1, &tex.id)
        log.debugf("Destroyed OpenGL texture ID %v (%s)", tex.id, tex.debug_name)
    }
    
    // Free the texture memory
    if tex.main_allocator != nil {
        free(tex, tex.main_allocator^)
    }
}

gl_destroy_texture_impl :: proc(texture: Gfx_Texture) {
    if tex_ptr, ok := texture.variant.(^Gl_Texture); ok {
        // Just release the reference - actual cleanup happens in destroy_gl_texture
        // when the reference count reaches zero
        core.release(tex_ptr)
    } else {
        log.errorf("gl_destroy_texture: Invalid texture type %v", texture.variant)
    }
}


// --- Utility function to load texture from file using the new interface ---
// This would typically reside in a higher-level utility package or the application code,
// not directly in the backend implementation.
// For now, placing it here to show how it would use the interface.

// load_texture_from_file_gfx loads a texture from a file and returns a Gfx_Texture handle.
// The caller is responsible for destroying the returned texture when it's no longer needed.
// load_texture_from_file loads a texture from a file and returns a reference-counted Gfx_Texture.
// The caller is responsible for calling destroy_texture when done with the texture.
load_texture_from_file :: proc(device: Gfx_Device, filepath: string, generate_mipmaps: bool = true) -> (texture: Gfx_Texture, err: Gfx_Error) {
    // Validate input parameters
    if !is_valid(device) {
        log.error("load_texture_from_file: Invalid Gfx_Device provided")
        return {}, .Invalid_Handle
    }

    if len(filepath) == 0 {
        log.error("load_texture_from_file: Empty file path provided")
        return {}, .Invalid_Argument
    }

    log.debugf("Loading texture from file: %s", filepath)

    // Load image data using stb_image
    data, width, height, comp, err_load := image.load_from_file(filepath, 0)
    if err_load != nil || data == nil {
        log.errorf("Failed to load image from file '%s': %v", filepath, err_load)
        return {}, .Texture_Creation_Failed
    }
    
    // Ensure image data is always freed, even on early returns
    defer {
        if data != nil {
            image.free(data)
        }
    }

    log.infof("Loaded image '%s': %dx%d, components: %d", filepath, width, height, comp)

    // Determine texture format based on number of components
    format: Texture_Format
    switch comp {
    case 1: format = .R8
    case 3: format = .RGB8
    case 4: format = .RGBA8
    case:
        log.errorf("Unsupported number of components (%d) in image '%s'", comp, filepath)
        return {}, .Unsupported_Format
    }

    // Prepare texture usage flags
    usage := Texture_Usage{.Sampled}
    if generate_mipmaps {
        usage += {.GenerateMipmaps}
    }

    // Create the texture using our reference-counted API
    texture, create_err := make_texture(device, width, height, format, usage, data)
    if create_err != .None {
        log.errorf("Failed to create Gfx_Texture from image '%s': %s", 
                  filepath, gfx_api.get_error_string(create_err))
        return {}, create_err
    }

    // Set debug name for the texture
    when ODIN_DEBUG {
        if t, ok := texture.variant.(^Gl_Texture); ok {
            t.debug_name = fmt.tprintf("Texture_%s", filepath)
        }
    }

    log.debugf("Successfully created texture from file '%s' (refcount: %d)", 
              filepath, get_texture_ref_count(texture))
    return texture, .None
}

// Keep the old function name for backward compatibility
load_texture_from_file_gfx :: proc(device: Gfx_Device, filepath: string, generate_mipmaps: bool = true) -> (Gfx_Texture, Gfx_Error) {
    log.warn("load_texture_from_file_gfx is deprecated, use load_texture_from_file instead")
    return load_texture_from_file(device, filepath, generate_mipmaps)
}
}


// The old Texture struct and load_texture_from_file, create_texture_from_image, destroy_texture
// are now replaced by Gfx_Texture and the interface functions.
// The `load_texture_from_file_gfx` is an example of how to use the new API.
// Binding textures for drawing will be handled by different functions in the interface,
// likely `set_texture_binding` or similar, which would be called by SpriteBatch or other renderers.
// This will be part of Gfx_Device_Interface and implemented later.
// For now, this file focuses on texture creation, update, and destruction.
// The functions like `gl_create_texture_impl` need to be assigned
// to the `gfx_api` in `device.odin`.
// I will do that in the next step.

// --- Texture Binding Implementation ---

gl_bind_texture_to_unit_impl :: proc(device: Gfx_Device, texture: Gfx_Texture, unit: u32) -> Gfx_Error {
	// device_ptr, ok_device := device.variant.(^Gl_Device)
	// if !ok_device {
	// 	log.error("gl_bind_texture_to_unit: Invalid Gfx_Device type.")
	// 	return .Invalid_Handle
	// }
	// No device specific state needed for bind_texture, relies on current GL context.

	tex_ptr, ok_tex := texture.variant.(^Gl_Texture)
	if !ok_tex {
		// Allow binding a nil/invalid texture to a unit, which effectively unbinds.
		gl.ActiveTexture(gl.TEXTURE0 + gl.GLenum(unit))
		gl.BindTexture(gl.TEXTURE_2D, 0)
		// log.warnf("gl_bind_texture_to_unit: Invalid Gfx_Texture provided. Unbinding texture unit %d.", unit)
		return .None // Or .Invalid_Handle if strictly requiring valid texture
	}

	if tex_ptr.id == 0 {
		// This is a valid Gl_Texture struct but with no GL resource.
		gl.ActiveTexture(gl.TEXTURE0 + gl.GLenum(unit))
		gl.BindTexture(gl.TEXTURE_2D, 0)
		// log.warnf("gl_bind_texture_to_unit: Gfx_Texture ID is 0. Unbinding texture unit %d.", unit)
		return .None
	}
	
	max_units : i32
	gl.GetIntegerv(gl.MAX_COMBINED_TEXTURE_IMAGE_UNITS, &max_units)
	if unit >= u32(max_units) {
		log.errorf("gl_bind_texture_to_unit: Texture unit %d exceeds maximum available units (%d).", unit, max_units)
		return .Invalid_Handle // Or some "Invalid_Unit" error
	}

	gl.ActiveTexture(gl.TEXTURE0 + gl.GLenum(unit))
	gl.BindTexture(gl.TEXTURE_2D, tex_ptr.id)
	// log.debugf("Bound texture ID %v to unit %v", tex_ptr.id, unit) // Can be spammy
	return .None
}

// --- Texture Utility Implementations ---

gl_get_texture_width_impl :: proc(texture: Gfx_Texture) -> int {
	if tex_ptr, ok := texture.variant.(^Gl_Texture); ok && tex_ptr != nil {
		return tex_ptr.width
	}
	log.warnf("gl_get_texture_width: Invalid or non-Gl_Texture Gfx_Texture type: %v", texture.variant)
	return 0
}

gl_get_texture_height_impl :: proc(texture: Gfx_Texture) -> int {
	if tex_ptr, ok := texture.variant.(^Gl_Texture); ok && tex_ptr != nil {
		return tex_ptr.height
	}
	log.warnf("gl_get_texture_height: Invalid or non-Gl_Texture Gfx_Texture type: %v", texture.variant)
	return 0
}
