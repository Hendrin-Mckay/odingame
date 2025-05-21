package math

import linalg "core:math/linalg"
import "core:math" // For math.cos, math.sin

Vector2f :: linalg.Vector2f
Vector2i :: linalg.Vector2i
Rectf :: struct { x, y, w, h: f32 }
Recti :: struct { x, y, w, h: i32 }
Matrix4f :: linalg.Matrix4f

// Creates an orthographic projection matrix
// Assumes linalg.matrix4_orthographic(left, right, bottom, top, near, far, homogeneous_depth: bool)
// where homogeneous_depth = false for OpenGL style (depth -1 to 1)
// and homogeneous_depth = true for DirectX style (depth 0 to 1)
orthographic_projection :: proc(left, right, bottom, top, near, far: f32) -> Matrix4f {
    // The `false` here means we want OpenGL's -1 to 1 depth range, not DirectX's 0 to 1.
    return linalg.matrix4_orthographic(left, right, bottom, top, near, far, false) 
}

// Identity matrix
matrix4_identity :: proc() -> Matrix4f {
	return linalg.matrix4_identity()
}

// Translation
matrix4_translate :: proc(m: Matrix4f, v: Vector2f) -> Matrix4f {
	// linalg.matrix4_translate typically takes a Vector3f.
	// We are in 2D, so z-component of translation is 0.
	return linalg.matrix4_translate(m, {v.x, v.y, 0})
}

// Rotation around Z-axis (for 2D rotation)
matrix4_rotate_z :: proc(m: Matrix4f, angle_radians: f32) -> Matrix4f {
	// linalg.matrix4_rotate typically takes an axis (Vector3f) and an angle.
	// For 2D rotation, the axis is (0, 0, 1).
	return linalg.matrix4_rotate(m, {0, 0, 1}, angle_radians)
}

// Scaling
matrix4_scale :: proc(m: Matrix4f, v: Vector2f) -> Matrix4f {
	// linalg.matrix4_scale typically takes a Vector3f.
	// For 2D, z-component of scale is 1 (no change in depth).
	return linalg.matrix4_scale(m, {v.x, v.y, 1})
}

// Expose core math functions for convenience if needed elsewhere,
// though direct use of "core:math" is also fine.
cos :: math.cos
sin :: math.sin
