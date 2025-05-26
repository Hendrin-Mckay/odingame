package sdl

import "core:fmt"
import "src:core" // Using collection-based import for the logger
import "core:c"   // For c.int typically used with bitflags

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
SDL_NUM_SCANCODES :: i32 = 512; 

// SDL_PRESSED and SDL_RELEASED constants for key/button states
SDL_PRESSED :: u8 = 1
SDL_RELEASED :: u8 = 0

// --- SDL_image specific constants ---
IMG_INIT_JPG :: c.int(0x00000001)
IMG_INIT_PNG :: c.int(0x00000002)
IMG_INIT_TIF :: c.int(0x00000004)
IMG_INIT_WEBP :: c.int(0x00000008)

// --- SDL_mixer specific constants ---
MIX_INIT_FLAC :: c.int(0x00000001)
MIX_INIT_MOD :: c.int(0x00000002)
MIX_INIT_MP3 :: c.int(0x00000008)
MIX_INIT_OGG :: c.int(0x00000010)
MIX_DEFAULT_CHANNELS :: 2      
MIX_DEFAULT_FREQUENCY :: 44100 
MIX_DEFAULT_FORMAT :: u16(0x8010) // AUDIO_S16LSB 
MIX_MAX_VOLUME :: 128


// --- SDL Event Structures ---
SDL_CommonEvent :: struct {
	type: u32,
	timestamp: u64, 
}
SDL_KeyboardEvent :: struct {
	type: u32, timestamp: u64, windowID: u32, state: u8, repeat: u8, 
	scancode: i32, keycode: i32, mod: u16, 
}
SDL_MouseMotionEvent :: struct {
    type: u32, timestamp: u64, windowID: u32, which: u32, 
    state: u32, x: i32, y: i32, xrel: i32, yrel: i32,  
}
SDL_MouseButtonEvent :: struct {
    type: u32, timestamp: u64, windowID: u32, which: u32, 
    button: u8, state: u8, clicks: u8, x: i32, y: i32,     
}
SDL_Event :: struct #raw_union {
    type: u32, common: SDL_CommonEvent, key: SDL_KeyboardEvent,     
    motion: SDL_MouseMotionEvent, button: SDL_MouseButtonEvent, 
    _padding: [64]u8, 
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

	// SDL_image functions
	IMG_Init :: proc(flags: c.int) -> c.int ---
	IMG_Quit :: proc() ---
	IMG_LoadTexture :: proc(renderer: rawptr, file: cstring) -> rawptr --- 

	// SDL_mixer functions
	Mix_Init :: proc(flags: c.int) -> c.int ---
	Mix_Quit :: proc() ---
	Mix_OpenAudio :: proc(frequency: c.int, format: u16, channels: c.int, chunksize: c.int) -> c.int ---
	Mix_CloseAudio :: proc() ---
	Mix_LoadWAV :: proc(file: cstring) -> rawptr --- 
	Mix_LoadMUS :: proc(file: cstring) -> rawptr --- 
	Mix_FreeChunk :: proc(chunk: rawptr) --- 
	Mix_FreeMusic :: proc(music: rawptr) --- 
	
	// SDL_render.h functions
	SDL_QueryTexture :: proc(texture: rawptr, format: ^u32, access: ^i32, w: ^i32, h: ^i32) -> i32 --- 
	SDL_DestroyTexture :: proc(texture: rawptr) --- 
}

// --- SDL Opaque Structs ---
SDL_Texture :: struct #opaque; 
Renderer :: struct #opaque;    
Mix_Chunk :: struct #opaque;   
Mix_Music :: struct #opaque;   

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

// InitSDLImage initializes SDL_image with desired format support.
InitSDLImage :: proc(flags: c.int = IMG_INIT_PNG | IMG_INIT_JPG) -> bool {
    core.LogInfo("[SDL] Initializing SDL_image...")
    initialized_flags := IMG_Init(flags)
    if (initialized_flags & flags) != flags {
        error_msg := SDL_GetError() 
        core.LogErrorFmt("[SDL] Failed to initialize SDL_image with required flags. Wanted %X, got %X. Error: %s", flags, initialized_flags, error_msg)
        return false
    }
    core.LogInfoFmt("[SDL] SDL_image initialized successfully (Flags: %X).", initialized_flags)
    return true
}

// ShutdownSDLImage cleans up SDL_image.
ShutdownSDLImage :: proc() {
    core.LogInfo("[SDL] Shutting down SDL_image...")
    IMG_Quit()
}

// InitSDLMixer initializes SDL_mixer.
InitSDLMixer :: proc(flags: c.int = MIX_INIT_OGG | MIX_INIT_MP3) -> bool {
    core.LogInfo("[SDL] Initializing SDL_mixer...")
    initialized_flags := Mix_Init(flags)
    if (initialized_flags & flags) != flags {
        error_msg := SDL_GetError()
        core.LogErrorFmt("[SDL] Failed to initialize SDL_mixer with required flags. Wanted %X, got %X. Error: %s", flags, initialized_flags, error_msg)
        return false
    }
    
    if Mix_OpenAudio(MIX_DEFAULT_FREQUENCY, MIX_DEFAULT_FORMAT, MIX_DEFAULT_CHANNELS, 2048) < 0 {
        error_msg := SDL_GetError()
        core.LogErrorFmt("[SDL] Failed to open audio device: %s", error_msg)
        Mix_Quit() 
        return false
    }
    
    core.LogInfoFmt("[SDL] SDL_mixer initialized successfully (Flags: %X), audio device opened.", initialized_flags)
    return true
}

// ShutdownSDLMixer cleans up SDL_mixer.
ShutdownSDLMixer :: proc() {
    core.LogInfo("[SDL] Shutting down SDL_mixer...")
    Mix_CloseAudio() 
    Mix_Quit()       
}
