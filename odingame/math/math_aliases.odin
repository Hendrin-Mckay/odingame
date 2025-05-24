package math

// This file defines common math type aliases to align with XNA-like naming conventions,
// using the `core:math/linalg` package as the underlying implementation.

import linalg "core:math/linalg"

// Vector2 represents a 2D vector with f32 components.
// Assuming linalg.Vec2f is the f32 version. If linalg uses Vector2f32, adjust accordingly.
Vector2 :: linalg.Vec2f 
// If Vector2f32 exists: Vector2 :: linalg.Vector2f32

// Vector3 represents a 3D vector with f32 components.
Vector3 :: linalg.Vec3f 
// If Vector3f32 exists: Vector3 :: linalg.Vector3f32

// Vector4 represents a 4D vector with f32 components.
Vector4 :: linalg.Vec4f 
// If Vector4f32 exists: Vector4 :: linalg.Vector4f32

// Matrix represents a 4x4 matrix with f32 components.
// Assuming linalg.Mat4f is the f32 version.
Matrix :: linalg.Mat4f 
// If Matrix4f32 exists: Matrix :: linalg.Matrix4f32

// Quaternion represents a quaternion with f32 components.
// Assuming linalg.Quatf is the f32 version.
Quaternion :: linalg.Quatf 
// If Quaternionf32 exists: Quaternion :: linalg.Quaternionf32


// --- Common Static Properties/Constructors (mimicking XNA style) ---
// These can be added as needed. Examples:

// Vector2_Zero returns a Vector2 with all components set to zero.
vector2_zero :: proc() -> Vector2 { return Vector2{0, 0} }
// Vector2_One returns a Vector2 with all components set to one.
vector2_one :: proc() -> Vector2 { return Vector2{1, 1} }
// Vector2_Unit_X returns a Vector2 representing the unit X direction.
vector2_unit_x :: proc() -> Vector2 { return Vector2{1, 0} }
// Vector2_Unit_Y returns a Vector2 representing the unit Y direction.
vector2_unit_y :: proc() -> Vector2 { return Vector2{0, 1} }

// Vector3_Zero returns a Vector3 with all components set to zero.
vector3_zero :: proc() -> Vector3 { return Vector3{0, 0, 0} }
// Vector3_One returns a Vector3 with all components set to one.
vector3_one :: proc() -> Vector3 { return Vector3{1, 1, 1} }
// ... and so on for UnitX, Up, Forward, etc.

// Matrix_Identity returns an identity Matrix.
matrix_identity :: proc() -> Matrix { return linalg.matrix4f32_identity() } // Assuming linalg provides this

// Quaternion_Identity returns an identity Quaternion.
quaternion_identity :: proc() -> Quaternion { return linalg.quaternionf32_identity() } // Assuming linalg provides this


// Note: The actual underlying types (e.g. linalg.Vec2f vs linalg.Vector2f32)
// depend on the specific version and naming convention of the `core:math/linalg` package being used.
// Adjust the aliases if `linalg` uses different names for its f32 types.
// For example, if `linalg` uses `Vector2`, `Matrix4`, etc. for its generic types,
// and specific versions like `Vector2f`, `Matrix4f`, this file correctly aliases them.
// If `linalg` itself provides `Vector2f32`, then that would be preferred.
// The `f32` suffix in the proposal (Vector2f32) implies a desire for explicit float32 types.
// `linalg.Vec2f`, `linalg.Mat4f` are common conventions for float32 specific types in Odin libraries.
