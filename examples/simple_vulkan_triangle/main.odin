package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:strings"

import "odingame:core"
import gfx "odingame:graphics" 
import gfx_types "../../odingame/graphics/types" // For Vertex_Attribute, Vertex_Buffer_Layout_Desc etc.
// Renamed to avoid conflict with local 'graphics' if any, and for brevity
// import "odingame:math" // Not used in this example yet

// Vertex struct definition
Vertex :: struct {
	pos: [2]f32, // x, y
	col: [3]f32, // r, g, b
}

// Triangle vertices data
triangle_vertices := [?]Vertex{
    {{0.0, -0.5}, {1.0, 0.0, 0.0}},  // Top, Red
    {{0.5, 0.5},  {0.0, 1.0, 0.0}},  // Bottom Right, Green
    {{-0.5, 0.5}, {0.0, 0.0, 1.0}}, // Bottom Left, Blue
}

// VulkanTriangleState to hold resources
VulkanTriangleState :: struct {
	vertex_buffer:   gfx.Gfx_Buffer,
	vert_shader:     gfx.Gfx_Shader,
	frag_shader:     gfx.Gfx_Shader,
	vao:             gfx.Gfx_Vertex_Array,
	pipeline:        gfx.Gfx_Pipeline,
}

// Helper to read shader file (remains the same)
read_shader_file :: proc(filepath: string, allocator := context.allocator) -> (string, bool) {
	data, ok := os.read_entire_file(filepath, allocator)
	if !ok {
		log.errorf("Failed to read shader file: %s", filepath)
		return "", false
	}
	return string(data), true
}

// --- Callback Procedures ---

initialize_triangle :: proc(game: ^core.Game) {
	log.info("Initialize Triangle Callback")
	
	// Allocate VulkanTriangleState in game.user_data
	state := new(VulkanTriangleState)
	game.user_data = state

	gfx_device := game.graphics_device // Use device from game core

	// --- Create Vertex Buffer ---
	vb_size := size_of(triangle_vertices)
	log.infof("Attempting to create vertex buffer of size %d bytes.", vb_size)
	vb, vb_err := gfx.gfx_api.create_buffer(
		gfx_device,
		.Vertex,
		vb_size,
		&triangle_vertices[0],
		false, // dynamic = false
	)
	if vb_err != .None {
		log.errorf("Failed to create vertex buffer: %s", gfx.gfx_api.get_error_string(vb_err))
		// core.exit(game) // Or some other error propagation
		return 
	}
	if vb.variant == nil {
		log.error("Vertex buffer creation returned success but handle is nil.")
		// core.exit(game)
		return
	}
	state.vertex_buffer = vb
	log.info("Vertex buffer created successfully.")

	// --- Load Shaders ---
	vert_shader_path := "shaders/simple_triangle.vert"
	frag_shader_path := "shaders/simple_triangle.frag"

	vert_shader_source, ok_vs := read_shader_file(vert_shader_path)
	if !ok_vs { /* core.exit(game); */ return }
	defer delete(vert_shader_source) 

	frag_shader_source, ok_fs := read_shader_file(frag_shader_path)
	if !ok_fs { /* core.exit(game); */ return }
	defer delete(frag_shader_source)
	log.info("Read shader sources.")

	vs, vs_err := gfx.gfx_api.create_shader_from_source(gfx_device, vert_shader_source, .Vertex)
	if vs_err != .None {
		log.errorf("Failed to create vertex shader: %s", gfx.gfx_api.get_error_string(vs_err))
		// core.exit(game)
		return
	}
	if vs.variant == nil { log.error("Vertex shader creation success but handle is nil."); /* core.exit(game); */ return }
	state.vert_shader = vs
	log.info("Vertex shader created successfully.")

	fs, fs_err := gfx.gfx_api.create_shader_from_source(gfx_device, frag_shader_source, .Fragment)
	if fs_err != .None {
		log.errorf("Failed to create fragment shader: %s", gfx.gfx_api.get_error_string(fs_err))
		// core.exit(game)
		return
	}
	if fs.variant == nil { log.error("Fragment shader creation success but handle is nil."); /* core.exit(game); */ return }
	state.frag_shader = fs
	log.info("Fragment shader created successfully.")

	// --- Create Vertex Array (VAO) ---
	vertex_attributes: []gfx.Vertex_Attribute = {
		{location = 0, buffer_binding = 0, format = .Float32_X2, offset_in_bytes = offset_of(Vertex, pos)},
		{location = 1, buffer_binding = 0, format = .Float32_X3, offset_in_bytes = offset_of(Vertex, col)},
	}
	vertex_buffer_layouts: []gfx.Vertex_Buffer_Layout = {
		{binding = 0, stride_in_bytes = size_of(Vertex), attributes = vertex_attributes},
	}
	vao_vertex_buffers := [1]gfx.Gfx_Buffer{state.vertex_buffer}
	v_array, vao_err := gfx.gfx_api.create_vertex_array(
		gfx_device,
		vertex_buffer_layouts[:],
		vao_vertex_buffers[:],
		gfx.Gfx_Buffer{}, // No index buffer
	)
	if vao_err != .None {
		log.errorf("Failed to create VAO: %s", gfx.gfx_api.get_error_string(vao_err))
		// core.exit(game)
		return
	}
	if v_array.variant == nil { log.error("VAO creation success but handle is nil."); /* core.exit(game); */ return }
	state.vao = v_array
	log.info("VAO created successfully.")

	// --- Create Pipeline ---
	gfx.gfx_api.bind_vertex_array(gfx_device, state.vao) // VAO must be bound before pipeline creation for some backends (GL)
	                                                    // For Vulkan, pipeline needs to know the vertex input layout.
	
	pipeline_shaders := [2]gfx.Gfx_Shader{state.vert_shader, state.frag_shader}

	// Define Vertex Attributes using gfx_types
	vertex_attributes_desc := [dynamic]gfx_types.Vertex_Attribute{
		gfx_types.Vertex_Attribute{
			location = 0,
			format   = .Float2, // Corresponds to Vertex.pos ([2]f32)
			offset   = offset_of(Vertex, pos), // Use offset_of for safety
		},
		gfx_types.Vertex_Attribute{
			location = 1,
			format   = .Float3, // Corresponds to Vertex.col ([3]f32)
			offset   = offset_of(Vertex, col), // Use offset_of for safety
		},
	}

	// Define Vertex Buffer Layout Description using gfx_types
	// This describes a single buffer binding (index 0)
	vertex_buffer_layout_desc := gfx_types.Vertex_Buffer_Layout_Desc{
		buffer_index = 0, // Matches binding = 0 in VAO setup
		layout = gfx_types.Gfx_Vertex_Layout_Desc{
			attributes = vertex_attributes_desc,
			stride     = size_of(Vertex), // Stride for the entire Vertex struct
			step_rate  = .Per_Vertex,     // Or .Per_Instance if instanced
		},
	}

	// Create Pipeline Description Overrides
	// The Gfx_Pipeline_Desc_Optional_Overrides allows specifying parts of the pipeline state.
	// We're focusing on vertex_input_state.
	pipeline_desc_overrides := gfx_types.Gfx_Pipeline_Desc_Optional_Overrides{}
	
	// Setup vertex_input_state
	// Note: make() is for dynamic arrays. We need to allocate the inner dynamic array for attributes.
	// The vertex_buffer_layouts itself is a dynamic array within Gfx_Vertex_Input_State_Desc.
	vis_desc := gfx_types.Gfx_Vertex_Input_State_Desc{
		vertex_buffer_layouts = make([dynamic]gfx_types.Vertex_Buffer_Layout_Desc, context.temp_allocator), // Use an allocator
	}
	append(&vis_desc.vertex_buffer_layouts, vertex_buffer_layout_desc)
	
	pipeline_desc_overrides.vertex_input_state = vis_desc // Assign the populated Gfx_Vertex_Input_State_Desc

	// Create pipeline using the shaders and the descriptor overrides
	pipe, pipe_err := gfx.gfx_api.create_pipeline(gfx_device, pipeline_shaders[:], pipeline_desc_overrides)
	if pipe_err != .None {
		log.errorf("Failed to create pipeline: %s", gfx.gfx_api.get_error_string(pipe_err))
		// core.exit(game)
		return
	}
	if pipe.variant == nil { log.error("Pipeline creation success but handle is nil."); /* core.exit(game); */ return }
	state.pipeline = pipe
	log.info("Graphics pipeline created successfully.")
	// Unbind VAO (optional, as it will be bound in draw)
    // gfx.gfx_api.bind_vertex_array(gfx_device, gfx.Gfx_Vertex_Array{})

	// Clean up temporary allocator if used for vis_desc.vertex_buffer_layouts
	// if using context.temp_allocator, it's usually managed per-scope or frame.
	// Here, since vis_desc is local and its data is copied into the pipeline, it should be fine.
	// If vis_desc.vertex_buffer_layouts was not using temp_allocator, delete it here.
	// For now, assuming temp_allocator or that the data is copied by create_pipeline.
	// If `make` was used with default allocator for `vis_desc.vertex_buffer_layouts`, then `delete(vis_desc.vertex_buffer_layouts)` would be needed if not copied.
	// Given it's `Gfx_Vertex_Input_State_Desc{...}` (a struct value), its dynamic array fields are copied if the underlying
	// create_pipeline implementation copies them. If it just stores pointers, then memory management is more complex.
	// For now, assume the API copies the necessary descriptor data.
	// If `context.temp_allocator` was used for `vis_desc.vertex_buffer_layouts`, it will be reset automatically.
	// Let's be safe and delete if we made it with default allocator:
	// delete(vis_desc.vertex_buffer_layouts) // This is only if it wasn't temp and not deep copied.
	// For now, I'll assume the API handles copying or uses the temp allocator correctly.
	// The `make` call inside `initialize_triangle` with `context.temp_allocator` is fine.
}

shutdown_triangle :: proc(game: ^core.Game) {
	log.info("Shutdown Triangle Callback")
	state_ptr := (^VulkanTriangleState)(game.user_data)
	if state_ptr == nil {
		log.warn("VulkanTriangleState is nil in shutdown callback. Nothing to clean up.")
		return
	}
	
	gfx_device := game.graphics_device

	// Destroy resources in reverse order of creation (generally a good practice)
	// Note: Original code used defers, so order was naturally reversed.
	// Here, we must be explicit.
	
	// Destroy Pipeline
	if state_ptr.pipeline.variant != nil {
		gfx.gfx_api.destroy_pipeline(state_ptr.pipeline)
		log.info("Pipeline destroyed.")
	}
	// Destroy VAO
	if state_ptr.vao.variant != nil {
		gfx.gfx_api.destroy_vertex_array(state_ptr.vao)
		log.info("VAO destroyed.")
	}
	// Destroy Shaders
	if state_ptr.frag_shader.variant != nil {
		gfx.gfx_api.destroy_shader(state_ptr.frag_shader)
		log.info("Fragment shader destroyed.")
	}
	if state_ptr.vert_shader.variant != nil {
		gfx.gfx_api.destroy_shader(state_ptr.vert_shader)
		log.info("Vertex shader destroyed.")
	}
	// Destroy Vertex Buffer
	if state_ptr.vertex_buffer.variant != nil {
		gfx.gfx_api.destroy_buffer(state_ptr.vertex_buffer)
		log.info("Vertex buffer destroyed.")
	}

	// Free the state struct itself if allocated with new()
	// context.allocator is default for new(), free() can be used.
	// Or if a different allocator was used, that should be used for freeing.
	// For now, assuming 'new' uses context.allocator and we can free it.
	// Check odingame's memory model for game.user_data if it's managed by the core.
	// Typically, if user allocates it, user frees it.
	free(state_ptr, context.allocator) 
	game.user_data = nil // Clear the pointer
	log.info("VulkanTriangleState freed.")
}

update_triangle :: proc(game: ^core.Game, game_time: core.GameTime) {
	// log.debug("Update Triangle Callback") // Can be too verbose
	// Event polling and window close check are handled by game_run by default.
	// Custom update logic (e.g., specific input handling beyond basic exit) would go here.
	// The core.game_run loop will handle polling events and checking for window close requests.
	// If Escape key should quit, it can be handled here or often by default by game_run.
	// For consistency with the provided callback stub:
	if core.keyboard_is_key_pressed(game.input_system, .Escape) { 
		core.exit(game)
	}
}

draw_triangle :: proc(game: ^core.Game, game_time: core.GameTime) {
	// log.debug("Draw Triangle Callback") 
	state_ptr := (^VulkanTriangleState)(game.user_data)
	if state_ptr == nil {
		log.error("VulkanTriangleState is nil in draw callback. Cannot render.")
		return
	}

	gfx_device := game.graphics_device
	main_window := game.window // Use game.window from core.Game

	// Begin Frame
	// For Vulkan, this acquires image and starts command buffer.
	// For other backends, it might set up the render target.
	gfx.gfx_api.begin_frame(gfx_device) 

	// Get Drawable Size for Viewport/Scissor
	drawable_w, drawable_h := gfx.gfx_api.get_window_drawable_size(main_window)
	if drawable_w == 0 || drawable_h == 0 {
		// Window might be minimized, skip rendering this frame.
		// end_frame and present should still be called to keep frame sync logic happy.
		gfx.gfx_api.end_frame(gfx_device)
		// Present might not be strictly necessary if nothing rendered, but for Vulkan sync, it's safer.
		gfx.gfx_api.present_window(main_window) 
		return // Skip actual drawing commands
	}

	viewport := gfx.Viewport{
		x = 0, y = 0,
		width = f32(drawable_w), height = f32(drawable_h),
		min_depth = 0.0, max_depth = 1.0,
	}
	scissor := gfx.Scissor{
		x = 0, y = 0,
		width = i32(drawable_w), height = i32(drawable_h),
	}

	gfx.gfx_api.set_viewport(gfx_device, viewport)
	gfx.gfx_api.set_scissor(gfx_device, scissor)

	clear_opts := gfx.default_clear_options()
	clear_opts.color = {0.1, 0.1, 0.1, 1.0} // Dark grey clear color
	gfx.gfx_api.clear_screen(gfx_device, main_window, clear_opts) // Pass main_window for target

	gfx.gfx_api.set_pipeline(gfx_device, state_ptr.pipeline)
	
	gfx.gfx_api.bind_vertex_array(gfx_device, state_ptr.vao) 
	
	// Bind the actual vertex buffer to binding point 0.
	// The VAO describes layout; this binds the data.
	gfx.gfx_api.set_vertex_buffer(gfx_device, state_ptr.vertex_buffer, 0, 0)
	// No index buffer for this example.

	gfx.gfx_api.draw(gfx_device, vertex_count=3, instance_count=1, first_vertex=0, first_instance=0)

	gfx.gfx_api.end_frame(gfx_device)   // For Vulkan, this ends command buffer and submits.
	                                    // For others, it might be a swap command.
	gfx.gfx_api.present_window(main_window)
}


main :: proc() {
	log.set_level(.Debug)
	log.info("Starting Simple Vulkan Triangle Example (New Pattern)...")

	game := core.new_game()
	options := core.Game_Options{
		title         = "Simple Vulkan Triangle",
		width         = 800,
		height        = 600,
		graphics_api  = .Vulkan,
		callbacks     = core.Game_Callbacks {
			initialize = initialize_triangle,
			shutdown   = shutdown_triangle,
			update     = update_triangle,
			draw       = draw_triangle,
		},
		// user_data can be pre-assigned here if preferred, but typically init in initialize_callback
	}

	// Run the game
	core.game_run(game, options)

	log.info("Shutting down Simple Vulkan Triangle Example (New Pattern).")
}
