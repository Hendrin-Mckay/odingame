package input

import "vendor:sdl2"

// --- Enums and Structs ---

// Key enum, maps to SDL Scancodes for physical key positions
Key :: sdl2.Scancode // Example: input.Key.A, input.Key.SPACE

// Max number of mouse buttons to track (SDL supports up to 5, typically 0=Left, 1=Middle, 2=Right)
MAX_MOUSE_BUTTONS :: 5 

// Internal state for keyboard and mouse
// These are zero-initialized by default at package level.
_current_keys    : [sdl2.NUM_SCANCODES]bool
_previous_keys   : [sdl2.NUM_SCANCODES]bool
_current_mouse_buttons : [MAX_MOUSE_BUTTONS]bool
_previous_mouse_buttons: [MAX_MOUSE_BUTTONS]bool
_mouse_x         : i32
_mouse_y         : i32
_mouse_scroll_x  : i32 // Scroll delta for the current frame
_mouse_scroll_y  : i32 // Scroll delta for the current frame

_quit_requested  : bool // Flag to signal game exit

// --- Initialization and Update ---

// _init_input_system - called by Game's initialization.
// Ensures event subsystem is active (though core.Game usually handles general SDL_Init).
_init_input_system :: proc() {
	// Ensure SDL event subsystem is initialized.
	// core.Game initializes INIT_VIDEO which includes INIT_EVENTS.
	// If not, this would be: if sdl2.WasInit(sdl2.INIT_EVENTS) == 0 { sdl2.InitSubSystem(sdl2.INIT_EVENTS) }
	// For now, assuming core.Game handles it.
}

// _update_input_states - processes SDL events and updates internal states.
// Called once per frame by Game before user's update.
_update_input_states :: proc() {
	// 1. Copy current to previous states
	_previous_keys = _current_keys
	_previous_mouse_buttons = _current_mouse_buttons
	
	// Reset per-frame state like scroll delta
	_mouse_scroll_x = 0
	_mouse_scroll_y = 0
	// _quit_requested is not reset here, it's a persistent flag until acted upon.

	// 2. Process SDL events
	event: sdl2.Event
	for sdl2.PollEvent(&event) {
		#partial switch event.type {
		case .QUIT:
			_quit_requested = true
		case .KEYDOWN:
			// SDL_KEYDOWN event.key.repeat is 0 for first press, non-zero for repeat
			// We generally care about the actual key state, so repeats don't change the logic here.
			scancode := event.key.keysym.scancode
			if scancode >= 0 && scancode < .NUM_SCANCODES { // Defensive bounds check
				_current_keys[scancode] = true
			}
		case .KEYUP:
			scancode := event.key.keysym.scancode
			if scancode >= 0 && scancode < .NUM_SCANCODES { // Defensive bounds check
				_current_keys[scancode] = false
			}
		case .MOUSEMOTION:
			_mouse_x = event.motion.x
			_mouse_y = event.motion.y
		case .MOUSEBUTTONDOWN:
			// SDL buttons are 1-indexed (SDL_BUTTON_LEFT=1, MIDDLE=2, RIGHT=3)
			button_idx := event.button.button - 1 
			if button_idx >= 0 && button_idx < MAX_MOUSE_BUTTONS {
				_current_mouse_buttons[button_idx] = true
			}
		case .MOUSEBUTTONUP:
			button_idx := event.button.button - 1 
			if button_idx >= 0 && button_idx < MAX_MOUSE_BUTTONS {
				_current_mouse_buttons[button_idx] = false
			}
		case .MOUSEWHEEL:
			// event.wheel.x: positive to the right, negative to the left
			// event.wheel.y: positive away from the user (scroll up normally), negative towards the user (scroll down normally)
			// event.wheel.direction can be SDL_MOUSEWHEEL_NORMAL or SDL_MOUSEWHEEL_FLIPPED
			// We'll assume normal direction for now.
			_mouse_scroll_x = event.wheel.x
			_mouse_scroll_y = event.wheel.y
		}
	}
}

// --- Public Accessor Functions ---

// Keyboard
is_key_down :: proc(key: Key) -> bool {
	// Check bounds to prevent reading out of range for _current_keys
	return key >= 0 && key < .NUM_SCANCODES && _current_keys[key]
}

is_key_up :: proc(key: Key) -> bool {
	return key >= 0 && key < .NUM_SCANCODES && !_current_keys[key]
}

is_key_pressed :: proc(key: Key) -> bool { // Pressed this frame
	return key >= 0 && key < .NUM_SCANCODES && _current_keys[key] && !_previous_keys[key]
}

is_key_released :: proc(key: Key) -> bool { // Released this frame
	return key >= 0 && key < .NUM_SCANCODES && !_current_keys[key] && _previous_keys[key]
}

// Mouse
get_mouse_position :: proc() -> (x: i32, y: i32) {
	return _mouse_x, _mouse_y
}

// `button_index`: 0 for left, 1 for middle, 2 for right (common mapping for SDL_BUTTON_LEFT, etc.)
is_mouse_button_down :: proc(button_index: int) -> bool {
	return button_index >= 0 && button_index < MAX_MOUSE_BUTTONS && _current_mouse_buttons[button_index]
}

is_mouse_button_up :: proc(button_index: int) -> bool {
	return button_index >= 0 && button_index < MAX_MOUSE_BUTTONS && !_current_mouse_buttons[button_index]
}

is_mouse_button_pressed :: proc(button_index: int) -> bool { // Pressed this frame
	return button_index >= 0 && button_index < MAX_MOUSE_BUTTONS && 
		   _current_mouse_buttons[button_index] && !_previous_mouse_buttons[button_index]
}

is_mouse_button_released :: proc(button_index: int) -> bool { // Released this frame
	return button_index >= 0 && button_index < MAX_MOUSE_BUTTONS && 
		   !_current_mouse_buttons[button_index] && _previous_mouse_buttons[button_index]
}

get_mouse_scroll_delta :: proc() -> (dx: i32, dy: i32) {
	return _mouse_scroll_x, _mouse_scroll_y
}

// Game Loop Control
is_quit_requested :: proc() -> bool {
	return _quit_requested
}
