package graphics

import "core:fmt"
import "core:strings"
import "core:log"
import "vendor:sdl2/ttf"

// TTF_Font wraps an SDL_ttf font
TTF_Font :: struct {
    sdl_font: ^ttf.Font,
    size:     i32,
    line_skip: i32,
}

// Loads a TTF font from file with the specified point size
load_ttf_font :: proc(filename: string, point_size: i32) -> (font: TTF_Font, ok: bool) {
    font.size = point_size
    
    // Initialize SDL_ttf if not already done
    if ttf.WasInit() == 0 {
        if ttf.Init() == -1 {
            log.errorf("Failed to initialize SDL_ttf: %s", ttf.GetError())
            return font, false
        }
    }
    
    // Load the font
    font.sdl_font = ttf.OpenFont(filename, point_size)
    if font.sdl_font == nil {
        log.errorf("Failed to load font '%s': %s", filename, ttf.GetError())
        return font, false
    }
    
    font.line_skip = ttf.FontLineSkip(font.sdl_font)
    return font, true
}

// Frees the TTF font
free_ttf_font :: proc(font: ^TTF_Font) {
    if font != nil && font.sdl_font != nil {
        ttf.CloseFont(font.sdl_font)
        font.sdl_font = nil
    }
}

// Renders UTF-8 text to a texture using the given font and color
render_text_ttf :: proc(
    device: ^Gfx_Device,
    font: ^TTF_Font,
    text: string,
    color: Color,
) -> (texture: Gfx_Texture, width, height: i32, ok: bool) {
    if font == nil || font.sdl_font == nil || len(text) == 0 {
        return {}, 0, 0, false
    }
    
    // Render text to a surface
    surface := ttf.RenderUTF8_Blended(font.sdl_font, text, sdl2.Color{color.r, color.g, color.b, color.a})
    if surface == nil {
        log.errorf("Failed to render text: %s", ttf.GetError())
        return {}, 0, 0, false
    }
    defer sdl2.FreeSurface(surface)
    
    // Create texture from surface
    tex, err := device.create_texture_from_surface(surface)
    if err != .None {
        log.errorf("Failed to create texture from surface: %v", err)
        return {}, 0, 0, false
    }
    
    return tex, i32(surface.w), i32(surface.h), true
}

// Helper to render text with a solid background (for better console readability)
render_text_ttf_solid_bg :: proc(
    device: ^Gfx_Device,
    font: ^TTF_Font,
    text: string,
    fg_color: Color,
    bg_color: Color,
) -> (texture: Gfx_Texture, width, height: i32, ok: bool) {
    if font == nil || font.sdl_font == nil || len(text) == 0 {
        return {}, 0, 0, false
    }
    
    // First render foreground text
    fg_surface := ttf.RenderUTF8_Blended(
        font.sdl_font, 
        text, 
        sdl2.Color{fg_color.r, fg_color.g, fg_color.b, fg_color.a}
    )
    if fg_surface == nil {
        log.errorf("Failed to render text: %s", ttf.GetError())
        return {}, 0, 0, false
    }
    defer sdl2.FreeSurface(fg_surface)
    
    // Create a surface with the same dimensions but with a background color
    bg_surface := sdl2.CreateRGBSurfaceWithFormat(
        0, 
        fg_surface.w + 4,  // Add some padding
        fg_surface.h + 4,  // Add some padding
        32,                // 32 bits per pixel
        u32(sdl2.PIXELFORMAT_RGBA8888)
    )
    if bg_surface == nil {
        log.errorf("Failed to create background surface: %s", sdl2.GetError())
        return {}, 0, 0, false
    }
    defer sdl2.FreeSurface(bg_surface)
    
    // Fill the background
    sdl2.FillRect(bg_surface, nil, 
        u32(bg_color.r) << 24 | 
        u32(bg_color.g) << 16 | 
        u32(bg_color.b) << 8  | 
        u32(bg_color.a))
    
    // Blit the text surface onto the background
    dst_rect := sdl2.Rect{2, 2, fg_surface.w, fg_surface.h}  // Center the text with padding
    sdl2.UpperBlit(fg_surface, nil, bg_surface, &dst_rect)
    
    // Create texture from the final surface
    tex, err := device.create_texture_from_surface(bg_surface)
    if err != .None {
        log.errorf("Failed to create texture from surface: %v", err)
        return {}, 0, 0, false
    }
    
    return tex, i32(bg_surface.w), i32(bg_surface.h), true
}
