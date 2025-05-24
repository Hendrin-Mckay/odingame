package graphics.api

// Import the new interface parts.
// Odin's import system allows direct use of exported names from imported packages.
// We'll need to ensure these packages are correctly imported where Gfx_Api_Composed is used.
import . "device_management"
import . "window_management"
import . "resource_creation"
import . "resource_management"
import . "drawing_commands"
import . "state_setting"
import . "utilities"

// Gfx_Api_Composed is the new central structure holding all graphics capabilities,
// broken down into logical groups.
// Backends will populate instances of these smaller interface structs.
Gfx_Api_Composed :: struct {
	// Using the interface structs directly as they primarily consist of procedure pointers.
	// If these interfaces were to hold state, pointers might be more appropriate.
	// For now, direct embedding is simpler.
	device_management: Device_Management_Interface,
	window_management: Window_Management_Interface,
	resource_creation: Resource_Creation_Interface,
	resource_management: Resource_Management_Interface,
	drawing_commands: Drawing_Commands_Interface,
	state_setting: State_Setting_Interface,
	utilities: Utilities_Interface,
}

// The global instance gfx_api will be of this type.
// It needs to be declared in a package that both the backends (to populate it)
// and the engine core (to use it) can access.
// This might be in the parent 'graphics' package or here.
// For now, this file defines the structure. The instance declaration
// will be handled in the next step (modifying gfx_interface.odin).

// Example of how a backend might initialize this (conceptual):
// import graphics_api "path/to/odingame/graphics/api"
// import opengl_impl "path/to/backend/opengl"
//
// init_gfx_system :: proc() {
//     graphics.gfx_api = graphics_api.Gfx_Api_Composed {
//         device_management = opengl_impl.get_device_management_impl(),
//         window_management = opengl_impl.get_window_management_impl(),
//         // ... and so on for all other interfaces
//     }
// }
