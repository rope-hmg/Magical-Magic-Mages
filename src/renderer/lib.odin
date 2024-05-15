package renderer

import "core:math/linalg/glsl"

import GL "vendor:OpenGL"

MAX_QUADS    :: 2048
MAX_VERTICES :: MAX_QUADS * 4
MAX_INDICES  :: MAX_QUADS * 6
MAX_SAMPLERS :: 16

Stats :: struct {
    draw_calls:     u32,
    triangle_count: u32,
}

Renderer :: struct {
    vao:    u32,
    vbo:    u32,
    ibo:    u32,
    shader: u32,

    element_draw_count: i32,

    stats:   Stats,
    variant: union { Quad_Batch_Renderer } // TODO: Add #no_nil
}

Vertex :: struct {
    position: glsl.vec3,
    colour:   glsl.vec4,
    uv:       glsl.vec2,
    texture:  f32, // Have to use floats because the fragment shader in OpenGL cannot accept ints as input
}

Camera :: struct {
}

// TODO: Spend some time making structs for the public API functions. e.g. Colour, Texture, etc.
// TODO: Use an arena for all temporary allocations during initialisation.

BLACK :: glsl.vec4 { 0, 0, 0, 1 }
WHITE :: glsl.vec4 { 1, 1, 1, 1 }

render_init :: proc(renderer: ^Renderer, shader_path: string) {
    // Make sure that the renderer is a valid pointer and that the quad buffer is not already initialised.
    assert(renderer != nil)

    //----------------------------------------
    // Generate Buffer Objects
    //----------------------------------------

    GL.GenVertexArrays(1, &renderer.vao)
    GL.GenBuffers     (1, &renderer.vbo)
    GL.GenBuffers     (1, &renderer.ibo)

    switch v in renderer.variant {
        case Quad_Batch_Renderer:
            quad_batch_init_data(auto_cast &renderer.variant, renderer.vao, renderer.vbo, renderer.ibo)
    }

    //----------------------------------------
    // Load Shader
    //----------------------------------------

    renderer.shader = GL.CreateProgram()
    vert_shader    := create_shader(GL.  VERTEX_SHADER, shader_path, ".vert")
    frag_shader    := create_shader(GL.FRAGMENT_SHADER, shader_path, ".frag")
    defer {
        GL.DeleteShader(vert_shader)
        GL.DeleteShader(frag_shader)
    }

    if vert_shader == 0 || frag_shader == 0 {
        GL.DeleteProgram(renderer.shader)
    } else {
        GL.AttachShader(renderer.shader, vert_shader)
        GL.AttachShader(renderer.shader, frag_shader)
        defer {
            GL.DetachShader(renderer.shader, vert_shader)
            GL.DetachShader(renderer.shader, frag_shader)
        }

        GL.LinkProgram(renderer.shader)

        if status_is_good(
            renderer.shader,
            GL.LINK_STATUS,
            GL.GetProgramiv,
            GL.GetProgramInfoLog,
            "Shader linking failed:",
        ) {
            GL.UseProgram(renderer.shader)

            switch v in renderer.variant {
                case Quad_Batch_Renderer:
                    quad_batch_init_uniforms(auto_cast &renderer.variant, renderer.shader)
            }
        } else {
            // Not sure if this is the right thing to do.
            render_destroy(renderer)
        }
    }
}

render_destroy :: proc(renderer: ^Renderer) {
    assert(renderer != nil)

    switch v in renderer.variant {
        case Quad_Batch_Renderer:
            quad_batch_destroy(auto_cast &renderer.variant)
    }

    GL.DeleteProgram     (renderer.shader)
    GL.DeleteBuffers     (1, &renderer.ibo)
    GL.DeleteBuffers     (1, &renderer.vbo)
    GL.DeleteVertexArrays(1, &renderer.vao)
}

render_begin :: proc(renderer: ^Renderer) {
    assert(renderer != nil)

    switch v in renderer.variant {
        case Quad_Batch_Renderer:
            quad_batch_begin(auto_cast &renderer.variant)
    }
}

render_flush :: proc(renderer: ^Renderer) {
    assert(renderer != nil)

    switch v in renderer.variant {
        case Quad_Batch_Renderer:
            quad_batch_flush(auto_cast &renderer.variant, renderer.vbo)
    }

    GL.BindVertexArray(renderer.vao)
    GL.UseProgram(renderer.shader)
    GL.DrawElements(GL.TRIANGLES, renderer.element_draw_count, GL.UNSIGNED_INT, nil)

    renderer.element_draw_count = 0
    renderer.stats.draw_calls  += 1
}
