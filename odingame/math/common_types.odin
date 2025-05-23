package math

import "core:math/linalg"
import "../types"

// Common types are now imported from the types package
// This file provides compatibility for existing code

// Vector type aliases
Vector2 :: types.Vector2
Vector2f :: types.Vector2f
Vector2i :: types.Vector2i

// Rectangle type aliases
Rectangle :: types.Rectangle
Rectf :: types.Rectf
Recti :: types.Recti

// Color type and constants aliases
Color :: types.Color

// Pre-defined colors
WHITE :: types.WHITE
BLACK :: types.BLACK
RED :: types.RED
GREEN :: types.GREEN
BLUE :: types.BLUE
CORNFLOWER_BLUE :: types.CORNFLOWER_BLUE

// Conversion functions
to_vector2f :: proc(v: Vector2) -> linalg.Vector2f {
    return {v.x, v.y}
}

from_vector2f :: proc(v: linalg.Vector2f) -> Vector2 {
    return {v.x, v.y}
}
