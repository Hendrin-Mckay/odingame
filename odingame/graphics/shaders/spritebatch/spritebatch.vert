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
