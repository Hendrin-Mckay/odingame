package directx11

import "../gfx_interface"
import "../../common" 
import "./dx11_types"    // For D3D11_Device_Internal, get_device_internal
import "./dx11_bindings" // For ID3D11DeviceContextVTable and HRESULT checks
import "core:log"

// --- Drawing ---

draw_impl :: proc(
    device_handle: gfx_interface.Gfx_Device,
    vertex_count: i32,
    first_vertex: i32 = 0,
    instance_count: i32 = 1,
    first_instance: i32 = 0,
) -> common.Engine_Error {
    // log.debugf("DX11: draw_impl called. Vertices: %d, First: %d, Instances: %d, FirstInstance: %d", 
    //             vertex_count, first_vertex, instance_count, first_instance) // Optional

    di := get_device_internal(device_handle)
    if di == nil {
        log.error("DX11: draw_impl: Invalid Gfx_Device.")
        return .Invalid_Handle
    }
    if di.immediate_context == nil {
        log.error("DX11: draw_impl: Immediate context is nil.")
        return .Invalid_Handle
    }

    if vertex_count <= 0 {
        log.warn("DX11: draw_impl: vertex_count is zero or negative, skipping draw call.")
        return .None // Or Invalid_Parameter, depending on strictness
    }
    if instance_count <= 0 {
        log.warn("DX11: draw_impl: instance_count is zero or negative, skipping draw call.")
        return .None // Or Invalid_Parameter
    }

    context_vtable := (^ID3D11DeviceContextVTable)(di.immediate_context)^

    if instance_count == 1 && first_instance == 0 { // Ensure first_instance is 0 if not instanced
        context_vtable.Draw(
            di.immediate_context,
            UINT(vertex_count),
            UINT(first_vertex),
        )
    } else {
        context_vtable.DrawInstanced( // This function is not explicitly in my simplified VTable, assume it exists or use a more complete one
            di.immediate_context,
            UINT(vertex_count),    // VertexCountPerInstance
            UINT(instance_count),  // InstanceCount
            UINT(first_vertex),    // StartVertexLocation
            UINT(first_instance),  // StartInstanceLocation
        )
        // DrawInstanced is assumed to be present in the VTable (dx11_bindings.odin)
    }
    // No HRESULT is returned by Draw or DrawInstanced. Errors are typically caught by the debug layer
    // or by device removed status on Present.

    return .None
}

draw_indexed_impl :: proc(
    device_handle: gfx_interface.Gfx_Device,
    index_count: i32,
    first_index: i32 = 0,
    base_vertex: i32 = 0,
    instance_count: i32 = 1,
    first_instance: i32 = 0,
) -> common.Engine_Error {
    // log.debugf("DX11: draw_indexed_impl: Indices: %d, FirstIndex: %d, BaseVertex: %d, Instances: %d, FirstInstance: %d",
    //             index_count, first_index, base_vertex, instance_count, first_instance) // Optional

    di := get_device_internal(device_handle)
    if di == nil {
        log.error("DX11: draw_indexed_impl: Invalid Gfx_Device.")
        return .Invalid_Handle
    }
    if di.immediate_context == nil {
        log.error("DX11: draw_indexed_impl: Immediate context is nil.")
        return .Invalid_Handle
    }

    if index_count <= 0 {
        log.warn("DX11: draw_indexed_impl: index_count is zero or negative, skipping draw call.")
        return .None // Or Invalid_Parameter
    }
     if instance_count <= 0 {
        log.warn("DX11: draw_indexed_impl: instance_count is zero or negative, skipping draw call.")
        return .None // Or Invalid_Parameter
    }

    context_vtable := (^ID3D11DeviceContextVTable)(di.immediate_context)^

    if instance_count == 1 && first_instance == 0 {
        context_vtable.DrawIndexed(
            di.immediate_context,
            UINT(index_count),
            UINT(first_index),
            INT(base_vertex), // Note: base_vertex is INT
        )
    } else {
        // DrawIndexedInstanced is assumed to be present in the VTable (dx11_bindings.odin)
        context_vtable.DrawIndexedInstanced( 
            di.immediate_context,
            UINT(index_count),     // IndexCountPerInstance
            UINT(instance_count),  // InstanceCount
            UINT(first_index),     // StartIndexLocation
            INT(base_vertex),      // BaseVertexLocation
            UINT(first_instance),  // StartInstanceLocation
        )
    }
    // No HRESULT returned by these draw calls either.

    return .None
}
