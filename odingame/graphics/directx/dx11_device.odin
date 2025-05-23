package directx11

import "../gfx_interface"
import "core:log"
import "core:mem"

// --- Device Management ---

create_device_impl :: proc(main_allocator_ptr: ^rawptr) -> (gfx_interface.Gfx_Device, gfx_interface.Gfx_Error) {
    log.warn("DirectX 11: create_device_impl not implemented")
    // Real implementation would:
    // 1. Create DXGI factory
    // 2. Enumerate adapters
    // 3. Create D3D11 device and immediate context
    // 4. Initialize swap chain
    // 5. Create render target view for back buffer
    return gfx_interface.Gfx_Device{}, .Not_Implemented
}

destroy_device_impl :: proc(device: gfx_interface.Gfx_Device) {
    log.warn("DirectX 11: destroy_device_impl not implemented")
    // Real implementation would:
    // 1. Release all device resources
    // 2. Release immediate context
    // 3. Release device
    if dev_internal, ok := device.variant.(D3D11_Device_Variant); ok && dev_internal != nil {
        // free(dev_internal, dev_internal.allocator)
    }
}

// --- Frame Management ---

begin_frame_impl :: proc(device: gfx_interface.Gfx_Device) -> gfx_interface.Gfx_Error {
    log.debug("DirectX 11: begin_frame_impl (stub)")
    // Real implementation would:
    // 1. Clear render target view
    // 2. Clear depth stencil view if it exists
    return .None
}

end_frame_impl :: proc(device: gfx_interface.Gfx_Device) -> gfx_interface.Gfx_Error {
    log.debug("DirectX 11: end_frame_impl (stub)")
    // Real implementation would:
    // 1. Present the swap chain
    // 2. Handle device lost scenarios
    return .None
}

clear_screen_impl :: proc(device: gfx_interface.Gfx_Device, color: gfx_interface.Color) -> gfx_interface.Gfx_Error {
    log.warn("DirectX 11: clear_screen_impl not implemented")
    // Real implementation would:
    // 1. Get current render target view
    // 2. Clear render target view with the specified color
    return .Not_Implemented
}

// --- Viewport and Scissor ---

set_viewport_impl :: proc(device: gfx_interface.Gfx_Device, x, y, width, height: i32) -> gfx_interface.Gfx_Error {
    log.warn("DirectX 11: set_viewport_impl not implemented")
    // Real implementation would:
    // 1. Create a D3D11_VIEWPORT structure
    // 2. Call RSSetViewports on the immediate context
    return .Not_Implemented
}

set_scissor_impl :: proc(device: gfx_interface.Gfx_Device, x, y, width, height: i32) -> gfx_interface.Gfx_Error {
    log.warn("DirectX 11: set_scissor_impl not implemented")
    // Real implementation would:
    // 1. Create a D3D11_RECT structure
    // 2. Call RSSetScissorRects on the immediate context
    return .Not_Implemented
}

disable_scissor_impl :: proc(device: gfx_interface.Gfx_Device) -> gfx_interface.Gfx_Error {
    log.warn("DirectX 11: disable_scissor_impl not implemented")
    // Real implementation would:
    // 1. Set scissor rect to cover the entire viewport
    return .Not_Implemented
}

// --- Window Management ---

create_window_impl :: proc(
    device: gfx_interface.Gfx_Device,
    title: string,
    width, height: int,
    fullscreen: bool = false,
) -> (gfx_interface.Gfx_Window, gfx_interface.Gfx_Error) {
    log.warn("DirectX 11: create_window_impl not implemented")
    // Real implementation would:
    // 1. Create a window using the appropriate API (Win32, SDL, etc.)
    // 2. Create a swap chain for the window
    // 3. Create a render target view for the back buffer
    return gfx_interface.Gfx_Window{}, .Not_Implemented
}

destroy_window_impl :: proc(window: gfx_interface.Gfx_Window) -> gfx_interface.Gfx_Error {
    log.warn("DirectX 11: destroy_window_impl not implemented")
    // Real implementation would:
    // 1. Release the swap chain
    // 2. Release the render target view
    // 3. Destroy the window
    if win_internal, ok := window.variant.(D3D11_Window_Variant); ok && win_internal != nil {
        // free(win_internal, win_internal.allocator)
    }
    return .None
}
