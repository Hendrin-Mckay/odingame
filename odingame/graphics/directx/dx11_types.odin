package directx11

import "../gfx_interface"
import "core:mem"
// It's crucial that actual DirectX bindings are available.
// For this exercise, we'll assume a vendor package like "vendor:dx" or "vendor:windows"
// provides the necessary types (e.g., d3d11.ID3D11Device, dxgi.IDXGISwapChain, windows.HWND).
// Since I cannot add new vendor packages, I will continue using distinct rawptr handles
// and note where specific types from such a package would be used.
// import "vendor:dx" 

// --- DirectX 11 Object Handles ---

ID3D11Device_Handle :: distinct rawptr           // Expected: ^d3d11.ID3D11Device
ID3D11DeviceContext_Handle :: distinct rawptr    // Expected: ^d3d11.ID3D11DeviceContext (Immediate Context)
IDXGIFactory_Handle :: distinct rawptr           // Expected: ^dxgi.IDXGIFactory or IDXGIFactory1/2
IDXGISwapChain_Handle :: distinct rawptr         // Expected: ^dxgi.IDXGISwapChain or IDXGISwapChain1
ID3D11RenderTargetView_Handle :: distinct rawptr // Expected: ^d3d11.ID3D11RenderTargetView
ID3D11DepthStencilView_Handle :: distinct rawptr// Expected: ^d3d11.ID3D11DepthStencilView
ID3D11Texture2D_Handle :: distinct rawptr        // Expected: ^d3d11.ID3D11Texture2D
ID3D11ShaderResourceView_Handle :: distinct rawptr // Expected: ^d3d11.ID3D11ShaderResourceView
ID3D11Buffer_Handle :: distinct rawptr           // Expected: ^d3d11.ID3D11Buffer
ID3D11VertexShader_Handle :: distinct rawptr     // Expected: ^d3d11.ID3D11VertexShader
ID3D11PixelShader_Handle :: distinct rawptr      // Expected: ^d3d11.ID3D11PixelShader
// GS, HS, DS, CS handles would go here if supported
ID3D11InputLayout_Handle :: distinct rawptr      // Expected: ^d3d11.ID3D11InputLayout
ID3D11BlendState_Handle :: distinct rawptr       // Expected: ^d3d11.ID3D11BlendState
ID3D11DepthStencilState_Handle :: distinct rawptr// Expected: ^d3d11.ID3D11DepthStencilState
ID3D11RasterizerState_Handle :: distinct rawptr  // Expected: ^d3d11.ID3D11RasterizerState
ID3D11SamplerState_Handle :: distinct rawptr     // Expected: ^d3d11.ID3D11SamplerState

HWND_Handle :: distinct rawptr                   // Expected: windows.HWND
ID3DBlob_Handle :: distinct rawptr               // Expected: ^d3dcommon.ID3DBlob

// --- Internal Types ---

D3D11_Device_Internal :: struct {
    device:            ID3D11Device_Handle,
    immediate_context: ID3D11DeviceContext_Handle,
    dxgi_factory:      IDXGIFactory_Handle, // Added
    allocator:         mem.Allocator,
    debug_device:      bool, // To know if debug layer was enabled
}

D3D11_Window_Internal :: struct {
    hwnd:              HWND_Handle,
    swap_chain:        IDXGISwapChain_Handle,
    render_target_view:ID3D11RenderTargetView_Handle, // Renamed for clarity
    // depth_stencil_view: ID3D11DepthStencilView_Handle, // To be added later
    width:             int,
    height:            int,
    vsync:             bool, // Will be used by Present flags
    // fullscreen:       bool, // Handled by swapchain desc and ResizeTarget
    device_ref:        ^D3D11_Device_Internal, // Reference back to the device
    allocator:         mem.Allocator,
}

// Other internal structs (D3D11_Shader_Internal, etc.) remain as they were.
// They are not the primary focus of this subtask but are correctly defined with placeholders.
D3D11_Shader_Object_Union :: union {
    vs: ID3D11VertexShader_Handle,
    ps: ID3D11PixelShader_Handle,
    // gs: ID3D11GeometryShader_Handle,
    // hs: ID3D11HullShader_Handle,
    // ds: ID3D11DomainShader_Handle,
    // cs: ID3D11ComputeShader_Handle,
}

D3D11_Shader_Internal :: struct {
    shader_object: D3D11_Shader_Object_Union, // The actual D3D11 shader object
    bytecode_blob: ID3DBlob_Handle,           // Store bytecode, especially for VS (input layout) and GS
    stage:         gfx_interface.Shader_Stage,  // Vertex, Pixel, etc.
    allocator:     mem.Allocator,
}

D3D11_Pipeline_Internal :: struct {
    // Shader handles (referencing, not owning the D3D11 COM objects directly here)
    // The Gfx_Shader handles are stored to allow access to their internal D3D objects (like VS/PS handles and VS bytecode)
    vertex_shader_ref:   gfx_interface.Gfx_Shader, 
    pixel_shader_ref:    gfx_interface.Gfx_Shader, 
    // geometry_shader_ref: gfx_interface.Gfx_Shader, // Example for future extension
    // hull_shader_ref:     gfx_interface.Gfx_Shader,
    // domain_shader_ref:   gfx_interface.Gfx_Shader,
    // compute_shader_ref:  gfx_interface.Gfx_Shader,

    input_layout:        ID3D11InputLayout_Handle,       // Owned by this pipeline object
    blend_state:         ID3D11BlendState_Handle,        // Owned by this pipeline object
    depth_stencil_state: ID3D11DepthStencilState_Handle, // Owned by this pipeline object
    rasterizer_state:    ID3D11RasterizerState_Handle,   // Owned by this pipeline object
    
    primitive_topology:  gfx_interface.Primitive_Topology, // The engine-level topology type

    allocator:           mem.Allocator,
}

D3D11_Buffer_Internal :: struct {
    buffer:          ID3D11Buffer_Handle,
    buffer_type:     gfx_interface.Buffer_Type, 
    size:            int,    // In bytes
    // dynamic:         bool, // Replaced by usage and cpu_access for more detail
    usage:           D3D11_USAGE, // Actual D3D11 usage
    cpu_access:      UINT,      // Actual D3D11 CPU access flags
    allocator:       mem.Allocator,
}

D3D11_Texture_Internal :: struct {
    texture:         ID3D11Texture2D_Handle,
    srv:             ID3D11ShaderResourceView_Handle, // Shader Resource View
    rtv:             ID3D11RenderTargetView_Handle, // Optional, if it can be a render target
    dsv:             ID3D11DepthStencilView_Handle, // Optional, if it can be a depth/stencil target
    width:           int,
    height:          int,
    // format:          gfx_interface.Texture_Format, // Store the engine-level format if needed for reconversion, or rely on dxgi_format_actual
    dxgi_format_actual: DXGI_FORMAT, // Actual DXGI_FORMAT used for creation
    d3d_usage:       D3D11_USAGE,   // Actual D3D11_USAGE used
    d3d_cpu_access:  UINT,          // Actual D3D11_CPU_ACCESS_FLAG used
    mip_levels:      int,
    allocator:       mem.Allocator,
}

D3D11_Render_Pass_Internal :: struct {
    // D3D11 doesn't have a direct RenderPass object like Vulkan.
    // This might store target views or configuration for a pass.
    // For now, it's conceptual.
    render_target_views:   []ID3D11RenderTargetView_Handle,
    depth_stencil_view:    ID3D11DepthStencilView_Handle,
    // clear_colors:     []gfx_interface.Color, // Clear colors are applied directly
    // clear_depth:      f32,
    // clear_stencil:    u32,
    allocator:        mem.Allocator,
}

D3D11_Framebuffer_Internal :: struct {
    // Similar to RenderPass, D3D11 FBOs are a collection of views set at render time.
    // This struct would hold these views if we pre-create them.
    render_target_views:   []ID3D11RenderTargetView_Handle,
    depth_stencil_view:    ID3D11DepthStencilView_Handle,
    width:            int,
    height:           int,
    allocator:        mem.Allocator,
}

// --- Variant Types ---

D3D11_Device_Variant :: ^D3D11_Device_Internal
D3D11_Window_Variant :: ^D3D11_Window_Internal
D3D11_Shader_Variant :: ^D3D11_Shader_Internal
D3D11_Pipeline_Variant :: ^D3D11_Pipeline_Internal
D3D11_Buffer_Variant :: ^D3D11_Buffer_Internal
D3D11_Texture_Variant :: ^D3D11_Texture_Internal
D3D11_Render_Pass_Variant :: ^D3D11_Render_Pass_Internal
D3D11_Framebuffer_Variant :: ^D3D11_Framebuffer_Internal
D3D11_Vertex_Array_Variant :: rawptr // Corresponds to ID3D11InputLayout, often part of Shader or Pipeline state

// --- Helper Functions ---

get_device_internal :: proc(device: gfx_interface.Gfx_Device) -> ^D3D11_Device_Internal {
    if device.variant == nil { return nil }
    internal, ok := device.variant.(D3D11_Device_Variant)
    if !ok { return nil }
    return internal
}

// --- Format Conversion Helpers ---

// Returns the DXGI_FORMAT, bytes per pixel for that format, and success.
to_dxgi_format_and_bpp :: proc(format: gfx_interface.Texture_Format) -> (dxgi: DXGI_FORMAT, bpp: int, ok: bool) {
    switch format {
    case .Undefined:
        return .UNKNOWN, 0, false
    case .R8_UNORM:
        return .R8_UNORM, 1, true
    case .RG8_UNORM:
        return .R8G8_UNORM, 2, true
    // case .RGB8_UNORM: // No direct DXGI_FORMAT_R8G8B8_UNORM. Often emulated or BGR used.
    //     return .UNKNOWN, 3, false // Or handle conversion/mapping
    case .RGBA8_UNORM:
        return .R8G8B8A8_UNORM, 4, true
    case .BGRA8_UNORM:
        return .B8G8R8A8_UNORM, 4, true
    case .R32_FLOAT:
        return .R32_FLOAT, 4, true
    case .RGBA32_FLOAT:
        return .R32G32B32A32_FLOAT, 16, true
    case .DEPTH24_STENCIL8:
        // For depth textures, the typeless format is often used for the texture itself,
        // and specific typed formats for DSV and SRV.
        // For simplicity, let's return the common DSV format.
        // SRV would be .R24_UNORM_X8_TYPELESS.
        return .D24_UNORM_S8_UINT, 4, true 
    // Add more mappings as needed by gfx_interface.Texture_Format
    }
    return .UNKNOWN, 0, false
}

// Optional: Convert DXGI_FORMAT back to engine's Texture_Format
to_gfx_texture_format :: proc(format: DXGI_FORMAT) -> (gfx_fmt: gfx_interface.Texture_Format, ok: bool) {
    switch format {
    case .R8_UNORM:
        return .R8_UNORM, true
    case .R8G8_UNORM:
        return .RG8_UNORM, true
    case .R8G8B8A8_UNORM:
        return .RGBA8_UNORM, true
    case .B8G8R8A8_UNORM:
        return .BGRA8_UNORM, true
    case .R32_FLOAT:
        return .R32_FLOAT, true
    case .R32G32B32A32_FLOAT:
        return .RGBA32_FLOAT, true
    case .D24_UNORM_S8_UINT:
        return .DEPTH24_STENCIL8, true
    // Add more mappings
    }
    return .Undefined, false
}

get_window_internal :: proc(window: gfx_interface.Gfx_Window) -> ^D3D11_Window_Internal {
    if window.variant == nil { return nil }
    internal, ok := window.variant.(D3D11_Window_Variant)
    if !ok { return nil }
    return internal
}
