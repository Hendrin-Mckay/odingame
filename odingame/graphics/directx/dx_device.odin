package directx

import "../gfx_interface"
import "core:log"
import "core:mem" // For context.allocator if needed by stubs

// --- Gfx_Device_Interface Device Management Stubs ---

dx_create_device_wrapper :: proc(main_allocator_ptr: ^rawptr) -> (gfx_interface.Gfx_Device, gfx_interface.Gfx_Error) {
	log.warn("DirectX: create_device_wrapper not implemented.")
	// In a real D3D11 implementation, this would:
	// 1. Create DXGI Factory
	// 2. Enumerate Adapters
	// 3. Create D3D11 Device and Immediate Context
	// 4. Populate Dx_Device_Internal
	
	// Stub: Create a dummy Dx_Device_Internal if needed for variant to not be nil, or return error.
	// For now, returning an empty Gfx_Device with error.
	return gfx_interface.Gfx_Device{}, .Not_Implemented
}

dx_destroy_device_wrapper :: proc(device: gfx_interface.Gfx_Device) {
	log.warn("DirectX: destroy_device_wrapper not implemented.")
	// In a real D3D11 implementation, this would:
	// 1. Release D3D11 Device Context (if deferred contexts were used, flush and clear state)
	// 2. Release D3D11 Device
	// 3. Release DXGI Factory
	// 4. Free Dx_Device_Internal struct
	if dev_internal, ok := device.variant.(Dx_Device_Variant); ok && dev_internal != nil {
		// Placeholder for freeing the variant data
		// free(dev_internal, dev_internal.allocator); 
	}
}

// --- Gfx_Device_Interface Frame Management Stubs ---

dx_begin_frame_wrapper :: proc(device: gfx_interface.Gfx_Device) {
	log.debug("DirectX: begin_frame_wrapper (stub).")
	// Real D3D11: Might involve per-frame setup, but often less explicit than Vulkan.
}

dx_end_frame_wrapper :: proc(device: gfx_interface.Gfx_Device) {
	log.debug("DirectX: end_frame_wrapper (stub).")
	// Real D3D11: Might involve end-of-frame cleanup or state reset.
}


// --- Gfx_Device_Interface Drawing Command Stubs ---

dx_clear_screen_wrapper :: proc(device: gfx_interface.Gfx_Device, options: gfx_interface.Clear_Options) {
	log.warn("DirectX: clear_screen_wrapper not implemented.")
	// Real D3D11: Would use ID3D11DeviceContext.ClearRenderTargetView and/or ClearDepthStencilView.
}

dx_set_viewport_wrapper :: proc(device: gfx_interface.Gfx_Device, viewport: gfx_interface.Viewport) {
    log.warn("DirectX: set_viewport_wrapper not implemented.")
	// Real D3D11: ID3D11DeviceContext.RSSetViewports
}

dx_set_scissor_wrapper :: proc(device: gfx_interface.Gfx_Device, scissor: gfx_interface.Scissor) {
    log.warn("DirectX: set_scissor_wrapper not implemented.")
	// Real D3D11: ID3D11DeviceContext.RSSetScissorRects
}

dx_draw_wrapper :: proc(device: gfx_interface.Gfx_Device, vertex_count, instance_count, first_vertex, first_instance: u32) {
	log.warn("DirectX: draw_wrapper not implemented.")
	// Real D3D11: ID3D11DeviceContext.DrawInstanced (or Draw if instance_count is 1)
}

dx_draw_indexed_wrapper :: proc(device: gfx_interface.Gfx_Device, index_count, instance_count, first_index, base_vertex, first_instance: u32) {
	log.warn("DirectX: draw_indexed_wrapper not implemented.")
	// Real D3D11: ID3D11DeviceContext.DrawIndexedInstanced (or DrawIndexed if instance_count is 1)
}


// --- Gfx_Device_Interface Utility Stubs ---

dx_get_error_string_wrapper :: proc(error: gfx_interface.Gfx_Error) -> string {
    // This can use a generic error string mapping or be DirectX specific if errors were more detailed.
    #partial switch error {
    case .None: return "No error (DirectX)"
    case .Initialization_Failed: return "Initialization failed (DirectX)"
    case .Device_Creation_Failed: return "Device creation failed (DirectX)"
    case .Window_Creation_Failed: return "Window creation failed (DirectX)"
    case .Shader_Compilation_Failed: return "Shader compilation failed (DirectX)"
    case .Buffer_Creation_Failed: return "Buffer creation failed (DirectX)"
    case .Texture_Creation_Failed: return "Texture creation failed (DirectX)"
    case .Invalid_Handle: return "Invalid handle (DirectX)"
    case .Not_Implemented: return "Not implemented (DirectX)"
    }
    return "Unknown Gfx_Error (DirectX)"
}
