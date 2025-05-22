package vulkan

import vk "vendor:vulkan" // Assumed Vulkan bindings
import sdl "vendor:sdl2"   // For SDL_Window handle
import "../gfx_interface" // For Gfx_Device, Gfx_Window etc.
import "core:mem"

// --- Vulkan Specific Structs ---

// Vk_Instance_Info stores the Vulkan instance and related data
Vk_Instance_Info :: struct {
	instance:            vk.Instance,
	allocator:           mem.Allocator, // Allocator used for this instance and its children
	// Debug messenger, layers, extensions can be stored here if needed for destruction or info
	// For now, keeping it simple.
	debug_messenger:     vk.DebugUtilsMessengerEXT,
	validation_layers_enabled: bool,
}

// Queue_Family_Indices stores indices of queue families found on a physical device
Queue_Family_Indices :: struct {
	graphics_family:         Maybe(u32),
	present_family:          Maybe(u32),
	// compute_family:       Maybe(u32), // For future use
	// transfer_family:      Maybe(u32), // For future use
}

is_complete :: proc(qfi: Queue_Family_Indices) -> bool {
	return qfi.graphics_family != nil && qfi.present_family != nil
}

// Vk_PhysicalDevice_Info stores information about a selected physical device
Vk_PhysicalDevice_Info :: struct {
	physical_device:     vk.PhysicalDevice,
	properties:          vk.PhysicalDeviceProperties,
	features:            vk.PhysicalDeviceFeatures, // Base features
	// available_extensions: []vk.ExtensionProperties, // To check for required extensions like swapchain
	queue_families:      Queue_Family_Indices,
	// memory_properties: vk.PhysicalDeviceMemoryProperties, // For buffer/texture memory allocation later
}

// Vk_Device is the main Vulkan logical device structure.
// This will be the variant data for Gfx_Device.
Vk_Device_Internal :: struct {
	using gfx_interface.Gfx_Device_Interface, // Embed the interface for easy calls if needed, though usually call via global gfx_api
	
	vk_instance:         ^Vk_Instance_Info, // Reference to the Vulkan instance info
	physical_device_info: ^Vk_PhysicalDevice_Info,
	logical_device:      vk.Device,         // The Vulkan logical device

	graphics_queue:      vk.Queue,
	present_queue:       vk.Queue,
	
	// Allocator that was used to create this device and its sub-resources
	allocator:           mem.Allocator, 
}

// Swapchain_Support_Details stores capabilities needed for swapchain creation
Swapchain_Support_Details :: struct {
	capabilities:        vk.SurfaceCapabilitiesKHR,
	formats:             []vk.SurfaceFormatKHR,
	present_modes:       []vk.PresentModeKHR,
}

// Vk_Window_Internal holds Vulkan specific data for a window, including its swapchain.
// This will be the variant data for Gfx_Window.
Vk_Window_Internal :: struct {
	sdl_window:          ^sdl.Window, // SDL window handle
	vk_instance:         ^Vk_Instance_Info, // Reference to the instance (for surface destruction)
	device_ref:          ^Vk_Device_Internal, // Reference back to the logical device
	
	surface:             vk.SurfaceKHR,
	
	swapchain:           vk.SwapchainKHR,
	swapchain_images:    []vk.Image,
	swapchain_image_views: []vk.ImageView,
	swapchain_format:    vk.Format,
	swapchain_extent:    vk.Extent2D,
	
	// For rendering (to be added later)
	// render_pass:      vk.RenderPass
	// framebuffers:     []vk.Framebuffer
	// command_pool:     vk.CommandPool
	// command_buffers:  []vk.CommandBuffer
	
	// Synchronization objects (to be added later)
	// image_available_semaphores: []vk.Semaphore
	// render_finished_semaphores: []vk.Semaphore
	// in_flight_fences:           []vk.Fence
	// current_frame:              int, // For multi-buffering

	allocator:           mem.Allocator, // Allocator for this struct and its slices
	recreating_swapchain: bool, // Flag to indicate swapchain needs recreation (e.g. after resize)
}

// --- Gfx_Device and Gfx_Window variants for Vulkan ---
// These are the types that will be stored in the Gfx_Device and Gfx_Window struct_variants.
Vk_Device_Variant :: ^Vk_Device_Internal
Vk_Window_Variant :: ^Vk_Window_Internal

// Helper to get the allocator from a Gfx_Device (assuming it's Vulkan)
get_vk_device_allocator :: proc(device: gfx_interface.Gfx_Device) -> (mem.Allocator, bool) {
	if vk_dev, ok := device.variant.(Vk_Device_Variant); ok && vk_dev != nil {
		return vk_dev.allocator, true
	}
	return context.allocator, false // Fallback or error
}

// Helper to get the allocator from a Gfx_Window (assuming it's Vulkan)
get_vk_window_allocator :: proc(window: gfx_interface.Gfx_Window) -> (mem.Allocator, bool) {
	if vk_win, ok := window.variant.(Vk_Window_Variant); ok && vk_win != nil {
		return vk_win.allocator, true
	}
	return context.allocator, false // Fallback or error
}
