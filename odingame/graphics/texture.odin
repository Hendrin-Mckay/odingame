package graphics

import "core:fmt"
import "vendor:sdl2/image"
import gl "vendor:OpenGL/gl"

Texture2D :: struct {
	gl_id:  gl.GLuint,
	width:  i32,
	height: i32,
}

texture_from_file :: proc(filepath: string) -> (^Texture2D, error) {
	surface := sdl2.image.Load(filepath)
	if surface == nil {
		err_str := sdl2.image.GetError() // Capture error before another SDL call
		return nil, err_str
	}
	defer sdl2.FreeSurface(surface)

	tex := new(Texture2D)
	tex.width = surface.w
	tex.height = surface.h

	gl.GenTextures(1, &tex.gl_id)
	gl.BindTexture(gl.TEXTURE_2D, tex.gl_id)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)

	gl_format: u32 
	gl_internal_format: i32 

	switch surface.format.BytesPerPixel {
	case 4:
		// Assuming RGBA for 4 BytesPerPixel. A more robust solution would inspect Rmask, Gmask etc.
		// For example, to distinguish between RGBA and ARGB or BGRA.
		// SDL_PIXELFORMAT_RGBA32 is common for this.
		gl_format = gl.RGBA
		gl_internal_format = gl.RGBA8 // Use sized internal format
	case 3:
		// Assuming RGB for 3 BytesPerPixel. SDL_PIXELFORMAT_RGB24 is common.
		gl_format = gl.RGB
		gl_internal_format = gl.RGB8  // Use sized internal format
	case _:
		gl.DeleteTextures(1, &tex.gl_id) // Clean up texture ID
		free(tex)                         // Free the struct
		err_msg := fmt.tprintf("Unsupported pixel format for texture '%s'. BytesPerPixel: %d, SDL Format ID: %v", 
			filepath, surface.format.BytesPerPixel, surface.format.format)
		return nil, err_msg
	}
	
	// Set pixel unpack alignment. Important for textures with widths not a multiple of 4.
	// Default GL alignment is 4. If rows are tightly packed (pitch == width * BPP), 1 is safe.
	expected_pitch := surface.w * surface.format.BytesPerPixel
	if surface.pitch == expected_pitch {
		gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1) // Tightly packed rows
	} else {
		// If pitch is not width*BPP, it implies padding.
		// Common alignments are 2, 4, 8. Defaulting to 4 is often safe.
		// For a truly robust solution, one might need to copy row by row if pitch is unusual,
		// or use SDL_ConvertSurfaceFormat to get a surface with a known, packed pixel layout.
		gl.PixelStorei(gl.UNPACK_ALIGNMENT, 4)
	}

	gl.TexImage2D(gl.TEXTURE_2D, 0, gl_internal_format, tex.width, tex.height, 0, gl_format, gl.UNSIGNED_BYTE, surface.pixels)
	
	// Mipmaps are useful for quality scaling but require specific minification filters.
	// For basic 2D, gl.LINEAR is often sufficient. If gl.GenerateMipmap is used,
	// gl.TEXTURE_MIN_FILTER should be set to something like gl.LINEAR_MIPMAP_LINEAR.
	// gl.GenerateMipmap(gl.TEXTURE_2D) 

	gl.BindTexture(gl.TEXTURE_2D, 0) // Unbind

	return tex, nil
}

destroy_texture :: proc(tex: ^Texture2D) {
	if tex == nil || tex.gl_id == 0 {
		return
	}
	gl.DeleteTextures(1, &tex.gl_id)
	tex.gl_id = 0 // Mark as deleted
	free(tex)
}
