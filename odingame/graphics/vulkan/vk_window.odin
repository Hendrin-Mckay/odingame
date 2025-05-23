package vulkan

import vk "vendor:vulkan"
import sdl "vendor:sdl2"
import "core:log"
import "core:fmt"
import "core:mem"
import "core:math"
import "../gfx_interface"
import "../../common" // For common.Engine_Error

// --- Swapchain Helpers ---

// vk_choose_swapchain_surface_format_internal selects a suitable surface format.
// Prefers B8G8R8A8_SRGB with SRGB_NONLINEAR color space if available.
vk_choose_swapchain_surface_format_internal :: proc(available_formats: []vk.SurfaceFormatKHR) -> vk.SurfaceFormatKHR {
	if len(available_formats) == 0 {
		log.error("No surface formats available for swapchain.")
		// This should not happen if physical device selection was correct.
		// Return a default, though it's unlikely to work.
		return vk.SurfaceFormatKHR{format = .B8G8R8A8_SRGB, colorSpace = .SRGB_NONLINEAR_KHR}
	}

	for _, format in available_formats {
		if format.format == .B8G8R8A8_SRGB && format.colorSpace == .SRGB_NONLINEAR_KHR {
			log.info("Chose preferred swapchain surface format: B8G8R8A8_SRGB, SRGB_NONLINEAR_KHR")
			return format
		}
	}
	// Fallback to the first available format if preferred is not found.
	log.warnf("Preferred swapchain format not found. Using first available: Format %v, ColorSpace %v",
		available_formats[0].format, available_formats[0].colorSpace)
	return available_formats[0]
}

// vk_choose_swapchain_present_mode_internal selects a suitable presentation mode.
// Prefers MAILBOX if available, falls back to FIFO.
vk_choose_swapchain_present_mode_internal :: proc(available_present_modes: []vk.PresentModeKHR) -> vk.PresentModeKHR {
	if len(available_present_modes) == 0 {
		log.error("No present modes available for swapchain.")
		return .FIFO_KHR // Should always be available as per spec
	}

	for _, mode in available_present_modes {
		if mode == .MAILBOX_KHR {
			log.info("Chose preferred swapchain present mode: MAILBOX_KHR")
			return mode
		}
	}
	// FIFO is guaranteed to be available by the Vulkan spec.
	log.info("MAILBOX_KHR present mode not available. Using FIFO_KHR.")
	return .FIFO_KHR
}

// vk_choose_swapchain_extent_internal determines the resolution of swap chain images.
// It usually matches the window's current extent, within Vulkan's min/max image extent limits.
vk_choose_swapchain_extent_internal :: proc(capabilities: vk.SurfaceCapabilitiesKHR, sdl_window_handle: ^sdl.Window) -> vk.Extent2D {
	if capabilities.currentExtent.width != MAX_U32 { // MAX_U32 indicates window manager sets extent
		log.infof("Swapchain extent determined by Vulkan: %d x %d", capabilities.currentExtent.width, capabilities.currentExtent.height)
		return capabilities.currentExtent
	} else {
		// Window manager allows us to choose. Get current window size from SDL.
		drawable_w, drawable_h: i32
		sdl.Vulkan_GetDrawableSize(sdl_window_handle, &drawable_w, &drawable_h)
		
		actual_extent := vk.Extent2D{
			width  = u32(drawable_w),
			height = u32(drawable_h),
		}
		// Clamp to Vulkan's min/max supported extents
		actual_extent.width  = math.clamp(actual_extent.width,  capabilities.minImageExtent.width,  capabilities.maxImageExtent.width)
		actual_extent.height = math.clamp(actual_extent.height, capabilities.minImageExtent.height, capabilities.maxImageExtent.height)
		
		log.infof("Swapchain extent chosen based on SDL drawable size: %d x %d (clamped from %d x %d)",
			actual_extent.width, actual_extent.height, drawable_w, drawable_h)
		return actual_extent
	}
}

// vk_create_swapchain_internal_logic handles the creation of the swapchain and its image views.
// This can be called for initial creation and for recreation (e.g., after window resize).
vk_create_swapchain_internal_logic :: proc(
	vk_dev_internal: ^Vk_Device_Internal, 
	vk_win_internal: ^Vk_Window_Internal, // The window struct to update
	sdl_window_handle: ^sdl.Window, // Needed for current drawable size if recreating
) -> common.Engine_Error {

	physical_device := vk_dev_internal.physical_device_info.physical_device
	logical_device  := vk_dev_internal.logical_device
	surface         := vk_win_internal.surface
	allocator       := vk_win_internal.allocator // Allocator from the window struct

	// Query fresh swapchain support details as they might change (e.g. after surface recreation or mode change)
	// The allocator passed here is for the slices within Swapchain_Support_Details.
	// These slices will be owned by `swap_support` and freed at the end of this function.
	swap_support, ok_ss := query_swapchain_support(physical_device, surface, allocator)
	if !ok_ss {
		log.error("Failed to query swapchain support details during swapchain (re)creation.")
		return common.Engine_Error.Device_Creation_Failed // Or a more specific swapchain error
	}
	// Ensure these slices are freed as they are allocated by query_swapchain_support with `allocator`.
	defer delete(swap_support.formats)
	defer delete(swap_support.present_modes)


	if len(swap_support.formats) == 0 || len(swap_support.present_modes) == 0 {
		log.error("No formats or present modes available for swapchain creation.")
		return common.Engine_Error.Device_Creation_Failed
	}

	surface_format := vk_choose_swapchain_surface_format_internal(swap_support.formats)
	present_mode   := vk_choose_swapchain_present_mode_internal(swap_support.present_modes)
	extent         := vk_choose_swapchain_extent_internal(swap_support.capabilities, sdl_window_handle)

	if extent.width == 0 || extent.height == 0 {
		log.warn("Swapchain extent is zero (e.g. window minimized). Cannot create/recreate swapchain yet.")
		vk_win_internal.recreating_swapchain = true // Mark for later recreation
		return .None // Not an error, but swapchain is not ready
	}

	// Determine image count for swapchain (e.g., double buffering, triple buffering)
	image_count := swap_support.capabilities.minImageCount + 1 // Aim for one more than minimum
	if swap_support.capabilities.maxImageCount > 0 && image_count > swap_support.capabilities.maxImageCount {
		image_count = swap_support.capabilities.maxImageCount // Clamp to max if there is a max
	}
	log.infof("Swapchain image count: %d (min: %d, max: %d)", 
		image_count, swap_support.capabilities.minImageCount, swap_support.capabilities.maxImageCount)

	// --- Swapchain Create Info ---
	swapchain_create_info := vk.SwapchainCreateInfoKHR{
		sType = .SWAPCHAIN_CREATE_INFO_KHR,
		surface = surface,
		minImageCount = image_count,
		imageFormat = surface_format.format,
		imageColorSpace = surface_format.colorSpace,
		imageExtent = extent,
		imageArrayLayers = 1, // Usually 1, unless doing stereoscopic rendering
		imageUsage = {.COLOR_ATTACHMENT_BIT}, // Image will be used as color attachment
		// TODO: Add .TRANSFER_DST_BIT if copying to swapchain image (e.g. for screenshots or post-processing)
	}

	// Handle queue family sharing if graphics and present queues are different
	indices := vk_dev_internal.physical_device_info.queue_families
	queue_family_indices_arr: [2]u32
	if indices.graphics_family.? != indices.present_family.? {
		swapchain_create_info.imageSharingMode = .CONCURRENT
		swapchain_create_info.queueFamilyIndexCount = 2
		queue_family_indices_arr[0] = indices.graphics_family.?
		queue_family_indices_arr[1] = indices.present_family.?
		swapchain_create_info.pQueueFamilyIndices = &queue_family_indices_arr[0]
		log.info("Swapchain image sharing mode: CONCURRENT (Graphics and Present families differ)")
	} else {
		swapchain_create_info.imageSharingMode = .EXCLUSIVE
		swapchain_create_info.queueFamilyIndexCount = 0 // Optional
		swapchain_create_info.pQueueFamilyIndices = nil   // Optional
		log.info("Swapchain image sharing mode: EXCLUSIVE (Graphics and Present families are the same)")
	}

	swapchain_create_info.preTransform = swap_support.capabilities.currentTransform // Usually no transform
	swapchain_create_info.compositeAlpha = .OPAQUE_BIT_KHR // No alpha blending with window system
	swapchain_create_info.presentMode = present_mode
	swapchain_create_info.clipped = vk.TRUE // Allow clipping of obscured pixels
	
	// oldSwapchain is important if recreating (e.g., after resize) for resource transfer.
	// For initial creation, it's vk.NULL_HANDLE.
	// If vk_win_internal.swapchain is valid, it's a recreation.
	if vk_win_internal.swapchain != vk.NULL_HANDLE {
		swapchain_create_info.oldSwapchain = vk_win_internal.swapchain
		log.info("Recreating swapchain, oldSwapchain handle provided.")
	} else {
		swapchain_create_info.oldSwapchain = vk.NULL_HANDLE
	}

	// Create the swapchain
	p_vk_allocator: ^vk.AllocationCallbacks = nil // Assuming nil for Vulkan allocators
	new_swapchain: vk.SwapchainKHR
	result := vk.CreateSwapchainKHR(logical_device, &swapchain_create_info, p_vk_allocator, &new_swapchain)
	if result != .SUCCESS {
		log.errorf("vkCreateSwapchainKHR failed. Result: %v (%d)", result, int(result))
		// If oldSwapchain was provided, it's still valid. Don't nullify vk_win_internal.swapchain yet.
		// The caller might try to continue with the old one if recreation fails.
		return common.Engine_Error.Device_Creation_Failed // Or a more specific error
	}
	log.info("Vulkan Swapchain (re)created successfully.")

	// If this was a recreation, the old swapchain is now retired.
	// It should be destroyed after ensuring its resources are no longer in use.
	// For simplicity now, we'll destroy it immediately if it existed.
	// Proper handling requires waiting for device idle or using fence synchronization.
	if swapchain_create_info.oldSwapchain != vk.NULL_HANDLE {
		log.info("Destroying old swapchain...")
		// vk.DeviceWaitIdle(logical_device) // Ensure old swapchain images are not in use
		vk.DestroySwapchainKHR(logical_device, swapchain_create_info.oldSwapchain, p_vk_allocator)
		// Image views for old swapchain also need cleanup (done by vk_destroy_swapchain_internal)
	}
	
	vk_win_internal.swapchain = new_swapchain
	vk_win_internal.swapchain_format = surface_format.format
	vk_win_internal.swapchain_extent = extent

	// --- Create Render Pass (if not already created for this window) ---
	// This render pass is owned by the window and used for its framebuffers.
	// Pipelines must be compatible with this render pass.
	if vk_win_internal.render_pass == vk.NULL_HANDLE {
		rp, rp_err := vk_create_render_pass_internal(logical_device, vk_win_internal.swapchain_format)
		if rp_err != .None {
			log.errorf("Failed to create render pass for window: %v", rp_err)
			// Cleanup new swapchain and its images/views if render pass fails
			// This path is complex; for now, assume render pass creation succeeds if swapchain does.
			// A more robust cleanup would be needed here.
			vk.DestroySwapchainKHR(logical_device, vk_win_internal.swapchain, p_vk_allocator)
			vk_win_internal.swapchain = vk.NULL_HANDLE
			// Also need to clean up swapchain_images and swapchain_image_views if they were populated
			return common.Engine_Error.Device_Creation_Failed 
		}
		vk_win_internal.render_pass = rp
		log.infof("Window render pass created: %p", vk_win_internal.render_pass)
	}


	// --- Get Swapchain Images ---
	var sc_image_count: u32
	vk.GetSwapchainImagesKHR(logical_device, vk_win_internal.swapchain, &sc_image_count, nil)
	if sc_image_count == 0 {
		log.error("vkGetSwapchainImagesKHR reported 0 images after swapchain creation.")
		// This is a critical error. Cleanup the new swapchain.
		vk.DestroySwapchainKHR(logical_device, vk_win_internal.swapchain, p_vk_allocator)
		vk_win_internal.swapchain = vk.NULL_HANDLE
		return common.Engine_Error.Device_Creation_Failed
	}
	// Allocate/reallocate slice for images
	// Ensure old image data is cleared/deleted if reallocating
	delete(vk_win_internal.swapchain_images) // Safe if nil or empty
	vk_win_internal.swapchain_images = make([]vk.Image, sc_image_count, allocator)
	vk.GetSwapchainImagesKHR(logical_device, vk_win_internal.swapchain, &sc_image_count, vk_win_internal.swapchain_images[:])
	log.infof("Retrieved %d swapchain images.", sc_image_count)

	// --- Create Image Views ---
	// Ensure old image views are cleaned up first if this is a recreation
	vk_destroy_swapchain_image_views(logical_device, vk_win_internal, p_vk_allocator) // Helper defined below

	vk_win_internal.swapchain_image_views = make([]vk.ImageView, sc_image_count, allocator)
	for i := 0; i < int(sc_image_count); i = i + 1 {
		iv_create_info := vk.ImageViewCreateInfo{
			sType = .IMAGE_VIEW_CREATE_INFO,
			image = vk_win_internal.swapchain_images[i],
			viewType = .TYPE_2D,
			format = vk_win_internal.swapchain_format,
			components = vk.ComponentMapping{ // Identity mapping
				r = .IDENTITY, g = .IDENTITY, b = .IDENTITY, a = .IDENTITY,
			},
			subresourceRange = vk.ImageSubresourceRange{
				aspectMask = {.COLOR_BIT},
				baseMipLevel = 0,
				levelCount = 1,
				baseArrayLayer = 0,
				layerCount = 1,
			},
		}
		iv_res := vk.CreateImageView(logical_device, &iv_create_info, p_vk_allocator, &vk_win_internal.swapchain_image_views[i])
		if iv_res != .SUCCESS {
			log.errorf("vkCreateImageView failed for swapchain image %d. Result: %v", i, iv_res)
			// Critical error: cleanup everything created so far for this swapchain
			// This is complex. For now, mark as error and expect caller to handle full cleanup.
			// Destroy already created image views for this attempt
			for j := 0; j < i; j = j + 1 {
				vk.DestroyImageView(logical_device, vk_win_internal.swapchain_image_views[j], p_vk_allocator)
			}
			delete(vk_win_internal.swapchain_image_views)
			delete(vk_win_internal.swapchain_images)
			vk.DestroySwapchainKHR(logical_device, vk_win_internal.swapchain, p_vk_allocator)
			vk_win_internal.swapchain = vk.NULL_HANDLE
			return common.Engine_Error.Device_Creation_Failed
		}
	}
	log.infof("Created %d image views for swapchain images.", sc_image_count)

	// --- Create Framebuffers ---
	// Framebuffers depend on image views and the render pass.
	// Destroy old framebuffers first if this is a recreation.
	vk_destroy_framebuffers_internal(logical_device, vk_win_internal, p_vk_allocator) // Defined below
	fb_err := vk_create_framebuffers_internal(logical_device, vk_win_internal, p_vk_allocator)
	if fb_err != .None {
		log.error("Failed to create framebuffers for swapchain.")
		// Extensive cleanup needed here: new image views, new images, new swapchain, potentially render pass if just created.
		// This indicates a critical failure. For now, returning error.
		// A robust implementation would unwind all creations from this function.
		vk_destroy_swapchain_image_views(logical_device, vk_win_internal, p_vk_allocator)
		delete(vk_win_internal.swapchain_images) // Images are owned by swapchain
		vk_win_internal.swapchain_images = nil
		vk.DestroySwapchainKHR(logical_device, vk_win_internal.swapchain, p_vk_allocator)
		vk_win_internal.swapchain = vk.NULL_HANDLE
		// Render pass is not destroyed here as it's window-owned, assumed to be valid if we got this far.
		return common.Engine_Error.Device_Creation_Failed
	}
	
	// Initialize images_in_flight fence array (size of swapchain images)
	// This should be done only once when the number of swapchain images is first known,
	// or if it changes (unlikely without full swapchain recreation).
	if vk_win_internal.images_in_flight == nil || len(vk_win_internal.images_in_flight) != int(sc_image_count) {
		delete(vk_win_internal.images_in_flight) // Delete old slice if sizes differ (or first time)
		vk_win_internal.images_in_flight = make([]vk.Fence, sc_image_count, allocator)
		// Initialize all to NULL_HANDLE (Odin default for slices of pointers/handles)
		log.debugf("Initialized images_in_flight fence array with size %d", sc_image_count)
	}


	vk_win_internal.recreating_swapchain = false // Successfully (re)created
	return .None
}


// vk_destroy_framebuffers_internal cleans up framebuffers.
vk_destroy_framebuffers_internal :: proc(logical_device: vk.Device, vk_win_internal: ^Vk_Window_Internal, p_vk_allocator: ^vk.AllocationCallbacks) {
	if vk_win_internal == nil || vk_win_internal.framebuffers == nil {
		return
	}
	log.debugf("Destroying %d framebuffers for swapchain %p", len(vk_win_internal.framebuffers), vk_win_internal.swapchain)
	for _, fb in vk_win_internal.framebuffers {
		if fb != vk.NULL_HANDLE {
			vk.DestroyFramebuffer(logical_device, fb, p_vk_allocator)
		}
	}
	delete(vk_win_internal.framebuffers)
	vk_win_internal.framebuffers = nil
}

// vk_create_framebuffers_internal creates framebuffers for the swapchain image views.
vk_create_framebuffers_internal :: proc(logical_device: vk.Device, vk_win_internal: ^Vk_Window_Internal, p_vk_allocator: ^vk.AllocationCallbacks) -> common.Engine_Error {
	if vk_win_internal.render_pass == vk.NULL_HANDLE {
		log.error("Cannot create framebuffers: Window render pass is NULL.")
		return common.Engine_Error.Invalid_Handle // Or .Not_Ready
	}
	if len(vk_win_internal.swapchain_image_views) == 0 {
		log.error("Cannot create framebuffers: No swapchain image views available.")
		return common.Engine_Error.Not_Ready 
	}

	num_images := len(vk_win_internal.swapchain_image_views)
	vk_win_internal.framebuffers = make([]vk.Framebuffer, num_images, vk_win_internal.allocator)
	
	for i := 0; i < num_images; i = i + 1 {
		attachments := [1]vk.ImageView{vk_win_internal.swapchain_image_views[i]} // Array of one image view
		fb_create_info := vk.FramebufferCreateInfo{
			sType = .FRAMEBUFFER_CREATE_INFO,
			renderPass = vk_win_internal.render_pass,
			attachmentCount = 1,
			pAttachments = &attachments[0],
			width = vk_win_internal.swapchain_extent.width,
			height = vk_win_internal.swapchain_extent.height,
			layers = 1,
		}
		fb_res := vk.CreateFramebuffer(logical_device, &fb_create_info, p_vk_allocator, &vk_win_internal.framebuffers[i])
		if fb_res != .SUCCESS {
			log.errorf("vkCreateFramebuffer failed for image view %d. Result: %v", i, fb_res)
			// Cleanup already created framebuffers for this attempt
			for j := 0; j < i; j = j + 1 {
				vk.DestroyFramebuffer(logical_device, vk_win_internal.framebuffers[j], p_vk_allocator)
			}
			delete(vk_win_internal.framebuffers)
			vk_win_internal.framebuffers = nil
			return common.Engine_Error.Device_Creation_Failed
		}
	}
	log.infof("Created %d framebuffers successfully.", num_images)
	return .None
}


// vk_destroy_swapchain_image_views cleans up image views.
vk_destroy_swapchain_image_views :: proc(logical_device: vk.Device, vk_win_internal: ^Vk_Window_Internal, p_vk_allocator: ^vk.AllocationCallbacks) {
	if vk_win_internal == nil || vk_win_internal.swapchain_image_views == nil {
		return
	}
	log.debugf("Destroying %d image views for swapchain %p", len(vk_win_internal.swapchain_image_views), vk_win_internal.swapchain)
	for _, image_view in vk_win_internal.swapchain_image_views {
		if image_view != vk.NULL_HANDLE {
			vk.DestroyImageView(logical_device, image_view, p_vk_allocator)
		}
	}
	delete(vk_win_internal.swapchain_image_views) // Free the slice itself
	vk_win_internal.swapchain_image_views = nil
}

// vk_destroy_swapchain_internal cleans up all swapchain related resources.
vk_destroy_swapchain_internal :: proc(logical_device: vk.Device, vk_win_internal: ^Vk_Window_Internal, p_vk_allocator: ^vk.AllocationCallbacks) {
	if vk_win_internal == nil {
		return
	}
	// Wait for device to be idle before destroying swapchain resources,
	// especially if this is called outside of full device destruction.
	// vk.DeviceWaitIdle(logical_device) // Consider if this is needed here or at a higher level

	// Destroy Framebuffers first, as they depend on image views and render pass
	vk_destroy_framebuffers_internal(logical_device, vk_win_internal, p_vk_allocator)

	// Then destroy Image Views
	vk_destroy_swapchain_image_views(logical_device, vk_win_internal, p_vk_allocator)
	
	// Swapchain images are owned by the swapchain and destroyed with it, so no explicit vkDestroyImage.
	// Just clear the slice.
	delete(vk_win_internal.swapchain_images)
	vk_win_internal.swapchain_images = nil

	if vk_win_internal.swapchain != vk.NULL_HANDLE {
		log.debugf("Destroying Vulkan Swapchain %p", vk_win_internal.swapchain)
		vk.DestroySwapchainKHR(logical_device, vk_win_internal.swapchain, p_vk_allocator)
		vk_win_internal.swapchain = vk.NULL_HANDLE
	}
}


// --- Gfx_Window_Interface Wrappers ---

vk_create_window_wrapper :: proc(
	device: gfx_interface.Gfx_Device, 
	title: string, 
	width, height: int,
) -> (gfx_interface.Gfx_Window, common.Engine_Error) {
	
	vk_dev_internal, ok_dev := device.variant.(Vk_Device_Variant)
	if !ok_dev || vk_dev_internal == nil {
		log.error("vk_create_window_wrapper: Invalid Gfx_Device (not Vulkan or nil variant).")
		return gfx_interface.Gfx_Window{}, common.Engine_Error.Invalid_Handle
	}
	
	allocator := vk_dev_internal.allocator // Use device's allocator for the window struct

	// 1. Create SDL Window with VULKAN flag
	// SDL_Init(SDL_INIT_VIDEO) and Vulkan_LoadLibrary should have been done by Gfx_Device creation.
	sdl_window_flags : sdl.WindowFlags = {.VULKAN} // Add .RESIZABLE, .ALLOW_HIGHDPI as needed
	// TODO: Make flags configurable
	// if (window_flags & WindowFlags.Resizable) != 0 { sdl_window_flags |= {.RESIZABLE} }
	
	sdl_win := sdl.CreateWindow(title, sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED, width, height, sdl_window_flags)
	if sdl_win == nil {
		log.errorf("SDL_CreateWindow failed (Vulkan window): %s", sdl.GetError())
		return gfx_interface.Gfx_Window{}, common.Engine_Error.Window_Creation_Failed
	}
	log.infof("SDL Window created for Vulkan (title: %s, %dx%d)", title, width, height)

	// 2. Create Vulkan Surface
	var surface_handle: vk.SurfaceKHR
	// pAllocator for Vulkan_CreateSurface is the instance's allocator, but SDL handles it.
	if sdl.Vulkan_CreateSurface(sdl_win, vk_dev_internal.vk_instance.instance, &surface_handle) == sdl.FALSE {
		err_msg := sdl.GetError()
		log.errorf("SDL_Vulkan_CreateSurface failed: %s", err_msg)
		sdl.DestroyWindow(sdl_win)
		return gfx_interface.Gfx_Window{}, common.Engine_Error.Window_Creation_Failed // Or a more specific Surface_Creation_Failed
	}
	log.infof("Vulkan SurfaceKHR created: %p", surface_handle)

	// 3. Create Vk_Window_Internal struct (partially initialized)
	vk_win_internal := new(Vk_Window_Internal, allocator)
	vk_win_internal.allocator = allocator
	vk_win_internal.sdl_window = sdl_win
	vk_win_internal.vk_instance = vk_dev_internal.vk_instance
	vk_win_internal.device_ref = vk_dev_internal
	vk_win_internal.surface = surface_handle
	// Swapchain and related fields (images, views, format, extent) will be set by vk_create_swapchain_internal_logic.
	// vk_win_internal.swapchain is initially vk.NULL_HANDLE

	// Set this window as the primary one for pipeline creation on the device.
	// This is a simplification. A more robust app might have explicit primary window management.
	vk_dev_internal.primary_window_for_pipeline = vk_win_internal
	log.infof("Window %p (SDL: %s) set as primary_window_for_pipeline on device %p", 
		vk_win_internal, title, vk_dev_internal)

	// 4. Create Swapchain, RenderPass, ImageViews, Framebuffers
	// This populates vk_win_internal with swapchain, images, views, format, extent, render_pass, framebuffers.
	swap_err := vk_create_swapchain_internal_logic(vk_dev_internal, vk_win_internal, sdl_win)
	if swap_err != .None {
		log.errorf("Initial swapchain and related resources creation failed for window '%s': %s", title, gfx_interface.gfx_api.get_error_string(swap_err))
		if vk_win_internal.render_pass != vk.NULL_HANDLE { // If render pass was created by this attempt
			vk.DestroyRenderPass(vk_dev_internal.logical_device, vk_win_internal.render_pass, nil)
		}
		vk.DestroySurfaceKHR(vk_dev_internal.vk_instance.instance, surface_handle, nil)
		sdl.DestroyWindow(sdl_win)
		free(vk_win_internal, allocator) 
		return gfx_interface.Gfx_Window{}, swap_err
	}

	// 5. Create Synchronization Primitives and Command Buffers
	// Semaphores and Fences
	p_vk_allocator: ^vk.AllocationCallbacks = nil
	semaphore_create_info := vk.SemaphoreCreateInfo{ sType = .SEMAPHORE_CREATE_INFO }
	fence_create_info := vk.FenceCreateInfo{ sType = .FENCE_CREATE_INFO, flags = {.SIGNALED_BIT} } // Create fences in signaled state

	for i := 0; i < MAX_FRAMES_IN_FLIGHT; i = i + 1 {
		if vk.CreateSemaphore(vk_dev_internal.logical_device, &semaphore_create_info, p_vk_allocator, &vk_win_internal.image_available_semaphores[i]) != .SUCCESS ||
		   vk.CreateSemaphore(vk_dev_internal.logical_device, &semaphore_create_info, p_vk_allocator, &vk_win_internal.render_finished_semaphores[i]) != .SUCCESS ||
		   vk.CreateFence(vk_dev_internal.logical_device, &fence_create_info, p_vk_allocator, &vk_win_internal.in_flight_fences[i]) != .SUCCESS {
			log.error("Failed to create synchronization primitives for a frame.")
			// Cleanup already created sync objects, swapchain resources, surface, window... this is extensive.
			// For now, consider this a fatal error for window creation.
			// A full cleanup path would be needed in production.
			vk_destroy_window_internal_resources(vk_win_internal) // Helper to destroy all vk_win_internal contents
			return gfx_interface.Gfx_Window{}, common.Engine_Error.Graphics_Initialization_Failed
		}
	}
	log.infof("Created %d sets of frame synchronization primitives.", MAX_FRAMES_IN_FLIGHT)

	// Command Buffers
	cmd_buf_alloc_info := vk.CommandBufferAllocateInfo{
		sType = .COMMAND_BUFFER_ALLOCATE_INFO,
		commandPool = vk_dev_internal.command_pool,
		level = .PRIMARY,
		commandBufferCount = MAX_FRAMES_IN_FLIGHT,
	}
	cmd_buf_res := vk.AllocateCommandBuffers(vk_dev_internal.logical_device, &cmd_buf_alloc_info, &vk_win_internal.command_buffers[0])
	if cmd_buf_res != .SUCCESS {
		log.errorf("Failed to allocate command buffers: %v", cmd_buf_res)
		vk_destroy_window_internal_resources(vk_win_internal)
		return gfx_interface.Gfx_Window{}, common.Engine_Error.Graphics_Initialization_Failed
	}
	log.infof("Allocated %d primary command buffers.", MAX_FRAMES_IN_FLIGHT)
	
	vk_win_internal.current_frame_index = 0 // Initialize current frame index

	log.infof("Vulkan Gfx_Window wrapper created successfully for SDL window '%s'.", title)
	return gfx_interface.Gfx_Window{variant = Vk_Window_Variant(vk_win_internal)}, .None
}

// vk_destroy_window_internal_resources is a helper to clean up all resources within Vk_Window_Internal
// This is called on failure during creation or during full destruction.
vk_destroy_window_internal_resources :: proc(vk_win: ^Vk_Window_Internal) {
	if vk_win == nil { return }
	
	logical_device := vk_win.device_ref.logical_device // Assume device_ref is valid if vk_win is
	instance       := vk_win.vk_instance.instance   // Assume vk_instance is valid
	p_vk_allocator: ^vk.AllocationCallbacks = nil

	// Wait for device idle before destroying window resources, especially if called outside full device destruction.
	// This ensures command buffers, etc., are no longer in use.
	if logical_device != vk.NULL_HANDLE {
		vk.DeviceWaitIdle(logical_device)
	}

	// Destroy swapchain and its dependent resources (framebuffers, image views, images are handled by it)
	vk_destroy_swapchain_internal(logical_device, vk_win, p_vk_allocator)

	// Destroy render pass owned by the window
	if vk_win.render_pass != vk.NULL_HANDLE {
		log.debugf("Destroying window RenderPass: %p", vk_win.render_pass)
		vk.DestroyRenderPass(logical_device, vk_win.render_pass, p_vk_allocator)
		vk_win.render_pass = vk.NULL_HANDLE
	}
	
	// Destroy synchronization primitives
	for i := 0; i < MAX_FRAMES_IN_FLIGHT; i = i + 1 {
		if vk_win.image_available_semaphores[i] != vk.NULL_HANDLE {
			vk.DestroySemaphore(logical_device, vk_win.image_available_semaphores[i], p_vk_allocator)
		}
		if vk_win.render_finished_semaphores[i] != vk.NULL_HANDLE {
			vk.DestroySemaphore(logical_device, vk_win.render_finished_semaphores[i], p_vk_allocator)
		}
		if vk_win.in_flight_fences[i] != vk.NULL_HANDLE {
			vk.DestroyFence(logical_device, vk_win.in_flight_fences[i], p_vk_allocator)
		}
	}
	log.debug("Destroyed frame synchronization primitives.")

	// Command buffers are allocated from device's pool; freed when pool is destroyed or explicitly.
	// If pool is device-global, explicit free here might be good if window is destroyed before device.
	// For now, assume they are cleaned up with the command pool owned by Vk_Device_Internal.
	// Or, if allocated specifically for this window and needs specific cleanup:
	// if vk_win.device_ref != nil && vk_win.device_ref.command_pool != vk.NULL_HANDLE && vk_win.command_buffers[0] != vk.NULL_HANDLE {
	// 	log.debugf("Freeing %d command buffers.", MAX_FRAMES_IN_FLIGHT)
	// 	vk.FreeCommandBuffers(logical_device, vk_win.device_ref.command_pool, MAX_FRAMES_IN_FLIGHT, &vk_win.command_buffers[0])
	// 	// Clear handles, though struct is about to be freed
	// 	for i := 0; i < MAX_FRAMES_IN_FLIGHT; i=i+1 { vk_win.command_buffers[i] = vk.NULL_HANDLE }
	// }


	// Destroy surface
	if vk_win.surface != vk.NULL_HANDLE {
		vk.DestroySurfaceKHR(instance, vk_win.surface, p_vk_allocator)
		log.info("Vulkan SurfaceKHR destroyed.")
		vk_win.surface = vk.NULL_HANDLE
	}
	
	// Destroy SDL window
	if vk_win.sdl_window != nil {
		sdl.DestroyWindow(vk_win.sdl_window)
		log.info("SDL Window destroyed.")
		vk_win.sdl_window = nil
	}
	
	// Free slices owned by Vk_Window_Internal not covered by other destroys
	delete(vk_win.images_in_flight) // Slice of fences, fences themselves destroyed above or managed by Vulkan

	// Free the Vk_Window_Internal struct itself
	// This should be done by the caller of this helper, vk_destroy_window_wrapper
	// free(vk_win, vk_win.allocator) 
	// log.info("Vk_Window_Internal struct freed.")
}


vk_destroy_window_wrapper :: proc(window: gfx_interface.Gfx_Window) {
	if vk_win, ok := window.variant.(Vk_Window_Variant); ok && vk_win != nil {
		log.infof("Destroying Vulkan Gfx_Window (SDL Window Title: %s, Surface: %p)", 
			sdl.GetWindowTitle(vk_win.sdl_window) if vk_win.sdl_window != nil else "N/A", 
			vk_win.surface)
		
		vk_destroy_window_internal_resources(vk_win) // Call the helper
		
		// Free the Vk_Window_Internal struct itself
		free(vk_win, vk_win.allocator)
		log.info("Vk_Window_Internal struct freed.")

	} else {
		log.errorf("vk_destroy_window_wrapper: Invalid Gfx_Window type or nil variant (%v).", window.variant)
	}
}


// --- Stubbed/Simplified Window Interface Functions for Vulkan ---

vk_present_window_wrapper :: proc(window: gfx_interface.Gfx_Window) -> common.Engine_Error {
	// TODO: Full Vulkan presentation logic:
	// 1. Acquire next available swapchain image (vkAcquireNextImageKHR) - needs semaphore
	// 2. Submit command buffer to render to that image (waits on acquire semaphore, signals render finished semaphore)
	// 3. Present the image (vkQueuePresentKHR) - waits on render finished semaphore
	// This is complex and involves command buffers, render passes, and synchronization.
	// For initial setup, this can be a placeholder.
	
	vk_win, ok := window.variant.(Vk_Window_Variant)
	if !ok || vk_win == nil { return common.Engine_Error.Invalid_Handle }
	
	if vk_win.recreating_swapchain {
		log.debug("Skipping present for window pending swapchain recreation.")
		// Attempt recreation here or expect app to handle resize events explicitly.
		// err_recreate := vk_create_swapchain_internal_logic(vk_win.device_ref, vk_win, vk_win.sdl_window)
		// if err_recreate != .None { log.error("Failed to recreate swapchain during present attempt.") }
		return .None // Or an error indicating not ready
	}

	log.debug("vk_present_window_wrapper: Placeholder - Full presentation logic not yet implemented.")
	// A very basic vkQueuePresentKHR without proper sync or image acquisition will likely error or flicker.
	// For now, just return None.
	return .None 
}

vk_resize_window_wrapper :: proc(window: gfx_interface.Gfx_Window, width, height: int) -> common.Engine_Error {
	// For Vulkan, resizing a window typically means the swapchain becomes out-of-date
	// and needs to be recreated.
	vk_win, ok := window.variant.(Vk_Window_Variant)
	if !ok || vk_win == nil { return common.Engine_Error.Invalid_Handle }

	log.infof("Vulkan window resize requested to %dx%d. Marking for swapchain recreation.", width, height)
	// SDL window itself might be resized by OS events. This function is for programmatic resize
	// or handling the event that SDL window size changed.
	// For now, just mark that it needs recreation. The rendering loop or next present call should handle it.
	vk_win.recreating_swapchain = true 
	
	// Actual recreation logic:
	// 1. Wait for device idle (vkDeviceWaitIdle)
	// 2. Clean up old swapchain (vk_destroy_swapchain_internal, but save vk.SwapchainKHR handle for oldSwapchain)
	// 3. Call vk_create_swapchain_internal_logic to build new one with new dimensions.
	// This is usually triggered by event handling (e.g. SDL_WINDOWEVENT_RESIZED).
	// For simplicity, this stub just marks it. A robust app needs to trigger recreation.
	
	// Let's attempt a simple recreation here, assuming SDL window is already resized.
	// vk.DeviceWaitIdle(vk_win.device_ref.logical_device) // Important!
	// vk_destroy_swapchain_image_views(vk_win.device_ref.logical_device, vk_win, nil) // Keep old swapchain handle for recreation
	// err := vk_create_swapchain_internal_logic(vk_win.device_ref, vk_win, vk_win.sdl_window)
	// if err != .None {
	// 	log.errorf("Failed to recreate swapchain during resize: %s", gfx_interface.gfx_api.get_error_string(err))
	// 	return err
	// }
	// log.info("Swapchain recreated due to resize.")
	return common.Engine_Error.Not_Implemented // Proper resize handling is complex.
}

vk_get_window_size_wrapper :: proc(window: gfx_interface.Gfx_Window) -> (w, h: int) {
	if vk_win, ok := window.variant.(Vk_Window_Variant); ok && vk_win != nil && vk_win.sdl_window != nil {
		w,h : i32
		sdl.GetWindowSize(vk_win.sdl_window, &w, &h) // Logical size
		return int(w), int(h)
	}
	return 0,0
}

vk_get_window_drawable_size_wrapper :: proc(window: gfx_interface.Gfx_Window) -> (w, h: int) {
	if vk_win, ok := window.variant.(Vk_Window_Variant); ok && vk_win != nil && vk_win.sdl_window != nil {
		w,h : i32
		sdl.Vulkan_GetDrawableSize(vk_win.sdl_window, &w, &h) // Drawable size for Vulkan surface
		return int(w), int(h)
	}
	return 0,0
}
