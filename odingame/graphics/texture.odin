package graphics

import gl "vendor:OpenGL/gl"
import "vendor:stb/image"
import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:strings"

// --- OpenGL Specific Struct ---

Gl_Texture :: struct {
	id:             u32,
	width:          int,
	height:         int,
	format:         Texture_Format, // Store the interface format for reference
	gl_internal_fmt: gl.GLenum,
	gl_fmt:         gl.GLenum,
	gl_type:        gl.GLenum,
	main_allocator: ^rawptr,
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

gl_create_texture_impl :: proc(device: Gfx_Device, width, height: int, format: Texture_Format, usage: Texture_Usage, data: rawptr = nil) -> (Gfx_Texture, Gfx_Error) {
	device_ptr, ok_device := device.variant.(^Gl_Device)
	if !ok_device {
		log.error("gl_create_texture: Invalid Gfx_Device type.")
		return Gfx_Texture{}, .Invalid_Handle
	}

	if width <= 0 || height <= 0 {
		log.errorf("gl_create_texture: Invalid texture dimensions %dx%d.", width, height)
		return Gfx_Texture{}, .Texture_Creation_Failed
	}

	internal_fmt, gl_fmt, gl_type, fmt_err := get_gl_texture_formats(format)
	if fmt_err != .None {
		return Gfx_Texture{}, fmt_err
	}

	tex_id: u32
	gl.GenTextures(1, &tex_id)
	if tex_id == 0 {
		log.error("glGenTextures failed.")
		return Gfx_Texture{}, .Texture_Creation_Failed
	}

	gl.BindTexture(gl.TEXTURE_2D, tex_id)

	// Set texture parameters - these could be part of Texture_Descriptor or set globally
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR) // Assuming mipmaps
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	// TODO: Handle pixel unpack alignment, especially for RGB/R8 etc.
	// gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1) // For tightly packed data if source is not 4-byte aligned
	// For RGB8, if data rows are not multiple of 4 bytes, this is important.
	// For RGBA8, usually not an issue.
	// For now, assume data is correctly aligned or format (like RGBA8) doesn't require special alignment.
	
	// Check if data is RGB and width is not a multiple of 4 pixels (which would make row not multiple of 4 bytes)
	if gl_fmt == gl.RGB && (width % 4 != 0) {
		// If width * 3 (bytes per row for RGB) is not a multiple of 4, set alignment to 1
		if (width * 3) % 4 != 0 {
			gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)
		}
	}


	gl.TexImage2D(gl.TEXTURE_2D, 0, internal_fmt, i32(width), i32(height), 0, gl_fmt, gl_type, data)

	// Generate mipmaps if data is provided. For dynamic textures, mipmaps might be generated after update.
	// Mipmapping requires min_filter to be one of the mipmap options.
	if data != nil {
		gl.GenerateMipmap(gl.TEXTURE_2D)
	}

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

gl_destroy_texture_impl :: proc(texture: Gfx_Texture) {
	if tex_ptr, ok := texture.variant.(^Gl_Texture); ok {
		if tex_ptr.id != 0 {
			gl.DeleteTextures(1, &tex_ptr.id)
			log.infof("OpenGL Texture ID %v destroyed.", tex_ptr.id)
		}
		free(tex_ptr, tex_ptr.main_allocator^)
	} else {
		log.errorf("gl_destroy_texture: Invalid texture type %v", texture.variant)
	}
}


// --- Utility function to load texture from file using the new interface ---
// This would typically reside in a higher-level utility package or the application code,
// not directly in the backend implementation.
// For now, placing it here to show how it would use the interface.

load_texture_from_file_gfx :: proc(device: Gfx_Device, filepath: string, generate_mipmaps: bool = true) -> (Gfx_Texture, Gfx_Error) {
	// Use the gfx_api, not device directly, as this is a utility.
	// Or pass gfx_api as a parameter if this utility is outside graphics package.
	// For now, assume gfx_api is accessible.

	data, width, height, comp, err_load := image.load_from_file(filepath, 0)
	if err_load != nil || data == nil {
		log.errorf("Failed to load image from file '%s': %v", filepath, err_load)
		return Gfx_Texture{}, .Texture_Creation_Failed
	}
	defer image.free(data) // Free stb_image data after texture creation

	log.infof("Loaded image '%s': %dx%d, components: %d", filepath, width, height, comp)

	format: Texture_Format
	#partial switch comp {
	case 1: // Grayscale
		format = .R8 // Treat grayscale as Red channel
	case 3: // RGB
		format = .RGB8
	case 4: // RGBA
		format = .RGBA8
	case:
		log.errorf("Unsupported number of components (%d) in image '%s'", comp, filepath)
		return Gfx_Texture{}, .Texture_Creation_Failed // Or Unsupported_Format
	}
	
	// TODO: The `usage` parameter for create_texture. For a loaded texture, it's typically Sampled.
	// Mipmap generation is handled by create_texture if data is provided.
	// The `generate_mipmaps` parameter here is illustrative.

	texture_handle, create_err := gfx_api.create_texture(device, width, height, format, {.Sampled}, data)
	if create_err != .None {
		log.errorf("Failed to create Gfx_Texture from image '%s': %s", filepath, gfx_api.get_error_string(create_err))
		return Gfx_Texture{}, create_err
	}

	return texture_handle, .None
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
