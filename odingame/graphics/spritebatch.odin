package graphics

import "core:fmt"
import "core:mem"
import gl "vendor:OpenGL/gl"
import "../core" // For Device, Window
import "../math"

MAX_SPRITES_PER_BATCH :: 1 // For immediate drawing; increase for actual batching

SpriteVertex :: struct {
	pos: math.Vector2f, // 2 * f32
	uv:  math.Vector2f, // 2 * f32
	col: Color,         // 4 * u8
}

// Calculate actual size: (2*f32) + (2*f32) + (4*u8) = 4*size_of(f32) + 4*size_of(u8)
// size_of(SpriteVertex) will correctly calculate this.
VERTEX_SIZE_BYTES :: size_of(SpriteVertex)

SpriteBatch :: struct {
	device: ^Device, // From graphics/device.odin

	shader_program:  gl.GLuint,
	vertex_shader:   gl.GLuint,
	fragment_shader: gl.GLuint,
	
	u_projection_matrix_loc: gl.GLint,
	u_model_view_matrix_loc: gl.GLint,
	u_texture_loc:           gl.GLint,

	vao: gl.GLuint,
	vbo: gl.GLuint, 

	projection_matrix: math.Matrix4f,
	model_view_matrix: math.Matrix4f,

	drawing: bool,
	
	vertices: [6 * MAX_SPRITES_PER_BATCH]SpriteVertex, // Buffer for vertices
}

new_sprite_batch :: proc(dev: ^Device, window_width, window_height: int) -> (^SpriteBatch, error) {
	sb := new(SpriteBatch)
	sb.device = dev

	// 1. Compile and link shaders
	vs, vs_err := compile_shader(SHADER_VERTEX_SOURCE_DEFAULT, gl.VERTEX_SHADER)
	if vs_err != nil { free(sb); return nil, vs_err }
	sb.vertex_shader = vs

	fs, fs_err := compile_shader(SHADER_FRAGMENT_SOURCE_DEFAULT, gl.FRAGMENT_SHADER)
	if fs_err != nil { gl.DeleteShader(vs); free(sb); return nil, fs_err }
	sb.fragment_shader = fs

	prog, prog_err := link_shader_program(vs, fs)
	if prog_err != nil {
		gl.DeleteShader(vs); gl.DeleteShader(fs); free(sb); return nil, prog_err
	}
	sb.shader_program = prog
	
	// Get uniform locations.
	// Using cstring literals directly. Some Odin GL bindings might handle this.
	// If not, explicit conversion (strings.clone_to_cstring) is needed.
	// For example: cstr_proj := strings.clone_to_cstring("uProjectionMatrix"); defer free(cstr_proj); sb.u_projection_matrix_loc = gl.GetUniformLocation(prog, cstr_proj)
	// Assuming current GL bindings handle string literals correctly for GetUniformLocation for brevity as per prompt.
	sb.u_projection_matrix_loc = gl.GetUniformLocation(prog, "uProjectionMatrix")
	sb.u_model_view_matrix_loc = gl.GetUniformLocation(prog, "uModelViewMatrix")
	sb.u_texture_loc =           gl.GetUniformLocation(prog, "uTexture")


	// 2. Create VAO and VBO
	gl.GenVertexArrays(1, &sb.vao)
	gl.GenBuffers(1, &sb.vbo)

	gl.BindVertexArray(sb.vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, sb.vbo)
	
	gl.BufferData(gl.ARRAY_BUFFER, len(sb.vertices) * VERTEX_SIZE_BYTES, nil, gl.DYNAMIC_DRAW)

	// Vertex attributes
	gl.EnableVertexAttribArray(0) // aPos
	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, VERTEX_SIZE_BYTES, uintptr(offset_of(SpriteVertex, pos)))
	
	gl.EnableVertexAttribArray(1) // aTexCoord
	gl.VertexAttribPointer(1, 2, gl.FLOAT, false, VERTEX_SIZE_BYTES, uintptr(offset_of(SpriteVertex, uv)))
	
	gl.EnableVertexAttribArray(2) // aColor
	gl.VertexAttribPointer(2, 4, gl.UNSIGNED_BYTE, true, VERTEX_SIZE_BYTES, uintptr(offset_of(SpriteVertex, col)))


	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	gl.BindVertexArray(0)

	// 3. Set default projection matrix
	sb.projection_matrix = math.orthographic_projection(0, f32(window_width), f32(window_height), 0, -1, 1)
	sb.model_view_matrix = math.matrix4_identity()

	return sb, nil
}

destroy_sprite_batch :: proc(sb: ^SpriteBatch) {
	if sb == nil { return }
	// Detach shaders before deleting program, though not strictly necessary as DeleteProgram handles it.
	// gl.DetachShader(sb.shader_program, sb.vertex_shader)
	// gl.DetachShader(sb.shader_program, sb.fragment_shader)
	gl.DeleteProgram(sb.shader_program)
	gl.DeleteShader(sb.vertex_shader)
	gl.DeleteShader(sb.fragment_shader)
	gl.DeleteBuffers(1, &sb.vbo)
	gl.DeleteVertexArrays(1, &sb.vao)
	free(sb)
}

begin :: proc(sb: ^SpriteBatch, model_view_matrix: Maybe(math.Matrix4f)) {
	assert(!sb.drawing, "SpriteBatch.End() must be called before Begin()")
	sb.drawing = true
	
	gl.UseProgram(sb.shader_program)
	gl.UniformMatrix4fv(sb.u_projection_matrix_loc, 1, false, &sb.projection_matrix[0][0])

	if mvm, ok := model_view_matrix; ok {
		sb.model_view_matrix = mvm
	} else {
		sb.model_view_matrix = math.matrix4_identity()
	}
	gl.UniformMatrix4fv(sb.u_model_view_matrix_loc, 1, false, &sb.model_view_matrix[0][0])

	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    
    gl.ActiveTexture(gl.TEXTURE0) // Sprites usually use texture unit 0
    gl.Uniform1i(sb.u_texture_loc, 0)

    gl.BindVertexArray(sb.vao) // Bind VAO once per begin
}

draw :: proc(
	sb: ^SpriteBatch,
	texture: ^Texture2D,
	position: math.Vector2f,
	source_rect_maybe: Maybe(math.Recti),
	color: Color,
	rotation_radians: f32,
	origin: math.Vector2f, // In pixels, relative to top-left of sprite frame for rotation/scaling
	scale: math.Vector2f,
) {
	assert(sb.drawing, "SpriteBatch.Begin() must be called before Draw()")
	assert(texture != nil && texture.gl_id != 0, "Attempting to draw with nil or invalid texture")

	inv_tex_width := 1.0 / f32(texture.width)
	inv_tex_height := 1.0 / f32(texture.height)

	src_x, src_y, src_w, src_h: f32
	
	dest_rect_w, dest_rect_h : f32

	if sr, ok := source_rect_maybe; ok {
		src_x = f32(sr.x) * inv_tex_width
		src_y = f32(sr.y) * inv_tex_height
		src_w = f32(sr.w) * inv_tex_width
		src_h = f32(sr.h) * inv_tex_height
		dest_rect_w = f32(sr.w)
		dest_rect_h = f32(sr.h)
	} else {
		src_x, src_y = 0, 0
		src_w, src_h = 1, 1
		dest_rect_w = f32(texture.width)
		dest_rect_h = f32(texture.height)
	}

	// Effective width/height after scaling
	eff_w := dest_rect_w * scale.x
	eff_h := dest_rect_h * scale.y

	// Local quad coordinates, before rotation, relative to origin point
	// The origin is applied *before* scaling and rotation, then translated to final position.
	// If origin = (0,0), rotation is around top-left.
	// If origin = (width/2, height/2), rotation is around center.
	
	// Coordinates of the 4 corners of the sprite relative to `position` after transformation
	// p1 = top-left, p2 = bottom-left, p3 = bottom-right, p4 = top-right
	
	// Define quad corners relative to the 'position' which acts as the pivot point + final translation
	// The 'origin' determines the point within the sprite that 'position' refers to.
	// Example: if origin is (0,0), 'position' is the top-left of the sprite.
	// If origin is (width/2, height/2), 'position' is the center of the sprite.

	// Calculate local corner coordinates relative to the origin parameter
    // The origin is scaled by the scale factor
	scaled_origin_x := origin.x * scale.x
	scaled_origin_y := origin.y * scale.y

	// Coordinates of the quad corners if there were no rotation, relative to the final 'position'
	// (i.e., after origin and scaling have been applied, before rotation)
	local_x1 := -scaled_origin_x          // Top-left X
	local_y1 := -scaled_origin_y          // Top-left Y
	local_x2 := eff_w - scaled_origin_x   // Top-right X (width - origin.x) * scale.x
	local_y2 := eff_h - scaled_origin_y   // Bottom-left Y (height - origin.y) * scale.y
	
	final_x1, final_y1: f32 // Top-left
	final_x2, final_y2: f32 // Bottom-left
	final_x3, final_y3: f32 // Bottom-right
	final_x4, final_y4: f32 // Top-right

	if rotation_radians == 0 {
		final_x1 = position.x + local_x1
		final_y1 = position.y + local_y1
		final_x2 = position.x + local_x1 
		final_y2 = position.y + local_y2 
		final_x3 = position.x + local_x2 
		final_y3 = position.y + local_y2 
		final_x4 = position.x + local_x2 
		final_y4 = position.y + local_y1 
	} else {
		cos_r := math.cos(rotation_radians)
		sin_r := math.sin(rotation_radians)

		// Top-left
		final_x1 = position.x + local_x1 * cos_r - local_y1 * sin_r
		final_y1 = position.y + local_x1 * sin_r + local_y1 * cos_r
		// Bottom-left (local_x1, local_y2)
		final_x2 = position.x + local_x1 * cos_r - local_y2 * sin_r
		final_y2 = position.y + local_x1 * sin_r + local_y2 * cos_r
		// Bottom-right (local_x2, local_y2)
		final_x3 = position.x + local_x2 * cos_r - local_y2 * sin_r
		final_y3 = position.y + local_x2 * sin_r + local_y2 * cos_r
		// Top-right (local_x2, local_y1)
		final_x4 = position.x + local_x2 * cos_r - local_y1 * sin_r
		final_y4 = position.y + local_x2 * sin_r + local_y1 * cos_r
	}

	// Triangle 1: TL, BL, BR
	sb.vertices[0] = SpriteVertex{{final_x1, final_y1}, {src_x,         src_y        }, color}
	sb.vertices[1] = SpriteVertex{{final_x2, final_y2}, {src_x,         src_y + src_h}, color}
	sb.vertices[2] = SpriteVertex{{final_x3, final_y3}, {src_x + src_w, src_y + src_h}, color}
	// Triangle 2: TL, BR, TR
	sb.vertices[3] = SpriteVertex{{final_x1, final_y1}, {src_x,         src_y        }, color}
	sb.vertices[4] = SpriteVertex{{final_x3, final_y3}, {src_x + src_w, src_y + src_h}, color}
	sb.vertices[5] = SpriteVertex{{final_x4, final_y4}, {src_x + src_w, src_y        }, color}

	gl.BindTexture(gl.TEXTURE_2D, texture.gl_id) // Active texture unit 0 is already set in Begin

	// For immediate drawing (MAX_SPRITES_PER_BATCH = 1):
	gl.BindBuffer(gl.ARRAY_BUFFER, sb.vbo) // VAO is already bound from Begin
	gl.BufferSubData(gl.ARRAY_BUFFER, 0, 6 * VERTEX_SIZE_BYTES, raw_data(sb.vertices[:6])) 
	
	// ModelViewMatrix is identity for this draw call as transformations are done on CPU.
	// If a different model-view is needed per sprite, it would be set here.
	// For now, using the one set in Begin() (which could be identity).
	// gl.UniformMatrix4fv(sb.u_model_view_matrix_loc, 1, false, &sb.model_view_matrix[0][0])


	gl.DrawArrays(gl.TRIANGLES, 0, 6)
}
   
draw_simple :: proc(sb: ^SpriteBatch, texture: ^Texture2D, position: math.Vector2f, color: Color) {
	draw(sb, texture, position, nil, color, 0, {0,0}, {1,1})
}
   
draw_source :: proc(sb: ^SpriteBatch, texture: ^Texture2D, position: math.Vector2f, source_rect: math.Recti, color: Color) {
	draw(sb, texture, position, source_rect, color, 0, {0,0}, {1,1})
}

end :: proc(sb: ^SpriteBatch) {
	assert(sb.drawing, "SpriteBatch.Begin() must be called before End()")
	sb.drawing = false
	
    gl.BindVertexArray(0) // Unbind VAO after drawing finishes
	gl.UseProgram(0) 
}
