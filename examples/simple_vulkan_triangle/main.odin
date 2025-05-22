package main

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:strings"

import "odingame:core"
import gfx "odingame:graphics" 
// Renamed to avoid conflict with local 'graphics' if any, and for brevity
import "odingame:math"


Vertex :: struct {
	pos: [2]f32, // x, y
	col: [3]f32, // r, g, b
}

// Standard Counter-Clockwise (CCW) winding order for Vulkan's default frontFace.
// Y points down in NDC, so -0.5 is top, 0.5 is bottom.
triangle_vertices := [?]Vertex{
    {{0.0, -0.5}, {1.0, 0.0, 0.0}},  // Top, Red
    {{0.5, 0.5},  {0.0, 1.0, 0.0}},  // Bottom Right, Green
    {{-0.5, 0.5}, {0.0, 0.0, 1.0}}, // Bottom Left, Blue
}

// Helper to read shader file
read_shader_file :: proc(filepath: string, allocator := context.allocator) -> (string, bool) {
	data, ok := os.read_entire_file(filepath, allocator)
	if !ok {
		log.errorf("Failed to read shader file: %s", filepath)
		return "", false
	}
	// Ensure it's a valid Odin string (UTF-8, though GLSL is usually ASCII)
	// For simplicity, directly convert. Proper validation might be needed.
	return string(data), true
}


main :: proc() {
	// Initialize logger
	log.set_level(.Debug) // Set to .Info or .Warning for less verbose output
	log.info("Starting Simple Vulkan Triangle Example...")

	// Game Config
	config := core.Game_Config{
		window_title  = "Simple Vulkan Triangle",
		window_width  = 800,
		window_height = 600,
		graphics_backend = .Vulkan, // Specify Vulkan backend
	}

	// Initialize Game
	if !core.init_game(config) {
		log.error("Failed to initialize game core.")
		return
	}
	defer core.shutdown_game()

	// Get device and window
	gfx_device := core.get_device()
	main_window := core.get_main_window()

	if gfx_device == nil || main_window == nil {
		log.error("Failed to get graphics device or main window from core.")
		return
	}
	log.info("Game core initialized, Vulkan backend selected.")

	// --- Create Vertex Buffer ---
	vb_size := size_of(triangle_vertices)
	log.infof("Attempting to create vertex buffer of size %d bytes.", vb_size)
	vertex_buffer, vb_err := gfx.gfx_api.create_buffer(
		gfx_device,
		.Vertex,
		vb_size,
		&triangle_vertices[0],
		false, // dynamic = false
	)
	if vb_err != .None {
		log.errorf("Failed to create vertex buffer: %s", gfx.gfx_api.get_error_string(vb_err))
		return
	}
	if vertex_buffer.variant == nil {
		log.error("Vertex buffer creation returned success but handle is nil.")
		return
	}
	defer gfx.gfx_api.destroy_buffer(vertex_buffer)
	log.info("Vertex buffer created successfully.")

	// --- Load Shaders ---
	// Shader file paths (adjust if needed, assuming execution from example root or shaders are findable)
	// For simplicity, assume execution from `examples/simple_vulkan_triangle/` or that paths are relative to it.
	// Or, use absolute paths or a more robust path finding mechanism.
	// Let's assume files are in "./shaders/" relative to executable for now.
	vert_shader_path := "shaders/simple_triangle.vert"
	frag_shader_path := "shaders/simple_triangle.frag"

	vert_shader_source, ok_vs := read_shader_file(vert_shader_path)
	if !ok_vs { return }
	defer delete(vert_shader_source) // Free the string data if read_shader_file used non-context allocator

	frag_shader_source, ok_fs := read_shader_file(frag_shader_path)
	if !ok_fs { return }
	defer delete(frag_shader_source)

	log.info("Read shader sources.")

	vert_shader, vs_err := gfx.gfx_api.create_shader_from_source(gfx_device, vert_shader_source, .Vertex)
	if vs_err != .None {
		log.errorf("Failed to create vertex shader: %s", gfx.gfx_api.get_error_string(vs_err))
		if vs_err == .Shader_Compilation_Failed {
			log.warn("Shader compilation failed. This might be due to shaderc not being found or a GLSL error.")
		}
		return
	}
	if vert_shader.variant == nil { log.error("Vertex shader creation success but handle is nil."); return }
	defer gfx.gfx_api.destroy_shader(vert_shader)
	log.info("Vertex shader created successfully.")

	frag_shader, fs_err := gfx.gfx_api.create_shader_from_source(gfx_device, frag_shader_source, .Fragment)
	if fs_err != .None {
		log.errorf("Failed to create fragment shader: %s", gfx.gfx_api.get_error_string(fs_err))
		if fs_err == .Shader_Compilation_Failed {
			log.warn("Shader compilation failed. This might be due to shaderc not being found or a GLSL error.")
		}
		return
	}
	if frag_shader.variant == nil { log.error("Fragment shader creation success but handle is nil."); return }
	defer gfx.gfx_api.destroy_shader(frag_shader)
	log.info("Fragment shader created successfully.")

	// --- Create Vertex Array (VAO) ---
	vertex_attributes: []gfx.Vertex_Attribute = {
		{ // Position
			location = 0,
			buffer_binding = 0,
			format = .Float32_X2,
			offset_in_bytes = offset_of(Vertex, pos),
		},
		{ // Color
			location = 1,
			buffer_binding = 0,
			format = .Float32_X3,
			offset_in_bytes = offset_of(Vertex, col),
		},
	}
	
	vertex_buffer_layouts: []gfx.Vertex_Buffer_Layout = {
		{
			binding = 0,
			stride_in_bytes = size_of(Vertex),
			attributes = vertex_attributes,
			// step_rate = .Vertex // Assuming default is per-vertex
		},
	}

	// For create_vertex_array, vertex_buffers is an array of Gfx_Buffer.
	// Since we have one layout for binding 0, we provide one buffer.
	vao_vertex_buffers := [1]gfx.Gfx_Buffer{vertex_buffer}

	vao, vao_err := gfx.gfx_api.create_vertex_array(
		gfx_device,
		vertex_buffer_layouts[:],
		vao_vertex_buffers[:],
		gfx.Gfx_Buffer{}, // No index buffer
	)
	if vao_err != .None {
		log.errorf("Failed to create VAO: %s", gfx.gfx_api.get_error_string(vao_err))
		return
	}
	if vao.variant == nil { log.error("VAO creation success but handle is nil."); return }
	defer gfx.gfx_api.destroy_vertex_array(vao)
	log.info("VAO created successfully.")

	// --- Create Pipeline ---
	// Bind VAO first so pipeline can be created with its vertex input layout.
	gfx.gfx_api.bind_vertex_array(gfx_device, vao) 
	
	pipeline_shaders := [2]gfx.Gfx_Shader{vert_shader, frag_shader}
	pipeline, pipe_err := gfx.gfx_api.create_pipeline(gfx_device, pipeline_shaders[:])
	if pipe_err != .None {
		log.errorf("Failed to create pipeline: %s", gfx.gfx_api.get_error_string(pipe_err))
		return
	}
	if pipeline.variant == nil { log.error("Pipeline creation success but handle is nil."); return }
	defer gfx.gfx_api.destroy_pipeline(pipeline)
	log.info("Graphics pipeline created successfully.")

	// Unbind VAO after pipeline creation (optional, good practice if state might change)
	// gfx.gfx_api.bind_vertex_array(gfx_device, gfx.Gfx_Vertex_Array{})


	// --- Main Loop ---
	log.info("Starting main loop...")
	running := true
	for running {
		// Event Polling
		core.poll_events()
		// Check if window should close (e.g., user clicks X)
		if core.window_should_close(main_window) {
			running = false
			continue
		}
		
		// Frame Pacing / Timing (not implemented here for simplicity)

		// Begin Frame
		gfx.gfx_api.begin_frame(gfx_device) // For Vulkan, this acquires image and starts command buffer

		// Get Drawable Size for Viewport/Scissor
		drawable_w, drawable_h := gfx.gfx_api.get_window_drawable_size(main_window)
		if drawable_w == 0 || drawable_h == 0 {
			// Window might be minimized, skip rendering this frame.
			// end_frame and present should still be called to keep frame sync logic happy.
			gfx.gfx_api.end_frame(gfx_device)
			// Present might not be strictly necessary if nothing rendered, but for Vulkan sync, it's safer.
			gfx.gfx_api.present_window(main_window) 
			continue 
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
		clear_opts.color = {0.1, 0.1, 0.1, 1.0}
		gfx.gfx_api.clear_screen(gfx_device, clear_opts)

		gfx.gfx_api.set_pipeline(gfx_device, pipeline)
		
		// Bind VAO (sets up which vertex layout is expected by pipeline state for draw)
		gfx.gfx_api.bind_vertex_array(gfx_device, vao) 
		
		// Bind the actual vertex buffer to binding point 0 (as defined in VAO layout)
		// The VAO itself doesn't bind buffers in Vulkan, it just describes layout.
		// This call tells Vulkan which actual VkBuffer to use for which binding.
		gfx.gfx_api.set_vertex_buffer(gfx_device, vertex_buffer, 0, 0)
		// No index buffer to bind for this example.

		gfx.gfx_api.draw(gfx_device, vertex_count=3, instance_count=1, first_vertex=0, first_instance=0)

		gfx.gfx_api.end_frame(gfx_device)   // For Vulkan, this ends command buffer and submits
		gfx.gfx_api.present_window(main_window)
	}
	log.info("Main loop ended.")

	// Cleanup is handled by defers.
	log.info("Shutting down Simple Vulkan Triangle Example.")
}
