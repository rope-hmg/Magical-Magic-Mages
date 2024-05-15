package renderer

import "core:math/linalg/glsl"

Camera :: struct {
    position:   glsl.vec3,
    zoom:       f32,
    projection: glsl.mat4,
}

