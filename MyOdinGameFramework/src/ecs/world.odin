package ecs

import "src:core" // Logging
import "core:mem" // For mem.copy in AddComponent
import "core:raw_data" // For raw_data.buffer access
import "core:reflect" // For type_info_of in Remove/Get/HasComponent

// World is the central container for all ECS data and managers.
World :: struct {
	entity_manager:     ^EntityManager,
	component_registry: ^ComponentRegistry,
	system_manager:     ^SystemManager,

	// Storage for all component pools, mapped by ComponentID.
	component_pools:    map[ComponentID]^ComponentPool,
}

// CreateWorld initializes a new ECS World.
CreateWorld :: proc(initial_entity_capacity: int = 1024) -> ^World {
	core.LogInfo("[ECS] Creating World...")
	world := new(World)

	world.entity_manager = CreateEntityManager(initial_entity_capacity)
	world.component_registry = CreateComponentRegistry()
	world.system_manager = CreateSystemManager()
	world.component_pools = make(map[ComponentID]^ComponentPool)

	core.LogInfo("[ECS] World created successfully.")
	return world
}

// DestroyWorld cleans up all resources used by the ECS World.
DestroyWorld :: proc(world: ^World) {
	if world == nil { return }
	core.LogInfo("[ECS] Destroying World...")

	// Destroy managers first
	DestroySystemManager(world.system_manager)
	// Components pools need to be destroyed before the registry that knows about their types.
	// Destroying pools might also involve iterating components if they have specific cleanup.
	for cid, pool in world.component_pools {
		DestroyComponentPool(pool) // Assumes DestroyComponentPool frees its internal data
	}
	delete(world.component_pools) // Delete the map itself

	DestroyComponentRegistry(world.component_registry) // Names in TypeInfo are deleted here
	DestroyEntityManager(world.entity_manager)
	
	free(world)
	core.LogInfo("[ECS] World destroyed.")
}

// --- World methods for component/entity operations ---

// GetPool retrieves (or creates and retrieves) a ComponentPool for a given ComponentID.
@(private="ecs.World.get_pool_internal") 
get_or_create_pool :: proc(world: ^World, cid: ComponentID) -> (^ComponentPool, bool) {
	if existing_pool, ok := world.component_pools[cid]; ok {
		return existing_pool, true
	}

	type_info_ptr, type_ok := GetComponentTypeInfo(world.component_registry, cid)
	if !type_ok || type_info_ptr == nil {
		core.LogErrorFmt("[ECS] World.get_or_create_pool: Failed to get ComponentTypeInfo for CID %v to create a new pool.", cid)
		return nil, false
	}

	new_pool := CreateComponentPool(type_info_ptr^) 
	world.component_pools[cid] = new_pool
	core.LogInfoFmt("[ECS] World: Auto-created ComponentPool for '%s' (CID: %v)", type_info_ptr.name, cid)
	return new_pool, true
}

// AddComponent adds a component for an entity in this world.
AddComponent :: proc(world: ^World, entity_id: EntityID, component_type: typeid, component_data: rawptr) -> bool {
	if !IsEntityAlive(world.entity_manager, entity_id) {
		core.LogWarningFmt("[ECS] AddComponent: Attempt to add component to inactive/invalid EntityID %v.", entity_id)
		return false
	}

	cid := GetCID(world.component_registry, component_type) 
	if cid == COMPONENT_ID_NIL {
		core.LogErrorFmt("[ECS] AddComponent: Failed to get/register CID for type %v", component_type)
		return false
	}
	
	type_info_ptr, ok := GetComponentTypeInfo(world.component_registry, cid)
	if !ok || type_info_ptr == nil {
		core.LogErrorFmt("[ECS] AddComponent: Could not get type info for CID %v", cid)
		return false
	}
	type_info := type_info_ptr^

	pool, pool_ok := get_or_create_pool(world, cid)
	if !pool_ok {
		core.LogErrorFmt("[ECS] AddComponent: Failed to get or create pool for CID %v (%s)", cid, type_info.name)
		return false
	}

	if _, exists := pool.sparse_to_dense[u32(entity_id)]; exists {
		core.LogWarningFmt("[ECS] AddComponent: Entity %v already has component %s. Overwriting.", entity_id, type_info.name)
		dense_idx := pool.sparse_to_dense[u32(entity_id)]
		component_dest_ptr := raw_data.buffer_get_ptr_at_idx(&pool.dense_data, dense_idx, type_info.size)
		mem.copy(component_dest_ptr, component_data, type_info.size)
		return true
	}

	dense_idx := len(pool.dense_to_sparse) 
	raw_data.buffer_append(&pool.dense_data, component_data, type_info.size, type_info.alignment)
	
	append(&pool.dense_to_sparse, entity_id)
	pool.sparse_to_dense[u32(entity_id)] = dense_idx
	return true
}

// RemoveComponent removes a component from an entity in this world.
RemoveComponent :: proc(world: ^World, entity_id: EntityID, component_type: typeid) -> bool {
	if !IsEntityAlive(world.entity_manager, entity_id) { return false } 

    ti := type_info_of(component_type)
    if ti == nil { // Check if type_info_of returned nil
        core.LogErrorFmt("[ECS] RemoveComponent: Failed to get type_info for type %v.", component_type)
        return false
    }
    cid, cid_exists := world.component_registry.typeid_to_cid[ti.id]
	if !cid_exists { 
        return false 
    }
	
	pool, pool_ok := world.component_pools[cid] 
	if !pool_ok {
		return false
	}

	dense_idx_to_remove, ok := pool.sparse_to_dense[u32(entity_id)]
	if !ok {
		return false
	}

	last_dense_idx := len(pool.dense_to_sparse) - 1
	entity_id_of_last_element := pool.dense_to_sparse[last_dense_idx]

	if dense_idx_to_remove != last_dense_idx {
		raw_data.buffer_unordered_remove(&pool.dense_data, dense_idx_to_remove, pool.type_info.size)
		pool.dense_to_sparse[dense_idx_to_remove] = entity_id_of_last_element
		pool.sparse_to_dense[u32(entity_id_of_last_element)] = dense_idx_to_remove
	} else {
        raw_data.buffer_resize(&pool.dense_data, last_dense_idx * pool.type_info.size)
    }
	
	delete_key(&pool.sparse_to_dense, u32(entity_id))
	pop(&pool.dense_to_sparse)
	return true
}

// GetComponent retrieves a pointer to an entity's component in this world.
GetComponent :: proc(world: ^World, entity_id: EntityID, component_type: typeid) -> rawptr {
	if !IsEntityAlive(world.entity_manager, entity_id) { return nil }

    ti := type_info_of(component_type)
    if ti == nil { // Check if type_info_of returned nil
        core.LogErrorFmt("[ECS] GetComponent: Failed to get type_info for type %v.", component_type)
        return nil
    }
    cid, cid_exists := world.component_registry.typeid_to_cid[ti.id]
	if !cid_exists { return nil }
	
	pool, pool_ok := world.component_pools[cid]
	if !pool_ok { return nil }

	dense_idx, ok := pool.sparse_to_dense[u32(entity_id)]
	if !ok { return nil }

	return raw_data.buffer_get_ptr_at_idx(&pool.dense_data, dense_idx, pool.type_info.size)
}

// HasComponent checks if an entity has a specific component in this world.
HasComponent :: proc(world: ^World, entity_id: EntityID, component_type: typeid) -> bool {
	if !IsEntityAlive(world.entity_manager, entity_id) { return false }

    ti := type_info_of(component_type)
    if ti == nil { // Check if type_info_of returned nil
        core.LogErrorFmt("[ECS] HasComponent: Failed to get type_info for type %v.", component_type)
        return false
    }
    cid, cid_exists := world.component_registry.typeid_to_cid[ti.id]
	if !cid_exists { return false }

	pool, pool_ok := world.component_pools[cid]
	if !pool_ok { return false }
	
	_, ok := pool.sparse_to_dense[u32(entity_id)]
	return ok
}

// Helper to get component by CID, useful for systems that work with CIDs directly.
GetComponentByCID :: proc(world: ^World, entity_id: EntityID, cid: ComponentID) -> rawptr {
    if !IsEntityAlive(world.entity_manager, entity_id) { return nil }

    pool, pool_ok := world.component_pools[cid]
    if !pool_ok { return nil }

    dense_idx, ok := pool.sparse_to_dense[u32(entity_id)]
    if !ok { return nil }

    return raw_data.buffer_get_ptr_at_idx(&pool.dense_data, dense_idx, pool.type_info.size)
}

// RunSystems convenience method on World
RunWorldSystems :: proc(world: ^World, dt: f32) {
    RunSystems(world.system_manager, world, dt) 
}

// CreateEntity convenience method on World
CreateWorldEntity :: proc(world: ^World) -> EntityID {
    return CreateEntity(world.entity_manager)
}

// DestroyEntity convenience method on World
DestroyWorldEntity :: proc(world: ^World, id: EntityID) {
    if !IsEntityAlive(world.entity_manager, id) {
        core.LogWarningFmt("[ECS] DestroyWorldEntity: Entity %v is not alive or already destroyed.", id)
        return
    }

    for cid, pool in world.component_pools {
        if _, exists := pool.sparse_to_dense[u32(id)]; exists {
            dense_idx_to_remove := pool.sparse_to_dense[u32(id)] 
            last_dense_idx := len(pool.dense_to_sparse) - 1
            entity_id_of_last_element := pool.dense_to_sparse[last_dense_idx]

            if dense_idx_to_remove != last_dense_idx {
                raw_data.buffer_unordered_remove(&pool.dense_data, dense_idx_to_remove, pool.type_info.size)
                pool.dense_to_sparse[dense_idx_to_remove] = entity_id_of_last_element
                pool.sparse_to_dense[u32(entity_id_of_last_element)] = dense_idx_to_remove
            } else {
                raw_data.buffer_resize(&pool.dense_data, last_dense_idx * pool.type_info.size)
            }
            delete_key(&pool.sparse_to_dense, u32(id))
            pop(&pool.dense_to_sparse)
        }
    }

    DestroyEntity(world.entity_manager, id)
}


// --- Component Querying ---

// QueryCallback is a procedure called for each entity that matches a query.
// It receives the World context and the EntityID.
QueryCallback :: proc(world: ^World, entity_id: EntityID)

// QueryEntities iterates over all active entities that possess ALL specified component types.
// For each matching entity, it invokes the provided callback.
// component_types: A slice of typeids representing the components an entity must have.
// callback: The procedure to call for each matching entity.
QueryEntities :: proc(world: ^World, component_types: []typeid, callback: QueryCallback) {
	if world == nil || callback == nil {
		core.LogError("[ECS] QueryEntities: nil world or callback provided.")
		return
	}
	if len(component_types) == 0 {
		core.LogWarning("[ECS] QueryEntities: Called with no component types specified. No entities will be processed.")
		return
	}

	// For this basic query, we iterate all active entities from the EntityManager.
	// A more optimized approach (e.g., iterating the smallest component pool) could be used later.
	
	// Need a way to iterate active entities from EntityManager.
	// EntityManager.active_entities is a map[EntityID]bool.
	// Iterating map keys:
	for entity_id, is_active in world.entity_manager.active_entities {
		if !is_active { // Should not happen if active_entities only stores active ones
			continue 
		}

		match_all_components := true
		for _, comp_type_id in component_types {
			if !HasComponent(world, entity_id, comp_type_id) {
				match_all_components = false
				break // Entity doesn't have this component, so it's not a match
			}
		}

		if match_all_components {
			// This entity has all the required components. Invoke the callback.
			callback(world, entity_id)
		}
	}
}

// Example of a more specific query for two components, often used by systems.
// This is a convenience wrapper around QueryEntities.
// Systems can use this to get component data directly.
// Q2_Callback :: proc(world: ^World, entity_id: EntityID, c1: ^$C1, c2: ^$C2)
// QueryEntities2 :: proc(world: ^World, C1: typeid, C2: typeid, callback: Q2_Callback($C1, $C2)) {
//     // ... implementation would use QueryEntities and then GetComponent for C1 and C2 ...
//     // This shows the direction for more ergonomic querying for systems.
//     // For now, systems will use QueryEntities and call GetComponent themselves.
// }
