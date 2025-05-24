package audio

import "core:log"
import "core:mem"
import "core:math" // For clamp, sin, cos if needed for pan
import mix "core:sdl/mixer" 
// Assuming audio_types.odin is in the same package or types are globally accessible
// import . "./audio_types" 

Sound_Effect_Instance :: struct {
    sound_effect: ^Sound_Effect, // Reference to the parent Sound_Effect
    state:        Sound_State,
    volume:       f32, // 0.0 (silent) to 1.0 (full)
    pitch:        f32, // -1.0 (down one octave) to 0.0 (normal) to 1.0 (up one octave). Not directly supported by SDL_mixer.
    pan:          f32, // -1.0 (full left) to 0.0 (center) to 1.0 (full right).
    is_looped:    bool,
    
    _channel:     i32, // SDL_mixer channel this instance is playing on, -1 if not playing.
    allocator:    mem.Allocator,
    // _audio_engine_ref: ^Audio_Engine, // Optional: reference to the audio engine for master volume
}

// --- Constructor and Destructor ---

sound_effect_create_instance :: proc(
    effect: ^Sound_Effect, 
    // audio_engine: ^Audio_Engine, // To get master volume
    alloc: mem.Allocator = context.allocator,
) -> ^Sound_Effect_Instance {
    if effect == nil {
        log.error("sound_effect_create_instance: Provided Sound_Effect is nil.")
        return nil
    }

    instance := new(Sound_Effect_Instance, alloc)
    instance.sound_effect = effect
    instance.state = .Stopped
    instance.volume = 1.0
    instance.pitch = 0.0 // Normal pitch
    instance.pan = 0.0   // Centered
    instance.is_looped = false
    instance._channel = -1 // Not playing on any channel initially
    instance.allocator = alloc
    // instance._audio_engine_ref = audio_engine

    // log.debugf("Sound_Effect_Instance created for Sound_Effect: '%s'", effect.name)
    return instance
}

sound_effect_instance_destroy :: proc(instance: ^Sound_Effect_Instance) {
    if instance == nil {
        return
    }
    // Ensure the sound is stopped if it's playing on a channel
    if instance._channel != -1 {
        mix.HaltChannel(instance._channel)
        instance._channel = -1 
    }
    // The Sound_Effect itself is not destroyed here, as it might be shared.
    // log.debugf("Sound_Effect_Instance destroyed for Sound_Effect: '%s'", instance.sound_effect.name)
    free(instance, instance.allocator)
}

// --- Playback Control ---

sound_effect_instance_play :: proc(instance: ^Sound_Effect_Instance) -> bool {
    if instance == nil || instance.sound_effect == nil || instance.sound_effect._chunk == nil {
        log.error("sound_effect_instance_play: Instance or Sound_Effect or its chunk is nil.")
        return false
    }

    // If already playing on a channel, stop it first to restart or apply changes.
    // XNA behavior: If Play is called on a playing instance, it restarts.
    if instance._channel != -1 && mix.Playing(instance._channel) != 0 {
        mix.HaltChannel(instance._channel) 
    }

    loops := 0
    if instance.is_looped {
        loops = -1 // SDL_mixer: -1 means loop indefinitely
    }

    // Play on the first free unreserved channel.
    // Passing -1 for channel tells SDL_mixer to find an available channel.
    instance._channel = mix.PlayChannel(-1, instance.sound_effect._chunk, loops)

    if instance._channel == -1 {
        log.errorf("sound_effect_instance_play: Failed to play Sound_Effect '%s'. No free channels or error. SDL_mixer Error: %s", 
                  instance.sound_effect.name, mix.GetError())
        instance.state = .Stopped
        return false
    }

    // Apply volume and pan
    sound_effect_instance_set_volume(instance, instance.volume) // Applies combined volume
    sound_effect_instance_set_pan(instance, instance.pan)
    // Pitch is not directly supported by SDL_mixer per channel. Effects might be used.

    instance.state = .Playing
    // log.debugf("Sound_Effect_Instance playing '%s' on channel %d", instance.sound_effect.name, instance._channel)
    return true
}

sound_effect_instance_pause :: proc(instance: ^Sound_Effect_Instance) {
    if instance == nil || instance._channel == -1 {
        return
    }
    if instance.state == .Playing {
        mix.Pause(instance._channel)
        instance.state = .Paused
        // log.debugf("Sound_Effect_Instance paused '%s' on channel %d", instance.sound_effect.name, instance._channel)
    }
}

sound_effect_instance_resume :: proc(instance: ^Sound_Effect_Instance) {
    if instance == nil || instance._channel == -1 {
        return
    }
    if instance.state == .Paused {
        mix.Resume(instance._channel)
        instance.state = .Playing
        // log.debugf("Sound_Effect_Instance resumed '%s' on channel %d", instance.sound_effect.name, instance._channel)
    }
}

sound_effect_instance_stop :: proc(instance: ^Sound_Effect_Instance, immediate: bool = true) {
    // `immediate` parameter is for XNA compatibility (FadeOut not implemented here).
    // SDL_mixer's HaltChannel is always immediate.
    if instance == nil || instance._channel == -1 {
        return
    }
    mix.HaltChannel(instance._channel)
    instance.state = .Stopped
    instance._channel = -1 // Mark channel as free for this instance
    // log.debugf("Sound_Effect_Instance stopped '%s' (was on channel %d)", instance.sound_effect.name, temp_channel_for_log)
}

// --- Property Setters ---

sound_effect_instance_set_volume :: proc(instance: ^Sound_Effect_Instance, volume: f32) {
    if instance == nil { return }
    
    instance.volume = math.clamp(volume, 0.0, 1.0)
    
    if instance._channel != -1 {
        // TODO: Combine with Audio_Engine.master_volume if available
        // master_vol := instance._audio_engine_ref != nil ? instance._audio_engine_ref.master_volume : 1.0
        master_vol := f32(1.0) // Placeholder for now
        
        final_volume_f32 := instance.volume * master_vol
        sdl_volume := i32(math.clamp(final_volume_f32, 0.0, 1.0) * f32(mix.MAX_VOLUME)) // mix.MAX_VOLUME is 128
        
        mix.Volume(instance._channel, sdl_volume)
    }
}

sound_effect_instance_set_pan :: proc(instance: ^Sound_Effect_Instance, pan: f32) {
    if instance == nil { return }

    instance.pan = math.clamp(pan, -1.0, 1.0)

    if instance._channel != -1 {
        // SDL_mixer SetPanning: left (0-255), right (0-255)
        // pan = -1.0 (full left), 0.0 (center), 1.0 (full right)
        
        left_vol_f: f32
        right_vol_f: f32

        if instance.pan <= 0 { // Center to Full Left
            left_vol_f = 1.0
            right_vol_f = 1.0 + instance.pan // pan is negative or zero, so this ranges from 0.0 to 1.0
        } else { // Center to Full Right
            left_vol_f = 1.0 - instance.pan // pan is positive, so this ranges from 0.0 to 1.0
            right_vol_f = 1.0
        }
        
        left_sdl := u8(math.clamp(left_vol_f, 0.0, 1.0) * 255)
        right_sdl := u8(math.clamp(right_vol_f, 0.0, 1.0) * 255)

        if mix.SetPanning(instance._channel, left_sdl, right_sdl) == 0 { // Returns 0 on error
            log.errorf("sound_effect_instance_set_pan: mix.SetPanning failed for channel %d. SDL_mixer Error: %s", 
                      instance._channel, mix.GetError())
        }
    }
}

sound_effect_instance_set_pitch :: proc(instance: ^Sound_Effect_Instance, pitch: f32) {
    if instance == nil { return }
    // XNA pitch: -1.0 (one octave down) to 1.0 (one octave up). 0.0 is normal.
    // SDL_mixer does not have direct per-channel pitch control like XNA.
    // This would require using sound effects processors or resampling the chunk.
    // For now, this is a stub.
    instance.pitch = math.clamp(pitch, -1.0, 1.0)
    if instance.pitch != 0.0 {
        log.warn("sound_effect_instance_set_pitch: Pitch shifting is not directly supported by SDL_mixer backend. Value stored but not applied.")
    }
}

sound_effect_instance_set_is_looped :: proc(instance: ^Sound_Effect_Instance, looped: bool) {
    if instance == nil { return }
    instance.is_looped = looped
    // If currently playing, the loop change might not take effect until next Play call
    // or requires more complex SDL_mixer handling (e.g., re-queueing or using channel finished callback).
    // For simplicity, loop state is applied when Play is called.
    if instance.state == .Playing && instance._channel != -1 {
        log.debug("sound_effect_instance_set_is_looped: Loop state changed while playing. May require re-play to take full effect for current sound.")
        // To make it take effect immediately for current sound, one might need to:
        // 1. Stop the current sound.
        // 2. Re-play it with the new loop setting.
        // This can cause a slight interruption.
        // For now, it will apply on the next explicit Play() call.
    }
}

// --- Fire-and-Forget Playback ---

// sound_effect_play plays a Sound_Effect once without creating a managed instance.
// This is for simple, non-controlled sound effects.
// Returns true if played successfully, false otherwise.
sound_effect_play :: proc(
    effect: ^Sound_Effect, 
    volume: f32 = 1.0, 
    pitch: f32 = 0.0, // Ignored for now
    pan: f32 = 0.0,
    // audio_engine: ^Audio_Engine, // Needed for master volume
) -> bool {
    if effect == nil || effect._chunk == nil {
        log.error("sound_effect_play: Sound_Effect or its chunk is nil.")
        return false
    }

    channel := mix.PlayChannel(-1, effect._chunk, 0) // Play once (loops = 0)
    if channel == -1 {
        log.errorf("sound_effect_play: Failed to play Sound_Effect '%s'. No free channels or error. SDL_mixer Error: %s", 
                  effect.name, mix.GetError())
        return false
    }

    // Apply volume (combining with master volume if AudioEngine reference was available)
    // master_vol := audio_engine != nil ? audio_engine.master_volume : 1.0
    master_vol := f32(1.0) // Placeholder, assume full master volume for now
    final_volume_f32 := math.clamp(volume, 0.0, 1.0) * master_vol
    sdl_volume := i32(math.clamp(final_volume_f32, 0.0, 1.0) * f32(mix.MAX_VOLUME))
    mix.Volume(channel, sdl_volume)

    // Apply pan
    pan_clamped := math.clamp(pan, -1.0, 1.0)
    left_vol_f: f32; right_vol_f: f32
    if pan_clamped <= 0 { left_vol_f = 1.0; right_vol_f = 1.0 + pan_clamped; } 
    else { left_vol_f = 1.0 - pan_clamped; right_vol_f = 1.0; }
    mix.SetPanning(channel, u8(left_vol_f * 255), u8(right_vol_f * 255))
    
    // Pitch is ignored for now.
    if pitch != 0.0 {
        log.warn("sound_effect_play: Pitch parameter is ignored in this backend.")
    }

    // log.debugf("Played fire-and-forget Sound_Effect '%s' on channel %d", effect.name, channel)
    return true
}
