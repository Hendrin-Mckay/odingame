package metal

import "../gfx_interface"
import "core:log"
import "core:mem" // For context.allocator if needed by stubs

// --- Gfx_Device_Interface Device Management Stubs ---

mtl_create_device_wrapper :: proc(main_allocator_ptr: ^rawptr) -> (gfx_interface.Gfx_Device, gfx_interface.Gfx_Error) {
	log.warn("Metal: create_device_wrapper not implemented.")
	// In a real Metal implementation, this would:
	// 1. Call MTLCreateSystemDefaultDevice() to get an id<MTLDevice>.
	// 2. Create an id<MTLCommandQueue> from the device.
	// 3. Populate Mtl_Device_Internal.
	return gfx_interface.Gfx_Device{}, .Not_Implemented
}

mtl_destroy_device_wrapper :: proc(device: gfx_interface.Gfx_Device) {
	log.warn("Metal: destroy_device_wrapper not implemented.")
	// In a real Metal implementation, this would:
	// 1. Ensure command queue is finished if necessary.
	// 2. Release id<MTLCommandQueue>.
	// 3. Release id<MTLDevice>.
	// 4. Free Mtl_Device_Internal struct.
	// Metal objects are reference-counted via ARC (Automatic Reference Counting) in Obj-C,
	// so "Release" means decrementing the ref count. In Odin, this would be via explicit release calls
	// provided by the Metal bindings if not using ARC directly.
	if dev_internal, ok := device.variant.(Mtl_Device_Variant); ok && dev_internal != nil {
		// Placeholder for freeing the variant data
		// free(dev_internal, dev_internal.allocator); 
	}
}

// --- Gfx_Device_Interface Frame Management Stubs ---

mtl_begin_frame_wrapper :: proc(device: gfx_interface.Gfx_Device) {
	log.debug("Metal: begin_frame_wrapper (stub).")
	// Real Metal: Might involve beginning a new command buffer from a command queue,
	// and getting the next available drawable from the CAMetalLayer (usually done in window/swapchain context).
}

mtl_end_frame_wrapper :: proc(device: gfx_interface.Gfx_Device) {
	log.debug("Metal: end_frame_wrapper (stub).")
	// Real Metal: Commit command buffer, and for drawable-based rendering, present the drawable.
}


// --- Gfx_Device_Interface Drawing Command Stubs ---

mtl_clear_screen_wrapper :: proc(device: gfx_interface.Gfx_Device, options: gfx_interface.Clear_Options) {
	log.warn("Metal: clear_screen_wrapper not implemented.")
	// Real Metal: This would be part of a render pass.
	// A MTLRenderPassDescriptor would be configured with clear colors/depth/stencil values.
	// Then a MTLRenderCommandEncoder would be created.
}

mtl_set_viewport_wrapper :: proc(device: gfx_interface.Gfx_Device, viewport: gfx_interface.Viewport) {
    log.warn("Metal: set_viewport_wrapper not implemented.")
	// Real Metal: MTLRenderCommandEncoder.setViewport()
}

mtl_set_scissor_wrapper :: proc(device: gfx_interface.Gfx_Device, scissor: gfx_interface.Scissor) {
    log.warn("Metal: set_scissor_wrapper not implemented.")
	// Real Metal: MTLRenderCommandEncoder.setScissorRect()
}

mtl_draw_wrapper :: proc(device: gfx_interface.Gfx_Device, vertex_count, instance_count, first_vertex, first_instance: u32) {
	log.warn("Metal: draw_wrapper not implemented.")
	// Real Metal: MTLRenderCommandEncoder.drawPrimitives(.triangle, first_vertex, vertex_count, instance_count, first_instance)
}

mtl_draw_indexed_wrapper :: proc(device: gfx_interface.Gfx_Device, index_count, instance_count, first_index, base_vertex, first_instance: u32) {
	log.warn("Metal: draw_indexed_wrapper not implemented.")
	// Real Metal: MTLRenderCommandEncoder.drawIndexedPrimitives(.triangle, index_count, index_type, index_buffer, index_buffer_offset + first_index * index_size, instance_count, base_vertex, first_instance)
}


// --- Gfx_Device_Interface Utility Stubs ---

mtl_get_error_string_wrapper :: proc(error: gfx_interface.Gfx_Error) -> string {
    #partial switch error {
    case .None: return "No error (Metal)"
    case .Initialization_Failed: return "Initialization failed (Metal)"
    case .Device_Creation_Failed: return "Device creation failed (Metal)"
    case .Window_Creation_Failed: return "Window creation failed (Metal)"
    case .Shader_Compilation_Failed: return "Shader compilation failed (Metal)"
    case .Buffer_Creation_Failed: return "Buffer creation failed (Metal)"
    case .Texture_Creation_Failed: return "Texture creation failed (Metal)"
    case .Invalid_Handle: return "Invalid handle (Metal)"
    case .Not_Implemented: return "Not implemented (Metal)"
    }
    return "Unknown Gfx_Error (Metal)"
}
