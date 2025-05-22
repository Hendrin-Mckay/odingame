package vulkan

import vk "vendor:vulkan"
import "core:log"
import "core:mem"
// import "core:fmt" // Might be needed later for error messages

import "../gfx_interface" // For Gfx_Device, Gfx_Texture, Texture_Format, Texture_Usage, Gfx_Error
import "./vk_types"       // For Vk_Device_Internal, Vk_Texture_Internal
import "./vk_helpers"     // For vk_create_image_internal, vk_create_image_view_internal, vk_create_sampler_internal etc.
import "./vk_buffer"      // For vk_create_buffer_internal (for staging buffer)


// --- Helper Functions (Stubs/Basic Implementations for now) ---

// gfx_format_to_vk_format translates Gfx_Texture_Format to vk.Format.
gfx_format_to_vk_format :: proc(format_gfx: gfx_interface.Texture_Format) -> (vk_format: vk.Format, err: gfx_interface.Gfx_Error) {
	#partial switch format_gfx {
		case .Undefined:
			log.error("gfx_format_to_vk_format: Undefined Gfx_Texture_Format provided.")
			return vk.Format.UNDEFINED, .Invalid_Handle // Or a more specific error
		case .R8_UNORM:
			return vk.Format.R8_UNORM, .None
		case .RG8_UNORM:
			return vk.Format.R8G8_UNORM, .None
		case .RGBA8_UNORM:
			return vk.Format.R8G8B8A8_UNORM, .None
		case .BGRA8_UNORM:
			return vk.Format.B8G8R8A8_UNORM, .None
		case .RGBA8_SRGB:
			return vk.Format.R8G8B8A8_SRGB, .None
		case .BGRA8_SRGB:
			return vk.Format.B8G8R8A8_SRGB, .None
		// TODO: Add other formats as they become supported by gfx_interface and needed
		// case .D32_SFLOAT:
		// 	return vk.Format.D32_SFLOAT, .None
		// case .D24_UNORM_S8_UINT:
		// 	return vk.Format.D24_UNORM_S8_UINT, .None
	}
	log.errorf("gfx_format_to_vk_format: Unsupported Gfx_Texture_Format: %v", format_gfx)
	return vk.Format.UNDEFINED, .Not_Implemented // Or .Invalid_Parameter
}

// gfx_usage_to_vk_image_usage translates Gfx_Texture_Usage to vk.ImageUsageFlags.
gfx_usage_to_vk_image_usage :: proc(usage_gfx: gfx_interface.Texture_Usage, has_initial_data: bool) -> (vk_usage: vk.ImageUsageFlags, err: gfx_interface.Gfx_Error) {
	vk_usage_flags: vk.ImageUsageFlags = {}
	
	if usage_gfx == .None {
		log.error("gfx_usage_to_vk_image_usage: Texture_Usage cannot be .None if creating a texture.")
		return {}, .Invalid_Handle // Or .Invalid_Parameter
	}

	if .Sampled in usage_gfx {
		vk_usage_flags |= {.SAMPLED_BIT}
	}
	if .Color_Attachment in usage_gfx {
		vk_usage_flags |= {.COLOR_ATTACHMENT_BIT}
	}
	if .Depth_Stencil_Attachment in usage_gfx {
		vk_usage_flags |= {.DEPTH_STENCIL_ATTACHMENT_BIT}
	}
	// Add other usage flags as needed, e.g. INPUT_ATTACHMENT_BIT, STORAGE_BIT

	// If data is provided, or if it's expected the texture might be updated later,
	// it needs to be a transfer destination.
	// For simplicity, always adding TRANSFER_DST_BIT for now if it's not purely transient.
	// A more refined approach might check if the texture is truly immutable.
	if has_initial_data || true { // Assuming most textures might be updated or were initialized
		vk_usage_flags |= {.TRANSFER_DST_BIT}
	}
    // If it's a source for copies (e.g. screenshots, blitting)
    // vk_usage_flags |= {.TRANSFER_SRC_BIT}


	if len(vk_usage_flags) == 0 {
		log.warnf("gfx_usage_to_vk_image_usage: No Vulkan usage flags mapped for Gfx_Texture_Usage: %v. Defaulting to SAMPLED.", usage_gfx)
		// Defaulting to SAMPLED might be problematic. Consider returning an error.
		// For now, to ensure it's not empty, but this might hide issues.
		vk_usage_flags |= {.SAMPLED_BIT} 
		// return {}, .Invalid_Parameter // Perhaps better to error if no clear usage.
	}

	return vk_usage_flags, .None
}

// vk_create_texture_internal is the main function for creating textures.
vk_create_texture_internal :: proc(
	device_gfx: gfx_interface.Gfx_Device, 
	width_in: int, 
	height_in: int, 
	format_gfx: gfx_interface.Texture_Format, 
	usage_gfx: gfx_interface.Texture_Usage, 
	data: rawptr, // Initial data, can be nil
) -> (gfx_interface.Gfx_Texture, gfx_interface.Gfx_Error) {

	// 1. Initial Setup
	if width_in <= 0 || height_in <= 0 {
		log.errorf("vk_create_texture_internal: Invalid texture dimensions: %dx%d.", width_in, height_in)
		return gfx_interface.Gfx_Texture{}, .Invalid_Handle // Or .Invalid_Parameter
	}
	width  := u32(width_in)
	height := u32(height_in)

	vk_dev_internal, ok_dev := device_gfx.variant.(Vk_Device_Variant)
	if !ok_dev || vk_dev_internal == nil {
		log.error("vk_create_texture_internal: Invalid Gfx_Device (not Vulkan or nil variant).")
		return gfx_interface.Gfx_Texture{}, .Invalid_Handle
	}
	logical_device := vk_dev_internal.logical_device
	allocator := vk_dev_internal.allocator // Use device's allocator

	// Translate GFX format to Vulkan format
	vk_fmt, fmt_err := gfx_format_to_vk_format(format_gfx)
	if fmt_err != .None {
		log.errorf("vk_create_texture_internal: Failed to translate Gfx_Texture_Format %v to vk.Format. Error: %v", format_gfx, fmt_err)
		return gfx_interface.Gfx_Texture{}, fmt_err
	}

	// Translate GFX usage to Vulkan image usage flags
	vk_img_usage, usage_err := gfx_usage_to_vk_image_usage(usage_gfx, data != nil)
	if usage_err != .None {
		log.errorf("vk_create_texture_internal: Failed to translate Gfx_Texture_Usage %v to vk.ImageUsageFlags. Error: %v", usage_gfx, usage_err)
		return gfx_interface.Gfx_Texture{}, usage_err
	}
	
	log.infof("vk_create_texture_internal: Begin texture creation. Dim: %dx%d, GfxFmt: %v (VkFmt: %v), GfxUsage: %v (VkUsage: %v), DataProvided: %v",
		width, height, format_gfx, vk_fmt, usage_gfx, vk_img_usage, data != nil)

	// Placeholder for actual Vulkan objects
	new_image: vk.Image = vk.NULL_HANDLE
	new_image: vk.Image = vk.NULL_HANDLE
	new_image_memory: vk.DeviceMemory = vk.NULL_HANDLE
	new_image_view: vk.ImageView = vk.NULL_HANDLE
	new_sampler: vk.Sampler = vk.NULL_HANDLE
	p_vk_allocator: ^vk.AllocationCallbacks = nil // Assuming nil for Vulkan allocators

	// 2. Image Creation
	// Assuming vk_helpers.vk_create_image_internal exists and handles physical_device_info.memory_properties internally.
	// It should return (vk.Image, vk.DeviceMemory, gfx_interface.Gfx_Error)
	create_img_err: gfx_interface.Gfx_Error
	new_image, new_image_memory, create_img_err = vk_helpers.vk_create_image_internal(
		logical_device,
		vk_dev_internal.physical_device_info.physical_device, // For memory properties query
		width, height, 1, // width, height, depth (1 for 2D)
		vk_fmt,
		vk.ImageTiling.OPTIMAL,
		vk_img_usage,
		{.DEVICE_LOCAL_BIT},
		allocator, // Pass allocator for internal allocations if any by helper
	)
	if create_img_err != .None {
		log.errorf("vk_create_texture_internal: Failed during image creation using vk_create_image_internal. Error: %v", create_img_err)
		// No resources to clean yet other than what vk_create_image_internal might have partially created and not cleaned.
		return gfx_interface.Gfx_Texture{}, create_img_err
	}
	log.debugf("vk_create_texture_internal: Image %p and memory %p created.", new_image, new_image_memory)

	// 3. Image View Creation
	// Assuming vk_helpers.vk_create_image_view_internal exists.
	// It should return (vk.ImageView, gfx_interface.Gfx_Error)
	// Aspect mask depends on format/usage. For color it's .COLOR_BIT.
	// For depth/stencil, it would be .DEPTH_BIT possibly with .STENCIL_BIT.
	aspect_mask: vk.ImageAspectFlags = {.COLOR_BIT} // Default to color
	if vk_img_usage == {.DEPTH_STENCIL_ATTACHMENT_BIT} { // Basic check, might need more robust one
		aspect_mask = {.DEPTH_BIT}
		// Check format for stencil component
		// if vk_fmt == .D24_UNORM_S8_UINT || vk_fmt == .D32_SFLOAT_S8_UINT { aspect_mask |= {.STENCIL_BIT} }
	}
	
	create_view_err: gfx_interface.Gfx_Error
	new_image_view, create_view_err = vk_helpers.vk_create_image_view_internal(
		logical_device, new_image, vk_fmt, aspect_mask, allocator, // Pass allocator if helper needs it
	)
	if create_view_err != .None {
		log.errorf("vk_create_texture_internal: Failed during image view creation. Error: %v", create_view_err)
		// Cleanup image and memory
		if new_image != vk.NULL_HANDLE { vk.DestroyImage(logical_device, new_image, p_vk_allocator) }
		if new_image_memory != vk.NULL_HANDLE { vk.FreeMemory(logical_device, new_image_memory, p_vk_allocator) }
		return gfx_interface.Gfx_Texture{}, create_view_err
	}
	log.debugf("vk_create_texture_internal: Image view %p created.", new_image_view)
	
	// 4. Sampler Creation
	// Assuming vk_helpers.vk_create_sampler_internal exists.
	// It should return (vk.Sampler, gfx_interface.Gfx_Error)
	create_sampler_err: gfx_interface.Gfx_Error
	new_sampler, create_sampler_err = vk_helpers.vk_create_sampler_internal(
		logical_device, 
		vk_dev_internal.physical_device_info, // Pass physical device info for properties like anisotropy limits
		allocator, // Pass allocator if helper needs it
	)
	if create_sampler_err != .None {
		log.errorf("vk_create_texture_internal: Failed during sampler creation. Error: %v", create_sampler_err)
		// Cleanup image, memory, and view
		if new_image_view != vk.NULL_HANDLE { vk.DestroyImageView(logical_device, new_image_view, p_vk_allocator) }
		if new_image != vk.NULL_HANDLE { vk.DestroyImage(logical_device, new_image, p_vk_allocator) }
		if new_image_memory != vk.NULL_HANDLE { vk.FreeMemory(logical_device, new_image_memory, p_vk_allocator) }
		return gfx_interface.Gfx_Texture{}, create_sampler_err
	}
	log.debugf("vk_create_texture_internal: Sampler %p created.", new_sampler)

	// 5. Data Upload (if data is not nil) - Placeholder for now
	//    - Create staging buffer
	//    - Transition image to TRANSFER_DST_OPTIMAL
	//    - Copy buffer to image
	//    - Transition image to SHADER_READ_ONLY_OPTIMAL (or other appropriate layout)
	//    - Destroy staging buffer

	// 6. Finalization
	vk_texture_internal := new(Vk_Texture_Internal, allocator)
	vk_texture_internal.image        = new_image
	vk_texture_internal.image_view   = new_image_view
	vk_texture_internal.memory       = new_image_memory
	vk_texture_internal.sampler      = new_sampler
	vk_texture_internal.width        = width
	vk_texture_internal.height       = height
	vk_texture_internal.format       = vk_fmt
	vk_texture_internal.usage        = vk_img_usage
	vk_texture_internal.device_ref   = vk_dev_internal
	// vk_texture_internal.allocator = allocator // If struct needs its own allocator reference

	log.infof("vk_create_texture_internal: Texture structure prepared (handles may be NULL if creation steps skipped). Image: %p, View: %p, Memory: %p, Sampler: %p",
		new_image, new_image_view, new_image_memory, new_sampler)

	// For now, returning with potentially NULL handles as steps are stubbed.
	// Proper error handling and resource cleanup will be added as helpers are implemented.
	return gfx_interface.Gfx_Texture{variant = vk_texture_internal}, .None 
}

// vk_bytes_per_pixel_for_format returns the number of bytes per pixel for a given vk.Format.
// This is a simplified helper and might need to be more comprehensive.
vk_bytes_per_pixel_for_format :: proc(format: vk.Format) -> (u32, bool) {
	#partial switch format {
		case .R8_UNORM, .R8_SNORM, .R8_UINT, .R8_SINT: return 1, true
		case .R8G8_UNORM, .R8G8_SNORM, .R8G8_UINT, .R8G8_SINT: return 2, true
		case .R8G8B8_UNORM, .R8G8B8_SRGB: return 3, true // Often padded to 4, but actual data might be 3
		case .B8G8R8_UNORM, .B8G8R8_SRGB: return 3, true // Often padded to 4
		case .R8G8B8A8_UNORM, .R8G8B8A8_SNORM, .R8G8B8A8_UINT, .R8G8B8A8_SINT, .R8G8B8A8_SRGB: return 4, true
		case .B8G8R8A8_UNORM, .B8G8R8A8_SRGB: return 4, true
		case .R16_SFLOAT: return 2, true
		case .R16G16_SFLOAT: return 4, true
		case .R16G16B16A16_SFLOAT: return 8, true
		case .R32_SFLOAT: return 4, true
		case .R32G32_SFLOAT: return 8, true
		case .R32G32B32A32_SFLOAT: return 16, true
		// Depth/stencil formats are more complex for simple bpp calculation
		// case .D32_SFLOAT: return 4, true
		// case .D24_UNORM_S8_UINT: return 4, true // (24 bits depth + 8 bits stencil)
	}
	log.errorf("vk_bytes_per_pixel_for_format: Unhandled or non-trivial format %v for bpp calculation.", format)
	return 0, false
}


// TODO: Implement helper functions (vk_create_image_internal, vk_create_image_view_internal, vk_create_sampler_internal, transition, copy etc.)
//       These might go into vk_helpers.odin

vk_destroy_texture_internal :: proc(texture_handle_gfx: gfx_interface.Gfx_Texture) {
	// Gfx_Texture.variant is expected to be ^Vk_Texture_Internal as per how it's set in vk_create_texture_internal.
	// However, the task description's example shows ^vk_types.Vk_Texture_Internal, which is more explicit if vk_types is imported with that name.
	// Given the file structure, it's likely just ^Vk_Texture_Internal.
	vk_texture_ptr, ok := texture_handle_gfx.variant.(^Vk_Texture_Internal)
	if !ok || vk_texture_ptr == nil {
		log.errorf("vk_destroy_texture_internal: Invalid Gfx_Texture variant or nil pointer. Type: %T. Handle: %v", 
			texture_handle_gfx.variant, texture_handle_gfx)
		return
	}

	// texture_internal := vk_texture_ptr^ // No need to dereference the whole struct, can use ptr directly
	
	if vk_texture_ptr.device_ref == nil {
		log.error("vk_destroy_texture_internal: device_ref in Vk_Texture_Internal is nil. Cannot get logical_device.")
		// Cannot proceed with Vulkan calls. Depending on design, might still try to free vk_texture_ptr if appropriate.
		// For now, returning as Vulkan resource cleanup is the primary goal.
		return 
	}
	logical_device := vk_texture_ptr.device_ref.logical_device
	p_vk_allocator: ^vk.AllocationCallbacks = nil // Assuming nil for Vulkan allocators

	log.infof("Destroying Vulkan texture... Image: %p, View: %p, Sampler: %p, Memory: %p", 
			  vk_texture_ptr.image, vk_texture_ptr.image_view, vk_texture_ptr.sampler, vk_texture_ptr.memory)

	// Destroy resources in reverse order of creation
	// 1. Sampler
	if vk_texture_ptr.sampler != vk.NULL_HANDLE {
		vk.DestroySampler(logical_device, vk_texture_ptr.sampler, p_vk_allocator)
		log.debugf("Destroyed sampler %p.", vk_texture_ptr.sampler)
		vk_texture_ptr.sampler = vk.NULL_HANDLE // Mark as destroyed
	}
	// 2. Image View
	if vk_texture_ptr.image_view != vk.NULL_HANDLE {
		vk.DestroyImageView(logical_device, vk_texture_ptr.image_view, p_vk_allocator)
		log.debugf("Destroyed image view %p.", vk_texture_ptr.image_view)
		vk_texture_ptr.image_view = vk.NULL_HANDLE
	}
	// 3. Image
	if vk_texture_ptr.image != vk.NULL_HANDLE {
		vk.DestroyImage(logical_device, vk_texture_ptr.image, p_vk_allocator)
		log.debugf("Destroyed image %p.", vk_texture_ptr.image)
		vk_texture_ptr.image = vk.NULL_HANDLE
	}
	// 4. Image Memory
	if vk_texture_ptr.memory != vk.NULL_HANDLE {
		vk.FreeMemory(logical_device, vk_texture_ptr.memory, p_vk_allocator)
		log.debugf("Freed device memory %p.", vk_texture_ptr.memory)
		vk_texture_ptr.memory = vk.NULL_HANDLE
	}

	// Get the allocator used for `Vk_Texture_Internal` struct itself.
	// Assuming it's the same allocator as the device that created it.
	// The `Vk_Texture_Internal` struct itself doesn't store its own allocator in the current definition.
	// We'll use the device_ref's allocator.
	struct_allocator := vk_texture_ptr.device_ref.allocator
	
	// Free the Vk_Texture_Internal struct itself
	// Check if struct_allocator is valid before using.
	// This assumes vk_texture_ptr was allocated using this allocator.
	if struct_allocator.proc != nil { // Basic check for a valid allocator
		free(vk_texture_ptr, struct_allocator)
		log.debug("Freed Vk_Texture_Internal struct.")
	} else {
		log.error("vk_destroy_texture_internal: Could not free Vk_Texture_Internal struct due to invalid allocator from device_ref.")
	}

	log.info("Vulkan texture destroyed successfully.")
}
