package vulkan

import vk "vendor:vulkan"
import "core:log"
import "core:mem"
import "../gfx_interface" // For Gfx_Device, Gfx_Error, Gfx_Shader, Gfx_Pipeline, Shader_Stage
// We need access to Vk_Shader_Internal from vk_shader.odin
// Assuming vk_shader.odin is part of the same 'vulkan' package.

// Vk_Pipeline_Internal holds the Vulkan-specific pipeline data.
Vk_Pipeline_Internal :: struct {
	pipeline:        vk.Pipeline,
	pipeline_layout: vk.PipelineLayout,
	render_pass:     vk.RenderPass,          // RenderPass used for this pipeline
	device_ref:      ^Vk_Device_Internal,    // Reference to the logical device for destruction
	allocator:       mem.Allocator,        // Allocator used for this struct
}

// vk_create_render_pass_internal creates a simple Vulkan RenderPass.
// This function is now intended to be called by window/swapchain setup
// to create a render pass compatible with the swapchain.
// Pipelines will then be created to be compatible with this render pass.
vk_create_render_pass_internal :: proc(
	logical_device: vk.Device,
	swapchain_format: vk.Format, 
) -> (vk.RenderPass, gfx_interface.Gfx_Error) {
	// allocator parameter removed as it's not creating heap-allocated Odin structs directly

	color_attachment_desc := vk.AttachmentDescription{
		format = swapchain_format,
		samples = .SAMPLE_COUNT_1_BIT, // No multisampling for now
		loadOp = .CLEAR,              // Clear framebuffer before rendering
		storeOp = .STORE,             // Store rendered contents in memory
		stencilLoadOp = .DONT_CARE,   // No stencil buffer
		stencilStoreOp = .DONT_CARE,  // No stencil buffer
		initialLayout = .UNDEFINED,   // Layout before render pass begins
		finalLayout = .PRESENT_SRC_KHR, // Layout to transition to after render pass (for presentation)
	}

	color_attachment_ref := vk.AttachmentReference{
		attachment = 0, // Index of the attachment in pAttachments array (we have one)
		layout = .COLOR_ATTACHMENT_OPTIMAL, // Layout during the subpass
	}

	// Define a single subpass that uses the color attachment
	subpass_desc := vk.SubpassDescription{
		pipelineBindPoint = .GRAPHICS,
		colorAttachmentCount = 1,
		pColorAttachments = &color_attachment_ref, // Pointer to array of color attachment references
		// pDepthStencilAttachment, pResolveAttachments, pInputAttachments, preserveAttachmentCount can be nil/0
	}
	
	// Subpass dependency (optional but good for layout transitions)
	// This ensures that the render pass waits for the image to be available before writing to it,
	// and that writing is finished before the image is transitioned to PRESENT_SRC_KHR.
	dependency := vk.SubpassDependency{
		srcSubpass = vk.SUBPASS_EXTERNAL, // Implicit subpass before render pass
		dstSubpass = 0,                   // Our subpass (index 0)
		srcStageMask = {.COLOR_ATTACHMENT_OUTPUT_BIT},
		srcAccessMask = {}, // No access needs to be synchronized before this
		dstStageMask = {.COLOR_ATTACHMENT_OUTPUT_BIT},
		dstAccessMask = {.COLOR_ATTACHMENT_WRITE_BIT},
		// No dependencyFlags
	}


	render_pass_create_info := vk.RenderPassCreateInfo{
		sType = .RENDER_PASS_CREATE_INFO,
		attachmentCount = 1,
		pAttachments = &color_attachment_desc,
		subpassCount = 1,
		pSubpasses = &subpass_desc,
		dependencyCount = 1, // One dependency for now
		pDependencies = &dependency,
	}

	p_vk_allocator: ^vk.AllocationCallbacks = nil
	render_pass: vk.RenderPass

	result := vk.CreateRenderPass(logical_device, &render_pass_create_info, p_vk_allocator, &render_pass)
	if result != .SUCCESS {
		log.errorf("vkCreateRenderPass failed. Result: %v (%d)", result, int(result))
		return vk.NULL_HANDLE, .Device_Creation_Failed // Or a more specific error
	}

	log.infof("Vulkan RenderPass created successfully: %p (for format %v)", render_pass, swapchain_format)
	return render_pass, .None
}


// vk_create_pipeline_layout_internal creates a Vulkan PipelineLayout.
// For now, it's empty (no descriptor sets, no push constants).
vk_create_pipeline_layout_internal :: proc(
	logical_device: vk.Device,
	// allocator: mem.Allocator, // Not needed for local stack allocations
) -> (vk.PipelineLayout, gfx_interface.Gfx_Error) {
	
	layout_create_info := vk.PipelineLayoutCreateInfo{
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = 0, // No descriptor set layouts yet
		pSetLayouts = nil,
		pushConstantRangeCount = 0, // No push constants yet
		pPushConstantRanges = nil,
	}

	p_vk_allocator: ^vk.AllocationCallbacks = nil
	pipeline_layout: vk.PipelineLayout

	result := vk.CreatePipelineLayout(logical_device, &layout_create_info, p_vk_allocator, &pipeline_layout)
	if result != .SUCCESS {
		log.errorf("vkCreatePipelineLayout failed. Result: %v (%d)", result, int(result))
		return vk.NULL_HANDLE, .Device_Creation_Failed // Or a more specific error
	}
	
	log.infof("Vulkan PipelineLayout created successfully (empty): %p", pipeline_layout)
	return pipeline_layout, .None
}


// vk_create_pipeline_internal creates the Vulkan graphics pipeline.
vk_create_pipeline_internal :: proc(
	gfx_device: gfx_interface.Gfx_Device,
	shaders: []gfx_interface.Gfx_Shader,
	render_pass_handle: vk.RenderPass,     // Passed from wrapper
	pipeline_layout_handle: vk.PipelineLayout, // Passed from wrapper
	// Vertex input state parameters, derived from the active VAO by the wrapper
	vertex_bindings: []Vk_Vertex_Input_Binding_Description, 
	vertex_attributes: []Vk_Vertex_Input_Attribute_Description,
) -> (gfx_interface.Gfx_Pipeline, gfx_interface.Gfx_Error) {

	vk_dev_internal, ok_dev := gfx_device.variant.(Vk_Device_Variant)
	if !ok_dev || vk_dev_internal == nil {
		log.error("vk_create_pipeline: Invalid Gfx_Device (not Vulkan or nil variant).")
		return gfx_interface.Gfx_Pipeline{}, .Invalid_Handle
	}
	allocator := vk_dev_internal.allocator // Use device's allocator for Vk_Pipeline_Internal struct

	if len(shaders) == 0 {
		log.error("Cannot create pipeline: no shaders provided.")
		return gfx_interface.Gfx_Pipeline{}, .Shader_Compilation_Failed // Or Invalid_Parameter
	}
	if render_pass_handle == vk.NULL_HANDLE {
		log.error("Cannot create pipeline: invalid render_pass_handle provided.")
		return gfx_interface.Gfx_Pipeline{}, .Invalid_Handle
	}
	if pipeline_layout_handle == vk.NULL_HANDLE {
		log.error("Cannot create pipeline: invalid pipeline_layout_handle provided.")
		return gfx_interface.Gfx_Pipeline{}, .Invalid_Handle
	}


	// 1. Shader Stages
	// Convert []Gfx_Shader to []vk.PipelineShaderStageCreateInfo
	// Use a temporary allocator for the slice of shader stage create infos.
	shader_stage_create_infos := make([dynamic]vk.PipelineShaderStageCreateInfo, 0, len(shaders), context.temp_allocator)
	defer delete(shader_stage_create_infos) // Frees the dynamic array's buffer

	entry_point_name := "main" // Standard entry point name for GLSL shaders

	for _, gfx_shader_handle in shaders {
		vk_shader_ptr, ok_shader := gfx_shader_handle.variant.(^Vk_Shader_Internal)
		if !ok_shader || vk_shader_ptr == nil {
			log.errorf("Invalid shader handle provided to pipeline creation. Variant: %v", gfx_shader_handle.variant)
			return gfx_interface.Gfx_Pipeline{}, .Invalid_Handle
		}
		shader_internal := vk_shader_ptr^

		stage_create_info := vk.PipelineShaderStageCreateInfo{
			sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage = shader_internal.stage,
			module = shader_internal.module,
			pName = entry_point_name, // Must be null-terminated string
			// pSpecializationInfo can be nil if no specialization constants
		}
		append(&shader_stage_create_infos, stage_create_info)
		log.debugf("Pipeline: Added shader module %p for stage %v", shader_internal.module, shader_internal.stage)
	}

	// 2. Vertex Input State
	// Uses the binding and attribute descriptions passed in (from active VAO)
	vertex_input_state_create_info := vk.PipelineVertexInputStateCreateInfo{
		sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		vertexBindingDescriptionCount = u32(len(vertex_bindings)),
		pVertexBindingDescriptions = rawptr(vertex_bindings.data) if len(vertex_bindings) > 0 else nil,
		vertexAttributeDescriptionCount = u32(len(vertex_attributes)),
		pVertexAttributeDescriptions = rawptr(vertex_attributes.data) if len(vertex_attributes) > 0 else nil,
	}
	if len(vertex_bindings) > 0 || len(vertex_attributes) > 0 {
		log.debugf("Pipeline: Vertex Input State: Bindings: %d, Attributes: %d.", len(vertex_bindings), len(vertex_attributes))
	} else {
		log.debug("Pipeline: Vertex Input State: No bindings, no attributes (empty VAO or default).")
	}

	// 3. Input Assembly State
	input_assembly_state_create_info := vk.PipelineInputAssemblyStateCreateInfo{
		sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
		topology = .TRIANGLE_LIST,
		primitiveRestartEnable = vk.FALSE,
	}
	log.debugf("Pipeline: Input Assembly State: Topology %v", input_assembly_state_create_info.topology)

	// 4. Viewport State (Viewport and Scissor will be dynamic)
	viewport_state_create_info := vk.PipelineViewportStateCreateInfo{
		sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		viewportCount = 1, // One viewport
		pViewports = nil,  // Dynamic, so nil here
		scissorCount = 1,  // One scissor
		pScissors = nil,   // Dynamic, so nil here
	}
	log.debug("Pipeline: Viewport State: 1 viewport, 1 scissor (dynamic).")

	// 5. Rasterization State
	rasterization_state_create_info := vk.PipelineRasterizationStateCreateInfo{
		sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		depthClampEnable = vk.FALSE,
		rasterizerDiscardEnable = vk.FALSE, // FALSE means geometry passes to fragment shader
		polygonMode = .FILL,
		lineWidth = 1.0, // Required even if not drawing lines
		cullMode = {.BACK_BIT}, // Cull back faces
		frontFace = .COUNTER_CLOCKWISE, // Or .CLOCKWISE, depends on vertex winding order
		depthBiasEnable = vk.FALSE,
		// depthBiasConstantFactor, depthBiasClamp, depthBiasSlopeFactor = 0
	}
	log.debugf("Pipeline: Rasterization State: PolygonMode %v, CullMode %v, FrontFace %v", 
		rasterization_state_create_info.polygonMode, rasterization_state_create_info.cullMode, rasterization_state_create_info.frontFace)

	// 6. Multisample State
	multisample_state_create_info := vk.PipelineMultisampleStateCreateInfo{
		sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
		sampleShadingEnable = vk.FALSE, // Disable sample shading
		rasterizationSamples = .SAMPLE_COUNT_1_BIT, // No MSAA for now
		// minSampleShading, pSampleMask, alphaToCoverageEnable, alphaToOneEnable can be default/0/nil
	}
	log.debugf("Pipeline: Multisample State: Samples %v", multisample_state_create_info.rasterizationSamples)

	// 7. Depth/Stencil State (Not used for now, but a placeholder might be needed)
	// For now, no depth/stencil test.
	// depth_stencil_state_create_info := vk.PipelineDepthStencilStateCreateInfo{...}
	// If not using depth/stencil, pDepthStencilState in VkGraphicsPipelineCreateInfo can be nil.
	// However, if a render pass has a depth/stencil attachment, this must be configured.
	// Our current render pass does not have one.
	log.debug("Pipeline: Depth/Stencil State: Disabled (not configured).")


	// 8. Color Blend State (One attachment, no blending)
	color_blend_attachment_state := vk.PipelineColorBlendAttachmentState{
		colorWriteMask = vk.ColorComponentFlags{.R_BIT, .G_BIT, .B_BIT, .A_BIT},
		blendEnable = vk.FALSE, // No blending for now
		// srcColorBlendFactor, dstColorBlendFactor, colorBlendOp, etc. are ignored if blendEnable is FALSE
	}

	color_blend_state_create_info := vk.PipelineColorBlendStateCreateInfo{
		sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		logicOpEnable = vk.FALSE, // Logic op disabled
		// logicOp = .COPY, // Optional if logicOpEnable is FALSE
		attachmentCount = 1,
		pAttachments = &color_blend_attachment_state, // Pointer to array of blend attachment states
		// blendConstants[4] can be default
	}
	log.debug("Pipeline: Color Blend State: Blending disabled, 1 attachment.")

	// 9. Dynamic State
	dynamic_states_arr: [2]vk.DynamicState = {.VIEWPORT, .SCISSOR}
	dynamic_state_create_info := vk.PipelineDynamicStateCreateInfo{
		sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		dynamicStateCount = u32(len(dynamic_states_arr)),
		pDynamicStates = &dynamic_states_arr[0],
	}
	log.debugf("Pipeline: Dynamic States: %v", dynamic_states_arr[:])

	// 10. Graphics Pipeline Create Info
	pipeline_create_info := vk.GraphicsPipelineCreateInfo{
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
		stageCount = u32(len(shader_stage_create_infos)),
		pStages = shader_stage_create_infos.data,
		pVertexInputState = &vertex_input_state_create_info,
		pInputAssemblyState = &input_assembly_state_create_info,
		// pTessellationState = nil, // No tessellation
		pViewportState = &viewport_state_create_info,
		pRasterizationState = &rasterization_state_create_info,
		pMultisampleState = &multisample_state_create_info,
		pDepthStencilState = nil, // No depth/stencil testing for now
		pColorBlendState = &color_blend_state_create_info,
		pDynamicState = &dynamic_state_create_info,
		layout = pipeline_layout_handle, // Use the passed-in layout
		renderPass = render_pass_handle, // Use the passed-in render pass
		subpass = 0, // Index of the subpass where this pipeline will be used
		// basePipelineHandle = vk.NULL_HANDLE, // Optional: for deriving from another pipeline
		// basePipelineIndex = -1,             // Optional
	}

	// 11. Create Graphics Pipeline
	p_vk_allocator: ^vk.AllocationCallbacks = nil
	graphics_pipeline: vk.Pipeline

	// vk.CreateGraphicsPipelines takes an array of create infos and returns an array of pipelines.
	// We are creating a single pipeline.
	result := vk.CreateGraphicsPipelines(vk_dev_internal.logical_device, vk.NULL_HANDLE, 1, &pipeline_create_info, p_vk_allocator, &graphics_pipeline)
	if result != .SUCCESS {
		log.errorf("vkCreateGraphicsPipelines failed. Result: %v (%d)", result, int(result))
		// Note: If this fails, render_pass_handle and pipeline_layout_handle are owned by the caller (wrapper)
		// and should be destroyed there if this function returns an error.
		return gfx_interface.Gfx_Pipeline{}, .Device_Creation_Failed // Or more specific error
	}
	log.infof("Vulkan Graphics Pipeline created successfully: %p", graphics_pipeline)

	// 12. Store pipeline and related info
	vk_pipeline_internal := new(Vk_Pipeline_Internal, allocator)
	vk_pipeline_internal.pipeline = graphics_pipeline
	vk_pipeline_internal.pipeline_layout = pipeline_layout_handle // Store the passed-in layout
	vk_pipeline_internal.render_pass = render_pass_handle       // Store the passed-in render pass
	vk_pipeline_internal.device_ref = vk_dev_internal
	vk_pipeline_internal.allocator = allocator

	return gfx_interface.Gfx_Pipeline{variant = vk_pipeline_internal}, .None
}


// vk_destroy_pipeline_internal destroys the Vulkan pipeline and its layout.
// vk_destroy_pipeline_internal destroys the Vulkan pipeline and its layout.
// The RenderPass is now owned by the window/swapchain, so it's not destroyed here.
vk_destroy_pipeline_internal :: proc(pipeline_handle: gfx_interface.Gfx_Pipeline) {
	vk_pipe_ptr, ok_pipe := pipeline_handle.variant.(^Vk_Pipeline_Internal)
	if !ok_pipe || vk_pipe_ptr == nil {
		log.errorf("vk_destroy_pipeline: Invalid Gfx_Pipeline type or nil variant (%v).", pipeline_handle.variant)
		return
	}

	vk_pipeline_internal := vk_pipe_ptr^ // Dereference to get the struct
	logical_device := vk_pipeline_internal.device_ref.logical_device
	p_vk_allocator: ^vk.AllocationCallbacks = nil

	if vk_pipeline_internal.pipeline != vk.NULL_HANDLE {
		log.infof("Destroying Vulkan Graphics Pipeline: %p", vk_pipeline_internal.pipeline)
		vk.DestroyPipeline(logical_device, vk_pipeline_internal.pipeline, p_vk_allocator)
	}
	if vk_pipeline_internal.pipeline_layout != vk.NULL_HANDLE {
		log.infof("Destroying Vulkan PipelineLayout: %p", vk_pipeline_internal.pipeline_layout)
		vk.DestroyPipelineLayout(logical_device, vk_pipeline_internal.pipeline_layout, p_vk_allocator)
	}
	// RenderPass (vk_pipeline_internal.render_pass) is not destroyed here as it's assumed to be owned by the window.
	// If it were a pipeline-specific render pass, it would be destroyed here.
	log.debugf("RenderPass %p associated with pipeline %p was not destroyed by pipeline (owned by window/swapchain).",
		vk_pipeline_internal.render_pass, vk_pipeline_internal.pipeline)
	
	// Free the Vk_Pipeline_Internal struct itself
	free(vk_pipe_ptr, vk_pipeline_internal.allocator)
	log.info("Vk_Pipeline_Internal struct freed.")
}
