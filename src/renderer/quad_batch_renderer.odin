package renderer

import "core:math/linalg/glsl"

import GL "vendor:OpenGL"

Quad_Batch_Renderer :: struct {
    quad_buffer_index:  u32,
    next_texture_unit:  i32,
    texture_unit_count: i32,

    quad_buffer:   []Vertex,
    texture_units: []u32,
    samplers:      []i32,
}

@private quad_batch_init_data :: proc(renderer: ^Quad_Batch_Renderer, vao: u32, vbo: u32, ibo: u32) {
    //----------------------------------------
    // Setup the Vertex Buffer Object (vbo)
    //----------------------------------------
    assert(renderer.quad_buffer == nil)

    renderer.quad_buffer = make([]Vertex, MAX_VERTICES)

    GL.BindVertexArray(vao)
    GL.BindBuffer(GL.ARRAY_BUFFER, vbo)
    GL.BufferData(GL.ARRAY_BUFFER, MAX_VERTICES * size_of(Vertex), nil, GL.DYNAMIC_DRAW)

    GL.EnableVertexAttribArray(0)
    GL.EnableVertexAttribArray(1)
    GL.EnableVertexAttribArray(2)
    GL.EnableVertexAttribArray(3)

    GL.VertexAttribPointer(0, 3, GL.FLOAT, GL.FALSE, size_of(Vertex), offset_of(Vertex, position))
    GL.VertexAttribPointer(1, 4, GL.FLOAT, GL.FALSE, size_of(Vertex), offset_of(Vertex, colour))
    GL.VertexAttribPointer(2, 2, GL.FLOAT, GL.FALSE, size_of(Vertex), offset_of(Vertex, uv))
    GL.VertexAttribPointer(3, 1, GL.FLOAT, GL.FALSE, size_of(Vertex), offset_of(Vertex, texture))

    //----------------------------------------
    // Setup the Index Buffer Object (ibo)
    //----------------------------------------

    indices := make([]u32, MAX_INDICES)
    defer delete(indices)

    offset: u32 = 0
    for i := 0; i < MAX_INDICES; i += 6 {
        indices[i + 0] = offset + 0
        indices[i + 1] = offset + 1
        indices[i + 2] = offset + 2

        indices[i + 3] = offset + 2
        indices[i + 4] = offset + 3
        indices[i + 5] = offset + 0

        offset += 4
    }

    GL.BindBuffer(GL.ELEMENT_ARRAY_BUFFER, ibo)
    GL.BufferData(GL.ELEMENT_ARRAY_BUFFER, MAX_INDICES * size_of(u32), &indices[0], GL.STATIC_DRAW)

    //----------------------------------------
    // Setup the White Texture
    //----------------------------------------

    // NOTE:
    // GL.MAX_TEXTURE_IMAGE_UNITS is the number of textures the fragment shader can access.
    // MAX_SAMPLERS is the largest number I'm allowed on my MacBook. No idea how to query this
    // on the shader side, so it has to be constant. Which means even if the hardware can support
    // more we can't use them.
    // One potential solution is to construct the shader from string fragments at runtime, but
    // that sounds like a pain in the ass right now... To be fair, I think it's what the big
    // engines do. Unity, Unreal, Godot, etc.

    GL.GetIntegerv(GL.MAX_COMBINED_TEXTURE_IMAGE_UNITS, &renderer.texture_unit_count)
    renderer.texture_unit_count = min(renderer.texture_unit_count, MAX_SAMPLERS)

    renderer.texture_units = make([]u32, renderer.texture_unit_count)
    renderer.samplers      = make([]i32, renderer.texture_unit_count)

    GL.GenTextures  (1,            &renderer.texture_units[0])
    GL.BindTexture  (GL.TEXTURE_2D, renderer.texture_units[0])
    GL.TexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR)
    GL.TexParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR)
    GL.TexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE)
    GL.TexParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE)

    colour: u32 = 0xFFFF_FFFF
    GL.TexImage2D(GL.TEXTURE_2D, 0, GL.RGBA8, 1, 1, 0, GL.RGBA, GL.UNSIGNED_BYTE, &colour)
}

@private quad_batch_init_uniforms :: proc(renderer: ^Quad_Batch_Renderer, shader: u32) {
    //----------------------------------------
    // Initialise the Samplers
    //----------------------------------------

    GL.UseProgram(shader)

    for i: i32 = 0; i < renderer.texture_unit_count; i += 1 {
        renderer.samplers[i] = i;
    }

    GL.Uniform1iv(
        GL.GetUniformLocation(shader, "u_samplers"),
        renderer.texture_unit_count,
        raw_data(renderer.samplers),
    )
}

@private quad_batch_destroy :: proc(renderer: ^Quad_Batch_Renderer) {
    GL.DeleteTextures(1, &renderer.texture_units[0])

    delete(renderer.quad_buffer)
}

@private quad_batch_begin :: proc(renderer: ^Quad_Batch_Renderer) {
    renderer.quad_buffer_index = 0
}

@private quad_batch_flush :: proc(renderer: ^Quad_Batch_Renderer, vbo: u32) {
    batch_byte_count := int(renderer.quad_buffer_index) * size_of(Vertex)

    GL.BindBuffer   (GL.ARRAY_BUFFER, vbo)
    GL.BufferSubData(GL.ARRAY_BUFFER, 0, batch_byte_count, raw_data(renderer.quad_buffer))

    // NOTE: BindTextureUnit is a GL 4.5 feature, so we can't use it.
    // for i: i32 = 0; i < renderer.next_texture_unit; i += 1 {
    //     GL.BindTextureUnit(u32(i), renderer.texture_units[i])
    // }
}

quad_batch_push_quad_with_colour :: proc(renderer: ^Renderer, position, size: glsl.vec2, colour: glsl.vec4) {
    assert(renderer != nil)

    quad_batch := &renderer.variant.(Quad_Batch_Renderer)

    if batch_full(quad_batch) {
        quad_batch_flush(quad_batch, renderer.vbo)
        quad_batch_begin(quad_batch)
    }

    push_quad(renderer, quad_batch, position, size, colour, 0)
}

quad_batch_push_quad_with_texture :: proc(renderer: ^Renderer, position, size: glsl.vec2, texture_id: u32) {
    assert(renderer != nil)

    quad_batch := &renderer.variant.(Quad_Batch_Renderer)

    if batch_full(quad_batch) {
        quad_batch_flush(quad_batch, renderer.vbo)
        quad_batch_begin(quad_batch)
    }

    texture_unit: i32 = 0

    // Has the texture been used for something in the batch already?
    for i: i32 = 1;
        i < quad_batch.next_texture_unit && texture_unit == 0;
        i += 1
    {
        if quad_batch.texture_units[i] == texture_id {
            texture_unit = i
        }
    }

    // It has not been used before, so we should add it.
    if texture_unit == 0 {
        texture_unit = quad_batch.next_texture_unit

        quad_batch.texture_units[quad_batch.next_texture_unit] = texture_id
        quad_batch.next_texture_unit += 1
    }

    push_quad(renderer, quad_batch, position, size, glsl.vec4 { 0, 0, 0, 0 }, texture_unit)
}

quad_batch_push_quad :: proc {
    quad_batch_push_quad_with_texture,
    quad_batch_push_quad_with_colour,
}

@(private="file")
batch_full :: proc(renderer: ^Quad_Batch_Renderer) -> bool {
    return renderer.quad_buffer_index >= MAX_QUADS ||
           renderer.next_texture_unit >= renderer.texture_unit_count
}

@(private="file")
push_quad :: proc(
    renderer:       ^Renderer,
    quad_batch:     ^Quad_Batch_Renderer,
    position, size: glsl.vec2,
    colour:         glsl.vec4,
    texture_unit:   i32,
) {
    half_size := size / 2

    v0 := &quad_batch.quad_buffer[quad_batch.quad_buffer_index + 0]
    v1 := &quad_batch.quad_buffer[quad_batch.quad_buffer_index + 1]
    v2 := &quad_batch.quad_buffer[quad_batch.quad_buffer_index + 2]
    v3 := &quad_batch.quad_buffer[quad_batch.quad_buffer_index + 3]

    v0.position = glsl.vec3 { position.x - half_size.x, position.y - half_size.y, 0 }
    v1.position = glsl.vec3 { position.x + half_size.x, position.y - half_size.y, 0 }
    v2.position = glsl.vec3 { position.x + half_size.x, position.y + half_size.y, 0 }
    v3.position = glsl.vec3 { position.x - half_size.x, position.y + half_size.y, 0 }

    v0.colour   = colour
    v1.colour   = colour
    v2.colour   = colour
    v3.colour   = colour

    v0.uv       = glsl.vec2 { 0, 0 }
    v1.uv       = glsl.vec2 { 1, 0 }
    v2.uv       = glsl.vec2 { 1, 1 }
    v3.uv       = glsl.vec2 { 0, 1 }

    v0.texture  = f32(texture_unit)
    v1.texture  = f32(texture_unit)
    v2.texture  = f32(texture_unit)
    v3.texture  = f32(texture_unit)

    quad_batch.quad_buffer_index  += 4
    renderer.element_draw_count   += 6
    renderer.stats.triangle_count += 2
}
