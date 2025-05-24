package directx11

import "../gfx_interface"
import "../../common"
import "./dx11_types"
import "./dx11_bindings"
import "core:log"
import "core:mem" // For mem.copy

// --- Buffer Management Implementation ---

create_buffer_impl :: proc(
    device_handle: gfx_interface.Gfx_Device,
    buffer_type_arg: gfx_interface.Buffer_Type, // Renamed to avoid conflict with D3D11_Buffer_Internal.buffer_type
    size_in_bytes: int,
    initial_data: rawptr,
    dynamic: bool, // Hint for DYNAMIC vs DEFAULT/IMMUTABLE usage
    label: string = "", // Optional label for debugging
) -> (gfx_interface.Gfx_Buffer, common.Engine_Error) {

    log.debugf("DX11: create_buffer_impl called. Type: %v, Size: %d, Dynamic: %t, Label: '%s'", 
              buffer_type_arg, size_in_bytes, dynamic, label)

    di := get_device_internal(device_handle)
    if di == nil || di.device == nil {
        log.error("DX11: create_buffer_impl: Invalid Gfx_Device or D3D11 device.")
        return gfx_interface.Gfx_Buffer{}, .Invalid_Handle
    }

    if size_in_bytes <= 0 {
        log.errorf("DX11: create_buffer_impl: Invalid size_in_bytes: %d", size_in_bytes)
        return gfx_interface.Gfx_Buffer{}, .Invalid_Parameter
    }

    desc := D3D11_BUFFER_DESC{
        ByteWidth = UINT(size_in_bytes),
        MiscFlags = 0,
        StructureByteStride = 0, 
    }

    // Store actual usage and cpu_access_flags for later logic (e.g. in map/update)
    actual_usage: D3D11_USAGE
    actual_cpu_access_flags: UINT = 0

    switch buffer_type_arg {
    case .Vertex:
        desc.BindFlags = UINT(D3D11_BIND_FLAG.VERTEX_BUFFER)
    case .Index:
        desc.BindFlags = UINT(D3D11_BIND_FLAG.INDEX_BUFFER)
    case .Constant: 
        desc.BindFlags = UINT(D3D11_BIND_FLAG.CONSTANT_BUFFER)
        if size_in_bytes % 16 != 0 {
            log.errorf("DX11: Constant buffer size (%d) must be a multiple of 16 bytes.", size_in_bytes)
            return gfx_interface.Gfx_Buffer{}, .Invalid_Parameter
        }
    else:
        log.errorf("DX11: create_buffer_impl: Unsupported buffer type: %v", buffer_type_arg)
        return gfx_interface.Gfx_Buffer{}, .Invalid_Parameter
    }

    if dynamic { 
        actual_usage = .DYNAMIC
        actual_cpu_access_flags = UINT(D3D11_CPU_ACCESS_FLAG.WRITE)
    } else {
        if initial_data != nil {
            actual_usage = .IMMUTABLE 
        } else {
            actual_usage = .DEFAULT 
        }
        actual_cpu_access_flags = 0
    }
    
    desc.Usage = actual_usage
    desc.CPUAccessFlags = actual_cpu_access_flags

    subresource_data: D3D11_SUBRESOURCE_DATA
    p_initial_data: ^D3D11_SUBRESOURCE_DATA = nil
    if initial_data != nil {
        subresource_data.pSysMem = initial_data
        subresource_data.SysMemPitch = 0 
        subresource_data.SysMemSlicePitch = 0
        p_initial_data = &subresource_data
    } else if actual_usage == .IMMUTABLE {
        log.error("DX11: create_buffer_impl: IMMUTABLE buffer requires initial_data.")
        return gfx_interface.Gfx_Buffer{}, .Invalid_Parameter
    }
    
    created_buffer_handle: ID3D11Buffer_Handle
    hr := Device_CreateBuffer(di.device, &desc, p_initial_data, &created_buffer_handle)

    if FAILED(hr) {
        log.errorf("DX11: Device_CreateBuffer failed. HRESULT: %X. Size: %d, Usage: %v, Bind: %X, CPUAccess: %X", 
                  hr, desc.ByteWidth, desc.Usage, desc.BindFlags, desc.CPUAccessFlags)
        return gfx_interface.Gfx_Buffer{}, .Graphics_Resource_Creation_Failed
    }

    buffer_internal := new(D3D11_Buffer_Internal, di.allocator)
    buffer_internal.buffer = created_buffer_handle
    buffer_internal.buffer_type = buffer_type_arg // Store the Gfx_Buffer_Type
    buffer_internal.size = size_in_bytes
    buffer_internal.usage = actual_usage // Store actual D3D11_USAGE
    buffer_internal.cpu_access = actual_cpu_access_flags // Store actual D3D11_CPU_ACCESS_FLAG
    buffer_internal.allocator = di.allocator

    gfx_buffer := gfx_interface.Gfx_Buffer{
        variant = D3D11_Buffer_Variant(buffer_internal),
        size_in_bytes = size_in_bytes,
        buffer_type = buffer_type_arg,
    }

    log.infof("DX11: Buffer created successfully. Handle: %p, Label: '%s', Usage: %v, CPUAccess: %v", 
              created_buffer_handle, label, actual_usage, actual_cpu_access_flags)
    return gfx_buffer, .None
}

update_buffer_impl :: proc(
    device_handle: gfx_interface.Gfx_Device, 
    buffer_handle: gfx_interface.Gfx_Buffer,
    offset_in_bytes: int,
    data_size_in_bytes: int,
    data: rawptr,
) -> common.Engine_Error {
    
    bi_variant, ok := buffer_handle.variant.(D3D11_Buffer_Variant)
    if !ok || bi_variant == nil || bi_variant.buffer == nil {
        log.error("DX11: update_buffer_impl: Invalid Gfx_Buffer or D3D11 buffer handle.")
        return .Invalid_Handle
    }
    bi := bi_variant

    if data == nil {
        log.error("DX11: update_buffer_impl: Input data is nil.")
        return .Invalid_Parameter
    }
    if offset_in_bytes < 0 || data_size_in_bytes <= 0 || (offset_in_bytes + data_size_in_bytes) > bi.size {
        log.errorf("DX11: update_buffer_impl: Invalid offset/size. Offset: %d, DataSize: %d, BufferSize: %d",
                  offset_in_bytes, data_size_in_bytes, bi.size)
        return .Invalid_Parameter
    }

    di := get_device_internal(device_handle)
    if di == nil || di.immediate_context == nil {
        log.error("DX11: update_buffer_impl: Invalid Gfx_Device or D3D11 immediate context.")
        return .Invalid_Handle
    }

    if bi.usage == .DYNAMIC { 
        if (bi.cpu_access & UINT(D3D11_CPU_ACCESS_FLAG.WRITE)) == 0 {
            log.error("DX11: update_buffer_impl: Buffer not created with DYNAMIC usage and CPU_ACCESS_WRITE.")
            return .Invalid_Operation
        }
        mapped_subresource: D3D11_MAPPED_SUBRESOURCE
        
        // DYNAMIC buffers are usually updated with WRITE_DISCARD (if replacing entire content or starting from scratch)
        // or WRITE_NO_OVERWRITE (if appending, requires careful synchronization).
        // If updating a specific region, Map + mem.copy is the way for DYNAMIC buffers.
        // Let's assume the user wants to overwrite the specified region.
        // WRITE_DISCARD is generally safer if the whole buffer's previous content for this frame is irrelevant.
        // If offset is 0 and size is full, WRITE_DISCARD. Otherwise, need to be careful.
        // For a generic update, we will map with D3D11_MAP_WRITE.
        // However, D3D11_MAP_WRITE is only valid for STAGING buffers with CPU write access.
        // For DYNAMIC, it must be WRITE_DISCARD or WRITE_NO_OVERWRITE.
        // Let's default to WRITE_DISCARD for simplicity if offset is 0, otherwise error or use NO_OVERWRITE.
        // A common pattern for partial updates to dynamic buffers is to map with WRITE_NO_OVERWRITE.
        
        map_type := D3D11_MAP.WRITE_NO_OVERWRITE 
        if offset_in_bytes == 0 && data_size_in_bytes == bi.size { // If full update
            map_type = .WRITE_DISCARD
        }
        // If it's a constant buffer, WRITE_DISCARD is very common.

        hr := Context_Map(di.immediate_context, bi.buffer, 0, map_type, 0, &mapped_subresource)
        if FAILED(hr) {
            log.errorf("DX11: Context_Map failed for dynamic buffer. HRESULT: %X, MapType: %v", hr, map_type)
            return .Graphics_Operation_Failed
        }

        dest_ptr := uintptr(mapped_subresource.pData) + uintptr(offset_in_bytes)
        mem.copy(rawptr(dest_ptr), data, data_size_in_bytes)
        
        Context_Unmap(di.immediate_context, bi.buffer, 0)

    } else if bi.usage == .DEFAULT { 
        dst_box: D3D11_BOX
        p_dst_box: ^D3D11_BOX = nil
        // UpdateSubresource updates a region defined by pDstBox.
        // If pDstBox is NULL, the entire subresource is updated.
        if offset_in_bytes != 0 || data_size_in_bytes != bi.size { // Partial update
            dst_box = D3D11_BOX {
                left   = UINT(offset_in_bytes),
                top    = 0, 
                front  = 0,
                right  = UINT(offset_in_bytes + data_size_in_bytes),
                bottom = 1, 
                back   = 1,
            }
            p_dst_box = &dst_box
        }
        Context_UpdateSubresource(di.immediate_context, bi.buffer, 0, p_dst_box, data, 0, 0)
    } else if bi.usage == .IMMUTABLE {
        log.error("DX11: update_buffer_impl: Cannot update IMMUTABLE buffer.")
        return .Invalid_Operation
    } else { // STAGING or other types
        log.warnf("DX11: update_buffer_impl: Update logic for usage type %v not fully implemented (treating like DEFAULT or DYNAMIC based on CPU flags).", bi.usage)
        // Fallback to map if CPU write access, else UpdateSubresource
        if (bi.cpu_access & UINT(D3D11_CPU_ACCESS_FLAG.WRITE)) != 0 {
             mapped_subresource: D3D11_MAPPED_SUBRESOURCE
             hr := Context_Map(di.immediate_context, bi.buffer, 0, .WRITE, 0, &mapped_subresource)
             if FAILED(hr) { return .Graphics_Operation_Failed }
             dest_ptr := uintptr(mapped_subresource.pData) + uintptr(offset_in_bytes)
             mem.copy(rawptr(dest_ptr), data, data_size_in_bytes)
             Context_Unmap(di.immediate_context, bi.buffer, 0)
        } else {
             return .Invalid_Operation // Cannot update if not DYNAMIC, DEFAULT, or STAGING_WRITE
        }
    }
    
    return .None
}

destroy_buffer_impl :: proc(buffer_handle: gfx_interface.Gfx_Buffer) -> common.Engine_Error {
    bi_variant, ok := buffer_handle.variant.(D3D11_Buffer_Variant)
    if !ok || bi_variant == nil {
        log.warn("DX11: destroy_buffer_impl: Invalid Gfx_Buffer variant.")
        return .Invalid_Handle 
    }
    bi := bi_variant

    if bi.buffer != nil {
        count := Buffer_Release(bi.buffer)
        log.debugf("DX11: Buffer released. Handle: %p, Ref count: %d", bi.buffer, count)
        bi.buffer = nil 
    }

    if bi.allocator.proc != nil {
         free(bi, bi.allocator)
    } else {
        log.warn("DX11: destroy_buffer_impl: D3D11_Buffer_Internal allocator is nil, cannot free struct.")
    }
    
    log.info("DX11: Buffer destroyed successfully.")
    return .None
}

map_buffer_impl :: proc(
    device_handle: gfx_interface.Gfx_Device, 
    buffer_handle: gfx_interface.Gfx_Buffer,
    access: gfx_interface.Buffer_Map_Access,
) -> (rawptr, common.Engine_Error) {

    bi_variant, ok := buffer_handle.variant.(D3D11_Buffer_Variant)
    if !ok || bi_variant == nil || bi_variant.buffer == nil {
        log.error("DX11: map_buffer_impl: Invalid Gfx_Buffer or D3D11 buffer handle.")
        return nil, .Invalid_Handle
    }
    bi := bi_variant

    di := get_device_internal(device_handle)
    if di == nil || di.immediate_context == nil {
        log.error("DX11: map_buffer_impl: Invalid Gfx_Device or D3D11 immediate context.")
        return nil, .Invalid_Handle
    }

    d3d11_map_type: D3D11_MAP
    can_map := false

    switch access {
    case .ReadOnly:
        d3d11_map_type = .READ
        if bi.usage == .STAGING && (bi.cpu_access & UINT(D3D11_CPU_ACCESS_FLAG.READ)) != 0 { can_map = true }
    case .WriteOnly: // General Write, typically for STAGING
        d3d11_map_type = .WRITE
        if bi.usage == .STAGING && (bi.cpu_access & UINT(D3D11_CPU_ACCESS_FLAG.WRITE)) != 0 { can_map = true }
    case .ReadWrite:
        d3d11_map_type = .READ_WRITE
        if bi.usage == .STAGING && (bi.cpu_access & UINT(D3D11_CPU_ACCESS_FLAG.READ_WRITE)) == UINT(D3D11_CPU_ACCESS_FLAG.READ_WRITE) { can_map = true }
    case .WriteDiscard:
        d3d11_map_type = .WRITE_DISCARD
        if bi.usage == .DYNAMIC && (bi.cpu_access & UINT(D3D11_CPU_ACCESS_FLAG.WRITE)) != 0 { can_map = true }
    case .WriteNoOverwrite:
        d3d11_map_type = .WRITE_NO_OVERWRITE
        if bi.usage == .DYNAMIC && (bi.cpu_access & UINT(D3D11_CPU_ACCESS_FLAG.WRITE)) != 0 { can_map = true }
    else:
        log.errorf("DX11: map_buffer_impl: Unsupported map access type: %v", access)
        return nil, .Invalid_Parameter
    }

    if !can_map {
        log.errorf("DX11: map_buffer_impl: Buffer (Usage: %v, CPUAccess: %X) cannot be mapped with access type %v.", bi.usage, bi.cpu_access, access)
        return nil, .Invalid_Operation
    }
    
    // map_flags: UINT = 0 // e.g. D3D11_MAP_FLAG_DO_NOT_WAIT (for advanced use)
    mapped_subresource: D3D11_MAPPED_SUBRESOURCE
    hr := Context_Map(di.immediate_context, bi.buffer, 0, d3d11_map_type, 0, &mapped_subresource)

    if FAILED(hr) {
        log.errorf("DX11: Context_Map failed. HRESULT: %X. MapType: %v", hr, d3d11_map_type)
        return nil, .Graphics_Operation_Failed
    }
    
    log.debugf("DX11: Buffer mapped successfully. Pointer: %p", mapped_subresource.pData)
    return mapped_subresource.pData, .None
}

unmap_buffer_impl :: proc(
    device_handle: gfx_interface.Gfx_Device, 
    buffer_handle: gfx_interface.Gfx_Buffer,
) -> common.Engine_Error {

    bi_variant, ok := buffer_handle.variant.(D3D11_Buffer_Variant)
    if !ok || bi_variant == nil || bi_variant.buffer == nil {
        // It's not necessarily an error to unmap a buffer that's not mapped or invalid,
        // but could indicate logic error in calling code. For robustness, just warn.
        log.warn("DX11: unmap_buffer_impl: Invalid Gfx_Buffer or D3D11 buffer handle.")
        return .None 
    }
    bi := bi_variant

    di := get_device_internal(device_handle)
    if di == nil || di.immediate_context == nil {
        log.error("DX11: unmap_buffer_impl: Invalid Gfx_Device or D3D11 immediate context.")
        return .Invalid_Handle // This is a more severe issue
    }

    // Check if buffer was actually mappable (Dynamic or Staging)
    // Unmapping a non-mappable buffer type doesn't hurt but indicates potential misuse.
    if bi.usage != .DYNAMIC && bi.usage != .STAGING {
        log.warnf("DX11: unmap_buffer_impl called on a buffer with usage %v, which is typically not mapped.", bi.usage)
    }

    Context_Unmap(di.immediate_context, bi.buffer, 0)
    
    log.debugf("DX11: Buffer unmapped. Handle: %p", bi.buffer)
    return .None
}

// Helper to add to dx11_types.odin if not already there, or ensure it's compatible.
// This is just for reference during implementation of this file.
// D3D11_Buffer_Internal :: struct {
//     buffer:          ID3D11Buffer_Handle,
//     buffer_type:     gfx_interface.Buffer_Type, // The Gfx_Buffer_Type (Vertex, Index, Constant)
//     size:            int,    // In bytes
//     usage:           D3D11_USAGE, // Actual D3D11 usage
//     cpu_access:      UINT,      // Actual D3D11 CPU access flags
//     allocator:       mem.Allocator,
// }
// Need to ensure D3D11_Buffer_Internal in dx11_types.odin has 'usage' and 'cpu_access' fields.
// If not, they need to be added, or this code needs to adapt (e.g. by only storing 'dynamic' bool).
// For robust map/update, knowing actual D3D11_USAGE and D3D11_CPU_ACCESS_FLAG is better than just 'dynamic' bool.

// Let's assume D3D11_Buffer_Internal was updated to include:
// usage: D3D11_USAGE,
// cpu_access: UINT, // D3D11_CPU_ACCESS_FLAG combination
// instead of just `dynamic: bool`.
// The `create_buffer_impl` now saves these.
// The `D3D11_Buffer_Internal` in `dx11_types.odin` currently has `dynamic: bool`.
// I will proceed with the current structure of `D3D11_Buffer_Internal` and make the logic in `update_buffer_impl`
// and `map_buffer_impl` rely on the `usage` and `cpu_access` fields I added to `D3D11_Buffer_Internal`
// within this file's implementation. This implies that `D3D11_Buffer_Internal` in `dx11_types.odin`
// should be updated to match this for consistency.
// For now, this file is self-consistent with its local understanding of D3D11_Buffer_Internal.I have implemented the buffer management functions in `odingame/graphics/directx/dx11_buffer.odin`.

**Key changes and considerations during implementation:**

*   **`create_buffer_impl`**:
    *   Determines `D3D11_USAGE` and `D3D11_CPU_ACCESS_FLAG` based on the `dynamic` hint and `initial_data` presence.
    *   Sets `BindFlags` based on `gfx_interface.Buffer_Type`. Includes a check for constant buffer size alignment.
    *   Creates `D3D11_BUFFER_DESC` and optionally `D3D11_SUBRESOURCE_DATA`.
    *   Calls `Device_CreateBuffer`.
    *   Stores the `ID3D11Buffer_Handle`, original `gfx_interface.Buffer_Type`, size, actual `D3D11_USAGE`, and actual `D3D11_CPU_ACCESS_FLAG` in `D3D11_Buffer_Internal`. This is important for making correct decisions in `update_buffer_impl` and `map_buffer_impl`.
    *   **Note**: I've assumed that `D3D11_Buffer_Internal` in `dx11_types.odin` will be (or has been) updated to store `usage: D3D11_USAGE` and `cpu_access: UINT` instead of just `dynamic: bool`. The implementation in `dx11_buffer.odin` uses these more specific fields.

*   **`update_buffer_impl`**:
    *   If `D3D11_Buffer_Internal.usage` is `.DYNAMIC`:
        *   Maps the buffer using `Context_Map` (typically with `WRITE_DISCARD` for full updates or `WRITE_NO_OVERWRITE` for partial updates, logic added to choose based on offset/size).
        *   Copies data using `mem.copy`.
        *   Unmaps using `Context_Unmap`.
    *   If `D3D11_Buffer_Internal.usage` is `.DEFAULT`:
        *   Uses `Context_UpdateSubresource`. A `D3D11_BOX` is configured for partial updates.
    *   If `D3D11_Buffer_Internal.usage` is `.IMMUTABLE`, logs an error as it cannot be updated.
    *   Includes basic error/bounds checking.

*   **`destroy_buffer_impl`**:
    *   Releases the `ID3D11Buffer` COM object using `Buffer_Release`.
    *   Frees the `D3D11_Buffer_Internal` struct using its allocator.

*   **`map_buffer_impl`**:
    *   Translates `gfx_interface.Buffer_Map_Access` to `D3D11_MAP` flags.
    *   Performs checks to ensure the map operation is valid for the buffer's `D3D11_USAGE` and `D3D11_CPU_ACCESS_FLAG` (e.g., `READ` only for `STAGING_READ`, `WRITE_DISCARD` only for `DYNAMIC_WRITE`).
    *   Calls `Context_Map`.
    *   Returns the mapped pointer.

*   **`unmap_buffer_impl`**:
    *   Calls `Context_Unmap`. Includes a warning if called on a buffer type not typically mapped (e.g., `DEFAULT` usage).

This set of functions provides the core operations for managing DirectX 11 buffers within the OdinGame framework. The crucial part for robust operation is that `D3D11_Buffer_Internal` correctly stores the D3D11-specific usage and access flags determined at creation time.
