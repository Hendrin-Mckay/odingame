package metal

// This file defines placeholder types for Metal objects and internal structures
// for the Metal backend. No actual Metal headers (Objective-C) are included or used directly.
// These are conceptual stand-ins for what would be Metal object pointers (id<...>).

import "../gfx_interface" // For Gfx_Device, Gfx_Window etc.
import "core:mem"
// For windowing, Metal often integrates with AppKit (NSView) or UIKit (UIView).
// If using SDL/GLFW for window creation, the CAMetalLayer would be attached to their view.
// For stubs, we might hold a generic window handle or assume it's managed externally.
// import "vendor:sdl2" // If SDL is used to obtain the drawable layer/view

// --- Placeholder Metal Object Handles ---
// In a real implementation, these would be `id` types (e.g., `id<MTLDevice>`).
// For stubs, we can use distinct rawptr or empty structs.
// Using distinct rawptr for conceptual clarity.
MTLDevice_Handle :: distinct rawptr
MTLCommandQueue_Handle :: distinct rawptr
MTLLibrary_Handle :: distinct rawptr
MTLRenderPipelineState_Handle :: distinct rawptr
MTLDepthStencilState_Handle :: distinct rawptr
MTLBuffer_Handle :: distinct rawptr
MTLTexture_Handle :: distinct rawptr
MTLDrawable_Handle :: distinct rawptr // e.g. id<CAMetalDrawable>
MTLVertexDescriptor_Handle :: distinct rawptr

// CAMetalLayer is a CoreAnimation layer, typically a pointer.
CAMetalLayer_Handle :: distinct rawptr 
// NSView_Handle or similar for the view hosting the CAMetalLayer
View_Handle :: distinct rawptr 
NSWindow_Handle :: distinct rawptr // For window operations like setTitle
NSString_Handle :: distinct rawptr // For Objective-C strings

// --- Metal Specific Internal Structs ---

// Mtl_Device_Internal: Stores core Metal device and command queue.
// This will be the variant data for Gfx_Device.
Mtl_Device_Internal :: struct {
	device:                  MTLDevice_Handle,
	command_queue:           MTLCommandQueue_Handle,
    active_command_buffer:   MTLCommandBuffer_Handle, 
    current_render_encoder:  MTLRenderCommandEncoder_Handle, // New
    primary_window:          ^Mtl_Window_Internal,    
	
	allocator:               mem.Allocator,
	// Store other global objects if needed, e.g. default library.
}

// Mtl_Window_Internal: Holds Metal specific data for a window, including its CAMetalLayer.
// This will be the variant data for Gfx_Window.
Mtl_Window_Internal :: struct {
	// If using SDL/GLFW, this might be a reference to the SDL_Window or GLFW_Window.
	// Or it could be a direct NSView/UIView handle if native windowing is used.
	// For stubs, a generic view_handle.
	view_handle:     View_Handle 
	ns_window_handle: NSWindow_Handle, // Conceptual handle to an NSWindow for operations like setTitle
	metal_layer:     CAMetalLayer_Handle // Attached to the view
	
	// Current drawable and render target texture, obtained from metal_layer per frame.
	current_drawable: MTLDrawable_Handle 
	// current_render_target_texture: MTLTexture_Handle // Derived from drawable

	// Depth texture and view, if used.
	// depth_texture: MTLTexture_Handle 
	
	width:           int // Drawable width
	height:          int // Drawable height
	format:          gfx_interface.Texture_Format // Or an MTLPixelFormat enum
	
	device_ref:      ^Mtl_Device_Internal // Reference back to the device
	allocator:       mem.Allocator
}

// Mtl_Shader_Internal: For compiled shader functions (MTLFunction).
// A MTLLibrary would typically store multiple MTLFunctions.
Mtl_Shader_Internal :: struct {
	library_handle:  MTLLibrary_Handle // Library containing the function
	function_handle: rawptr            // Placeholder for MTLFunction (actual type is id<MTLFunction>)
	stage:           gfx_interface.Shader_Stage
	allocator:       mem.Allocator,
}

// Mtl_Pipeline_Internal: For Metal, this is primarily the MTLRenderPipelineState.
Mtl_Pipeline_Internal :: struct {
	pipeline_state:      MTLRenderPipelineState_Handle
	depth_stencil_state: MTLDepthStencilState_Handle // Optional
	// Vertex descriptor might be part of pipeline state or set separately.
	// Other states like cull mode, winding order are part of MTLRenderPipelineDescriptor.
	allocator:           mem.Allocator,
}

// Mtl_Buffer_Internal: For MTLBuffer objects.
Mtl_Buffer_Internal :: struct {
	buffer_handle:   MTLBuffer_Handle
	size_in_bytes:   int
	type:            gfx_interface.Buffer_Type
	// storage_mode: MTLStorageMode (shared, private, managed)
	dynamic:         bool 
	allocator:       mem.Allocator,
}

// Mtl_Texture_Internal: For MTLTexture objects.
Mtl_Texture_Internal :: struct {
	texture_handle:  MTLTexture_Handle
	width:           int
	height:          int
	format:          gfx_interface.Texture_Format // Or an MTLPixelFormat
	// texture_type: MTLTextureType (e.g., .Type2D)
	// usage: MTLTextureUsage
	allocator:       mem.Allocator,
}

// Mtl_Vertex_Array_Internal: In Metal, this corresponds to a MTLVertexDescriptor,
// which describes the layout of vertex data and how it maps to vertex shader inputs.
// It's used when creating a MTLRenderPipelineState.
Mtl_Vertex_Array_Internal :: struct {
	vertex_descriptor: MTLVertexDescriptor_Handle
	// This might also store information about which buffers are bound to which attribute table entries,
	// though that's often set at draw call time with setVertexBuffer:offset:atIndex:.
	allocator:         mem.Allocator,
}


// --- Gfx_Device and Gfx_Window variants for Metal ---
Mtl_Device_Variant        :: ^Mtl_Device_Internal
Mtl_Window_Variant        :: ^Mtl_Window_Internal
Mtl_Shader_Variant        :: ^Mtl_Shader_Internal
Mtl_Pipeline_Variant      :: ^Mtl_Pipeline_Internal
Mtl_Buffer_Variant        :: ^Mtl_Buffer_Internal
Mtl_Texture_Variant       :: ^Mtl_Texture_Internal
Mtl_Vertex_Array_Variant  :: ^Mtl_Vertex_Array_Internal
