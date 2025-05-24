package directx11

import "../gfx_interface"
import "../../common"
import "./dx11_types"
import "./dx11_bindings"
import "core:log"
import "core:mem"
import "core:strings" // For string manipulation if needed for cstring conversion
import "core:sys/windows" // For LPCSTR etc.

// --- Shader Management Implementation ---

_get_shader_profile_and_entry :: proc(shader_type: gfx_interface.Shader_Type) -> (entry_point: string, target_profile: string, ok: bool) {
    ok = true
    switch shader_type {
    case .Vertex:
        entry_point = "VSMain"
        target_profile = "vs_5_0" 
    case .Pixel: 
        entry_point = "PSMain"
        target_profile = "ps_5_0" 
    else:
        log.errorf("DX11: Unsupported shader type: %v", shader_type)
        ok = false
    }
    return
}

create_shader_from_source_impl :: proc(
    device_handle: gfx_interface.Gfx_Device,
    shader_source: string,
    shader_type: gfx_interface.Shader_Type,
    label: string = "", 
) -> (gfx_interface.Gfx_Shader, common.Engine_Error) {

    log.debugf("DX11: create_shader_from_source_impl called. Type: %v, Label: '%s'", shader_type, label)

    di := get_device_internal(device_handle)
    if di == nil || di.device == nil {
        log.error("DX11: create_shader_from_source_impl: Invalid Gfx_Device or D3D11 device.")
        return gfx_interface.Gfx_Shader{}, .Invalid_Handle
    }

    entry_point_str, target_profile_str, ok := _get_shader_profile_and_entry(shader_type)
    if !ok {
        return gfx_interface.Gfx_Shader{}, .Invalid_Parameter
    }
    
    // D3DCompile expects null-terminated strings for entry point, target, and source name.
    // Odin strings are not inherently null-terminated.
    // We must ensure null termination for these parameters.
    // A common way is to clone to a C-string or append a null terminator.
    // For simplicity with fixed strings like "VSMain", "ps_5_0", we can make them C-string literals.
    // Or, for passed strings, ensure they are converted.

    // For D3DCompile, pEntrypoint and pTarget can be direct string literals if they are const.
    entry_point_cstr := strings.clone_to_cstring(entry_point_str, context.temp_allocator)
    defer delete(entry_point_cstr, context.temp_allocator)
    target_profile_cstr := strings.clone_to_cstring(target_profile_str, context.temp_allocator)
    defer delete(target_profile_cstr, context.temp_allocator)
    
    // pSourceName can be nil. If label is provided, use it.
    source_name_cstr: LPCSTR = nil
    temp_label_cstr: ^byte = nil
    if label != "" {
        temp_label_cstr = strings.clone_to_cstring(label, context.temp_allocator)
        defer delete(temp_label_cstr, context.temp_allocator)
        source_name_cstr = temp_label_cstr
    }


    compile_flags: UINT = D3DCOMPILE_ENABLE_STRICTNESS
    if di.debug_device { 
        compile_flags |= D3DCOMPILE_DEBUG
        compile_flags |= D3DCOMPILE_SKIP_OPTIMIZATION 
    } else {
        compile_flags |= D3DCOMPILE_OPTIMIZATION_LEVEL3
    }

    bytecode_blob: ID3DBlob_Handle = nil
    error_blob: ID3DBlob_Handle = nil
    
    hr := D3DCompile(
        rawptr(shader_source.data),
        SIZE_T(len(shader_source)),
        source_name_cstr, 
        nil, // pDefines
        D3DCOMPILE_STANDARD_FILE_INCLUDE, 
        entry_point_cstr, 
        target_profile_cstr, 
        compile_flags, 
        0,             
        &bytecode_blob,
        &error_blob,
    )

    if FAILED(hr) {
        log.errorf("DX11: D3DCompile failed. HRESULT: %X. Label: '%s'", hr, label)
        if error_blob != nil {
            error_msg_ptr := Blob_GetBufferPointer(error_blob)
            error_msg_size := Blob_GetBufferSize(error_blob)
            error_string := string(transmute([^]u8)error_msg_ptr[:error_msg_size])
            log.errorf("DX11: Compiler errors:\n%s", error_string)
            Blob_Release(error_blob)
        }
        if bytecode_blob != nil { Blob_Release(bytecode_blob); bytecode_blob = nil } 
        return gfx_interface.Gfx_Shader{}, .Shader_Compilation_Failed
    }

    if error_blob != nil { 
        error_msg_ptr := Blob_GetBufferPointer(error_blob)
        error_msg_size := Blob_GetBufferSize(error_blob)
        warning_string := string(transmute([^]u8)error_msg_ptr[:error_msg_size])
        log.warnf("DX11: Compiler warnings (Label: '%s'):\n%s", label, warning_string)
        Blob_Release(error_blob) 
    }

    if bytecode_blob == nil { 
        log.error("DX11: D3DCompile succeeded but returned no bytecode blob. Label: '%s'", label)
        return gfx_interface.Gfx_Shader{}, .Shader_Compilation_Failed
    }

    shader_bytecode_ptr := Blob_GetBufferPointer(bytecode_blob)
    shader_bytecode_size := Blob_GetBufferSize(bytecode_blob)

    shader_internal := new(D3D11_Shader_Internal, di.allocator)
    shader_internal.allocator = di.allocator
    shader_internal.stage = shader_type
    
    hr_shader_create: HRESULT = S_OK

    switch shader_type {
    case .Vertex:
        hr_shader_create = Device_CreateVertexShader(di.device, shader_bytecode_ptr, shader_bytecode_size, nil, &shader_internal.shader_object.vs)
        shader_internal.bytecode_blob = bytecode_blob // Store blob for VS (for Input Layout)
    case .Pixel:
        hr_shader_create = Device_CreatePixelShader(di.device, shader_bytecode_ptr, shader_bytecode_size, nil, &shader_internal.shader_object.ps)
        Blob_Release(bytecode_blob) // PS bytecode not typically needed after creation
        shader_internal.bytecode_blob = nil 
    else:
        log.errorf("DX11: Cannot create shader object for unsupported shader type: %v. Label: '%s'", shader_type, label)
        Blob_Release(bytecode_blob) 
        free(shader_internal, shader_internal.allocator)
        return gfx_interface.Gfx_Shader{}, .Invalid_Parameter
    }

    if FAILED(hr_shader_create) {
        log.errorf("DX11: Failed to create %v shader object from bytecode. HRESULT: %X. Label: '%s'", shader_type, hr_shader_create, label)
        if shader_internal.bytecode_blob != nil { // If VS blob was stored and create failed
            Blob_Release(shader_internal.bytecode_blob)
        }
        free(shader_internal, shader_internal.allocator)
        return gfx_interface.Gfx_Shader{}, .Graphics_Resource_Creation_Failed
    }
    
    log.infof("DX11: %v shader created successfully. Label: '%s'", shader_type, label)
    
    gfx_shader := gfx_interface.Gfx_Shader{
        variant = D3D11_Shader_Variant(shader_internal),
        shader_type = shader_type,
    }
    return gfx_shader, .None
}


create_shader_from_bytecode_impl :: proc(
    device_handle: gfx_interface.Gfx_Device,
    shader_bytecode: []u8,
    shader_type: gfx_interface.Shader_Type,
    label: string = "", 
) -> (gfx_interface.Gfx_Shader, common.Engine_Error) {

    log.debugf("DX11: create_shader_from_bytecode_impl called. Type: %v, Size: %d, Label: '%s'", 
              shader_type, len(shader_bytecode), label)

    di := get_device_internal(device_handle)
    if di == nil || di.device == nil {
        log.error("DX11: create_shader_from_bytecode_impl: Invalid Gfx_Device or D3D11 device.")
        return gfx_interface.Gfx_Shader{}, .Invalid_Handle
    }

    if len(shader_bytecode) == 0 {
        log.error("DX11: create_shader_from_bytecode_impl: Shader bytecode is empty. Label: '%s'", label)
        return gfx_interface.Gfx_Shader{}, .Invalid_Parameter
    }

    bytecode_ptr := rawptr(shader_bytecode.data)
    bytecode_size := SIZE_T(len(shader_bytecode))

    shader_internal := new(D3D11_Shader_Internal, di.allocator)
    shader_internal.allocator = di.allocator
    shader_internal.stage = shader_type
    
    hr_shader_create: HRESULT = S_OK

    switch shader_type {
    case .Vertex:
        hr_shader_create = Device_CreateVertexShader(di.device, bytecode_ptr, bytecode_size, nil, &shader_internal.shader_object.vs)
        // If bytecode is from an external source and needs to be kept for Input Layout,
        // it should be copied into a new ID3DBlob or an engine-managed buffer.
        // For now, if created from raw bytecode, we assume the caller manages the bytecode if needed elsewhere,
        // or that it's not needed (e.g., if input layout is defined separately or not used).
        // To be safe and consistent with create_from_source, we could create a blob here.
        // However, D3DCreateBlob is another function to bind.
        // For now, set to nil. If this Gfx_Shader is used for input layout, bytecode might need to be retrieved/passed differently.
        shader_internal.bytecode_blob = nil 
    case .Pixel:
        hr_shader_create = Device_CreatePixelShader(di.device, bytecode_ptr, bytecode_size, nil, &shader_internal.shader_object.ps)
        shader_internal.bytecode_blob = nil 
    else:
        log.errorf("DX11: Cannot create shader object from bytecode for unsupported shader type: %v. Label: '%s'", shader_type, label)
        free(shader_internal, shader_internal.allocator)
        return gfx_interface.Gfx_Shader{}, .Invalid_Parameter
    }

    if FAILED(hr_shader_create) {
        log.errorf("DX11: Failed to create %v shader object from bytecode. HRESULT: %X. Label: '%s'", shader_type, hr_shader_create, label)
        free(shader_internal, shader_internal.allocator)
        return gfx_interface.Gfx_Shader{}, .Graphics_Resource_Creation_Failed
    }

    log.infof("DX11: %v shader from bytecode created successfully. Label: '%s'", shader_type, label)

    gfx_shader := gfx_interface.Gfx_Shader{
        variant = D3D11_Shader_Variant(shader_internal),
        shader_type = shader_type,
    }
    return gfx_shader, .None
}


destroy_shader_impl :: proc(shader_handle: gfx_interface.Gfx_Shader) -> common.Engine_Error {
    si_variant, ok := shader_handle.variant.(D3D11_Shader_Variant)
    if !ok || si_variant == nil {
        log.warn("DX11: destroy_shader_impl: Invalid Gfx_Shader variant.")
        return .Invalid_Handle
    }
    si := si_variant

    log.debugf("DX11: Destroying shader. Type: %v", si.stage)

    switch si.stage {
    case .Vertex:
        if si.shader_object.vs != nil { VertexShader_Release(si.shader_object.vs); si.shader_object.vs = nil }
    case .Pixel:
        if si.shader_object.ps != nil { PixelShader_Release(si.shader_object.ps); si.shader_object.ps = nil }
    else:
        log.warnf("DX11: destroy_shader_impl: Unknown shader stage (%v) for stored shader object.", si.stage)
    }

    if si.bytecode_blob != nil {
        Blob_Release(si.bytecode_blob)
        si.bytecode_blob = nil
    }

    if si.allocator.proc != nil {
        free(si, si.allocator)
    } else {
        log.warn("DX11: destroy_shader_impl: D3D11_Shader_Internal allocator is nil.")
    }
    
    log.info("DX11: Shader destroyed successfully.")
    return .None
}
