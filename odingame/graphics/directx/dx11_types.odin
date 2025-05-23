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
ID3D11InputLayout_Handle :: distinct rawptr      // Expected: ^d3d11.ID3D11InputLayout
ID3D11BlendState_Handle :: distinct rawptr       // Expected: ^d3d11.ID3D11BlendState
ID3D11DepthStencilState_Handle :: distinct rawptr// Expected: ^d3d11.ID3D11DepthStencilState
ID3D11RasterizerState_Handle :: distinct rawptr  // Expected: ^d3d11.ID3D11RasterizerState
ID3D11SamplerState_Handle :: distinct rawptr     // Expected: ^d3d11.ID3D11SamplerState

HWND_Handle :: distinct rawptr                   // Expected: windows.HWND

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
D3D11_Shader_Internal :: struct {
    vs:              ID3D11VertexShader_Handle,
    ps:              ID3D11PixelShader_Handle,
    input_layout:    ID3D11InputLayout_Handle,
    stage:           gfx_interface.Shader_Stage,
    allocator:       mem.Allocator,
}

D3D11_Pipeline_Internal :: struct {
    blend_state:     ID3D11BlendState_Handle,
    depth_stencil_state: ID3D11DepthStencilState_Handle,
    rasterizer_state: ID3D11RasterizerState_Handle,
    primitive_topology: gfx_interface.Primitive_Topology, // D3D11_PRIMITIVE_TOPOLOGY
    allocator:       mem.Allocator,
}

D3D11_Buffer_Internal :: struct {
    buffer:          ID3D11Buffer_Handle,
    buffer_type:     gfx_interface.Buffer_Type, // To map to D3D11_BIND_FLAG
    size:            int,    // In bytes
    dynamic:         bool,   // To map to D3D11_USAGE
    allocator:       mem.Allocator,
}

D3D11_Texture_Internal :: struct {
    texture:         ID3D11Texture2D_Handle,
    srv:             ID3D11ShaderResourceView_Handle, // Shader Resource View
    rtv:             ID3D11RenderTargetView_Handle, // Optional, if it can be a render target
    dsv:             ID3D11DepthStencilView_Handle, // Optional, if it can be a depth/stencil target
    width:           int,
    height:          int,
    format:          gfx_interface.Texture_Format, // To map to DXGI_FORMAT
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

get_window_internal :: proc(window: gfx_interface.Gfx_Window) -> ^D3D11_Window_Internal {
    if window.variant == nil { return nil }
    internal, ok := window.variant.(D3D11_Window_Variant)
    if !ok { return nil }
    return internal
}
