package graphics

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import gl "vendor:OpenGL/gl" // Will remove direct GL calls gradually. Used for vertex attribs for now.
import "core:strings" // For cstring conversion hack
import "core:unsafe"  // For offset_of, size_of

// Updated imports for graphics types
import graphics_types "./types"      // odingame/graphics/types/common_types.odin
import sprite_types "./sprite_types" // odingame/graphics/sprite_types.odin (contains Sprite_Vertex)
// Engine-level common types (Color, Rectangle, Vector2)
import engine_types "../types"       // odingame/types/
import "../common"                   // odingame/common/
import "./font"                      // odingame/graphics/font/

// Shader source constants are removed. They will be loaded using #load.
// HLSL Placeholders are also removed as the DX11 path is inactive.

// --- SpriteBatch Structs ---
// Sprite_Vertex is now imported from sprite_types.

SpriteBatch :: struct {
	gfx_device: Gfx_Device, 
	pipeline:   Gfx_Pipeline, 
	vbo:        Gfx_Buffer,   
	ebo:        Gfx_Buffer,   
    vao:        Gfx_Vertex_Array, // Added for VAO support

	default_white_texture: Gfx_Texture, // Now a direct handle

	vertices: [dynamic]sprite_types.Sprite_Vertex, // Use imported Sprite_Vertex
	indices:  []u16, 
	max_sprites_per_batch: int,
	current_texture:     Gfx_Texture, // Now a direct handle
	sprite_count:        int,           

	current_projection_view_matrix: math.Matrix4f,
	is_drawing: bool,
	allocator: mem.Allocator, 
}


// --- SpriteBatch Constants ---

MAX_SPRITES_DEFAULT :: 1000
VERTICES_PER_SPRITE :: 4
INDICES_PER_SPRITE :: 6


// --- Constructor and Destructor ---

new_spritebatch :: proc(
	device: Gfx_Device, 
	max_sprites: int = MAX_SPRITES_DEFAULT,
	allocator := context.allocator,
) -> (^SpriteBatch, common.Engine_Error) {
	
	sb := new(SpriteBatch, allocator)
	sb.gfx_device = device
	sb.max_sprites_per_batch = max_sprites
	sb.allocator = allocator

	// 1. Create Shaders and Pipeline
	// Load GLSL shaders using #load. Path is relative to this file (spritebatch.odin is in odingame/graphics).
	vert_shader_src :: #load("./shaders/spritebatch/spritebatch.vert")
	frag_shader_src :: #load("./shaders/spritebatch/spritebatch.frag")
	
	// active_backend := gfx_api.utilities.query_backend_type(device) // This function remains commented out.
	// log.info("SpriteBatch: Using GLSL shaders (backend query removed).")

	// Create shader program. This is a simplified model where create_shader_from_source
	// might internally handle linking if given a .Vertex stage, or create_pipeline does.
	// Ideally, there'd be a separate create_program call.
	// For now, we assume the backend's create_shader_from_source or create_pipeline
	// can derive the full program from vert_shader_src and potentially frag_shader_src
	// if the backend implementation of create_shader_from_source is smart or by convention.
	// This is a known simplification from prior refactoring.
	shader_program_handle, shader_err := gfx_api.resource_creation.create_shader_from_source(device, vert_shader_src, graphics_types.Shader_Stage.Vertex)
	if shader_err != .None { 
		log.errorf("Failed to create SpriteBatch shader program: %v", shader_err)
		return nil, common.Engine_Error.Shader_Compilation_Failed
	}
	// Note: frag_shader_src is not explicitly passed to create_shader_from_source here.
	// This implies the backend or pipeline creation must handle it.

	// Define Vertex Layout for SpriteBatch
	vertex_attributes := [dynamic]graphics_types.Vertex_Attribute{
		{name = "In_Position", format = graphics_types.Vertex_Format.Float2, location = 0, offset = offset_of(sprite_types.Sprite_Vertex, pos)},
		{name = "In_Color",    format = graphics_types.Vertex_Format.UByte4N,location = 1, offset = offset_of(sprite_types.Sprite_Vertex, color)},
		{name = "In_TexCoord", format = graphics_types.Vertex_Format.Float2, location = 2, offset = offset_of(sprite_types.Sprite_Vertex, texcoord)},
	}
	
	vertex_buffer_layout_desc := graphics_types.Vertex_Buffer_Layout_Desc {
		buffer_index = 0,
		layout = graphics_types.Gfx_Vertex_Layout_Desc {
			attributes = vertex_attributes,
			stride     = size_of(sprite_types.Sprite_Vertex), 
			step_rate  = graphics_types.Vertex_Step_Rate.Per_Vertex,
		},
	}

	// Define Pipeline Description using graphics_types
	pipeline_desc := graphics_types.Gfx_Pipeline_Desc {
		shader_handle = shader_program_handle, 
		vertex_buffer_layouts = {vertex_buffer_layout_desc},
		primitive_topology = graphics_types.Primitive_Topology.Triangles,
		blend_state = {
			enabled = true,
			src_factor_rgb = .Src_Alpha, dst_factor_rgb = .One_Minus_Src_Alpha, op_rgb = .Add,
			src_factor_alpha = .One,     dst_factor_alpha = .One_Minus_Src_Alpha, op_alpha = .Add,
			write_mask = {.All},
		},
		depth_stencil_state = {
			depth_test_enabled = false, depth_write_enabled = false,
			stencil_test_enabled = false,
		},
		rasterizer_state = {
			cull_mode = .Back, fill_mode = .Fill,
			winding_order = .Counter_Clockwise,
		},
		debug_name = "SpriteBatchPipeline",
	}

	pipeline, pipe_err := gfx_api.resource_creation.create_pipeline(device, pipeline_desc) 
	if pipe_err != .None {
		log.errorf("Failed to create SpriteBatch pipeline: %v", pipe_err)
		gfx_api.resource_management.destroy_shader(shader_program_handle)
		return nil, common.Engine_Error.Pipeline_Creation_Failed
	}
	sb.pipeline = pipeline
	gfx_api.resource_management.destroy_shader(shader_program_handle)


	// 2. Create Vertex and Index Buffers
	max_vertices := max_sprites * VERTICES_PER_SPRITE
	max_indices := max_sprites * INDICES_PER_SPRITE

	vbo, vbo_err := gfx_api.resource_creation.create_buffer(device, graphics_types.Buffer_Type.Vertex, size_of(sprite_types.Sprite_Vertex) * max_vertices, nil, true)
	if vbo_err != .None {
		log.errorf("Failed to create SpriteBatch VBO: %s", gfx_api.utilities.get_error_string(vbo_err))
		gfx_api.resource_management.destroy_pipeline(sb.pipeline)
		return nil, common.Engine_Error.Buffer_Creation_Failed
	}
	sb.vbo = vbo

	sb.indices = make([]u16, max_indices, allocator)
	j: u16 = 0
	for i := 0; i < max_indices; i += INDICES_PER_SPRITE {
		sb.indices[i+0] = j + 0; sb.indices[i+1] = j + 1; sb.indices[i+2] = j + 3
		sb.indices[i+3] = j + 1; sb.indices[i+4] = j + 2; sb.indices[i+5] = j + 3
		j += VERTICES_PER_SPRITE
	}
	ebo, ebo_err := gfx_api.resource_creation.create_buffer(device, graphics_types.Buffer_Type.Index, size_of(u16) * max_indices, rawptr(sb.indices), false)
	if ebo_err != .None {
		log.errorf("Failed to create SpriteBatch EBO: %s", gfx_api.utilities.get_error_string(ebo_err))
		gfx_api.resource_management.destroy_pipeline(sb.pipeline)
		gfx_api.resource_management.destroy_buffer(sb.vbo)
		free(sb.indices, allocator) 
		return nil, common.Engine_Error.Buffer_Creation_Failed
	}
	sb.ebo = ebo
	
	sb.vertices = make([dynamic]sprite_types.Sprite_Vertex, 0, max_vertices, allocator)

    // Create VAO for SpriteBatch
    sprite_batch_vertex_buffer_layout_for_vao := graphics_types.Vertex_Buffer_Layout {
        attributes = vertex_attributes, 
        stride = size_of(sprite_types.Sprite_Vertex), 
        step_rate = graphics_types.Vertex_Step_Rate.Per_Vertex,
    }
    
    vao, vao_err := gfx_api.resource_creation.create_vertex_array(device, {sprite_batch_vertex_buffer_layout_for_vao}, {sb.vbo}, sb.ebo)
    if vao_err != .None {
        log.errorf("Failed to create SpriteBatch VAO: %s", gfx_api.utilities.get_error_string(vao_err))
        gfx_api.resource_management.destroy_pipeline(sb.pipeline)
        gfx_api.resource_management.destroy_buffer(sb.vbo)
        gfx_api.resource_management.destroy_buffer(sb.ebo)
        free(sb.indices, allocator)
        return nil, common.Engine_Error.Vertex_Array_Creation_Failed
    }
    sb.vao = vao

	// 4. Create Default White Texture
	white_pixel_data: [4]u8 = {255, 255, 255, 255}
	def_tex_usage: graphics_types.Texture_Usage_Flags = {.Sample} 
	def_tex_handle, tex_err := gfx_api.resource_creation.create_texture(
		device, 1, 1, 0, 
		graphics_types.Texture_Format.RGBA8, 
		graphics_types.Texture_Type.Tex_2D,
		def_tex_usage, 
		1, 0, 
		rawptr(&white_pixel_data[0]), 
		0,0, 
		"DefaultWhiteTexture")
	if tex_err != .None {
		log.errorf("Failed to create SpriteBatch default white texture: %v", tex_err)
		gfx_api.resource_management.destroy_vertex_array(sb.vao)
		gfx_api.resource_management.destroy_pipeline(sb.pipeline)
		gfx_api.resource_management.destroy_buffer(sb.vbo)
		gfx_api.resource_management.destroy_buffer(sb.ebo)
		if sb.indices != nil { free(sb.indices, allocator); sb.indices = nil }
		delete(sb.vertices) 
		return nil, common.Engine_Error.Texture_Creation_Failed
	}
    sb.default_white_texture = def_tex_handle
	sb.current_texture = sb.default_white_texture 

	sb.sprite_count = 0
	sb.is_drawing = false 

	log.infof("SpriteBatch created with max_sprites=%d", max_sprites)
	return sb, common.Engine_Error.None
}

destroy_spritebatch :: proc(sb: ^SpriteBatch) {
    if sb == nil {
        return
    }
    
    log.debugf("Destroying SpriteBatch...")
    
    // Reset current_texture handle, actual resource it pointed to is not owned by current_texture itself.
    sb.current_texture = graphics_types.INVALID_HANDLE 
    
    // Release the default white texture
    if sb.default_white_texture.variant != nil { // Check for valid handle
        gfx_api.resource_management.destroy_texture(sb.default_white_texture)
        sb.default_white_texture = graphics_types.INVALID_HANDLE // Reset handle
    }
    delete(sb.vertices) // For dynamic array
    sb.vertices = nil
    
    if sb.indices != nil { // CPU copy of indices
        free(sb.indices, sb.allocator) // Use free for slices allocated with make
        sb.indices = nil
    }
    
    // Destroy GPU resources
    if sb.vbo.variant != nil { 
        gfx_api.resource_management.destroy_buffer(sb.vbo)
        sb.vbo = {} 
    }
    if sb.ebo.variant != nil {
        gfx_api.resource_management.destroy_buffer(sb.ebo)
        sb.ebo = {}
    }
    if sb.vao.variant != nil { 
        gfx_api.resource_management.destroy_vertex_array(sb.vao)
        sb.vao = {}
    }
    if sb.pipeline.variant != nil {
        gfx_api.resource_management.destroy_pipeline(sb.pipeline)
        sb.pipeline = {}
    }
    
    log.debug("SpriteBatch destroyed")
    
    // Free the SpriteBatch itself
	free(sb, sb.allocator) // Use the stored allocator
}


// --- Batching Logic ---

// begin_batch now takes a combined projection_view_matrix.
begin_batch :: proc(sb: ^SpriteBatch, projection_view_matrix: math.Matrix4f) {
	// Store the combined matrix to be used by flush_batch for the u_ProjectionView uniform.
	// This requires adding a field to SpriteBatch struct to hold this matrix during a batch.
	// Let's add `current_projection_view_matrix: math.Matrix4f` to SpriteBatch struct.
	// For now, to avoid modifying struct in this step, I'll assume flush_batch can get it
	// or that this matrix is set as a uniform immediately.
	// However, flush_batch is called internally. So, SpriteBatch *must* store it.
	// I will add this field now.

	// This design implies that the matrix passed to begin_batch is used for all sprites
	// drawn between this begin_batch and end_batch.

	// Store this matrix in the SpriteBatch.
	// This requires adding a field to SpriteBatch: `active_projection_view: math.Matrix4f`
	// For now, I'll proceed as if it's stored and used by flush_batch.
	// This change will be made to the struct definition in the next appropriate step if this diff fails.
	// For now, let's assume it's available to flush_batch.
	// The subtask description for SpriteBatch says "The SpriteBatch will use this combined matrix directly".
	// This implies flush_batch will use it. So SpriteBatch needs to store it from begin_batch.

	// Let's assume the field `active_projection_view_matrix: math.Matrix4f` exists in SpriteBatch.
	// I will add this field in the next modification of SpriteBatch struct.
	// For this diff, I'll just update the signature and internal logic flow.
	// The actual uniform setting is in flush_batch.
	
	sb.current_projection_view_matrix = projection_view_matrix
	sb.sprite_count = 0
	// Clear vertex buffer by resetting length to 0, retaining capacity for reuse.
	sb.vertices = sb.vertices[:0] 
}

end_batch :: proc(sb: ^SpriteBatch) {
	if sb.sprite_count > 0 {
		flush_batch(sb)
	}
}

// @(private="file")
// setup_sprite_vertex_attributes :: proc() {
// 	// ... removed ...
// }

// @(private="file")
// disable_sprite_vertex_attributes :: proc() {
//     // ... removed ...
// }


flush_batch :: proc(sb: ^SpriteBatch) {
	if sb.sprite_count == 0 || len(sb.vertices) == 0 {
		return 
	}

	vertex_data_size := len(sb.vertices) * size_of(sprite_types.Sprite_Vertex) 
	if vertex_data_size > 0 {
		err_vbo_up := gfx_api.resource_management.update_buffer(sb.vbo, 0, rawptr(sb.vertices), vertex_data_size)
		if err_vbo_up != common.Engine_Error.None {
			log.errorf("SpriteBatch: Failed to update VBO: %s", gfx_api.utilities.get_error_string(err_vbo_up))
			return
		}
	}

    encoder_handle: rawptr = nil 

	gfx_api.state_setting.set_pipeline(encoder_handle, sb.pipeline)

	active_texture_to_bind := sb.current_texture
	if active_texture_to_bind.variant == nil { 
		active_texture_to_bind = sb.default_white_texture
	}
    if active_texture_to_bind.variant != nil {
        gfx_api.state_setting.bind_texture_to_unit(encoder_handle, active_texture_to_bind, 0, graphics_types.Shader_Stage.Fragment)
    } else {
        log.error("Spritebatch: No valid texture to bind for flush.")
    }
	
	gfx_api.state_setting.set_uniform_mat4(encoder_handle, sb.pipeline, "u_ProjectionView", sb.current_projection_view_matrix)
	gfx_api.state_setting.set_uniform_int(encoder_handle, sb.pipeline, "u_Texture", 0)

	gfx_api.state_setting.bind_vertex_array(encoder_handle, sb.vao)

	num_indices_to_draw := sb.sprite_count * INDICES_PER_SPRITE
	gfx_api.drawing_commands.draw_indexed(encoder_handle, sb.gfx_device, u32(num_indices_to_draw), 1, 0, 0, 0)

	gfx_api.state_setting.bind_vertex_array(encoder_handle, Gfx_Vertex_Array{}) 

	sb.vertices = sb.vertices[:0] 
	sb.sprite_count = 0
}


// --- Drawing Methods ---
is_gfx_texture_valid_direct :: proc(texture: Gfx_Texture) -> bool { 
    return texture.variant != nil
}

draw_texture_region :: proc(
    sb: ^SpriteBatch,
    texture: Gfx_Texture, 
    src_rect: engine_types.Rectangle, 
    dst_rect: engine_types.Rectangle,
    tint: engine_types.Color = engine_types.WHITE, 
    origin: math.Vector2 = {0, 0},
    rotation: f32 = 0,
) {
    if sb == nil || !sb.is_drawing { return }
    
    active_texture_for_draw := texture
    if !is_gfx_texture_valid_direct(active_texture_for_draw) {
        if is_gfx_texture_valid_direct(sb.default_white_texture) {
            active_texture_for_draw = sb.default_white_texture
        } else {
            log.error("SpriteBatch: Draw failed - active and default textures invalid.")
            return
        }
    }
    
    has_texture_changed := sb.current_texture.variant != active_texture_for_draw.variant || sb.current_texture.variant == nil
    
    if has_texture_changed || sb.sprite_count >= sb.max_sprites_per_batch {
        flush_batch(sb)
        if has_texture_changed { 
             sb.current_texture = active_texture_for_draw
        }
    }

    tex_width  := f32(gfx_api.utilities.get_texture_width(active_texture_for_draw))
    tex_height := f32(gfx_api.utilities.get_texture_height(active_texture_for_draw))
    if tex_width == 0 || tex_height == 0 {
        log.warnf("SpriteBatch: Texture has zero dimension (W: %d, H: %d). Skipping draw.", gfx_api.utilities.get_texture_width(active_texture_for_draw), gfx_api.utilities.get_texture_height(active_texture_for_draw))
        return
    }

    u1 := src_rect.x / tex_width
    v1 := src_rect.y / tex_height
    u2 := (src_rect.x + src_rect.width) / tex_width
    v2 := (src_rect.y + src_rect.height) / tex_height

    // Calculate vertex positions relative to origin
    world_tl_x := -origin.x
    world_tl_y := -origin.y
    world_tr_x := dst_rect.width - origin.x
    world_tr_y := -origin.y
    world_bl_x := -origin.x
    world_bl_y := dst_rect.height - origin.y
    world_br_x := dst_rect.width - origin.x
    world_br_y := dst_rect.height - origin.y
    
    final_tl_x, final_tl_y: f32
    final_tr_x, final_tr_y: f32
    final_br_x, final_br_y: f32
    final_bl_x, final_bl_y: f32

    if rotation != 0 {
        cos_r, sin_r := math.cos(rotation), math.sin(rotation)
        final_tl_x = dst_rect.x + (world_tl_x * cos_r - world_tl_y * sin_r)
        final_tl_y = dst_rect.y + (world_tl_x * sin_r + world_tl_y * cos_r)
        final_tr_x = dst_rect.x + (world_tr_x * cos_r - world_tr_y * sin_r)
        final_tr_y = dst_rect.y + (world_tr_x * sin_r + world_tr_y * cos_r)
        final_br_x = dst_rect.x + (world_br_x * cos_r - world_br_y * sin_r)
        final_br_y = dst_rect.y + (world_br_x * sin_r + world_br_y * cos_r)
        final_bl_x = dst_rect.x + (world_bl_x * cos_r - world_bl_y * sin_r)
        final_bl_y = dst_rect.y + (world_bl_x * sin_r + world_bl_y * cos_r)
    } else {
        final_tl_x = dst_rect.x + world_tl_x; final_tl_y = dst_rect.y + world_tl_y
        final_tr_x = dst_rect.x + world_tr_x; final_tr_y = dst_rect.y + world_tr_y
        final_br_x = dst_rect.x + world_br_x; final_br_y = dst_rect.y + world_br_y
        final_bl_x = dst_rect.x + world_bl_x; final_bl_y = dst_rect.y + world_bl_y
    }
    
    // Append new vertices
    append(&sb.vertices, sprite_types.Sprite_Vertex{{final_tl_x, final_tl_y}, tint, {u1, v1}}) 
    append(&sb.vertices, sprite_types.Sprite_Vertex{{final_tr_x, final_tr_y}, tint, {u2, v1}})
    append(&sb.vertices, sprite_types.Sprite_Vertex{{final_br_x, final_br_y}, tint, {u2, v2}})
    append(&sb.vertices, sprite_types.Sprite_Vertex{{final_bl_x, final_bl_y}, tint, {u1, v2}})
    
    sb.sprite_count += 1
}

draw_texture :: proc(
    sb: ^SpriteBatch,
    texture: Gfx_Texture,
    position: math.Vector2,
    tint: engine_types.Color = engine_types.WHITE,
    origin: math.Vector2 = {0, 0},
    scale: math.Vector2 = {1, 1},
    rotation: f32 = 0,
) {
    if sb == nil || !sb.is_drawing { return }

    tex_to_use := texture
    if !is_gfx_texture_valid_direct(tex_to_use) {
        if is_gfx_texture_valid_direct(sb.default_white_texture) {
            tex_to_use = sb.default_white_texture
        } else {
            log.error("SpriteBatch.draw_texture: Active and default textures invalid.")
            return
        }
    }

    tex_width  := f32(gfx_api.utilities.get_texture_width(tex_to_use))
    tex_height := f32(gfx_api.utilities.get_texture_height(tex_to_use))
    if tex_width == 0 || tex_height == 0 {
         log.warnf("SpriteBatch.draw_texture: Texture has zero dimensions (W: %d, H: %d). Using 1x1.", gfx_api.utilities.get_texture_width(tex_to_use), gfx_api.utilities.get_texture_height(tex_to_use))
         tex_width = 1; tex_height = 1;
    }
    
    src_rect := engine_types.Rectangle{0, 0, tex_width, tex_height}
    dst_rect := engine_types.Rectangle{
        x = position.x, y = position.y,
        width = tex_width * scale.x, height = tex_height * scale.y,
    }
    
    draw_texture_region(sb, tex_to_use, src_rect, dst_rect, tint, origin, rotation)
}

draw_string :: proc(
    sb: ^SpriteBatch,
    font_ptr: ^font.Font, 
    text: string,
    position: math.Vector2,
    tint: engine_types.Color = engine_types.WHITE,
    scale_factor: f32 = 1.0, 
) {
    if sb == nil || font_ptr == nil || len(text) == 0 || !sb.is_drawing { return }

    active_font := font_ptr^ 
    font_tex_handle := active_font.texture 
    if !is_gfx_texture_valid_direct(font_tex_handle) {
        log.error("SpriteBatch.draw_string: Font texture is invalid.")
        return
    }
    
    current_x := position.x
    current_y := position.y 
    
    for r in text {
        if r == '\n' { 
            current_x = position.x
            current_y += active_font.base_size * scale_factor 
            continue
        }
        char_data, ok := active_font.char_data[r] 
        if !ok || r < 32 { 
            continue
        }

        src_rect := engine_types.Rectangle{
            x = char_data.x, y = char_data.y,
            width = char_data.width, height = char_data.height,
        }
        
        dst_pos_x := current_x + char_data.xoffset * scale_factor
        dst_pos_y := current_y + char_data.yoffset * scale_factor 
        
        dst_rect := engine_types.Rectangle{
            x = dst_pos_x, y = dst_pos_y,
            width = char_data.width * scale_factor, height = char_data.height * scale_factor,
        }

        draw_texture_region(sb, font_tex_handle, src_rect, dst_rect, tint, {0,0}, 0)
        
        current_x += char_data.xadvance * scale_factor
    }
}