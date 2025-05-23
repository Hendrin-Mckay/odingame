package graphics

import "core:fmt"
import "core:log"
import "core:os"
import "core:strings"
import "../common"
import "./opengl"
import "./vulkan"
import "./directx11" // Changed from "./directx"
import "./metal"

// Backend types supported by the engine
Backend_Type :: enum {
    Auto,    // Automatically select the best backend for the current platform
    OpenGL,  // OpenGL backend
    Vulkan,  // Vulkan backend
    DirectX, // DirectX backend (Windows only) - Now specifically DX11
    Metal,   // Metal backend (Apple platforms only)
}

// Backend preference settings
Backend_Settings :: struct {
    preferred_backend: Backend_Type,
    fallback_order: []Backend_Type,
    debug_mode: bool,
}

// Default backend settings
DEFAULT_BACKEND_SETTINGS :: Backend_Settings {
    preferred_backend = .Auto,
    fallback_order = nil,
    debug_mode = false,
}

// Initialize the graphics backend based on settings
initialize_graphics_backend :: proc(settings: Backend_Settings = DEFAULT_BACKEND_SETTINGS) -> common.Engine_Error {
    backend_to_use := settings.preferred_backend
    
    // If Auto is selected, determine the best backend for the current platform
    if backend_to_use == .Auto {
        backend_to_use = get_best_backend_for_platform()
    }
    
    // Try to initialize the selected backend
    err := initialize_backend(backend_to_use, settings.debug_mode)
    if err == .None {
        log.infof("Successfully initialized %s backend", backend_to_use)
        return .None
    }
    
    // If the preferred backend failed, try fallbacks in order
    if settings.fallback_order != nil {
        for fallback in settings.fallback_order {
            if fallback == backend_to_use {
                continue // Skip the already tried backend
            }
            
            log.infof("Preferred backend %s failed, trying fallback: %s", backend_to_use, fallback)
            err = initialize_backend(fallback, settings.debug_mode)
            if err == .None {
                log.infof("Successfully initialized fallback backend %s", fallback)
                return .None
            }
        }
    }
    
    // All backends failed
    log.errorf("Failed to initialize any graphics backend")
    return .Graphics_Initialization_Failed
}

// Determine the best backend for the current platform
get_best_backend_for_platform :: proc() -> Backend_Type {
    when ODIN_OS == "windows" {
        return .DirectX  // Prefer DirectX on Windows
    } when ODIN_OS == "darwin" {
        return .Metal    // Prefer Metal on macOS/iOS
    } when ODIN_OS == "linux" {
        return .Vulkan   // Prefer Vulkan on Linux
    } else {
        return .OpenGL   // Default to OpenGL for other platforms
    }
}

// Initialize a specific backend
initialize_backend :: proc(backend_type: Backend_Type, debug_mode: bool) -> common.Engine_Error {
    switch backend_type {
    case .OpenGL:
        return opengl.initialize_sdl_opengl_backend(debug_mode)
    case .Vulkan:
        return vulkan.initialize_sdl_vulkan_backend(debug_mode)
    case .DirectX:
        // Changed to directx11 and assuming initialize_d3d11_backend doesn't take debug_mode for now.
        // If debug_mode is needed for DX11, its initialize function signature must be updated.
        return directx11.initialize_d3d11_backend() 
    case .Metal:
        return metal.initialize_sdl_metal_backend(debug_mode)
    case .Auto:
        log.error("Auto should not be passed to initialize_backend")
        return .Invalid_Operation
    }
    
    return .Invalid_Operation
}

// Get the name of the currently active backend
get_active_backend_name :: proc() -> string {
    // This could be expanded to query the actual backend in use
    // For now, we'll just return a placeholder
    return "Unknown"
}
