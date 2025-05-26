package sdl

// This module will manage SDL initialization and shutdown.
// It will utilize Odin's `context` and `defer` features
// for robust resource management.

// TODO:
// - Define SDLContext struct if needed.
// - Implement InitSDL() proc.
//   - Initialize SDL video, audio, etc.
//   - Store SDL_Window and SDL_Renderer if created here, or manage them separately.
// - Implement ShutdownSDL() proc.
//   - Clean up SDL resources.
//   - Ensure this is called via `defer` when the context is destroyed.

// Example of how context might be used:
// sdl_system: SDL_System_Context
// init_sdl_system :: proc() -> (context, bool) {
//     // ... initialization ...
//     context.sdl_system = sdl_system
//     return context, true
// }
// main :: proc() {
//     context, ok := init_sdl_system()
//     if !ok { return }
//     // ... use context.sdl_system ...
// }
