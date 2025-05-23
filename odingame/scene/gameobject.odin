package scene

import "../core" // For GameTime
import "../graphics" // For SpriteBatch
import "../math"   // For Transform2D, Vector2f
import "core:mem"
import "core:slice"
import "core:log"
import "core:fmt" // For potential debug name printing

// GameObject is the basic building block for scene entities.
GameObject :: struct {
	name: string,
	
	transform: math.Transform2D, // Local transform relative to parent
	// Cached world transform. Recalculated when dirty.
	// Note: Storing world_transform directly in GameObject can be problematic if an object is part of multiple scenes
	// or if its parent changes frequently in complex ways outside a single scene graph update.
	// For typical scene graph, caching it is fine.
	_world_transform: math.Transform2D, 
	_world_transform_dirty: bool,

	components: [dynamic]Component, // Owned components
	
	parent:   ^GameObject,
	children: [dynamic]^GameObject, // Pointers to children; children are owned by the scene or another system if not parented.
	                                // For a strict tree, children are owned by their parent.
	                                // If children are added via add_child, this GameObject "owns" them for lifetime.

	active: bool, // Is the GameObject itself active? Affects updates and drawing of self and children.
	// active_in_hierarchy: bool, // Cached state of whether it's active considering parent's state (advanced)

	allocator: mem.Allocator, // Allocator used for this GameObject's dynamic arrays (components, children)
}


// --- Constructor and Destructor ---

// new_game_object creates a new GameObject.
// The GameObject owns its list of components and its list of children.
// When a GameObject is destroyed, it destroys its components and recursively destroys its children.
new_game_object :: proc(name: string, allocator := context.allocator) -> ^GameObject {
	go := new(GameObject, allocator)
	go.name = name
	go.allocator = allocator
	go.transform = math.transform2d_identity()
	go._world_transform = math.transform2d_identity()
	go._world_transform_dirty = true // Initially dirty to force first calculation
	go.active = true
	// Initialize dynamic arrays with the GameObject's allocator
	go.components = make([dynamic]Component, 0, 4, allocator) // Initial capacity of 4 for components
	go.children = make([dynamic]^GameObject, 0, 4, allocator)  // Initial capacity of 4 for children
	return go
}

// destroy_game_object recursively destroys a GameObject, its components, and its children.
// It also removes itself from its parent if it has one.
destroy_game_object :: proc(go: ^GameObject) {
	if go == nil {
		return
	}
	log.debugf("Destroying GameObject: %s", go.name)

	// 1. Remove from parent
	if go.parent != nil {
		// This will call _orphan_child internally if set_parent(go, nil) is used.
		// Or, if we want to be explicit about internal list management:
		_raw_remove_child(go.parent, go) // Internal helper, assumes go is indeed a child
	}

	// 2. Destroy all components' data
	// The component structs themselves are part of go.components dynamic array and will be freed with it.
	// We need to call their specific destroy functions and free their `component_data`.
	for i := 0; i < len(go.components); i = i + 1 {
		// Pass the GameObject's allocator, assuming component_data was allocated with it.
		// This is a convention that must be followed by add_component.
		destroy_component_data(&go.components[i], go.allocator)
	}
	delete(go.components) // Free the dynamic array of components

	// 3. Recursively destroy children
	// Iterate backwards as children might modify the list when they are removed from their parent (this GO).
	// However, since we are deleting the whole sub-tree, direct iteration is fine.
	// Clone the children list before iteration if children's destroy_game_object modifies go.children
	// (e.g. if child calls set_parent(nil) which calls remove_child on `go`).
	// To be safe, iterate on a copy or manage indices carefully.
	// For a simple recursive destroy, direct iteration on current children should be okay
	// as they are removed from *their* parent (which is `go`), but `go.children` itself isn't
	// directly modified by the child's `set_parent(nil)` in a way that breaks this loop
	// *if* `_raw_remove_child` is used carefully.
	// A safer pattern: copy pointers, then iterate.
	children_to_destroy := slice.clone(go.children[:], context.temp_allocator) // Use temp allocator for the copy
	defer delete(children_to_destroy)

	for child_ptr in children_to_destroy {
		destroy_game_object(child_ptr) // Recursive call
	}
	// After all children are destroyed (and thus should have removed themselves from `go.children` if `set_parent(nil)` was robust),
	// the `go.children` dynamic array can be deleted.
	delete(go.children) // Free the dynamic array of children pointers

	// 4. Free the GameObject itself
	free(go, go.allocator)
}


// --- Hierarchy Management ---

// _raw_add_child is an internal helper to add a child without parent checks.
// Assumes parentage is already handled (e.g., child's parent pointer set).
_raw_add_child :: proc(parent_go: ^GameObject, child_go: ^GameObject) {
	// Optional: Check if child is already in the list to prevent duplicates
	// for existing_child in parent_go.children { if existing_child == child_go { return } }
	append(&parent_go.children, child_go)
}

// _raw_remove_child is an internal helper to remove a child.
// Assumes parentage is already handled (e.g., child's parent pointer cleared).
_raw_remove_child :: proc(parent_go: ^GameObject, child_go: ^GameObject) {
	found_idx := -1
	for i, c in parent_go.children {
		if c == child_go {
			found_idx = i
			break
		}
	}
	if found_idx != -1 {
		slice.ordered_remove(&parent_go.children, found_idx)
	}
}

// set_parent assigns a new parent to a GameObject.
// If new_parent is nil, the GameObject becomes a root object (orphaned).
set_parent :: proc(child_go: ^GameObject, new_parent_go: ^GameObject) {
	if child_go == nil {
		return
	}
	// Cannot parent to self
	if child_go == new_parent_go {
		log.warnf("GameObject '%s' cannot parent to itself.", child_go.name)
		return
	}
	// TODO: Prevent circular parenting (e.g. child_go becomes an ancestor of new_parent_go)
	// This requires traversing up new_parent_go's hierarchy. For now, skipping this check.

	// Remove from old parent's children list, if any
	if child_go.parent != nil {
		_raw_remove_child(child_go.parent, child_go)
	}

	// Set new parent
	child_go.parent = new_parent_go

	// Add to new parent's children list, if new_parent is not nil
	if new_parent_go != nil {
		_raw_add_child(new_parent_go, child_go)
	}
	
	mark_transform_dirty(child_go) // World transform needs recalculation
}

// add_child is a convenience function. Same as set_parent(child, parent).
add_child :: proc(parent_go: ^GameObject, child_go: ^GameObject) {
	if parent_go == nil || child_go == nil {
		log.error("add_child: parent_go or child_go is nil.")
		return
	}
	set_parent(child_go, parent_go)
}

// remove_child is a convenience function. Same as set_parent(child, nil) if child is indeed a child of parent.
// More robustly, it ensures the child is actually parented to this parent before orphaning.
remove_child :: proc(parent_go: ^GameObject, child_go: ^GameObject) {
	if parent_go == nil || child_go == nil {
		log.error("remove_child: parent_go or child_go is nil.")
		return
	}
	if child_go.parent == parent_go { // Ensure this parent is actually the current parent
		set_parent(child_go, nil) // Orphan the child
	} else {
		log.warnf("remove_child: GameObject '%s' is not a direct child of '%s'. Cannot remove.", child_go.name, parent_go.name)
	}
}


// --- Component Management ---

// add_component creates a Component struct, stores it in the GameObject's component list,
// and associates it with the provided component_data and vtable.
// The component_data is assumed to be allocated by the caller using an allocator compatible
// with the one used by destroy_component_data (typically go.allocator).
// `data_typeid` must be `typeid_of()` the actual type of `component_data_ptr`.
add_component :: proc(go: ^GameObject, component_data_ptr: rawptr, data_typeid: typeid, vtable_ptr: ^Component_VTable) -> ^Component {
	if go == nil || component_data_ptr == nil || vtable_ptr == nil {
		log.error("add_component: GameObject, component_data_ptr, or vtable_ptr is nil.")
		return nil
	}
	
	new_comp := Component{
		owner = go,
		vtable = vtable_ptr,
		component_data = component_data_ptr,
		component_data_typeid = data_typeid,
		active = true,
	}
	append(&go.components, new_comp)
	
	// Return a pointer to the component within the dynamic array.
	// This pointer is stable as long as the array is not reallocated in a way that moves elements,
	// or if elements are not removed before this one.
	// For many use cases, getting the component by typeid later is safer.
	return &go.components[len(go.components)-1]
}

// get_component searches for a component by the typeid of its data struct.
// Returns Maybe(^Component) - .? gives the pointer if .ok is true.
get_component :: proc(go: ^GameObject, type_id_to_find: typeid) -> Maybe(^Component) {
	if go == nil {
		return Maybe(^Component){}
	}
	for i := 0; i < len(go.components); i = i + 1 {
		if go.components[i].component_data_typeid == type_id_to_find {
			return Maybe(^Component){&go.components[i], true}
		}
	}
	return Maybe(^Component){} // Not found
}

// TODO: get_components (plural, for multiple components of same type, though less common with this model)
// TODO: remove_component (needs careful handling of component_data destruction and list modification)


// --- Transform Management ---

// mark_transform_dirty flags this GameObject and all its children as needing world transform recalculation.
mark_transform_dirty :: proc(go: ^GameObject) {
	if go == nil {
		return
	}
	go._world_transform_dirty = true
	for child_go in go.children {
		mark_transform_dirty(child_go) // Recursive call
	}
}

// get_world_transform returns the calculated world transform for the GameObject.
// If the transform is dirty, it recalculates it based on its parent and local transform.
get_world_transform :: proc(go: ^GameObject) -> math.Transform2D {
	if go == nil {
		// Should not happen if called on valid GO. Return identity or handle error.
		log.error("get_world_transform called on nil GameObject.")
		return math.transform2d_identity()
	}

	if go._world_transform_dirty {
		if go.parent != nil {
			parent_world_t := get_world_transform(go.parent) // Recursive call to ensure parent is up-to-date
			go._world_transform = math.transform2d_combine(parent_world_t, go.transform)
		} else {
			// No parent, local transform is world transform
			go._world_transform = go.transform
		}
		go._world_transform_dirty = false
	}
	return go._world_transform
}

// set_local_position updates the local position and marks the transform dirty.
set_local_position :: proc(go: ^GameObject, pos: math.Vector2f) {
	if go == nil { return }
	go.transform.position = pos
	mark_transform_dirty(go)
}

set_local_rotation :: proc(go: ^GameObject, angle_degrees: f32) {
    if go == nil { return }
    // Assuming Transform2D stores rotation as radians or has a method to set from degrees.
    // For now, direct assignment if Transform2D.rotation is in degrees, or convert.
    // If Transform2D.rotation is a complex number or quaternion, this would be different.
    // Let's assume it's a simple float for degrees for this stub.
    // go.transform.rotation_degrees = angle_degrees; // Or similar
    log.warnf("GameObject '%s': set_local_rotation (%.2f deg) called, but Transform2D rotation field/method is not fully defined here. Assuming direct angle storage or conversion.", go.name, angle_degrees)
    // If Transform2D stores radians:
    // go.transform.rotation_radians = math.deg_to_rad(angle_degrees) 
    mark_transform_dirty(go)
}

set_local_scale :: proc(go: ^GameObject, scale: math.Vector2f) {
    if go == nil { return }
    go.transform.scale = scale
    mark_transform_dirty(go)
}


// --- Update and Draw ---

// update calls update on all active components of this GameObject,
// then recursively calls update on all its active children.
update_game_object :: proc(go: ^GameObject, game_time: core.GameTime) {
	if go == nil || !go.active {
		return
	}

	// Update components
	for i := 0; i < len(go.components); i = i + 1 {
		// Pass &go.components[i] because update_component takes ^Component
		update_component(&go.components[i], game_time)
	}

	// Update children
	for child_go in go.children {
		update_game_object(child_go, game_time) // Recursive call
	}
}

// draw calls draw on all active components of this GameObject,
// then recursively calls draw on all its active children.
// It calculates the world transform before drawing.
draw_game_object :: proc(go: ^GameObject, sprite_batch: ^gfx.SpriteBatch) {
	if go == nil || !go.active {
		return
	}

	// Calculate current object's world transform
	current_world_transform := get_world_transform(go)
	// Note: In a more complex system, the parent's world transform would be passed down to avoid
	// redundant parent lookups in get_world_transform if already calculated by caller.
	// However, get_world_transform caches, so repeated calls are cheap if not dirty.

	// Draw components
	for i := 0; i < len(go.components); i = i + 1 {
		draw_component(&go.components[i], sprite_batch, current_world_transform)
	}

	// Draw children
	// Children will combine their local transform with this `current_world_transform` (implicitly via their `get_world_transform`).
	for child_go in go.children {
		draw_game_object(child_go, sprite_batch) // Recursive call
	}
}
