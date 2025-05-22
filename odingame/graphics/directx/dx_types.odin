package directx

// This file defines placeholder types for DirectX objects and internal structures
// for the DirectX backend. No actual DirectX headers are included or used.
// These are conceptual stand-ins for what would be DirectX COM interface pointers.

import "../gfx_interface" // For Gfx_Device, Gfx_Window etc.
import "core:mem"
import "core:windows" // For HWND (window handle), assuming this is available for Windows target

// --- Placeholder DirectX Object Handles ---
// In a real implementation, these would be pointers to COM interfaces (e.g., ^IDXGIFactory)
// For stubs, we can use distinct rawptr or empty structs to represent them.
DXGI_Factory_Handle :: distinct rawptr
DXGI_Adapter_Handle :: distinct rawptr
DXGI_Output_Handle :: distinct rawptr
DXGI_SwapChain_Handle :: distinct rawptr

D3D11_Device_Handle :: distinct rawptr
D3D11_DeviceContext_Handle :: distinct rawptr // Immediate context

D3D11_Resource_Handle :: distinct rawptr      // Generic resource (textures, buffers)
D3D11_Buffer_Handle :: distinct rawptr         // Specifically for buffers
D3D11_Texture2D_Handle :: distinct rawptr     // Specifically for 2D textures

D3D11_RenderTargetView_Handle :: distinct rawptr
D3D11_DepthStencilView_Handle :: distinct rawptr
D3D11_ShaderResourceView_Handle :: distinct rawptr

D3D11_VertexShader_Handle :: distinct rawptr
D3D11_PixelShader_Handle :: distinct rawptr
D3D11_InputLayout_Handle :: distinct rawptr
// Add other shader types (Geometry, Hull, Domain, Compute) if interface expands

// D3D11_BlendState_Handle :: distinct rawptr
// D3D11_DepthStencilState_Handle :: distinct rawptr
// D3D11_RasterizerState_Handle :: distinct rawptr
// D3D11_SamplerState_Handle :: distinct rawptr


// --- DirectX Specific Internal Structs ---

// Dx_Device_Internal: Stores core D3D11 device, context, and DXGI factory.
// This will be the variant data for Gfx_Device.
Dx_Device_Internal :: struct {
	factory:         DXGI_Factory_Handle
	adapter:         DXGI_Adapter_Handle       // Selected adapter
	device:          D3D11_Device_Handle       // D3D11 Device
	immediate_context: D3D11_DeviceContext_Handle // D3D11 Immediate Device Context
	
	allocator:       mem.Allocator
	// Store feature level, other capabilities if needed
}

// Dx_Window_Internal: Holds DirectX specific data for a window, including swapchain.
// This will be the variant data for Gfx_Window.
Dx_Window_Internal :: struct {
	hwnd:            windows.HWND // Window handle from OS
	swap_chain:      DXGI_SwapChain_Handle
	render_target_view: D3D11_RenderTargetView_Handle
	depth_stencil_view: D3D11_DepthStencilView_Handle // Optional
	
	// Current back buffer resource (changes per frame for some swap effects)
	// current_back_buffer: D3D11_Texture2D_Handle 
	
	width:           int
	height:          int
	format:          gfx_interface.Texture_Format // Or a DXGI_FORMAT enum
	
	device_ref:      ^Dx_Device_Internal // Reference back to the device
	allocator:       mem.Allocator
}

// Dx_Shader_Internal: For compiled shader objects.
Dx_Shader_Internal :: struct {
	// Could store separate handles for VS, PS etc. or a generic blob
	bytecode:        rawptr // Placeholder for compiled shader blob
	stage:           gfx_interface.Shader_Stage
	vs_handle:       D3D11_VertexShader_Handle // If stage is Vertex
	ps_handle:       D3D11_PixelShader_Handle  // If stage is Fragment
	// ... other shader type handles
	allocator:       mem.Allocator,
}

// Dx_Pipeline_Internal: For D3D11, this is less a single "pipeline object" like Vulkan/Metal
// and more a collection of states (shaders, input layout, blend, depth, rasterizer).
// For simplicity in the stub, it might just hold shader handles and input layout.
Dx_Pipeline_Internal :: struct {
	vertex_shader:   D3D11_VertexShader_Handle
	pixel_shader:    D3D11_PixelShader_Handle
	input_layout:    D3D11_InputLayout_Handle // Crucial for linking VS to vertex buffers
	// Store other states like blend, depth-stencil, rasterizer if created upfront.
	allocator:       mem.Allocator,
}

// Dx_Buffer_Internal: For vertex, index, constant buffers.
Dx_Buffer_Internal :: struct {
	buffer_handle:   D3D11_Buffer_Handle
	size_in_bytes:   int
	type:            gfx_interface.Buffer_Type
	dynamic:         bool // CPU_ACCESS_WRITE for dynamic, DEFAULT for static
	allocator:       mem.Allocator,
}

// Dx_Texture_Internal: For 2D textures.
Dx_Texture_Internal :: struct {
	texture_handle:  D3D11_Texture2D_Handle
	srv_handle:      D3D11_ShaderResourceView_Handle // For sampling in shaders
	rtv_handle:      D3D11_RenderTargetView_Handle   // If it can be a render target
	dsv_handle:      D3D11_DepthStencilView_Handle   // If it can be a depth/stencil target
	width:           int
	height:          int
	format:          gfx_interface.Texture_Format
	allocator:       mem.Allocator,
}

// Dx_Vertex_Array_Internal: In D3D11, this concept is primarily embodied by the Input Layout,
// which is part of a pipeline or set before drawing. It defines how vertex buffer data maps to VS inputs.
// VAOs don't exist as separate objects like in GL.
// This might just store the D3D11_InputLayout_Handle, or be a collection of buffer bindings and layouts.
// For stubs, it can be simple.
Dx_Vertex_Array_Internal :: struct {
	input_layout:    D3D11_InputLayout_Handle // This is the most direct D3D11 equivalent
	// Could also store references to the vertex buffers and their strides/offsets if not fully managed by InputLayout alone.
	allocator:       mem.Allocator,
}


// --- Gfx_Device and Gfx_Window variants for DirectX ---
Dx_Device_Variant        :: ^Dx_Device_Internal
Dx_Window_Variant        :: ^Dx_Window_Internal
Dx_Shader_Variant        :: ^Dx_Shader_Internal
Dx_Pipeline_Variant      :: ^Dx_Pipeline_Internal
Dx_Buffer_Variant        :: ^Dx_Buffer_Internal
Dx_Texture_Variant       :: ^Dx_Texture_Internal
Dx_Vertex_Array_Variant  :: ^Dx_Vertex_Array_Internal
