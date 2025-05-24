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


// --- Metal Specific Internal Structs ---

// Mtl_Device_Internal: Stores core Metal device and command queue.
// This will be the variant data for Gfx_Device.
Mtl_Device_Internal :: struct {
	device:          MTLDevice_Handle
	command_queue:   MTLCommandQueue_Handle
	
	allocator:       mem.Allocator
	// Store other global objects if needed, e.g. default library.
}

// Mtl_Window_Internal: Holds Metal specific data for a window, including its CAMetalLayer.
// This will be the variant data for Gfx_Window.
Mtl_Window_Internal :: struct {
	// If using SDL/GLFW, this might be a reference to the SDL_Window or GLFW_Window.
	// Or it could be a direct NSView/UIView handle if native windowing is used.
	// For stubs, a generic view_handle.
	view_handle:     View_Handle 
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

// MTL_Pipeline_Internal: For Metal, this is primarily the MTLRenderPipelineState.
MTL_Pipeline_Internal :: struct { // Renamed for consistency
	pipeline_state:      MTLRenderPipelineState_Handle  // The baked PSO
	vertex_function:     MTLFunction_Handle           // Reference to the vertex function used (not owned)
	fragment_function:   MTLFunction_Handle         // Reference to the fragment function used (not owned)
    vertex_descriptor:   MTLVertexDescriptor_Handle   // Optional: if a custom VD was created and set (owned by pipeline)
	depth_stencil_state: MTLDepthStencilState_Handle  // Optional: if a custom DSS was created and set (owned by pipeline)
                                                    // Rasterizer state (cull, fill) is part of PSO.
                                                    // Blend state (for color attachments) is part of PSO.
	primitive_topology:  MTLPrimitiveType           // The topology this PSO was compiled for (from descriptor)
	allocator:           mem.Allocator,
}

// Mtl_Buffer_Internal: For MTLBuffer objects.
MTL_Buffer_Internal :: struct { // Renamed for consistency from Mtl_ to MTL_
	buffer:          MTLBuffer_Handle // Renamed from buffer_handle for consistency
	size:            int              // Renamed from size_in_bytes
	options:         MTLResourceOptions // Store the actual Metal resource options used
	allocator:       mem.Allocator,
	// type:            gfx_interface.Buffer_Type, // Engine-level type can be stored if needed for logic, but options are key for Metal
	// dynamic:         bool, // Superseded by options like StorageModeShared/Managed
}

// MTL_Texture_Internal: For MTLTexture objects.
MTL_Texture_Internal :: struct { // Renamed for consistency
	texture:         MTLTexture_Handle      // Renamed from texture_handle
    texture_type:    MTLTextureType         // Added
    pixel_format:    MTLPixelFormat         // Added (actual Metal format)
	width:           int
	height:          int
    depth:           int                    // Added (for 3D textures or array layers if Type1D/2DArray)
    mipmap_levels:   int                    // Added
    array_length:    int                    // Added
    usage:           MTLTextureUsage        // Added
    storage_mode:    MTLStorageMode         // Added
	allocator:       mem.Allocator,
    // format:          gfx_interface.Texture_Format // Store original engine format if needed for mapping back
}

// Mtl_Vertex_Array_Internal: In Metal, this corresponds to a MTLVertexDescriptor,
// which describes the layout of vertex data and how it maps to vertex shader inputs.
// It's used when creating a MTLRenderPipelineState.
MTL_Vertex_Array_Internal :: struct { // Renamed for consistency
	vertex_descriptor: MTLVertexDescriptor_Handle 
	allocator:         mem.Allocator,
}


// --- Gfx_Device and Gfx_Window variants for Metal ---
MTL_Device_Variant        :: ^MTL_Device_Internal 
MTL_Window_Variant        :: ^MTL_Window_Internal 
MTL_Shader_Variant        :: ^MTL_Shader_Internal 
MTL_Pipeline_Variant      :: ^MTL_Pipeline_Internal 
MTL_Buffer_Variant        :: ^MTL_Buffer_Internal 
MTL_Texture_Variant       :: ^MTL_Texture_Internal 
MTL_Vertex_Array_Variant  :: ^MTL_Vertex_Array_Internal
