package graphics

import "../core" // For core.Game (forward declared or actual if no cycle)
import "../common"
import "core:log"
import "core:fmt" // For logging errors
import "vendor:sdl2" // For window creation and VSync settings

// Graphics_Device_Manager is responsible for configuring and managing the Graphics_Device
// and the main Game_Window.
Graphics_Device_Manager :: struct {
    game:                    ^core.Game, // Back reference to the game
    graphics_device:         ^Graphics_Device, 

    preferred_back_buffer_width:  int,
    preferred_back_buffer_height: int,
    preferred_back_buffer_format: Surface_Format,
    preferred_depth_stencil_format: Depth_Format,
    is_full_screen:               bool,
    synchronize_with_vertical_retrace: bool, // VSync

    // Internal state
    _is_initialized: bool,      // Whether CreateDevice has been called
    _begin_draw_called: bool,   // For XNA compatibility, tracks BeginDraw/EndDraw pairing
}

// new_graphics_device_manager creates a new GraphicsDeviceManager.
new_graphics_device_manager :: proc(game_instance: ^core.Game) -> ^Graphics_Device_Manager {
    gdm := new(Graphics_Device_Manager)
    gdm.game = game_instance
    
    // Default preferences (typical XNA defaults)
    gdm.preferred_back_buffer_width = 800
    gdm.preferred_back_buffer_height = 600
    gdm.preferred_back_buffer_format = .Color
    gdm.preferred_depth_stencil_format = .Depth24_Stencil8 // Common default
    gdm.is_full_screen = false
    gdm.synchronize_with_vertical_retrace = true // VSync on by default

    gdm._is_initialized = false
    gdm._begin_draw_called = false
    
    log.info("GraphicsDeviceManager created.")
    return gdm
}

// apply_changes applies any pending configuration changes to the graphics device and window.
// This is where the actual device and window are created or reconfigured.
apply_changes :: proc(gdm: ^Graphics_Device_Manager) -> (err: common.Engine_Error) {
    if gdm == nil {
        log.error("apply_changes: GraphicsDeviceManager is nil.")
        return .Invalid_Parameter
    }
    log.info("GraphicsDeviceManager: Applying changes...")
    
    // --- SDL Window Creation/Update (Simplified for now) ---
    // In a full XNA model, window management might be more separate, but GDM often handles it.
    // This part assumes SDL is initialized (usually done at the start of Game.Run).
    
    sdl_window_handle: ^sdl2.Window
    is_new_window := false

    if gdm.graphics_device == nil || gdm.graphics_device._sdl_window == nil {
        log.info("GDM: Creating new SDL window and Graphics_Device.")
        is_new_window = true
        
        window_title := gdm.game != nil ? gdm.game.window_title_base : "OdinGame" // Get title from Game
        window_flags: u32 = sdl2.WINDOW_SHOWN
        // Backend will add its specific flags (e.g. OPENGL, VULKAN_SURFACE)
        // For now, assume gfx_api.create_window handles this.

        sdl_window_handle = sdl2.CreateWindow(window_title, 
                                            sdl2.WINDOWPOS_CENTERED, sdl2.WINDOWPOS_CENTERED,
                                            gdm.preferred_back_buffer_width, 
                                            gdm.preferred_back_buffer_height, 
                                            window_flags)
        if sdl_window_handle == nil {
            log.errorf("GDM: SDL_CreateWindow failed: %s", sdl2.GetError())
            return .Window_Creation_Failed
        }
        
        // Allocate Graphics_Device if it doesn't exist
        if gdm.graphics_device == nil {
            // Assuming game.allocator is accessible or context.allocator
            allocator := context.allocator 
            if gdm.game != nil { allocator = gdm.game.allocator_ref } // Use game's allocator if available
            gdm.graphics_device = new(Graphics_Device, allocator)
        }
        gdm.graphics_device._sdl_window = sdl_window_handle
    } else {
        sdl_window_handle = cast(^sdl2.Window)gdm.graphics_device._sdl_window
        log.info("GDM: Using existing SDL window.")
        // TODO: Handle window resizing: sdl2.SetWindowSize, etc.
        // TODO: Handle fullscreen toggle: sdl2.SetWindowFullscreen
    }

    // --- Graphics Backend and Device Initialization ---
    // This part uses the gfx_interface layer.
    // Backend selection and initialization should happen here if not already done.
    // For now, assume graphics.initialize_graphics_backend was called by Game.Run earlier.
    
    // If it's a new device or window, or if settings changed significantly
    if is_new_window || /* settings changed */ false {
        // If device exists, destroy old Gfx_Window and Gfx_Device first
        if gdm.graphics_device._gfx_device.variant != nil {
             _graphics_device_destroy_internal_handles(gdm.graphics_device) // Destroys _gfx_window and _gfx_device
        }

        // Create low-level Gfx_Device
        // The allocator should be passed from the game or a global context.
        alloc := context.allocator; if gdm.game != nil { alloc = gdm.game.allocator_ref }
        gfx_dev, dev_err := gfx_api.create_device(&alloc)
        if dev_err != .None {
            log.errorf("GDM: gfx_api.create_device failed: %v", dev_err)
            // SDL window was created, needs cleanup if we bail here.
            if is_new_window && sdl_window_handle != nil { sdl2.DestroyWindow(sdl_window_handle) }
            gdm.graphics_device._sdl_window = nil // Null out to prevent double free if GDM is destroyed later
            return dev_err
        }
        gdm.graphics_device._gfx_device = gfx_dev
        gdm.graphics_device._backend_type = gfx_api.query_backend_type(gfx_dev)

        // Create low-level Gfx_Window (associates with the SDL window and Gfx_Device)
        // The Gfx_Window needs the SDL window handle (as rawptr for abstraction)
        // and other parameters.
        window_title_for_gfx := sdl2.GetWindowTitle(sdl_window_handle) // Get current title
        defer free(window_title_for_gfx, context.temp_allocator) // Free C-string

        gfx_win, win_err := gfx_api.create_window(
            gdm.graphics_device._gfx_device,
            gdm.graphics_device._sdl_window, // Pass SDL window handle
            string(window_title_for_gfx), // Title
            gdm.preferred_back_buffer_width,
            gdm.preferred_back_buffer_height,
            gdm.synchronize_with_vertical_retrace, // VSync
        )
        if win_err != .None {
            log.errorf("GDM: gfx_api.create_window failed: %v", win_err)
            gfx_api.destroy_device(gdm.graphics_device._gfx_device)
            if is_new_window && sdl_window_handle != nil { sdl2.DestroyWindow(sdl_window_handle) }
            gdm.graphics_device._sdl_window = nil
            gdm.graphics_device._gfx_device = {}
            return win_err
        }
        gdm.graphics_device._gfx_window = gfx_win
    }
    
    // Update Present_Parameters on the Graphics_Device
    gdm.graphics_device.present_params = Present_Parameters {
        back_buffer_width    = gdm.preferred_back_buffer_width,
        back_buffer_height   = gdm.preferred_back_buffer_height,
        back_buffer_format   = gdm.preferred_back_buffer_format,
        depth_stencil_format = gdm.preferred_depth_stencil_format,
        is_full_screen       = gdm.is_full_screen,
        vsync                = gdm.synchronize_with_vertical_retrace,
    }

    // Set initial viewport to full window size
    initial_viewport := Viewport {
        x = 0, y = 0,
        width = gdm.preferred_back_buffer_width,
        height = gdm.preferred_back_buffer_height,
        min_depth = 0.0, max_depth = 1.0,
    }
    graphics_device_set_viewport(gdm.graphics_device, initial_viewport)
    
    gdm._is_initialized = true
    log.info("GraphicsDeviceManager: Changes applied successfully.")
    return .None
}


// toggle_fullscreen attempts to switch between fullscreen and windowed mode.
toggle_fullscreen :: proc(gdm: ^Graphics_Device_Manager) {
    if gdm == nil { return }
    gdm.is_full_screen = !gdm.is_full_screen
    log.infof("GDM: Toggling fullscreen preference to: %t. Call Apply_Changes() to take effect.", gdm.is_full_screen)
    // apply_changes(gdm) // Optionally apply immediately. XNA requires explicit Apply_Changes.
}

// destroy_graphics_device_manager cleans up resources owned by GDM.
// This primarily means destroying the Graphics_Device it manages.
// The SDL window is assumed to be owned by the Game instance or a higher-level window manager.
destroy_graphics_device_manager :: proc(gdm: ^Graphics_Device_Manager) {
    if gdm == nil { return }
    log.info("Destroying GraphicsDeviceManager...")
    if gdm.graphics_device != nil {
        // This destroys _gfx_device and _gfx_window
        _graphics_device_destroy_internal_handles(gdm.graphics_device) 
        
        // The SDL_Window handle (_sdl_window) stored in Graphics_Device is NOT destroyed here.
        // It's owned by the Game's main loop or a dedicated Windowing class.
        // GDM only uses it.
        
        // Free the Graphics_Device struct itself
        allocator := context.allocator
        if gdm.game != nil { allocator = gdm.game.allocator_ref }
        free(gdm.graphics_device, allocator) 
        gdm.graphics_device = nil
    }
    // Free the GDM struct itself using the allocator from its game instance or context
    allocator := context.allocator
    if gdm.game != nil { allocator = gdm.game.allocator_ref }
    free(gdm, allocator)
    log.info("GraphicsDeviceManager destroyed.")
}

// begin_draw is called by Game before drawing.
// In XNA, this is where the device might be checked for readiness.
// For now, it's a simple flag setter.
begin_draw :: proc(gdm: ^Graphics_Device_Manager) -> bool {
    if gdm == nil || gdm.graphics_device == nil {
        log.error("GDM.BeginDraw: GraphicsDeviceManager or Graphics_Device is nil.")
        return false
    }
    if gdm._begin_draw_called {
        log.error("GDM.BeginDraw: BeginDraw already called. Call EndDraw first.")
        return false // Or panic
    }
    gdm._begin_draw_called = true
    // In XNA, this might also handle device lost/reset scenarios.
    return true
}

// end_draw is called by Game after drawing.
// It presents the back buffer.
end_draw :: proc(gdm: ^Graphics_Device_Manager) {
    if gdm == nil || gdm.graphics_device == nil {
        log.error("GDM.EndDraw: GraphicsDeviceManager or Graphics_Device is nil.")
        return
    }
    if !gdm._begin_draw_called {
        log.error("GDM.EndDraw: EndDraw called without a matching BeginDraw.")
        return // Or panic
    }
    
    graphics_device_present(gdm.graphics_device)
    
    gdm._begin_draw_called = false
}
