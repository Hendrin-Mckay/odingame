package ecs

import "src:core" // Adjusted for logger: using core.LogInfo etc.
// import "core:mem" // For managing free list if it gets complex

// EntityID is a distinct type for unique entity identifiers.
// Using u32 for now; can be u64 if more entities are anticipated.
EntityID :: distinct u32

// A special EntityID value to represent a null or invalid entity.
ENTITY_NIL :: EntityID(max(u32)) // Or 0, if 0 is not a valid ID. Using max(u32) is safer.

// EntityManager is responsible for creating, destroying, and recycling EntityIDs.
EntityManager :: struct {
	next_id:         u32,     // Counter for the next available ID.
	free_ids:        [dynamic]u32, // Stack of recycled IDs.
	// generation:   [dynamic]u8, // Optional: for checking "alive" status with ID recycling.
	// min_free_ids: int,       // Optional: to keep a certain number of IDs in free_ids.
	active_entities: map[EntityID]bool, // To quickly check if an entity is active
}

// CreateEntityManager initializes a new entity manager.
CreateEntityManager :: proc(initial_capacity: int = 1024) -> ^EntityManager {
	core.LogInfo("[ECS] Creating Entity Manager...") // Adjusted to core.LogInfo
	manager := new(EntityManager)
	manager.next_id = 0
	// manager.free_ids = make([dynamic]u32, 0, initial_capacity) // Reserve some space
	// manager.active_entities = make(map[EntityID]bool, initial_capacity)
	// Or initialize with make() if preferred for dynamic arrays/maps
	manager.free_ids = make([dynamic]u32)
	manager.active_entities = make(map[EntityID]bool)
	return manager
}

// DestroyEntityManager cleans up the entity manager.
DestroyEntityManager :: proc(manager: ^EntityManager) {
	if manager == nil {
		return
	}
	core.LogInfo("[ECS] Destroying Entity Manager...") // Adjusted to core.LogInfo
	delete(manager.free_ids)
	delete(manager.active_entities)
	free(manager)
}

// CreateEntity generates a new unique EntityID.
CreateEntity :: proc(manager: ^EntityManager) -> EntityID {
	if manager == nil {
		core.LogError("[ECS] CreateEntity called on nil EntityManager.") // Adjusted to core.LogError
		return ENTITY_NIL
	}

	id_val: u32
	if len(manager.free_ids) > 0 {
		id_val = pop(&manager.free_ids) // Pop from the end of the free list
	} else {
		// Ensure next_id doesn't wrap around to ENTITY_NIL or other special values if u32 is used.
		// This simple manager doesn't handle exhaustion of u32 space well,
		// a real one might need generations or u64 IDs.
		if manager.next_id == max(u32) {
			core.LogError("[ECS] Entity ID space exhausted!") // Adjusted to core.LogError
			return ENTITY_NIL 
		}
		id_val = manager.next_id
		manager.next_id += 1
	}
	
	entity := EntityID(id_val)
	manager.active_entities[entity] = true
	// core.LogInfoFmt("[ECS] Created Entity: %v", entity) // Can be too verbose
	return entity
}

// DestroyEntity marks an EntityID as free for recycling.
// Note: This only frees the ID. Component data associated with this ID
// must be cleaned up separately by the component system.
DestroyEntity :: proc(manager: ^EntityManager, id: EntityID) {
	if manager == nil {
		core.LogError("[ECS] DestroyEntity called on nil EntityManager.") // Adjusted to core.LogError
		return
	}
	if id == ENTITY_NIL {
		core.LogWarning("[ECS] Attempted to destroy ENTITY_NIL.") // Adjusted to core.LogWarning
		return
	}

	if !manager.active_entities[id] {
		// Adjusted to core.LogWarningFmt
		core.LogWarningFmt("[ECS] Attempted to destroy inactive or already destroyed EntityID: %v", id) 
		return
	}

	delete_key(&manager.active_entities, id)
	append(&manager.free_ids, u32(id)) // Add ID to free list
	// core.LogInfoFmt("[ECS] Destroyed Entity: %v", id) // Can be too verbose
}

// IsEntityAlive checks if an entity ID is currently active.
IsEntityAlive :: proc(manager: ^EntityManager, id: EntityID) -> bool {
    if manager == nil || id == ENTITY_NIL {
        return false
    }
    return manager.active_entities[id] or_else false // or_else false if key not found
}
