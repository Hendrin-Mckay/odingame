package graphics

import "core:fmt"
import "core:strings"
import gl "vendor:OpenGL/gl"

SHADER_VERTEX_SOURCE_DEFAULT :: `
#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in vec2 aTexCoord;
layout (location = 2) in vec4 aColor;

out vec2 vTexCoord;
out vec4 vColor;

uniform mat4 uProjectionMatrix;
uniform mat4 uModelViewMatrix;

void main() {
    gl_Position = uProjectionMatrix * uModelViewMatrix * vec4(aPos.x, aPos.y, 0.0, 1.0);
    vTexCoord = aTexCoord;
    vColor = aColor;
}
`

SHADER_FRAGMENT_SOURCE_DEFAULT :: `
#version 330 core
in vec2 vTexCoord;
in vec4 vColor;

out vec4 FragColor;

uniform sampler2D uTexture;

void main() {
    FragColor = texture(uTexture, vTexCoord) * vColor;
}
`

compile_shader :: proc(source: string, type: gl.GLenum) -> (gl.GLuint, error) {
	shader_id := gl.CreateShader(type)
	
	source_cstring := strings.clone_to_cstring(source)
	if source_cstring == nil { 
		gl.DeleteShader(shader_id) 
		return 0, "Failed to convert shader source to cstring"
	}
	defer free(source_cstring) 
	
	// &source_cstring is correct because source_cstring is a cstring (^u8),
	// and glShaderSource expects a pointer to an array of cstrings (**char).
	// A pointer to a single cstring variable works here.
	gl.ShaderSource(shader_id, 1, &source_cstring, nil)
	gl.CompileShader(shader_id)

	success: i32
	gl.GetShaderiv(shader_id, gl.COMPILE_STATUS, &success)
	if success == gl.FALSE {
		info_log_len: i32
		gl.GetShaderiv(shader_id, gl.INFO_LOG_LENGTH, &info_log_len)
		
		info_log_bytes := make([]u8, info_log_len) 
		defer delete(info_log_bytes) 
		
		actual_len: i32 
		gl.GetShaderInfoLog(shader_id, info_log_len, &actual_len, raw_data(info_log_bytes))
		
		// Use actual_len for creating the error string
		err_msg_str := string(info_log_bytes[:actual_len]) 
		err := fmt.tprintf("Shader compilation error (type %v): %s", type, err_msg_str)
		
		gl.DeleteShader(shader_id)
		return 0, err
	}
	return shader_id, nil
}

link_shader_program :: proc(vertex_shader_id, fragment_shader_id: gl.GLuint) -> (gl.GLuint, error) {
	program_id := gl.CreateProgram()
	gl.AttachShader(program_id, vertex_shader_id)
	gl.AttachShader(program_id, fragment_shader_id)
	gl.LinkProgram(program_id)

	success: i32
	gl.GetProgramiv(program_id, gl.LINK_STATUS, &success)
	if success == gl.FALSE {
		info_log_len: i32
		gl.GetProgramiv(program_id, gl.INFO_LOG_LENGTH, &info_log_len)
		
		info_log_bytes := make([]u8, info_log_len)
		defer delete(info_log_bytes)
		
		actual_len: i32 
		gl.GetProgramInfoLog(program_id, info_log_len, &actual_len, raw_data(info_log_bytes))
		
		// Use actual_len for creating the error string
		err_msg_str := string(info_log_bytes[:actual_len]) 
		err := fmt.tprintf("Shader program linking error: %s", err_msg_str)
		
		gl.DeleteProgram(program_id) 
		// Do not delete shaders here; caller should manage them if linking failed.
		return 0, err
	}
	return program_id, nil
}
