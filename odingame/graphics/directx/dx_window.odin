package directx

import "../gfx_interface"
import "core:log"
// import "core:windows" // For HWND - already in dx_types.odin

// --- Gfx_Device_Interface Window Management Stubs ---

dx_create_window_wrapper :: proc(
	device: gfx_interface.Gfx_Device, 
	title: string, 
	width, height: int,
) -> (gfx_interface.Gfx_Window, gfx_interface.Gfx_Error) {
	log.warn("DirectX: create_window_wrapper not implemented.")
	// In a real D3D11 implementation, this would:
	// 1. Ensure Gfx_Device is a valid Dx_Device.
	// 2. Create an OS window (e.g., using Win32 API, or from an existing SDL/GLFW window if hybrid). Get HWND.
	// 3. Create IDXGISwapChain using the DXGI Factory (from Dx_Device_Internal) and HWND.
	// 4. Get the back buffer from swap chain.
	// 5. Create a RenderTargetView for the back buffer.
	// 6. Optionally create a DepthStencilView.
	// 7. Populate Dx_Window_Internal.
	return gfx_interface.Gfx_Window{}, .Not_Implemented
}

dx_destroy_window_wrapper :: proc(window: gfx_interface.Gfx_Window) {
	log.warn("DirectX: destroy_window_wrapper not implemented.")
	// In a real D3D11 implementation, this would:
	// 1. Release RenderTargetView, DepthStencilView.
	// 2. Release SwapChain. (Important: SwapChain might need to be set to windowed mode before release if fullscreen).
	// 3. Destroy/Release the OS window (HWND) if created by this backend.
	// 4. Free Dx_Window_Internal struct.
	if win_internal, ok := window.variant.(Dx_Window_Variant); ok && win_internal != nil {
		// Placeholder for freeing variant data
		// free(win_internal, win_internal.allocator);
	}
}

dx_present_window_wrapper :: proc(window: gfx_interface.Gfx_Window) -> gfx_interface.Gfx_Error {
	log.debug("DirectX: present_window_wrapper (stub).") // Debug as it's called frequently
	// Real D3D11: IDXGISwapChain.Present(sync_interval, flags)
	return .Not_Implemented // Or .None if stubbing success
}

dx_resize_window_wrapper :: proc(window: gfx_interface.Gfx_Window, width, height: int) -> gfx_interface.Gfx_Error {
	log.warn("DirectX: resize_window_wrapper not implemented.")
	// Real D3D11:
	// 1. Release old RenderTargetView, DepthStencilView, and back buffer references.
	// 2. Call IDXGISwapChain.ResizeBuffers(...).
	// 3. Get new back buffer.
	// 4. Create new RenderTargetView and DepthStencilView.
	// 5. Update Dx_Window_Internal width/height.
	return .Not_Implemented
}

dx_get_window_size_wrapper :: proc(window: gfx_interface.Gfx_Window) -> (w, h: int) {
	log.warn("DirectX: get_window_size_wrapper not implemented.")
	if win_internal, ok := window.variant.(Dx_Window_Variant); ok && win_internal != nil {
		// return win_internal.width, win_internal.height; // If dimensions were stored
	}
	return 0,0
}

dx_get_window_drawable_size_wrapper :: proc(window: gfx_interface.Gfx_Window) -> (w, h: int) {
	log.warn("DirectX: get_window_drawable_size_wrapper not implemented.")
	// For D3D11, this is typically the same as window client rect size,
	// or swapchain back buffer size.
	if win_internal, ok := window.variant.(Dx_Window_Variant); ok && win_internal != nil {
		// return win_internal.width, win_internal.height; 
	}
	return 0,0
}
