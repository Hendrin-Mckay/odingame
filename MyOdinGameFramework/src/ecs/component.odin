package ecs

import "src:core" // Adjusted for logger: using core.LogInfo etc.
import "core:reflect" // For type_info
import "core:strings"
import "core:mem" // For copy, etc.
import "core:raw_data"
// import "core:slice" // For operations on slices if needed
// import "core:intrinsics" // For size_of, align_of if not using type_info directly for this


// Note: World_Placeholder and _ToWorld functions (AddComponent_ToWorld, etc.) 
// and private stubs (_GetPool, _GetComponentRegistryFromWorld) are removed.
// Their functionality is now part of the World struct methods in world.odin.

// ComponentID is a distinct type for unique component type identifiers.
// Often derived from type_info.Type_Info.id.
ComponentID :: distinct u32

// COMPONENT_ID_NIL represents an invalid or unregistered component type.
COMPONENT_ID_NIL :: ComponentID(max(u32))

// ComponentTypeInfo stores metadata about a registered component type.
ComponentTypeInfo :: struct {
	id:        ComponentID,
	size:      int,
	alignment: int,
	name:      string, // Fully qualified name from type_info
	// destroy_proc: proc(component_data: rawptr), // Optional: for components needing special destruction
}

// ComponentRegistry holds information about all registered component types.
// This could be part of the World struct or a standalone manager.
ComponentRegistry :: struct {
	// Maps ComponentID to its TypeInfo.
	infos:         map[ComponentID]ComponentTypeInfo,
	// Maps typeid (reflect.Type_Info.id) to ComponentID for quick lookup during registration.
	typeid_to_cid: map[u32]ComponentID, 
	next_cid:      u32, // Simple counter for generating ComponentIDs if not using type_info.id directly
}

// CreateComponentRegistry initializes a new component registry.
CreateComponentRegistry :: proc() -> ^ComponentRegistry {
	core.LogInfo("[ECS] Creating Component Registry...") // Adjusted to core.LogInfo
	registry := new(ComponentRegistry)
	registry.infos = make(map[ComponentID]ComponentTypeInfo)
	registry.typeid_to_cid = make(map[u32]ComponentID)
	registry.next_cid = 0 // Start CIDs from 0
	return registry
}

// DestroyComponentRegistry cleans up the component registry.
DestroyComponentRegistry :: proc(registry: ^ComponentRegistry) {
	if registry == nil {
		return
	}
	core.LogInfo("[ECS] Destroying Component Registry...") // Adjusted to core.LogInfo
	// Free cloned names in ComponentTypeInfo if any were deeply cloned
	for _, info in registry.infos {
		delete(info.name) // Assuming name was cloned
	}
	delete(registry.infos)
	delete(registry.typeid_to_cid)
	free(registry)
}

// RegisterComponent registers a component type (T) with the registry.
// It uses Odin's typeid system.
// Returns the ComponentID for the type, or COMPONENT_ID_NIL on failure.
RegisterComponent :: proc(registry: ^ComponentRegistry, T: typeid) -> ComponentID {
	if registry == nil {
		core.LogError("[ECS] RegisterComponent called on nil ComponentRegistry.") // Adjusted
		return COMPONENT_ID_NIL
	}

	ti := type_info_of(T)
	if ti == nil {
		core.LogError("[ECS] Failed to get type_info for component registration.") // Adjusted
		return COMPONENT_ID_NIL
	}

	typeid_val := ti.id // This is reflect.Type_Info.id

	// Check if already registered
	if existing_cid, ok := registry.typeid_to_cid[typeid_val]; ok {
		// core.LogWarningFmt("[ECS] Component type '%s' (TypeID: %v) already registered with CID: %v. Returning existing.", ti.name, typeid_val, existing_cid) // Adjusted
		return existing_cid
	}

	// Generate a new ComponentID
	cid := ComponentID(registry.next_cid)
	registry.next_cid += 1
	
	info := ComponentTypeInfo{
		id        = cid,
		size      = ti.size,
		alignment = ti.align,
		name      = strings.clone(ti.name), // Clone the name string
	}
	registry.infos[cid] = info
	registry.typeid_to_cid[typeid_val] = cid

	core.LogInfoFmt("[ECS] Registered component '%s' (Size: %d, Align: %d) -> CID: %v, TypeInfoID: %v", info.name, info.size, info.alignment, cid, typeid_val) // Adjusted
	return cid
}

// GetComponentTypeInfo retrieves the ComponentTypeInfo for a given ComponentID.
GetComponentTypeInfo :: proc(registry: ^ComponentRegistry, cid: ComponentID) -> (^ComponentTypeInfo, bool) {
    if registry == nil { return nil, false }
    
    // To return a pointer to the value in the map (if it exists):
    if existing_info_ptr, found := &registry.infos[cid]; found {
        return existing_info_ptr, true
    }
    return nil, false
}

// GetCID :: proc(registry: ^ComponentRegistry, T: typeid) -> ComponentID
// Helper to get ComponentID from typeid, registers if not present.
GetCID :: proc(registry: ^ComponentRegistry, T: typeid) -> ComponentID {
    ti := type_info_of(T)
    if ti == nil { // Added nil check for ti
        core.LogError("[ECS] GetCID: Failed to get type_info.")
        return COMPONENT_ID_NIL
    }
    if existing_cid, ok := registry.typeid_to_cid[ti.id]; ok {
        return existing_cid
    }
    // Automatically register if not found.
    return RegisterComponent(registry, T)
}


// --- Component Storage Structures ---

// ComponentPool stores all instances of a single component type.
// It uses a dense array for component data and a sparse set for EntityID mapping.
ComponentPool :: struct {
	type_info:     ComponentTypeInfo, // Copy of the type info for this pool
	
	// Dense storage for component instances. Data is type-erased.
	// Each element is `type_info.size` bytes.
	dense_data:    raw_data.Buffer,
	
	// Sparse set: maps EntityID to the index in `dense_data`.
	// The key is the raw u32 value of EntityID.
	sparse_to_dense: map[u32]int,
	
	// Dense to sparse: maps index in `dense_data` back to EntityID.
	// This is useful for removal by swapping with the last element.
	dense_to_sparse: [dynamic]EntityID, 
	
	// Count of active components in this pool (also len(dense_to_sparse)).
	// count:         int, // Can be derived from len(dense_to_sparse) or dense_data size / type_info.size
}

// CreateComponentPool initializes a new pool for a given component type.
CreateComponentPool :: proc(type_info: ComponentTypeInfo, initial_capacity: int = 64) -> ^ComponentPool {
	pool := new(ComponentPool)
	pool.type_info = type_info 

	// Initialize dense_data buffer. Initial capacity in bytes.
	// Ensure alignment is handled by raw_data.buffer_init if it takes alignment.
	// Odin's default allocator should handle alignment correctly for the buffer itself.
	// The elements within will be aligned if the buffer starts aligned and sizes are multiples of alignment.
	raw_data.buffer_init(&pool.dense_data, initial_capacity * type_info.size) // Alignment managed by buffer_append
	
	pool.sparse_to_dense = make(map[u32]int, initial_capacity)
	pool.dense_to_sparse = make([dynamic]EntityID, 0, initial_capacity)
	
	core.LogInfoFmt("[ECS] Created ComponentPool for '%s' (CID: %v)", type_info.name, type_info.id)
	return pool
}

// DestroyComponentPool frees resources used by a component pool.
DestroyComponentPool :: proc(pool: ^ComponentPool) {
	if pool == nil { return }
	core.LogInfoFmt("[ECS] Destroying ComponentPool for '%s' (CID: %v)", pool.type_info.name, pool.type_info.id)
	
	// Note: If components contain heap-allocated data not managed by Odin's GC (if any on those types),
	// and need manual destruction, that logic would go here, iterating through components.
	// For now, assume components are plain data or managed elsewhere if complex.

	raw_data.buffer_destroy(&pool.dense_data)
	delete(pool.sparse_to_dense)
	delete(pool.dense_to_sparse)
	// delete(pool.type_info.name) // This was cloned during RegisterComponent, so it should be deleted here
	                            // if ComponentTypeInfo in the pool is the sole owner.
	                            // However, ComponentTypeInfo is also in ComponentRegistry.
	                            // The name should be deleted when ComponentTypeInfo is removed from registry or when registry is destroyed.
	                            // Let's assume DestroyComponentRegistry handles deleting names in its stored TypeInfos.
	free(pool)
}

// Component operations that used to have _ToWorld suffix (e.g. AddComponent_ToWorld)
// and the private stubs (_GetPool, _GetComponentRegistryFromWorld) have been removed from this file.
// Their logic has been integrated into methods on the `World` struct in `world.odin`.
