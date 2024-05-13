#version 410 core

layout (location = 0) in vec3  position;
layout (location = 1) in vec4  colour;
layout (location = 2) in vec2  uv;
layout (location = 3) in float texture;

uniform mat4 u_view_projection;
uniform mat4 u_transform;

out vec4  v_colour;
out vec2  v_uv;
out float v_texture;

void main() {
    v_colour    = colour;
    v_uv        = uv;
    v_texture   = texture;
    gl_Position = u_view_projection * u_transform * vec4(position, 1.0);
}
