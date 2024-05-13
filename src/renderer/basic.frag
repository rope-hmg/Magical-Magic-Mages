#version 410 core

layout (location = 0) out vec4 frag_colour;

in vec4  v_colour;
in vec2  v_uv;
in float v_texture;

// MAX_SAMPLERS defined in renderer/lib.odin
uniform sampler2D u_samplers[16];

void main() {
    frag_colour = texture(u_samplers[int(v_texture)], v_uv) * v_colour;
}
