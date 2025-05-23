package core

import "core:mem"
import "core:sync"

// RefCounted is the base type for all reference-counted objects
RefCounted :: struct {
    // Using atomic operations for thread safety
    ref_count: sync.Atomic_Int,
    // Optional callback for custom cleanup when refcount reaches zero
    on_zero:   proc("" $T: typeid, resource: ^T),
}

// init_refcount initializes the reference count to 1 (owned by the caller)
init_refcount :: proc(rc: ^$T/RefCounted, on_zero: proc(^T)) {
    rc.ref_count.store(1, .Relaxed)
    rc.on_zero = auto_cast on_zero
}

// add_ref increments the reference count
add_ref :: proc(rc: ^$T/RefCounted) -> ^T {
    if rc != nil {
        rc.ref_count.add(1, .Acquire_Release)
    }
    return rc
}

// release decrements the reference count and calls the cleanup callback if it reaches zero
release :: proc(rc: ^$T/RefCounted) -> (result: ^T) {
    if rc == nil {
        return nil
    }
    
    // Decrement and get the new count
    count := rc.ref_count.sub(1, .Acquire_Release)
    
    if count == 0 {
        // Call the cleanup callback if it exists
        if rc.on_zero != nil {
            rc.on_zero(rc)
        }
        return nil
    } else if count < 0 {
        // This should never happen if references are managed correctly
        // Consider panicking or logging an error in debug builds
        when ODIN_DEBUG {
            panic("Reference count went negative!")
        }
    }
    
    return rc
}

// get_ref_count gets the current reference count (mostly for debugging)
get_ref_count :: proc(rc: ^$T/RefCounted) -> int {
    return rc != nil ? int(rc.ref_count.load(.Relaxed)) : 0
}
