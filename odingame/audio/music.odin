package audio

import sdl "vendor:sdl2"
import mix "vendor:sdl2/mixer"
import "core:log"
import "core:fmt"
import "core:strings" // For strings.clone_to_cstring

// load_music loads a music track from a file (e.g., MP3, OGG, WAV).
// Returns Maybe(Music).ok = true on success.
load_music :: proc(filepath: string) -> MaybeMusic {
	if filepath == "" {
		log.error("load_music: Filepath is empty.")
		return MaybeMusic{}
	}

	filepath_cstr := strings.clone_to_cstring(filepath)
	defer delete(filepath_cstr)

	// Open the file using SDL_RWops
	rw_ops := sdl.RWFromFile(filepath_cstr, "rb")
	if rw_ops == nil {
		log.errorf("load_music: SDL_RWFromFile failed for '%s'. SDL Error: %s", filepath, sdl.GetError())
		return MaybeMusic{}
	}
	
	// Mix_LoadMUSType_RW can take a type, or use Mix_LoadMUS_RW which tries to autodetect.
	// For simplicity, assuming Mix_LoadMUS_RW exists and works.
	// The `free_src` parameter (last one) determines if rw_ops is closed after load.
	// Set to 1 (true) to have SDL_mixer close it.
	music_ptr := mix.LoadMUS_RW(rw_ops, 1) // 1 means SDL_mixer will free/close rw_ops

	if music_ptr == nil {
		log.errorf("load_music: Mix_LoadMUS_RW failed for '%s'. Mixer Error: %s", filepath, mix.GetError())
		return MaybeMusic{}
	}

	log.infof("Music loaded successfully from '%s'. Handle: %p", filepath, music_ptr)
	return MaybeMusic{Music(music_ptr), true}
}

// destroy_music frees a loaded music track.
destroy_music :: proc(music_track: Music) {
	if music_track == Music(nil) {
		log.warn("destroy_music: Attempted to free a nil Music track.")
		return
	}
	music_ptr := mix.Music_Handle(music_track)
	mix.FreeMusic(music_ptr)
	log.infof("Music track freed. Handle: %p", music_ptr)
}

// play_music plays a loaded music track.
//   music_track: The music to play.
//   loops: Number of times to repeat the track. 
//          -1 means loop indefinitely. 0 or 1 means play once (SDL_mixer treats 0 as 1 for PlayMusic).
//          To play N times, pass N. (Mix_PlayMusic(mus, N-1) for N total plays if N > 0)
//          The interface asks for `loops: int = -1`. If loops is 0, play once. If 1, play twice.
//          Mix_PlayMusic: pass 0 for 1 play, 1 for 2 plays, N-1 for N plays. -1 for infinite.
//          So, if user passes loops=0 (play once), we should pass 0 to Mix_PlayMusic.
//          If user passes loops=1 (play twice), we should pass 1 to Mix_PlayMusic.
//          If user passes loops=N (play N+1 times), we should pass N to Mix_PlayMusic.
//          The subtask says "loops: int = -1". Let's clarify:
//          If loops = 0 means "play once", then Mix_PlayMusic(track, 0).
//          If loops = 1 means "play once then repeat once (total 2 plays)", then Mix_PlayMusic(track, 1).
//          If loops = -1 means "loop infinitely", then Mix_PlayMusic(track, -1).
//          Common interpretation: loops=0 play once, loops=1 play once and repeat once, etc.
//          Let's map `loops` directly to `Mix_PlayMusic` `loops` param, where -1 is infinite.
//          The documentation for Mix_PlayMusic says "number of times to play through the music. If loops is -1, loop indefinitely."
//          It also mentions "passing 0 will play the music zero times... better to use Halt Music". This is unusual.
//          Most APIs treat loops=0 as "play once".
//          Let's assume standard: loops=0 -> play once. loops=1 -> repeat once (play twice total).
//          SDL_mixer: loops=0 plays once, loops=1 plays twice, loops=-1 infinite. This matches!
play_music :: proc(music_track: Music, loops := -1) -> bool {
	if music_track == Music(nil) {
		log.error("play_music: Cannot play a nil Music track.")
		return false
	}
	music_ptr := mix.Music_Handle(music_track)

	// Mix_FadeInMusic can be used for smooth transitions if desired later.
	// For now, direct play.
	if mix.PlayMusic(music_ptr, loops) == -1 { // Returns 0 on success, -1 on error.
		log.errorf("play_music: Mix_PlayMusic failed for track %p. Mixer Error: %s", music_ptr, mix.GetError())
		return false
	}
	log.infof("Music track %p started (loops: %d).", music_ptr, loops)
	return true
}

// pause_music pauses the currently playing music.
pause_music :: proc() {
	if mix.PlayingMusic() == 1 { // Check if music is actually playing
		mix.PauseMusic()
		log.info("Music paused.")
	} else {
		log.debug("pause_music: No music was playing or music already paused.")
	}
}

// resume_music resumes paused music.
resume_music :: proc() {
	if mix.PausedMusic() == 1 { // Check if music is paused
		mix.ResumeMusic()
		log.info("Music resumed.")
	} else {
		log.debug("resume_music: Music was not paused.")
	}
}

// stop_music stops the currently playing music.
stop_music :: proc() {
	// Mix_HaltMusic is usually preferred as it stops immediately.
	// Mix_FadeOutMusic(ms) can be used for smooth fade-out.
	if mix.PlayingMusic() == 1 || mix.PausedMusic() == 1 {
		mix.HaltMusic()
		log.info("Music stopped (halted).")
	} else {
		log.debug("stop_music: No music was playing or paused to stop.")
	}
}

// set_music_volume sets the volume for music playback.
//   volume: Volume from 0 (silent) to 128 (MIX_MAX_VOLUME).
// Returns the previous volume setting.
set_music_volume :: proc(volume: i32) -> i32 {
	actual_volume := volume
	if actual_volume < 0 { actual_volume = 0 }
	if actual_volume > mix.MAX_VOLUME { actual_volume = mix.MAX_VOLUME }

	// Mix_VolumeMusic returns the old volume.
	old_volume := mix.VolumeMusic(actual_volume)
	log.infof("Music volume set to %d. Old volume was %d.", actual_volume, old_volume)
	return old_volume
}

// is_music_playing checks if music is currently playing (not paused).
is_music_playing :: proc() -> bool {
	// Mix_PlayingMusic returns 1 if music is actively playing, 0 otherwise.
	// It returns 0 if music is paused.
	return mix.PlayingMusic() == 1
}

// is_music_paused checks if music is currently paused.
is_music_paused :: proc() -> bool {
	// Mix_PausedMusic returns 1 if music is paused, 0 otherwise.
	return mix.PausedMusic() == 1
}
