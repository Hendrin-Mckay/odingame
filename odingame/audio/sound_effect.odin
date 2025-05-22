package audio

import sdl "vendor:sdl2"
import mix "vendor:sdl2/mixer"
import "core:log"
import "core:fmt"
import "core:strings" // For strings.clone_to_cstring

// load_sound_effect loads a sound effect from a WAV file.
// Returns Maybe(SoundEffect).ok = true on success.
load_sound_effect :: proc(filepath: string) -> MaybeSoundEffect {
	if filepath == "" {
		log.error("load_sound_effect: Filepath is empty.")
		return MaybeSoundEffect{}
	}

	filepath_cstr := strings.clone_to_cstring(filepath)
	defer delete(filepath_cstr)

	// Open the file using SDL_RWops for more robust file handling.
	// "rb" for read binary mode.
	rw_ops := sdl.RWFromFile(filepath_cstr, "rb")
	if rw_ops == nil {
		log.errorf("load_sound_effect: SDL_RWFromFile failed for '%s'. SDL Error: %s", filepath, sdl.GetError())
		return MaybeSoundEffect{}
	}
	// Note: SDL_mixer's Mix_LoadWAV_RW will automatically free the rw_ops if `autofree` is true (1).
	// The `free_src` parameter of `Mix_LoadWAV_RW` (last param) determines if rw_ops is closed after load.
	// Set to 1 (true) to have SDL_mixer close it.
	
	// chunk := mix.LoadWAV(filepath_cstr) // Simpler, but less control
	chunk_ptr := mix.LoadWAV_RW(rw_ops, 1) // 1 means SDL_mixer will free/close rw_ops

	if chunk_ptr == nil {
		log.errorf("load_sound_effect: Mix_LoadWAV_RW failed for '%s'. Mixer Error: %s", filepath, mix.GetError())
		// rw_ops would have been freed by Mix_LoadWAV_RW if the call was made, even on failure, if `free_src` was 1.
		// If `free_src` was 0, we would need to call `sdl.FreeRW(rw_ops)` here.
		return MaybeSoundEffect{}
	}

	log.infof("SoundEffect loaded successfully from '%s'. Handle: %p", filepath, chunk_ptr)
	return MaybeSoundEffect{SoundEffect(chunk_ptr), true}
}

// destroy_sound_effect frees a loaded sound effect.
destroy_sound_effect :: proc(effect: SoundEffect) {
	if effect == SoundEffect(nil) {
		log.warn("destroy_sound_effect: Attempted to free a nil SoundEffect.")
		return
	}
	// Convert SoundEffect (distinct rawptr) back to mix.Chunk_Handle (^mix.Chunk)
	chunk_ptr := mix.Chunk_Handle(effect) 
	mix.FreeChunk(chunk_ptr)
	log.infof("SoundEffect freed. Handle: %p", chunk_ptr)
}

// play_sound_effect plays a loaded sound effect.
//   effect: The sound effect to play.
//   loops: Number of times to loop (0 means play once, 1 means play twice, etc.).
//          Use -1 for infinite looping (though less common for sound effects).
//   channel: Specific channel to play on (-1 for first available channel).
// Returns the channel the sound was played on, or -1 if it could not be played.
play_sound_effect :: proc(effect: SoundEffect, loops := 0, channel := -1) -> (played_channel: i32) {
	if effect == SoundEffect(nil) {
		log.error("play_sound_effect: Cannot play a nil SoundEffect.")
		return -1
	}
	chunk_ptr := mix.Chunk_Handle(effect)
	
	played_on_channel := mix.PlayChannel(channel, chunk_ptr, loops)
	
	if played_on_channel == -1 {
		log.errorf("play_sound_effect: Mix_PlayChannel failed for effect %p. Mixer Error: %s", chunk_ptr, mix.GetError())
	} else {
		log.debugf("SoundEffect %p played on channel %d (loops: %d).", chunk_ptr, played_on_channel, loops)
	}
	return played_on_channel
}

// set_channel_volume sets the volume for a specific mixer channel.
//   channel: The channel number (-1 is not valid here, must be a specific channel).
//   volume: Volume from 0 (silent) to 128 (MIX_MAX_VOLUME).
// Returns the old volume of the channel, or -1 if channel is invalid.
set_channel_volume :: proc(channel: i32, volume: i32) -> i32 {
	if channel < 0 { // mix.Volume treats -1 as all channels, but here we want specific channel.
		log.errorf("set_channel_volume: Invalid channel number %d. Must be 0 or greater.", channel)
		return -1
	}
	// Clamp volume to SDL_mixer's range [0, MIX_MAX_VOLUME (128)]
	actual_volume := volume
	if actual_volume < 0 { actual_volume = 0 }
	if actual_volume > mix.MAX_VOLUME { actual_volume = mix.MAX_VOLUME } // mix.MAX_VOLUME is typically 128

	old_volume := mix.Volume(channel, actual_volume)
	// mix.Volume returns the old volume of the channel. If channel is out of range, it might return -1,
	// but the documentation isn't explicit about return on invalid channel for volume setting.
	// It's safer to check channel validity beforehand if possible (e.g. against mix.AllocateChannels).
	log.debugf("Volume for channel %d set to %d. Old volume was %d.", channel, actual_volume, old_volume)
	return old_volume
}

// set_master_sound_volume sets the volume for all sound effect channels.
//   volume: Volume from 0 (silent) to 128 (MIX_MAX_VOLUME).
// Returns the average of the old volumes of all channels (or a representative value based on Mix_Volume(-1, vol)).
set_master_sound_volume :: proc(volume: i32) -> i32 {
	// Clamp volume
	actual_volume := volume
	if actual_volume < 0 { actual_volume = 0 }
	if actual_volume > mix.MAX_VOLUME { actual_volume = mix.MAX_VOLUME }

	// Mix_Volume with channel -1 sets volume for all channels.
	// It returns the average of their PREVIOUS volumes.
	avg_old_volume := mix.Volume(-1, actual_volume)
	log.infof("Master sound volume set to %d. Average old volume was %d.", actual_volume, avg_old_volume)
	return avg_old_volume
}

// --- Other Sound Effect Channel Controls (Examples) ---

// pause_channel pauses a specific channel.
pause_channel :: proc(channel: i32) {
	if channel < 0 { 
		log.warn("pause_channel: Cannot pause channel -1 (all channels). Use pause_all_channels or specific channel.")
		return 
	}
	mix.Pause(channel)
	log.debugf("Channel %d paused.", channel)
}

// resume_channel resumes a paused channel.
resume_channel :: proc(channel: i32) {
	if channel < 0 { 
		log.warn("resume_channel: Cannot resume channel -1 (all channels). Use resume_all_channels or specific channel.")
		return 
	}
	mix.Resume(channel)
	log.debugf("Channel %d resumed.", channel)
}

// stop_channel stops playback on a specific channel.
stop_channel :: proc(channel: i32) {
	if channel < 0 { 
		log.warn("stop_channel: Cannot stop channel -1 (all channels). Use stop_all_channels or specific channel.")
		return 
	}
	mix.HaltChannel(channel) // 0 means no fade out
	log.debugf("Channel %d halted.", channel)
}

// stop_all_channels stops playback on all sound effect channels.
stop_all_channels :: proc() {
	mix.HaltChannel(-1) // Halt all channels
	log.info("All sound effect channels halted.")
}

// set_channel_panning sets the panning for a specific channel.
//   channel: The channel to set panning for.
//   left_volume: Volume for the left speaker (0-255).
//   right_volume: Volume for the right speaker (0-255).
// Returns true on success, false on failure (e.g. channel invalid, panning not supported).
set_channel_panning :: proc(channel: i32, left_volume: u8, right_volume: u8) -> bool {
	if channel < 0 {
		log.errorf("set_channel_panning: Invalid channel %d.", channel)
		return false
	}
	if mix.SetPanning(channel, left_volume, right_volume) == 0 { // 0 is error for SetPanning
		log.errorf("set_channel_panning: Mix_SetPanning failed for channel %d. Mixer Error: %s", channel, mix.GetError())
		return false
	}
	log.debugf("Channel %d panned: Left=%d, Right=%d.", channel, left_volume, right_volume)
	return true
}
