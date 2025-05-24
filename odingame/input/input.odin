package input

import "core:log"
import "core:sdl"
import "core:mem" // For copy_slice, etc.
import "core:math/linalg" // For bit_set, if used, or manual bit manipulation
// Assuming input_types.odin is in the same package or types are globally accessible
// If input_types.odin defines `package input_types`, then:
// import . "./input_types" or input_types "input_types_package_path"
// For now, assuming types like Keys, Button_State, etc., are directly visible.


// --- Global State Variables ---
// These store the input state for the current and previous frames.

_current_keyboard_state:  Keyboard_State
_previous_keyboard_state: Keyboard_State

_current_mouse_state:     Mouse_State
_previous_mouse_state:    Mouse_State
_mouse_wheel_x_this_frame: i32 // Accumulated mouse wheel for the current frame
_mouse_wheel_y_this_frame: i32 // Accumulated mouse wheel for the current frame


_active_controllers:      [MAX_GAMEPADS]^sdl.GameController // Array of pointers to SDL GameController objects
_current_gamepad_states:  [MAX_GAMEPADS]Gamepad_State
_previous_gamepad_states: [MAX_GAMEPADS]Gamepad_State

_is_input_system_initialized: bool


// --- Initialization and Shutdown ---

// _init_input_system initializes SDL subsystems required for input.
// Called by core.Game.
_init_input_system :: proc "contextless" () {
    if _is_input_system_initialized {
        return
    }
    log.info("Initializing Input System...")
    // SDL_INIT_EVENTS is usually initialized by core.Game's main SDL_Init.
    // Ensure GameController subsystem is initialized.
    if sdl.InitSubSystem(sdl.INIT_GAMECONTROLLER | sdl.INIT_EVENTS) != 0 {
        log.errorf("SDL_InitSubSystem(INIT_GAMECONTROLLER | INIT_EVENTS) failed: %s", sdl.GetError())
        // Consider returning an error or panicking
        return
    }

    // Enable controller events. SDL_QUERY can be used to check current state.
    sdl.GameControllerEventState(sdl.ENABLE) 
    // sdl.JoystickEventState(sdl.ENABLE) // If also using raw joystick events

    // Discover and open any already connected gamepads
    // Note: SDL_CONTROLLERDEVICEADDED events will also fire for these if event polling starts after this.
    // This pre-opening can be useful.
    for i in 0..<sdl.NumJoysticks() {
        if sdl.IsGameController(i) {
            controller_idx := Player_Index(len(_active_controllers_list)) // This logic is wrong for fixed array
            // This loop is more for initial setup if not relying on events for already connected ones.
            // The event loop in update will handle newly connected ones.
            // For simplicity, let's rely on the event loop.
            // Or, we can try to open them here.
            // For now, keep it simple and let events handle additions.
        }
    }
    // Initialize states to default (e.g., all keys/buttons released)
    // Zero-initialization of structs should handle this.

    _is_input_system_initialized = true
    log.info("Input System initialized.")
}

// _shutdown_input_system closes any open game controllers.
// Called by core.Game.
_shutdown_input_system :: proc "contextless" () {
    if !_is_input_system_initialized {
        return
    }
    log.info("Shutting down Input System...")
    for i in 0..<MAX_GAMEPADS {
        if _active_controllers[i] != nil {
            log.debugf("Closing game controller for player %v (SDL instance ID %d)", Player_Index(i), _current_gamepad_states[i]._joystick_id)
            sdl.GameControllerClose(_active_controllers[i])
            _active_controllers[i] = nil
        }
    }
    // SDL_QuitSubSystem(sdl.INIT_GAMECONTROLLER) // If exclusively managed here. Usually core.Game handles SDL_Quit.
    _is_input_system_initialized = false
    log.info("Input System shut down.")
}


// --- Internal State Update ---

// _handle_controller_added attempts to open and assign a game controller.
_handle_controller_added :: proc "contextless" (which_joystick_idx: i32) {
    // Find an empty slot for this new controller
    player_idx_to_assign := -1
    for i in 0..<MAX_GAMEPADS {
        if _active_controllers[i] == nil {
            player_idx_to_assign = i
            break
        }
    }

    if player_idx_to_assign == -1 {
        log.warnf("Controller added (SDL joystick index %d), but no more player slots available (max %d).", which_joystick_idx, MAX_GAMEPADS)
        return
    }

    controller := sdl.GameControllerOpen(which_joystick_idx)
    if controller == nil {
        log.errorf("Could not open gamecontroller %d: %s", which_joystick_idx, sdl.GetError())
        return
    }
    
    _active_controllers[player_idx_to_assign] = controller
    joystick := sdl.GameControllerGetJoystick(controller)
    instance_id := sdl.JoystickInstanceID(joystick)
    
    _current_gamepad_states[player_idx_to_assign]._sdl_controller = controller
    _current_gamepad_states[player_idx_to_assign]._joystick_id = instance_id
    _current_gamepad_states[player_idx_to_assign].is_connected = true
    
    log.infof("Game controller added for player %v (SDL joystick index %d, instance ID %d)", Player_Index(player_idx_to_assign), which_joystick_idx, instance_id)
}

// _handle_controller_removed closes and deassigns a game controller.
_handle_controller_removed :: proc "contextless" (which_instance_id: sdl.JoystickID) {
    for i in 0..<MAX_GAMEPADS {
        if _active_controllers[i] != nil && _current_gamepad_states[i]._joystick_id == which_instance_id {
            log.infof("Game controller removed for player %v (SDL instance ID %d)", Player_Index(i), which_instance_id)
            sdl.GameControllerClose(_active_controllers[i])
            _active_controllers[i] = nil
            _current_gamepad_states[i] = {} // Reset state (is_connected will be false)
            _previous_gamepad_states[i] = {}
            return
        }
    }
    log.warnf("Controller removed (SDL instance ID %d), but no active controller found for that instance.", which_instance_id)
}


// input_update_frame_state is called once per frame by core.Game to update all input states.
// This was previously _update_input_states.
input_update_frame_state :: proc "contextless" () {
    if !_is_input_system_initialized {
        // This can happen if Game.Run calls Update before InputSystem is ready.
        // log.warn("input_update_frame_state called before input system initialized.")
        return
    }

    // 1. Copy current states to previous states
    _previous_keyboard_state = _current_keyboard_state
    _previous_mouse_state    = _current_mouse_state
    _previous_gamepad_states = _current_gamepad_states // Array copy

    // Reset per-frame accumulators like mouse wheel delta
    _mouse_wheel_x_this_frame = 0
    _mouse_wheel_y_this_frame = 0
    // _current_mouse_state.scroll_wheel_value is cumulative, delta is per-frame.
    // For XNA compatibility, scroll_wheel_value is total. Delta is derived by comparing current and previous.

    // 2. Process SDL Events
    event: sdl.Event
    for sdl.PollEvent(&event) {
        // Pass all events to Dear ImGui if used (example)
        // when ODIN_IMGUI { imgui.ImplSDL2_ProcessEvent(&event) }

        #partial switch event.type {
        case .QUIT:
            // Game loop should handle this to set game.is_running = false
            // This can be forwarded or handled by a global quit_requested flag.
            // For now, assume core.Game handles SDL_QUIT directly from its event loop.
            break 
        case .CONTROLLERDEVICEADDED:
            _handle_controller_added(event.cdevice.which)
        case .CONTROLLERDEVICEREMOVED:
            _handle_controller_removed(event.cdevice.which) // which is instance ID here
        case .CONTROLLERDEVICEREMAPPED:
            log.info("Controller remapped event received (not fully handled yet).")
            // Could update mappings if necessary.
        case .MOUSEWHEEL:
            // Accumulate wheel motion for this frame.
            // SDL_MOUSEWHEEL event y is positive for scroll away from user (up), negative for towards (down)
            // XNA: Positive for scroll up, negative for scroll down.
            // So, SDL y needs to be potentially inverted depending on desired XNA behavior.
            // XNA's ScrollWheelValue increases when wheel moved forward (away from user), decreases when backward.
            // SDL's y: "positive_value is scrolled away from the user (X11 mapping: Button4 / wheel up)"
            // "negative value is scrolled toward the user (X11 mapping: Button5 / wheel down)"
            // So, SDL's y directly maps to XNA's ScrollWheelValue change if positive is "up/away".
            // For this frame's delta:
            _mouse_wheel_x_this_frame += event.wheel.x
            _mouse_wheel_y_this_frame += event.wheel.y
        // Other events like KEYDOWN, KEYUP, MOUSEBUTTONDOWN, MOUSEBUTTONUP, MOUSEMOTION
        // are typically handled by polling current state, but events can be used for more precise
        // "just pressed/released" logic if needed, or for text input.
        }
    }

    // 3. Update Keyboard State
    // Get current state of all keys
    num_keys: i32
    key_states_ptr := sdl.GetKeyboardState(&num_keys) // Returns pointer to internal SDL array
    // Ensure num_keys is consistent with Keys._Count or sdl.Scancode.NUM_SCANCODES
    // The array is indexed by SDL_Scancode values.
    
    // Clear our internal bitset first
    // _current_keyboard_state._keys = {} // For bit_set
    for i in 0..<KEY_STORAGE_SIZE { _current_keyboard_state._keys[i] = 0 }


    max_scancode_to_check := min(i32(sdl.Scancode.NUM_SCANCODES), num_keys) // Safety
    for scancode_val in 0..<max_scancode_to_check {
        key_sdl_scancode := sdl.Scancode(scancode_val)
        if key_states_ptr[key_sdl_scancode] != 0 { // Key is down
            // Set the bit in our state
            key_index := int(key_sdl_scancode)
            storage_idx := key_index / 64
            bit_idx     := key_index % 64
            if storage_idx < KEY_STORAGE_SIZE { // Boundary check
                _current_keyboard_state._keys[storage_idx] |= (u64(1) << bit_idx)
            }
        }
    }
    
    // 4. Update Mouse State
    mouse_buttons_sdl := sdl.GetMouseState(&_current_mouse_state.x, &_current_mouse_state.y)
    _current_mouse_state.left_button   = .Released; if (mouse_buttons_sdl & sdl.BUTTON_LMASK)  != 0 { _current_mouse_state.left_button   = .Pressed }
    _current_mouse_state.middle_button = .Released; if (mouse_buttons_sdl & sdl.BUTTON_MMASK)  != 0 { _current_mouse_state.middle_button = .Pressed }
    _current_mouse_state.right_button  = .Released; if (mouse_buttons_sdl & sdl.BUTTON_RMASK)  != 0 { _current_mouse_state.right_button  = .Pressed }
    _current_mouse_state.x_button1     = .Released; if (mouse_buttons_sdl & sdl.BUTTON_X1MASK) != 0 { _current_mouse_state.x_button1     = .Pressed }
    _current_mouse_state.x_button2     = .Released; if (mouse_buttons_sdl & sdl.BUTTON_X2MASK) != 0 { _current_mouse_state.x_button2     = .Pressed }
    
    // Update cumulative scroll wheel value
    // XNA: ScrollWheelValue is total. Positive = scroll forward/away from user.
    // SDL MOUSEWHEEL y: positive = scroll away from user.
    _current_mouse_state.scroll_wheel_value += _mouse_wheel_y_this_frame 
    // Note: XNA also has HorizontalScrollWheelValue, which _mouse_wheel_x_this_frame could map to.


    // 5. Update Gamepad States
    for i in 0..<MAX_GAMEPADS {
        controller := _active_controllers[i]
        if controller != nil && sdl.GameControllerGetAttached(controller) {
            state := &_current_gamepad_states[i]
            state.is_connected = true
            state._sdl_controller = controller // Ensure it's current
            state._joystick_id = sdl.JoystickInstanceID(sdl.GameControllerGetJoystick(controller))


            // Buttons
            state.buttons.a = sdl.GameControllerGetButton(controller, .A) == 1 ? .Pressed : .Released
            state.buttons.b = sdl.GameControllerGetButton(controller, .B) == 1 ? .Pressed : .Released
            state.buttons.x = sdl.GameControllerGetButton(controller, .X) == 1 ? .Pressed : .Released
            state.buttons.y = sdl.GameControllerGetButton(controller, .Y) == 1 ? .Pressed : .Released
            state.buttons.back = sdl.GameControllerGetButton(controller, .BACK) == 1 ? .Pressed : .Released
            state.buttons.start = sdl.GameControllerGetButton(controller, .START) == 1 ? .Pressed : .Released
            state.buttons.left_stick_button = sdl.GameControllerGetButton(controller, .LEFTSTICK) == 1 ? .Pressed : .Released
            state.buttons.right_stick_button = sdl.GameControllerGetButton(controller, .RIGHTSTICK) == 1 ? .Pressed : .Released
            state.buttons.left_shoulder = sdl.GameControllerGetButton(controller, .LEFTSHOULDER) == 1 ? .Pressed : .Released
            state.buttons.right_shoulder = sdl.GameControllerGetButton(controller, .RIGHTSHOULDER) == 1 ? .Pressed : .Released
            state.buttons.dpad_up = sdl.GameControllerGetButton(controller, .DPAD_UP) == 1 ? .Pressed : .Released
            state.buttons.dpad_down = sdl.GameControllerGetButton(controller, .DPAD_DOWN) == 1 ? .Pressed : .Released
            state.buttons.dpad_left = sdl.GameControllerGetButton(controller, .DPAD_LEFT) == 1 ? .Pressed : .Released
            state.buttons.dpad_right = sdl.GameControllerGetButton(controller, .DPAD_RIGHT) == 1 ? .Pressed : .Released

            // Triggers (0-32767 range from SDL) -> normalize to 0.0-1.0
            AXIS_MAX :: 32767.0
            state.triggers.left  = f32(sdl.GameControllerGetAxis(controller, .TRIGGERLEFT)) / AXIS_MAX
            state.triggers.right = f32(sdl.GameControllerGetAxis(controller, .TRIGGERRIGHT)) / AXIS_MAX

            // Thumbsticks (-32768 to 32767 range from SDL) -> normalize to -1.0-1.0
            // SDL Y is -up, +down. XNA Y is +up, -down. For now, store raw SDL values.
            // Getter functions can invert Y if XNA compatibility is desired.
            // Deadzone should be applied by user or in getter.
            state.thumb_sticks.left_x  = _normalize_axis(sdl.GameControllerGetAxis(controller, .LEFTX))
            state.thumb_sticks.left_y  = _normalize_axis(sdl.GameControllerGetAxis(controller, .LEFTY)) // Y is -up for SDL
            state.thumb_sticks.right_x = _normalize_axis(sdl.GameControllerGetAxis(controller, .RIGHTX))
            state.thumb_sticks.right_y = _normalize_axis(sdl.GameControllerGetAxis(controller, .RIGHTY)) // Y is -up for SDL
        } else {
            // If controller was disconnected by event, it's already reset.
            // If it became unattached between event poll and here:
            if _active_controllers[i] != nil && !sdl.GameControllerGetAttached(controller) {
                 log.warnf("Controller for player %v (SDL instance ID %d) reported unattached during poll. Closing.", Player_Index(i), _current_gamepad_states[i]._joystick_id)
                _handle_controller_removed(_current_gamepad_states[i]._joystick_id) // Use existing removal logic
            } else {
                 // Ensure non-connected slots are marked
                _current_gamepad_states[i].is_connected = false
                _current_gamepad_states[i]._sdl_controller = nil
            }
        }
    }
}

_normalize_axis :: proc "contextless" (value: i16) -> f32 {
    // Normalize SDL axis value from -32768 to 32767 range to -1.0 to 1.0
    // Special case for -32768 as it doesn't have a positive counterpart.
    if value == -32768 { return -1.0 }
    return f32(value) / 32767.0
}


// --- Public API Functions ---

keyboard_get_state :: proc "contextless" () -> Keyboard_State {
    return _current_keyboard_state
}

keyboard_state_is_key_down :: proc "contextless" (state: Keyboard_State, key: Keys) -> bool {
    key_index := int(key)
    if key_index < 0 || key_index >= int(sdl.Scancode.NUM_SCANCODES) { return false } // Bounds check
    
    storage_idx := key_index / 64
    bit_idx     := u64(key_index % 64)
    
    // Check if storage_idx is within bounds of our _keys array
    if storage_idx >= 0 && storage_idx < KEY_STORAGE_SIZE {
        return (state._keys[storage_idx] & (u64(1) << bit_idx)) != 0
    }
    return false
}

keyboard_state_is_key_up :: proc "contextless" (state: Keyboard_State, key: Keys) -> bool {
    return !keyboard_state_is_key_down(state, key)
}

mouse_get_state :: proc "contextless" () -> Mouse_State {
    return _current_mouse_state
}

gamepad_get_state :: proc "contextless" (player_idx: Player_Index) -> Gamepad_State {
    if player_idx >= 0 && int(player_idx) < MAX_GAMEPADS {
        return _current_gamepad_states[player_idx]
    }
    log.warnf("gamepad_get_state: Invalid player_index %v.", player_idx)
    return Gamepad_State{is_connected = false} // Return a disconnected state
}


// --- Deprecated / To be removed ---
// These are from the old input system. They will be removed once examples are updated.

Key :: Keys // Alias for backward compatibility if needed temporarily

is_key_down :: proc(key: Key) -> bool {
	// log.warn("Deprecated: input.is_key_down called. Use input.keyboard_get_state().is_key_down() instead.")
    return keyboard_state_is_key_down(_current_keyboard_state, key)
}
is_key_pressed :: proc(key: Key) -> bool {
	// log.warn("Deprecated: input.is_key_pressed called. Use input.keyboard_get_state() and compare with previous state.")
    // Requires _previous_keyboard_state to be correctly updated.
    return keyboard_state_is_key_down(_current_keyboard_state, key) && 
           keyboard_state_is_key_up(_previous_keyboard_state, key)
}
is_key_released :: proc(key: Key) -> bool {
	// log.warn("Deprecated: input.is_key_released called. Use input.keyboard_get_state() and compare with previous state.")
    return keyboard_state_is_key_up(_current_keyboard_state, key) && 
           keyboard_state_is_key_down(_previous_keyboard_state, key)
}

get_mouse_position :: proc() -> (x, y: i32) {
	// log.warn("Deprecated: input.get_mouse_position called. Use input.mouse_get_state().x/y instead.")
    return _current_mouse_state.x, _current_mouse_state.y
}
is_mouse_button_down :: proc(button_index: int) -> bool { // 0:left, 1:middle, 2:right
	// log.warn("Deprecated: input.is_mouse_button_down called. Use input.mouse_get_state().left_button etc. instead.")
    #partial switch button_index {
    case 0: return _current_mouse_state.left_button == .Pressed
    case 1: return _current_mouse_state.middle_button == .Pressed
    case 2: return _current_mouse_state.right_button == .Pressed
    }
    return false
}
is_mouse_button_pressed :: proc(button_index: int) -> bool {
	// log.warn("Deprecated: input.is_mouse_button_pressed called. Use input.mouse_get_state() and compare with previous state.")
    #partial switch button_index {
    case 0: return mouse_is_button_pressed(.Left)
    case 1: return mouse_is_button_pressed(.Middle)
    case 2: return mouse_is_button_pressed(.Right)
    case 3: return mouse_is_button_pressed(.X1) // Assuming X1 is index 3
    case 4: return mouse_is_button_pressed(.X2) // Assuming X2 is index 4
    }
    return false
}
get_mouse_scroll_delta :: proc() -> (dx: i32, dy: i32) {
    // This returns per-frame delta, not total.
    // XNA's ScrollWheelValue is cumulative. Delta is current - previous.
    // The _mouse_wheel_x/y_this_frame are the deltas from events.
    // For XNA compatibility, a direct delta from scroll_wheel_value is better.
    // return _mouse_wheel_x_this_frame, _mouse_wheel_y_this_frame 
    return _mouse_wheel_x_this_frame, _current_mouse_state.scroll_wheel_value - _previous_mouse_state.scroll_wheel_value
}

// Dummy is_quit_requested for compatibility, game loop should handle SDL_QUIT directly
is_quit_requested :: proc() -> bool { return false }


// --- New XNA-style "Pressed" and "Released" logic ---

// Keyboard
keyboard_is_key_pressed :: proc "contextless" (key: Keys) -> bool {
    return keyboard_state_is_key_down(_current_keyboard_state, key) &&
           keyboard_state_is_key_up(_previous_keyboard_state, key)
}

keyboard_is_key_released :: proc "contextless" (key: Keys) -> bool {
    return keyboard_state_is_key_up(_current_keyboard_state, key) &&
           keyboard_state_is_key_down(_previous_keyboard_state, key)
}

// Mouse
mouse_is_button_pressed :: proc "contextless" (button: Mouse_Button) -> bool {
    #partial switch button {
    case .Left:   return _current_mouse_state.left_button == .Pressed && _previous_mouse_state.left_button == .Released
    case .Middle: return _current_mouse_state.middle_button == .Pressed && _previous_mouse_state.middle_button == .Released
    case .Right:  return _current_mouse_state.right_button == .Pressed && _previous_mouse_state.right_button == .Released
    case .X1:     return _current_mouse_state.x_button1 == .Pressed && _previous_mouse_state.x_button1 == .Released
    case .X2:     return _current_mouse_state.x_button2 == .Pressed && _previous_mouse_state.x_button2 == .Released
    }
    return false
}

mouse_is_button_released :: proc "contextless" (button: Mouse_Button) -> bool {
    #partial switch button {
    case .Left:   return _current_mouse_state.left_button == .Released && _previous_mouse_state.left_button == .Pressed
    case .Middle: return _current_mouse_state.middle_button == .Released && _previous_mouse_state.middle_button == .Pressed
    case .Right:  return _current_mouse_state.right_button == .Released && _previous_mouse_state.right_button == .Pressed
    case .X1:     return _current_mouse_state.x_button1 == .Released && _previous_mouse_state.x_button1 == .Pressed
    case .X2:     return _current_mouse_state.x_button2 == .Released && _previous_mouse_state.x_button2 == .Pressed
    }
    return false
}

mouse_get_scroll_wheel_delta :: proc "contextless" () -> i32 {
    // Returns the change in scroll wheel value since the last frame.
    // XNA's ScrollWheelValue is cumulative.
    return _current_mouse_state.scroll_wheel_value - _previous_mouse_state.scroll_wheel_value
}


// Gamepad
// Helper to get a specific button state from Gamepad_Buttons struct
_get_gamepad_button_state :: proc "contextless" (buttons_struct: Gamepad_Buttons, button_type: Gamepad_Button_Type) -> Button_State {
    #partial switch button_type {
    case .A: return buttons_struct.a
    case .B: return buttons_struct.b
    case .X: return buttons_struct.x
    case .Y: return buttons_struct.y
    case .Back: return buttons_struct.back
    case .Start: return buttons_struct.start
    case .LEFTSTICK: return buttons_struct.left_stick_button
    case .RIGHTSTICK: return buttons_struct.right_stick_button
    case .LEFTSHOULDER: return buttons_struct.left_shoulder
    case .RIGHTSHOULDER: return buttons_struct.right_shoulder
    case .DPAD_UP: return buttons_struct.dpad_up
    case .DPAD_DOWN: return buttons_struct.dpad_down
    case .DPAD_LEFT: return buttons_struct.dpad_left
    case .DPAD_RIGHT: return buttons_struct.dpad_right
    // case .GUIDE: // Guide button often not queryable or reserved
    }
    return .Released // Default for unhandled or invalid buttons
}

gamepad_is_button_down :: proc "contextless" (player_idx: Player_Index, button: Gamepad_Button_Type) -> bool {
    if player_idx < 0 || int(player_idx) >= MAX_GAMEPADS { return false }
    if !_current_gamepad_states[player_idx].is_connected { return false }
    return _get_gamepad_button_state(_current_gamepad_states[player_idx].buttons, button) == .Pressed
}
gamepad_is_button_up :: proc "contextless" (player_idx: Player_Index, button: Gamepad_Button_Type) -> bool {
    if player_idx < 0 || int(player_idx) >= MAX_GAMEPADS { return false }
    if !_current_gamepad_states[player_idx].is_connected { return true } // If not connected, all buttons are "up"
    return _get_gamepad_button_state(_current_gamepad_states[player_idx].buttons, button) == .Released
}

gamepad_is_button_pressed :: proc "contextless" (player_idx: Player_Index, button: Gamepad_Button_Type) -> bool {
    if player_idx < 0 || int(player_idx) >= MAX_GAMEPADS { return false }
    if !_current_gamepad_states[player_idx].is_connected { return false } // Can't be pressed if not connected
    
    current_down := _get_gamepad_button_state(_current_gamepad_states[player_idx].buttons, button) == .Pressed
    // If previous state was not connected, treat all buttons as released for "pressed" logic
    previous_down := _previous_gamepad_states[player_idx].is_connected && 
                     _get_gamepad_button_state(_previous_gamepad_states[player_idx].buttons, button) == .Pressed
    
    return current_down && !previous_down
}

gamepad_is_button_released :: proc "contextless" (player_idx: Player_Index, button: Gamepad_Button_Type) -> bool {
    if player_idx < 0 || int(player_idx) >= MAX_GAMEPADS { return false }
    // A button can be "released" if it was pressed and now the controller is disconnected.
    
    current_up := _get_gamepad_button_state(_current_gamepad_states[player_idx].buttons, button) == .Released
    if !_current_gamepad_states[player_idx].is_connected { current_up = true } // Treat as up if disconnected now

    previous_down := _previous_gamepad_states[player_idx].is_connected &&
                     _get_gamepad_button_state(_previous_gamepad_states[player_idx].buttons, button) == .Pressed
    
    return current_up && previous_down
}
