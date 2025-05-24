#version 330 core
in vec4 vs_Color;
in vec2 vs_TexCoord;

out vec4 fs_Color;

uniform sampler2D u_Texture; // Texture unit 0

void main() {
    fs_Color = vs_Color * texture(u_Texture, vs_TexCoord);
}
