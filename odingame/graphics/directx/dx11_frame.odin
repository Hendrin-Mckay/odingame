package directx11

import "../gfx_interface"
import "../../common"
import "../../types"
import "./dx11_types"
import "./dx11_bindings"
import "core:log"
import "core:sys/windows" // For HRESULT and other Windows types if not in dx11_bindings

// Implementation of frame management functions for DirectX 11

begin_frame_impl :: proc(
    device_handle: gfx_interface.Gfx_Device, 
    window_handle: gfx_interface.Gfx_Window,
) -> common.Engine_Error {
    // log.debug("DirectX 11: begin_frame_impl called.") // Optional: for verbose logging

    di := get_device_internal(device_handle)
    if di == nil {
        log.error("DX11: begin_frame_impl: Invalid Gfx_Device.")
        return .Invalid_Handle
    }
    if di.immediate_context == nil {
        log.error("DX11: begin_frame_impl: Immediate context is nil.")
        return .Invalid_Handle
    }

    wi := get_window_internal(window_handle)
    if wi == nil {
        log.error("DX11: begin_frame_impl: Invalid Gfx_Window.")
        return .Invalid_Handle
    }
    if wi.render_target_view == nil {
        log.error("DX11: begin_frame_impl: Render target view is nil.")
        return .Invalid_Handle
    }

    context_vtable := (^ID3D11DeviceContextVTable)(di.immediate_context)^

    // Set the render target. For now, no depth stencil view is used.
    // The array ppRenderTargetViews is a pointer to the first element of an array of RTVs.
    // Since we have only one RTV, we take its address.
    rtv_array: [1]ID3D11RenderTargetView_Handle = {wi.render_target_view}
    
    context_vtable.OMSetRenderTargets(
        di.immediate_context,
        1, // NumViews
        &rtv_array[0], // ppRenderTargetViews (as rawptr)
        nil, // pDepthStencilView
    )
    
    // Viewport setup could also be done here if it changes or needs to be reset per frame.
    // For now, assume viewport is set once after window creation/resize.
    // D3D11_VIEWPORT viewport = { 0.0f, 0.0f, (float)wi.width, (float)wi.height, 0.0f, 1.0f };
    // context_vtable.RSSetViewports(di.immediate_context, 1, &viewport);


    return .None
}

end_frame_impl :: proc(
    device_handle: gfx_interface.Gfx_Device, 
    window_handle: gfx_interface.Gfx_Window,
) -> common.Engine_Error {
    // log.debug("DirectX 11: end_frame_impl called.") // Optional

    // Presentation is handled by present_window_impl in dx11_device.odin
    // This function might be used for any post-rendering logic before presentation,
    // or for multi-threaded command list submission in more advanced scenarios.
    // For now, it does nothing.
    
    // Example: If using deferred contexts, this is where you might execute command lists.
    // di := get_device_internal(device_handle)
    // if di != nil && di.immediate_context != nil {
    //    vt_ctx := (^ID3D11DeviceContextVTable)(di.immediate_context)^
    //    vt_ctx.Flush(di.immediate_context) // Example: Flush commands
    // }

    return .None
}

clear_screen_impl :: proc(
    device_handle: gfx_interface.Gfx_Device, 
    window_handle: gfx_interface.Gfx_Window, 
    color: types.Color,
) -> common.Engine_Error {
    // log.debugf("DirectX 11: clear_screen_impl called with color: %v", color) // Optional

    di := get_device_internal(device_handle)
    if di == nil {
        log.error("DX11: clear_screen_impl: Invalid Gfx_Device.")
        return .Invalid_Handle
    }
    if di.immediate_context == nil {
        log.error("DX11: clear_screen_impl: Immediate context is nil.")
        return .Invalid_Handle
    }

    wi := get_window_internal(window_handle)
    if wi == nil {
        log.error("DX11: clear_screen_impl: Invalid Gfx_Window.")
        return .Invalid_Handle
    }
    if wi.render_target_view == nil {
        log.error("DX11: clear_screen_impl: Render target view is nil.")
        return .Invalid_Handle
    }

    // Convert types.Color (0-255 RGBA) to [4]f32 (0.0-1.0 RGBA)
    clear_color_rgba: [4]f32
    clear_color_rgba[0] = f32(color.r) / 255.0
    clear_color_rgba[1] = f32(color.g) / 255.0
    clear_color_rgba[2] = f32(color.b) / 255.0
    clear_color_rgba[3] = f32(color.a) / 255.0

    context_vtable := (^ID3D11DeviceContextVTable)(di.immediate_context)^
    
    context_vtable.ClearRenderTargetView(
        di.immediate_context,
        wi.render_target_view,
        &clear_color_rgba,
    )

    // If a depth stencil view were bound, it would be cleared here too:
    // if wi.depth_stencil_view != nil {
    //    context_vtable.ClearDepthStencilView(di.immediate_context, wi.depth_stencil_view, D3D11_CLEAR_DEPTH | D3D11_CLEAR_STENCIL, 1.0f, 0);
    // }
    
    return .None
}
