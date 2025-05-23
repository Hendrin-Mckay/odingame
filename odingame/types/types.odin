package types

import "core:math/linalg"

// Vector types
Vector2 :: linalg.Vector2f
Vector2f :: linalg.Vector2f
Vector2i :: linalg.Vector2i
Vector3 :: linalg.Vector3f
Vector3f :: linalg.Vector3f
Vector4 :: linalg.Vector4f

// Matrix types
Matrix4 :: linalg.Matrix4f
Matrix4f :: linalg.Matrix4f

// Rectangle with integer coordinates
Recti :: struct {
    x, y: i32,
    w, h: i32,
}
Rectf :: struct { x, y, w, h: f32 }

// Color type and constants
Color :: struct { r, g, b, a: u8 }

// Common color constants
WHITE :: Color{255, 255, 255, 255}
BLACK :: Color{0, 0, 0, 255}
RED :: Color{255, 0, 0, 255}
GREEN :: Color{0, 255, 0, 255}
BLUE :: Color{0, 0, 255, 255}
CORNFLOWER_BLUE :: Color{100, 149, 237, 255}
TRANSPARENT :: Color{0, 0, 0, 0}
