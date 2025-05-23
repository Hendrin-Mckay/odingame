package directx11

import "../gfx_interface"
import "core:mem"

// --- DirectX 11 Object Handles ---

// These are placeholders for the actual Direct3D 11 COM interfaces
ID3D11Device_Handle :: distinct rawptr
ID3D11DeviceContext_Handle :: distinct rawptr
IDXGISwapChain_Handle :: distinct rawptr
ID3D11RenderTargetView_Handle :: distinct rawptr
ID3D11DepthStencilView_Handle :: distinct rawptr
ID3D11Texture2D_Handle :: distinct rawptr
ID3D11ShaderResourceView_Handle :: distinct rawptr
ID3D11Buffer_Handle :: distinct rawptr
ID3D11VertexShader_Handle :: distinct rawptr
ID3D11PixelShader_Handle :: distinct rawptr
ID3D11InputLayout_Handle :: distinct rawptr
ID3D11BlendState_Handle :: distinct rawptr
ID3D11DepthStencilState_Handle :: distinct rawptr
ID3D11RasterizerState_Handle :: distinct rawptr
ID3D11SamplerState_Handle :: distinct rawptr

// Window handle (HWND)
HWND_Handle :: distinct rawptr

// --- Internal Types ---

D3D11_Device_Internal :: struct {
    device:           ID3D11Device_Handle,
    immediate_context: ID3D11DeviceContext_Handle,
    allocator:        mem.Allocator,
    // Add other device-specific state here
}

D3D11_Window_Internal :: struct {
    hwnd:             HWND_Handle,
    swap_chain:       IDXGISwapChain_Handle,
    render_target:    ID3D11RenderTargetView_Handle,
    depth_stencil:    ID3D11DepthStencilView_Handle,
    width:            int,
    height:           int,
    vsync:            bool,
    fullscreen:       bool,
    device_ref:       ^D3D11_Device_Internal,
    allocator:        mem.Allocator,
}

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
    primitive_topology: gfx_interface.Primitive_Topology,
    allocator:       mem.Allocator,
}

D3D11_Buffer_Internal :: struct {
    buffer:          ID3D11Buffer_Handle,
    buffer_type:     gfx_interface.Buffer_Type,
    size:            int,
    dynamic:         bool,
    allocator:       mem.Allocator,
}

D3D11_Texture_Internal :: struct {
    texture:         ID3D11Texture2D_Handle,
    srv:             ID3D11ShaderResourceView_Handle,
    width:           int,
    height:          int,
    format:          gfx_interface.Texture_Format,
    mip_levels:      int,
    allocator:       mem.Allocator,
}

D3D11_Render_Pass_Internal :: struct {
    render_targets:   []ID3D11RenderTargetView_Handle,
    depth_stencil:    ID3D11DepthStencilView_Handle,
    clear_colors:     []gfx_interface.Color,
    clear_depth:      f32,
    clear_stencil:    u32,
    allocator:        mem.Allocator,
}

D3D11_Framebuffer_Internal :: struct {
    render_targets:   []ID3D11RenderTargetView_Handle,
    depth_stencil:    ID3D11DepthStencilView_Handle,
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
D3D11_Vertex_Array_Variant :: rawptr // Not used in DirectX 11

// --- Helper Functions ---

get_device_internal :: proc(device: gfx_interface.Gfx_Device) -> ^D3D11_Device_Internal {
    if device.variant == nil {
        return nil
    }
    internal, ok := device.variant.(D3D11_Device_Variant)
    if !ok {
        return nil
    }
    return internal
}

get_window_internal :: proc(window: gfx_interface.Gfx_Window) -> ^D3D11_Window_Internal {
    if window.variant == nil {
        return nil
    }
    internal, ok := window.variant.(D3D11_Window_Variant)
    if !ok {
        return nil
    }
    return internal
}

// Add similar getter functions for other internal types as needed
