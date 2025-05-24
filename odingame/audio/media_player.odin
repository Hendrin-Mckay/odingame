package audio

import "core:log"
import "core:mem"
import "core:math" // For clamp
import mix "core:sdl/mixer"
// Assuming audio_types.odin is in the same package or types are globally accessible
// import . "./audio_types"

Media_Player :: struct {
    state:         Media_State,
    volume:        f32, // 0.0 to 1.0, application-level volume
    is_muted:      bool,
    is_repeating:  bool,
    
    _current_song: ^Song, // Optional: keep track of current song for context
    _actual_sdl_volume_before_mute: i32, // To restore volume when unmuting

    allocator:     mem.Allocator,
}

// --- Constructor and Destructor ---

media_player_new :: proc(alloc: mem.Allocator = context.allocator) -> ^Media_Player {
    player := new(Media_Player, alloc)
    player.allocator = alloc
    player.state = .Stopped
    player.volume = 1.0
    player.is_muted = false
    player.is_repeating = false
    player._current_song = nil
    player._actual_sdl_volume_before_mute = mix.MAX_VOLUME // Default to max SDL volume

    // log.info("MediaPlayer created.")
    return player
}

media_player_destroy :: proc(player: ^Media_Player) {
    if player == nil {
        return
    }
    // Stop any playing music first
    if mix.PlayingMusic() != 0 {
        mix.HaltMusic()
    }
    // _current_song is not owned by MediaPlayer, so it's not freed here.
    // log.info("MediaPlayer destroyed.")
    free(player, player.allocator)
}

// --- Playback Control ---

media_player_play :: proc(player: ^Media_Player, song: ^Song) {
    if player == nil {
        log.error("media_player_play: MediaPlayer instance is nil.")
        return
    }
    if song == nil || song._music == nil {
        log.error("media_player_play: Song or its music data is nil.")
        if player._current_song != nil { // If a song was playing, stop it
            mix.HaltMusic()
            player.state = .Stopped
        }
        player._current_song = nil
        return
    }

    // Stop currently playing music before starting a new one
    if mix.PlayingMusic() != 0 || mix.PausedMusic() != 0 {
        mix.HaltMusic()
    }

    loops := 0
    if player.is_repeating {
        loops = -1 // Loop indefinitely
    }

    if mix.PlayMusic(song._music, loops) == -1 {
        log.errorf("media_player_play: Failed to play song '%s'. SDL_mixer Error: %s", song.name, mix.GetError())
        player.state = .Stopped
        player._current_song = nil
        return
    }
    
    player._current_song = song
    player.state = .Playing
    // Apply current volume/mute settings
    media_player_set_volume(player, player.volume) // This will handle mute as well
    // log.infof("MediaPlayer: Playing song '%s'. Looping: %t", song.name, player.is_repeating)
}

media_player_pause :: proc(player: ^Media_Player) {
    if player == nil { return }
    if mix.PlayingMusic() == 1 && mix.PausedMusic() == 0 { // Only pause if actively playing
        mix.PauseMusic()
        player.state = .Paused
        // log.info("MediaPlayer: Music paused.")
    }
}

media_player_resume :: proc(player: ^Media_Player) {
    if player == nil { return }
    if mix.PausedMusic() == 1 { // Only resume if actually paused
        mix.ResumeMusic()
        player.state = .Playing
        // log.info("MediaPlayer: Music resumed.")
    }
}

media_player_stop :: proc(player: ^Media_Player) {
    if player == nil { return }
    mix.HaltMusic()
    player.state = .Stopped
    player._current_song = nil // Clear current song on stop
    // log.info("MediaPlayer: Music stopped.")
}

// --- Properties ---

media_player_set_volume :: proc(player: ^Media_Player, volume: f32) {
    if player == nil { return }
    
    player.volume = math.clamp(volume, 0.0, 1.0)
    
    actual_play_volume := player.volume
    if player.is_muted {
        actual_play_volume = 0.0
    }
    
    sdl_volume := i32(actual_play_volume * f32(mix.MAX_VOLUME))
    player._actual_sdl_volume_before_mute = sdl_volume // Store this even if muted, for unmute
    
    mix.VolumeMusic(sdl_volume)
    // log.debugf("MediaPlayer: Volume set to %.2f (SDL: %d). Muted: %t", player.volume, sdl_volume, player.is_muted)
}

media_player_get_volume :: proc(player: ^Media_Player) -> f32 {
    if player == nil { return 0.0 }
    return player.volume
}

media_player_set_is_muted :: proc(player: ^Media_Player, muted: bool) {
    if player == nil { return }
    if player.is_muted == muted { return } // No change
    
    player.is_muted = muted
    
    if muted {
        // Store current effective volume before muting, then set SDL volume to 0
        player._actual_sdl_volume_before_mute = mix.VolumeMusic(-1) // Query current music volume
        mix.VolumeMusic(0)
        // log.debug("MediaPlayer: Music muted.")
    } else {
        // Restore volume to pre-mute level (or current player.volume if that's preferred)
        // Using player.volume ensures it reflects the desired app-level volume.
        new_sdl_volume := i32(player.volume * f32(mix.MAX_VOLUME))
        mix.VolumeMusic(new_sdl_volume)
        // log.debugf("MediaPlayer: Music unmuted. Volume restored to %.2f (SDL: %d)", player.volume, new_sdl_volume)
    }
}

media_player_get_is_muted :: proc(player: ^Media_Player) -> bool {
    if player == nil { return false } // Or true, depending on desired default for nil player
    return player.is_muted
}

media_player_set_is_repeating :: proc(player: ^Media_Player, repeating: bool) {
    if player == nil { return }
    player.is_repeating = repeating
    // Note: If a song is currently playing, changing this flag won't affect the current playback's loop status
    // until the song is played again with media_player_play. This matches XNA behavior.
    // log.debugf("MediaPlayer: IsRepeating set to %t.", repeating)
}

media_player_get_is_repeating :: proc(player: ^Media_Player) -> bool {
    if player == nil { return false }
    return player.is_repeating
}

media_player_get_state :: proc(player: ^Media_Player) -> Media_State {
    if player == nil { return .Stopped } // Default if player is nil

    // Update internal state based on SDL_mixer status
    if mix.PlayingMusic() == 1 {
        if mix.PausedMusic() == 1 {
            player.state = .Paused
        } else {
            player.state = .Playing
        }
    } else {
        player.state = .Stopped
        // If it stopped naturally, _current_song might still be set.
        // XNA's behavior: if a song finishes, state becomes Stopped.
        // If user explicitly called Stop, _current_song is cleared.
        // For now, if not playing and not paused, it's stopped.
    }
    return player.state
}

// play_position :: proc(player: ^Media_Player) -> time.Duration { ... } // Needs mix.GetMusicPosition
// current_song :: proc(player: ^Media_Player) -> ^Song { return player._current_song if player != nil else nil }
