package metal

import "../gfx_interface"
import "../../common"
import "./mtl_types" 
import "core:log"
import "core:mem"
import "core:runtime" // For ODIN_OS
import "core:strings" // For CString and strings.contains
import "core:strconv" // For f64_to_string etc. for logging
import "core:math"    // For math.clamp

// --- Simulated Objective-C Messaging & Metal Types (Conceptual) ---
// These are placeholders for actual Objective-C message sending and some Metal types.

// Handles are distinct rawptr, defined in mtl_types.odin
// MTLCommandBuffer_Handle :: distinct rawptr 
// MTLRenderPassDescriptor_Handle :: distinct rawptr 
// MTLRenderCommandEncoder_Handle :: distinct rawptr
// MTLTexture_Handle :: distinct rawptr 
// NSWindow_Handle :: distinct rawptr
// NSString_Handle :: distinct rawptr


// --- Simulated Metal Structs (for parameters) ---
// These would be actual structs in Metal headers.
MTLViewport :: struct {
    originX, originY, width, height, znear, zfar: f64,
}
MTLScissorRect :: struct {
    x, y, width, height: u32, // Metal uses uint for these
}
CGSize :: struct { // CoreGraphics size, often used in Metal
    width, height: f64,
}


// Simulates [object selector] returning a new object (rawptr).
sim_objc_msg_send_ret_ptr :: proc(obj: rawptr, selector: cstring, args: ..any) -> rawptr {
	log.debugf("SIM_OBJC_MSG_SEND_RET_PTR: obj %p, selector '%s'", obj, selector)
	switch selector {
	case "nextDrawable": 
		if obj == nil { return nil }
		return rawptr(uintptr(0xCAFE0001)) // Dummy CAMetalDrawable
	case "commandBuffer": 
		if obj == nil { return nil }
		return rawptr(uintptr(0xABCD0002)) // Dummy MTLCommandBuffer
	case "renderPassDescriptor": // Class method usually
		return rawptr(uintptr(0xBCDE0003)) // Dummy MTLRenderPassDescriptor
	case "renderCommandEncoderWithDescriptor:": 
		if obj == nil || (len(args) > 0 && args[0] == nil) { return nil }
		return rawptr(uintptr(0xCDEF0004)) // Dummy MTLRenderCommandEncoder
	case "texture": // For CAMetalDrawable
		if obj == nil { return nil }
		return rawptr(uintptr(0xDEFA0005)) // Dummy MTLTexture
    case "window": // For NSView (conceptual, if view_handle were NSView)
        if obj == nil { return nil }
        return rawptr(uintptr(0xEFAB0006)) // Dummy NSWindow
    case "stringWithUTF8String:": // For NSString class
        // args[0] would be cstring
        return rawptr(uintptr(0xFABC0007)) // Dummy NSString
    case "contentView": // For NSWindow
        if obj == nil { return nil }
        return rawptr(uintptr(0xABBA0008)) // Dummy NSView
    case "layer": // For NSView
        if obj == nil { return nil }
        return rawptr(uintptr(0xBAAB0009)) // Dummy CALayer (could be CAMetalLayer)
    case "MTLCreateSystemDefaultDevice": // Global function
        return rawptr(uintptr(0xDADA000A)) // Dummy MTLDevice
    case "newCommandQueue": // For MTLDevice
        if obj == nil { return nil }
        return rawptr(uintptr(0xADAD000B)) // Dummy MTLCommandQueue
    // CAMetalLayer layer class method for creating a layer
    case "layer": 
        // Check if obj is nil (meaning class method) or if it's an instance for an instance `layer` property
        if obj == nil { // Simulating [CAMetalLayer layer]
             return rawptr(uintptr(0xBABA000C)) // Dummy CAMetalLayer
        }
        // If obj is not nil, it might be some other object's "layer" property
        log.warnf("SIM_OBJC_MSG_SEND_RET_PTR: Unhandled 'layer' selector on existing object %p", obj)
        return nil
	}
	log.warnf("SIM_OBJC_MSG_SEND_RET_PTR: Unhandled selector '%s', returning nil.", selector)
	return nil
}

// Simulates [object selector] returning void.
sim_objc_msg_send_void :: proc(obj: rawptr, selector: cstring, args: ..any) {
    // Log with more detail for specific selectors if needed
    switch selector {
    case "setViewport:":
        // First arg is a pointer to MTLViewport
        if len(args) > 0 && args[0] != nil {
            vp := (^MTLViewport)(args[0])^
            log.debugf("SIM_OBJC_MSG_SEND_VOID: obj %p, selector '%s', viewport: {x:%v, y:%v, w:%v, h:%v, near:%v, far:%v}", 
                obj, selector, vp.originX, vp.originY, vp.width, vp.height, vp.znear, vp.zfar)
        } else {
            log.debugf("SIM_OBJC_MSG_SEND_VOID: obj %p, selector '%s' (args: %v) - Args error or nil", obj, selector, args)
        }
    case "setScissorRect:":
        // First arg is a pointer to MTLScissorRect
         if len(args) > 0 && args[0] != nil {
            rect := (^MTLScissorRect)(args[0])^
            log.debugf("SIM_OBJC_MSG_SEND_VOID: obj %p, selector '%s', scissor_rect: {x:%v, y:%v, w:%v, h:%v}", 
                obj, selector, rect.x, rect.y, rect.width, rect.height)
        } else {
            log.debugf("SIM_OBJC_MSG_SEND_VOID: obj %p, selector '%s' (args: %v) - Args error or nil", obj, selector, args)
        }
    case "setDrawableSize:": // For CAMetalLayer (takes CGSize by value, often split)
        if len(args) == 2 { // Assuming width, height passed as separate args
             log.debugf("SIM_OBJC_MSG_SEND_VOID: obj %p, selector '%s', drawableSize: {w:%v, h:%v}", obj, selector, args[0], args[1])
        } else {
             log.debugf("SIM_OBJC_MSG_SEND_VOID: obj %p, selector '%s' (args: %v) - Args error for drawableSize", obj, selector, args)
        }
    case "setTitle:": // For NSWindow
        // args[0] is NSString_Handle
        log.debugf("SIM_OBJC_MSG_SEND_VOID: obj %p, selector '%s', title_nsstring: %p", obj, selector, args[0])
    case "release":
         log.debugf("SIM_OBJC_MSG_SEND_VOID: obj %p, selector '%s' (simulated release)", obj, selector)
    case "setDevice:": fallthrough
    case "setPixelFormat:": fallthrough
    case "setFramebufferOnly:": fallthrough
    case "setWantsLayer:": fallthrough
    case "setLayer:": fallthrough
    case "presentDrawable:": fallthrough
    case "commit": fallthrough
    case "endEncoding":
	    log.debugf("SIM_OBJC_MSG_SEND_VOID: obj %p, selector '%s' (args: %v)", obj, selector, args)
    case:
        log.debugf("SIM_OBJC_MSG_SEND_VOID: obj %p, selector '%s' (args: %v) - Unhandled detail log", obj, selector, args)
    }
}

// Simulates [object selector] returning a bool.
sim_objc_msg_send_ret_bool :: proc(obj: rawptr, selector: cstring, args: ..any) -> bool {
    log.debugf("SIM_OBJC_MSG_SEND_RET_BOOL: obj %p, selector '%s'", obj, selector)
    return true // Assume success for boolean setters/getters
}

// Simulates [MTLRenderPassDescriptor new] or [MTLRenderPassDescriptor renderPassDescriptor]
sim_mtl_render_pass_descriptor_new :: proc() -> MTLRenderPassDescriptor_Handle {
    log.debug("SIM_MTL_RENDER_PASS_DESCRIPTOR_NEW")
    return MTLRenderPassDescriptor_Handle(uintptr(0xABCD0001)) 
}
sim_mtl_render_pass_descriptor_get_color_attachment :: proc(desc: MTLRenderPassDescriptor_Handle, index: int) -> rawptr {
    log.debugf("SIM_MTL_RENDER_PASS_DESCRIPTOR_GET_COLOR_ATTACHMENT: desc %p, index %d", desc, index)
    return rawptr(uintptr(desc) + uintptr(index * 16)) 
}
sim_mtl_color_attachment_set_texture :: proc(attachment_obj: rawptr, texture: MTLTexture_Handle) {
    log.debugf("SIM_MTL_COLOR_ATTACHMENT_SET_TEXTURE: attachment %p, texture %p", attachment_obj, texture)
}
sim_mtl_color_attachment_set_load_action :: proc(attachment_obj: rawptr, action: int) { 
    log.debugf("SIM_MTL_COLOR_ATTACHMENT_SET_LOAD_ACTION: attachment %p, action %d", attachment_obj, action)
}
sim_mtl_color_attachment_set_store_action :: proc(attachment_obj: rawptr, action: int) { 
    log.debugf("SIM_MTL_COLOR_ATTACHMENT_SET_STORE_ACTION: attachment %p, action %d", attachment_obj, action)
}
sim_mtl_color_attachment_set_clear_color :: proc(attachment_obj: rawptr, r, g, b, a: f64) {
    log.debugf("SIM_MTL_COLOR_ATTACHMENT_SET_CLEAR_COLOR: attachment %p, color (%f,%f,%f,%f)", attachment_obj, r, g, b, a)
}

// Simulates [object drawableSize] returning CGSize
sim_objc_msg_send_ret_cgsize :: proc(obj: rawptr, selector: cstring) -> CGSize {
    log.debugf("SIM_OBJC_MSG_SEND_RET_CGSIZE: obj %p, selector '%s'", obj, selector)
    // This needs to get actual size from Mtl_Window_Internal for realistic simulation
    // For now, a dummy size. A real version would look up the Mtl_Window_Internal.
    return CGSize{width=640, height=480} 
}


MTLLoadActionClear    :: 0
MTLLoadActionLoad     :: 1
MTLLoadActionDontCare :: 2
MTLStoreActionStore   :: 0
MTLStoreActionDontCare:: 1


// --- Helper Functions ---
get_device_internal :: proc(device_handle: gfx_interface.Gfx_Device) -> (dev_ptr: ^Mtl_Device_Internal, err: common.Engine_Error) {
    if device_handle.variant == nil {
        log.error("get_device_internal: Gfx_Device variant is nil.")
        return nil, .Invalid_Handle
    }
    dev_ptr_cast, ok := device_handle.variant.(^Mtl_Device_Internal)
    if !ok || dev_ptr_cast == nil {
        log.errorf("get_device_internal: Invalid Gfx_Device variant type (%T) or nil pointer.", device_handle.variant)
        return nil, .Invalid_Handle
    }
    if dev_ptr_cast.device == nil || dev_ptr_cast.command_queue == nil {
        log.error("get_device_internal: Mtl_Device_Internal contains nil device or command_queue.")
        return nil, .Not_Initialized 
    }
    return dev_ptr_cast, .None
}

get_window_internal :: proc(window_handle: gfx_interface.Gfx_Window) -> (win_ptr: ^Mtl_Window_Internal, err: common.Engine_Error) {
    if window_handle.variant == nil {
        log.error("get_window_internal: Gfx_Window variant is nil.")
        return nil, .Invalid_Handle
    }
    win_ptr_cast, ok := window_handle.variant.(^Mtl_Window_Internal)
    if !ok || win_ptr_cast == nil {
        log.errorf("get_window_internal: Invalid Gfx_Window variant type (%T) or nil pointer.", window_handle.variant)
        return nil, .Invalid_Handle
    }
    if win_ptr_cast.metal_layer == nil {
        log.error("get_window_internal: Mtl_Window_Internal contains nil metal_layer.")
        return nil, .Not_Initialized
    }
    return win_ptr_cast, .None
}

// --- Device and Window Management (Stubs from previous subtask, may need actual implementation later) ---
mtl_create_device_wrapper :: proc(main_allocator_ptr: ^rawptr) -> (gfx_interface.Gfx_Device, common.Engine_Error) {
    // ... (Implementation from previous subtask, assumed correct for now)
    allocator := context.allocator
	if main_allocator_ptr != nil && main_allocator_ptr^ != nil {
		allocator = main_allocator_ptr^.(mem.Allocator)
	}
    log.info("Metal: mtl_create_device_wrapper called.")
    if ODIN_OS != "darwin" {
        log.error("Metal: Backend is only supported on Darwin (macOS, iOS).")
        return gfx_interface.Gfx_Device{}, common.Engine_Error.Graphics_Initialization_Failed
    }
    device_internal := new(Mtl_Device_Internal, allocator)
    device_internal.allocator = allocator
    simulated_mtl_device := MTLDevice_Handle(sim_objc_msg_send_ret_ptr(nil, "MTLCreateSystemDefaultDevice"))
    if simulated_mtl_device == nil {
        log.error("Metal: MTLCreateSystemDefaultDevice() failed (simulated).")
        free(device_internal, allocator)
        return gfx_interface.Gfx_Device{}, common.Engine_Error.Device_Creation_Failed
    }
    device_internal.device = simulated_mtl_device
    log.infof("Metal: id<MTLDevice> created (simulated: %p).", device_internal.device)
    simulated_command_queue := MTLCommandQueue_Handle(sim_objc_msg_send_ret_ptr(device_internal.device, "newCommandQueue"))
     if simulated_command_queue == nil {
        log.error("Metal: Failed to create command queue (simulated).")
        free(device_internal, allocator)
        return gfx_interface.Gfx_Device{}, common.Engine_Error.Device_Creation_Failed
    }
    device_internal.command_queue = simulated_command_queue
    log.infof("Metal: id<MTLCommandQueue> created (simulated: %p).", device_internal.command_queue)
    gfx_device_handle := gfx_interface.Gfx_Device { variant = Mtl_Device_Variant(device_internal) }
    log.info("Metal: Gfx_Device created successfully.")
    return gfx_device_handle, common.Engine_Error.None
}

mtl_destroy_device_wrapper :: proc(device_handle: gfx_interface.Gfx_Device) { // Should return common.Engine_Error
    log.info("Metal: mtl_destroy_device_wrapper called.")
    dev_internal, err := get_device_internal(device_handle)
    if err != .None { log.errorf("Metal: mtl_destroy_device_wrapper: %v", err); return }

    if dev_internal.command_queue != nil {
        log.infof("Metal: Releasing id<MTLCommandQueue> (simulated: %p).", dev_internal.command_queue)
		sim_objc_msg_send_void(dev_internal.command_queue, "release")
        dev_internal.command_queue = nil
    }
    if dev_internal.device != nil {
        log.infof("Metal: Releasing id<MTLDevice> (simulated: %p).", dev_internal.device)
		sim_objc_msg_send_void(dev_internal.device, "release")
        dev_internal.device = nil
    }
    free(dev_internal, dev_internal.allocator)
    log.info("Metal: Mtl_Device_Internal struct freed.")
}

mtl_create_window_wrapper :: proc( device_handle: gfx_interface.Gfx_Device, title: string, width, height: int, ) -> (gfx_interface.Gfx_Window, common.Engine_Error) {
    // ... (Implementation from previous subtask, assumed correct for now) ...
    log.info("Metal: mtl_create_window_wrapper called.")
    dev_internal, err := get_device_internal(device_handle) 
    if err != .None {
        log.errorf("Metal: mtl_create_window_wrapper: Invalid Gfx_Device: %v", err)
        return gfx_interface.Gfx_Window{}, err
    }
    allocator := dev_internal.allocator
    win_internal := new(Mtl_Window_Internal, allocator)
    win_internal.allocator = allocator
    win_internal.device_ref = dev_internal
    win_internal.width = width
    win_internal.height = height
    // Simulate NSWindow and NSView creation/retrieval
    win_internal.ns_window_handle = NSWindow_Handle(sim_objc_msg_send_ret_ptr(nil, "NSWindow_alloc_initWithContentRect_styleMask_backing_defer")) // Simplified
    if win_internal.ns_window_handle == nil { /* error */ }
    win_internal.view_handle = View_Handle(sim_objc_msg_send_ret_ptr(rawptr(win_internal.ns_window_handle), "contentView"))
    if win_internal.view_handle == nil { /* error */ }

    simulated_metal_layer := CAMetalLayer_Handle(sim_objc_msg_send_ret_ptr(nil, "layer")) // Simulating [CAMetalLayer layer]
    if simulated_metal_layer == nil { /* error */ }
    win_internal.metal_layer = simulated_metal_layer
    sim_objc_msg_send_void(win_internal.metal_layer, "setDevice:", dev_internal.device)
    sim_objc_msg_send_void(win_internal.metal_layer, "setPixelFormat:", uintptr(80)) // BGRA8Unorm
    win_internal.format = .RGBA8 
    sim_objc_msg_send_bool(win_internal.metal_layer, "setFramebufferOnly:", true)
    sim_objc_msg_send_void(win_internal.metal_layer, "setDrawableSize:", f64(width), f64(height))
    sim_objc_msg_send_void(win_internal.view_handle, "setWantsLayer:", true)
    sim_objc_msg_send_void(win_internal.view_handle, "setLayer:", win_internal.metal_layer)
    
    // Set this window as primary (simplification from previous subtask)
    dev_internal.primary_window = win_internal

    gfx_window_handle := gfx_interface.Gfx_Window { variant = Mtl_Window_Variant(win_internal) }
    log.info("Metal: Gfx_Window created successfully.")
    return gfx_window_handle, common.Engine_Error.None
}

mtl_destroy_window_wrapper :: proc(window_handle: gfx_interface.Gfx_Window) { // Should return common.Engine_Error
    // ... (Implementation from previous subtask, assumed correct for now) ...
    log.info("Metal: mtl_destroy_window_wrapper called.")
    win_internal, err := get_window_internal(window_handle) 
    if err != .None { log.errorf("Metal: mtl_destroy_window_wrapper: %v", err); return }
    if win_internal.metal_layer != nil {
        if win_internal.view_handle != nil { sim_objc_msg_send_void(win_internal.view_handle, "setLayer:", nil) }
        sim_objc_msg_send_void(win_internal.metal_layer, "release")
        win_internal.metal_layer = nil
    }
    if win_internal.ns_window_handle != nil { // Assuming we "own" the NSWindow
        sim_objc_msg_send_void(rawptr(win_internal.ns_window_handle), "release")
        win_internal.ns_window_handle = nil
    }
    // view_handle is part of ns_window_handle usually.
    free(win_internal, win_internal.allocator)
    log.info("Metal: Mtl_Window_Internal struct freed.")
}


// --- Frame Implementation ---
begin_frame_impl :: proc(device_handle: gfx_interface.Gfx_Device) -> common.Engine_Error {
    // ... (Implementation from previous subtask, assumed correct) ...
    dev_internal, err := get_device_internal(device_handle)
    if err != .None { return err }
    if dev_internal.primary_window == nil {
        log.error("begin_frame_impl: No primary window set on Metal device.")
        return .Invalid_Operation 
    }
    win_internal := dev_internal.primary_window
    if win_internal.metal_layer == nil {
        log.error("begin_frame_impl: Metal layer is nil for the primary window.")
        return .Invalid_Handle
    }
    current_drawable_handle := MTLDrawable_Handle(sim_objc_msg_send_ret_ptr(rawptr(win_internal.metal_layer), "nextDrawable"))
    if current_drawable_handle == nil {
        log.error("begin_frame_impl: Failed to get next drawable from metal layer.")
        return .Surface_Lost 
    }
    win_internal.current_drawable = current_drawable_handle
    log.infof("begin_frame_impl: Obtained drawable %p for window.", current_drawable_handle)
    if dev_internal.command_queue == nil {
        log.error("begin_frame_impl: Command queue is nil.")
        return .Not_Initialized
    }
    active_cmd_buf_handle := MTLCommandBuffer_Handle(sim_objc_msg_send_ret_ptr(rawptr(dev_internal.command_queue), "commandBuffer"))
    if active_cmd_buf_handle == nil {
        log.error("begin_frame_impl: Failed to create command buffer from command queue.")
        win_internal.current_drawable = nil 
        return .Vulkan_Error // Using as generic graphics error
    }
    dev_internal.active_command_buffer = active_cmd_buf_handle
    log.infof("begin_frame_impl: Created active command buffer %p.", active_cmd_buf_handle)
    return .None
}

end_frame_impl :: proc(device_handle: gfx_interface.Gfx_Device) -> common.Engine_Error { 
    dev_internal, err := get_device_internal(device_handle)
    if err != .None { return err }

    // End current render encoder if one is active
    if dev_internal.current_render_encoder != nil {
        sim_objc_msg_send_void(rawptr(dev_internal.current_render_encoder), "endEncoding")
        log.infof("end_frame_impl: Ended current render encoder %p.", dev_internal.current_render_encoder)
        dev_internal.current_render_encoder = nil
    }

    if dev_internal.active_command_buffer == nil {
        log.warn("end_frame_impl: No active command buffer to end.")
        return .None 
    }
    
    win_internal := dev_internal.primary_window
    if win_internal == nil {
        log.error("end_frame_impl: No primary window associated with device.")
        dev_internal.active_command_buffer = nil
        return .Invalid_Operation
    }

    if win_internal.current_drawable != nil {
        sim_objc_msg_send_void(rawptr(dev_internal.active_command_buffer), "presentDrawable:", rawptr(win_internal.current_drawable))
        log.infof("end_frame_impl: Presented drawable %p with command buffer %p.", win_internal.current_drawable, dev_internal.active_command_buffer)
    } else {
        log.warn("end_frame_impl: current_drawable was nil. Nothing to present.")
    }

    sim_objc_msg_send_void(rawptr(dev_internal.active_command_buffer), "commit")
    log.infof("end_frame_impl: Committed command buffer %p.", dev_internal.active_command_buffer)

    dev_internal.active_command_buffer = nil
    if win_internal != nil { 
        win_internal.current_drawable = nil
    }
    
    return .None
}

clear_screen_impl :: proc(device_handle: gfx_interface.Gfx_Device, options: gfx_interface.Clear_Options) -> common.Engine_Error {
    dev_internal, err := get_device_internal(device_handle)
    if err != .None { return err }

    if dev_internal.active_command_buffer == nil {
        log.error("clear_screen_impl: No active command buffer. Call begin_frame first.")
        return .Invalid_Operation
    }
    if dev_internal.current_render_encoder != nil {
        log.warn("clear_screen_impl: A render encoder is already active. Ending it before starting a new one for clear.")
        sim_objc_msg_send_void(rawptr(dev_internal.current_render_encoder), "endEncoding")
        dev_internal.current_render_encoder = nil
    }
    
    win_internal := dev_internal.primary_window
    if win_internal == nil || win_internal.current_drawable == nil {
        log.error("clear_screen_impl: No primary window or current drawable available.")
        return .Invalid_Operation
    }

    drawable_texture_handle := MTLTexture_Handle(sim_objc_msg_send_ret_ptr(rawptr(win_internal.current_drawable), "texture"))
    if drawable_texture_handle == nil {
        log.error("clear_screen_impl: Failed to get texture from current drawable.")
        return .Vulkan_Error 
    }

    rp_descriptor_handle := sim_mtl_render_pass_descriptor_new()
    if rp_descriptor_handle == nil {
        log.error("clear_screen_impl: Failed to create MTLRenderPassDescriptor.")
        return .Vulkan_Error
    }

    color_attachment_obj_ptr := sim_mtl_render_pass_descriptor_get_color_attachment(rp_descriptor_handle, 0)
    sim_mtl_color_attachment_set_texture(color_attachment_obj_ptr, drawable_texture_handle)

    if options.clear_color {
        sim_mtl_color_attachment_set_load_action(color_attachment_obj_ptr, MTLLoadActionClear)
        sim_mtl_color_attachment_set_clear_color(color_attachment_obj_ptr, 
            f64(options.color[0]), f64(options.color[1]), 
            f64(options.color[2]), f64(options.color[3]))
        log.debugf("clear_screen_impl: Configured color attachment to clear with color %v", options.color)
    } else {
        sim_mtl_color_attachment_set_load_action(color_attachment_obj_ptr, MTLLoadActionDontCare)
        log.debug("clear_screen_impl: Configured color attachment with load action DontCare.")
    }
    sim_mtl_color_attachment_set_store_action(color_attachment_obj_ptr, MTLStoreActionStore)

    render_encoder_handle := MTLRenderCommandEncoder_Handle(sim_objc_msg_send_ret_ptr(rawptr(dev_internal.active_command_buffer), "renderCommandEncoderWithDescriptor:", rawptr(rp_descriptor_handle)))
    if render_encoder_handle == nil {
        log.error("clear_screen_impl: Failed to create MTLRenderCommandEncoder.")
        return .Vulkan_Error
    }
    dev_internal.current_render_encoder = render_encoder_handle 
    log.infof("clear_screen_impl: Render command encoder %p created and stored.", render_encoder_handle)
    
    return .None
}

set_viewport_impl :: proc(device_handle: gfx_interface.Gfx_Device, x, y, width, height: i32) -> common.Engine_Error {
    dev_internal, err := get_device_internal(device_handle)
    if err != .None { return err }

    if dev_internal.current_render_encoder == nil {
        log.error("set_viewport_impl: No active render command encoder. Call clear_screen or begin_render_pass first.")
        return .Invalid_Operation
    }
    viewport := MTLViewport{
        originX = f64(x), originY = f64(y), 
        width = f64(width), height = f64(height), 
        znear = 0.0, zfar = 1.0,
    }
    sim_objc_msg_send_void(rawptr(dev_internal.current_render_encoder), "setViewport:", &viewport)
    log.infof("set_viewport_impl: Viewport set on encoder %p to {x:%d y:%d w:%d h:%d}", dev_internal.current_render_encoder, x, y, width, height)
    return .None
}

set_scissor_impl :: proc(device_handle: gfx_interface.Gfx_Device, x, y, width, height: i32) -> common.Engine_Error {
    dev_internal, err := get_device_internal(device_handle)
    if err != .None { return err }

    if dev_internal.current_render_encoder == nil {
        log.error("set_scissor_impl: No active render command encoder.")
        return .Invalid_Operation
    }
    if width < 0 || height < 0 {
        log.errorf("set_scissor_impl: Invalid scissor dimensions (width: %d, height: %d). Must be non-negative.", width, height)
        return .Invalid_Parameter
    }
    scissor_rect := MTLScissorRect{
        x = u32(math.max(0, x)), 
        y = u32(math.max(0, y)), 
        width = u32(width), height = u32(height),
    }
    sim_objc_msg_send_void(rawptr(dev_internal.current_render_encoder), "setScissorRect:", &scissor_rect)
    log.infof("set_scissor_impl: Scissor rect set on encoder %p to {x:%d y:%d w:%d h:%d}", dev_internal.current_render_encoder, x, y, width, height)
    return .None
}

disable_scissor_impl :: proc(device_handle: gfx_interface.Gfx_Device) -> common.Engine_Error {
    dev_internal, err := get_device_internal(device_handle)
    if err != .None { return err }

    if dev_internal.current_render_encoder == nil {
        log.error("disable_scissor_impl: No active render command encoder.")
        return .Invalid_Operation
    }
    win_internal := dev_internal.primary_window
    if win_internal == nil {
        log.error("disable_scissor_impl: No primary window available to determine full scissor rect.")
        return .Invalid_Operation
    }
    
    drawable_width  := u32(win_internal.width)
    drawable_height := u32(win_internal.height)
    // In a real scenario, one would query drawable_texture.width and .height
    // For simulation, using window stored size which should reflect drawable size.

    full_scissor_rect := MTLScissorRect{ x = 0, y = 0, width = drawable_width, height = drawable_height, }
    sim_objc_msg_send_void(rawptr(dev_internal.current_render_encoder), "setScissorRect:", &full_scissor_rect)
    log.infof("disable_scissor_impl: Scissor rect set to full drawable size (%dx%d) on encoder %p.", drawable_width, drawable_height, dev_internal.current_render_encoder)
    return .None
}

present_window_impl :: proc(window_handle: gfx_interface.Gfx_Window) -> common.Engine_Error {
    win_internal, err_win := get_window_internal(window_handle)
    if err_win != .None { return err_win }
    if win_internal.device_ref == nil {
        log.error("present_window_impl: Window has no device reference.")
        return .Invalid_Handle
    }
    dev_internal := win_internal.device_ref

    if dev_internal.active_command_buffer == nil {
        log.warn("present_window_impl: No active command buffer. Frame might have been ended already or not begun.")
        return .Invalid_Operation 
    }
    if win_internal.current_drawable == nil {
        log.warn("present_window_impl: No current drawable for window. Frame might have been ended or not properly begun.")
        return .Invalid_Operation
    }
    
    if dev_internal.current_render_encoder != nil {
        sim_objc_msg_send_void(rawptr(dev_internal.current_render_encoder), "endEncoding")
        log.infof("present_window_impl: Ended active render encoder %p.", dev_internal.current_render_encoder)
        dev_internal.current_render_encoder = nil
    }

    sim_objc_msg_send_void(rawptr(dev_internal.active_command_buffer), "presentDrawable:", rawptr(win_internal.current_drawable))
    log.infof("present_window_impl: Explicitly presented drawable %p with command buffer %p.", win_internal.current_drawable, dev_internal.active_command_buffer)
    
    sim_objc_msg_send_void(rawptr(dev_internal.active_command_buffer), "commit")
    log.infof("present_window_impl: Committed command buffer %p.", dev_internal.active_command_buffer)

    dev_internal.active_command_buffer = nil
    win_internal.current_drawable = nil

    return .None
}

resize_window_impl :: proc(window_handle: gfx_interface.Gfx_Window, width, height: int) -> common.Engine_Error {
    win_internal, err := get_window_internal(window_handle)
    if err != .None { return err }

    if width <= 0 || height <= 0 {
        log.errorf("resize_window_impl: Invalid dimensions for resize (width: %d, height: %d). Must be positive.", width, height)
        return .Invalid_Parameter
    }

    win_internal.width = width
    win_internal.height = height
    
    if win_internal.metal_layer == nil {
        log.error("resize_window_impl: Metal layer is nil. Cannot set drawable size.")
        return .Not_Initialized 
    }
    
    drawable_width  := f64(width) 
    drawable_height := f64(height)

    sim_objc_msg_send_void(rawptr(win_internal.metal_layer), "setDrawableSize:", drawable_width, drawable_height) 
    log.infof("resize_window_impl: Set CAMetalLayer drawableSize to %vx%v for window.", drawable_width, drawable_height)
    
    return .None
}

get_window_size_impl :: proc(window_handle: gfx_interface.Gfx_Window) -> (w,h: int) {
    win_internal, err := get_window_internal(window_handle)
    if err != .None {
        log.errorf("get_window_size_impl: Error getting internal window: %v", err)
        return 0,0
    }
    log.debugf("get_window_size_impl: Returning logical size %dx%d for window.", win_internal.width, win_internal.height)
    return win_internal.width, win_internal.height
}

get_window_drawable_size_impl :: proc(window_handle: gfx_interface.Gfx_Window) -> (w,h: int) {
    win_internal, err := get_window_internal(window_handle)
    if err != .None {
        log.errorf("get_window_drawable_size_impl: Error getting internal window: %v", err)
        return 0,0
    }
    if win_internal.metal_layer == nil {
        log.error("get_window_drawable_size_impl: Metal layer is nil. Cannot get drawable size.")
        return 0,0
    }
    // Actual drawable size comes from the layer, which might differ due to Retina scaling.
    // For this simulation, we use the stored width/height which should be updated by resize_window_impl to reflect drawable pixels.
    // CGSize actual_drawable_size = [metal_layer drawableSize];
    // return int(actual_drawable_size.width), int(actual_drawable_size.height);
    // Our `resize_window_impl` sets `win_internal.width/height` to the drawable pixel size.
    log.debugf("get_window_drawable_size_impl: Returning drawable size %dx%d for window (from stored values).", win_internal.width, win_internal.height)
    return win_internal.width, win_internal.height
}

set_window_title_impl :: proc(window_handle: gfx_interface.Gfx_Window, title: string) -> common.Engine_Error {
    win_internal, err := get_window_internal(window_handle)
    if err != .None { return err }

    if win_internal.ns_window_handle == nil {
        log.warn("set_window_title_impl: No NSWindow handle stored; cannot set title directly via Metal backend. This would typically be an SDL call if SDL manages the window.")
        return .Not_Implemented 
    }
    
    title_cstr := strings.clone_to_cstring(title)
    defer delete(title_cstr)

    ns_title_string_handle := NSString_Handle(sim_objc_msg_send_ret_ptr(nil, "stringWithUTF8String:", title_cstr)) 
    if ns_title_string_handle == nil {
        log.error("set_window_title_impl: Failed to create NSString from title.")
        return .Memory_Error 
    }
    
    sim_objc_msg_send_void(rawptr(win_internal.ns_window_handle), "setTitle:", rawptr(ns_title_string_handle))
    // Assuming NSString is autoreleased or handled by ARC in a real scenario.
    log.infof("set_window_title_impl: Window title set to '%s' (simulated).", title)
    return .None
}


initialize_metal_backend :: proc() {
    log.info("Initializing Metal graphics backend...")
    gfx_interface.gfx_api = gfx_interface.Gfx_Device_Interface {
        create_device              = mtl_create_device_wrapper, 
        destroy_device             = mtl_destroy_device_wrapper, // Should be -> common.Engine_Error
        create_window              = mtl_create_window_wrapper,
        destroy_window             = mtl_destroy_window_wrapper, // Should be -> common.Engine_Error
        
        begin_frame                = begin_frame_impl,
        end_frame                  = end_frame_impl,
        clear_screen               = clear_screen_impl,
        
        set_viewport               = set_viewport_impl,
        set_scissor                = set_scissor_impl,
        disable_scissor            = disable_scissor_impl,
        
        present_window             = present_window_impl,
        resize_window              = resize_window_impl,
        get_window_size            = get_window_size_impl,
        get_window_drawable_size   = get_window_drawable_size_impl,
        set_window_title           = set_window_title_impl,

        // Stubs for remaining functions from the previous subtask.
        // These would be filled in as other parts of the Metal backend are implemented.
        create_shader_from_source  = proc(d:gfx_interface.Gfx_Device,s:string,st:gfx_interface.Shader_Stage)->(gfx_interface.Gfx_Shader,common.Engine_Error){ log.warn("Metal: create_shader_from_source not implemented"); return gfx_interface.Gfx_Shader{},.Not_Implemented},
        create_shader_from_bytecode= proc(d:gfx_interface.Gfx_Device,b:[]u8,st:gfx_interface.Shader_Stage)->(gfx_interface.Gfx_Shader,common.Engine_Error){ log.warn("Metal: create_shader_from_bytecode not implemented"); return gfx_interface.Gfx_Shader{},.Not_Implemented},
        destroy_shader             = proc(s:gfx_interface.Gfx_Shader){log.warn("Metal: destroy_shader not implemented")}, // Should return common.Engine_Error
        create_pipeline            = proc(d:gfx_interface.Gfx_Device,s:[]gfx_interface.Gfx_Shader)->(gfx_interface.Gfx_Pipeline,common.Engine_Error){ log.warn("Metal: create_pipeline not implemented"); return gfx_interface.Gfx_Pipeline{},.Not_Implemented},
        destroy_pipeline           = proc(p:gfx_interface.Gfx_Pipeline){log.warn("Metal: destroy_pipeline not implemented")}, // Should return common.Engine_Error
        set_pipeline               = proc(d:gfx_interface.Gfx_Device,p:gfx_interface.Gfx_Pipeline){log.warn("Metal: set_pipeline not implemented")}, // Should return common.Engine_Error
        create_buffer              = proc(d:gfx_interface.Gfx_Device,t:gfx_interface.Buffer_Type,s:int,dt:rawptr,dyn:bool)->(gfx_interface.Gfx_Buffer,common.Engine_Error){ log.warn("Metal: create_buffer not implemented"); return gfx_interface.Gfx_Buffer{},.Not_Implemented},
        update_buffer              = proc(b:gfx_interface.Gfx_Buffer,o:int,dt:rawptr,s:int)->common.Engine_Error{log.warn("Metal: update_buffer not implemented"); return .Not_Implemented},
        destroy_buffer             = proc(b:gfx_interface.Gfx_Buffer){log.warn("Metal: destroy_buffer not implemented")}, // Should return common.Engine_Error
        map_buffer                 = proc(b:gfx_interface.Gfx_Buffer,o,s:int)->(rawptr, common.Engine_Error){log.warn("Metal: map_buffer not implemented"); return nil, .Not_Implemented},
        unmap_buffer               = proc(b:gfx_interface.Gfx_Buffer){log.warn("Metal: unmap_buffer not implemented")}, // Should return common.Engine_Error
        set_vertex_buffer          = proc(d:gfx_interface.Gfx_Device,b:gfx_interface.Gfx_Buffer,bi,bo:u32){log.warn("Metal: set_vertex_buffer not implemented")},
        set_index_buffer           = proc(d:gfx_interface.Gfx_Device,b:gfx_interface.Gfx_Buffer,o:u32){log.warn("Metal: set_index_buffer not implemented")},
        create_texture             = proc(d:gfx_interface.Gfx_Device,w,h:int,f:gfx_interface.Texture_Format,u:gfx_interface.Texture_Usage,dt:rawptr)->(gfx_interface.Gfx_Texture,common.Engine_Error){ log.warn("Metal: create_texture not implemented"); return gfx_interface.Gfx_Texture{},.Not_Implemented},
        update_texture             = proc(t:gfx_interface.Gfx_Texture,x,y,w,h:int,dt:rawptr)->common.Engine_Error{log.warn("Metal: update_texture not implemented"); return .Not_Implemented},
        destroy_texture            = proc(t:gfx_interface.Gfx_Texture){log.warn("Metal: destroy_texture not implemented")}, // Should return common.Engine_Error
        bind_texture_to_unit       = proc(d:gfx_interface.Gfx_Device,t:gfx_interface.Gfx_Texture,u:u32)->common.Engine_Error{log.warn("Metal: bind_texture_to_unit not implemented"); return .Not_Implemented},
        get_texture_width          = proc(t:gfx_interface.Gfx_Texture)->int{log.warn("Metal: get_texture_width not implemented"); return 0},
        get_texture_height         = proc(t:gfx_interface.Gfx_Texture)->int{log.warn("Metal: get_texture_height not implemented"); return 0},
        draw                       = proc(d:gfx_interface.Gfx_Device,vc,ic,fv,fi:u32){log.warn("Metal: draw not implemented")},
        draw_indexed               = proc(d:gfx_interface.Gfx_Device,ic,insc,fi,bv,fiv:u32){log.warn("Metal: draw_indexed not implemented")}, // base_vertex was i32 in Gfx_Interface
        set_uniform_mat4           = proc(d:gfx_interface.Gfx_Device,p:gfx_interface.Gfx_Pipeline,n:string,m:matrix[4,4]f32)->common.Engine_Error{log.warn("Metal: set_uniform_mat4 not implemented"); return .Not_Implemented},
        set_uniform_vec2           = proc(d:gfx_interface.Gfx_Device,p:gfx_interface.Gfx_Pipeline,n:string,v:[2]f32)->common.Engine_Error{log.warn("Metal: set_uniform_vec2 not implemented"); return .Not_Implemented},
        set_uniform_vec3           = proc(d:gfx_interface.Gfx_Device,p:gfx_interface.Gfx_Pipeline,n:string,v:[3]f32)->common.Engine_Error{log.warn("Metal: set_uniform_vec3 not implemented"); return .Not_Implemented},
        set_uniform_vec4           = proc(d:gfx_interface.Gfx_Device,p:gfx_interface.Gfx_Pipeline,n:string,v:[4]f32)->common.Engine_Error{log.warn("Metal: set_uniform_vec4 not implemented"); return .Not_Implemented},
        set_uniform_int            = proc(d:gfx_interface.Gfx_Device,p:gfx_interface.Gfx_Pipeline,n:string,v:i32)->common.Engine_Error{log.warn("Metal: set_uniform_int not implemented"); return .Not_Implemented},
        set_uniform_float          = proc(d:gfx_interface.Gfx_Device,p:gfx_interface.Gfx_Pipeline,n:string,v:f32)->common.Engine_Error{log.warn("Metal: set_uniform_float not implemented"); return .Not_Implemented},
        create_vertex_array      = proc(d:gfx_interface.Gfx_Device,vbl:[]gfx_interface.Vertex_Buffer_Layout,vb:[]gfx_interface.Gfx_Buffer,ib:gfx_interface.Gfx_Buffer)->(gfx_interface.Gfx_Vertex_Array,common.Engine_Error){ log.warn("Metal: create_vertex_array not implemented"); return gfx_interface.Gfx_Vertex_Array{},.Not_Implemented},
        destroy_vertex_array     = proc(v:gfx_interface.Gfx_Vertex_Array){log.warn("Metal: destroy_vertex_array not implemented")}, // Should return common.Engine_Error
        bind_vertex_array        = proc(d:gfx_interface.Gfx_Device,v:gfx_interface.Gfx_Vertex_Array){log.warn("Metal: bind_vertex_array not implemented")},
        get_error_string           = proc(e:common.Engine_Error)->string{return "Metal: get_error_string not implemented"},
    }
    log.info("Metal graphics backend function pointers assigned to gfx_api.")
}

// Ensure this file ends with a newline for POSIX compatibility
