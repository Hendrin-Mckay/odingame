package graphics

import "../common" // For common.Engine_Error
import "core:log"
import "core:strings"
import "core:math"
// Import ../math if needed for common types

// CharacterInfo holds the position and size of a character in the font texture
CharacterInfo :: struct {
    x, y:           f32,  // Position in the texture (in texels)
    width, height:  f32,  // Size of the character (in texels)
    xoffset:        f32,  // X offset from cursor position to render
    yoffset:        f32,  // Y offset from cursor position to render
    xadvance:       f32,  // How far to move the cursor after rendering this character
}

// Font represents a bitmap font with character information
Font :: struct {
    texture:        Gfx_Texture,  // The texture containing the font characters
    char_width:     int,          // Width of each character in the texture
    char_height:    int,          // Height of each character in the texture
    chars_per_row:  int,          // Number of characters per row in the texture
    line_spacing:   f32,          // Space between lines (in pixels)
    char_spacing:  f32,           // Space between characters (in pixels)
    default_char:   rune,         // Default character to use for missing characters
    char_info:      [256]CharacterInfo,  // ASCII character info
}

// load_default_font creates a simple bitmap font using the default white texture
// For a real game, you would load a proper font texture and metrics
load_default_font :: proc(device: Gfx_Device, char_width, char_height: int) -> (^Font, common.Engine_Error) {
    font := new(Font)
    
    // Use the default white texture as a fallback
    // In a real implementation, you would load a proper font texture here
    font.texture = {}
    font.char_width = char_width
    font.char_height = char_height
    font.chars_per_row = 16  // 16 characters per row in the texture
    font.line_spacing = 2.0
    font.char_spacing = 1.0
    font.default_char = '?'
    
    // Initialize character info for ASCII 32-126 (printable characters)
    for c in 0..<256 {
        if c >= 32 && c <= 126 {
            // Simple grid-based character layout
            row := (c - 32) / font.chars_per_row
            col := (c - 32) % font.chars_per_row
            
            font.char_info[c] = CharacterInfo{
                x = f32(col * font.char_width),
                y = f32(row * font.char_height),
                width = f32(font.char_width),
                height = f32(font.char_height),
                xoffset = 0,
                yoffset = 0,
                xadvance = f32(font.char_width) + font.char_spacing,
            }
        } else {
            // For non-printable characters, use the default character's info
            font.char_info[c] = font.char_info[int(font.default_char)]
        }
    }
    
    return font, common.Engine_Error.None
}

// destroy_font cleans up font resources
// Note: The texture is reference-counted, so it will be destroyed when no longer used
destroy_font :: proc(font: ^Font) {
    if font == nil {
        return
    }
    
    // The texture is reference-counted, so we don't need to explicitly destroy it here
    free(font)
}

// get_char_info returns the character info for the given rune
// If the character is not in the font, returns the default character's info
get_char_info :: proc(font: ^Font, char: rune) -> ^CharacterInfo {
    if font == nil {
        return nil
    }
    
    // Simple ASCII support - for full Unicode, you'd need a more sophisticated approach
    c := int(char)
    if c < 0 || c >= 256 {
        c = int(font.default_char)
    }
    
    return &font.char_info[c]
}
