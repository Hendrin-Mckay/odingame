package directx11

import "../gfx_interface"
import "../../common"
import "../../types" // For Color
import "./dx11_types"
import "./dx11_bindings"
import "core:log"
import "core:mem"
import "core:strings" // For cstring creation

// --- Pipeline State Management Implementation ---

// Helper to translate engine vertex format to DXGI_FORMAT
to_dxgi_vertex_format :: proc(format: gfx_interface.Vertex_Format) -> (dxgi_fmt: DXGI_FORMAT, ok: bool) {
    ok = true
    switch format {
    case .Float1: dxgi_fmt = .R32_FLOAT
    case .Float2: dxgi_fmt = .R32G32_FLOAT
    case .Float3: dxgi_fmt = .R32G32B32_FLOAT
    case .Float4: dxgi_fmt = .R32G32B32A32_FLOAT
    case .Byte4_Norm: dxgi_fmt = .R8G8B8A8_UNORM // Assuming normalized
    case .UByte4_Norm: dxgi_fmt = .R8G8B8A8_UNORM 
    // Add more as needed, e.g. for SNORM, UINT, SINT types
    else:
        log.errorf("DX11: Unsupported gfx_interface.Vertex_Format: %v", format)
        ok = false
    }
    return
}

// Helper to translate engine blend factor to D3D11_BLEND
to_d3d11_blend :: proc(factor: gfx_interface.Blend_Factor) -> (blend: D3D11_BLEND, ok: bool) {
    ok = true
    switch factor {
    case .Zero: blend = .ZERO
    case .One: blend = .ONE
    case .Src_Color: blend = .SRC_COLOR
    case .Inv_Src_Color: blend = .INV_SRC_COLOR
    case .Src_Alpha: blend = .SRC_ALPHA
    case .Inv_Src_Alpha: blend = .INV_SRC_ALPHA
    case .Dest_Alpha: blend = .DEST_ALPHA
    case .Inv_Dest_Alpha: blend = .INV_DEST_ALPHA
    case .Dest_Color: blend = .DEST_COLOR
    case .Inv_Dest_Color: blend = .INV_DEST_COLOR
    case .Src_Alpha_Sat: blend = .SRC_ALPHA_SAT
    // case .Blend_Factor: blend = .BLEND_FACTOR // Requires separate blend factor color
    // case .Inv_Blend_Factor: blend = .INV_BLEND_FACTOR
    else:
        log.errorf("DX11: Unsupported gfx_interface.Blend_Factor: %v", factor)
        ok = false
    }
    return
}

// Helper to translate engine blend op to D3D11_BLEND_OP
to_d3d11_blend_op :: proc(op: gfx_interface.Blend_Op) -> (blend_op: D3D11_BLEND_OP, ok: bool) {
    ok = true
    switch op {
    case .Add: blend_op = .ADD
    case .Subtract: blend_op = .SUBTRACT
    case .Rev_Subtract: blend_op = .REV_SUBTRACT
    case .Min: blend_op = .MIN
    case .Max: blend_op = .MAX
    else:
        log.errorf("DX11: Unsupported gfx_interface.Blend_Op: %v", op)
        ok = false
    }
    return
}

// Helper to translate engine comparison func to D3D11_COMPARISON_FUNC
to_d3d11_comparison_func :: proc(cmp: gfx_interface.Comparison_Func) -> (d3d_cmp: D3D11_COMPARISON_FUNC, ok: bool) {
    ok = true
    switch cmp {
    case .Never: d3d_cmp = .NEVER
    case .Less: d3d_cmp = .LESS
    case .Equal: d3d_cmp = .EQUAL
    case .Less_Equal: d3d_cmp = .LESS_EQUAL
    case .Greater: d3d_cmp = .GREATER
    case .Not_Equal: d3d_cmp = .NOT_EQUAL
    case .Greater_Equal: d3d_cmp = .GREATER_EQUAL
    case .Always: d3d_cmp = .ALWAYS
    else: 
        log.errorf("DX11: Unsupported gfx_interface.Comparison_Func: %v", cmp)
        ok = false
    }
    return
}

// Helper to translate engine primitive topology to D3D_PRIMITIVE_TOPOLOGY
to_d3d_primitive_topology :: proc(topology: gfx_interface.Primitive_Topology) -> (d3d_topo: D3D_PRIMITIVE_TOPOLOGY, ok: bool) {
    ok = true
    switch topology {
    case .Triangle_List: d3d_topo = .TRIANGLELIST
    case .Triangle_Strip: d3d_topo = .TRIANGLESTRIP
    case .Line_List: d3d_topo = .LINELIST
    case .Line_Strip: d3d_topo = .LINESTRIP
    case .Point_List: d3d_topo = .POINTLIST
    // Add more as needed
    else:
        log.errorf("DX11: Unsupported gfx_interface.Primitive_Topology: %v", topology)
        ok = false
    }
    return
}


create_pipeline_impl :: proc(
    device_handle: gfx_interface.Gfx_Device, 
    pipeline_desc: ^gfx_interface.Gfx_Pipeline_Desc,
) -> (gfx_interface.Gfx_Pipeline, common.Engine_Error) {

    log.debug("DX11: create_pipeline_impl called.")

    di := get_device_internal(device_handle)
    if di == nil || di.device == nil {
        log.error("DX11: create_pipeline_impl: Invalid Gfx_Device or D3D11 device.")
        return gfx_interface.Gfx_Pipeline{}, .Invalid_Handle
    }
    if pipeline_desc == nil {
        log.error("DX11: create_pipeline_impl: pipeline_desc is nil.")
        return gfx_interface.Gfx_Pipeline{}, .Invalid_Parameter
    }
    if pipeline_desc.vertex_shader.variant == nil {
        log.error("DX11: create_pipeline_impl: Vertex shader in pipeline_desc is invalid.")
        return gfx_interface.Gfx_Pipeline{}, .Invalid_Parameter
    }
    // Pixel shader can be nil for some rendering techniques (e.g. depth pre-pass)
    // but for typical rendering, it's required. Assume it's required for now.
    if pipeline_desc.pixel_shader.variant == nil {
         log.warn("DX11: create_pipeline_impl: Pixel shader in pipeline_desc is nil. This might be intentional for some techniques.")
    }


    pipeline_internal := new(D3D11_Pipeline_Internal, di.allocator)
    pipeline_internal.allocator = di.allocator
    pipeline_internal.vertex_shader_ref = pipeline_desc.vertex_shader
    pipeline_internal.pixel_shader_ref  = pipeline_desc.pixel_shader
    
    hr: HRESULT
    temp_alloc := context.temp_allocator // For temporary C-string allocations

    // --- 1. Input Layout ---
    vs_internal_variant, vs_ok := pipeline_desc.vertex_shader.variant.(D3D11_Shader_Variant)
    if !vs_ok || vs_internal_variant == nil || vs_internal_variant.bytecode_blob == nil {
        log.error("DX11: create_pipeline_impl: Vertex shader bytecode blob is missing or invalid for InputLayout creation.")
        // No free(pipeline_internal) here yet, as COM objects aren't created.
        // Caller or a more robust cleanup mechanism would handle this.
        // For now, return error; the allocated pipeline_internal will leak if not handled by caller.
        // Ideally, use a local arena for pipeline_internal until all D3D objects are created.
        return gfx_interface.Gfx_Pipeline{}, .Invalid_Parameter 
    }
    vs_bytecode_ptr := Blob_GetBufferPointer(vs_internal_variant.bytecode_blob)
    vs_bytecode_size := Blob_GetBufferSize(vs_internal_variant.bytecode_blob)

    num_elements := len(pipeline_desc.vertex_layout.attributes)
    if num_elements > 0 { // Only create input layout if attributes are defined
        input_element_descs := make([]D3D11_INPUT_ELEMENT_DESC, num_elements, temp_alloc)
        defer delete(input_element_descs) // Clean up temporary slice

        for i, attr in pipeline_desc.vertex_layout.attributes {
            semantic_name_cstr := strings.clone_to_cstring(attr.semantic_name, temp_alloc)
            defer delete(semantic_name_cstr) // Defer deletion for each C-string

            dxgi_fmt, fmt_ok := to_dxgi_vertex_format(attr.format)
            if !fmt_ok {
                // Error already logged by to_dxgi_vertex_format
                // Clean up previously allocated C-strings if any (defer handles this)
                // Free pipeline_internal? See above note.
                return gfx_interface.Gfx_Pipeline{}, .Invalid_Parameter
            }

            input_element_descs[i] = D3D11_INPUT_ELEMENT_DESC{
                SemanticName      = semantic_name_cstr,
                SemanticIndex     = UINT(attr.semantic_index),
                Format            = dxgi_fmt,
                InputSlot         = UINT(attr.buffer_slot), // Or determine from vertex_layout.buffers[attr.buffer_slot].slot
                AlignedByteOffset = UINT(attr.offset_in_bytes), // Or use D3D11_APPEND_ALIGNED_ELEMENT if calculating automatically
                InputSlotClass    = .PER_VERTEX_DATA, // Assuming per-vertex for now
                InstanceDataStepRate = 0,
            }
            // TODO: Handle per-instance data based on vertex_layout.buffers[attr.buffer_slot].step_rate
        }
        
        hr = Device_CreateInputLayout(di.device, &input_element_descs[0], UINT(num_elements), 
                                      vs_bytecode_ptr, vs_bytecode_size, &pipeline_internal.input_layout)
        if FAILED(hr) {
            log.errorf("DX11: Device_CreateInputLayout failed. HRESULT: %X", hr)
            return gfx_interface.Gfx_Pipeline{}, .Graphics_Resource_Creation_Failed
        }
    } else {
        pipeline_internal.input_layout = nil // No attributes, no input layout
    }


    // --- 2. Blend State ---
    bs_desc := D3D11_BLEND_DESC{}
    bs_desc.AlphaToCoverageEnable = pipeline_desc.blend_state.alpha_to_coverage_enable
    bs_desc.IndependentBlendEnable = false // Common case: same blend for all MRTs
    
    // Assuming single render target for now (RenderTarget[0])
    rt_blend_desc := &bs_desc.RenderTarget[0]
    rt_blend_desc.BlendEnable = pipeline_desc.blend_state.blend_enable
    
    ok_blend: bool
    rt_blend_desc.SrcBlend, ok_blend = to_d3d11_blend(pipeline_desc.blend_state.src_factor_rgb)
    if !ok_blend { return gfx_interface.Gfx_Pipeline{}, .Invalid_Parameter }
    rt_blend_desc.DestBlend, ok_blend = to_d3d11_blend(pipeline_desc.blend_state.dst_factor_rgb)
    if !ok_blend { return gfx_interface.Gfx_Pipeline{}, .Invalid_Parameter }
    rt_blend_desc.BlendOp, ok_blend = to_d3d11_blend_op(pipeline_desc.blend_state.op_rgb)
    if !ok_blend { return gfx_interface.Gfx_Pipeline{}, .Invalid_Parameter }
    
    rt_blend_desc.SrcBlendAlpha, ok_blend = to_d3d11_blend(pipeline_desc.blend_state.src_factor_alpha)
    if !ok_blend { return gfx_interface.Gfx_Pipeline{}, .Invalid_Parameter }
    rt_blend_desc.DestBlendAlpha, ok_blend = to_d3d11_blend(pipeline_desc.blend_state.dst_factor_alpha)
    if !ok_blend { return gfx_interface.Gfx_Pipeline{}, .Invalid_Parameter }
    rt_blend_desc.BlendOpAlpha, ok_blend = to_d3d11_blend_op(pipeline_desc.blend_state.op_alpha)
    if !ok_blend { return gfx_interface.Gfx_Pipeline{}, .Invalid_Parameter }

    rt_blend_desc.RenderTargetWriteMask = u8(pipeline_desc.blend_state.color_write_mask) // Assuming direct mapping for now

    hr = Device_CreateBlendState(di.device, &bs_desc, &pipeline_internal.blend_state)
    if FAILED(hr) {
        log.errorf("DX11: Device_CreateBlendState failed. HRESULT: %X", hr)
        if pipeline_internal.input_layout != nil { InputLayout_Release(pipeline_internal.input_layout) }
        return gfx_interface.Gfx_Pipeline{}, .Graphics_Resource_Creation_Failed
    }

    // --- 3. Depth Stencil State ---
    dss_desc := D3D11_DEPTH_STENCIL_DESC{}
    dss_desc.DepthEnable = pipeline_desc.depth_stencil_state.depth_test_enable
    dss_desc.DepthWriteMask = pipeline_desc.depth_stencil_state.depth_write_enable ? .ALL : .ZERO
    dss_desc.DepthFunc, ok = to_d3d11_comparison_func(pipeline_desc.depth_stencil_state.depth_compare_op)
    if !ok { /* cleanup, return error */ return gfx_interface.Gfx_Pipeline{}, .Invalid_Parameter} // Simplified cleanup

    dss_desc.StencilEnable = pipeline_desc.depth_stencil_state.stencil_enable
    dss_desc.StencilReadMask = pipeline_desc.depth_stencil_state.stencil_read_mask
    dss_desc.StencilWriteMask = pipeline_desc.depth_stencil_state.stencil_write_mask
    // TODO: Map FrontFace and BackFace D3D11_DEPTH_STENCILOP_DESC from pipeline_desc

    hr = Device_CreateDepthStencilState(di.device, &dss_desc, &pipeline_internal.depth_stencil_state)
    if FAILED(hr) {
        log.errorf("DX11: Device_CreateDepthStencilState failed. HRESULT: %X", hr)
        if pipeline_internal.input_layout != nil { InputLayout_Release(pipeline_internal.input_layout) }
        if pipeline_internal.blend_state != nil { BlendState_Release(pipeline_internal.blend_state) }
        return gfx_interface.Gfx_Pipeline{}, .Graphics_Resource_Creation_Failed
    }

    // --- 4. Rasterizer State ---
    rs_desc := D3D11_RASTERIZER_DESC{}
    switch pipeline_desc.rasterizer_state.fill_mode {
    case .Solid: rs_desc.FillMode = .SOLID
    case .Wireframe: rs_desc.FillMode = .WIREFRAME
    else: log.warnf("DX11: Unsupported fill mode %v, defaulting to SOLID.", pipeline_desc.rasterizer_state.fill_mode); rs_desc.FillMode = .SOLID
    }
    switch pipeline_desc.rasterizer_state.cull_mode {
    case .None: rs_desc.CullMode = .NONE
    case .Front: rs_desc.CullMode = .FRONT
    case .Back: rs_desc.CullMode = .BACK
    else: log.warnf("DX11: Unsupported cull mode %v, defaulting to BACK.", pipeline_desc.rasterizer_state.cull_mode); rs_desc.CullMode = .BACK
    }
    rs_desc.FrontCounterClockwise = pipeline_desc.rasterizer_state.front_face_winding == .CounterClockwise
    rs_desc.DepthBias = INT(pipeline_desc.rasterizer_state.depth_bias)
    rs_desc.DepthBiasClamp = pipeline_desc.rasterizer_state.depth_bias_clamp
    rs_desc.SlopeScaledDepthBias = pipeline_desc.rasterizer_state.slope_scaled_depth_bias
    rs_desc.DepthClipEnable = pipeline_desc.rasterizer_state.depth_clip_enable
    rs_desc.ScissorEnable = pipeline_desc.rasterizer_state.scissor_enable
    rs_desc.MultisampleEnable = false // Relates to MSAA render targets, not just a rasterizer state
    rs_desc.AntialiasedLineEnable = false // For wireframe lines

    hr = Device_CreateRasterizerState(di.device, &rs_desc, &pipeline_internal.rasterizer_state)
    if FAILED(hr) {
        log.errorf("DX11: Device_CreateRasterizerState failed. HRESULT: %X", hr)
        if pipeline_internal.input_layout != nil { InputLayout_Release(pipeline_internal.input_layout) }
        if pipeline_internal.blend_state != nil { BlendState_Release(pipeline_internal.blend_state) }
        if pipeline_internal.depth_stencil_state != nil { DepthStencilState_Release(pipeline_internal.depth_stencil_state) }
        return gfx_interface.Gfx_Pipeline{}, .Graphics_Resource_Creation_Failed
    }

    // --- 5. Primitive Topology ---
    pipeline_internal.primitive_topology = pipeline_desc.primitive_topology // Store engine-level topology

    gfx_pipeline := gfx_interface.Gfx_Pipeline{
        variant = D3D11_Pipeline_Variant(pipeline_internal),
    }
    log.info("DX11: Pipeline created successfully.")
    return gfx_pipeline, .None
}

destroy_pipeline_impl :: proc(pipeline_handle: gfx_interface.Gfx_Pipeline) -> common.Engine_Error {
    pi_variant, ok := pipeline_handle.variant.(D3D11_Pipeline_Variant)
    if !ok || pi_variant == nil {
        log.warn("DX11: destroy_pipeline_impl: Invalid Gfx_Pipeline variant.")
        return .Invalid_Handle
    }
    pi := pi_variant

    log.debug("DX11: Destroying pipeline.")
    if pi.input_layout != nil { InputLayout_Release(pi.input_layout); pi.input_layout = nil }
    if pi.blend_state != nil { BlendState_Release(pi.blend_state); pi.blend_state = nil }
    if pi.depth_stencil_state != nil { DepthStencilState_Release(pi.depth_stencil_state); pi.depth_stencil_state = nil }
    if pi.rasterizer_state != nil { RasterizerState_Release(pi.rasterizer_state); pi.rasterizer_state = nil }

    // Shaders referenced (vertex_shader_ref, pixel_shader_ref) are not owned by the pipeline,
    // so their D3D objects are not released here. They are managed by Gfx_Shader handles.

    if pi.allocator.proc != nil {
        free(pi, pi.allocator)
    } else {
        log.warn("DX11: destroy_pipeline_impl: D3D11_Pipeline_Internal allocator is nil.")
    }
    
    log.info("DX11: Pipeline destroyed successfully.")
    return .None
}

set_pipeline_impl :: proc(device_handle: gfx_interface.Gfx_Device, pipeline_handle: gfx_interface.Gfx_Pipeline) -> common.Engine_Error {
    di := get_device_internal(device_handle)
    if di == nil || di.immediate_context == nil {
        log.error("DX11: set_pipeline_impl: Invalid Gfx_Device or D3D11 immediate context.")
        return .Invalid_Handle
    }
    pi_variant, ok_pipe := pipeline_handle.variant.(D3D11_Pipeline_Variant)
    if !ok_pipe || pi_variant == nil {
        log.error("DX11: set_pipeline_impl: Invalid Gfx_Pipeline.")
        return .Invalid_Handle
    }
    pi := pi_variant

    // log.debug("DX11: Setting pipeline.") // Can be very spammy

    // Set Input Layout
    Context_IASetInputLayout(di.immediate_context, pi.input_layout)

    // Set Primitive Topology
    d3d_topo, ok_topo := to_d3d_primitive_topology(pi.primitive_topology)
    if !ok_topo { return .Invalid_Parameter } // Error logged in helper
    Context_IASetPrimitiveTopology(di.immediate_context, d3d_topo)

    // Set Shaders
    vs_internal_variant, vs_ok := pi.vertex_shader_ref.variant.(D3D11_Shader_Variant)
    if vs_ok && vs_internal_variant != nil {
        Context_VSSetShader(di.immediate_context, vs_internal_variant.shader_object.vs, nil, 0)
    } else {
        log.error("DX11: set_pipeline_impl: Invalid vertex shader in pipeline.")
        // Optionally set VS to nil: Context_VSSetShader(di.immediate_context, nil, nil, 0)
        return .Invalid_Handle 
    }

    if pi.pixel_shader_ref.variant != nil { // Pixel shader can be nil
        ps_internal_variant, ps_ok := pi.pixel_shader_ref.variant.(D3D11_Shader_Variant)
        if ps_ok && ps_internal_variant != nil {
            Context_PSSetShader(di.immediate_context, ps_internal_variant.shader_object.ps, nil, 0)
        } else {
             Context_PSSetShader(di.immediate_context, nil, nil, 0) // Explicitly unbind if invalid
        }
    } else {
        Context_PSSetShader(di.immediate_context, nil, nil, 0) // Unbind pixel shader
    }
    // TODO: Set GS, HS, DS, CS if supported

    // Set Rasterizer State
    Context_RSSetState(di.immediate_context, pi.rasterizer_state)

    // Set Blend State
    // BlendFactor and SampleMask are often default (nil/[1,1,1,1] and 0xffffffff)
    blend_factor: [4]FLOAT = {1.0, 1.0, 1.0, 1.0} 
    Context_OMSetBlendState(di.immediate_context, pi.blend_state, &blend_factor, 0xffffffff)
    
    // Set Depth Stencil State
    // StencilRef is often default (0)
    Context_OMSetDepthStencilState(di.immediate_context, pi.depth_stencil_state, 0)

    return .None
}


// Individual state setters - these are complex with immutable D3D11 states.
// For now, they are mostly not implemented or would require a PSO cache/recreation system.
set_blend_mode_impl :: proc(device: gfx_interface.Gfx_Device, enabled: bool, src_factor: gfx_interface.Blend_Factor, dst_factor: gfx_interface.Blend_Factor, op: gfx_interface.Blend_Op) -> common.Engine_Error {
    log.warn("DX11: set_blend_mode_impl is a simplified stub. Full dynamic state changes require PSO management not yet implemented. Use create_pipeline for full control.")
    // This would require finding/creating a D3D11_BLEND_STATE object that matches these parameters
    // and then calling OMSetBlendState. This is non-trivial.
    return .Not_Implemented
}

set_depth_test_impl :: proc(device: gfx_interface.Gfx_Device, enabled: bool, write_enable: bool, compare_op: gfx_interface.Comparison_Func) -> common.Engine_Error {
    log.warn("DX11: set_depth_test_impl is a simplified stub. Full dynamic state changes require PSO management not yet implemented. Use create_pipeline for full control.")
    return .Not_Implemented
}

set_cull_mode_impl :: proc(device: gfx_interface.Gfx_Device, cull_mode: gfx_interface.Cull_Mode, front_winding: gfx_interface.Winding_Order) -> common.Engine_Error {
    log.warn("DX11: set_cull_mode_impl is a simplified stub. Full dynamic state changes require PSO management not yet implemented. Use create_pipeline for full control.")
    return .Not_Implemented
}
