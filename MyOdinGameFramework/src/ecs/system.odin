package ecs

import "src:core" // For logging
import "core:strings" // For strings.clone
// import "core:time" // Might be useful if systems get individual timing later

// Note: World_Placeholder removed as World is now defined in world.odin.
// Procedures now take ^World directly.

// SystemUpdateProc is the signature for a system's main update function.
// It takes the game world and delta time as parameters.
SystemUpdateProc :: proc(world: ^World, dt: f32)

// System struct wraps a system procedure and any associated metadata.
System :: struct {
	name:         string, // For debugging and identification
	update_proc:  SystemUpdateProc,
	// query_mask:   u64, // Optional: Bitmask representing component types this system cares about.
	// priority:     int, // Optional: For ordering system updates.
	// enabled:      bool,
}

// SystemManager holds and manages all registered game systems.
SystemManager :: struct {
	systems: [dynamic]^System, // Ordered list of systems
	// systems_by_name: map[string]^System, // Optional: for quick lookup by name
}

// CreateSystemManager initializes a new system manager.
CreateSystemManager :: proc() -> ^SystemManager {
	core.LogInfo("[ECS] Creating System Manager...")
	manager := new(SystemManager)
	manager.systems = make([dynamic]^System)
	// manager.systems_by_name = make(map[string]^System)
	return manager
}

// DestroySystemManager cleans up the system manager.
DestroySystemManager :: proc(manager: ^SystemManager) {
	if manager == nil { return }
	core.LogInfo("[ECS] Destroying System Manager...")
	for system_ptr in manager.systems {
		delete(system_ptr.name) // Assuming name was cloned
		free(system_ptr)        // Free the System struct itself
	}
	delete(manager.systems)
	// delete(manager.systems_by_name) // If used
	free(manager)
}

// AddSystem registers a new system with the manager.
// The `name` is cloned for ownership by the System struct.
AddSystem :: proc(manager: ^SystemManager, system_proc: SystemUpdateProc, name: string) {
	if manager == nil || system_proc == nil {
		core.LogError("[ECS] AddSystem: Called with nil manager or system procedure.")
		return
	}

	core.LogInfoFmt("[ECS] Adding System: %s", name)
	system_obj := new(System)
	system_obj.name = strings.clone(name) // Clone the name
	system_obj.update_proc = system_proc
	// system_obj.enabled = true

	// if _, exists := manager.systems_by_name[name]; exists {
	// 	core.LogWarningFmt("[ECS] System with name '%s' already exists. Overwriting (or choose to prevent).", name)
	// 	// Handle replacement if necessary, for now just appends
	// }
	
	append(&manager.systems, system_obj)
	// manager.systems_by_name[system_obj.name] = system_obj // If using name map
}

// RunSystems executes the update procedure for all registered systems.
// Systems are run in the order they were added.
RunSystems :: proc(manager: ^SystemManager, world: ^World, dt: f32) {
	if manager == nil {
		core.LogError("[ECS] RunSystems: Called with nil manager.")
		return
	}
	if world == nil {
		core.LogError("[ECS] RunSystems: Called with nil world.")
		return
	}

	// core.LogInfoFmt("[ECS] Running %d systems...", len(manager.systems)) // Can be verbose
	for system in manager.systems {
		// if system.enabled { // If we add an enabled flag
		// start_time := time.tick_now() // For system profiling
		system.update_proc(world, dt)
		// duration := time.tick_since(start_time)
		// core.LogInfoFmt("[ECS] System %s took %v", system.name, duration) // Verbose
		// }
	}
}
