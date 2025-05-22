package scene

// Forward declarations to break circular dependencies.
// GameObject will be fully defined in gameobject.odin.
// SpriteBatch and GameTime are from external packages.
import go "../core" // For GameTime (ocore.GameTime)
import gfx "../graphics" // For SpriteBatch (^graphics.SpriteBatch)
import math "../math"  // For Transform2D (math.Transform2D)

// GameObject_Handle is used as a forward declaration for ^GameObject.
// The actual ^GameObject type will be used once both files are processed by the compiler.
// This is a common way to handle mutual dependencies in Odin if direct pointer types cause issues
// across file boundaries before full type resolution, though often direct ^OtherStruct works.
// For clarity and to be safe with multi-file struct dependencies, using a distinct handle type
// for the forward reference can sometimes help, then casting.
// However, direct use of `^GameObject` should be fine as long as one is defined before the other,
// or they are in the same package and declaration order is resolved.
// Let's try with direct ^GameObject and ensure file processing order or package semantics handle it.
// If not, a temporary distinct handle type could be an intermediate step.
// For now, assuming ^GameObject from gameobject.odin will be resolvable.
// Actual type: import g "../gameobject" (^g.GameObject) - but that creates import cycle.
// So, we'll define Component with owner: rawptr initially, and cast, or rely on Odin's type system for pointers.
// Let's use `^GameObject` and ensure it's defined. For this file, we only need its size for the pointer.

// Pre-declare GameObject so Component can use a pointer to it.
// The full definition of GameObject will be in gameobject.odin.
GameObject :: struct; 

// Component_VTable defines the "interface" for a component.
// Procedures will operate on `component_data: rawptr` which points to the actual component struct.
Component_VTable :: struct {
	// Called when the component is updated.
	update: proc(self: ^Component, game_time: go.GameTime),
	
	// Called when the component is drawn (if it's drawable).
	// world_transform is the final transform of the owning GameObject.
	draw: proc(self: ^Component, sprite_batch: ^gfx.SpriteBatch, world_transform: math.Transform2D),
	
	// Called when the component or its owning GameObject is destroyed.
	// Used for cleaning up any resources held by the component's specific data.
	destroy: proc(self: ^Component),
	
	// (Optional) Other lifecycle methods like:
	// on_add: proc(self: ^Component, owner: ^GameObject)
	// on_remove: proc(self: ^Component)
	// on_enable: proc(self: ^Component)
	// on_disable: proc(self: ^Component)
}

// Component is a generic container that attaches to a GameObject.
// It holds a pointer to specific component data and a vtable for its behavior.
Component :: struct {
	owner:          ^GameObject,      // Pointer to the GameObject that owns this component.
	vtable:         ^Component_VTable,// Points to the functions that define this component's behavior.
	component_data: rawptr,           // Pointer to the actual data for this specific component type.
	                                  // e.g., ^SpriteRendererComponent, ^PlayerControllerComponent.
	component_data_typeid: typeid,    // Stores typeid_of(the_actual_component_data_struct) for GetComponent
	active:         bool,             // Whether this component is currently active (update/draw will be called).
}


// --- Component Lifecycle Helper Functions (to be called via vtable) ---

// update_component calls the component's specific update function.
update_component :: proc(comp: ^Component, game_time: go.GameTime) {
	if comp != nil && comp.active && comp.vtable != nil && comp.vtable.update != nil {
		comp.vtable.update(comp, game_time)
	}
}

// draw_component calls the component's specific draw function.
draw_component :: proc(comp: ^Component, sprite_batch: ^gfx.SpriteBatch, world_transform: math.Transform2D) {
	if comp != nil && comp.active && comp.vtable != nil && comp.vtable.draw != nil {
		comp.vtable.draw(comp, sprite_batch, world_transform)
	}
}

// destroy_component calls the component's specific destroy function and frees its data.
// Note: The Component struct itself is usually part of a GameObject's list and freed with GameObject,
// or if components are dynamically allocated and stored as pointers `^Component`.
// This destroy is for the `component_data`.
destroy_component_data :: proc(comp: ^Component, allocator: mem.Allocator) {
	if comp == nil {
		return
	}
	if comp.vtable != nil && comp.vtable.destroy != nil {
		comp.vtable.destroy(comp) // Call specific cleanup
	}
	if comp.component_data != nil {
		// We need the allocator that was used for component_data.
		// This implies component creation needs to store/know its allocator.
		// For now, assuming a passed-in allocator or a global one from context.
		// This is a simplification. A robust system would track allocators per allocation.
		// If component_data was allocated with `new()`, it uses `context.allocator`.
		// If `allocator` param is provided, it's assumed to be the correct one for comp.component_data.
		free(comp.component_data, allocator) 
		comp.component_data = nil
	}
	// The Component struct itself is not freed here, as it's typically embedded or managed by GameObject.
}


// --- Example of how a specific component might be defined (Illustrative) ---
/*
// MyCustomComponentData :: struct {
//     some_value: int,
//     // other fields...
// }

// my_custom_component_update :: proc(self: ^Component, game_time: go.GameTime) {
//     data := cast(^MyCustomComponentData)self.component_data
//     log.debugf("MyCustomComponent (owner: %s) updating! Value: %d", self.owner.name, data.some_value)
//     data.some_value += 1
// }

// my_custom_component_draw :: proc(self: ^Component, sprite_batch: ^gfx.SpriteBatch, world_transform: math.Transform2D) {
//     // This component might not draw anything
// }

// my_custom_component_destroy :: proc(self: ^Component) {
//     data := cast(^MyCustomComponentData)self.component_data
//     log.debugf("MyCustomComponent (owner: %s) destroying! Final value: %d", self.owner.name, data.some_value)
//     // No specific heap allocations in MyCustomComponentData, so nothing extra to free beyond the struct itself.
// }

// Global vtable for MyCustomComponent type
// MY_CUSTOM_COMPONENT_VTABLE :: Component_VTable{
//     update = my_custom_component_update,
//     draw = my_custom_component_draw,
//     destroy = my_custom_component_destroy,
// }

// Constructor for MyCustomComponent
// create_my_custom_component :: proc(owner_go: ^GameObject, initial_value: int, allocator: mem.Allocator) -> Component {
//     data := new(MyCustomComponentData, allocator)
//     data.some_value = initial_value
    
//     return Component{
//         owner = owner_go,
//         vtable = &MY_CUSTOM_COMPONENT_VTABLE,
//         component_data = data,
//         active = true,
//     }
// }
*/
// Note: GameObject definition and its component management functions (add_component, get_component)
// will be in gameobject.odin.
// This file just defines the Component structure and interface pattern.
