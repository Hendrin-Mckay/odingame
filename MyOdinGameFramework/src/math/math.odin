package math

// Vec2 represents a 2D vector.
Vec2 :: struct {
	x, y: f32,
}

// Add returns the sum of two Vec2 vectors.
add_vec2 :: proc(a, b: Vec2) -> Vec2 {
	return {a.x + b.x, a.y + b.y}
}

// Vec3 represents a 3D vector.
Vec3 :: struct {
	x, y, z: f32,
}

// Add returns the sum of two Vec3 vectors.
add_vec3 :: proc(a, b: Vec3) -> Vec3 {
	return {a.x + b.x, a.y + b.y, a.z + b.z}
}

// Placeholder for Vec4
Vec4 :: struct {
    x, y, z, w: f32,
}

// Placeholder for Mat3
Mat3 :: struct {
    // Define 3x3 matrix elements
    // e.g., m: [3][3]f32 or m00, m01, m02, m10, ...
}

// Placeholder for Mat4
Mat4 :: struct {
    // Define 4x4 matrix elements
    // e.g., m: [4][4]f32 or m00, m01, m02, m03, ...
}

// TODO: Implement other math operations as per Phase 0:
// - Subtraction, multiplication (vector-scalar, vector-vector, matrix-vector, matrix-matrix)
// - Dot product, cross product, normalization, magnitude
// - Functions for common transformations: orthographic, perspective, translate, rotate, scale
