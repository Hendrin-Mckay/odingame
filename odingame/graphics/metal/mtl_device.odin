package metal

import "../gfx_interface"
import "../../common"
import "./mtl_types" 
import "core:log"
import "core:mem"
import "core:runtime" // For ODIN_OS
import "core:strings" // For strings.contains in sim_objc_msg_send_ptr

// Placeholder for actual Metal and Objective-C framework bindings.
// In a real scenario, this might be:
// import metal "vendor:apple/metal"
// import quartzcore "vendor:apple/quartzcore" // For CAMetalLayer
// import appkit "vendor:apple/appkit"       // For NSWindow, NSView (if not using SDL for windowing)
// import foundation "vendor:apple/foundation" // For NSObject, NSString, etc.
//
// For this exercise, we use the distinct rawptr types from mtl_types.odin
// and simulate success/failure for Objective-C runtime calls.
// We'll assume functions like `objc_get_class`, `objc_msg_send`, `sel_get_uid`
// are available through an Odin Objective-C runtime binding if we were to make real calls.

// Helper to simulate Objective-C message sending for logging purposes.
// In a real implementation, this would use actual Objective-C runtime functions.
@(private)
sim_objc_msg_send_ptr :: proc(obj: rawptr, selector_name: string, args: ..any) -> rawptr {
    log.debugf("Metal Sim: [0x%p %s%s]", obj, selector_name, if len(args) > 0 then " ... (with args)" else "")
    // Simulate returning a new non-nil handle for creation methods
    if strings.contains(selector_name, "new") || 
       strings.contains(selector_name, "DefaultDevice") || 
       strings.contains(selector_name, "Layer") ||
       strings.contains(selector_name, "contentView") || // For NSWindow.contentView
       strings.contains(selector_name, "nextDrawable") { // For CAMetalLayer.nextDrawable
        // Return a slightly different pointer for each call to simulate distinct objects
        // This is a very crude simulation.
        return rawptr(uintptr(cast(int)uintptr(obj) + uintptr(len(selector_name)) + 100 + uintptr(len(args)*10))) 
    }
    return nil
}
@(private)
sim_objc_msg_send_void :: proc(obj: rawptr, selector_name: string, args: ..any) {
    log.debugf("Metal Sim: [0x%p %s%s]", obj, selector_name, if len(args) > 0 then " ... (with args)" else "")
}
@(private)
sim_objc_msg_send_bool :: proc(obj: rawptr, selector_name: string, args: ..any) -> bool {
    log.debugf("Metal Sim: [0x%p %s%s]", obj, selector_name, if len(args) > 0 then " ... (with args)" else "")
    return true // Assume success for boolean setters
}


mtl_create_device_wrapper :: proc(main_allocator_ptr: ^rawptr) -> (gfx_interface.Gfx_Device, common.Engine_Error) {
    allocator := context.allocator
	if main_allocator_ptr != nil && main_allocator_ptr^ != nil {
		allocator = main_allocator_ptr^.(mem.Allocator)
	}

    log.info("Metal: mtl_create_device_wrapper called.")

    // Check OS
    if ODIN_OS != "darwin" {
        log.error("Metal: Backend is only supported on Darwin (macOS, iOS).")
        return gfx_interface.Gfx_Device{}, common.Engine_Error.Graphics_Initialization_Failed
    }

    device_internal := new(Mtl_Device_Internal, allocator)
    device_internal.allocator = allocator

    // 1. Get id<MTLDevice>
    log.info("Metal: Simulating MTLCreateSystemDefaultDevice()...")
    // In real code:
    // mtl_device_obj := metal.MTLCreateSystemDefaultDevice()
    // if mtl_device_obj == nil {
    //     log.error("Metal: MTLCreateSystemDefaultDevice() failed. No suitable Metal device found.")
    //     free(device_internal, allocator)
    //     return gfx_interface.Gfx_Device{}, common.Engine_Error.Device_Creation_Failed
    // }
    // device_internal.device = MTLDevice_Handle(mtl_device_obj)
    simulated_mtl_device := MTLDevice_Handle(sim_objc_msg_send_ptr(nil, "MTLCreateSystemDefaultDevice"))
    if simulated_mtl_device == nil {
        log.error("Metal: MTLCreateSystemDefaultDevice() failed (simulated).")
        free(device_internal, allocator)
        return gfx_interface.Gfx_Device{}, common.Engine_Error.Device_Creation_Failed
    }
    device_internal.device = simulated_mtl_device
    log.infof("Metal: id<MTLDevice> created (simulated: %p).", device_internal.device)

    // 2. Create id<MTLCommandQueue>
    log.info("Metal: Simulating [device newCommandQueue]...")
    // In real code:
    // command_queue_obj := ((^metal.Device)device_internal.device).newCommandQueue() // Assuming binding allows this
    // if command_queue_obj == nil {
    //     log.error("Metal: Failed to create command queue.")
    //     // device_internal.device.release() // If manual ref counting
    //     free(device_internal, allocator)
    //     return gfx_interface.Gfx_Device{}, common.Engine_Error.Device_Creation_Failed
    // }
    // device_internal.command_queue = MTLCommandQueue_Handle(command_queue_obj)
    simulated_command_queue := MTLCommandQueue_Handle(sim_objc_msg_send_ptr(device_internal.device, "newCommandQueue"))
     if simulated_command_queue == nil {
        log.error("Metal: Failed to create command queue (simulated).")
        // No actual device.Release() needed for placeholder
        free(device_internal, allocator)
        return gfx_interface.Gfx_Device{}, common.Engine_Error.Device_Creation_Failed
    }
    device_internal.command_queue = simulated_command_queue
    log.infof("Metal: id<MTLCommandQueue> created (simulated: %p).", device_internal.command_queue)
    
    gfx_device_handle := gfx_interface.Gfx_Device {
        variant = Mtl_Device_Variant(device_internal),
    }
    
    log.info("Metal: Gfx_Device created successfully.")
    return gfx_device_handle, common.Engine_Error.None
}

mtl_destroy_device_wrapper :: proc(device_handle: gfx_interface.Gfx_Device) {
    log.info("Metal: mtl_destroy_device_wrapper called.")
    
    device_internal_ptr, ok := device_handle.variant.(Mtl_Device_Variant)
    if !ok || device_internal_ptr == nil {
        log.error("Metal: mtl_destroy_device_wrapper: Invalid Gfx_Device variant or nil pointer.")
        return
    }

    // In real Metal with ARC, direct Release calls might not be needed if using Odin's objc runtime
    // which could handle ARC. If using raw pointers from C bindings without ARC interop,
    // then explicit [obj release] via objc_msgSend would be necessary.
    // For this stub, we just log.
    if device_internal_ptr.command_queue != nil {
        log.infof("Metal: Releasing id<MTLCommandQueue> (simulated: %p).", device_internal_ptr.command_queue)
		sim_objc_msg_send_void(device_internal_ptr.command_queue, "release")
        device_internal_ptr.command_queue = nil
    }
    if device_internal_ptr.device != nil {
        log.infof("Metal: Releasing id<MTLDevice> (simulated: %p).", device_internal_ptr.device)
		sim_objc_msg_send_void(device_internal_ptr.device, "release")
        device_internal_ptr.device = nil
    }

    free(device_internal_ptr, device_internal_ptr.allocator)
    log.info("Metal: Mtl_Device_Internal struct freed.")
}

mtl_create_window_wrapper :: proc(
    device_handle: gfx_interface.Gfx_Device, 
    title: string, 
    width, height: int,
) -> (gfx_interface.Gfx_Window, common.Engine_Error) {
    log.info("Metal: mtl_create_window_wrapper called.")

    device_internal_ptr := get_device_internal(device_handle) 
    if device_internal_ptr == nil {
        log.error("Metal: mtl_create_window_wrapper: Invalid Gfx_Device.")
        return gfx_interface.Gfx_Window{}, common.Engine_Error.Invalid_Handle
    }
    
    allocator := device_internal_ptr.allocator
    window_internal := new(Mtl_Window_Internal, allocator)
    window_internal.allocator = allocator
    window_internal.device_ref = device_internal_ptr
    window_internal.width = width
    window_internal.height = height

    // 1. Obtain NSWindow* and its contentView (NSView*)
    // This is highly OS-dependent. If using SDL:
    // sdl_window_handle := sdl.CreateWindow(title, x, y, width, height, {.ALLOW_HIGHDPI, .SHOWN} | {.METAL}) 
    // info: sdl.SysWMinfo
    // sdl.GetVersion(&info.version)
    // if sdl.GetWindowWMInfo(sdl_window_handle, &info) {
    //     when ODIN_OS == "darwin" {
    //         // ns_window := info.info.cocoa.window // This is an id (ObjC object pointer)
    //         // ns_view := objc_msg_send_ptr_0(ns_window, sel_get_uid("contentView")) // ns_window.contentView()
    //         // window_internal.view_handle = View_Handle(ns_view)
    //     }
    // } else { log.error("SDL_GetWindowWMInfo failed."); ... cleanup ... return error; }
    // For this stub:
    simulated_ns_window_ptr := rawptr(uintptr(0x200)) // Placeholder for NSWindow* or SDL_Window*
    // If using SDL, one would get the NSView from SDL_Metal_GetLayer / SDL_Metal_CreateView
    // For now, directly simulate getting a view_handle.
    window_internal.view_handle = View_Handle(sim_objc_msg_send_ptr(simulated_ns_window_ptr, "contentView_placeholder_or_SDL_Metal_GetView"))
    if window_internal.view_handle == nil {
        log.error("Metal: Failed to get window's contentView/view (simulated).")
        free(window_internal, allocator)
        return gfx_interface.Gfx_Window{}, common.Engine_Error.Window_Creation_Failed
    }
    log.infof("Metal: Obtained NSWindow and contentView (simulated: view %p).", window_internal.view_handle)


    // 2. Create CAMetalLayer
    log.info("Metal: Simulating CAMetalLayer creation ([CAMetalLayer layer])...")
    // In real code:
    // metal_layer_class := objc_get_class("CAMetalLayer") // Needs ObjC runtime
    // metal_layer_obj := objc_msg_send_ptr_0(metal_layer_class, sel_get_uid("layer")) // [CAMetalLayer layer]
    simulated_metal_layer := CAMetalLayer_Handle(sim_objc_msg_send_ptr(nil, "CAMetalLayer_layer"))
    if simulated_metal_layer == nil {
        log.error("Metal: Failed to create CAMetalLayer (simulated).")
        // Potentially destroy view_handle if it was created here
        free(window_internal, allocator)
        return gfx_interface.Gfx_Window{}, common.Engine_Error.Window_Creation_Failed
    }
    window_internal.metal_layer = simulated_metal_layer
    log.infof("Metal: CAMetalLayer created (simulated: %p).", window_internal.metal_layer)

    // 3. Configure CAMetalLayer
    sim_objc_msg_send_void(window_internal.metal_layer, "setDevice:", device_internal_ptr.device)
    // Common pixel format, typically BGRA8Unorm or RGBA16Float for HDR.
    // MTLPixelFormatBGRA8Unorm = 80
    sim_objc_msg_send_void(window_internal.metal_layer, "setPixelFormat:", uintptr(80)) 
    window_internal.format = .RGBA8 // Closest GfxFormat, though Metal uses BGRA for display typically.
                                     // This mapping might need adjustment.
    
    sim_objc_msg_send_bool(window_internal.metal_layer, "setFramebufferOnly:", true)
    
    // Set drawable size (important for Retina displays)
    // In real code, one would get scale factor from screen and multiply width/height.
    // e.g. drawable_size = CGSize{f64(width) * scale, f64(height) * scale}
    // For stub, use width/height directly.
    sim_objc_msg_send_void(window_internal.metal_layer, "setDrawableSize_width_height:", uintptr(width), uintptr(height)) 
    log.info("Metal: CAMetalLayer configured (simulated).")

    // 4. Associate layer with window's view
    // If view_handle is an NSView*:
    // [view_handle setLayer: metal_layer_obj]
    // [view_handle setWantsLayer: YES]
    sim_objc_msg_send_void(window_internal.view_handle, "setWantsLayer:", true)
    sim_objc_msg_send_void(window_internal.view_handle, "setLayer:", window_internal.metal_layer)
    log.info("Metal: CAMetalLayer associated with view (simulated).")
    
    gfx_window_handle := gfx_interface.Gfx_Window {
        variant = Mtl_Window_Variant(window_internal),
    }
    log.info("Metal: Gfx_Window created successfully.")
    return gfx_window_handle, common.Engine_Error.None
}

mtl_destroy_window_wrapper :: proc(window_handle: gfx_interface.Gfx_Window) {
    log.info("Metal: mtl_destroy_window_wrapper called.")
    window_internal_ptr := get_window_internal(window_handle) 
    if window_internal_ptr == nil {
        log.error("Metal: mtl_destroy_window_wrapper: Invalid Gfx_Window variant.")
        return
    }

    if window_internal_ptr.metal_layer != nil {
        log.infof("Metal: Releasing CAMetalLayer (simulated: %p).", window_internal_ptr.metal_layer)
        // If view_handle.layer == metal_layer, then view_handle.setLayer(nil)
        // This might be done by SDL_Metal_DestroyView if SDL is used.
        if window_internal_ptr.view_handle != nil {
             sim_objc_msg_send_void(window_internal_ptr.view_handle, "setLayer:", nil)
        }
        sim_objc_msg_send_void(window_internal_ptr.metal_layer, "release")
        window_internal_ptr.metal_layer = nil
    }

    // If NSWindow/View was created by us (not by SDL), destroy it.
    // If view_handle came from SDL, SDL_DestroyWindow handles it.
    log.info("Metal: NSWindow/View released or managed externally (simulated).")

    free(window_internal_ptr, window_internal_ptr.allocator)
    log.info("Metal: Mtl_Window_Internal struct freed.")
}

// --- Stubs for other functions from Gfx_Device_Interface ---
// These would need actual Metal implementations.

begin_frame_impl :: proc(device: gfx_interface.Gfx_Device) { 
    log.debug("Metal: begin_frame_impl (stub)")
    // Real Metal: 
    // - Get next drawable from CAMetalLayer (stored in Mtl_Window_Internal.current_drawable)
    // - Create command buffer from command queue ([command_queue commandBuffer])
}

end_frame_impl :: proc(device: gfx_interface.Gfx_Device) { 
    log.debug("Metal: end_frame_impl (stub)")
    // Real Metal: 
    // - Commit command buffer ([command_buffer commit])
    // - (If drawable was obtained) Present drawable ([command_buffer presentDrawable: drawable])
    // - (Wait for command buffer completion if needed for synchronization: [command_buffer waitUntilCompleted])
}

clear_screen_impl :: proc(device: gfx_interface.Gfx_Device, options: gfx_interface.Clear_Options) { 
    log.warn("Metal: clear_screen_impl not implemented")
    // Real Metal: 
    // - Get current command buffer.
    // - Create MTLRenderPassDescriptor.
    // - Configure colorAttachment[0].texture = current_drawable.texture.
    // - Set colorAttachment[0].loadAction = .Clear.
    // - Set colorAttachment[0].clearColor = MTLClearColorMake(...).
    // - Create MTLRenderCommandEncoder: [command_buffer renderCommandEncoderWithDescriptor: desc].
    // - [render_encoder endEncoding]. (Clearing happens at start of pass).
}

set_viewport_impl :: proc(device: gfx_interface.Gfx_Device, x, y, width, height: i32) -> common.Engine_Error {
    log.warn("Metal: set_viewport_impl not implemented")
    // Real Metal: [render_encoder setViewport: MTLViewport{...}]
    return .Not_Implemented
}

set_scissor_impl :: proc(device: gfx_interface.Gfx_Device, x, y, width, height: i32) -> common.Engine_Error {
    log.warn("Metal: set_scissor_impl not implemented")
    // Real Metal: [render_encoder setScissorRect: MTLScissorRect{...}]
    return .Not_Implemented
}

disable_scissor_impl :: proc(device: gfx_interface.Gfx_Device) -> common.Engine_Error {
    log.warn("Metal: disable_scissor_impl not implemented")
    // Real Metal: Set scissor rect to cover the entire viewport/drawable.
    return .Not_Implemented
}

present_window :: proc(window: gfx_interface.Gfx_Window) -> common.Engine_Error {
    log.debug("Metal: present_window (stub)")
    // This is usually part of end_frame_impl (commit and present drawable)
    // If called separately, it might just mean "ensure frame is ready for presentation queue"
    // For now, assume end_frame_impl handles presentation.
    return .None // Or .Not_Implemented if it has a distinct meaning.
}
resize_window :: proc(window: gfx_interface.Gfx_Window, width, height: int) -> common.Engine_Error {
    log.warn("Metal: resize_window not implemented")
    // Get Mtl_Window_Internal.
    // Update metal_layer.drawableSize = CGSize{f64(width)*scale, f64(height)*scale}
    // Update internal width/height.
    return .Not_Implemented
}
get_window_size :: proc(window: gfx_interface.Gfx_Window) -> (w,h: int) {
    log.warn("Metal: get_window_size not implemented")
    if win_internal_ptr := get_window_internal(window); win_internal_ptr != nil {
        return win_internal_ptr.width, win_internal_ptr.height // This should be logical size
    }
    return 0,0
}
get_window_drawable_size :: proc(window: gfx_interface.Gfx_Window) -> (w,h: int) {
    log.warn("Metal: get_window_drawable_size not implemented")
     if win_internal_ptr := get_window_internal(window); win_internal_ptr != nil {
        // This should return the pixel dimensions of the CAMetalLayer's drawable.
        // For stub, return stored width/height which might be updated on resize.
        return win_internal_ptr.width, win_internal_ptr.height 
    }
    return 0,0
}
set_window_title :: proc(window: gfx_interface.Gfx_Window, title: string) -> common.Engine_Error {
    log.warn("Metal: set_window_title not implemented")
    // If view_handle is an NSWindow or obtained via SDL, set title there.
    return .Not_Implemented
}
