package input

import "core:sdl" // For sdl2.Scancode and other SDL types if needed
import "core:math/linalg" // For bit_set potentially, or define simple bit_set

// --- Enums ---

// Keys defines a universal set of keyboard keys.
// Values are mapped from sdl2.Scancode for consistency with SDL backend.
// This provides an abstraction layer over SDL's scancodes.
Keys :: enum sdl.Scancode {
    Unknown = sdl.Scancode.UNKNOWN,

    A = sdl.Scancode.A, B = sdl.Scancode.B, C = sdl.Scancode.C, D = sdl.Scancode.D, E = sdl.Scancode.E,
    F = sdl.Scancode.F, G = sdl.Scancode.G, H = sdl.Scancode.H, I = sdl.Scancode.I, J = sdl.Scancode.J,
    K = sdl.Scancode.K, L = sdl.Scancode.L, M = sdl.Scancode.M, N = sdl.Scancode.N, O = sdl.Scancode.O,
    P = sdl.Scancode.P, Q = sdl.Scancode.Q, R = sdl.Scancode.R, S = sdl.Scancode.S, T = sdl.Scancode.T,
    U = sdl.Scancode.U, V = sdl.Scancode.V, W = sdl.Scancode.W, X = sdl.Scancode.X, Y = sdl.Scancode.Y,
    Z = sdl.Scancode.Z,

    Num1 = sdl.Scancode.NUM_1, Num2 = sdl.Scancode.NUM_2, Num3 = sdl.Scancode.NUM_3, Num4 = sdl.Scancode.NUM_4, Num5 = sdl.Scancode.NUM_5,
    Num6 = sdl.Scancode.NUM_6, Num7 = sdl.Scancode.NUM_7, Num8 = sdl.Scancode.NUM_8, Num9 = sdl.Scancode.NUM_9, Num0 = sdl.Scancode.NUM_0,

    Return = sdl.Scancode.RETURN,
    Escape = sdl.Scancode.ESCAPE,
    Backspace = sdl.Scancode.BACKSPACE,
    Tab = sdl.Scancode.TAB,
    Space = sdl.Scancode.SPACE,

    Minus = sdl.Scancode.MINUS,
    Equals = sdl.Scancode.EQUALS,
    Left_Bracket = sdl.Scancode.LEFTBRACKET,
    Right_Bracket = sdl.Scancode.RIGHTBRACKET,
    Backslash = sdl.Scancode.BACKSLASH,
    Semicolon = sdl.Scancode.SEMICOLON,
    Apostrophe = sdl.Scancode.APOSTROPHE,
    Grave = sdl.Scancode.GRAVE,
    Comma = sdl.Scancode.COMMA,
    Period = sdl.Scancode.PERIOD,
    Slash = sdl.Scancode.SLASH,

    Caps_Lock = sdl.Scancode.CAPSLOCK,

    F1 = sdl.Scancode.F1, F2 = sdl.Scancode.F2, F3 = sdl.Scancode.F3, F4 = sdl.Scancode.F4,
    F5 = sdl.Scancode.F5, F6 = sdl.Scancode.F6, F7 = sdl.Scancode.F7, F8 = sdl.Scancode.F8,
    F9 = sdl.Scancode.F9, F10 = sdl.Scancode.F10, F11 = sdl.Scancode.F11, F12 = sdl.Scancode.F12,

    Print_Screen = sdl.Scancode.PRINTSCREEN,
    Scroll_Lock = sdl.Scancode.SCROLLLOCK,
    Pause = sdl.Scancode.PAUSE,
    Insert = sdl.Scancode.INSERT,
    Home = sdl.Scancode.HOME,
    Page_Up = sdl.Scancode.PAGEUP,
    Delete = sdl.Scancode.DELETE,
    End = sdl.Scancode.END,
    Page_Down = sdl.Scancode.PAGEDOWN,

    Right = sdl.Scancode.RIGHT, Left = sdl.Scancode.LEFT, Down = sdl.Scancode.DOWN, Up = sdl.Scancode.UP,

    Num_Lock_Clear = sdl.Scancode.NUMLOCKCLEAR,
    Kp_Divide = sdl.Scancode.KP_DIVIDE,
    Kp_Multiply = sdl.Scancode.KP_MULTIPLY,
    Kp_Minus = sdl.Scancode.KP_MINUS,
    Kp_Plus = sdl.Scancode.KP_PLUS,
    Kp_Enter = sdl.Scancode.KP_ENTER,
    Kp_1 = sdl.Scancode.KP_1, Kp_2 = sdl.Scancode.KP_2, Kp_3 = sdl.Scancode.KP_3, Kp_4 = sdl.Scancode.KP_4,
    Kp_5 = sdl.Scancode.KP_5, Kp_6 = sdl.Scancode.KP_6, Kp_7 = sdl.Scancode.KP_7, Kp_8 = sdl.Scancode.KP_8,
    Kp_9 = sdl.Scancode.KP_9, Kp_0 = sdl.Scancode.KP_0,
    Kp_Period = sdl.Scancode.KP_PERIOD,

    Left_Control = sdl.Scancode.LCTRL,
    Left_Shift = sdl.Scancode.LSHIFT,
    Left_Alt = sdl.Scancode.LALT, // Alt / Option
    Left_Gui = sdl.Scancode.LGUI, // Windows / Command / Super
    Right_Control = sdl.Scancode.RCTRL,
    Right_Shift = sdl.Scancode.RSHIFT,
    Right_Alt = sdl.Scancode.RALT, // Alt Gr / Option
    Right_Gui = sdl.Scancode.RGUI, // Windows / Command / Super
    
    // Add more as needed, map to sdl.Scancode
    _Count = sdl.Scancode.NUM_SCANCODES, // For sizing arrays/bitsets
}

Button_State :: enum {
    Released,
    Pressed,
}

Mouse_Button :: enum {
    Left,
    Middle,
    Right,
    X1, // Extra button 1
    X2, // Extra button 2
}

// Player_Index identifies the player controlling the input device.
// Maps to SDL controller indices.
Player_Index :: enum {
    One   = 0,
    Two   = 1,
    Three = 2,
    Four  = 3,
    // Add Five to Eight if supporting more than 4 controllers.
    // Max_Players = 4, // Or some other constant
}
MAX_GAMEPADS :: Player_Index.Four + 1 // Max number of gamepads supported

// Gamepad_Button_Type maps to SDL_GameControllerButton for abstraction.
Gamepad_Button_Type :: enum sdl.GameControllerButton {
    Invalid          = .INVALID,
    A                = .A,
    B                = .B,
    X                = .X,
    Y                = .Y,
    Back             = .BACK,
    Guide            = .GUIDE, // Often reserved by system
    Start            = .START,
    Left_Stick       = .LEFTSTICK,
    Right_Stick      = .RIGHTSTICK,
    Left_Shoulder    = .LEFTSHOULDER,
    Right_Shoulder   = .RIGHTSHOULDER,
    Dpad_Up          = .DPAD_UP,
    Dpad_Down        = .DPAD_DOWN,
    Dpad_Left        = .DPAD_LEFT,
    Dpad_Right       = .DPAD_RIGHT,
    // Misc1         = .MISC1, /* Xbox Series X share button, PS5 microphone button, Nintendo Switch Pro capture button */
    // Paddle1       = .PADDLE1, /* Xbox Elite paddle P1 */
    // Paddle2       = .PADDLE2, /* Xbox Elite paddle P2 */
    // Paddle3       = .PADDLE3, /* Xbox Elite paddle P3 */
    // Paddle4       = .PADDLE4, /* Xbox Elite paddle P4 */
    // Touchpad      = .TOUCHPAD, /* PS4/PS5 touchpad button */
    // Max           = .MAX,
}


// --- State Structs ---

// Keyboard_State represents the state of the keyboard at a specific time.
// Uses a bit_set for efficient storage of key states.
// SDL_NUM_SCANCODES is 512. A u128 can hold 128 bits. Need more.
// A slice of u64 or similar would be better, or a larger fixed array for bit_set.
// For bit_set[Keys; uXXX], Keys is the enum, uXXX is the storage.
// The size of the storage needs to accommodate the highest value in Keys enum.
// sdl.Scancode.NUM_SCANCODES is 512.
// We need ceil(512 / 64) = 8 u64s.
KEY_STORAGE_SIZE :: (sdl.Scancode.NUM_SCANCODES + 63) / 64 // Number of u64 elements
Keyboard_State :: struct {
    // _keys: bit_set[Keys; [KEY_STORAGE_SIZE]u64], // This syntax might need adjustment for Odin's bit_set
    _keys: [KEY_STORAGE_SIZE]u64, // Manual bit manipulation on this array
}

// Mouse_State represents the state of the mouse at a specific time.
Mouse_State :: struct {
    x, y:               i32,
    scroll_wheel_value: i32, // Total accumulated scroll value since game start
    left_button:        Button_State,
    middle_button:      Button_State,
    right_button:       Button_State,
    x_button1:          Button_State, // Extra mouse button 1
    x_button2:          Button_State, // Extra mouse button 2
    // Delta values can be added if needed: delta_x, delta_y, delta_scroll_wheel
}

// Gamepad_Buttons represents the state of all buttons on a gamepad.
Gamepad_Buttons :: struct {
    a, b, x, y:         Button_State,
    back, start:        Button_State,
    left_stick_button:  Button_State, // Click of the left stick
    right_stick_button: Button_State, // Click of the right stick
    left_shoulder:      Button_State,
    right_shoulder:     Button_State,
    dpad_up:            Button_State,
    dpad_down:          Button_State,
    dpad_left:          Button_State,
    dpad_right:         Button_State,
    // big_button: Button_State, // Guide/Home button (often reserved by OS or platform)
}

// Gamepad_Triggers represents the state of the left and right trigger buttons.
// Values are normalized from 0.0 (released) to 1.0 (fully pressed).
Gamepad_Triggers :: struct {
    left:  f32,
    right: f32,
}

// Gamepad_Thumb_Sticks represents the state of the left and right thumb sticks.
// Values are normalized from -1.0 to 1.0 for each axis.
// Y is typically inverted (up is positive) by XNA, but SDL provides up as negative.
// This struct will store values as SDL provides them (Y up = negative).
// Getter functions can invert Y if XNA compatibility is desired.
Gamepad_Thumb_Sticks :: struct {
    left_x, left_y:   f32,
    right_x, right_y: f32,
}

// Gamepad_State represents the complete state of a gamepad.
Gamepad_State :: struct {
    is_connected: bool,
    // packet_number: u32, // For XInput compatibility, tracks changes. SDL doesn't provide this directly.
    buttons:      Gamepad_Buttons,
    triggers:     Gamepad_Triggers,
    thumb_sticks: Gamepad_Thumb_Sticks,
    
    _sdl_controller:  ^sdl.GameController, // Internal handle to the SDL_GameController object
    _joystick_id:     sdl.JoystickID,      // To identify the device if it gets reconnected
}
