package core

// This file previously defined the core.Window struct and its associated procedures.
// These have been moved to `odingame/graphics/window.odin` and the struct renamed to `Game_Window`.
// This file now provides a type alias for backward compatibility or for core systems
// that conceptually work with a "Window" type without needing to know it's graphics.Game_Window.

import graphics "../graphics" // Import the graphics package where Game_Window is now defined.

// Window is now an alias to graphics.Game_Window.
// Code using core.Window will now refer to graphics.Game_Window.
Window :: graphics.Game_Window

// Accessor functions like get_window_width, get_window_height, etc.,
// that were previously here, have been removed.
// They will be added as methods to graphics.Game_Window in a subsequent step.
// Procedures like new_window, destroy_window, set_title have also been moved to
// the graphics package and operate on graphics.Game_Window.
// Calls to core.new_window() should be updated to graphics.new_window().
// Calls to core.destroy_window() should be updated to graphics.destroy_window().
// Calls to core.set_title() should be updated to graphics.set_title().
