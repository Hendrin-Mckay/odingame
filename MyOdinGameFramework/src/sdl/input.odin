package sdl

import "src:core" // For logging, if needed for debug messages

// Assuming SDL_Event, SDL_PollEvent, SDL_SCANCODE_*, SDL_NUM_SCANCODES, SDL_EVENT_*, etc.
// are accessible from the sdl package context (e.g., defined in sdl_context.odin).

MAX_MOUSE_BUTTONS :: 5 // Support for up to 5 mouse buttons (Left, Middle, Right, X1, X2)

InputState :: struct {
	// Keyboard state
	prev_key_state: [SDL_NUM_SCANCODES]bool, // Previous frame's state
	key_state:      [SDL_NUM_SCANCODES]bool, // Current frame's state

	// Mouse state
	prev_mouse_buttons: [MAX_MOUSE_BUTTONS]bool,
	mouse_buttons:      [MAX_MOUSE_BUTTONS]bool,
	mouse_x, mouse_y:   i32,
	mouse_x_rel, mouse_y_rel: i32, // Relative motion since last frame
	// scroll_x_rel, scroll_y_rel: i32, // For mouse wheel, if SDL_MouseWheelEvent is handled

	quit_requested: bool,
}

// Global input state instance (or pass ^InputState around if preferred)
// For simplicity in an immediate mode UI or global access:
g_input_state: InputState 

// InitInputState initializes the input state. Call once at startup.
InitInputState :: proc() {
	core.LogInfo("[Input] Initializing input state.")
	// All boolean arrays default to false, which is correct initial state.
	// mouse_x, mouse_y can be initialized by first mouse motion event.
	g_input_state.quit_requested = false
}

// UpdateInputState should be called at the very beginning of each frame,
// before ProcessEvents. It copies current states to previous states.
UpdateInputState :: proc() {
	g_input_state.prev_key_state = g_input_state.key_state // Copy current to previous
	g_input_state.prev_mouse_buttons = g_input_state.mouse_buttons

	// Reset relative motion for mouse
	g_input_state.mouse_x_rel = 0
	g_input_state.mouse_y_rel = 0
	// g_input_state.scroll_x_rel = 0
	// g_input_state.scroll_y_rel = 0
}

// ProcessEvents polls and processes all pending SDL events, updating the g_input_state.
// Returns true if quit was requested, false otherwise.
ProcessEvents :: proc() -> bool {
	event: SDL_Event

	for SDL_PollEvent(&event) != 0 {
		#partial switch event.type {
		case SDL_EVENT_QUIT:
			core.LogInfo("[Input] SDL_EVENT_QUIT received.")
			g_input_state.quit_requested = true
		
		case SDL_EVENT_KEY_DOWN:
			scancode := event.key.scancode
			if scancode >= 0 && scancode < SDL_NUM_SCANCODES {
				g_input_state.key_state[scancode] = true
				// core.LogInfoFmt("[Input] Key down: %d", scancode) // Debug
			}
		
		case SDL_EVENT_KEY_UP:
			scancode := event.key.scancode
			if scancode >= 0 && scancode < SDL_NUM_SCANCODES {
				g_input_state.key_state[scancode] = false
				// core.LogInfoFmt("[Input] Key up: %d", scancode) // Debug
			}

		case SDL_EVENT_MOUSE_MOTION:
			g_input_state.mouse_x = event.motion.x
			g_input_state.mouse_y = event.motion.y
			g_input_state.mouse_x_rel = event.motion.xrel
			g_input_state.mouse_y_rel = event.motion.yrel
			// core.LogInfoFmt("[Input] Mouse motion: %d, %d (Rel: %d, %d)", event.motion.x, event.motion.y, event.motion.xrel, event.motion.yrel) // Debug

		case SDL_EVENT_MOUSE_BUTTON_DOWN:
			button_idx := event.button.button
			// SDL mouse buttons are 1-indexed (SDL_BUTTON_LEFT=1, etc.)
			// Map to 0-indexed array.
			if button_idx > 0 && button_idx < auto_cast MAX_MOUSE_BUTTONS + 1 {
				g_input_state.mouse_buttons[button_idx-1] = true
				// core.LogInfoFmt("[Input] Mouse button down: %d", button_idx) // Debug
			}

		case SDL_EVENT_MOUSE_BUTTON_UP:
			button_idx := event.button.button
			if button_idx > 0 && button_idx < auto_cast MAX_MOUSE_BUTTONS + 1 {
				g_input_state.mouse_buttons[button_idx-1] = false
				// core.LogInfoFmt("[Input] Mouse button up: %d", button_idx) // Debug
			}
		
		// case SDL_EVENT_MOUSE_WHEEL: // Example for later
			// g_input_state.scroll_x_rel = event.wheel.x
			// g_input_state.scroll_y_rel = event.wheel.y
			// core.LogInfoFmt("[Input] Mouse wheel: x %d, y %d", event.wheel.x, event.wheel.y)


		// default:
			// core.LogInfoFmt("[Input] Unhandled Event type: %#x", event.type) // Debug
		}
	}
	return g_input_state.quit_requested
}

// --- Keyboard state accessors ---
IsKeyDown :: proc(scancode: i32) -> bool {
	if scancode < 0 || scancode >= SDL_NUM_SCANCODES { return false }
	return g_input_state.key_state[scancode]
}

IsKeyPressed :: proc(scancode: i32) -> bool { // Pressed this frame
	if scancode < 0 || scancode >= SDL_NUM_SCANCODES { return false }
	return g_input_state.key_state[scancode] && !g_input_state.prev_key_state[scancode]
}

IsKeyReleased :: proc(scancode: i32) -> bool { // Released this frame
	if scancode < 0 || scancode >= SDL_NUM_SCANCODES { return false }
	return !g_input_state.key_state[scancode] && g_input_state.prev_key_state[scancode]
}

// --- Mouse state accessors ---
GetMousePosition :: proc() -> (i32, i32) {
	return g_input_state.mouse_x, g_input_state.mouse_y
}

GetMouseRelativeMotion :: proc() -> (i32, i32) {
	return g_input_state.mouse_x_rel, g_input_state.mouse_y_rel
}

IsMouseButtonDown :: proc(button: u8) -> bool { // button is 0 for Left, 1 for Middle, 2 for Right, etc.
	if button >= MAX_MOUSE_BUTTONS { return false }
	return g_input_state.mouse_buttons[button]
}

IsMouseButtonPressed :: proc(button: u8) -> bool { // Pressed this frame
	if button >= MAX_MOUSE_BUTTONS { return false }
	return g_input_state.mouse_buttons[button] && !g_input_state.prev_mouse_buttons[button]
}

IsMouseButtonReleased :: proc(button: u8) -> bool { // Released this frame
	if button >= MAX_MOUSE_BUTTONS { return false }
	return !g_input_state.mouse_buttons[button] && g_input_state.prev_mouse_buttons[button]
}
