package core

import "core:time"

// Game_Time provides timing information for the game loop.
// This is passed to the Update and Draw callbacks.
Game_Time :: struct {
    elapsed_game_time: time.Duration, // Time since last Update call
    total_game_time:   time.Duration, // Total time since game start
    is_running_slowly: bool,          // True if the Update loop is taking longer than target_elapsed_time in fixed time step mode
}
