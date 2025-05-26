package main

import "src:core"
import "src:sdl"
import "src:ecs"    // Import the ECS package
import "src:game"   // Import the game-specific components and systems

// For delta_time (if not already imported)
import "core:time" 

main :: proc() {
	core.LogInfo("MyOdinGameFramework starting...")

	if !sdl.InitSDL() {
		core.LogErrorAndExit("Failed to initialize SDL. Exiting.")
	}
	defer sdl.ShutdownSDL()
	core.LogInfo("[Main] SDL Initialized.")
	
	sdl.InitInputState() 

	window_obj, ok := sdl.CreateWindow("My Odin Game Framework", 800, 600)
	if !ok {
		core.LogErrorAndExit("[Main] Failed to create window. Exiting.")
	}
	defer sdl.DestroyWindow(window_obj)
	core.LogInfoFmt("[Main] Window '%s' created.", window_obj.title)

	renderer_obj, renderer_ok := sdl.CreateRenderer(sdl.GetSDLWindow(window_obj))
	if !renderer_ok {
		core.LogErrorAndExit("[Main] Failed to create renderer. Exiting.")
	}
	defer sdl.DestroyRenderer(renderer_obj)
	core.LogInfo("[Main] Renderer created.")

	// --- ECS Initialization ---
	core.LogInfo("[Main] Initializing ECS World...")
	ecs_world := ecs.CreateWorld()
	if ecs_world == nil {
		core.LogErrorAndExit("[Main] Failed to create ECS World. Exiting.")
	}
	defer ecs.DestroyWorld(ecs_world) // Ensure world is cleaned up

	// Register components
	core.LogInfo("[Main] Registering components...")
	ecs.RegisterComponent(ecs_world.component_registry, game.PositionComponent)
	ecs.RegisterComponent(ecs_world.component_registry, game.VelocityComponent)

	// Add systems
	core.LogInfo("[Main] Adding systems...")
	ecs.AddSystem(ecs_world.system_manager, game.MovementSystem, "MovementSystem")

	// Create some entities
	core.LogInfo("[Main] Creating entities...")
	num_entities_to_create :: 5
	for i := 0; i < num_entities_to_create; i += 1 {
		entity := ecs.CreateWorldEntity(ecs_world)
		if entity == ecs.ENTITY_NIL {
			core.LogWarningFmt("[Main] Failed to create entity %d", i)
			continue
		}

		// Add components to the entity
		pos_data := game.PositionComponent{x = f32(i) * 10.0, y = f32(i) * 5.0}
		vel_data := game.VelocityComponent{dx = 2.0 + f32(i)*0.5, dy = 1.0 + f32(i)*0.25}
		
		// Pass pointers to component data for AddComponent
		ecs.AddComponent(ecs_world, entity, game.PositionComponent, &pos_data)
		ecs.AddComponent(ecs_world, entity, game.VelocityComponent, &vel_data)
		
		core.LogInfoFmt("[Main] Created Entity %v with Pos(%v,%v) Vel(%v,%v)", entity, pos_data.x, pos_data.y, vel_data.dx, vel_data.dy)
	}


	// Game loop
	is_running := true
	core.LogInfo("[Main] Starting game loop...")

	last_time := time.tick_now()
	current_time: time.Tick
	delta_time: f32

	frame_counter := 0 // For logging positions periodically

	for is_running {
		current_time = time.tick_now()
		delta_time_duration := time.tick_since(last_time)
		delta_time = time.duration_seconds(delta_time_duration)
		last_time = current_time
        // Cap delta_time to avoid large jumps if debugging or system lags
        MAX_DELTA_TIME :: 1.0 / 30.0 // e.g., max step is for 30 FPS
        if delta_time > MAX_DELTA_TIME { delta_time = MAX_DELTA_TIME }


		sdl.UpdateInputState() 
		if sdl.ProcessEvents() { 
			is_running = false
		}

		if sdl.IsKeyPressed(sdl.SDL_SCANCODE_ESCAPE) {
			core.LogInfo("[Main] ESC key pressed. Shutting down.")
			is_running = false
		}
        if sdl.IsMouseButtonPressed(0) { 
            mx, my := sdl.GetMousePosition()
			core.LogInfoFmt("[Main] Left mouse button pressed at: %d, %d", mx, my)
        }

		// --- ECS Update ---
		ecs.RunWorldSystems(ecs_world, delta_time) // Run all systems

		// --- Logging entity positions periodically ---
		frame_counter += 1
		if frame_counter % 120 == 0 { // Log every ~2 seconds if running at 60fps
			core.LogInfoFmt("[Main] Frame %d (dt: %.4fs) - Checking entity positions:", frame_counter, delta_time)
			// Iterate active entities to log their positions
            // (This is a manual iteration for logging, not using QueryEntities here, but could)
            logged_entities_count := 0
			for entity_id, is_active in ecs_world.entity_manager.active_entities {
				if is_active && ecs.HasComponent(ecs_world, entity_id, game.PositionComponent) {
					pos := cast(^game.PositionComponent)ecs.GetComponent(ecs_world, entity_id, game.PositionComponent)
					if pos != nil {
						core.LogInfoFmt("  Entity %v: Pos(%f, %f)", entity_id, pos.x, pos.y)
                        logged_entities_count +=1
					}
				}
                if logged_entities_count >= num_entities_to_create { break } // Only log the ones we made
			}
		}


		// --- Rendering ---
		bg_color := sdl.COLOR_BLUE
		if sdl.IsKeyDown(sdl.SDL_SCANCODE_SPACE) {
			bg_color = sdl.COLOR_GREEN 
		}
		sdl.Clear(renderer_obj, bg_color) 
		// TODO: Add a RenderSystem that would draw entities based on PositionComponent and some SpriteComponent
		sdl.Present(renderer_obj)

		// sdl.SDL_Delay(1) // Yield, PresentVSync should handle pacing if enabled
	}

	core.LogInfo("[Main] Game loop finished. Application closing.")
}
