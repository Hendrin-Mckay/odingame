package types

// This file is intended to be a central place for common, simple data structures
// used throughout the OdinGame engine, or for re-exporting types from other
// core packages for easier access.

// After refactoring math and primitive types to odingame/math:
// - Vector types (Vector2, Vector3, Vector4) are now in odingame.math (aliases to linalg)
// - Matrix types (Matrix4) are now in odingame.math (alias to linalg)
// - Rectangle (formerly Recti) is now odingame.math.Rectangle
// - Color struct and constants are now in odingame.math.Color and odingame.math.Color_XYZ

// This file can be used to:
// 1. Define very generic engine-wide types not specific to math or another subsystem.
// 2. Re-export types from other odingame packages for convenience, e.g.:
//    import "../math"
//    Vector2 :: math.Vector2 // Re-export
//    Color   :: math.Color   // Re-export
// For now, it will be left mostly empty or with truly general types. Users will
// import directly from `odingame/math/primitives` or `odingame/math/math_aliases`.

// Example of a type that might remain or be added here if not fitting elsewhere:
// Engine_Handle :: distinct u32 // A generic handle type for engine resources

// For now, keeping it minimal as most types have moved to odingame.math.
// Users should import from `odingame/math` for math-related types.

// Placeholder: If any truly general types are needed later, they can go here.
// For example, if `Duration` wasn't in `core:time` and was engine-specific:
// Duration :: distinct i64 // Nanoseconds, for example

// The `Color` constants like `WHITE`, `BLACK` etc. were previously defined here.
// They are now `Color_White`, `Color_Black` in `odingame/math/primitives.odin`.
// If global unqualified access is desired (like `WHITE` instead of `math.Color_White`),
// that would typically be handled by importing the `math` package with a dot `import . "../math"`,
// or by re-exporting specific constants here.
// e.g. import m "../math"; WHITE :: m.Color_White;
// For now, users will use qualified names like `math.Color_White`.

// Rectf was removed as it's not part of the immediate XNA-type consolidation.
// It can be added to odingame.math.primitives if needed later.
log_if_types_is_still_imported :: proc() {
    // This is a dummy procedure. If any file still imports "odingame/types"
    // expecting the old types, this might help trace it during a full build
    // if those types are now missing, causing compile errors.
    // Or, more practically, the compiler errors for missing types will guide the update.
    #if ODIN_DEBUG {
        // log.debug("odingame/types/types.odin was imported. Ensure all type references are updated to odingame/math where appropriate.")
    }
}
