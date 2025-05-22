package scene

import "../core" // For GameTime
import "../graphics" // For SpriteBatch
import "../math"   // For Transform2D (though not directly used by Scene methods, GameObjects use it)
import "core:mem"
import "core:slice"
import "core:log"

// Scene manages a collection of root GameObjects and orchestrates their update and draw calls.
Scene :: struct {
	name: string,
	root_game_objects: [dynamic]^GameObject, // Pointers to root GameObjects
	
	// Active camera: pointer to the Component struct (which is part of a GameObject's component list).
	// The component_data of this Component will be a ^Camera2DComponent_Data.
	active_camera_component: Maybe(^Component), 
	
	allocator: mem.Allocator,
}

// --- Constructor and Destructor ---

// new_scene creates a new, empty Scene.
new_scene :: proc(name: string, allocator := context.allocator) -> ^Scene {
	s := new(Scene, allocator)
	s.name = name
	s.allocator = allocator
	// Initialize dynamic array with the scene's allocator
	s.root_game_objects = make([dynamic]^GameObject, 0, 8, allocator) // Initial capacity of 8 root objects
	log.infof("Scene '%s' created.", name)
	return s
}

// destroy_scene destroys the scene and all GameObjects it manages (root and their children).
destroy_scene :: proc(s: ^Scene) {
	if s == nil {
		return
	}
	log.infof("Destroying Scene: %s", s.name)

	// Destroy all root GameObjects. This will recursively destroy their children and components.
	// Iterate on a copy if destroy_game_object (specifically, child's set_parent(nil))
	// might modify s.root_game_objects. However, root objects have nil parent, so set_parent(nil) on them
	// won't affect s.root_game_objects through parentage.
	// The destroy_game_object also handles removing itself from its parent, which is nil for roots.
	// So, direct iteration should be fine here.
	for root_go in s.root_game_objects {
		destroy_game_object(root_go) // This frees the GameObject and its hierarchy
	}
	delete(s.root_game_objects) // Free the dynamic array itself

	free(s, s.allocator) // Free the Scene struct
}


// --- Scene Management ---

// set_active_camera sets the active camera for the scene.
// Pass camera_owner_go = nil to deactivate the current camera.
set_active_camera :: proc(s: ^Scene, camera_owner_go: ^GameObject) {
	if s == nil {
		log.error("set_active_camera: Scene is nil.")
		return
	}

	if camera_owner_go == nil {
		s.active_camera_component = Maybe(^Component){} // Clear active camera
		log.info("Scene '%s': Active camera cleared.", s.name)
		return
	}

	// Verify the GameObject has a Camera2DComponent
	camera_comp_maybe := get_component(camera_owner_go, typeid_of(Camera2DComponent_Data))
	if !camera_comp_maybe.ok {
		log.errorf("GameObject '%s' does not have a Camera2DComponent. Cannot set as active camera for Scene '%s'.", 
			camera_owner_go.name, s.name)
		s.active_camera_component = Maybe(^Component){} // Ensure no invalid camera is set
		return
	}
	
	// Ensure the component data is actually Camera2DComponent_Data (though typeid check should suffice)
	// _, data_ok := camera_comp_maybe.?.component_data.(^Camera2DComponent_Data)
	// if !data_ok { 
	//     log.errorf("GameObject '%s' has a component with the right typeid, but data is not ^Camera2DComponent_Data.", camera_owner_go.name)
	//     s.active_camera_component = Maybe(^Component){}
	//     return
	// }

	s.active_camera_component = camera_comp_maybe
	// camera_data := cast(^Camera2DComponent_Data)camera_comp_maybe.?.component_data
	// camera_data.is_active_camera_tag = true // Set tag if used, though Scene holds the true reference.
	// De-activate old camera's tag if it existed and we were using tags:
	// (This requires finding the old camera component if only GO was stored, but now we store ^Component directly)
	log.infof("Scene '%s': GameObject '%s' set as active camera.", s.name, camera_owner_go.name)
}


// add_root_game_object adds a GameObject to the scene's list of root objects.
// The GameObject should not have a parent if it's being added as a root object.
add_root_game_object :: proc(s: ^Scene, go: ^GameObject) {
	if s == nil || go == nil {
		log.error("add_root_game_object: Scene or GameObject is nil.")
		return
	}
	if go.parent != nil {
		log.warnf("GameObject '%s' already has a parent. Cannot add as root to Scene '%s'. Set its parent to nil first.", go.name, s.name)
		return
	}
	// Optional: Check if 'go' is already in root_game_objects to prevent duplicates.
	// for existing_go in s.root_game_objects { if existing_go == go { return } }
	
	append(&s.root_game_objects, go)
	// log.debugf("GameObject '%s' added as root to Scene '%s'.", go.name, s.name)
}

// remove_root_game_object removes a GameObject from the scene's list of root objects.
// This does NOT destroy the GameObject itself, only removes it from the scene's management.
// The caller is responsible for destroying the GameObject if it's no longer needed.
remove_root_game_object :: proc(s: ^Scene, go: ^GameObject) {
	if s == nil || go == nil {
		log.error("remove_root_game_object: Scene or GameObject is nil.")
		return
	}
	
	found_idx := -1
	for i, root_go in s.root_game_objects {
		if root_go == go {
			found_idx = i
			break
		}
	}
	
	if found_idx != -1 {
		slice.ordered_remove(&s.root_game_objects, found_idx)
		// log.debugf("GameObject '%s' removed from root of Scene '%s'.", go.name, s.name)
		// Note: go.parent should remain nil as it was a root object.
	} else {
		log.warnf("GameObject '%s' not found in root list of Scene '%s'. Cannot remove.", go.name, s.name)
	}
}


// --- Update and Draw ---

// update iterates through all active root GameObjects in the scene and calls their update methods.
update_scene :: proc(s: ^Scene, game_time: core.GameTime) {
	if s == nil {
		return
	}
	// Iterate on a copy of the slice if game objects could be added/removed during update,
	// which might invalidate iterators or change slice length.
	// For now, assuming updates don't modify s.root_game_objects list directly.
	for root_go in s.root_game_objects {
		// GameObject's own update will handle its 'active' state and children.
		update_game_object(root_go, game_time)
	}
}

// draw iterates through all active root GameObjects in the scene and calls their draw methods.
// The initial parent_transform for root objects is identity.
// draw_scene now uses the active camera to set up projection and clear screen.
draw_scene :: proc(
	s: ^Scene, 
	sprite_batch: ^gfx.SpriteBatch, 
	gfx_api_ref: ^gfx.Gfx_Device_Interface, // Pointer to the global gfx_api
	device: gfx.Gfx_Device,                 // The Gfx_Device handle
	window: gfx.Gfx_Window,                 // The Gfx_Window handle (for default projection)
) {
	if s == nil || sprite_batch == nil || gfx_api_ref == nil || !core.is_valid(device) {
		log.error("draw_scene: Scene, SpriteBatch, gfx_api_ref, or Gfx_Device is nil/invalid.")
		return
	}

	proj_view_matrix: math.Matrix4f
	clear_color_final: core.Color

	active_camera_found := false
	if s.active_camera_component.ok {
		camera_comp := s.active_camera_component.?
		if camera_comp.active && camera_comp.component_data != nil {
			// Ensure it's the correct data type (already checked by typeid in set_active_camera)
			camera_data := cast(^Camera2DComponent_Data)camera_comp.component_data
			
			// 1. Clear screen with camera's background color
			clear_options := gfx.Clear_Options{
				color = { // Convert core.Color to [4]f32
					f32(camera_data.background_color.r)/255,
					f32(camera_data.background_color.g)/255,
					f32(camera_data.background_color.b)/255,
					f32(camera_data.background_color.a)/255,
				},
				clear_color = true,
				clear_depth = true, // Assume depth clearing for a 2D camera too for consistency
				depth = 1.0,
			}
			gfx_api_ref.clear_screen(device, clear_options)

			// 2. Calculate View and Projection matrices
			cam_owner_go := camera_comp.owner
			cam_world_transform := get_world_transform(cam_owner_go) // Ensures transform is up-to-date
			
			view_matrix := get_view_matrix(camera_data, cam_world_transform)
			projection_matrix := get_projection_matrix(camera_data)
			
			// Combine: P * V (Standard order: projection applies to view space)
			proj_view_matrix = linalg.matrix_multiply(projection_matrix, view_matrix)
			active_camera_found = true
			
			// log.debugf("Scene '%s': Drawing with active camera '%s'. VP: %v", s.name, cam_owner_go.name, proj_view_matrix)
		}
	}

	if !active_camera_found {
		// No active camera, or active camera component is inactive/invalid. Use default.
		log.debugf("Scene '%s': No active camera. Using default projection and clear.", s.name)
		
		// Default clear (e.g., black)
		default_bg := core.Color{20, 20, 20, 255}
		clear_options := gfx.Clear_Options{
			color = {f32(default_bg.r)/255, f32(default_bg.g)/255, f32(default_bg.b)/255, f32(default_bg.a)/255},
			clear_color = true, clear_depth = true, depth = 1.0,
		}
		gfx_api_ref.clear_screen(device, clear_options)

		// Default orthographic projection based on window size
		win_w, win_h := gfx_api_ref.get_window_drawable_size(window) // Use drawable size for projection
		if win_w == 0 || win_h == 0 { 
			log.warn("draw_scene: Window drawable size is zero. Cannot create default projection.")
			// Fallback to identity or skip drawing if sprite_batch requires valid matrix
			proj_view_matrix = linalg.matrix4_identity()
		} else {
			proj_view_matrix = linalg.matrix4_orthographic(0, f32(win_w), f32(win_h), 0, -1, 1, false) // Y-down, like SB default
		}
	}

	// Begin SpriteBatch with the determined projection_view_matrix
	gfx.begin_batch(sprite_batch, proj_view_matrix)

	// Draw root GameObjects
	for root_go in s.root_game_objects {
		draw_game_object(root_go, sprite_batch)
	}
	
	// End SpriteBatch - This should typically be done by the main game loop after all scenes/UI are drawn
	// to the same SpriteBatch instance for that frame.
	// gfx.end_batch(sprite_batch) 
	// For now, assuming draw_scene is the only thing using this sprite_batch instance this frame,
	// or that the game loop handles begin/end around all draw_scene calls.
	// The subtask implies SpriteBatch uses the matrix, which is set in begin_batch. End_batch flushes.
	// Let's assume for now the game loop calls end_batch.
}
