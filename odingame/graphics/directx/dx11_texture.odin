package directx11

import "../gfx_interface"
import "../../common"
import "./dx11_types"
import "./dx11_bindings"
import "core:log"
import "core:mem"

// --- Texture Management Implementation ---

create_texture_impl :: proc(
    device_handle: gfx_interface.Gfx_Device,
    width: int,
    height: int,
    gfx_format_arg: gfx_interface.Texture_Format, // Renamed to avoid conflict
    usage_flags: gfx_interface.Texture_Usage_Flags, 
    initial_data: rawptr, 
    label: string = "", 
) -> (gfx_interface.Gfx_Texture, common.Engine_Error) {

    log.debugf("DX11: create_texture_impl called. W: %d, H: %d, Format: %v, Usage: %v, Label: '%s'",
              width, height, gfx_format_arg, usage_flags, label)

    di := get_device_internal(device_handle)
    if di == nil || di.device == nil {
        log.error("DX11: create_texture_impl: Invalid Gfx_Device or D3D11 device.")
        return gfx_interface.Gfx_Texture{}, .Invalid_Handle
    }

    if width <= 0 || height <= 0 {
        log.errorf("DX11: create_texture_impl: Invalid dimensions (%d x %d).", width, height)
        return gfx_interface.Gfx_Texture{}, .Invalid_Parameter
    }

    dxgi_fmt, bytes_per_pixel, fmt_ok := to_dxgi_format_and_bpp(gfx_format_arg)
    if !fmt_ok {
        log.errorf("DX11: create_texture_impl: Unsupported gfx_interface.Texture_Format: %v.", gfx_format_arg)
        return gfx_interface.Gfx_Texture{}, .Invalid_Parameter
    }

    actual_d3d_usage: D3D11_USAGE
    actual_d3d_cpu_access: UINT = 0
    actual_d3d_bind_flags: UINT = 0
    
    // Determine D3D11_USAGE and CPUAccessFlags
    if usage_flags has .Dynamic {
        actual_d3d_usage = .DYNAMIC
        actual_d3d_cpu_access = UINT(D3D11_CPU_ACCESS_FLAG.WRITE)
    } else if initial_data != nil && !(usage_flags has .RenderTarget || usage_flags has .DepthStencil) {
        actual_d3d_usage = .IMMUTABLE
    } else {
        actual_d3d_usage = .DEFAULT
    }

    // Determine BindFlags
    if usage_flags has .ShaderResource { actual_d3d_bind_flags |= UINT(D3D11_BIND_FLAG.SHADER_RESOURCE) }
    if usage_flags has .RenderTarget   { actual_d3d_bind_flags |= UINT(D3D11_BIND_FLAG.RENDER_TARGET) }
    if usage_flags has .DepthStencil   { actual_d3d_bind_flags |= UINT(D3D11_BIND_FLAG.DEPTH_STENCIL) }
    
    if actual_d3d_bind_flags == 0 {
        if initial_data != nil {
            log.warn("DX11: create_texture_impl: No specific bind flags, defaulting to ShaderResource due to initial_data.")
            actual_d3d_bind_flags = UINT(D3D11_BIND_FLAG.SHADER_RESOURCE)
        } else {
             log.error("DX11: create_texture_impl: Texture must have at least one bind flag.")
             return gfx_interface.Gfx_Texture{}, .Invalid_Parameter
        }
    }

    desc := D3D11_TEXTURE2D_DESC{
        Width           = UINT(width),
        Height          = UINT(height),
        MipLevels       = 1, 
        ArraySize       = 1, 
        Format          = dxgi_fmt,
        SampleDesc      = {Count = 1, Quality = 0},
        Usage           = actual_d3d_usage,
        BindFlags       = actual_d3d_bind_flags,
        CPUAccessFlags  = actual_d3d_cpu_access,
        MiscFlags       = 0, 
    }
    // if usage_flags has .GenerateMips { desc.MiscFlags |= UINT(D3D11_RESOURCE_MISC_FLAG.GENERATE_MIPS) } // And MipLevels = 0

    subresource_data_array: [1]D3D11_SUBRESOURCE_DATA // D3D11_SUBRESOURCE_DATA for each mip level if MipLevels > 1
    p_initial_data_array: ^D3D11_SUBRESOURCE_DATA = nil
    if initial_data != nil {
        subresource_data_array[0].pSysMem = initial_data
        subresource_data_array[0].SysMemPitch = UINT(width * bytes_per_pixel)
        subresource_data_array[0].SysMemSlicePitch = 0 // Not used for 2D textures
        p_initial_data_array = &subresource_data_array[0]
    } else if actual_d3d_usage == .IMMUTABLE {
        log.error("DX11: create_texture_impl: IMMUTABLE texture requires initial_data.")
        return gfx_interface.Gfx_Texture{}, .Invalid_Parameter
    }

    created_texture_handle: ID3D11Texture2D_Handle
    hr := Device_CreateTexture2D(di.device, &desc, p_initial_data_array, &created_texture_handle)
    if FAILED(hr) {
        log.errorf("DX11: Device_CreateTexture2D failed. HRESULT: %X. Format: %v, Label: '%s'", hr, dxgi_fmt, label)
        return gfx_interface.Gfx_Texture{}, .Graphics_Resource_Creation_Failed
    }

    created_srv_handle: ID3D11ShaderResourceView_Handle = nil
    if (desc.BindFlags & UINT(D3D11_BIND_FLAG.SHADER_RESOURCE)) != 0 {
        srv_desc_val := D3D11_SHADER_RESOURCE_VIEW_DESC{
            Format:        desc.Format, 
            ViewDimension: .TEXTURE2D,
        }
        // Correctly access the union member for Texture2D
        srv_desc_val.union_Texture2D = D3D11_TEX2D_SRV{ // Assuming union_Texture2D is the name for Texture2D member in D3D11_SHADER_RESOURCE_VIEW_DESC
            MostDetailedMip = 0,
            MipLevels       = desc.MipLevels, 
        }
        
        hr_srv := Device_CreateShaderResourceView(di.device, created_texture_handle, &srv_desc_val, &created_srv_handle)
        if FAILED(hr_srv) {
            log.errorf("DX11: Device_CreateShaderResourceView failed. HRESULT: %X. Label: '%s'", hr_srv, label)
            Texture2D_Release(created_texture_handle) 
            return gfx_interface.Gfx_Texture{}, .Graphics_Resource_Creation_Failed
        }
    }

    texture_internal := new(D3D11_Texture_Internal, di.allocator)
    texture_internal.texture = created_texture_handle
    texture_internal.srv = created_srv_handle
    texture_internal.width = width
    texture_internal.height = height
    texture_internal.dxgi_format_actual = desc.Format
    texture_internal.d3d_usage = desc.Usage
    texture_internal.d3d_cpu_access = desc.CPUAccessFlags
    texture_internal.mip_levels = int(desc.MipLevels)
    texture_internal.allocator = di.allocator
    
    gfx_tex := gfx_interface.Gfx_Texture{
        variant = D3D11_Texture_Variant(texture_internal),
        width = width, height = height, format = gfx_format_arg,
    }

    log.infof("DX11: Texture created successfully. Handle: %p, SRV: %p, Label: '%s'", 
              created_texture_handle, created_srv_handle, label)
    return gfx_tex, .None
}

update_texture_impl :: proc(
    device_handle: gfx_interface.Gfx_Device, 
    texture_handle: gfx_interface.Gfx_Texture,
    x_offset: int, y_offset: int,
    update_width: int, update_height: int,
    data: rawptr, 
    data_pitch: int, 
) -> common.Engine_Error {

    ti_variant, ok := texture_handle.variant.(D3D11_Texture_Variant)
    if !ok || ti_variant == nil || ti_variant.texture == nil {
        log.error("DX11: update_texture_impl: Invalid Gfx_Texture or D3D11 texture handle.")
        return .Invalid_Handle
    }
    ti := ti_variant

    if data == nil {
        log.error("DX11: update_texture_impl: Input data is nil.")
        return .Invalid_Parameter
    }
    if x_offset < 0 || y_offset < 0 || update_width <= 0 || update_height <= 0 ||
       (x_offset + update_width) > ti.width || (y_offset + update_height) > ti.height {
        log.errorf("DX11: update_texture_impl: Invalid update region. Offset:(%d,%d), Size:(%d,%d), TexSize:(%d,%d)",
                  x_offset, y_offset, update_width, update_height, ti.width, ti.height)
        return .Invalid_Parameter
    }
    
    di := get_device_internal(device_handle)
    if di == nil || di.immediate_context == nil {
        log.error("DX11: update_texture_impl: Invalid Gfx_Device or D3D11 immediate context.")
        return .Invalid_Handle
    }

    if ti.d3d_usage == .DYNAMIC {
        if (ti.d3d_cpu_access & UINT(D3D11_CPU_ACCESS_FLAG.WRITE)) == 0 {
            log.error("DX11: update_texture_impl: Texture is DYNAMIC but not CPU writable.")
            return .Invalid_Operation
        }
        mapped_subresource: D3D11_MAPPED_SUBRESOURCE
        // For DYNAMIC textures, map with WRITE_DISCARD. Partial updates are complex and often avoided by re-uploading the whole texture region of interest.
        // This implementation assumes the user wants to replace the entire content if using DYNAMIC or manages regions carefully.
        // A more robust partial update for dynamic textures would involve D3D11_MAP_WRITE_NO_OVERWRITE and careful region management.
        hr := Context_Map_Texture(di.immediate_context, ti.texture, 0, .WRITE_DISCARD, 0, &mapped_subresource)
        if FAILED(hr) {
            log.errorf("DX11: Context_Map_Texture failed for dynamic texture. HRESULT: %X", hr)
            return .Graphics_Operation_Failed
        }

        dest_base_ptr := uintptr(mapped_subresource.pData)
        src_base_ptr := uintptr(data)
        
        // This simplified copy assumes the update region matches the texture dimensions or that RowPitch matches data_pitch.
        // For a true subrect update into a mapped resource, a row-by-row copy adjusting for pitches is needed.
        // _, bpp, _ := to_dxgi_format_and_bpp_from_dxgi(ti.dxgi_format_actual) // Helper needed
        // For now, assume data_pitch is for the update_width.
        // And mapped_subresource.RowPitch is for the full texture width.

        if x_offset == 0 && y_offset == 0 && update_width == ti.width && update_height == ti.height && data_pitch == int(mapped_subresource.RowPitch) {
            // Full texture update, pitches match
            mem.copy(mapped_subresource.pData, data, update_height * data_pitch)
        } else {
            // Partial update: requires row-by-row copy
            // Get BPP from the actual DXGI format stored
            _, bpp_actual, bpp_ok := to_dxgi_format_and_bpp_from_dxgi(ti.dxgi_format_actual)
            if !bpp_ok || bpp_actual == 0 {
                log.errorf("DX11: update_texture_impl: Could not determine BPP for DXGI_FORMAT %v for partial dynamic update.", ti.dxgi_format_actual)
                Context_Unmap_Texture(di.immediate_context, ti.texture, 0)
                return .Invalid_Operation
            }

            for y in 0..<update_height {
                dest_row_start := rawptr(dest_base_ptr + uintptr(y_offset + y) * uintptr(mapped_subresource.RowPitch) + uintptr(x_offset * bpp_actual))
                src_row_start  := rawptr(src_base_ptr + uintptr(y) * uintptr(data_pitch))
                mem.copy(dest_row_start, src_row_start, update_width * bpp_actual)
            }
        }
        Context_Unmap_Texture(di.immediate_context, ti.texture, 0)

    } else if ti.d3d_usage == .DEFAULT {
        dst_box := D3D11_BOX{
            left   = UINT(x_offset),
            top    = UINT(y_offset),
            front  = 0,
            right  = UINT(x_offset + update_width),
            bottom = UINT(y_offset + update_height),
            back   = 1, 
        }
        Context_UpdateSubresource(di.immediate_context, ti.texture, 0, &dst_box, data, UINT(data_pitch), 0)
    
    } else if ti.d3d_usage == .IMMUTABLE {
        log.error("DX11: update_texture_impl: Cannot update IMMUTABLE texture.")
        return .Invalid_Operation
    } else { 
        log.warnf("DX11: update_texture_impl: Update logic for D3D11_USAGE %v not fully implemented.", ti.d3d_usage)
        return .Invalid_Operation 
    }
    
    return .None
}


destroy_texture_impl :: proc(texture_handle: gfx_interface.Gfx_Texture) -> common.Engine_Error {
    ti_variant, ok := texture_handle.variant.(D3D11_Texture_Variant)
    if !ok || ti_variant == nil {
        log.warn("DX11: destroy_texture_impl: Invalid Gfx_Texture variant.")
        return .Invalid_Handle
    }
    ti := ti_variant

    log.debugf("DX11: Destroying texture. Handle: %p, SRV: %p", ti.texture, ti.srv)

    if ti.srv != nil { ShaderResourceView_Release(ti.srv); ti.srv = nil }
    if ti.rtv != nil { RTV_Release(ti.rtv); ti.rtv = nil }
    if ti.dsv != nil { DSV_Release(ti.dsv); ti.dsv = nil } // Assuming DSV_Release wrapper exists
    if ti.texture != nil { Texture2D_Release(ti.texture); ti.texture = nil }

    if ti.allocator.proc != nil {
        free(ti, ti.allocator)
    } else {
        log.warn("DX11: destroy_texture_impl: D3D11_Texture_Internal allocator is nil.")
    }
    
    log.info("DX11: Texture destroyed successfully.")
    return .None
}


// Helper to get BPP from DXGI_FORMAT (needed for partial dynamic texture updates)
// This can be expanded or moved to dx11_types.odin
to_dxgi_format_and_bpp_from_dxgi :: proc(format: DXGI_FORMAT) -> (dxgi: DXGI_FORMAT, bpp: int, ok: bool) {
    // This is a reverse lookup or direct mapping if the gfx_interface.Texture_Format is not the source.
    // For simplicity, this helper just returns BPP for known DXGI formats.
    ok = true
    bpp = 0
    // A subset of formats
    switch format {
    case .R8_UNORM: bpp = 1
    case .R8G8_UNORM: bpp = 2
    case .R8G8B8A8_UNORM, .B8G8R8A8_UNORM, .R8G8B8A8_UNORM_SRGB, .B8G8R8A8_UNORM_SRGB: bpp = 4
    case .R32_FLOAT: bpp = 4
    case .R32G32B32A32_FLOAT: bpp = 16
    case .D24_UNORM_S8_UINT: bpp = 4 
    // Add more as needed
    else: ok = false
    }
    return format, bpp, ok
}
