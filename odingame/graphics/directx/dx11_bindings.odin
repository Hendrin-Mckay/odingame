package directx11

import "core:sys/windows" 
import "core:mem"
import "core:unicode/utf16"

// --- Foreign Libraries ---
#foreign_system_library "d3d11"
#foreign_system_library "dxgi"
#foreign_system_library "d3dcompiler_47" 

// --- Basic Windows Types & HRESULT ---
HRESULT :: windows.HRESULT
S_OK :: HRESULT(0)
E_FAIL :: HRESULT(0x80004005)
E_INVALIDARG :: HRESULT(0x80070057)
E_OUTOFMEMORY :: HRESULT(0x8007000E)
DXGI_ERROR_INVALID_CALL :: HRESULT(0x887A0001)
DXGI_ERROR_DEVICE_REMOVED :: HRESULT(0x887A0005)
DXGI_ERROR_SDK_COMPONENT_MISSING :: HRESULT(0x887A002D)

FAILED :: proc(hr: HRESULT) -> bool { return hr < 0 }
SUCCEEDED :: proc(hr: HRESULT) -> bool { return hr >= 0 }

UINT :: u32
BOOL :: windows.BOOL 
TRUE :: BOOL(1)
FALSE :: BOOL(0)
LPCSTR :: ^byte 
SIZE_T :: windows.SIZE_T
FLOAT :: f32 // For blend factor array

GUID :: struct { Data1: u32, Data2: u16, Data3: u16, Data4: [8]u8, }

// --- DXGI Enums & Structs ---
DXGI_FORMAT :: enum u32 {
    UNKNOWN, R32G32B32A32_TYPELESS, R32G32B32A32_FLOAT, R32G32B32A32_UINT, R32G32B32A32_SINT,
    R16G16B16A16_TYPELESS, R16G16B16A16_FLOAT, R16G16B16A16_UNORM, R16G16B16A16_UINT, R16G16B16A16_SNORM, R16G16B16A16_SINT,
    R32G32_TYPELESS, R32G32_FLOAT, R32G32_UINT, R32G32_SINT,
    R10G10B10A2_TYPELESS, R10G10B10A2_UNORM, R10G10B10A2_UINT,
    R11G11B10_FLOAT,
    R8G8B8A8_TYPELESS, R8G8B8A8_UNORM, R8G8B8A8_UNORM_SRGB, R8G8B8A8_UINT, R8G8B8A8_SNORM, R8G8B8A8_SINT,
    R16G16_TYPELESS, R16G16_FLOAT, R16G16_UNORM, R16G16_UINT, R16G16_SNORM, R16G16_SINT,
    R32_TYPELESS, R32_FLOAT, R32_UINT, R32_SINT,
    R8G8_TYPELESS, R8G8_UNORM, R8G8_UINT, R8G8_SNORM, R8G8_SINT,
    R16_TYPELESS, R16_FLOAT, R16_UNORM, R16_UINT, R16_SNORM, R16_SINT,
    R8_TYPELESS, R8_UNORM, R8_UINT, R8_SNORM, R8_SINT,
    BC1_TYPELESS, BC1_UNORM, BC1_UNORM_SRGB,
    BC2_TYPELESS, BC2_UNORM, BC2_UNORM_SRGB,
    BC3_TYPELESS, BC3_UNORM, BC3_UNORM_SRGB,
    BC4_TYPELESS, BC4_UNORM, BC4_SNORM,
    BC5_TYPELESS, BC5_UNORM, BC5_SNORM,
    B5G6R5_UNORM, B5G5R5A1_UNORM,
    B8G8R8A8_UNORM, B8G8R8X8_UNORM, B8G8R8A8_TYPELESS, B8G8R8A8_UNORM_SRGB, B8G8R8X8_TYPELESS, B8G8R8X8_UNORM_SRGB,
    D32_FLOAT = 40, D24_UNORM_S8_UINT = 45, R24G8_TYPELESS = 44, R24_UNORM_X8_TYPELESS = 46, X24_TYPELESS_G8_UINT = 47,
}
DXGI_SAMPLE_DESC :: struct { Count: UINT, Quality: UINT, }
DXGI_USAGE_RENDER_TARGET_OUTPUT :: (1 << 5) 
DXGI_USAGE_SHADER_INPUT :: (1 << 4)
DXGI_SCALING :: enum u32 { STRETCH, NONE, ASPECT_RATIO_STRETCH, }
DXGI_SWAP_EFFECT :: enum u32 { DISCARD, SEQUENTIAL, FLIP_SEQUENTIAL, FLIP_DISCARD, }
DXGI_ALPHA_MODE :: enum u32 { UNSPECIFIED, PREMULTIPLIED, STRAIGHT, IGNORE, }
DXGI_SWAP_CHAIN_FLAG :: enum u32 { NONE = 0, NONPREROTATED = 1, ALLOW_MODE_SWITCH = 2, GDI_COMPATIBLE = 4, RESTRICTED_CONTENT = 8, RESTRICT_SHARED_RESOURCE_DRIVER = 16, DISPLAY_ONLY = 32, FRAME_LATENCY_WAITABLE_OBJECT = 64, FOREGROUND_LAYER = 128, FULLSCREEN_VIDEO = 256, YUV_VIDEO = 512, HW_PROTECTED = 1024, ALLOW_TEARING = 2048, RESTRICTED_TO_ALL_HOLOGRAPHIC_DISPLAYS = 4096, }
DXGI_SWAP_CHAIN_DESC1 :: struct { Width: UINT, Height: UINT, Format: DXGI_FORMAT, Stereo: BOOL, SampleDesc: DXGI_SAMPLE_DESC, BufferUsage:UINT, BufferCount:UINT, Scaling: DXGI_SCALING, SwapEffect: DXGI_SWAP_EFFECT, AlphaMode: DXGI_ALPHA_MODE, Flags: UINT, }
DXGI_SWAP_CHAIN_FULLSCREEN_DESC :: struct { RefreshRate: struct { Numerator: UINT, Denominator: UINT }, ScanlineOrdering: enum u32 { UNSPECIFIED, PROGRESSIVE, UPPER_FIELD_FIRST, LOWER_FIELD_FIRST, }, Scaling: enum u32 { UNSPECIFIED_FS = 0, CENTERED, STRETCHED_FS = 3, }, Windowed: BOOL, }

// --- D3D11 Enums & Structs ---
D3D11_CREATE_DEVICE_FLAG :: enum u32 { NONE = 0, SINGLETHREADED = 0x1, DEBUG = 0x2, SWITCH_TO_REF = 0x4, PREVENT_INTERNAL_THREADING_OPTIMIZATIONS = 0x8, BGRA_SUPPORT = 0x20, DEBUGGABLE = 0x40, PREVENT_ALTERING_LAYER_SETTINGS_FROM_REGISTRY = 0x80, DISABLE_GPU_TIMEOUT = 0x100, VIDEO_SUPPORT = 0x800, }
D3D_DRIVER_TYPE :: enum u32 { UNKNOWN, HARDWARE, REFERENCE, NULL_DEVICE, SOFTWARE, }
D3D_FEATURE_LEVEL :: enum u32 { L9_1 = 0x9100, L9_2 = 0x9200, L9_3 = 0x9300, L10_0 = 0xa000, L10_1 = 0xa100, L11_0 = 0xb000, L11_1 = 0xb100, }
D3D11_SDK_VERSION :: 7

D3D11_USAGE :: enum u32 { DEFAULT = 0, IMMUTABLE = 1, DYNAMIC = 2, STAGING = 3, }
D3D11_BIND_FLAG :: enum u32 { NONE = 0, VERTEX_BUFFER = 0x1, INDEX_BUFFER = 0x2, CONSTANT_BUFFER = 0x4, SHADER_RESOURCE = 0x8, STREAM_OUTPUT = 0x10, RENDER_TARGET = 0x20, DEPTH_STENCIL = 0x40, UNORDERED_ACCESS = 0x80, DECODER = 0x200, VIDEO_ENCODER = 0x400, }
D3D11_CPU_ACCESS_FLAG :: enum u32 { NONE = 0, WRITE = 0x10000, READ = 0x20000, }
D3D11_RESOURCE_MISC_FLAG :: enum u32 { NONE = 0, GENERATE_MIPS = 0x1, SHARED = 0x2, TEXTURECUBE = 0x4, DRAWINDIRECT_ARGS = 0x10, BUFFER_ALLOW_RAW_VIEWS = 0x20, BUFFER_STRUCTURED = 0x40, RESOURCE_CLAMP = 0x80, SHARED_KEYEDMUTEX = 0x100, GDI_COMPATIBLE = 0x200, }
D3D11_MAP :: enum u32 { READ = 1, WRITE = 2, READ_WRITE = 3, WRITE_DISCARD = 4, WRITE_NO_OVERWRITE = 5, }
D3D11_MAP_FLAG :: enum u32 { NONE = 0, DO_NOT_WAIT = 0x100000, }

D3D11_BUFFER_DESC :: struct { ByteWidth: UINT, Usage: D3D11_USAGE, BindFlags: UINT, CPUAccessFlags: UINT, MiscFlags: UINT, StructureByteStride: UINT, }
D3D11_TEXTURE2D_DESC :: struct { Width: UINT, Height: UINT, MipLevels: UINT, ArraySize: UINT, Format: DXGI_FORMAT, SampleDesc: DXGI_SAMPLE_DESC, Usage: D3D11_USAGE, BindFlags: UINT, CPUAccessFlags: UINT, MiscFlags: UINT, }
D3D11_SUBRESOURCE_DATA :: struct { pSysMem: rawptr, SysMemPitch: UINT, SysMemSlicePitch: UINT, }
D3D11_BOX :: struct { left, top, front: UINT, right, bottom, back: UINT, }
D3D11_MAPPED_SUBRESOURCE :: struct { pData: rawptr, RowPitch: UINT, DepthPitch: UINT, }

// Input Assembler Stage
D3D11_INPUT_CLASSIFICATION :: enum u32 { PER_VERTEX_DATA = 0, PER_INSTANCE_DATA = 1, }
D3D11_INPUT_ELEMENT_DESC :: struct {
    SemanticName: LPCSTR,
    SemanticIndex: UINT,
    Format: DXGI_FORMAT,
    InputSlot: UINT,
    AlignedByteOffset: UINT, // Use D3D11_APPEND_ALIGNED_ELEMENT for automatic offset
    InputSlotClass: D3D11_INPUT_CLASSIFICATION,
    InstanceDataStepRate: UINT, // 0 for per-vertex, >=1 for per-instance
}
D3D11_APPEND_ALIGNED_ELEMENT :: 0xffffffff

D3D_PRIMITIVE_TOPOLOGY :: enum u32 { // Renamed from D3D11_PRIMITIVE_TOPOLOGY for consistency if used elsewhere
    UNDEFINED = 0, POINTLIST = 1, LINELIST = 2, LINESTRIP = 3, TRIANGLELIST = 4, TRIANGLESTRIP = 5,
    LINELIST_ADJ = 10, LINESTRIP_ADJ = 11, TRIANGLELIST_ADJ = 12, TRIANGLESTRIP_ADJ = 13,
    CONTROL_POINT_PATCHLIST_1 = 33, // Hull shader related
    // ... up to CONTROL_POINT_PATCHLIST_32
}

// Blend State
D3D11_BLEND :: enum u32 { ZERO = 1, ONE = 2, SRC_COLOR = 3, INV_SRC_COLOR = 4, SRC_ALPHA = 5, INV_SRC_ALPHA = 6, DEST_ALPHA = 7, INV_DEST_ALPHA = 8, DEST_COLOR = 9, INV_DEST_COLOR = 10, SRC_ALPHA_SAT = 11, BLEND_FACTOR = 14, INV_BLEND_FACTOR = 15, SRC1_COLOR = 16, INV_SRC1_COLOR = 17, SRC1_ALPHA = 18, INV_SRC1_ALPHA = 19, }
D3D11_BLEND_OP :: enum u32 { ADD = 1, SUBTRACT = 2, REV_SUBTRACT = 3, MIN = 4, MAX = 5, }
D3D11_COLOR_WRITE_ENABLE :: enum u8 { RED = 1, GREEN = 2, BLUE = 4, ALPHA = 8, ALL = (RED | GREEN | BLUE | ALPHA), }
D3D11_RENDER_TARGET_BLEND_DESC :: struct {
    BlendEnable: BOOL,
    SrcBlend: D3D11_BLEND, DestBlend: D3D11_BLEND, BlendOp: D3D11_BLEND_OP,
    SrcBlendAlpha: D3D11_BLEND, DestBlendAlpha: D3D11_BLEND, BlendOpAlpha: D3D11_BLEND_OP,
    RenderTargetWriteMask: u8, // D3D11_COLOR_WRITE_ENABLE flags
}
D3D11_BLEND_DESC :: struct {
    AlphaToCoverageEnable: BOOL,
    IndependentBlendEnable: BOOL, // If true, RenderTarget uses unique blend states. If false, only RenderTarget[0] is used.
    RenderTarget: [8]D3D11_RENDER_TARGET_BLEND_DESC, // Max 8 render targets
}

// Depth Stencil State
D3D11_DEPTH_WRITE_MASK :: enum u32 { ZERO = 0, ALL = 1, }
D3D11_COMPARISON_FUNC :: enum u32 { NEVER = 1, LESS = 2, EQUAL = 3, LESS_EQUAL = 4, GREATER = 5, NOT_EQUAL = 6, GREATER_EQUAL = 7, ALWAYS = 8, }
D3D11_STENCIL_OP :: enum u32 { KEEP = 1, ZERO = 2, REPLACE = 3, INCR_SAT = 4, DECR_SAT = 5, INVERT = 6, INCR = 7, DECR = 8, }
D3D11_DEPTH_STENCILOP_DESC :: struct { StencilFailOp: D3D11_STENCIL_OP, StencilDepthFailOp: D3D11_STENCIL_OP, StencilPassOp: D3D11_STENCIL_OP, StencilFunc: D3D11_COMPARISON_FUNC, }
D3D11_DEPTH_STENCIL_DESC :: struct {
    DepthEnable: BOOL, DepthWriteMask: D3D11_DEPTH_WRITE_MASK, DepthFunc: D3D11_COMPARISON_FUNC,
    StencilEnable: BOOL, StencilReadMask: u8, StencilWriteMask: u8,
    FrontFace: D3D11_DEPTH_STENCILOP_DESC, BackFace: D3D11_DEPTH_STENCILOP_DESC,
}

// Rasterizer State
D3D11_FILL_MODE :: enum u32 { WIREFRAME = 2, SOLID = 3, }
D3D11_CULL_MODE :: enum u32 { NONE = 1, FRONT = 2, BACK = 3, }
D3D11_RASTERIZER_DESC :: struct {
    FillMode: D3D11_FILL_MODE, CullMode: D3D11_CULL_MODE,
    FrontCounterClockwise: BOOL,
    DepthBias: INT, DepthBiasClamp: FLOAT, SlopeScaledDepthBias: FLOAT,
    DepthClipEnable: BOOL, ScissorEnable: BOOL, MultisampleEnable: BOOL, AntialiasedLineEnable: BOOL,
}


// Shader Resource View
D3D_SRV_DIMENSION :: enum u32 { UNKNOWN = 0, BUFFER = 1, TEXTURE1D = 2, TEXTURE1DARRAY = 3, TEXTURE2D = 4, TEXTURE2DARRAY = 5, TEXTURE2DMS = 6, TEXTURE2DMSARRAY = 7, TEXTURE3D = 8, TEXTURECUBE = 9, TEXTURECUBEARRAY = 10, BUFFEREX = 11, }
D3D11_TEX2D_SRV :: struct { MostDetailedMip: UINT, MipLevels: UINT, }
D3D11_SHADER_RESOURCE_VIEW_DESC :: struct { Format: DXGI_FORMAT, ViewDimension: D3D_SRV_DIMENSION, union #raw_union { Buffer: rawptr, Texture1D: rawptr, Texture1DArray: rawptr, Texture2D: D3D11_TEX2D_SRV, Texture2DArray: rawptr, Texture2DMS: rawptr, Texture2DMSArray: rawptr, Texture3D: rawptr, TextureCube: rawptr, TextureCubeArray: rawptr, BufferEx: rawptr, }, }

// D3DCompile related
D3D_SHADER_MACRO :: struct { Name: LPCSTR, Definition: LPCSTR, }
D3DCOMPILE_STANDARD_FILE_INCLUDE :: rawptr(1) 
D3DCOMPILE_DEBUG :: (1 << 0); D3DCOMPILE_SKIP_VALIDATION :: (1 << 1); D3DCOMPILE_SKIP_OPTIMIZATION :: (1 << 2); D3DCOMPILE_PACK_MATRIX_ROW_MAJOR :: (1 << 3); D3DCOMPILE_PACK_MATRIX_COLUMN_MAJOR :: (1 << 4); D3DCOMPILE_PARTIAL_PRECISION :: (1 << 5); D3DCOMPILE_OPTIMIZATION_LEVEL0 :: (1 << 14); D3DCOMPILE_OPTIMIZATION_LEVEL3 :: (1 << 15);

// --- VTable Structs ---
IUnknownVTable :: struct #ordered { QueryInterface: proc(this: rawptr, riid: ^GUID, ppvObject: ^rawptr) -> HRESULT, AddRef: proc(this: rawptr) -> u32, Release: proc(this: rawptr) -> u32, }
ID3DBlobVTable :: struct #ordered { QueryInterface_IUnknown: proc(this: rawptr, riid: ^GUID, ppvObject: ^rawptr) -> HRESULT, AddRef_IUnknown: proc(this: rawptr) -> u32, Release_IUnknown: proc(this: rawptr) -> u32, GetBufferPointer: proc(this: rawptr) -> rawptr, GetBufferSize: proc(this: rawptr) -> SIZE_T, }
IDXGIFactory2VTable :: struct #ordered { QueryInterface_IUnknown: proc(this: rawptr, riid: ^GUID, ppvObject: ^rawptr) -> HRESULT, AddRef_IUnknown: proc(this: rawptr) -> u32, Release_IUnknown: proc(this: rawptr) -> u32, SetPrivateData: proc(this: rawptr, Name: ^GUID, DataSize: UINT, pData: rawptr) -> HRESULT, SetPrivateDataInterface: proc(this: rawptr, Name: ^GUID, pUnknown: rawptr) -> HRESULT, GetPrivateData: proc(this: rawptr, Name: ^GUID, pDataSize: ^UINT, pData: rawptr) -> HRESULT, GetParent: proc(this: rawptr, riid: ^GUID, ppParent: ^rawptr) -> HRESULT, EnumAdapters: proc(this: rawptr, Adapter: UINT, ppAdapter: ^rawptr) -> HRESULT, MakeWindowAssociation: proc(this: rawptr, WindowHandle: windows.HWND, Flags: UINT) -> HRESULT, GetWindowAssociation: proc(this: rawptr, pWindowHandle: ^windows.HWND, pFlags: ^UINT) -> HRESULT, CreateSwapChain: proc(this: rawptr, pDevice: rawptr, pDesc: rawptr, ppSwapChain: ^rawptr) -> HRESULT, CreateSoftwareAdapter: proc(this: rawptr, Module: windows.HMODULE, ppAdapter: ^rawptr) -> HRESULT, EnumAdapters1: proc(this: rawptr, Adapter: UINT, ppAdapter1: ^rawptr) -> HRESULT, IsCurrent: proc(this: rawptr) -> BOOL, IsWindowedStereoEnabled: proc(this: rawptr) -> BOOL, CreateSwapChainForHwnd: proc(this: rawptr, pDevice: rawptr, hWnd: windows.HWND, pDesc: ^DXGI_SWAP_CHAIN_DESC1, pFullscreenDesc: ^DXGI_SWAP_CHAIN_FULLSCREEN_DESC, pRestrictToOutput: rawptr, ppSwapChain: ^rawptr) -> HRESULT, CreateSwapChainForCoreWindow: proc(this: rawptr, pDevice: rawptr, pWindow: rawptr, pDesc: ^DXGI_SWAP_CHAIN_DESC1, pRestrictToOutput: rawptr, ppSwapChain: ^rawptr) -> HRESULT, GetSharedResourceAdapterLuid: proc(this: rawptr, Luid: ^windows.LUID, pNumVidPnSources: ^UINT) -> HRESULT, RegisterStereoStatusWindow: proc(this: rawptr, WindowHandle: windows.HWND, wMsg: UINT, pdwCookie: ^u32) -> HRESULT, UnregisterStereoStatus: proc(this: rawptr, dwCookie: u32) -> HRESULT, RegisterOcclusionStatusWindow: proc(this: rawptr, WindowHandle: windows.HWND, wMsg: UINT, pdwCookie: ^u32) -> HRESULT, UnregisterOcclusionStatus: proc(this: rawptr, dwCookie: u32) -> HRESULT, CreateSwapChainForComposition: proc(this: rawptr, pDevice: rawptr, pDesc: ^DXGI_SWAP_CHAIN_DESC1, pRestrictToOutput: rawptr, ppSwapChain: ^rawptr) -> HRESULT, }
ID3D11DeviceVTable :: struct #ordered { QueryInterface_IUnknown: proc(this: rawptr, riid: ^GUID, ppvObject: ^rawptr) -> HRESULT, AddRef_IUnknown: proc(this: rawptr) -> u32, Release_IUnknown: proc(this: rawptr) -> u32, CreateBuffer: proc(this: rawptr, pDesc: ^D3D11_BUFFER_DESC, pInitialData: ^D3D11_SUBRESOURCE_DATA, ppBuffer: ^rawptr) -> HRESULT, CreateTexture1D: proc(this: rawptr, pDesc: rawptr, pInitialData: rawptr, ppTexture1D: ^rawptr) -> HRESULT, CreateTexture2D: proc(this: rawptr, pDesc: ^D3D11_TEXTURE2D_DESC, pInitialData: ^D3D11_SUBRESOURCE_DATA, ppTexture2D: ^rawptr) -> HRESULT, CreateTexture3D: proc(this: rawptr, pDesc: rawptr, pInitialData: rawptr, ppTexture3D: ^rawptr) -> HRESULT, CreateShaderResourceView: proc(this: rawptr, pResource: rawptr, pDesc: ^D3D11_SHADER_RESOURCE_VIEW_DESC, ppSRView: ^rawptr) -> HRESULT, CreateUnorderedAccessView: proc(this: rawptr, pResource: rawptr, pDesc: rawptr, ppUAView: ^rawptr) -> HRESULT, CreateRenderTargetView: proc(this: rawptr, pResource: rawptr, pDesc: rawptr, ppRTView: ^rawptr) -> HRESULT, CreateDepthStencilView: proc(this: rawptr, pResource: rawptr, pDesc: rawptr, ppDepthStencilView: ^rawptr) -> HRESULT, CreateInputLayout: proc(this: rawptr, pInputElementDescs: ^D3D11_INPUT_ELEMENT_DESC, NumElements: UINT, pShaderBytecodeWithInputSignature: rawptr, BytecodeLength: SIZE_T, ppInputLayout: ^rawptr) -> HRESULT, CreateVertexShader: proc(this: rawptr, pShaderBytecode: rawptr, BytecodeLength: SIZE_T, pClassLinkage: rawptr, ppVertexShader: ^rawptr) -> HRESULT, CreateGeometryShader: proc(this: rawptr, pShaderBytecode: rawptr, BytecodeLength: SIZE_T, pClassLinkage: rawptr, ppGeometryShader: ^rawptr) -> HRESULT, CreateGeometryShaderWithStreamOutput: proc(this: rawptr, pShaderBytecode: rawptr, BytecodeLength: SIZE_T, pSODeclaration: rawptr, NumEntries: UINT, pBufferStrides: ^UINT, NumStrides: UINT, RasterizedStream: UINT, pClassLinkage: rawptr, ppGeometryShader: ^rawptr) -> HRESULT, CreatePixelShader: proc(this: rawptr, pShaderBytecode: rawptr, BytecodeLength: SIZE_T, pClassLinkage: rawptr, ppPixelShader: ^rawptr) -> HRESULT, CreateHullShader: proc(this: rawptr, pShaderBytecode: rawptr, BytecodeLength: SIZE_T, pClassLinkage: rawptr, ppHullShader: ^rawptr) -> HRESULT, CreateDomainShader: proc(this: rawptr, pShaderBytecode: rawptr, BytecodeLength: SIZE_T, pClassLinkage: rawptr, ppDomainShader: ^rawptr) -> HRESULT, CreateComputeShader: proc(this: rawptr, pShaderBytecode: rawptr, BytecodeLength: SIZE_T, pClassLinkage: rawptr, ppComputeShader: ^rawptr) -> HRESULT, CreateClassLinkage: proc(this: rawptr, ppLinkage: ^rawptr) -> HRESULT, CreateBlendState: proc(this: rawptr, pBlendStateDesc: ^D3D11_BLEND_DESC, ppBlendState: ^rawptr) -> HRESULT, CreateDepthStencilState: proc(this: rawptr, pDepthStencilStateDesc: ^D3D11_DEPTH_STENCIL_DESC, ppDepthStencilState: ^rawptr) -> HRESULT, CreateRasterizerState: proc(this: rawptr, pRasterizerStateDesc: ^D3D11_RASTERIZER_DESC, ppRasterizerState: ^rawptr) -> HRESULT, CreateSamplerState: proc(this: rawptr, pSamplerDesc: rawptr, ppSamplerState: ^rawptr) -> HRESULT, CreateQuery: proc(this: rawptr, pQueryDesc: rawptr, ppQuery: ^rawptr) -> HRESULT, CreatePredicate: proc(this: rawptr, pPredicateDesc: rawptr, ppPredicate: ^rawptr) -> HRESULT, CreateCounter: proc(this: rawptr, pCounterDesc: rawptr, ppCounter: ^rawptr) -> HRESULT, CreateDeferredContext: proc(this: rawptr, ContextFlags: UINT, ppDeferredContext: ^rawptr) -> HRESULT, OpenSharedResource: proc(this: rawptr, hResource: windows.HANDLE, ReturnedInterface: ^GUID, ppResource: ^rawptr) -> HRESULT, CheckFormatSupport: proc(this: rawptr, Format: DXGI_FORMAT, pFormatSupport: ^UINT) -> HRESULT, CheckMultisampleQualityLevels: proc(this: rawptr, Format: DXGI_FORMAT, SampleCount: UINT, pNumQualityLevels: ^UINT) -> HRESULT, CheckFeatureSupport: proc(this: rawptr, Feature: UINT, pFeatureSupportData: rawptr, FeatureSupportDataSize: UINT) -> HRESULT, GetPrivateData_Device: proc(this: rawptr, guid: ^GUID, pDataSize: ^UINT, pData: rawptr) -> HRESULT, SetPrivateData_Device: proc(this: rawptr, guid: ^GUID, DataSize: UINT, pData: rawptr) -> HRESULT, SetPrivateDataInterface_Device: proc(this: rawptr, guid: ^GUID, pData: rawptr) -> HRESULT, GetFeatureLevel: proc(this: rawptr) -> D3D_FEATURE_LEVEL, GetCreationFlags: proc(this: rawptr) -> UINT, GetDeviceRemovedReason: proc(this: rawptr) -> HRESULT, GetImmediateContext: proc(this: rawptr, ppImmediateContext: ^rawptr), SetExceptionMode: proc(this: rawptr, RaiseFlags: UINT) -> HRESULT, GetExceptionMode: proc(this: rawptr) -> UINT, }
ID3D11DeviceContextVTable :: struct #ordered { QueryInterface_IUnknown: proc(this: rawptr, riid: ^GUID, ppvObject: ^rawptr) -> HRESULT, AddRef_IUnknown: proc(this: rawptr) -> u32, Release_IUnknown: proc(this: rawptr) -> u32, GetDevice: proc(this: rawptr, ppDevice: ^rawptr), GetPrivateData_Ctx: proc(this: rawptr, guid: ^GUID, pDataSize: ^UINT, pData: rawptr) -> HRESULT, SetPrivateData_Ctx: proc(this: rawptr, guid: ^GUID, DataSize: UINT, pData: rawptr) -> HRESULT, SetPrivateDataInterface_Ctx: proc(this: rawptr, guid: ^GUID, pData: rawptr) -> HRESULT, VSSetConstantBuffers: proc(this: rawptr, StartSlot: UINT, NumBuffers: UINT, ppConstantBuffers: ^rawptr) -> (), PSSetShaderResources: proc(this: rawptr, StartSlot: UINT, NumViews: UINT, ppShaderResourceViews: ^rawptr) -> (), PSSetShader: proc(this: rawptr, pPixelShader: rawptr, ppClassInstances: ^rawptr, NumClassInstances: UINT) -> (), PSSetSamplers: proc(this: rawptr, StartSlot: UINT, NumSamplers: UINT, ppSamplers: ^rawptr) -> (), VSSetShader: proc(this: rawptr, pVertexShader: rawptr, ppClassInstances: ^rawptr, NumClassInstances: UINT) -> (), DrawIndexed: proc(this: rawptr, IndexCount: UINT, StartIndexLocation: UINT, BaseVertexLocation: INT) -> (), Draw: proc(this: rawptr, VertexCount: UINT, StartVertexLocation: UINT) -> (), Map: proc(this: rawptr, pResource: rawptr, Subresource: UINT, MapType: D3D11_MAP, MapFlags: UINT, pMappedResource: ^D3D11_MAPPED_SUBRESOURCE) -> HRESULT, Unmap: proc(this: rawptr, pResource: rawptr, Subresource: UINT) -> (), PSSetConstantBuffers: proc(this: rawptr, StartSlot: UINT, NumBuffers: UINT, ppConstantBuffers: ^rawptr) -> (), IASetInputLayout: proc(this: rawptr, pInputLayout: rawptr) -> (), IASetVertexBuffers: proc(this: rawptr, StartSlot: UINT, NumBuffers: UINT, ppVertexBuffers: ^rawptr, pStrides: ^UINT, pOffsets: ^UINT) -> (), IASetIndexBuffer: proc(this: rawptr, pIndexBuffer: rawptr, Format: DXGI_FORMAT, Offset: UINT) -> (), DrawIndexedInstanced: proc(this: rawptr, IndexCountPerInstance: UINT, InstanceCount: UINT, StartIndexLocation: UINT, BaseVertexLocation: INT, StartInstanceLocation: UINT) -> (), DrawInstanced: proc(this: rawptr, VertexCountPerInstance: UINT, InstanceCount: UINT, StartVertexLocation: UINT, StartInstanceLocation: UINT) -> (), GSSetConstantBuffers: proc(this: rawptr, StartSlot: UINT, NumBuffers: UINT, ppConstantBuffers: ^rawptr) -> (), GSSetShader: proc(this: rawptr, pShader: rawptr, ppClassInstances: ^rawptr, NumClassInstances: UINT) -> (), IASetPrimitiveTopology: proc(this: rawptr, Topology: D3D_PRIMITIVE_TOPOLOGY) -> (), VSSetShaderResources: proc(this: rawptr, StartSlot: UINT, NumViews: UINT, ppShaderResourceViews: ^rawptr) -> (), VSSetSamplers: proc(this: rawptr, StartSlot: UINT, NumSamplers: UINT, ppSamplers: ^rawptr) -> (), GenerateMips: proc(this: rawptr, pShaderResourceView: rawptr) -> (), SetTextFilterSize: proc(this: rawptr, Width: UINT, Height: UINT) -> (), GetTextFilterSize: proc(this: rawptr, pWidth: ^UINT, pHeight: ^UINT) -> (), OMSetRenderTargets: proc(this: rawptr, NumViews: UINT, ppRenderTargetViews: ^rawptr, pDepthStencilView: rawptr) -> (), OMSetRenderTargetsAndUnorderedAccessViews: proc(this: rawptr, NumRTVs: UINT, ppRenderTargetViews: ^rawptr, pDepthStencilView: rawptr, UAVStartSlot: UINT, NumUAVs: UINT, ppUnorderedAccessViews: ^rawptr, pUAVInitialCounts: ^UINT) -> (), OMSetBlendState: proc(this: rawptr, pBlendState: rawptr, BlendFactor: ^[4]FLOAT, SampleMask: UINT) -> (), OMSetDepthStencilState: proc(this: rawptr, pDepthStencilState: rawptr, StencilRef: UINT) -> (), SOSetTargets: proc(this: rawptr, NumBuffers: UINT, ppSOTargets: ^rawptr, pOffsets: ^UINT) -> (), DrawAuto: proc(this: rawptr) -> (), RSSetState: proc(this: rawptr, pRasterizerState: rawptr) -> (), RSSetViewports: proc(this: rawptr, NumViewports: UINT, pViewports: rawptr) -> (), RSSetScissorRects: proc(this: rawptr, NumRects: UINT, pRects: rawptr) -> (), CopySubresourceRegion: proc(this: rawptr, pDstResource: rawptr, DstSubresource: UINT, DstX: UINT, DstY: UINT, DstZ: UINT, pSrcResource: rawptr, SrcSubresource: UINT, pSrcBox: ^D3D11_BOX) -> (), CopyResource: proc(this: rawptr, pDstResource: rawptr, pSrcResource: rawptr) -> (), UpdateSubresource: proc(this: rawptr, pDstResource: rawptr, DstSubresource: UINT, pDstBox: ^D3D11_BOX, pSrcData: rawptr, SrcRowPitch: UINT, SrcDepthPitch: UINT) -> (), ClearRenderTargetView: proc(this: rawptr, pRenderTargetView: rawptr, ColorRGBA: ^[4]f32) -> (), ClearUnorderedAccessViewUint: proc(this: rawptr, pUnorderedAccessView: rawptr, Values: ^[4]UINT) -> (), ClearUnorderedAccessViewFloat: proc(this: rawptr, pUnorderedAccessView: rawptr, Values: ^[4]f32) -> (), ClearDepthStencilView: proc(this: rawptr, pDepthStencilView: rawptr, ClearFlags: UINT, Depth: f32, Stencil: u8) -> (), DSSetShaderResources: proc(this: rawptr, StartSlot: UINT, NumViews: UINT, ppShaderResourceViews: ^rawptr) -> (), DSSetShader: proc(this: rawptr, pDomainShader: rawptr, ppClassInstances: ^rawptr, NumClassInstances: UINT) -> (), DSSetSamplers: proc(this: rawptr, StartSlot: UINT, NumSamplers: UINT, ppSamplers: ^rawptr) -> (), DSSetConstantBuffers: proc(this: rawptr, StartSlot: UINT, NumBuffers: UINT, ppConstantBuffers: ^rawptr) -> (), CSSetShaderResources: proc(this: rawptr, StartSlot: UINT, NumViews: UINT, ppShaderResourceViews: ^rawptr) -> (), CSSetUnorderedAccessViews: proc(this: rawptr, StartSlot: UINT, NumUAVs: UINT, ppUnorderedAccessViews: ^rawptr, pUAVInitialCounts: ^UINT) -> (), CSSetShader: proc(this: rawptr, pComputeShader: rawptr, ppClassInstances: ^rawptr, NumClassInstances: UINT) -> (), CSSetSamplers: proc(this: rawptr, StartSlot: UINT, NumSamplers: UINT, ppSamplers: ^rawptr) -> (), CSSetConstantBuffers: proc(this: rawptr, StartSlot: UINT, NumBuffers: UINT, ppConstantBuffers: ^rawptr) -> (), HSSetShaderResources: proc(this: rawptr, StartSlot: UINT, NumViews: UINT, ppShaderResourceViews: ^rawptr) -> (), HSSetShader: proc(this: rawptr, pHullShader: rawptr, ppClassInstances: ^rawptr, NumClassInstances: UINT) -> (), HSSetSamplers: proc(this: rawptr, StartSlot: UINT, NumSamplers: UINT, ppSamplers: ^rawptr) -> (), HSSetConstantBuffers: proc(this: rawptr, StartSlot: UINT, NumBuffers: UINT, ppConstantBuffers: ^rawptr) -> (), SetShaderResources: proc(this: rawptr, ShaderStage: UINT, StartSlot: UINT, NumViews: UINT, ppShaderResourceViews: ^rawptr) -> (), SetSamplers: proc(this: rawptr, ShaderStage: UINT, StartSlot: UINT, NumSamplers: UINT, ppSamplers: ^rawptr) -> (), SetConstantBuffers: proc(this: rawptr, ShaderStage: UINT, StartSlot: UINT, NumBuffers: UINT, ppConstantBuffers: ^rawptr) -> (), SetShader: proc(this: rawptr, ShaderStage: UINT, pShader: rawptr, ppClassInstances: ^rawptr, NumClassInstances: UINT) -> (), Dispatch: proc(this: rawptr, ThreadGroupCountX: UINT, ThreadGroupCountY: UINT, ThreadGroupCountZ: UINT) -> (), DispatchIndirect: proc(this: rawptr, pBufferForArgs: rawptr, AlignedByteOffsetForArgs: UINT) -> (), FinishCommandList: proc(this: rawptr, RestoreDeferredContextState: BOOL, ppCommandList: ^rawptr) -> HRESULT, ExecuteCommandList: proc(this: rawptr, pCommandList: rawptr, RestoreContextState: BOOL) -> (), Flush: proc(this: rawptr) -> (), }
IDXGISwapChain1VTable :: struct #ordered { QueryInterface_IUnknown: proc(this: rawptr, riid: ^GUID, ppvObject: ^rawptr) -> HRESULT, AddRef_IUnknown: proc(this: rawptr) -> u32, Release_IUnknown: proc(this: rawptr) -> u32, SetPrivateData: proc(this: rawptr, Name: ^GUID, DataSize: UINT, pData: rawptr) -> HRESULT, SetPrivateDataInterface: proc(this: rawptr, Name: ^GUID, pUnknown: rawptr) -> HRESULT, GetPrivateData_SC: proc(this: rawptr, Name: ^GUID, pDataSize: ^UINT, pData: rawptr) -> HRESULT, GetParent_SC: proc(this: rawptr, riid: ^GUID, ppParent: ^rawptr) -> HRESULT, GetDevice_SC: proc(this: rawptr, riid: ^GUID, ppDevice: ^rawptr) -> HRESULT, Present: proc(this: rawptr, SyncInterval: UINT, Flags: UINT) -> HRESULT, GetBuffer: proc(this: rawptr, Buffer: UINT, riid: ^GUID, ppSurface: ^rawptr) -> HRESULT, SetFullscreenState: proc(this: rawptr, Fullscreen: BOOL, pTarget: rawptr) -> HRESULT, GetFullscreenState: proc(this: rawptr, pFullscreen: ^BOOL, ppTarget: ^rawptr) -> HRESULT, GetDesc: proc(this: rawptr, pDesc: rawptr) -> HRESULT, ResizeBuffers: proc(this: rawptr, BufferCount: UINT, Width: UINT, Height: UINT, NewFormat: DXGI_FORMAT, SwapChainFlags: UINT) -> HRESULT, ResizeTarget: proc(this: rawptr, pNewTargetParameters: rawptr) -> HRESULT, GetContainingOutput: proc(this: rawptr, ppOutput: ^rawptr) -> HRESULT, GetFrameStatistics: proc(this: rawptr, pStats: rawptr) -> HRESULT, GetLastPresentCount: proc(this: rawptr, pLastPresentCount: ^UINT) -> HRESULT, GetDesc1: proc(this: rawptr, pDesc: ^DXGI_SWAP_CHAIN_DESC1) -> HRESULT, GetFullscreenDesc: proc(this: rawptr, pDesc: ^DXGI_SWAP_CHAIN_FULLSCREEN_DESC) -> HRESULT, GetHwnd: proc(this: rawptr, pHwnd: ^windows.HWND) -> HRESULT, GetCoreWindow: proc(this: rawptr, refiid: ^GUID, ppUnk: ^rawptr) -> HRESULT, Present1: proc(this: rawptr, SyncInterval: UINT, PresentFlags: UINT, pPresentParameters: rawptr) -> HRESULT, IsTemporaryMonoSupported: proc(this: rawptr) -> BOOL, GetRestrictToOutput: proc(this: rawptr, ppRestrictToOutput: ^rawptr) -> HRESULT, SetBackgroundColor: proc(this: rawptr, pColor: ^[4]f32) -> HRESULT, GetBackgroundColor: proc(this: rawptr, pColor: ^[4]f32) -> HRESULT, SetRotation: proc(this: rawptr, Rotation: UINT) -> HRESULT, GetRotation: proc(this: rawptr, pRotation: ^UINT) -> HRESULT, }
ID3D11ResourceVTable :: struct #ordered { QueryInterface_IUnknown: proc(this: rawptr, riid: ^GUID, ppvObject: ^rawptr) -> HRESULT, AddRef_IUnknown: proc(this: rawptr) -> u32, Release_IUnknown: proc(this: rawptr) -> u32, GetDevice_Child: proc(this: rawptr, ppDevice: ^rawptr), GetPrivateData_Child: proc(this: rawptr, guid: ^GUID, pDataSize: ^UINT, pData: rawptr) -> HRESULT, SetPrivateData_Child: proc(this: rawptr, guid: ^GUID, DataSize: UINT, pData: rawptr) -> HRESULT, SetPrivateDataInterface_Child: proc(this: rawptr, guid: ^GUID, pData: rawptr) -> HRESULT, GetType: proc(this: rawptr, pResourceDimension: ^UINT) -> (), SetEvictionPriority: proc(this: rawptr, EvictionPriority: UINT) -> (), GetEvictionPriority: proc(this: rawptr) -> UINT, }
ID3D11Texture2DVTable :: struct #ordered { QueryInterface_IUnknown: proc(this: rawptr, riid: ^GUID, ppvObject: ^rawptr) -> HRESULT, AddRef_IUnknown: proc(this: rawptr) -> u32, Release_IUnknown: proc(this: rawptr) -> u32, GetDevice_Child: proc(this: rawptr, ppDevice: ^rawptr), GetPrivateData_Child: proc(this: rawptr, guid: ^GUID, pDataSize: ^UINT, pData: rawptr) -> HRESULT, SetPrivateData_Child: proc(this: rawptr, guid: ^GUID, DataSize: UINT, pData: rawptr) -> HRESULT, SetPrivateDataInterface_Child: proc(this: rawptr, guid: ^GUID, pData: rawptr) -> HRESULT, GetType_Resource: proc(this: rawptr, pResourceDimension: ^UINT) -> (), SetEvictionPriority_Resource: proc(this: rawptr, EvictionPriority: UINT) -> (), GetEvictionPriority_Resource: proc(this: rawptr) -> UINT, GetDesc: proc(this: rawptr, pDesc: rawptr), }
ID3D11RenderTargetViewVTable :: struct #ordered { QueryInterface_IUnknown: proc(this: rawptr, riid: ^GUID, ppvObject: ^rawptr) -> HRESULT, AddRef_IUnknown: proc(this: rawptr) -> u32, Release_IUnknown: proc(this: rawptr) -> u32, GetDevice_Child: proc(this: rawptr, ppDevice: ^rawptr), GetPrivateData_Child: proc(this: rawptr, guid: ^GUID, pDataSize: ^UINT, pData: rawptr) -> HRESULT, SetPrivateData_Child: proc(this: rawptr, guid: ^GUID, DataSize: UINT, pData: rawptr) -> HRESULT, SetPrivateDataInterface_Child: proc(this: rawptr, guid: ^GUID, pData: rawptr) -> HRESULT, GetResource: proc(this: rawptr, ppResource: ^rawptr), GetDesc_RTV: proc(this: rawptr, pDesc: rawptr), }
ID3D11BufferVTable :: struct #ordered { QueryInterface_IUnknown: proc(this: rawptr, riid: ^GUID, ppvObject: ^rawptr) -> HRESULT, AddRef_IUnknown: proc(this: rawptr) -> u32, Release_IUnknown: proc(this: rawptr) -> u32, GetDevice_Child: proc(this: rawptr, ppDevice: ^rawptr), GetPrivateData_Child: proc(this: rawptr, guid: ^GUID, pDataSize: ^UINT, pData: rawptr) -> HRESULT, SetPrivateData_Child: proc(this: rawptr, guid: ^GUID, DataSize: UINT, pData: rawptr) -> HRESULT, SetPrivateDataInterface_Child: proc(this: rawptr, guid: ^GUID, pData: rawptr) -> HRESULT, GetType_Resource: proc(this: rawptr, pResourceDimension: ^UINT) -> (), SetEvictionPriority_Resource: proc(this: rawptr, EvictionPriority: UINT) -> (), GetEvictionPriority_Resource: proc(this: rawptr) -> UINT, GetDesc: proc(this: rawptr, pDesc: ^D3D11_BUFFER_DESC), }
ID3D11VertexShaderVTable :: struct #ordered { QueryInterface_IUnknown: proc(this: rawptr, riid: ^GUID, ppvObject: ^rawptr) -> HRESULT, AddRef_IUnknown: proc(this: rawptr) -> u32, Release_IUnknown: proc(this: rawptr) -> u32, GetDevice_Child: proc(this: rawptr, ppDevice: ^rawptr), GetPrivateData_Child: proc(this: rawptr, guid: ^GUID, pDataSize: ^UINT, pData: rawptr) -> HRESULT, SetPrivateData_Child: proc(this: rawptr, guid: ^GUID, DataSize: UINT, pData: rawptr) -> HRESULT, SetPrivateDataInterface_Child: proc(this: rawptr, guid: ^GUID, pData: rawptr) -> HRESULT, }
ID3D11PixelShaderVTable :: struct #ordered { QueryInterface_IUnknown: proc(this: rawptr, riid: ^GUID, ppvObject: ^rawptr) -> HRESULT, AddRef_IUnknown: proc(this: rawptr) -> u32, Release_IUnknown: proc(this: rawptr) -> u32, GetDevice_Child: proc(this: rawptr, ppDevice: ^rawptr), GetPrivateData_Child: proc(this: rawptr, guid: ^GUID, pDataSize: ^UINT, pData: rawptr) -> HRESULT, SetPrivateData_Child: proc(this: rawptr, guid: ^GUID, DataSize: UINT, pData: rawptr) -> HRESULT, SetPrivateDataInterface_Child: proc(this: rawptr, guid: ^GUID, pData: rawptr) -> HRESULT, }
ID3D11ShaderResourceViewVTable :: struct #ordered { QueryInterface_IUnknown: proc(this: rawptr, riid: ^GUID, ppvObject: ^rawptr) -> HRESULT, AddRef_IUnknown: proc(this: rawptr) -> u32, Release_IUnknown: proc(this: rawptr) -> u32, GetDevice_Child: proc(this: rawptr, ppDevice: ^rawptr), GetPrivateData_Child: proc(this: rawptr, guid: ^GUID, pDataSize: ^UINT, pData: rawptr) -> HRESULT, SetPrivateData_Child: proc(this: rawptr, guid: ^GUID, DataSize: UINT, pData: rawptr) -> HRESULT, SetPrivateDataInterface_Child: proc(this: rawptr, guid: ^GUID, pData: rawptr) -> HRESULT, GetDesc: proc(this: rawptr, pDesc: ^D3D11_SHADER_RESOURCE_VIEW_DESC), }
ID3D11InputLayoutVTable :: struct #ordered { QueryInterface_IUnknown: proc(this: rawptr, riid: ^GUID, ppvObject: ^rawptr) -> HRESULT, AddRef_IUnknown: proc(this: rawptr) -> u32, Release_IUnknown: proc(this: rawptr) -> u32, GetDevice_Child: proc(this: rawptr, ppDevice: ^rawptr), GetPrivateData_Child: proc(this: rawptr, guid: ^GUID, pDataSize: ^UINT, pData: rawptr) -> HRESULT, SetPrivateData_Child: proc(this: rawptr, guid: ^GUID, DataSize: UINT, pData: rawptr) -> HRESULT, SetPrivateDataInterface_Child: proc(this: rawptr, guid: ^GUID, pData: rawptr) -> HRESULT, }
ID3D11BlendStateVTable :: struct #ordered { QueryInterface_IUnknown: proc(this: rawptr, riid: ^GUID, ppvObject: ^rawptr) -> HRESULT, AddRef_IUnknown: proc(this: rawptr) -> u32, Release_IUnknown: proc(this: rawptr) -> u32, GetDevice_Child: proc(this: rawptr, ppDevice: ^rawptr), GetPrivateData_Child: proc(this: rawptr, guid: ^GUID, pDataSize: ^UINT, pData: rawptr) -> HRESULT, SetPrivateData_Child: proc(this: rawptr, guid: ^GUID, DataSize: UINT, pData: rawptr) -> HRESULT, SetPrivateDataInterface_Child: proc(this: rawptr, guid: ^GUID, pData: rawptr) -> HRESULT, GetDesc: proc(this: rawptr, pDesc: ^D3D11_BLEND_DESC), }
ID3D11DepthStencilStateVTable :: struct #ordered { QueryInterface_IUnknown: proc(this: rawptr, riid: ^GUID, ppvObject: ^rawptr) -> HRESULT, AddRef_IUnknown: proc(this: rawptr) -> u32, Release_IUnknown: proc(this: rawptr) -> u32, GetDevice_Child: proc(this: rawptr, ppDevice: ^rawptr), GetPrivateData_Child: proc(this: rawptr, guid: ^GUID, pDataSize: ^UINT, pData: rawptr) -> HRESULT, SetPrivateData_Child: proc(this: rawptr, guid: ^GUID, DataSize: UINT, pData: rawptr) -> HRESULT, SetPrivateDataInterface_Child: proc(this: rawptr, guid: ^GUID, pData: rawptr) -> HRESULT, GetDesc: proc(this: rawptr, pDesc: ^D3D11_DEPTH_STENCIL_DESC), }
ID3D11RasterizerStateVTable :: struct #ordered { QueryInterface_IUnknown: proc(this: rawptr, riid: ^GUID, ppvObject: ^rawptr) -> HRESULT, AddRef_IUnknown: proc(this: rawptr) -> u32, Release_IUnknown: proc(this: rawptr) -> u32, GetDevice_Child: proc(this: rawptr, ppDevice: ^rawptr), GetPrivateData_Child: proc(this: rawptr, guid: ^GUID, pDataSize: ^UINT, pData: rawptr) -> HRESULT, SetPrivateData_Child: proc(this: rawptr, guid: ^GUID, DataSize: UINT, pData: rawptr) -> HRESULT, SetPrivateDataInterface_Child: proc(this: rawptr, guid: ^GUID, pData: rawptr) -> HRESULT, GetDesc: proc(this: rawptr, pDesc: ^D3D11_RASTERIZER_DESC), }


// --- IIDs ---
IID_IDXGIFactory1 :: GUID{0x770aae78, 0xf26f, 0x4dba, {0xa8, 0x29, 0x25, 0x3c, 0x83, 0xd1, 0xb3, 0x87}}
IID_IDXGIFactory2 :: GUID{0x50c83a1c, 0xe072, 0x4c48, {0x87,0xb0, 0x36,0x30,0xfa,0x36,0xa6,0xd0}}
IID_ID3D11Device :: GUID{0xdb6f6ddb, 0xac77, 0x4e88, {0x82, 0x53, 0x81, 0x9d, 0xf9, 0xbb, 0xf1, 0x40}}
IID_ID3D11Texture2D :: GUID{0x6f15aaf2,0xd208,0x4e89,{0x9a,0xb4,0x48,0x95,0x35,0xd3,0x4f,0x9c}}
IID_ID3D11Debug :: GUID{0x79cf2233, 0x7536, 0x4948, {0x9d,0x36, 0x1e,0x46,0x92,0xdc,0x57,0x60}}
IID_IDXGIDebug :: GUID{0x119E7452,0xDE9E,0x40fe,{0x88,0x06,0x88,0xF9,0x0C,0x12,0xB4,0x41}}
IDXGI_DEBUG_ALL :: GUID{0xe48ae283,0xda80,0x490b,{0x87,0xe6,0x43,0xe9,0xa9,0xcf,0xda,0x08}}

DXGI_DEBUG_RLO_FLAGS :: enum u32 { SUMMARY = 0x1, DETAIL = 0x2, IGNORE_INTERNAL = 0x4, }
IDXGIDebugVTable :: struct #ordered { QueryInterface_IUnknown: proc(this: rawptr, riid: ^GUID, ppvObject: ^rawptr) -> HRESULT, AddRef_IUnknown: proc(this: rawptr) -> u32, Release_IUnknown: proc(this: rawptr) -> u32, ReportLiveObjects: proc(this: rawptr, apiid: GUID, flags: DXGI_DEBUG_RLO_FLAGS) -> HRESULT, }

// --- Foreign Function Prototypes ---
@(link_name="CreateDXGIFactory1") CreateDXGIFactory1 :: proc(riid: ^GUID, ppFactory: ^rawptr) -> HRESULT ---
@(link_name="CreateDXGIFactory2") CreateDXGIFactory2 :: proc(Flags: UINT, riid: ^GUID, ppFactory: ^rawptr) -> HRESULT ---
@(link_name="D3D11CreateDevice") D3D11CreateDevice :: proc(pAdapter: rawptr, DriverType: D3D_DRIVER_TYPE, Software: windows.HMODULE, Flags: UINT, pFeatureLevels: ^D3D_FEATURE_LEVEL, FeatureLevels: UINT, SDKVersion: UINT, ppDevice: ^rawptr, pFeatureLevel: ^D3D_FEATURE_LEVEL, ppImmediateContext: ^rawptr) -> HRESULT ---
@(link_name="DXGIGetDebugInterface") DXGIGetDebugInterface :: proc(riid: ^GUID, ppDebug: ^rawptr) -> HRESULT ---
@(link_name="D3DCompile") D3DCompile :: proc(pSrcData: rawptr, SrcDataSize: SIZE_T, pSourceName: LPCSTR, pDefines: ^D3D_SHADER_MACRO, pInclude: rawptr, pEntrypoint: LPCSTR, pTarget: LPCSTR, Flags1: UINT, Flags2: UINT, ppCode: ^ID3DBlob_Handle, ppErrorMsgs: ^ID3DBlob_Handle) -> HRESULT ---

// --- COM Object Release Helpers ---
release_com_object_typed :: proc(obj_ptr_ptr: ^$T, allocator := context.allocator) where T distinct rawptr { if obj_ptr_ptr != nil && obj_ptr_ptr^ != nil { raw_obj_ptr := rawptr(obj_ptr_ptr^); vt := (^IUnknownVTable)raw_obj_ptr^; _ = vt.Release(raw_obj_ptr); obj_ptr_ptr^ = nil; } }

// --- VTable Wrapper Functions ---
Factory_Release :: proc(factory: IDXGIFactory_Handle) -> u32 { if factory == nil { return 0 }; return ((^IDXGIFactory2VTable)(factory)^).Release_IUnknown(factory) }
Factory_CreateSwapChainForHwnd :: proc(factory: IDXGIFactory_Handle, pDevice: ID3D11Device_Handle, hWnd: windows.HWND, pDesc: ^DXGI_SWAP_CHAIN_DESC1, pFullscreenDesc: ^DXGI_SWAP_CHAIN_FULLSCREEN_DESC, pRestrictToOutput: rawptr, ppSwapChain: ^IDXGISwapChain_Handle) -> HRESULT { if factory == nil { return E_INVALIDARG }; return ((^IDXGIFactory2VTable)(factory)^).CreateSwapChainForHwnd(factory, pDevice, hWnd, pDesc, pFullscreenDesc, pRestrictToOutput, cast(^rawptr)ppSwapChain) }

Device_Release :: proc(device: ID3D11Device_Handle) -> u32 { if device == nil { return 0 }; return ((^ID3D11DeviceVTable)(device)^).Release_IUnknown(device) }
Device_GetImmediateContext :: proc(device: ID3D11Device_Handle, ppImmediateContext: ^ID3D11DeviceContext_Handle) { if device == nil { return }; ((^ID3D11DeviceVTable)(device)^).GetImmediateContext(device, cast(^rawptr)ppImmediateContext) }
Device_CreateRenderTargetView :: proc(device: ID3D11Device_Handle, pResource: ID3D11Texture2D_Handle, pDesc: rawptr, ppRTView: ^ID3D11RenderTargetView_Handle) -> HRESULT { if device == nil { return E_INVALIDARG }; return ((^ID3D11DeviceVTable)(device)^).CreateRenderTargetView(device, pResource, pDesc, cast(^rawptr)ppRTView) }
Device_QueryInterface :: proc(device: ID3D11Device_Handle, riid: ^GUID, ppvObject: ^rawptr) -> HRESULT { if device == nil { return E_INVALIDARG }; return ((^ID3D11DeviceVTable)(device)^).QueryInterface_IUnknown(device, riid, ppvObject) }
Device_CreateBuffer :: proc(device: ID3D11Device_Handle, pDesc: ^D3D11_BUFFER_DESC, pInitialData: ^D3D11_SUBRESOURCE_DATA, ppBuffer: ^ID3D11Buffer_Handle) -> HRESULT { if device == nil { return E_INVALIDARG }; return ((^ID3D11DeviceVTable)(device)^).CreateBuffer(device, pDesc, pInitialData, cast(^rawptr)ppBuffer) }
Device_CreateVertexShader :: proc(device: ID3D11Device_Handle, pShaderBytecode: rawptr, BytecodeLength: SIZE_T, pClassLinkage: rawptr, ppVertexShader: ^ID3D11VertexShader_Handle) -> HRESULT { if device == nil { return E_INVALIDARG }; return ((^ID3D11DeviceVTable)(device)^).CreateVertexShader(device, pShaderBytecode, BytecodeLength, pClassLinkage, cast(^rawptr)ppVertexShader) }
Device_CreatePixelShader :: proc(device: ID3D11Device_Handle, pShaderBytecode: rawptr, BytecodeLength: SIZE_T, pClassLinkage: rawptr, ppPixelShader: ^ID3D11PixelShader_Handle) -> HRESULT { if device == nil { return E_INVALIDARG }; return ((^ID3D11DeviceVTable)(device)^).CreatePixelShader(device, pShaderBytecode, BytecodeLength, pClassLinkage, cast(^rawptr)ppPixelShader) }
Device_CreateTexture2D :: proc(device: ID3D11Device_Handle, pDesc: ^D3D11_TEXTURE2D_DESC, pInitialData: ^D3D11_SUBRESOURCE_DATA, ppTexture2D: ^ID3D11Texture2D_Handle) -> HRESULT { if device == nil { return E_INVALIDARG }; return ((^ID3D11DeviceVTable)(device)^).CreateTexture2D(device, pDesc, pInitialData, cast(^rawptr)ppTexture2D) }
Device_CreateShaderResourceView :: proc(device: ID3D11Device_Handle, pResource: ID3D11Texture2D_Handle, pDesc: ^D3D11_SHADER_RESOURCE_VIEW_DESC, ppSRView: ^ID3D11ShaderResourceView_Handle) -> HRESULT { if device == nil { return E_INVALIDARG }; return ((^ID3D11DeviceVTable)(device)^).CreateShaderResourceView(device, pResource, pDesc, cast(^rawptr)ppSRView) }
Device_CreateInputLayout :: proc(device: ID3D11Device_Handle, pInputElementDescs: ^D3D11_INPUT_ELEMENT_DESC, NumElements: UINT, pShaderBytecodeWithInputSignature: rawptr, BytecodeLength: SIZE_T, ppInputLayout: ^ID3D11InputLayout_Handle) -> HRESULT { if device == nil { return E_INVALIDARG }; return ((^ID3D11DeviceVTable)(device)^).CreateInputLayout(device, pInputElementDescs, NumElements, pShaderBytecodeWithInputSignature, BytecodeLength, cast(^rawptr)ppInputLayout) }
Device_CreateBlendState :: proc(device: ID3D11Device_Handle, pBlendStateDesc: ^D3D11_BLEND_DESC, ppBlendState: ^ID3D11BlendState_Handle) -> HRESULT { if device == nil { return E_INVALIDARG }; return ((^ID3D11DeviceVTable)(device)^).CreateBlendState(device, pBlendStateDesc, cast(^rawptr)ppBlendState) }
Device_CreateDepthStencilState :: proc(device: ID3D11Device_Handle, pDepthStencilStateDesc: ^D3D11_DEPTH_STENCIL_DESC, ppDepthStencilState: ^ID3D11DepthStencilState_Handle) -> HRESULT { if device == nil { return E_INVALIDARG }; return ((^ID3D11DeviceVTable)(device)^).CreateDepthStencilState(device, pDepthStencilStateDesc, cast(^rawptr)ppDepthStencilState) }
Device_CreateRasterizerState :: proc(device: ID3D11Device_Handle, pRasterizerStateDesc: ^D3D11_RASTERIZER_DESC, ppRasterizerState: ^ID3D11RasterizerState_Handle) -> HRESULT { if device == nil { return E_INVALIDARG }; return ((^ID3D11DeviceVTable)(device)^).CreateRasterizerState(device, pRasterizerStateDesc, cast(^rawptr)ppRasterizerState) }

Context_Release :: proc(context: ID3D11DeviceContext_Handle) -> u32 { if context == nil { return 0 }; return ((^ID3D11DeviceContextVTable)(context)^).Release_IUnknown(context) }
Context_Map :: proc(context: ID3D11DeviceContext_Handle, pResource: ID3D11Buffer_Handle, Subresource: UINT, MapType: D3D11_MAP, MapFlags: UINT, pMappedResource: ^D3D11_MAPPED_SUBRESOURCE) -> HRESULT { if context == nil { return E_INVALIDARG }; return ((^ID3D11DeviceContextVTable)(context)^).Map(context, pResource, Subresource, MapType, MapFlags, pMappedResource) } 
Context_Map_Texture :: proc(context: ID3D11DeviceContext_Handle, pResource: ID3D11Texture2D_Handle, Subresource: UINT, MapType: D3D11_MAP, MapFlags: UINT, pMappedResource: ^D3D11_MAPPED_SUBRESOURCE) -> HRESULT { if context == nil { return E_INVALIDARG }; return ((^ID3D11DeviceContextVTable)(context)^).Map(context, pResource, Subresource, MapType, MapFlags, pMappedResource) }
Context_Unmap :: proc(context: ID3D11DeviceContext_Handle, pResource: ID3D11Buffer_Handle, Subresource: UINT) { if context == nil { return }; ((^ID3D11DeviceContextVTable)(context)^).Unmap(context, pResource, Subresource) }
Context_Unmap_Texture :: proc(context: ID3D11DeviceContext_Handle, pResource: ID3D11Texture2D_Handle, Subresource: UINT) { if context == nil { return }; ((^ID3D11DeviceContextVTable)(context)^).Unmap(context, pResource, Subresource) }
Context_UpdateSubresource :: proc(context: ID3D11DeviceContext_Handle, pDstResource: rawptr , DstSubresource: UINT, pDstBox: ^D3D11_BOX, pSrcData: rawptr, SrcRowPitch: UINT, SrcDepthPitch: UINT) { if context == nil { return }; ((^ID3D11DeviceContextVTable)(context)^).UpdateSubresource(context, pDstResource, DstSubresource, pDstBox, pSrcData, SrcRowPitch, SrcDepthPitch) }
Context_CopySubresourceRegion :: proc(context: ID3D11DeviceContext_Handle, pDstResource: rawptr, DstSubresource: UINT, DstX: UINT, DstY: UINT, DstZ: UINT, pSrcResource: rawptr, SrcSubresource: UINT, pSrcBox: ^D3D11_BOX) { if context == nil { return }; ((^ID3D11DeviceContextVTable)(context)^).CopySubresourceRegion(context, pDstResource, DstSubresource, DstX, DstY, DstZ, pSrcResource, SrcSubresource, pSrcBox) }
Context_OMSetRenderTargets :: proc(context: ID3D11DeviceContext_Handle, NumViews: UINT, ppRenderTargetViews: ^ID3D11RenderTargetView_Handle, pDepthStencilView: ID3D11DepthStencilView_Handle) { if context == nil { return }; ((^ID3D11DeviceContextVTable)(context)^).OMSetRenderTargets(context, NumViews, cast(^rawptr)ppRenderTargetViews, pDepthStencilView) }
Context_ClearRenderTargetView :: proc(context: ID3D11DeviceContext_Handle, pRenderTargetView: ID3D11RenderTargetView_Handle, ColorRGBA: ^[4]f32) { if context == nil { return }; ((^ID3D11DeviceContextVTable)(context)^).ClearRenderTargetView(context, pRenderTargetView, ColorRGBA) }
Context_Draw :: proc(context: ID3D11DeviceContext_Handle, VertexCount: UINT, StartVertexLocation: UINT) { if context == nil { return }; ((^ID3D11DeviceContextVTable)(context)^).Draw(context, VertexCount, StartVertexLocation) }
Context_DrawIndexed :: proc(context: ID3D11DeviceContext_Handle, IndexCount: UINT, StartIndexLocation: UINT, BaseVertexLocation: INT) { if context == nil { return }; ((^ID3D11DeviceContextVTable)(context)^).DrawIndexed(context, IndexCount, StartIndexLocation, BaseVertexLocation) }
Context_DrawInstanced :: proc(context: ID3D11DeviceContext_Handle, VertexCountPerInstance: UINT, InstanceCount: UINT, StartVertexLocation: UINT, StartInstanceLocation: UINT) { if context == nil { return }; ((^ID3D11DeviceContextVTable)(context)^).DrawInstanced(context, VertexCountPerInstance, InstanceCount, StartVertexLocation, StartInstanceLocation) }
Context_DrawIndexedInstanced :: proc(context: ID3D11DeviceContext_Handle, IndexCountPerInstance: UINT, InstanceCount: UINT, StartIndexLocation: UINT, BaseVertexLocation: INT, StartInstanceLocation: UINT) { if context == nil { return }; ((^ID3D11DeviceContextVTable)(context)^).DrawIndexedInstanced(context, IndexCountPerInstance, InstanceCount, StartIndexLocation, BaseVertexLocation, StartInstanceLocation) }
Context_VSSetShader :: proc(context: ID3D11DeviceContext_Handle, pVertexShader: ID3D11VertexShader_Handle, ppClassInstances: ^rawptr, NumClassInstances: UINT) { if context == nil { return }; ((^ID3D11DeviceContextVTable)(context)^).VSSetShader(context, pVertexShader, ppClassInstances, NumClassInstances) }
Context_PSSetShader :: proc(context: ID3D11DeviceContext_Handle, pPixelShader: ID3D11PixelShader_Handle, ppClassInstances: ^rawptr, NumClassInstances: UINT) { if context == nil { return }; ((^ID3D11DeviceContextVTable)(context)^).PSSetShader(context, pPixelShader, ppClassInstances, NumClassInstances) }
Context_PSSetShaderResources :: proc(context: ID3D11DeviceContext_Handle, StartSlot: UINT, NumViews: UINT, ppShaderResourceViews: ^ID3D11ShaderResourceView_Handle) { if context == nil { return }; ((^ID3D11DeviceContextVTable)(context)^).PSSetShaderResources(context, StartSlot, NumViews, cast(^rawptr)ppShaderResourceViews) }
Context_IASetInputLayout :: proc(context: ID3D11DeviceContext_Handle, pInputLayout: ID3D11InputLayout_Handle) { if context == nil { return }; ((^ID3D11DeviceContextVTable)(context)^).IASetInputLayout(context, pInputLayout) }
Context_IASetPrimitiveTopology :: proc(context: ID3D11DeviceContext_Handle, Topology: D3D_PRIMITIVE_TOPOLOGY) { if context == nil { return }; ((^ID3D11DeviceContextVTable)(context)^).IASetPrimitiveTopology(context, Topology) }
Context_RSSetState :: proc(context: ID3D11DeviceContext_Handle, pRasterizerState: ID3D11RasterizerState_Handle) { if context == nil { return }; ((^ID3D11DeviceContextVTable)(context)^).RSSetState(context, pRasterizerState) }
Context_OMSetBlendState :: proc(context: ID3D11DeviceContext_Handle, pBlendState: ID3D11BlendState_Handle, BlendFactor: ^[4]FLOAT, SampleMask: UINT) { if context == nil { return }; ((^ID3D11DeviceContextVTable)(context)^).OMSetBlendState(context, pBlendState, BlendFactor, SampleMask) }
Context_OMSetDepthStencilState :: proc(context: ID3D11DeviceContext_Handle, pDepthStencilState: ID3D11DepthStencilState_Handle, StencilRef: UINT) { if context == nil { return }; ((^ID3D11DeviceContextVTable)(context)^).OMSetDepthStencilState(context, pDepthStencilState, StencilRef) }


SwapChain_Release :: proc(swap_chain: IDXGISwapChain_Handle) -> u32 { if swap_chain == nil { return 0 }; return ((^IDXGISwapChain1VTable)(swap_chain)^).Release_IUnknown(swap_chain) }
SwapChain_GetBuffer :: proc(swap_chain: IDXGISwapChain_Handle, Buffer: UINT, riid: ^GUID, ppSurface: ^ID3D11Texture2D_Handle) -> HRESULT { if swap_chain == nil { return E_INVALIDARG }; return ((^IDXGISwapChain1VTable)(swap_chain)^).GetBuffer(swap_chain, Buffer, riid, cast(^rawptr)ppSurface) }
SwapChain_Present :: proc(swap_chain: IDXGISwapChain_Handle, SyncInterval: UINT, Flags: UINT) -> HRESULT { if swap_chain == nil { return E_INVALIDARG }; return ((^IDXGISwapChain1VTable)(swap_chain)^).Present(swap_chain, SyncInterval, Flags) }

Texture2D_Release :: proc(texture: ID3D11Texture2D_Handle) -> u32 { if texture == nil { return 0 }; return ((^ID3D11Texture2DVTable)(texture)^).Release_IUnknown(texture) }
RTV_Release :: proc(rtv: ID3D11RenderTargetView_Handle) -> u32 { if rtv == nil { return 0 }; return ((^ID3D11RenderTargetViewVTable)(rtv)^).Release_IUnknown(rtv) }
Buffer_Release :: proc(buffer: ID3D11Buffer_Handle) -> u32 { if buffer == nil { return 0 }; return ((^ID3D11BufferVTable)(buffer)^).Release_IUnknown(buffer) }
ShaderResourceView_Release :: proc(srv: ID3D11ShaderResourceView_Handle) -> u32 { if srv == nil { return 0}; return ((^ID3D11ShaderResourceViewVTable)(srv)^).Release_IUnknown(srv) }
InputLayout_Release :: proc(input_layout: ID3D11InputLayout_Handle) -> u32 { if input_layout == nil { return 0 }; return ((^ID3D11InputLayoutVTable)(input_layout)^).Release_IUnknown(input_layout) }
BlendState_Release :: proc(blend_state: ID3D11BlendState_Handle) -> u32 { if blend_state == nil { return 0 }; return ((^ID3D11BlendStateVTable)(blend_state)^).Release_IUnknown(blend_state) }
DepthStencilState_Release :: proc(depth_stencil_state: ID3D11DepthStencilState_Handle) -> u32 { if depth_stencil_state == nil { return 0 }; return ((^ID3D11DepthStencilStateVTable)(depth_stencil_state)^).Release_IUnknown(depth_stencil_state) }
RasterizerState_Release :: proc(rasterizer_state: ID3D11RasterizerState_Handle) -> u32 { if rasterizer_state == nil { return 0 }; return ((^ID3D11RasterizerStateVTable)(rasterizer_state)^).Release_IUnknown(rasterizer_state) }


Blob_Release :: proc(blob: ID3DBlob_Handle) -> u32 { if blob == nil { return 0 }; return ((^ID3DBlobVTable)(blob)^).Release_IUnknown(blob) }
Blob_GetBufferPointer :: proc(blob: ID3DBlob_Handle) -> rawptr { if blob == nil { return nil }; return ((^ID3DBlobVTable)(blob)^).GetBufferPointer(blob) }
Blob_GetBufferSize :: proc(blob: ID3DBlob_Handle) -> SIZE_T { if blob == nil { return 0 }; return ((^ID3DBlobVTable)(blob)^).GetBufferSize(blob) }

VertexShader_Release :: proc(vs: ID3D11VertexShader_Handle) -> u32 { if vs == nil { return 0 }; return ((^ID3D11VertexShaderVTable)(vs)^).Release_IUnknown(vs) }
PixelShader_Release :: proc(ps: ID3D11PixelShader_Handle) -> u32 { if ps == nil { return 0 }; return ((^ID3D11PixelShaderVTable)(ps)^).Release_IUnknown(ps) }


Debug_ReportLiveObjects :: proc(debug_device: rawptr, apiid: GUID, flags: DXGI_DEBUG_RLO_FLAGS) -> HRESULT { if debug_device == nil { return E_INVALIDARG }; return ((^IDXGIDebugVTable)(debug_device)^).ReportLiveObjects(debug_device, apiid, flags) }
Debug_Release :: proc(debug_device: rawptr) -> u32 { if debug_device == nil { return 0 }; return ((^IDXGIDebugVTable)(debug_device)^).Release_IUnknown(debug_device) }

D3D11_RENDER_TARGET_VIEW_DESC :: struct { Format: DXGI_FORMAT, ViewDimension: D3D11_RTV_DIMENSION, union { Buffer: D3D11_BUFFER_RTV, Texture1D: D3D11_TEX1D_RTV, Texture1DArray: D3D11_TEX1D_ARRAY_RTV, Texture2D: D3D11_TEX2D_RTV, Texture2DArray: D3D11_TEX2D_ARRAY_RTV, Texture2DMS: D3D11_TEX2DMS_RTV, Texture2DMSArray: D3D11_TEX2DMS_ARRAY_RTV, Texture3D: D3D11_TEX3D_RTV, }, }
D3D11_RTV_DIMENSION :: enum UINT { UNKNOWN, BUFFER, TEXTURE1D, TEXTURE1DARRAY, TEXTURE2D, TEXTURE2DARRAY, TEXTURE2DMS, TEXTURE2DMSARRAY, TEXTURE3D, }
D3D11_BUFFER_RTV :: struct { union { FirstElement: UINT, ElementOffset: UINT, }, union { NumElements: UINT, ElementWidth: UINT, }, }
D3D11_TEX1D_RTV :: struct { MipSlice: UINT }
D3D11_TEX1D_ARRAY_RTV :: struct { MipSlice: UINT, FirstArraySlice: UINT, ArraySize: UINT }
D3D11_TEX2D_RTV :: struct { MipSlice: UINT }
D3D11_TEX2D_ARRAY_RTV :: struct { MipSlice: UINT, FirstArraySlice: UINT, ArraySize: UINT }
D3D11_TEX2DMS_RTV :: struct { UnusedField_NothingToDefine: UINT }
D3D11_TEX2DMS_ARRAY_RTV :: struct { FirstArraySlice: UINT, ArraySize: UINT }
D3D11_TEX3D_RTV :: struct { MipSlice: UINT, FirstWSlice: UINT, WSize: UINT }I've updated `dx11_bindings.odin` with the necessary definitions for pipeline states, VTable methods, and wrapper functions.

Key additions:
*   Structs: `D3D11_INPUT_ELEMENT_DESC`, `D3D11_BLEND_DESC`, `D3D11_RENDER_TARGET_BLEND_DESC`, `D3D11_DEPTH_STENCIL_DESC`, `D3D11_RASTERIZER_DESC`.
*   Enums: `D3D11_INPUT_CLASSIFICATION`, `D3D11_BLEND`, `D3D11_BLEND_OP`, `D3D11_COLOR_WRITE_ENABLE`, `D3D11_DEPTH_WRITE_MASK`, `D3D11_COMPARISON_FUNC`, `D3D11_STENCIL_OP`, `D3D11_FILL_MODE`, `D3D11_CULL_MODE`, `D3D_PRIMITIVE_TOPOLOGY`.
*   Device VTable Methods & Wrappers: `CreateInputLayout`, `CreateBlendState`, `CreateDepthStencilState`, `CreateRasterizerState`.
*   Context VTable Methods & Wrappers: `IASetInputLayout`, `IASetPrimitiveTopology`, `RSSetState`, `OMSetBlendState`, `OMSetDepthStencilState`.
*   VTable Structs & Release Wrappers: For `ID3D11InputLayout`, `ID3D11BlendState`, `ID3D11DepthStencilState`, `ID3D11RasterizerState`.

Now, I will proceed to **Phase 3: Implement `create_pipeline_impl` and other pipeline functions** in a new file `odingame/graphics/directx/dx11_pipeline.odin`.
