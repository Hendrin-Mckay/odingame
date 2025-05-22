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

// --- Transform2D ---
Transform2D :: struct {
    position: Vector2f, // Uses linalg.Vector2f via alias
    rotation: f32,     // Radians
    scale:    Vector2f, // Uses linalg.Vector2f via alias
}

// transform2d_identity returns a Transform2D with no translation, rotation, or scaling.
transform2d_identity :: proc() -> Transform2D {
    return Transform2D {
        position = {0, 0},
        rotation = 0,
        scale    = {1, 1},
    }
}

// transform2d_to_matrix converts a Transform2D to a 4x4 transformation matrix (linalg.Matrix4f).
// Order: Scale, then Rotate, then Translate.
transform2d_to_matrix :: proc(t: Transform2D) -> Matrix4f {
    // Start with identity matrix
    mat := linalg.matrix4_identity()
    
    // 1. Translate
    mat = linalg.matrix4_translate(mat, {t.position.x, t.position.y, 0})
    
    // 2. Rotate around Z axis
    // Note: linalg.matrix4_rotate applies rotation around existing matrix.
    // If we want SRT order, we should build scale, then rotate, then translate matrix separately
    // or apply them in reverse order to an identity matrix.
    // Let's build SRT:
    // M = Translation * Rotation * Scale
    
    scale_mat    := linalg.matrix4_scale({t.scale.x, t.scale.y, 1})
    rotate_mat   := linalg.matrix4_rotate_z(linalg.matrix4_identity(), t.rotation) // Rotate identity around Z
    translate_mat:= linalg.matrix4_translate(linalg.matrix4_identity(), {t.position.x, t.position.y, 0})

    // Combine: T * R * S
    // Note: Odin's linalg.matrix_multiply is m1 * m2 (like standard math notation).
    // If m1 is on the left, it's applied "first" in terms of coordinate transformation.
    // So, world_coord = Projection * View * Model * local_coord.
    // Model matrix = Translation * Rotation * Scale.
    mat = linalg.matrix_multiply(translate_mat, linalg.matrix_multiply(rotate_mat, scale_mat))
    
    return mat
}

// transform_vector :: proc(m: Matrix4f, v: Vector2f) -> Vector2f {
//     // Transform a 2D vector by a 4x4 matrix (ignoring Z, assuming w=1 for position, w=0 for direction)
//     // This is a simplified version for transforming a position.
//     res_x := m.m00*v.x + m.m01*v.y + m.m03 // Assumes w=1
//     res_y := m.m10*v.x + m.m11*v.y + m.m13 // Assumes w=1
//     return {res_x, res_y}
// }


// transform2d_combine_matrix_based is a robust way to combine transforms using matrix math.
// ChildWorld = ParentWorld * LocalTransform
transform2d_combine :: proc(parent_world_t: Transform2D, local_t: Transform2D) -> Transform2D {
    parent_matrix := transform2d_to_matrix(parent_world_t)
    local_matrix  := transform2d_to_matrix(local_t)
    
    world_matrix := linalg.matrix_multiply(parent_matrix, local_matrix)
    
    // Decompose world_matrix back to Transform2D
    // This decomposition assumes the matrix is a 2D affine transformation (no shear applied through this process).
    world: Transform2D
    
    // Position
    world.position.x = world_matrix[0,3] // col 3, row 0
    world.position.y = world_matrix[1,3] // col 3, row 1
    
    // Scale
    // sx = length of first column vector (m00, m10)
    // sy = length of second column vector (m01, m11)
    world.scale.x = f32(math.sqrt(f64(world_matrix[0,0]*world_matrix[0,0] + world_matrix[1,0]*world_matrix[1,0])))
    world.scale.y = f32(math.sqrt(f64(world_matrix[0,1]*world_matrix[0,1] + world_matrix[1,1]*world_matrix[1,1])))

    // Rotation
    // Assuming positive scales. If scales can be negative, this becomes more complex as rotation can absorb the flip.
    // cos(theta) = m00 / scale.x
    // sin(theta) = m10 / scale.x
    // Using atan2 for robustness.
    // Note: linalg.Matrix4f is column-major: matrix[col, row]
    // m00 is world_matrix[0,0], m10 is world_matrix[0,1] in row-major terms, but world_matrix[0,0] and world_matrix[1,0] in col-major for first col.
    // So, using matrix[0,0] and matrix[1,0] (1st column) for X-axis rotation.
    world.rotation = f32(math.atan2(f64(world_matrix[1,0]), f64(world_matrix[0,0])))
    
    // A check for determinant sign could indicate flipped coordinate system if scales were negative,
    // but basic decomposition usually extracts positive scales.
    // More advanced decomposition might be needed for full generality (e.g. QR decomposition or SVD-like approaches).
    // For game transforms built from positive scales, position, rotation, this is usually sufficient.

    return world
}
