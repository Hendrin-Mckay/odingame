package math

import "core:log"
import "core:sort"
import "core:math" // For lerp, etc.

// Curve_Loop_Type defines how a curve behaves before its first key and after its last key.
Curve_Loop_Type :: enum {
    Constant,   // The value of the first/last key is returned.
    Cycle,      // The curve is repeated.
    Cycle_Offset, // The curve is repeated with an offset based on the curve's start/end values.
    Oscillate,  // The curve is mirrored and repeated.
    Linear,     // The curve is linearly extrapolated.
}

// Curve_Tangent_Type defines the type of tangent for a CurveKey.
Curve_Tangent_Type :: enum {
    Flat,   // Tangent is horizontal (0).
    Linear, // Tangent is linear (straight line to next/previous key).
    Smooth, // Tangent is smooth (e.g., Catmull-Rom or Hermite).
    // Step, // For stepped curves (value remains constant until next key) - XNA has this
}

// Curve_Key represents a single point (key) on a curve.
// It defines a position (time), value, and tangents for interpolation.
Curve_Key :: struct {
    position:     f32, // The X-coordinate (time) of the key.
    value:        f32, // The Y-coordinate (value) of the key.
    tangent_in:   f32, // Tangent approaching this key from the previous key.
    tangent_out:  f32, // Tangent leaving this key towards the next key.
    continuity:   Curve_Tangent_Type, // How tangents are handled at this key.
}

// Curve represents a collection of Curve_Keys that define an animation curve.
Curve :: struct {
    keys:             [dynamic]Curve_Key, // Keys must be sorted by position.
    pre_loop:         Curve_Loop_Type,
    post_loop:        Curve_Loop_Type,
    
    // _is_sorted: bool, // Internal flag to ensure keys are sorted before evaluation
}

// --- Curve Helper Procedures ---

// curve_new creates a new Curve instance.
curve_new :: proc(allocator := context.allocator) -> ^Curve {
    curve := new(Curve, allocator)
    curve.keys = make([dynamic]Curve_Key, 0, 4, allocator) // Start with a small capacity
    curve.pre_loop = .Constant
    curve.post_loop = .Constant
    // curve._is_sorted = true // Initially true for an empty curve
    return curve
}

// curve_destroy frees the memory used by a Curve.
curve_destroy :: proc(curve: ^Curve) {
    if curve == nil { return }
    // Keys are part of the dynamic array, will be deleted with it.
    // If Curve_Key itself contained allocated memory, it would need custom deletion.
    delete(curve.keys)
    free(curve, curve.allocator) // Assuming allocator was stored or context is appropriate
}

// curve_add_key adds a new key to the curve.
// Keys should ideally be added in order of position, or sort_keys should be called.
curve_add_key :: proc(curve: ^Curve, key: Curve_Key) {
    if curve == nil { return }
    append(&curve.keys, key)
    // curve._is_sorted = false // Adding a key might unsort it
}

// curve_sort_keys sorts the keys by position. Necessary for correct evaluation.
curve_sort_keys :: proc(curve: ^Curve) {
    if curve == nil || len(curve.keys) == 0 {
        return
    }
    sort.slice(curve.keys, proc(a, b: Curve_Key) -> bool {
        return a.position < b.position
    })
    // curve._is_sorted = true
}

// curve_evaluate evaluates the value of the curve at a given position.
// This is a simplified implementation using linear interpolation between keys.
// Full Hermite spline evaluation (using tangents) is more complex.
// Pre-loop and post-loop behavior is not fully implemented here yet.
curve_evaluate :: proc(curve: ^Curve, position: f32) -> f32 {
    if curve == nil || len(curve.keys) == 0 {
        // log.warn("curve_evaluate: Curve is nil or has no keys.")
        return 0.0 // Or NaN, or some other default
    }

    // Ensure keys are sorted (caller should manage this, or we do it internally)
    // if !curve._is_sorted {
    //     log.warn("curve_evaluate: Keys are not sorted. Sorting now. Call curve_sort_keys for efficiency.")
    //     curve_sort_keys(curve)
    // }

    first_key := curve.keys[0]
    last_key := curve.keys[len(curve.keys)-1]

    // Handle pre-loop (position before first key)
    if position < first_key.position {
        #partial switch curve.pre_loop {
        case .Constant: return first_key.value
        // TODO: Implement .Cycle, .Cycle_Offset, .Oscillate, .Linear for pre-loop
        case: return first_key.value // Default to Constant
        }
    }

    // Handle post-loop (position after last key)
    if position > last_key.position {
        #partial switch curve.post_loop {
        case .Constant: return last_key.value
        // TODO: Implement .Cycle, .Cycle_Offset, .Oscillate, .Linear for post-loop
        case: return last_key.value // Default to Constant
        }
    }

    // Find the two keys that bracket the position (or the key itself if position matches a key)
    // This assumes keys are sorted.
    prev_key_idx := -1
    for i := 0; i < len(curve.keys); i += 1 {
        if curve.keys[i].position == position {
            return curve.keys[i].value // Exact match
        }
        if curve.keys[i].position < position {
            prev_key_idx = i
        } else { // curve.keys[i].position > position
            break // Found the segment
        }
    }

    // Should be between keys[prev_key_idx] and keys[prev_key_idx+1]
    if prev_key_idx == -1 || prev_key_idx + 1 >= len(curve.keys) {
        // This case should ideally be handled by pre/post loop logic or indicate an error
        // if keys are not sorted or position is outside the last key somehow missed by post-loop.
        // If only one key, pre/post loop should have handled it.
        // If prev_key_idx is the last key, post-loop should handle.
        // log.errorf("curve_evaluate: Position %v is out of evaluated key range after pre/post loop. Prev_idx: %d. NumKeys: %d", 
        //           position, prev_key_idx, len(curve.keys))
        // This might happen if position == last_key.position and it wasn't caught by the exact match.
        if prev_key_idx == len(curve.keys) -1 && curve.keys[prev_key_idx].position == position {
             return curve.keys[prev_key_idx].value
        }
        return last_key.value // Fallback, should not be hit with proper pre/post loop
    }

    key1 := curve.keys[prev_key_idx]
    key2 := curve.keys[prev_key_idx+1]

    // Linear interpolation for now
    // t = (position - key1.position) / (key2.position - key1.position)
    // value = lerp(key1.value, key2.value, t)
    
    if key1.position == key2.position { // Avoid division by zero if keys have same position
        return key1.value
    }

    t := (position - key1.position) / (key2.position - key1.position)
    
    // Basic linear interpolation (lerp)
    // return key1.value + t * (key2.value - key1.value) 
    // Using core:math.lerp if available, or implement manually.
    // For now, assume math.lerp exists for f32.
    // If not, simple (1-t)*a + t*b.
    // return math.lerp(key1.value, key2.value, t) // This is usually for vectors.
    // Manual lerp:
    value := (1.0 - t) * key1.value + t * key2.value

    // TODO: Implement Hermite spline interpolation using tangents if continuity is .Smooth or .Linear (for non-flat linear)
    // switch key1.continuity { // Or key2.continuity, or a combination
    // case .Smooth: // Hermite
    // case .Linear: // Linear (already done)
    // case .Flat: // value should be key1.value until key2.position (effectively)
    //     return key1.value
    // }


    return value
}
