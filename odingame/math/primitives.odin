package math

// Using package math for these primitives as they are math-related geometry types.
// Could also be `package types` or `package primitives` depending on desired organization.

import "core:math" // For min, max

// Point defines a 2D point with integer coordinates.
Point :: struct {
    x, y: int,
}

// Rectangle defines a 2D rectangle with integer coordinates and dimensions.
Rectangle :: struct {
    x, y, width, height: int,
}

// --- Rectangle Helper Procedures ---

// rectangle_empty returns an empty rectangle (all fields zero).
rectangle_empty :: proc() -> Rectangle {
    return Rectangle{0, 0, 0, 0}
}

// rectangle_is_empty checks if a rectangle has zero width or height.
rectangle_is_empty :: proc(rect: Rectangle) -> bool {
    return rect.width == 0 || rect.height == 0
}

// rectangle_left returns the x-coordinate of the left edge.
rectangle_left :: proc(rect: Rectangle) -> int {
    return rect.x
}

// rectangle_right returns the x-coordinate of the right edge.
rectangle_right :: proc(rect: Rectangle) -> int {
    return rect.x + rect.width
}

// rectangle_top returns the y-coordinate of the top edge.
rectangle_top :: proc(rect: Rectangle) -> int {
    return rect.y
}

// rectangle_bottom returns the y-coordinate of the bottom edge.
rectangle_bottom :: proc(rect: Rectangle) -> int {
    return rect.y + rect.height
}

// rectangle_center returns the center point of the rectangle.
rectangle_center :: proc(rect: Rectangle) -> Point {
    return Point{rect.x + rect.width / 2, rect.y + rect.height / 2}
}

// rectangle_contains_point checks if a point is within the rectangle.
// Edges are inclusive.
rectangle_contains_point :: proc(rect: Rectangle, p: Point) -> bool {
    return p.x >= rect.x && p.x < (rect.x + rect.width) &&
           p.y >= rect.y && p.y < (rect.y + rect.height)
}

// rectangle_contains_rectangle checks if another rectangle is entirely contained within this one.
rectangle_contains_rectangle :: proc(rect_a, rect_b: Rectangle) -> bool {
    return rect_a.x <= rect_b.x &&
           (rect_b.x + rect_b.width) <= (rect_a.x + rect_a.width) &&
           rect_a.y <= rect_b.y &&
           (rect_b.y + rect_b.height) <= (rect_a.y + rect_a.height)
}


// rectangle_intersects checks if two rectangles overlap.
rectangle_intersects :: proc(rect_a, rect_b: Rectangle) -> bool {
    return rect_a.x < rect_b.x + rect_b.width &&
           rect_a.x + rect_a.width > rect_b.x &&
           rect_a.y < rect_b.y + rect_b.height &&
           rect_a.y + rect_a.height > rect_b.y
}

// rectangle_intersection returns the overlapping portion of two rectangles.
// If they don't intersect, an empty rectangle is returned.
rectangle_intersection :: proc(rect_a, rect_b: Rectangle) -> Rectangle {
    if !rectangle_intersects(rect_a, rect_b) {
        return rectangle_empty()
    }

    x := math.max(rect_a.x, rect_b.x)
    y := math.max(rect_a.y, rect_b.y)
    w := math.min(rect_a.x + rect_a.width, rect_b.x + rect_b.width) - x
    h := math.min(rect_a.y + rect_a.height, rect_b.y + rect_b.height) - y
    
    return Rectangle{x, y, w, h}
}

// rectangle_union returns the smallest rectangle that contains both input rectangles.
rectangle_union :: proc(rect_a, rect_b: Rectangle) -> Rectangle {
    x := math.min(rect_a.x, rect_b.x)
    y := math.min(rect_a.y, rect_b.y)
    
    width := math.max(rect_a.x + rect_a.width, rect_b.x + rect_b.width) - x
    height := math.max(rect_a.y + rect_a.height, rect_b.y + rect_b.height) - y
    
    return Rectangle{x, y, width, height}
}

// rectangle_offset changes the location of the rectangle.
rectangle_offset :: proc(rect: Rectangle, dx, dy: int) -> Rectangle {
    return Rectangle{rect.x + dx, rect.y + dy, rect.width, rect.height}
}

// rectangle_inflate changes the size of the rectangle, growing or shrinking from the center.
rectangle_inflate :: proc(rect: Rectangle, horizontal_amount, vertical_amount: int) -> Rectangle {
    return Rectangle{
        x = rect.x - horizontal_amount,
        y = rect.y - vertical_amount,
        width = rect.width + (horizontal_amount * 2),
        height = rect.height + (vertical_amount * 2),
    }
}

// --- Color Definition ---

// Color represents a 4-component color (Red, Green, Blue, Alpha) using u8 per component.
Color :: struct {
    r, g, b, a: u8,
}

// Predefined colors
Color_Transparent :: Color{0, 0, 0, 0}
Color_Alice_Blue :: Color{240, 248, 255, 255}
Color_Antique_White :: Color{250, 235, 215, 255}
Color_Aqua :: Color{0, 255, 255, 255}
Color_Aquamarine :: Color{127, 255, 212, 255}
Color_Azure :: Color{240, 255, 255, 255}
Color_Beige :: Color{245, 245, 220, 255}
Color_Bisque :: Color{255, 228, 196, 255}
Color_Black :: Color{0, 0, 0, 255}
Color_Blanched_Almond :: Color{255, 235, 205, 255}
Color_Blue :: Color{0, 0, 255, 255}
Color_Blue_Violet :: Color{138, 43, 226, 255}
Color_Brown :: Color{165, 42, 42, 255}
Color_Burly_Wood :: Color{222, 184, 135, 255}
Color_Cadet_Blue :: Color{95, 158, 160, 255}
Color_Chartreuse :: Color{127, 255, 0, 255}
Color_Chocolate :: Color{210, 105, 30, 255}
Color_Coral :: Color{255, 127, 80, 255}
Color_Cornflower_Blue :: Color{100, 149, 237, 255} // XNA classic!
Color_Cornsilk :: Color{255, 248, 220, 255}
Color_Crimson :: Color{220, 20, 60, 255}
Color_Cyan :: Color{0, 255, 255, 255}
Color_Dark_Blue :: Color{0, 0, 139, 255}
Color_Dark_Cyan :: Color{0, 139, 139, 255}
Color_Dark_Goldenrod :: Color{184, 134, 11, 255}
Color_Dark_Gray :: Color{169, 169, 169, 255}
Color_Dark_Green :: Color{0, 100, 0, 255}
Color_Dark_Khaki :: Color{189, 183, 107, 255}
Color_Dark_Magenta :: Color{139, 0, 139, 255}
Color_Dark_Olive_Green :: Color{85, 107, 47, 255}
Color_Dark_Orange :: Color{255, 140, 0, 255}
Color_Dark_Orchid :: Color{153, 50, 204, 255}
Color_Dark_Red :: Color{139, 0, 0, 255}
Color_Dark_Salmon :: Color{233, 150, 122, 255}
Color_Dark_Sea_Green :: Color{143, 188, 139, 255}
Color_Dark_Slate_Blue :: Color{72, 61, 139, 255}
Color_Dark_Slate_Gray :: Color{47, 79, 79, 255}
Color_Dark_Turquoise :: Color{0, 206, 209, 255}
Color_Dark_Violet :: Color{148, 0, 211, 255}
Color_Deep_Pink :: Color{255, 20, 147, 255}
Color_Deep_Sky_Blue :: Color{0, 191, 255, 255}
Color_Dim_Gray :: Color{105, 105, 105, 255}
Color_Dodger_Blue :: Color{30, 144, 255, 255}
Color_Firebrick :: Color{178, 34, 34, 255}
Color_Floral_White :: Color{255, 250, 240, 255}
Color_Forest_Green :: Color{34, 139, 34, 255}
Color_Fuchsia :: Color{255, 0, 255, 255}
Color_Gainsboro :: Color{220, 220, 220, 255}
Color_Ghost_White :: Color{248, 248, 255, 255}
Color_Gold :: Color{255, 215, 0, 255}
Color_Goldenrod :: Color{218, 165, 32, 255}
Color_Gray :: Color{128, 128, 128, 255}
Color_Green :: Color{0, 128, 0, 255}
Color_Green_Yellow :: Color{173, 255, 47, 255}
Color_Honeydew :: Color{240, 255, 240, 255}
Color_Hot_Pink :: Color{255, 105, 180, 255}
Color_Indian_Red :: Color{205, 92, 92, 255}
Color_Indigo :: Color{75, 0, 130, 255}
Color_Ivory :: Color{255, 255, 240, 255}
Color_Khaki :: Color{240, 230, 140, 255}
Color_Lavender :: Color{230, 230, 250, 255}
Color_Lavender_Blush :: Color{255, 240, 245, 255}
Color_Lawn_Green :: Color{124, 252, 0, 255}
Color_Lemon_Chiffon :: Color{255, 250, 205, 255}
Color_Light_Blue :: Color{173, 216, 230, 255}
Color_Light_Coral :: Color{240, 128, 128, 255}
Color_Light_Cyan :: Color{224, 255, 255, 255}
Color_Light_Goldenrod_Yellow :: Color{250, 250, 210, 255}
Color_Light_Gray :: Color{211, 211, 211, 255}
Color_Light_Green :: Color{144, 238, 144, 255}
Color_Light_Pink :: Color{255, 182, 193, 255}
Color_Light_Salmon :: Color{255, 160, 122, 255}
Color_Light_Sea_Green :: Color{32, 178, 170, 255}
Color_Light_Sky_Blue :: Color{135, 206, 250, 255}
Color_Light_Slate_Gray :: Color{119, 136, 153, 255}
Color_Light_Steel_Blue :: Color{176, 196, 222, 255}
Color_Light_Yellow :: Color{255, 255, 224, 255}
Color_Lime :: Color{0, 255, 0, 255}
Color_Lime_Green :: Color{50, 205, 50, 255}
Color_Linen :: Color{250, 240, 230, 255}
Color_Magenta :: Color{255, 0, 255, 255}
Color_Maroon :: Color{128, 0, 0, 255}
Color_Medium_Aquamarine :: Color{102, 205, 170, 255}
Color_Medium_Blue :: Color{0, 0, 205, 255}
Color_Medium_Orchid :: Color{186, 85, 211, 255}
Color_Medium_Purple :: Color{147, 112, 219, 255}
Color_Medium_Sea_Green :: Color{60, 179, 113, 255}
Color_Medium_Slate_Blue :: Color{123, 104, 238, 255}
Color_Medium_Spring_Green :: Color{0, 250, 154, 255}
Color_Medium_Turquoise :: Color{72, 209, 204, 255}
Color_Medium_Violet_Red :: Color{199, 21, 133, 255}
Color_Midnight_Blue :: Color{25, 25, 112, 255}
Color_Mint_Cream :: Color{245, 255, 250, 255}
Color_Misty_Rose :: Color{255, 228, 225, 255}
Color_Moccasin :: Color{255, 228, 181, 255}
Color_Navajo_White :: Color{255, 222, 173, 255}
Color_Navy :: Color{0, 0, 128, 255}
Color_Old_Lace :: Color{253, 245, 230, 255}
Color_Olive :: Color{128, 128, 0, 255}
Color_Olive_Drab :: Color{107, 142, 35, 255}
Color_Orange :: Color{255, 165, 0, 255}
Color_Orange_Red :: Color{255, 69, 0, 255}
Color_Orchid :: Color{218, 112, 214, 255}
Color_Pale_Goldenrod :: Color{238, 232, 170, 255}
Color_Pale_Green :: Color{152, 251, 152, 255}
Color_Pale_Turquoise :: Color{175, 238, 238, 255}
Color_Pale_Violet_Red :: Color{219, 112, 147, 255}
Color_Papaya_Whip :: Color{255, 239, 213, 255}
Color_Peach_Puff :: Color{255, 218, 185, 255}
Color_Peru :: Color{205, 133, 63, 255}
Color_Pink :: Color{255, 192, 203, 255}
Color_Plum :: Color{221, 160, 221, 255}
Color_Powder_Blue :: Color{176, 224, 230, 255}
Color_Purple :: Color{128, 0, 128, 255}
Color_Red :: Color{255, 0, 0, 255}
Color_Rosy_Brown :: Color{188, 143, 143, 255}
Color_Royal_Blue :: Color{65, 105, 225, 255}
Color_Saddle_Brown :: Color{139, 69, 19, 255}
Color_Salmon :: Color{250, 128, 114, 255}
Color_Sandy_Brown :: Color{244, 164, 96, 255}
Color_Sea_Green :: Color{46, 139, 87, 255}
Color_Sea_Shell :: Color{255, 245, 238, 255}
Color_Sienna :: Color{160, 82, 45, 255}
Color_Silver :: Color{192, 192, 192, 255}
Color_Sky_Blue :: Color{135, 206, 235, 255}
Color_Slate_Blue :: Color{106, 90, 205, 255}
Color_Slate_Gray :: Color{112, 128, 144, 255}
Color_Snow :: Color{255, 250, 250, 255}
Color_Spring_Green :: Color{0, 255, 127, 255}
Color_Steel_Blue :: Color{70, 130, 180, 255}
Color_Tan :: Color{210, 180, 140, 255}
Color_Teal :: Color{0, 128, 128, 255}
Color_Thistle :: Color{216, 191, 216, 255}
Color_Tomato :: Color{255, 99, 71, 255}
Color_Turquoise :: Color{64, 224, 208, 255}
Color_Violet :: Color{238, 130, 238, 255}
Color_Wheat :: Color{245, 222, 179, 255}
Color_White :: Color{255, 255, 255, 255}
Color_White_Smoke :: Color{245, 245, 245, 255}
Color_Yellow :: Color{255, 255, 0, 255}
Color_Yellow_Green :: Color{154, 205, 50, 255}

// color_premultiply_alpha multiplies the R, G, B components by the alpha component.
color_premultiply_alpha :: proc(color: Color) -> Color {
    // Convert to float for multiplication, then back to u8.
    // This avoids u8 overflow and maintains some precision.
    a_norm := f32(color.a) / 255.0
    return Color{
        r = u8(f32(color.r) * a_norm + 0.5), // Add 0.5 for rounding before cast
        g = u8(f32(color.g) * a_norm + 0.5),
        b = u8(f32(color.b) * a_norm + 0.5),
        a = color.a,
    }
}
