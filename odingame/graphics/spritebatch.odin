package graphics

import "core:fmt"
import "core:log"
import "core:math"
import "core:math/linalg"
import gl "vendor:OpenGL/gl" // Will remove direct GL calls gradually. Used for vertex attribs for now.
import "core:strings" // For cstring conversion hack
import "core:unsafe"  // For offset_of, size_of
import "../types" // For common types: Color, Rectangle, Vector2
import "../common" // For standardized error handling
import "./font"

// --- Default SpriteBatch Shaders (GLSL) ---

DEFAULT_SB_VERTEX_SHADER_SOURCE :: `
#version 330 core
layout (location = 0) in vec2 In_Position;
layout (location = 1) in vec4 In_Color;
layout (location = 2) in vec2 In_TexCoord;

out vec4 vs_Color;
out vec2 vs_TexCoord;

uniform mat4 u_ProjectionView;

void main() {
    gl_Position = u_ProjectionView * vec4(In_Position, 0.0, 1.0);
    vs_Color = In_Color;
    vs_TexCoord = In_TexCoord;
}
`

DEFAULT_SB_FRAGMENT_SHADER_SOURCE :: `
#version 330 core
in vec4 vs_Color;
in vec2 vs_TexCoord;

out vec4 fs_Color;

uniform sampler2D u_Texture; // Texture unit 0

void main() {
    fs_Color = vs_Color * texture(u_Texture, vs_TexCoord);
}
`

// --- SpriteBatch Structs ---

Sprite_Vertex :: struct {
	pos:      math.Vector2, 
	color:    math.Color,   
	texcoord: math.Vector2, 
}

SpriteBatch :: struct {
	gfx_device: Gfx_Device, 
	pipeline: Gfx_Pipeline,
	vbo:      Gfx_Buffer,
	ebo:      Gfx_Buffer,

	default_white_texture: ^Gfx_Texture, // Reference-counted 1x1 white texture

	vertices: []Sprite_Vertex,
	indices:  []u16, 
	max_sprites_per_batch: int,
	current_texture:     ^Gfx_Texture, // Reference to the currently bound texture
	sprite_count:        int,           // Number of sprites in the current batch

	current_projection_view_matrix: math.Matrix4f, // Stores the matrix passed to begin_batch
	allocator: mem.Allocator, // Store allocator for consistent use
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
	vert_shader_src := DEFAULT_SB_VERTEX_SHADER_SOURCE
	frag_shader_src := DEFAULT_SB_FRAGMENT_SHADER_SOURCE

	v_shader, vs_err := gfx_api.create_shader_from_source(device, vert_shader_src, .Vertex)
	if vs_err != .None {
		log.errorf("Failed to create SpriteBatch vertex shader: %s", gfx_api.get_error_string(vs_err))
		return nil, common.Engine_Error.Shader_Compilation_Failed
	}
	
	f_shader, fs_err := gfx_api.create_shader_from_source(device, frag_shader_src, .Fragment)
	if fs_err != .None {
		log.errorf("Failed to create SpriteBatch fragment shader: %s", gfx_api.get_error_string(fs_err))
		gfx_api.destroy_shader(v_shader) 
		free(sb, allocator)
		return nil, common.Engine_Error.Shader_Compilation_Failed
	}
	
	// Corrected: Pass slice of dynamic array
	shaders_to_link_dyn := [dynamic]Gfx_Shader{v_shader, f_shader}
	pipeline, pipe_err := gfx_api.create_pipeline(device, shaders_to_link_dyn[:]) 
	delete(shaders_to_link_dyn) // Dynamic array itself can be deleted after slice is used if not needed

	if pipe_err != .None {
		log.errorf("Failed to create SpriteBatch pipeline: %s", gfx_api.get_error_string(pipe_err))
		gfx_api.destroy_shader(v_shader)
		gfx_api.destroy_shader(f_shader)
		free(sb, allocator)
		return nil, common.Engine_Error.Shader_Compilation_Failed
	}
	sb.pipeline = pipeline
	gfx_api.destroy_shader(v_shader) // Destroy individual shaders as they are now part of the pipeline
	gfx_api.destroy_shader(f_shader)


	// 2. Create Vertex and Index Buffers
	max_vertices := max_sprites * VERTICES_PER_SPRITE
	max_indices := max_sprites * INDICES_PER_SPRITE

	vbo, vbo_err := gfx_api.create_buffer(device, .Vertex, size_of(Sprite_Vertex) * max_vertices, nil, true)
	if vbo_err != .None {
		log.errorf("Failed to create SpriteBatch VBO: %s", gfx_api.get_error_string(vbo_err))
		gfx_api.destroy_pipeline(sb.pipeline)
		free(sb, allocator)
		return nil, common.Engine_Error.Buffer_Creation_Failed
	}
	sb.vbo = vbo

	sb.indices = make([]u16, max_indices, allocator)
	j: u16 = 0
	for i := 0; i < max_indices; i += INDICES_PER_SPRITE {
		sb.indices[i+0] = j + 0
		sb.indices[i+1] = j + 1
		sb.indices[i+2] = j + 3 // Corrected: TL, TR, BL, BR quad from EBO: 0,1,3, 1,2,3
		sb.indices[i+3] = j + 1 // These indices define two triangles: (v0,v1,v3) and (v1,v2,v3)
		sb.indices[i+4] = j + 2 // v0=TL, v1=TR, v2=BR, v3=BL
		sb.indices[i+5] = j + 3 // (TL,TR,BL) and (TR,BR,BL)
		j += VERTICES_PER_SPRITE
	}
	ebo, ebo_err := gfx_api.create_buffer(device, .Index, size_of(u16) * max_indices, rawptr(sb.indices), false)
	if ebo_err != .None {
		log.errorf("Failed to create SpriteBatch EBO: %s", gfx_api.get_error_string(ebo_err))
		gfx_api.destroy_pipeline(sb.pipeline)
		gfx_api.destroy_buffer(sb.vbo)
		free(sb.indices, allocator) 
		free(sb, allocator)
		return nil, common.Engine_Error.Buffer_Creation_Failed
	}
	sb.ebo = ebo
	// sb.indices can be freed now as it's uploaded to GPU, unless needed for dynamic resizing.
	// For now, let's keep it, assuming max_sprites is fixed after creation.

	// 3. Create Vertices Slice
	sb.vertices = make([]Sprite_Vertex, 0, max_vertices, allocator)

	// 4. Create Default White Texture
	white_pixel_data: [4]u8 = {255, 255, 255, 255}
	def_tex, tex_err := gfx_api.create_texture(device, 1, 1, .RGBA8, {.Sampled}, rawptr(&white_pixel_data[0]))
	if tex_err != .None {
		log.errorf("Failed to create SpriteBatch default white texture: %s", gfx_api.get_error_string(tex_err))
		gfx_api.destroy_pipeline(sb.pipeline)
		gfx_api.destroy_buffer(sb.vbo)
		gfx_api.destroy_buffer(sb.ebo)
		free(sb.indices, allocator)
		free(sb.vertices, allocator) // Free the slice header and underlying array if any
		free(sb, allocator)
		return nil, common.Engine_Error.Texture_Creation_Failed
	}
	sb.default_white_texture = def_tex
	sb.current_texture = sb.default_white_texture 

	sb.sprite_count = 0
	sb.is_drawing = false
	sb.vertex_count = 0
	sb.index_count = 0
	// sb.projection_matrix = matrix[4,4]f32{1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1} // Removed

	log.infof("SpriteBatch created with max_sprites=%d (VBO size=%d bytes)", max_sprites, vbo_size)
	return sb, common.Engine_Error.None
}

destroy_spritebatch :: proc(sb: ^SpriteBatch) {
    if sb == nil {
        return
    }
    
    log.debugf("Destroying SpriteBatch...")
    
    // Release the current texture reference
    if sb.current_texture != nil {
        destroy_texture(sb.current_texture)
        free(sb.current_texture)
        sb.current_texture = nil
    }
    
    // Release the default white texture
    if sb.default_white_texture != nil {
        destroy_texture(sb.default_white_texture)
        free(sb.default_white_texture)
        sb.default_white_texture = nil
    }
    
    // Free vertex and index data
    if sb.vertices != nil {
        delete(sb.vertices, sb.allocator)
        sb.vertices = nil
    }
    
    if sb.indices != nil {
        delete(sb.indices, sb.allocator)
        sb.indices = nil
    }
    
    // Destroy GPU resources
    if is_gfx_buffer_valid(sb.vbo) {
        gfx_api.destroy_buffer(sb.vbo)
        sb.vbo = {}
    }
    
    if is_gfx_buffer_valid(sb.ebo) {
        gfx_api.destroy_buffer(sb.ebo)
        sb.ebo = {}
    }
    
    if is_gfx_pipeline_valid(sb.pipeline) {
        gfx_api.destroy_pipeline(sb.pipeline)
        sb.pipeline = {}
    }
    
    log.debugf("SpriteBatch destroyed")
    
    // Free the SpriteBatch itself
    free(sb, sb.allocator)
	if sb.indices != nil {
		free(sb.indices, sb.allocator)
		sb.indices = nil
	}
	
	// Finally free the SpriteBatch itself
	allocator := sb.allocator
	free(sb, allocator)
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

	vertex_data_size := len(sb.vertices) * size_of(Sprite_Vertex)
	if vertex_data_size > 0 {
		err_vbo_up := gfx_api.update_buffer(sb.vbo, 0, rawptr(sb.vertices), vertex_data_size)
		if err_vbo_up != common.Engine_Error.None {
			log.errorf("SpriteBatch: Failed to update VBO: %s", gfx_api.get_error_string(err_vbo_up))
			return
		}
	}

	gfx_api.set_pipeline(sb.gfx_device, sb.pipeline)

	active_texture := sb.current_texture
	if gl_tex, ok := active_texture.variant.(^Gl_Texture); !ok || gl_tex == nil || gl_tex.id == 0 {
		active_texture = sb.default_white_texture
	}
    gfx_api.bind_texture_to_unit(sb.gfx_device, active_texture, 0)
	
	// Pass Odin strings directly to set_uniform_* methods.
	// The gfx_api implementation (e.g., gl_set_uniform_*) now handles cstring conversion.
	gfx_api.set_uniform_mat4(sb.gfx_device, sb.pipeline, "u_ProjectionView", sb.projection_matrix)
	gfx_api.set_uniform_int(sb.gfx_device, sb.pipeline, "u_Texture", 0) // Texture sampler for unit 0

	// Bind the VAO. This sets up VBO, EBO, and attribute pointers.
	gfx_api.bind_vertex_array(sb.gfx_device, sb.vao)
	// gfx_api.set_vertex_buffer and gfx_api.set_index_buffer calls are now implicitly handled by VAO binding for this draw.
	// If we needed to switch VBOs/EBOs with the same VAO (not typical for this SB),
	// the VAO would need to be rebound after those calls, or attributes re-set.
	// But here, VAO is configured once with the correct VBO/EBO.

	num_indices_to_draw := sb.sprite_count * INDICES_PER_SPRITE
	gfx_api.draw_indexed(sb.gfx_device, u32(num_indices_to_draw), 1, 0, 0, 0)

	// Unbind VAO
	gfx_api.bind_vertex_array(sb.gfx_device, Gfx_Vertex_Array{}) // Passing empty Gfx_Vertex_Array unbinds.

	sb.vertices = sb.vertices[:0] 
	sb.sprite_count = 0
}


// --- Drawing Methods ---
// Helper to check texture validity (very basic)
is_gfx_texture_valid :: proc(texture: Gfx_Texture) -> bool {
    if gl_tex, ok := texture.variant.(^Gl_Texture); ok && gl_tex != nil && gl_tex.id != 0 {
        return true
    }
    // Add checks for other Gfx_Texture variants if any
    return false
}


// draw_texture_region draws a portion of a texture to the screen with the specified parameters.
// The texture is automatically managed with reference counting.
draw_texture_region :: proc(
    sb: ^SpriteBatch,
    texture: Gfx_Texture,
    src_rect: math.Rectangle,
    dst_rect: math.Rectangle,
    tint: math.Color = math.WHITE,
    origin: math.Vector2 = {0, 0},
    rotation: f32 = 0,
) {
    if sb == nil || !sb.is_drawing {
        return
    }
    
    // Use the provided texture or fall back to the default white texture
    tex_to_use := texture
    if !is_gfx_texture_valid(tex_to_use) {
        if sb.default_white_texture != nil {
            tex_to_use = sb.default_white_texture^
        } else {
            log.error("Cannot draw: No valid texture and default white texture is missing")
            return
        }
    }

    // If the texture changed, we need to flush the current batch
    if sb.current_texture == nil || !is_same_texture(tex_to_use, sb.current_texture^) {
        flush_batch(sb)
        set_texture(sb, tex_to_use)
    }

    // If we've reached the max batch size, flush and start a new batch
    if sb.sprite_count >= sb.max_sprites_per_batch {
        flush_batch(sb)
    }

    // Get texture dimensions for UV calculation
    tex_width: f32 = 1.0
    tex_height: f32 = 1.0
    
    if gl_tex, ok := tex_to_use.variant.(^Gl_Texture); ok && gl_tex != nil {
        tex_width = f32(gl_tex.width)
        tex_height = f32(gl_tex.height)
    }

    // Calculate UV coordinates
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
    
    // Final transformed positions
    final_tl_x, final_tl_y: f32
    final_tr_x, final_tr_y: f32
    final_br_x, final_br_y: f32
    final_bl_x, final_bl_y: f32

    // Apply rotation if needed
    if rotation != 0 {
        cos_r := math.cos(rotation)
        sin_r := math.sin(rotation)
        
        // Rotate each corner around the origin
        final_tl_x = dst_rect.x + (world_tl_x * cos_r - world_tl_y * sin_r)
        final_tl_y = dst_rect.y + (world_tl_x * sin_r + world_tl_y * cos_r)
        
        final_tr_x = dst_rect.x + (world_tr_x * cos_r - world_tr_y * sin_r)
        final_tr_y = dst_rect.y + (world_tr_x * sin_r + world_tr_y * cos_r)
        
        final_br_x = dst_rect.x + (world_br_x * cos_r - world_br_y * sin_r)
        final_br_y = dst_rect.y + (world_br_x * sin_r + world_br_y * cos_r)
        
        final_bl_x = dst_rect.x + (world_bl_x * cos_r - world_bl_y * sin_r)
        final_bl_y = dst_rect.y + (world_bl_x * sin_r + world_bl_y * cos_r)
    } else {
        // No rotation, just translate
        final_tl_x = dst_rect.x + world_tl_x
        final_tl_y = dst_rect.y + world_tl_y
        final_tr_x = dst_rect.x + world_tr_x
        final_tr_y = dst_rect.y + world_tr_y
        final_br_x = dst_rect.x + world_br_x
        final_br_y = dst_rect.y + world_br_y
        final_bl_x = dst_rect.x + world_bl_x
        final_bl_y = dst_rect.y + world_bl_y
    }

    // Add vertices
    base_vertex := sb.vertex_count
    
    // Make sure we have enough space
    if base_vertex + 4 > len(sb.vertices) {
        flush_batch(sb)
        base_vertex = 0
    }

    // Add vertices in TL, TR, BR, BL order
    sb.vertices[base_vertex + 0] = {{final_tl_x, final_tl_y}, tint, {u1, v1}} // TL
    sb.vertices[base_vertex + 1] = {{final_tr_x, final_tr_y}, tint, {u2, v1}} // TR
    sb.vertices[base_vertex + 2] = {{final_br_x, final_br_y}, tint, {u2, v2}} // BR
    sb.vertices[base_vertex + 3] = {{final_bl_x, final_bl_y}, tint, {u1, v2}} // BL

    // Add indices for two triangles (TL,TR,BL and TR,BR,BL)
    base_index := sb.index_count
    if base_index + 6 > len(sb.indices) {
        flush_batch(sb)
        base_vertex = 0
        base_index = 0
    }
    
    sb.indices[base_index + 0] = u16(base_vertex + 0) // TL
    sb.indices[base_index + 1] = u16(base_vertex + 1) // TR
    sb.indices[base_index + 2] = u16(base_vertex + 3) // BL
    sb.indices[base_index + 3] = u16(base_vertex + 1) // TR
    sb.indices[base_index + 4] = u16(base_vertex + 2) // BR
    sb.indices[base_index + 5] = u16(base_vertex + 3) // BL

    sb.vertex_count += 4
    sb.index_count += 6
    sb.sprite_count += 1
}

// draw_texture draws a texture at the specified position with optional scaling and rotation.
// The texture is automatically managed with reference counting.
draw_texture :: proc(
    sb: ^SpriteBatch,
    texture: Gfx_Texture,
    position: math.Vector2,
    tint: math.Color = math.WHITE,
    origin: math.Vector2 = {0, 0},
    scale: math.Vector2 = {1, 1},
    rotation: f32 = 0,
) {
    if sb == nil || !sb.is_drawing {
        return
    }

    // Get texture dimensions
    tex_width: f32 = 1.0
    tex_height: f32 = 1.0
    
    // Use the provided texture or fall back to the default white texture
    tex_to_use := texture
    if !is_gfx_texture_valid(tex_to_use) {
        if sb.default_white_texture != nil {
            tex_to_use = sb.default_white_texture^
        } else {
            log.error("Cannot draw: No valid texture and default white texture is missing")
            return
        }
    }

    // Get actual texture dimensions
    if gl_tex, ok := tex_to_use.variant.(^Gl_Texture); ok && gl_tex != nil && gl_tex.id != 0 {
        if gl_tex.width > 0 && gl_tex.height > 0 {
            tex_width = f32(gl_tex.width)
            tex_height = f32(gl_tex.height)
        } else {
            log.warnf("SpriteBatch.draw_texture: Texture has invalid dimensions (%v x %v). Using 1x1.", 
                     gl_tex.width, gl_tex.height)
        }
    }

    // Create source and destination rectangles
    src_rect := math.Rectangle{0, 0, tex_width, tex_height}
    dst_rect := math.Rectangle{
        x = position.x,
        y = position.y,
        width = tex_width * scale.x,
        height = tex_height * scale.y,
    }
    
    // Draw the texture region
    draw_texture_region(sb, texture, src_rect, dst_rect, tint, origin, rotation)
}

// draw_string renders text using the specified font at the given position
// The texture is automatically managed with reference counting
draw_string :: proc(
    sb: ^SpriteBatch,
    font: ^font.Font,
    text: string,
    position: math.Vector2,
    tint: math.Color = math.WHITE,
    scale: f32 = 1.0,
) {
    if sb == nil || font == nil || len(text) == 0 || !sb.is_drawing {
        return
    }

    // Save current texture to restore it later
    current_tex := sb.current_texture
    
    // Use the font's texture
    sb.current_texture = &font.texture
    
    // Calculate scale factors
    scale_vec := math.Vector2{scale, scale}
    x := position.x
    y := position.y

    // Draw each character
    for char in text {
        // Skip control characters
        if char < 32 {
            continue
        }

        // Get character info
        char_info := font.get_char_info(char)
        if char_info == nil {
            continue
        }

        // Calculate source rectangle
        src_rect := math.Rectangle{
            x = char_info.x,
            y = char_info.y,
            width = char_info.width,
            height = char_info.height,
        }

        // Calculate destination rectangle
        dst_rect := math.Rectangle{
            x = x + char_info.xoffset * scale,
            y = y + char_info.yoffset * scale,
            width = char_info.width * scale,
            height = char_info.height * scale,
        }

        // Draw the character
        draw_texture_region(
            sb,
            font.texture,
            src_rect,
            dst_rect,
            tint,
            {0, 0},  // origin
            0,       // rotation
        )

        // Advance cursor
        x += char_info.xadvance * scale
    }

    // Restore the original texture
    sb.current_texture = current_tex
}