package opengl

import gl "vendor:OpenGL/gl"
import common "../../common"
import gfx_types "../types"
import gfx_interface "../gfx_interface"
import gl_types "./gl_types" // For Gl_Device_Variant, Gl_Shader_Variant, Gl_Pipeline_Internal
import gl_shader "./gl_shader" // For Gl_Shader_Internal if variant points to it directly (or defined in gl_types)

import "core:log"
import "core:mem"
import "core:strings"

// Gl_Pipeline_Internal stores OpenGL specific pipeline data (program ID)
// This should be defined in gl_types.odin ideally, but placing here for self-containment if gl_types isn't created yet.
// Subtask mentions: Define `Gl_Pipeline_Internal :: struct { program_id: u32, main_allocator: ^rawptr }`
// Using allocator: mem.Allocator from device internal struct.
Gl_Pipeline_Internal :: struct {
    program_id: u32,
    allocator:  mem.Allocator, 
}

gl_create_pipeline_impl :: proc(
    device: gfx_interface.Gfx_Device, 
    desc: ^gfx_types.Gfx_Pipeline_Desc,
) -> (gfx_interface.Gfx_Pipeline, common.Engine_Error) {
    
    log.debug("OpenGL: gl_create_pipeline_impl called.")

    // Extract Gl_Device_Internal from Gfx_Device variant
    // Assuming Gl_Device_Variant is defined in gl_types and points to Gl_Device_Internal
    gl_device_internal, ok := device.variant.(gl_types.Gl_Device_Variant)
    if !ok || gl_device_internal == nil {
        log.error("OpenGL: Invalid Gfx_Device variant for pipeline creation.")
        return gfx_interface.Gfx_Pipeline{}, .Invalid_Handle
    }

    if desc == nil {
        log.error("OpenGL: Gfx_Pipeline_Desc is nil.")
        return gfx_interface.Gfx_Pipeline{}, .Invalid_Parameter
    }

    // Get GL Shader IDs from Gfx_Shader variants
    // Assuming Gl_Shader_Variant is defined in gl_types and points to Gl_Shader_Internal from gl_shader package
    vs_variant, vs_ok := desc.vertex_shader.variant.(gl_types.Gl_Shader_Variant)
    if !vs_ok || vs_variant == nil || vs_variant.shader_id == 0 {
        log.error("OpenGL: Invalid or missing vertex shader for pipeline creation.")
        return gfx_interface.Gfx_Pipeline{}, .Invalid_Parameter
    }
    vs_id := vs_variant.shader_id

    ps_id: u32 = 0 // Pixel shader can be optional in some engines, but GL link needs it if used.
    if desc.pixel_shader.variant != nil {
        ps_variant, ps_ok := desc.pixel_shader.variant.(gl_types.Gl_Shader_Variant)
        if !ps_ok || ps_variant == nil || ps_variant.shader_id == 0 {
            log.error("OpenGL: Invalid pixel shader provided for pipeline creation.")
            // Allow pipeline creation without pixel shader if that's a supported use case by engine?
            // For now, assume if present, it must be valid. If not present, ps_id remains 0.
            // GL linking will fail if VS expects PS output and PS is not there.
            return gfx_interface.Gfx_Pipeline{}, .Invalid_Parameter
        }
        ps_id = ps_variant.shader_id
    } else {
        // This case (nil pixel shader) might be valid for depth-only passes or compute.
        // For simplicity, current GL graphics pipeline usually requires VS and PS.
        // Let's assume for now a graphics pipeline always needs a pixel shader.
        // If not, the linking logic might need adjustment or this error is too strict.
        log.error("OpenGL: Pixel shader is nil. Required for standard graphics pipeline.")
        return gfx_interface.Gfx_Pipeline{}, .Invalid_Parameter
    }


    // Create GL Program
    program_id := gl.CreateProgram()
    if program_id == 0 {
        log.error("OpenGL: gl.CreateProgram() failed.")
        return gfx_interface.Gfx_Pipeline{}, .Graphics_Resource_Creation_Failed
    }

    // Attach Shaders
    gl.AttachShader(program_id, vs_id)
    if ps_id != 0 { // Only attach if a valid pixel shader ID was obtained
        gl.AttachShader(program_id, ps_id)
    }
    // log.debugf("OpenGL: Attached VS ID %d and PS ID %d to Program ID %d", vs_id, ps_id, program_id)


    // Link Program
    gl.LinkProgram(program_id)

    // Check Link Status
    link_status: i32
    gl.GetProgramiv(program_id, gl.LINK_STATUS, &link_status)
    if link_status == gl.FALSE {
        info_log_length: i32
        gl.GetProgramiv(program_id, gl.INFO_LOG_LENGTH, &info_log_length)
        
        info_log_buffer: [dynamic]u8
        if info_log_length > 0 {
            info_log_buffer = make([dynamic]u8, info_log_length, context.temp_allocator)
            defer delete(info_log_buffer)
            gl.GetProgramInfoLog(program_id, info_log_length, nil, rawptr(&info_log_buffer[0]))
            log.errorf("OpenGL: gl.LinkProgram() failed for Program ID %d. Info Log: %s", program_id, string(info_log_buffer))
        } else {
            log.errorf("OpenGL: gl.LinkProgram() failed for Program ID %d. No info log.", program_id)
        }

        gl.DetachShader(program_id, vs_id)
        if ps_id != 0 { gl.DetachShader(program_id, ps_id) }
        gl.DeleteProgram(program_id)
        return gfx_interface.Gfx_Pipeline{}, .Pipeline_Creation_Failed
    }
    log.infof("OpenGL: Program ID %d linked successfully.", program_id)

    // Create Gl_Pipeline_Internal struct
    pipeline_internal := new(Gl_Pipeline_Internal, gl_device_internal.allocator)
    pipeline_internal.program_id = program_id
    pipeline_internal.allocator = gl_device_internal.allocator
    
    // Return Gfx_Pipeline
    return gfx_interface.Gfx_Pipeline{variant = gl_types.Gl_Pipeline_Variant(pipeline_internal)}, .None
}

gl_destroy_pipeline_impl :: proc(pipeline: gfx_interface.Gfx_Pipeline) -> common.Engine_Error {
    log.debug("OpenGL: gl_destroy_pipeline_impl called.")
    
    gl_pipeline_internal, ok := pipeline.variant.(gl_types.Gl_Pipeline_Variant)
    if !ok || gl_pipeline_internal == nil {
        log.warn("OpenGL: Invalid Gfx_Pipeline variant for destruction.")
        return .Invalid_Handle
    }

    if gl_pipeline_internal.program_id != 0 {
        gl.DeleteProgram(gl_pipeline_internal.program_id)
        log.infof("OpenGL: Program ID %d deleted.", gl_pipeline_internal.program_id)
    }

    // Free the Gl_Pipeline_Internal struct itself
    // Ensure allocator is valid before freeing
    if gl_pipeline_internal.allocator.proc != nil {
         free(gl_pipeline_internal, gl_pipeline_internal.allocator)
    } else {
        log.error("OpenGL: Allocator for Gl_Pipeline_Internal is nil, cannot free.")
        // This might indicate a double free or an issue during creation.
        // For now, just log it. The program_id is deleted.
    }
    
    return .None
}
