package main

import "src:core"
import "src:sdl"
import "src:ecs"    // Import the ECS package
import "src:game"   // Import the game-specific components and systems
import "core:time" 
import "src:assets" // Import the new assets package

main :: proc() {
	core.LogInfo("MyOdinGameFramework starting...")

	if !sdl.InitSDL() {
		core.LogErrorAndExit("Failed to initialize SDL. Exiting.")
	}
	defer sdl.ShutdownSDL() // Base SDL
	core.LogInfo("[Main] Base SDL Initialized.")

	if !sdl.InitSDLImage() { // SDL_image
		core.LogErrorAndExit("Failed to initialize SDL_image. Exiting.")
	}
	defer sdl.ShutdownSDLImage() // SDL_image
	core.LogInfo("[Main] SDL_image Initialized.")

	if !sdl.InitSDLMixer() { // SDL_mixer
		core.LogErrorAndExit("Failed to initialize SDL_mixer. Exiting.")
	}
	defer sdl.ShutdownSDLMixer() // SDL_mixer
	core.LogInfo("[Main] SDL_mixer Initialized.")
	
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

	// --- Asset Manager Initialization ---
	core.LogInfo("[Main] Initializing Asset Manager...")
	asset_manager := assets.CreateAssetManager()
	if asset_manager == nil {
		core.LogErrorAndExit("[Main] Failed to create Asset Manager. Exiting.")
	}
	defer assets.DestroyAssetManager(asset_manager) // Ensure assets are cleaned up
	core.LogInfo("[Main] Asset Manager created.")

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
		
		ecs.AddComponent(ecs_world, entity, game.PositionComponent, &pos_data)
		ecs.AddComponent(ecs_world, entity, game.VelocityComponent, &vel_data)
		// core.LogInfoFmt("[Main] Created Entity %v with Pos(%v,%v) Vel(%v,%v)", entity, pos_data.x, pos_data.y, vel_data.dx, vel_data.dy) // Verbose
	}


	// --- Example Asset Loading ---
	core.LogInfo("[Main] Requesting example assets...")
	// Note: Provide actual paths to valid image/sound files for testing on user's machine.
	// These paths are placeholders.
	test_texture_path := "test_data/textures/sample.png" // User needs to create this
	test_sound_path   := "test_data/audio/sfx/sample.wav"    // User needs to create this
    test_music_path   := "test_data/audio/music/sample.ogg"  // User needs to create this

	texture_id := assets.LoadAsset(asset_manager, test_texture_path, .TEXTURE)
	sound_id   := assets.LoadAsset(asset_manager, test_sound_path, .SOUND)
    music_id   := assets.LoadAsset(asset_manager, test_music_path, .MUSIC)

	if texture_id != assets.ASSET_ID_NIL {
		core.LogInfoFmt("[Main] Texture '%s' requested. ID: %v.", test_texture_path, texture_id)
	} else {
		core.LogWarningFmt("[Main] Failed to request texture '%s'.", test_texture_path)
	}
	if sound_id != assets.ASSET_ID_NIL {
		core.LogInfoFmt("[Main] Sound '%s' requested. ID: %v.", test_sound_path, sound_id)
	} else {
		core.LogWarningFmt("[Main] Failed to request sound '%s'.", test_sound_path)
	}
    if music_id != assets.ASSET_ID_NIL {
		core.LogInfoFmt("[Main] Music '%s' requested. ID: %v.", test_music_path, music_id)
	} else {
		core.LogWarningFmt("[Main] Failed to request music '%s'.", test_music_path)
	}
    // Try loading one of them again to test ref counting
    texture_id_2 := assets.LoadAsset(asset_manager, test_texture_path, .TEXTURE)
    if texture_id_2 == texture_id {
        core.LogInfoFmt("[Main] Second request for '%s' returned same ID %v. Ref counting test presumed OK for LoadAsset.", test_texture_path, texture_id_2)
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

		if sdl.IsKeyPressed(sdl.SDL_SCANCODE_ESCAPE) { is_running = false }
        // ... (other input handling) ...

		// --- Asset Manager Update ---
		assets.UpdateAssetManager(asset_manager, renderer_obj) // Pass renderer for texture loading

		// --- ECS Update ---
		ecs.RunWorldSystems(ecs_world, delta_time)

		// --- Logging and Info ---
		frame_counter += 1
		if frame_counter == 10 { // After a few frames, check asset states
			core.LogInfo("[Main] Checking asset states after initial load attempts...")
			if texture_id != assets.ASSET_ID_NIL {
				tex_asset_base, ok := assets.GetAsset(asset_manager, texture_id)
				if ok {
					core.LogInfoFmt("  Texture '%s' (ID: %v) state: %v, ref_count: %d", tex_asset_base.path, texture_id, tex_asset_base.state, tex_asset_base.ref_count)
					if tex_asset_base.state == .LOADED {
                        // Try to get specific and log dimensions
                        tex_specific, spec_ok := assets.GetSpecificAsset(asset_manager, texture_id, assets.TextureAsset)
                        if spec_ok {
                            actual_tex_asset := cast(^assets.TextureAsset)tex_specific
                            core.LogInfoFmt("    Texture specific: Width %d, Height %d", actual_tex_asset.width, actual_tex_asset.height)
                        }
                    }
				} else { core.LogWarningFmt("  Could not get asset info for texture ID %v", texture_id) }
			}
			if sound_id != assets.ASSET_ID_NIL {
				sound_asset_base, ok := assets.GetAsset(asset_manager, sound_id)
				if ok { core.LogInfoFmt("  Sound '%s' (ID: %v) state: %v, ref_count: %d", sound_asset_base.path, sound_id, sound_asset_base.state, sound_asset_base.ref_count) }
                else { core.LogWarningFmt("  Could not get asset info for sound ID %v", sound_id) }
			}
            if music_id != assets.ASSET_ID_NIL {
				music_asset_base, ok := assets.GetAsset(asset_manager, music_id)
				if ok { core.LogInfoFmt("  Music '%s' (ID: %v) state: %v, ref_count: %d", music_asset_base.path, music_id, music_asset_base.state, music_asset_base.ref_count) }
                else { core.LogWarningFmt("  Could not get asset info for music ID %v", music_id) }
            }

            // Example: Unload one of the requests for the texture to test ref_count decrement
            if texture_id_2 != assets.ASSET_ID_NIL { // texture_id_2 is same as texture_id
                core.LogInfoFmt("[Main] Unloading one reference to texture ID %v ('%s')", texture_id_2, test_texture_path)
                assets.UnloadAsset(asset_manager, texture_id_2)
                tex_asset_base_after_unload, _ := assets.GetAsset(asset_manager, texture_id)
                if tex_asset_base_after_unload != nil {
                     core.LogInfoFmt("  After UnloadAsset, texture '%s' ref_count: %d, state: %v", tex_asset_base_after_unload.path, tex_asset_base_after_unload.ref_count, tex_asset_base_after_unload.state)
                }
            }
		}
		// ... (periodic entity position logging) ...

		// --- Rendering ---
		// ... (clear screen, etc.) ...
		sdl.Clear(renderer_obj, sdl.COLOR_BLACK) // Change color to distinguish from prev phase
		sdl.Present(renderer_obj)
	}

	core.LogInfo("[Main] Game loop finished. Application closing.")
}
