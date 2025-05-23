package vulkan

import vk "vendor:vulkan"
import "../../common"
import "../gfx_interface"
import "./vk_types"
import "./vk_helpers" 
import "./vk_buffer"  
import "core:log"
import "core:mem"
import "core:unsafe" // For size_of in staging buffer calculations

// gfx_format_to_vk_format translates Gfx_Texture_Format to vk.Format.
@(private="file")
gfx_format_to_vk_format :: proc(format_gfx: gfx_interface.Texture_Format) -> (vk_format: vk.Format, err: common.Engine_Error) {
	#partial switch format_gfx {
	case .R8:
		return vk.Format.R8_UNORM, .None
	case .RGB8: // Often maps to R8G8B8_UNORM or R8G8B8_SRGB. Assuming UNORM.
		return vk.Format.R8G8B8_UNORM, .None 
	case .RGBA8:
		return vk.Format.R8G8B8A8_UNORM, .None
	case .SRGBA8: // sRGB version of RGBA8
		return vk.Format.R8G8B8A8_SRGB, .None
	case .Depth24_Stencil8:
		return vk.Format.D24_UNORM_S8_UINT, .None
	// Add other formats as they become supported by gfx_interface and needed
	}
	log.errorf("gfx_format_to_vk_format: Unsupported Gfx_Texture_Format: %v", format_gfx)
	return vk.Format.UNDEFINED, common.Engine_Error.Unsupported_Format
}

// gfx_usage_to_vk_image_usage translates Gfx_Texture_Usage to vk.ImageUsageFlags.
@(private="file")
gfx_usage_to_vk_image_usage :: proc(usage_gfx: gfx_interface.Texture_Usage, data_provided: bool) -> (vk_usage: vk.ImageUsageFlags, err: common.Engine_Error) {
	vk_img_usage: vk.ImageUsageFlags = {}
	
	if len(usage_gfx) == 0 {
		log.error("gfx_usage_to_vk_image_usage: Texture_Usage cannot be empty.")
		return {}, common.Engine_Error.Invalid_Parameter
	}

	if .Sampled in usage_gfx {
		vk_img_usage |= {.SAMPLED_BIT}
	}
	if .Color_Attachment in usage_gfx {
		vk_img_usage |= {.COLOR_ATTACHMENT_BIT}
	}
	if .Depth_Stencil_Attachment in usage_gfx {
		vk_img_usage |= {.DEPTH_STENCIL_ATTACHMENT_BIT}
	}
	if .Storage in usage_gfx { // Assuming gfx_interface.Texture_Usage might get a .Storage flag
		vk_img_usage |= {.STORAGE_BIT}
	}

	// Necessary for uploading data or updating the texture
	if data_provided || true { // Assume most textures might be updated or need initial data copy
		vk_img_usage |= {.TRANSFER_DST_BIT}
	}
    // Necessary if the texture might be a source of a transfer (e.g. mipmap generation from base level, screenshot)
    // or if it might be updated after creation.
    // For now, assume if it's sampled or a color/depth attachment, it might also be a transfer source/destination at some point.
    // This is a broad assumption; more specific usage patterns could refine this.
	if .Sampled in usage_gfx || .Color_Attachment in usage_gfx || .Depth_Stencil_Attachment in usage_gfx {
        vk_img_usage |= {.TRANSFER_SRC_BIT} // For potential mipmapping or copying from
        // vk_img_usage |= {.TRANSFER_DST_BIT} // Already added above if data_provided or true
	}


	if len(vk_img_usage) == 0 {
		log.warnf("gfx_usage_to_vk_image_usage: No Vulkan usage flags mapped for Gfx_Texture_Usage: %v. This is likely an error.", usage_gfx)
        // Fallback to a common default or error out. For now, error.
		return {}, common.Engine_Error.Invalid_Parameter 
	}

	return vk_img_usage, .None
}

// vk_bytes_per_pixel_for_format returns the number of bytes per pixel for a given vk.Format.
@(private="file")
vk_bytes_per_pixel_for_format :: proc(format: vk.Format) -> (u32, bool) {
	#partial switch format {
		case .R8_UNORM, .R8_SNORM, .R8_UINT, .R8_SINT: return 1, true
		case .R8G8_UNORM, .R8G8_SNORM, .R8G8_UINT, .R8G8_SINT: return 2, true
		case .R8G8B8_UNORM, .R8G8B8_SRGB: return 3, true 
		case .B8G8R8_UNORM, .B8G8R8_SRGB: return 3, true 
		case .R8G8B8A8_UNORM, .R8G8B8A8_SNORM, .R8G8B8A8_UINT, .R8G8B8A8_SINT, .R8G8B8A8_SRGB: return 4, true
		case .B8G8R8A8_UNORM, .B8G8R8A8_SRGB: return 4, true
        case .D24_UNORM_S8_UINT: return 4, true 
        case .D32_SFLOAT: return 4, true
        case .D32_SFLOAT_S8_UINT: return 5, true // Or 8 if padded, depends on implementation details
	}
	log.errorf("vk_bytes_per_pixel_for_format: Unhandled format %v for bpp calculation.", format)
	return 0, false
}


vk_create_texture_internal :: proc(
	gfx_device_handle: gfx_interface.Gfx_Device, 
	width_in: int, 
	height_in: int, 
	format_gfx: gfx_interface.Texture_Format, 
	usage_gfx: gfx_interface.Texture_Usage, 
	data: rawptr,
) -> (gfx_interface.Gfx_Texture, common.Engine_Error) {

	if width_in <= 0 || height_in <= 0 { return {}, common.Engine_Error.Invalid_Parameter }
	width  := u32(width_in)
	height := u32(height_in)

	vk_dev_variant, ok_dev := gfx_device_handle.variant.(vk_types.Vk_Device_Variant)
	if !ok_dev || vk_dev_variant == nil { return {}, common.Engine_Error.Invalid_Handle }
	vk_dev_internal := vk_dev_variant
	
	logical_device  := vk_dev_internal.logical_device
	allocator       := vk_dev_internal.allocator
	p_vk_allocator: ^vk.AllocationCallbacks = nil

	vk_fmt, fmt_err := gfx_format_to_vk_format(format_gfx)
	if fmt_err != .None { return {}, fmt_err }

	vk_img_usage, usage_err := gfx_usage_to_vk_image_usage(usage_gfx, data != nil)
	if usage_err != .None { return {}, usage_err }
	
	new_image, new_image_memory, create_img_err := vk_helpers.vk_create_image_internal(
		vk_dev_internal, width, height, 1, vk_fmt, .OPTIMAL, vk_img_usage, {.DEVICE_LOCAL_BIT},
	)
	if create_img_err != .None { return {}, create_img_err }

	current_image_layout := vk.ImageLayout.UNDEFINED

	if data != nil {
		bpp, bpp_ok := vk_bytes_per_pixel_for_format(vk_fmt)
		if !bpp_ok {
			log.errorf("Failed to get bytes per pixel for format %v during texture data upload.", vk_fmt)
			vk.DestroyImage(logical_device, new_image, p_vk_allocator)
			vk.FreeMemory(logical_device, new_image_memory, p_vk_allocator)
			return {}, common.Engine_Error.Unsupported_Format
		}
		staging_buffer_size := u64(bpp) * u64(width) * u64(height)
		
		staging_buffer_gfx, stage_err := vk_buffer.vk_create_buffer_internal(
			gfx_device_handle, .Transfer_Src, int(staging_buffer_size), data, true,
		)
		if stage_err != .None {
			vk.DestroyImage(logical_device, new_image, p_vk_allocator)
			vk.FreeMemory(logical_device, new_image_memory, p_vk_allocator)
			return {}, stage_err
		}
        staging_buffer_vk_internal, ok_vk_buf := staging_buffer_gfx.variant.(^vk_types.Vk_Buffer_Internal)
        if !ok_vk_buf || staging_buffer_vk_internal == nil {
            vk.DestroyImage(logical_device, new_image, p_vk_allocator)
            vk.FreeMemory(logical_device, new_image_memory, p_vk_allocator)
            vk_buffer.vk_destroy_buffer_internal(staging_buffer_gfx)
            return {}, common.Engine_Error.Invalid_Handle
        }

		trans_err_dst := vk_helpers.vk_transition_image_layout_internal(
			vk_dev_internal, new_image, vk_fmt, current_image_layout, .TRANSFER_DST_OPTIMAL, 1,
		)
		if trans_err_dst != .None {
            vk_buffer.vk_destroy_buffer_internal(staging_buffer_gfx)
			vk.DestroyImage(logical_device, new_image, p_vk_allocator)
			vk.FreeMemory(logical_device, new_image_memory, p_vk_allocator)
			return {}, trans_err_dst
		}
		current_image_layout = .TRANSFER_DST_OPTIMAL

		copy_err := vk_helpers.vk_copy_buffer_to_image_internal(
			vk_dev_internal, staging_buffer_vk_internal.buffer, new_image, width, height, 1,
		)
		vk_buffer.vk_destroy_buffer_internal(staging_buffer_gfx) 
		if copy_err != .None {
			vk.DestroyImage(logical_device, new_image, p_vk_allocator)
			vk.FreeMemory(logical_device, new_image_memory, p_vk_allocator)
			return {}, copy_err
		}
	}
    
	target_layout := vk.ImageLayout.SHADER_READ_ONLY_OPTIMAL
	if .Color_Attachment in usage_gfx { target_layout = .COLOR_ATTACHMENT_OPTIMAL } 
    else if .Depth_Stencil_Attachment in usage_gfx { target_layout = .DEPTH_STENCIL_ATTACHMENT_OPTIMAL }
    else if .Storage in usage_gfx { target_layout = .GENERAL }

	if current_image_layout != target_layout {
		trans_err_final := vk_helpers.vk_transition_image_layout_internal(
			vk_dev_internal, new_image, vk_fmt, current_image_layout, target_layout, 1,
		)
		if trans_err_final != .None {
			vk.DestroyImage(logical_device, new_image, p_vk_allocator)
			vk.FreeMemory(logical_device, new_image_memory, p_vk_allocator)
			return {}, trans_err_final
		}
		current_image_layout = target_layout
	}
    
	aspect_mask: vk.ImageAspectFlags = {.COLOR_BIT}
	if .Depth_Stencil_Attachment in usage_gfx {
		aspect_mask = {.DEPTH_BIT}
		if vk_fmt == .D24_UNORM_S8_UINT || vk_fmt == .D32_SFLOAT_S8_UINT { aspect_mask |= {.STENCIL_BIT} }
	}

	new_image_view, view_err := vk_helpers.vk_create_image_view_internal(logical_device, new_image, vk_fmt, aspect_mask)
	if view_err != .None {
		vk.DestroyImage(logical_device, new_image, p_vk_allocator)
		vk.FreeMemory(logical_device, new_image_memory, p_vk_allocator)
		return {}, view_err
	}

	new_sampler, sampler_err := vk_helpers.vk_create_sampler_internal(logical_device, vk_dev_internal.physical_device_info)
	if sampler_err != .None {
		vk.DestroyImageView(logical_device, new_image_view, p_vk_allocator)
		vk.DestroyImage(logical_device, new_image, p_vk_allocator)
		vk.FreeMemory(logical_device, new_image_memory, p_vk_allocator)
		return {}, sampler_err
	}
	
	vk_texture_internal := new(vk_types.Vk_Texture_Internal, allocator)
	vk_texture_internal.image            = new_image
	vk_texture_internal.image_view       = new_image_view
	vk_texture_internal.memory           = new_image_memory
	vk_texture_internal.sampler          = new_sampler
	vk_texture_internal.width            = width
	vk_texture_internal.height           = height
	vk_texture_internal.format           = vk_fmt
	vk_texture_internal.usage            = vk_img_usage
    vk_texture_internal.current_layout   = current_image_layout
	vk_texture_internal.device_ref       = vk_dev_internal
	
	return gfx_interface.Gfx_Texture{variant = vk_texture_internal}, .None
}

vk_destroy_texture_internal :: proc(gfx_device_handle: gfx_interface.Gfx_Device, texture: gfx_interface.Gfx_Texture) {
	tex_internal_ptr, ok_tex := texture.variant.(^vk_types.Vk_Texture_Internal)
	if !ok_tex || tex_internal_ptr == nil {
		log.errorf("vk_destroy_texture_internal: Invalid Gfx_Texture variant. Type: %T", texture.variant)
		return
	}
	
	if tex_internal_ptr.device_ref == nil || tex_internal_ptr.device_ref.logical_device == vk.NULL_HANDLE {
		log.error("vk_destroy_texture_internal: Cannot destroy texture, logical device reference is nil.")
		return
	}
	logical_device := tex_internal_ptr.device_ref.logical_device
	allocator      := tex_internal_ptr.device_ref.allocator 
	p_vk_allocator: ^vk.AllocationCallbacks = nil

	if tex_internal_ptr.sampler != vk.NULL_HANDLE { vk.DestroySampler(logical_device, tex_internal_ptr.sampler, p_vk_allocator) }
	if tex_internal_ptr.image_view != vk.NULL_HANDLE { vk.DestroyImageView(logical_device, tex_internal_ptr.image_view, p_vk_allocator) }
	if tex_internal_ptr.image != vk.NULL_HANDLE { vk.DestroyImage(logical_device, tex_internal_ptr.image, p_vk_allocator) }
	if tex_internal_ptr.memory != vk.NULL_HANDLE { vk.FreeMemory(logical_device, tex_internal_ptr.memory, p_vk_allocator) }
	
	free(tex_internal_ptr, allocator)
}

vk_update_texture_internal :: proc(
	gfx_device_handle: gfx_interface.Gfx_Device, 
	texture_gfx: gfx_interface.Gfx_Texture, 
	x_in: int, y_in: int, 
	width_in: int, height_in: int, 
	data: rawptr,
) -> common.Engine_Error {
	
	tex_internal, ok_tex := texture_gfx.variant.(^vk_types.Vk_Texture_Internal)
	if !ok_tex || tex_internal == nil { return common.Engine_Error.Invalid_Handle }
	if data == nil { return common.Engine_Error.Invalid_Parameter }
	if width_in <= 0 || height_in <= 0 { return common.Engine_Error.Invalid_Parameter }
    if x_in < 0 || y_in < 0 || x_in + width_in > int(tex_internal.width) || y_in + height_in > int(tex_internal.height) {
        return common.Engine_Error.Invalid_Parameter 
    }

	width  := u32(width_in)
	height := u32(height_in)
    x := i32(x_in) 
    y := i32(y_in) 
	
	vk_dev_internal := tex_internal.device_ref
	logical_device  := vk_dev_internal.logical_device
	
	bpp, bpp_ok := vk_bytes_per_pixel_for_format(tex_internal.format)
	if !bpp_ok { return common.Engine_Error.Unsupported_Format }
	staging_buffer_size := u64(bpp) * u64(width) * u64(height)

	staging_buffer_gfx, stage_err := vk_buffer.vk_create_buffer_internal(
		gfx_device_handle, .Transfer_Src, int(staging_buffer_size), data, true,
	)
	if stage_err != .None { return stage_err }
    staging_buffer_vk_internal, ok_vk_buf := staging_buffer_gfx.variant.(^vk_types.Vk_Buffer_Internal)
    if !ok_vk_buf || staging_buffer_vk_internal == nil {
        vk_buffer.vk_destroy_buffer_internal(staging_buffer_gfx)
        return common.Engine_Error.Invalid_Handle
    }

	original_layout := tex_internal.current_layout
	
	trans_err_dst := vk_helpers.vk_transition_image_layout_internal(
		vk_dev_internal, tex_internal.image, tex_internal.format, 
		original_layout, .TRANSFER_DST_OPTIMAL, 1,
	)
	if trans_err_dst != .None {
		vk_buffer.vk_destroy_buffer_internal(staging_buffer_gfx)
		return trans_err_dst
	}
	
	copy_region := vk.BufferImageCopy{
		bufferOffset = 0,
		bufferRowLength = 0, bufferImageHeight = 0,
		imageSubresource = {aspectMask = {.COLOR_BIT}, mipLevel = 0, baseArrayLayer = 0, layerCount = 1},
		imageOffset = {x, y, 0},
		imageExtent = {width, height, 1},
	}
	
	cmd_buffer, begin_err := vk_helpers.vk_begin_single_time_commands_internal(vk_dev_internal)
	if begin_err != .None {
		vk_buffer.vk_destroy_buffer_internal(staging_buffer_gfx)
		// Attempt to transition back if possible, though state is uncertain
		// vk_helpers.vk_transition_image_layout_internal(vk_dev_internal, tex_internal.image, tex_internal.format, .TRANSFER_DST_OPTIMAL, original_layout, 1)
		// No need to update tex_internal.current_layout here as it wasn't changed yet.
		return begin_err
	}
	vk.CmdCopyBufferToImage(cmd_buffer, staging_buffer_vk_internal.buffer, tex_internal.image, .TRANSFER_DST_OPTIMAL, 1, &copy_region)
	end_err := vk_helpers.vk_end_single_time_commands_internal(vk_dev_internal, cmd_buffer)
    vk_buffer.vk_destroy_buffer_internal(staging_buffer_gfx) 

	if end_err != .None {
        log.errorf("Failed to submit copy command for texture update. Image layout is TRANSFER_DST_OPTIMAL. Error: %v", end_err)
        tex_internal.current_layout = .TRANSFER_DST_OPTIMAL // Stuck in this layout
		return end_err
	}
    tex_internal.current_layout = .TRANSFER_DST_OPTIMAL // Set after successful copy command submission

	trans_err_final := vk_helpers.vk_transition_image_layout_internal(
		vk_dev_internal, tex_internal.image, tex_internal.format, 
		tex_internal.current_layout, original_layout, 1, // Transition from current (TRANSFER_DST) back to original
	)
    if trans_err_final != .None {
        log.errorf("Failed to transition texture back to original layout %v after update. Image layout is now %v. Error: %v", original_layout, tex_internal.current_layout, trans_err_final)
        // current_layout is already TRANSFER_DST_OPTIMAL, no change if this fails
        return trans_err_final
    }
    tex_internal.current_layout = original_layout
	return .None
}

vk_get_texture_width_internal :: proc(texture: gfx_interface.Gfx_Texture) -> int {
	if tex_internal, ok := texture.variant.(^vk_types.Vk_Texture_Internal); ok && tex_internal != nil {
		return int(tex_internal.width)
	}
	return 0
}

vk_get_texture_height_internal :: proc(texture: gfx_interface.Gfx_Texture) -> int {
	if tex_internal, ok := texture.variant.(^vk_types.Vk_Texture_Internal); ok && tex_internal != nil {
		return int(tex_internal.height)
	}
	return 0
}
