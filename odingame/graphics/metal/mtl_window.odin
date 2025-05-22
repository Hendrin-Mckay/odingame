package metal

import "../gfx_interface"
import "core:log"
// import "vendor:sdl2" // If SDL is used for window creation and CAMetalLayer retrieval.
// For stubs, direct dependency might not be needed if we assume view_handle is abstract.

// --- Gfx_Device_Interface Window Management Stubs ---

mtl_create_window_wrapper :: proc(
	device: gfx_interface.Gfx_Device, 
	title: string, 
	width, height: int,
) -> (gfx_interface.Gfx_Window, gfx_interface.Gfx_Error) {
	log.warn("Metal: create_window_wrapper not implemented.")
	// In a real Metal implementation, this would:
	// 1. Ensure Gfx_Device is a valid Mtl_Device.
	// 2. Create an OS window (e.g., NSWindow via AppKit, or use an existing SDL/GLFW window).
	// 3. Create a CAMetalLayer and attach it to the window's view.
	// 4. Configure CAMetalLayer properties (device, pixelFormat, drawableSize).
	// 5. Populate Mtl_Window_Internal.
	return gfx_interface.Gfx_Window{}, .Not_Implemented
}

mtl_destroy_window_wrapper :: proc(window: gfx_interface.Gfx_Window) {
	log.warn("Metal: destroy_window_wrapper not implemented.")
	// In a real Metal implementation, this would:
	// 1. Release CAMetalLayer.
	// 2. Destroy/Release the OS window if created by this backend.
	// 3. Free Mtl_Window_Internal struct.
	if win_internal, ok := window.variant.(Mtl_Window_Variant); ok && win_internal != nil {
		// Placeholder for freeing variant data
		// free(win_internal, win_internal.allocator);
	}
}

mtl_present_window_wrapper :: proc(window: gfx_interface.Gfx_Window) -> gfx_interface.Gfx_Error {
	log.debug("Metal: present_window_wrapper (stub).")
	// Real Metal:
	// 1. Obtain next drawable: id<CAMetalDrawable> from CAMetalLayer.nextDrawable().
	// 2. Get texture from drawable: id<MTLTexture> drawable.texture.
	// 3. (After command buffer is encoded and committed) CommandBuffer.present(drawable).
	// 4. CommandBuffer.commit().
	return .Not_Implemented // Or .None if stubbing success
}

mtl_resize_window_wrapper :: proc(window: gfx_interface.Gfx_Window, width, height: int) -> gfx_interface.Gfx_Error {
	log.warn("Metal: resize_window_wrapper not implemented.")
	// Real Metal:
	// 1. Update the CAMetalLayer's drawableSize property.
	// 2. The swapchain (drawable pool) usually handles resizing implicitly.
	// 3. May need to recreate depth textures or other size-dependent resources.
	// 4. Update Mtl_Window_Internal width/height.
	return .Not_Implemented
}

mtl_get_window_size_wrapper :: proc(window: gfx_interface.Gfx_Window) -> (w, h: int) {
	log.warn("Metal: get_window_size_wrapper not implemented.")
	// This would typically return the logical size of the window (points).
	if win_internal, ok := window.variant.(Mtl_Window_Variant); ok && win_internal != nil {
		// return win_internal.width, win_internal.height; // If logical size stored
	}
	return 0,0
}

mtl_get_window_drawable_size_wrapper :: proc(window: gfx_interface.Gfx_Window) -> (w, h: int) {
	log.warn("Metal: get_window_drawable_size_wrapper not implemented.")
	// This would return the CAMetalLayer.drawableSize (pixels).
	if win_internal, ok := window.variant.(Mtl_Window_Variant); ok && win_internal != nil {
		// return win_internal.width, win_internal.height; // If drawable size stored
	}
	return 0,0
}
