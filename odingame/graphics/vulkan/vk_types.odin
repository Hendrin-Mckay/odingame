package vulkan

import vk "vendor:vulkan" 
import sdl "vendor:sdl2"   
import "../gfx_interface" 
import "core:mem"

// --- Vulkan Specific Constants ---
MAX_FRAMES_IN_FLIGHT :: 2
MAX_DESCRIPTOR_SETS_PER_POOL :: 128 // Example value
DEFAULT_UBO_SIZE :: 16 * 1024      // Example: 16KB for a general purpose UBO

// --- Vulkan Specific Structs ---

Vk_Instance_Info :: struct {
	instance:            vk.Instance,
	allocator:           mem.Allocator,
	debug_messenger:     vk.DebugUtilsMessengerEXT,
	validation_layers_enabled: bool,
}

Queue_Family_Indices :: struct {
	graphics_family:         Maybe(u32),
	present_family:          Maybe(u32),
}

is_complete :: proc(qfi: Queue_Family_Indices) -> bool {
	return qfi.graphics_family != nil && qfi.present_family != nil
}

Vk_PhysicalDevice_Info :: struct {
	physical_device:     vk.PhysicalDevice,
	properties:          vk.PhysicalDeviceProperties,
	features:            vk.PhysicalDeviceFeatures,
	queue_families:      Queue_Family_Indices,
}

Vk_Device_Internal :: struct {
	using gfx_interface.Gfx_Device_Interface,
	
	vk_instance:         ^Vk_Instance_Info,
	physical_device_info: ^Vk_PhysicalDevice_Info,
	logical_device:      vk.Device,

	graphics_queue:      vk.Queue,
	present_queue:       vk.Queue,
	
	allocator:           mem.Allocator,
	
	primary_window_for_pipeline: ^Vk_Window_Internal, 
	command_pool:        vk.CommandPool, 
	descriptor_pool:     vk.DescriptorPool,
    
    // Uniform Buffers: one per frame in flight for dynamic data like MVP matrices
    uniform_buffers:     [MAX_FRAMES_IN_FLIGHT]Vk_Uniform_Buffer_Info, 
}

Swapchain_Support_Details :: struct {
	capabilities:        vk.SurfaceCapabilitiesKHR,
	formats:             []vk.SurfaceFormatKHR,
	present_modes:       []vk.PresentModeKHR,
}

Vk_Uniform_Buffer_Info :: struct {
    buffer:          vk.Buffer,
    memory:          vk.DeviceMemory,
    size:            vk.DeviceSize,
    mapped_ptr:      rawptr, 
    device_ref:      ^Vk_Device_Internal,
    allocator:       mem.Allocator,
}

Vk_Window_Internal :: struct {
	sdl_window:          ^sdl.Window,
	vk_instance:         ^Vk_Instance_Info,
	device_ref:          ^Vk_Device_Internal,
	
	surface:             vk.SurfaceKHR,
	
	swapchain:           vk.SwapchainKHR,
	swapchain_images:    []vk.Image,
	swapchain_image_views: []vk.ImageView,
	swapchain_format:    vk.Format,
	swapchain_extent:    vk.Extent2D,
	
	render_pass:         vk.RenderPass, 
	framebuffers:        []vk.Framebuffer,

	command_buffers:     [MAX_FRAMES_IN_FLIGHT]vk.CommandBuffer,

	image_available_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
	render_finished_semaphores: [MAX_FRAMES_IN_FLIGHT]vk.Semaphore,
	in_flight_fences:           [MAX_FRAMES_IN_FLIGHT]vk.Fence,
	images_in_flight:           []vk.Fence, 

	current_frame_index: u32,

	active_command_buffer: vk.CommandBuffer, 
	acquired_image_index: u32,            
	
	active_pipeline_layout: vk.PipelineLayout, 
	active_pipeline_gfx:    gfx_interface.Gfx_Pipeline, 
    current_descriptor_sets: [MAX_FRAMES_IN_FLIGHT]vk.DescriptorSet, 
                                                                    
	active_vao: gfx_interface.Gfx_Vertex_Array,

	allocator:           mem.Allocator, 
	recreating_swapchain: bool, 
}

Vk_Texture_Internal :: struct {
	image:               vk.Image,
	image_view:          vk.ImageView,
	memory:              vk.DeviceMemory,
	sampler:             vk.Sampler, 
	width:               u32,
	height:              u32,
	format:              vk.Format,
	usage:               vk.ImageUsageFlags,
	current_layout:      vk.ImageLayout, 
	device_ref:          ^Vk_Device_Internal, 
}

Vk_Pipeline_Internal :: struct {
	pipeline:            vk.Pipeline,        
	pipeline_layout:     vk.PipelineLayout,  
	descriptor_set_layouts: []vk.DescriptorSetLayout, 
	render_pass:         vk.RenderPass, // RenderPass this pipeline is compatible with
	device_ref:          ^Vk_Device_Internal,
	allocator:           mem.Allocator,
}


Vk_Device_Variant :: ^Vk_Device_Internal
Vk_Window_Variant :: ^Vk_Window_Internal

Vk_Buffer_Internal :: struct { 
	buffer:          vk.Buffer,
	memory:          vk.DeviceMemory,
	device_ref:      ^Vk_Device_Internal, 
	size:            vk.DeviceSize,     
	allocator:       mem.Allocator,     
	mapped_ptr:      rawptr,            
}

get_vk_device_allocator :: proc(device: gfx_interface.Gfx_Device) -> (mem.Allocator, bool) {
	if vk_dev, ok := device.variant.(Vk_Device_Variant); ok && vk_dev != nil {
		return vk_dev.allocator, true
	}
	return context.allocator, false 
}

get_vk_window_allocator :: proc(window: gfx_interface.Gfx_Window) -> (mem.Allocator, bool) {
	if vk_win, ok := window.variant.(Vk_Window_Variant); ok && vk_win != nil {
		return vk_win.allocator, true
	}
	return context.allocator, false 
}
