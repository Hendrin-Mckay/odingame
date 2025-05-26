package sdl

import "core:fmt"
import "src:core" // Using collection-based import for the logger

// --- SDL Constants ---
// SDL_Init flags
SDL_INIT_VIDEO :: u32(0x00000020)
SDL_INIT_AUDIO :: u32(0x00000010)
SDL_INIT_EVENTS :: u32(0x00004000)

// SDL_WindowFlags enum (subset)
SDL_WINDOW_FULLSCREEN :: u32(0x00000001)
SDL_WINDOW_OPENGL :: u32(0x00000002)
SDL_WINDOW_SHOWN :: u32(0x00000004)
SDL_WINDOW_HIDDEN :: u32(0x00000008)
SDL_WINDOW_BORDERLESS :: u32(0x00000010)
SDL_WINDOW_RESIZABLE :: u32(0x00000020)
SDL_WINDOW_MINIMIZED :: u32(0x00000040)
SDL_WINDOW_MAXIMIZED :: u32(0x00000080)
SDL_WINDOW_MOUSE_GRABBED :: u32(0x00000100)

// SDL_RendererFlags enum (subset)
SDL_RENDERER_SOFTWARE :: u32(0x00000001)
SDL_RENDERER_ACCELERATED :: u32(0x00000002)
SDL_RENDERER_PRESENTVSYNC :: u32(0x00000004)

// SDL_EventType enum (minimal subset for now)
SDL_EVENT_FIRST :: u32 = 0; 

SDL_EVENT_QUIT :: u32 = 0x100; 

SDL_EVENT_KEY_DOWN :: u32 = 0x300; 
SDL_EVENT_KEY_UP :: u32 = 0x301;   

SDL_EVENT_MOUSE_MOTION :: u32 = 0x400;    
SDL_EVENT_MOUSE_BUTTON_DOWN :: u32 = 0x401; 
SDL_EVENT_MOUSE_BUTTON_UP :: u32 = 0x402;   
SDL_EVENT_MOUSE_WHEEL :: u32 = 0x403;     

// SDL_Scancode enum (subset, from SDL_scancode.h)
SDL_SCANCODE_UNKNOWN :: i32 = 0;
SDL_SCANCODE_A :: i32 = 4;
SDL_SCANCODE_RETURN :: i32 = 40;
SDL_SCANCODE_ESCAPE :: i32 = 41;
SDL_SCANCODE_SPACE :: i32 = 44;
SDL_NUM_SCANCODES :: i32 = 512; // Maximum number of scancodes

// SDL_PRESSED and SDL_RELEASED constants for key/button states
SDL_PRESSED :: u8 = 1
SDL_RELEASED :: u8 = 0

// --- SDL Event Structures ---
SDL_CommonEvent :: struct {
	type: u32,
	timestamp: u64, 
}

SDL_KeyboardEvent :: struct {
	type: u32,
	timestamp: u64,
	windowID: u32,
	state: u8, 
	repeat: u8, 
	// padding2: u8, // Odin handles padding automatically based on alignment rules
	// padding3: u8,
	scancode: i32, 
	keycode: i32, 
	mod: u16, 
    // padding4: u16,
    // text: [32]u8, 
}

SDL_MouseMotionEvent :: struct {
    type: u32,
    timestamp: u64,
    windowID: u32,
    which: u32, 
    state: u32, 
    x: i32,     
    y: i32,     
    xrel: i32,  
    yrel: i32,  
}

SDL_MouseButtonEvent :: struct {
    type: u32,
    timestamp: u64,
    windowID: u32,
    which: u32, 
    button: u8, 
    state: u8,  
    clicks: u8, 
    // padding1: u8,
    x: i32,     
    y: i32,     
}

// SDL_Event structure - ensure it can hold these event types
SDL_Event :: struct #raw_union {
    type: u32,                  
    common: SDL_CommonEvent,    
    key: SDL_KeyboardEvent,     
    motion: SDL_MouseMotionEvent, 
    button: SDL_MouseButtonEvent, 
    // SDL_QuitEvent is just common, so no explicit member needed if common is used.
    // SDL_MouseWheelEvent would be another member here.
    _padding: [64]u8, // Ensure this is large enough for the largest member (e.g. SDL_MouseMotionEvent or SDL_KeyboardEvent)
}


// --- SDL Foreign Function Interface ---
@(foreign="SDL3") 
foreign SDL {
	SDL_Init :: proc(flags: u32) -> i32 ---
	SDL_Quit :: proc() ---
	SDL_GetError :: proc() -> cstring ---

	SDL_CreateWindow :: proc(title: cstring, w: i32, h: i32, flags: u32) -> rawptr ---
	SDL_DestroyWindow :: proc(window: rawptr) ---
	
	SDL_CreateRenderer :: proc(window: rawptr, flags: u32) -> rawptr ---
	SDL_DestroyRenderer :: proc(renderer: rawptr) ---
	SDL_SetRenderDrawColor :: proc(renderer: rawptr, r: u8, g: u8, b: u8, a: u8) -> i32 ---
	SDL_RenderClear :: proc(renderer: rawptr) -> i32 ---
	SDL_RenderPresent :: proc(renderer: rawptr) ---

	SDL_PollEvent :: proc(event: ^SDL_Event) -> i32 --- 

	SDL_Delay :: proc(ms: u32) ---
}


// --- SDL Initialization and Shutdown ---
InitSDL :: proc(init_flags: u32 = SDL_INIT_VIDEO | SDL_INIT_AUDIO | SDL_INIT_EVENTS) -> bool {
	core.LogInfo("[SDL] Initializing SDL...")
	if SDL_Init(init_flags) < 0 {
		error_msg := SDL_GetError()
		core.LogErrorFmt("[SDL] Failed to initialize SDL: %s", error_msg)
		return false
	}
	core.LogInfo("[SDL] SDL Initialized successfully.")
	return true
}

ShutdownSDL :: proc() {
	core.LogInfo("[SDL] Shutting down SDL...")
	SDL_Quit()
	core.LogInfo("[SDL] SDL Shutdown complete.")
}
