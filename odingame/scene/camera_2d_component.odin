package scene

import "../core" // For core.Color, core.GameTime
import "../graphics" // For gfx.Color (if used, but core.Color is preferred), gfx.SpriteBatch
import "../math"   // For math.Vector2f, math.Matrix4f, math.Transform2D
import "core:log"
import "core:math/linalg" // For matrix operations
import "core:math"      // For math.tan, etc.

// --- Camera2DComponent Specific Data ---
Camera2DComponent_Data :: struct {
	zoom:            f32,
	viewport_size:   math.Vector2f, // Width and height of the camera's view in pixels
	background_color: core.Color,    // Color to clear the screen with
	// is_active_camera_tag: bool, // Tag to identify, Scene will hold the actual active reference.
	                            // This tag can be useful for querying if a GO *thinks* it's an active camera.
	                            // However, Scene.active_camera_component is the source of truth.
}

// --- Camera Logic ---

// get_view_matrix calculates the view matrix for the camera.
// The view matrix transforms world coordinates to camera (view) space.
// It's the inverse of the camera's world transformation matrix.
get_view_matrix :: proc(camera_data: ^Camera2DComponent_Data, camera_go_world_transform: math.Transform2D) -> math.Matrix4f {
	// The camera's "position" in the world is defined by its GameObject's world transform.
	// The view matrix is the inverse of this transform.
	// For a 2D camera, we typically consider:
	// - Translation: Inverse of camera's world position.
	// - Rotation: Inverse of camera's world rotation.
	// - Scale (Zoom): This is often applied in the projection matrix, but can also be part of view.
	//   If zoom is part of view, it would scale the world *around* the camera's position.
	//   It's simpler to handle zoom in projection. Here, we'll assume view matrix doesn't include camera_data.zoom directly.

	// Create a transform that represents the camera's orientation in the world
	cam_world_matrix := math.transform2d_to_matrix(camera_go_world_transform)
	
	// The view matrix is the inverse of the camera's world matrix.
	// linalg.matrix4_inverse can calculate this.
	view_matrix, ok := linalg.matrix4_inverse(cam_world_matrix)
	if !ok {
		log.error("Failed to invert camera world matrix for view matrix. Returning identity.")
		return linalg.matrix4_identity()
	}
	
	return view_matrix
}


// get_projection_matrix calculates the projection matrix for the camera.
// This is typically an orthographic projection for 2D cameras.
// Zoom is applied here by scaling the orthographic view volume.
get_projection_matrix :: proc(camera_data: ^Camera2DComponent_Data) -> math.Matrix4f {
	if camera_data == nil || camera_data.zoom == 0 {
		log.error("get_projection_matrix: Camera data is nil or zoom is zero. Returning identity.")
		return linalg.matrix4_identity()
	}

	// Zoom effect: Smaller zoom value means seeing more (zoomed out), larger means seeing less (zoomed in).
	// The orthographic projection extents are adjusted by zoom.
	// If zoom = 1.0, viewport_size is mapped directly.
	// If zoom = 2.0 (zoomed in), we see half the width/height.
	// If zoom = 0.5 (zoomed out), we see double the width/height.
	ortho_width  := camera_data.viewport_size.x / camera_data.zoom
	ortho_height := camera_data.viewport_size.y / camera_data.zoom

	// Create an orthographic projection.
	// The origin of the projection can be center (e.g. -width/2 to width/2) or top-left (0 to width).
	// For SpriteBatch, we used 0 to width (top-left origin for screen coordinates).
	// Let's assume camera looks at its own position as the center of its view.
	// So, projection extents are [-ortho_width/2, +ortho_width/2] and [-ortho_height/2, +ortho_height/2]
	// if the camera's GameObject position is (0,0) in world space and we want that to be screen center.
	// However, the view matrix already handles camera position.
	// The projection should map the camera's viewable area (defined by ortho_width/height) to NDC.
	// If using a top-left origin for screen coordinates (like SpriteBatch default):
	// left = 0, right = ortho_width, bottom = ortho_height, top = 0
	// This matches how SpriteBatch set up its projection if no camera was used.
	// The view matrix will then position this viewport in the world.
	
	// For a camera centered at its GameObject's position, and viewport_size defining the
	// extent of what's visible at zoom=1:
	left   := -ortho_width / 2
	right  :=  ortho_width / 2
	bottom := -ortho_height/ 2 // In many 2D systems, Y might be inverted (e.g. top = -H/2, bottom = H/2 for Y-up)
	top    :=  ortho_height/ 2  // Or, if Y is down in screen space: top=0, bottom=H; or top=-H/2, bottom=H/2 with Y pointing up.
	                            // Let's assume Y points up in world space, and projection maps to NDC where Y also points up.
								// The `linalg.orthographic_rh_zo` maps bottom to -1, top to 1 if using those directly.
								// If we want a projection where (0,0) is top-left of viewport:
								// left=0, right=width, top=0, bottom=height (for Y-down systems)
								// For Y-up systems, with (0,0) at bottom-left of viewport:
								// left=0, right=width, bottom=0, top=height

	// Let's use a projection where the camera's world position is the center of the view.
	// The viewport_size then dictates how much is seen around that center.
	// Projection matrix:
	// This creates a view volume centered at (0,0) in view space.
	// The view matrix has already transformed the world so the camera is at the origin of view space.
	// Near/Far planes for orthographic projection.
	near_plane: f32 = -1.0 // Or 0.0 if using a 0-to-1 depth range convention (homogeneous_depth=true)
	far_plane:  f32 =  1.0
	
	// Using linalg.orthographic_rh_zo (Right-Handed, Zero-to-One depth)
	// or _no (Near-to-One) for OpenGL style depth (-1 to 1).
	// SpriteBatch used ortho_rh_zo(0, W, H, 0, -1, 1) - this has origin top-left, Y pointing down screen.
	// If we want camera center to be (0,0) of its viewport_size:
	// proj := linalg.orthographic_rh_zo(left, right, bottom, top, near_plane, far_plane, homogeneous_depth = false for GL)
	// Let's be consistent with SpriteBatch's previous default if no camera: top-left origin.
	// This means the projection itself doesn't center. The view matrix handles the "camera position".
	// If camera is at (cx, cy), view matrix effectively translates world by (-cx, -cy).
	// Then projection maps (0,0) in view space to top-left of screen, (ortho_width, ortho_height) to bottom-right.
	// This seems most compatible with existing SpriteBatch if its shaders expect top-left UVs for screen.
	// However, a typical camera projection is centered. Let's use centered for now.
	// This implies game world coordinates are relative to a world origin, and camera moves in this world.
	// Viewport coordinates (after projection) are then -1 to 1 (or 0 to 1).

	// Centered Orthographic Projection:
	// This means if camera is at (0,0) and zoom is 1, world coordinates from
	// -viewport_size.x/2 to +viewport_size.x/2 are visible.
	proj := linalg.matrix4_orthographic(
		left, right, 
		bottom, top,          // For Y-up in view space to Y-up in NDC
		near_plane, far_plane,
		false, // homogeneous_depth = false for OpenGL style depth range [-1, 1]
	)
	// If game world has Y-down for coordinates (e.g. top of screen is Y=0, bottom is Y=Height):
	// Then use: top, bottom instead of bottom, top to flip Y axis for projection if needed.
	// proj := linalg.matrix4_orthographic(left, right, top, bottom, near_plane, far_plane, false)
	// This depends on chosen world coordinate system and rendering conventions.
	// For now, assume world Y is up, screen Y is up in NDC.

	return proj
}


// --- Component VTable Implementation ---

// camera_2d_update is the component's update function. Empty for now.
camera_2d_update :: proc(self: ^Component, game_time: core.GameTime) {
	// camera_data := cast(^Camera2DComponent_Data)self.component_data
	// Camera logic can go here (e.g., smooth follow, screen shake effects)
	// For now, camera properties (zoom, viewport) are set directly.
}

// camera_2d_draw: Cameras themselves don't draw, they provide matrices. Empty.
camera_2d_draw :: proc(self: ^Component, sprite_batch: ^gfx.SpriteBatch, world_transform: math.Transform2D) {
	// No-op
}

// camera_2d_destroy: Cleans up Camera2DComponent_Data.
camera_2d_destroy :: proc(self: ^Component) {
	// camera_data := cast(^Camera2DComponent_Data)self.component_data
	// If Camera2DComponent_Data held any heap-allocated resources itself, free them here.
	// For this struct, it's all value types, so nothing beyond freeing component_data itself,
	// which is handled by destroy_component_data in component.odin.
	log.debugf("Camera2DComponent destroyed for GameObject: %s", self.owner.name if self.owner != nil else "nil")
}

// CAMERA_2D_COMPONENT_VTABLE is the global vtable for Camera2DComponent.
CAMERA_2D_COMPONENT_VTABLE :: Component_VTable{
	update  = camera_2d_update,
	draw    = camera_2d_draw,
	destroy = camera_2d_destroy,
}


// --- Constructor Helper ---

// make_camera_2d_component_data allocates and initializes the Camera2DComponent_Data.
// This is typically called by a higher-level add_camera_2d_component function.
make_camera_2d_component_data :: proc(
	viewport_width, viewport_height: f32, 
	zoom_level: f32,
	bg_color: core.Color,
	allocator := context.allocator,
) -> ^Camera2DComponent_Data {
	data := new(Camera2DComponent_Data, allocator)
	data.viewport_size = {viewport_width, viewport_height}
	data.zoom = zoom_level if zoom_level > 0 else 1.0
	data.background_color = bg_color
	// data.is_active_camera_tag = false // Default, Scene will manage active camera
	return data
}

// add_camera_2d_component creates a Camera2DComponent, initializes its data,
// and adds it to the specified GameObject.
// Returns a pointer to the created Component in the GameObject's component list.
add_camera_2d_component :: proc(
	owner_go: ^GameObject, 
	viewport_width, viewport_height: f32, 
	zoom_level: f32,
	bg_color := core.Color{50,50,50,255}, // Default dark grey
) -> ^Component { // Returns ^scene.Component
	if owner_go == nil {
		log.error("add_camera_2d_component: owner_go is nil.")
		return nil
	}
	
	// Use the GameObject's allocator for its component data.
	camera_data_ptr := make_camera_2d_component_data(viewport_width, viewport_height, zoom_level, bg_color, owner_go.allocator)
	
	// Add component to GameObject
	// The typeid_of(^Camera2DComponent_Data) is not what we want. We want typeid_of(Camera2DComponent_Data).
	// However, component_data stores a rawptr to it.
	// To get a component of type Camera2DComponent_Data, we'd search for typeid_of(Camera2DComponent_Data).
	// So, store typeid_of(Camera2DComponent_Data), not its pointer.
	comp_ptr := add_component(owner_go, camera_data_ptr, typeid_of(Camera2DComponent_Data), &CAMERA_2D_COMPONENT_VTABLE)
	
	if comp_ptr == nil {
		// add_component failed, need to free the allocated camera_data_ptr
		free(camera_data_ptr, owner_go.allocator)
		return nil
	}
	
	log.infof("Camera2DComponent added to GameObject '%s'. Viewport: %vx%v, Zoom: %v", 
		owner_go.name, viewport_width, viewport_height, zoom_level)
	return comp_ptr
}
