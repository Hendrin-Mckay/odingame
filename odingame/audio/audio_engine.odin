package audio

// Import audio_system.odin for init/shutdown
// Assuming audio_system.odin is in the same package 'audio'
// or its functions are made available through an API struct if different.
// For now, assume direct access to init_audio_system and shutdown_audio_system.
import "core:log"
import "core:mem"
import mix "core:sdl/mixer" // For mix.MAX_VOLUME, mix.MasterVolume, mix.VolumeMusic
import "../../common"     // For Engine_Error

Audio_Engine :: struct {
    _initialized: bool,
    master_volume: f32, // Master volume for all sound effects (0.0 to 1.0)
                        // Music volume is handled by MediaPlayer separately in XNA.
                        // For now, this might affect both if a single SDL_mixer control is used.
    allocator: mem.Allocator,
}

audio_engine_initialize :: proc(alloc: mem.Allocator = context.allocator) -> (engine: ^Audio_Engine, err: common.Engine_Error) {
    log.info("Initializing AudioEngine...")

    // Initialize the low-level audio system (SDL_mixer via audio_system.odin)
    // init_audio_system() returns bool, not an error code directly.
    if !init_audio_system() { // Default parameters for frequency, channels, chunk_size
        log.error("AudioEngine: Failed to initialize low-level audio system.")
        return nil, .Audio_System_Init_Failed
    }

    engine = new(Audio_Engine, alloc)
    engine._initialized = true
    engine.master_volume = 1.0 // Default master volume
    engine.allocator = alloc
    
    // Set initial master volume for sound effects channels in SDL_mixer
    // mix.MasterVolume(-1, i32(engine.master_volume * f32(mix.MAX_VOLUME)))
    // This sets volume for all channels. If music also uses channels, it's affected.
    // XNA SoundEffect.MasterVolume is global.
    // Let's assume this is the equivalent of SoundEffect.MasterVolume.
    // Music volume is separate via MediaPlayer.
    // mix.MasterVolume applies to all channels, so it's a true master.
    // However, XNA has SoundEffect.MasterVolume and MediaPlayer.Volume.
    // For now, this will be a global "sound effects" master volume.
    // mix.Volume(-1, i32(engine.master_volume * f32(mix.MAX_VOLUME))) might be more appropriate if -1 means all current sfx channels.
    // Let's use mix.MasterVolume for now as a general setting.
    // The documentation for Mix_MasterVolume says it "Set the master volume for all channels".
    // This is fine for a global SFX volume if music isn't played on specific channels managed this way.
    // Since music uses Mix_PlayMusic, Mix_VolumeMusic is the control for music.
    // So, this master_volume will effectively be for sound effects via channels.
    
    // To reflect XNA's SoundEffect.MasterVolume, we might need to store this
    // and have SoundEffectInstance apply it multiplicatively with its own volume.
    // For now, let's make this a simple global channel volume setting.
    // This is not perfectly XNA-like yet. XNA's SoundEffect.MasterVolume is static.
    // We'll treat this as the initial global volume for channels.
    // Actual per-instance volume will multiply with this.
    // For simplicity, let's assume this call sets a baseline.
    // mix.MasterVolume(i32(engine.master_volume * f32(mix.MAX_VOLUME))) // SDL_mixer v2.0.5+
    // If using older SDL_mixer or simpler binding, this might not exist or work as expected.
    // For now, we will just store the master_volume, and SoundEffectInstance will use it.
    // This engine.master_volume will be the equivalent of SoundEffect.MasterVolume.

    log.info("AudioEngine initialized successfully.")
    return engine, .None
}

audio_engine_destroy :: proc(engine: ^Audio_Engine) {
    if engine == nil {
        return
    }
    log.info("Destroying AudioEngine...")
    if engine._initialized {
        shutdown_audio_system() // Shuts down SDL_mixer
        engine._initialized = false
    }
    free(engine, engine.allocator)
    log.info("AudioEngine destroyed.")
}

audio_engine_update :: proc(engine: ^Audio_Engine) {
    if engine == nil || !engine._initialized {
        return
    }
    // No-op for now.
    // Future: Could handle 3D audio updates, global effects, etc.
}

// audio_engine_set_master_volume sets the global volume for sound effects.
// This maps to XNA's static SoundEffect.MasterVolume.
// Individual SoundEffectInstances will combine this with their own volume.
// Music volume is handled separately by MediaPlayer.
audio_engine_set_master_volume :: proc(engine: ^Audio_Engine, volume: f32) {
    if engine == nil || !engine._initialized {
        return
    }
    
    vol_clamped := volume
    if vol_clamped < 0.0 { vol_clamped = 0.0 }
    if vol_clamped > 1.0 { vol_clamped = 1.0 }
    
    engine.master_volume = vol_clamped
    log.infof("AudioEngine: Master Sound Effect Volume set to %.2f", engine.master_volume)

    // Note: This doesn't directly change SDL_mixer's global channel volumes here.
    // Instead, SoundEffectInstance.Play/SetVolume will read this master_volume
    // and combine it with instance volume to set the actual channel volume via mix.Volume().
    // This approach mirrors XNA's SoundEffect.MasterVolume behavior more closely
    // than using mix.MasterVolume(), which is an immediate global hardware/mixer setting.
}

audio_engine_get_master_volume :: proc(engine: ^Audio_Engine) -> f32 {
    if engine == nil { return 0.0 } // Or a default like 1.0 if engine is nil but code proceeds
    return engine.master_volume
}
