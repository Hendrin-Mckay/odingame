package vulkan

import vk "vendor:vulkan"
import "core:log"
import "core:mem"
import "../gfx_interface" 
import "../../common" 
import "./vk_types" // Added for Vk_Device_Variant, Vk_Shader_Internal, Vk_Pipeline_Internal, Vk_Vertex_Input_Binding_Description, Vk_Vertex_Input_Attribute_Description

// vk_create_render_pass_internal creates a simple Vulkan RenderPass.
vk_create_render_pass_internal :: proc(
	logical_device: vk.Device,
	swapchain_format: vk.Format, 
) -> (vk.RenderPass, common.Engine_Error) {

	color_attachment_desc := vk.AttachmentDescription{
		format = swapchain_format,
		samples = .SAMPLE_COUNT_1_BIT,
		loadOp = .CLEAR,             
		storeOp = .STORE,            
		stencilLoadOp = .DONT_CARE,  
		stencilStoreOp = .DONT_CARE, 
		initialLayout = .UNDEFINED,  
		finalLayout = .PRESENT_SRC_KHR, 
	}

	color_attachment_ref := vk.AttachmentReference{
		attachment = 0, 
		layout = .COLOR_ATTACHMENT_OPTIMAL, 
	}

	subpass_desc := vk.SubpassDescription{
		pipelineBindPoint = .GRAPHICS,
		colorAttachmentCount = 1,
		pColorAttachments = &color_attachment_ref,
	}
	
	dependency := vk.SubpassDependency{
		srcSubpass = vk.SUBPASS_EXTERNAL, 
		dstSubpass = 0,                  
		srcStageMask = {.COLOR_ATTACHMENT_OUTPUT_BIT},
		srcAccessMask = {}, 
		dstStageMask = {.COLOR_ATTACHMENT_OUTPUT_BIT},
		dstAccessMask = {.COLOR_ATTACHMENT_WRITE_BIT},
	}

	render_pass_create_info := vk.RenderPassCreateInfo{
		sType = .RENDER_PASS_CREATE_INFO,
		attachmentCount = 1,
		pAttachments = &color_attachment_desc,
		subpassCount = 1,
		pSubpasses = &subpass_desc,
		dependencyCount = 1, 
		pDependencies = &dependency,
	}

	p_vk_allocator: ^vk.AllocationCallbacks = nil
	render_pass: vk.RenderPass

	result := vk.CreateRenderPass(logical_device, &render_pass_create_info, p_vk_allocator, &render_pass)
	if result != .SUCCESS {
		log.errorf("vkCreateRenderPass failed. Result: %v (%d)", result, int(result))
		return vk.NULL_HANDLE, common.Engine_Error.Device_Creation_Failed 
	}

	log.infof("Vulkan RenderPass created successfully: %p (for format %v)", render_pass, swapchain_format)
	return render_pass, .None
}


// vk_create_pipeline_layout_internal creates a Vulkan PipelineLayout.
// Now accepts descriptor_set_layouts.
vk_create_pipeline_layout_internal :: proc(
	logical_device: vk.Device,
    descriptor_set_layouts: []vk.DescriptorSetLayout, // Added parameter
	// allocator: mem.Allocator, // Not needed for local stack allocations
) -> (vk.PipelineLayout, common.Engine_Error) {
	
	layout_create_info := vk.PipelineLayoutCreateInfo{
		sType = .PIPELINE_LAYOUT_CREATE_INFO,
		setLayoutCount = u32(len(descriptor_set_layouts)),       // Use provided layouts
		pSetLayouts = rawptr(descriptor_set_layouts.data) if len(descriptor_set_layouts) > 0 else nil, // Use provided layouts
		pushConstantRangeCount = 0, // No push constants yet
		pPushConstantRanges = nil,
	}

	p_vk_allocator: ^vk.AllocationCallbacks = nil
	pipeline_layout: vk.PipelineLayout

	result := vk.CreatePipelineLayout(logical_device, &layout_create_info, p_vk_allocator, &pipeline_layout)
	if result != .SUCCESS {
		log.errorf("vkCreatePipelineLayout failed. Result: %v (%d)", result, int(result))
		return vk.NULL_HANDLE, common.Engine_Error.Device_Creation_Failed 
	}
	
    if len(descriptor_set_layouts) > 0 {
	    log.infof("Vulkan PipelineLayout created successfully: %p with %d descriptor set layout(s).", pipeline_layout, len(descriptor_set_layouts))
    } else {
        log.infof("Vulkan PipelineLayout created successfully (empty): %p", pipeline_layout)
    }
	return pipeline_layout, .None
}


// vk_create_pipeline_internal creates the Vulkan graphics pipeline.
vk_create_pipeline_internal :: proc(
	gfx_device: gfx_interface.Gfx_Device,
	shaders: []gfx_interface.Gfx_Shader,
	render_pass_handle: vk.RenderPass,     
	// pipeline_layout_handle is now created inside this function
	// Vertex input state parameters, derived from the active VAO by the wrapper
	vertex_bindings: []vk_types.Vk_Vertex_Input_Binding_Description, 
	vertex_attributes: []vk_types.Vk_Vertex_Input_Attribute_Description,
) -> (gfx_interface.Gfx_Pipeline, common.Engine_Error) {

	vk_dev_internal, ok_dev := gfx_device.variant.(vk_types.Vk_Device_Variant)
	if !ok_dev || vk_dev_internal == nil {
		return gfx_interface.Gfx_Pipeline{}, common.Engine_Error.Invalid_Handle
	}
	allocator := vk_dev_internal.allocator 
	logical_device := vk_dev_internal.logical_device

	if len(shaders) == 0 { return gfx_interface.Gfx_Pipeline{}, common.Engine_Error.Shader_Compilation_Failed }
	if render_pass_handle == vk.NULL_HANDLE { return gfx_interface.Gfx_Pipeline{}, common.Engine_Error.Invalid_Handle }

    // --- Create DescriptorSetLayout(s) ---
    // For this task, assume a predefined layout: 
    // Binding 0: UniformBuffer (Vertex Stage)
    // Binding 1: CombinedImageSampler (Fragment Stage)
    dsl_bindings := [2]Vk_Descriptor_Set_Layout_Binding_Info {
        { binding = 0, descriptor_type = .UNIFORM_BUFFER, descriptor_count = 1, stage_flags = {.VERTEX_BIT} },
        { binding = 1, descriptor_type = .COMBINED_IMAGE_SAMPLER, descriptor_count = 1, stage_flags = {.FRAGMENT_BIT} },
    }
    // Use context.temp_allocator or pass allocator if vk_create_descriptor_set_layout_internal needs it for temporary arrays
    // Assuming vk_create_descriptor_set_layout_internal handles its own temporary allocations.
    single_descriptor_set_layout, dsl_err := vk_create_descriptor_set_layout_internal(vk_dev_internal, dsl_bindings[:])
    if dsl_err != .None {
        log.errorf("Failed to create descriptor set layout for pipeline: %v", dsl_err)
        return gfx_interface.Gfx_Pipeline{}, dsl_err
    }
    // Store it for cleanup if pipeline layout creation fails
    // And it will be stored in Vk_Pipeline_Internal

    descriptor_set_layouts_for_pipeline_layout := [1]vk.DescriptorSetLayout{single_descriptor_set_layout}

    // --- Create PipelineLayout ---
    pipeline_layout_handle, pl_err := vk_create_pipeline_layout_internal(logical_device, descriptor_set_layouts_for_pipeline_layout[:])
    if pl_err != .None {
        log.errorf("Failed to create pipeline layout: %v", pl_err)
        vk_destroy_descriptor_set_layout_internal(vk_dev_internal, single_descriptor_set_layout) // Cleanup created DSL
        return gfx_interface.Gfx_Pipeline{}, pl_err
    }
    // pipeline_layout_handle is now created here.

	shader_stage_create_infos := make([dynamic]vk.PipelineShaderStageCreateInfo, 0, len(shaders), context.temp_allocator)
	defer delete(shader_stage_create_infos) 

	entry_point_name := "main" 

	for _, gfx_shader_handle in shaders {
		vk_shader_ptr, ok_shader := gfx_shader_handle.variant.(^vk_types.Vk_Shader_Internal)
		if !ok_shader || vk_shader_ptr == nil {
            vk_destroy_descriptor_set_layout_internal(vk_dev_internal, single_descriptor_set_layout)
            vk.DestroyPipelineLayout(logical_device, pipeline_layout_handle, nil)
			return gfx_interface.Gfx_Pipeline{}, common.Engine_Error.Invalid_Handle
		}
		shader_internal := vk_shader_ptr^

		stage_create_info := vk.PipelineShaderStageCreateInfo{
			sType = .PIPELINE_SHADER_STAGE_CREATE_INFO,
			stage = shader_internal.stage,
			module = shader_internal.module,
			pName = entry_point_name, 
		}
		append(&shader_stage_create_infos, stage_create_info)
	}

	vertex_input_state_create_info := vk.PipelineVertexInputStateCreateInfo{
		sType = .PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO,
		vertexBindingDescriptionCount = u32(len(vertex_bindings)),
		pVertexBindingDescriptions = rawptr(vertex_bindings.data) if len(vertex_bindings) > 0 else nil,
		vertexAttributeDescriptionCount = u32(len(vertex_attributes)),
		pVertexAttributeDescriptions = rawptr(vertex_attributes.data) if len(vertex_attributes) > 0 else nil,
	}

	input_assembly_state_create_info := vk.PipelineInputAssemblyStateCreateInfo{
		sType = .PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO,
		topology = .TRIANGLE_LIST,
		primitiveRestartEnable = vk.FALSE,
	}

	viewport_state_create_info := vk.PipelineViewportStateCreateInfo{
		sType = .PIPELINE_VIEWPORT_STATE_CREATE_INFO,
		viewportCount = 1, 
		pViewports = nil,  
		scissorCount = 1,  
		pScissors = nil,   
	}

	rasterization_state_create_info := vk.PipelineRasterizationStateCreateInfo{
		sType = .PIPELINE_RASTERIZATION_STATE_CREATE_INFO,
		depthClampEnable = vk.FALSE,
		rasterizerDiscardEnable = vk.FALSE, 
		polygonMode = .FILL,
		lineWidth = 1.0, 
		cullMode = {.BACK_BIT}, 
		frontFace = .COUNTER_CLOCKWISE, 
		depthBiasEnable = vk.FALSE,
	}

	multisample_state_create_info := vk.PipelineMultisampleStateCreateInfo{
		sType = .PIPELINE_MULTISAMPLE_STATE_CREATE_INFO,
		sampleShadingEnable = vk.FALSE, 
		rasterizationSamples = .SAMPLE_COUNT_1_BIT, 
	}

	color_blend_attachment_state := vk.PipelineColorBlendAttachmentState{
		colorWriteMask = vk.ColorComponentFlags{.R_BIT, .G_BIT, .B_BIT, .A_BIT},
		blendEnable = vk.FALSE, 
	}

	color_blend_state_create_info := vk.PipelineColorBlendStateCreateInfo{
		sType = .PIPELINE_COLOR_BLEND_STATE_CREATE_INFO,
		logicOpEnable = vk.FALSE, 
		attachmentCount = 1,
		pAttachments = &color_blend_attachment_state, 
	}

	dynamic_states_arr: [2]vk.DynamicState = {.VIEWPORT, .SCISSOR}
	dynamic_state_create_info := vk.PipelineDynamicStateCreateInfo{
		sType = .PIPELINE_DYNAMIC_STATE_CREATE_INFO,
		dynamicStateCount = u32(len(dynamic_states_arr)),
		pDynamicStates = &dynamic_states_arr[0],
	}

	pipeline_create_info := vk.GraphicsPipelineCreateInfo{
		sType = .GRAPHICS_PIPELINE_CREATE_INFO,
		stageCount = u32(len(shader_stage_create_infos)),
		pStages = shader_stage_create_infos.data,
		pVertexInputState = &vertex_input_state_create_info,
		pInputAssemblyState = &input_assembly_state_create_info,
		pViewportState = &viewport_state_create_info,
		pRasterizationState = &rasterization_state_create_info,
		pMultisampleState = &multisample_state_create_info,
		pDepthStencilState = nil, 
		pColorBlendState = &color_blend_state_create_info,
		pDynamicState = &dynamic_state_create_info,
		layout = pipeline_layout_handle, 
		renderPass = render_pass_handle, 
		subpass = 0, 
	}

	p_vk_allocator: ^vk.AllocationCallbacks = nil
	graphics_pipeline: vk.Pipeline

	result := vk.CreateGraphicsPipelines(logical_device, vk.NULL_HANDLE, 1, &pipeline_create_info, p_vk_allocator, &graphics_pipeline)
	if result != .SUCCESS {
		log.errorf("vkCreateGraphicsPipelines failed. Result: %v (%d)", result, int(result))
        vk_destroy_descriptor_set_layout_internal(vk_dev_internal, single_descriptor_set_layout)
        vk.DestroyPipelineLayout(logical_device, pipeline_layout_handle, nil)
		return gfx_interface.Gfx_Pipeline{}, common.Engine_Error.Device_Creation_Failed 
	}
	log.infof("Vulkan Graphics Pipeline created successfully: %p", graphics_pipeline)

	vk_pipeline_internal := new(vk_types.Vk_Pipeline_Internal, allocator)
	vk_pipeline_internal.pipeline = graphics_pipeline
	vk_pipeline_internal.pipeline_layout = pipeline_layout_handle 
    // Store the descriptor set layouts
    vk_pipeline_internal.descriptor_set_layouts = make([]vk.DescriptorSetLayout, len(descriptor_set_layouts_for_pipeline_layout), allocator)
    // copy(vk_pipeline_internal.descriptor_set_layouts, descriptor_set_layouts_for_pipeline_layout[:])
    // This needs to be a proper copy if the slice passed to vkCreatePipelineLayout was temporary.
    // For now, it's a single layout, so:
    vk_pipeline_internal.descriptor_set_layouts = []vk.DescriptorSetLayout{single_descriptor_set_layout} 
                                                // This slice now shares the handle.
                                                // If single_descriptor_set_layout is destroyed before pipeline, this is bad.
                                                // The Vk_Pipeline_Internal now "owns" these.

	// vk_pipeline_internal.render_pass = render_pass_handle // render_pass is already part of Vk_Pipeline_Internal from previous task
	vk_pipeline_internal.device_ref = vk_dev_internal
	vk_pipeline_internal.allocator = allocator

	return gfx_interface.Gfx_Pipeline{variant = vk_pipeline_internal}, .None
}

vk_destroy_pipeline_internal :: proc(pipeline_handle: gfx_interface.Gfx_Pipeline) -> common.Engine_Error {
	if pipeline_handle.variant == nil {
		log.error("vk_destroy_pipeline_internal: Gfx_Pipeline variant is nil.")
		return common.Engine_Error.Invalid_Handle
	}

	vk_pipe_ptr, ok_pipe := pipeline_handle.variant.(^vk_types.Vk_Pipeline_Internal)
	if !ok_pipe || vk_pipe_ptr == nil {
		log.errorf("vk_destroy_pipeline_internal: Invalid Gfx_Pipeline variant type (%T) or nil pointer.", pipeline_handle.variant)
		return common.Engine_Error.Invalid_Handle
	}

	if vk_pipe_ptr.device_ref == nil {
		log.errorf("vk_destroy_pipeline_internal: Pipeline (handle %p) has nil device_ref.", vk_pipe_ptr.pipeline)
		// Cannot proceed with Vulkan cleanup without device. Freeing struct memory is still important.
		free(vk_pipe_ptr, vk_pipe_ptr.allocator) 
		log.warn("Vk_Pipeline_Internal struct freed, but Vulkan resources may remain due to nil device_ref.")
		return common.Engine_Error.Invalid_Handle 
	}
	logical_device := vk_pipe_ptr.device_ref.logical_device
	if logical_device == vk.NULL_HANDLE {
		log.errorf("vk_destroy_pipeline_internal: Pipeline (handle %p) has nil logical_device in device_ref.", vk_pipe_ptr.pipeline)
		free(vk_pipe_ptr, vk_pipe_ptr.allocator)
		log.warn("Vk_Pipeline_Internal struct freed, but Vulkan resources may remain due to nil logical_device.")
		return common.Engine_Error.Invalid_Handle
	}
	
	p_vk_allocator: ^vk.AllocationCallbacks = nil
	overall_error: common.Engine_Error = .None

	// Destroy actual Vulkan pipeline
	if vk_pipe_ptr.pipeline != vk.NULL_HANDLE {
		log.infof("Destroying Vulkan Pipeline: %p on device %p", vk_pipe_ptr.pipeline, logical_device)
		vk.DestroyPipeline(logical_device, vk_pipe_ptr.pipeline, p_vk_allocator)
	} else {
		log.warn("vk_destroy_pipeline_internal: pipeline field in Vk_Pipeline_Internal is vk.NULL_HANDLE.")
	}

    // Destroy descriptor set layouts owned by this pipeline
    if vk_pipe_ptr.descriptor_set_layouts != nil {
        log.infof("Destroying %d descriptor set layout(s) for pipeline %p.", len(vk_pipe_ptr.descriptor_set_layouts), vk_pipe_ptr.pipeline)
        for i, layout in vk_pipe_ptr.descriptor_set_layouts {
            // vk_destroy_descriptor_set_layout_internal handles nil layout gracefully.
            err := vk_destroy_descriptor_set_layout_internal(vk_pipe_ptr.device_ref, layout)
            if err != .None {
                log.errorf("vk_destroy_pipeline_internal: Failed to destroy descriptor_set_layout[%d] (%p) for pipeline %p: %v. Continuing cleanup.", 
                    i, layout, vk_pipe_ptr.pipeline, err)
                if overall_error == .None { overall_error = err } // Capture first error
            }
        }
        // Free the slice structure itself after destroying its contents.
        // This assumes the slice was allocated by this pipeline's allocator.
        // If it was pointing to layouts owned elsewhere or a fixed array, this delete might be wrong.
        // Given it's `make`d in create_pipeline, deleting is likely correct.
        log.infof("Deleting descriptor_set_layouts slice for pipeline %p.", vk_pipe_ptr.pipeline)
        delete(vk_pipe_ptr.descriptor_set_layouts, vk_pipe_ptr.allocator) 
    } else {
        log.info("vk_destroy_pipeline_internal: No descriptor_set_layouts slice to destroy.")
    }

	// Destroy pipeline layout
	if vk_pipe_ptr.pipeline_layout != vk.NULL_HANDLE {
		log.infof("Destroying Vulkan PipelineLayout: %p on device %p", vk_pipe_ptr.pipeline_layout, logical_device)
		vk.DestroyPipelineLayout(logical_device, vk_pipe_ptr.pipeline_layout, p_vk_allocator)
	} else {
		log.warn("vk_destroy_pipeline_internal: pipeline_layout field in Vk_Pipeline_Internal is vk.NULL_HANDLE.")
	}
	
	log.infof("Freeing Vk_Pipeline_Internal struct (allocator: %p) for pipeline %p", vk_pipe_ptr.allocator, vk_pipe_ptr.pipeline)
	free(vk_pipe_ptr, vk_pipe_ptr.allocator)
	// log.info("Vk_Pipeline_Internal struct and associated resources freed.") // Covered by infof

	return overall_error
}
