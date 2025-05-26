package game

import "src:core"  // For logging
import "src:ecs"   // Import the ECS package
// Import "src:sdl" // For delta_time if it's not passed directly, though dt is from main loop

// MovementSystem updates entity positions based on their velocities.
MovementSystem :: proc(world: ^ecs.World, dt: f32) {
	// Define the component types this system is interested in.
	required_components := [dynamic]typeid{PositionComponent, VelocityComponent}
	defer delete(required_components) // Clean up the dynamic array

	// core.LogInfoFmt("[MovementSystem] Running with dt: %f, Querying for %v entities", dt, len(required_components)) // Can be verbose

	entities_processed := 0
	ecs.QueryEntities(world, required_components[:], proc(w: ^ecs.World, entity_id: ecs.EntityID) {
		// This callback is executed for each entity that has PositionComponent and VelocityComponent.
		pos := cast(^PositionComponent)ecs.GetComponent(w, entity_id, PositionComponent)
		vel := cast(^VelocityComponent)ecs.GetComponent(w, entity_id, VelocityComponent)

		// Should always be non-nil due to the query, but a safety check is good practice.
		if pos == nil || vel == nil {
			core.LogErrorFmt("[MovementSystem] Query returned entity %v without expected components!", entity_id)
			return
		}
		
		// Update position
		pos.x += vel.dx * dt
		pos.y += vel.dy * dt

		entities_processed += 1
		// core.LogInfoFmt("[MovementSystem] Entity %v: Pos (%f, %f), Vel (%f, %f)", entity_id, pos.x, pos.y, vel.dx, vel.dy) // Verbose
	})

	// if entities_processed > 0 {
	// 	core.LogInfoFmt("[MovementSystem] Processed %d entities.", entities_processed) // Verbose
	// }
}
