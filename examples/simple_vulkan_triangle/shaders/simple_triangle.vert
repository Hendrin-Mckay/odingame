#version 450
layout(location = 0) in vec2 v_Pos;
layout(location = 1) in vec3 v_Col;
layout(location = 0) out vec3 f_Col;
void main() {
    gl_Position = vec4(v_Pos, 0.0, 1.0);
    f_Col = v_Col;
}
