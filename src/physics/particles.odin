package physics

import "core:slice"
import "core:math/linalg/glsl"

import "vendor:box2d"
import "vendor:sdl3"

import "game:graphics"

PARTICLE_POOL_SIZE     :: 256
PARTICLE_GRAVITY_SCALE :: 0.11
PARTICLE_DENSITY       :: 0.01
PARTICLE_LIFETIME      :: 2.25

Particle :: struct {
    lifetime: f32,
    texture:  ^sdl3.Texture,
    colour:   graphics.Colour,
    body_id:  box2d.BodyId,
    shape_id: box2d.ShapeId,
}

Particle_System :: struct {
    count:     int,
    particles: [PARTICLE_POOL_SIZE]Particle,
}

make_particle_system :: proc(world_id: box2d.WorldId) -> ^Particle_System {
    system := new(Particle_System)

    for i := 0; i < PARTICLE_POOL_SIZE; i += 1 {
        body_def := box2d.DefaultBodyDef()
        body_def.isEnabled    = false
        body_def.type         = .dynamicBody
        body_def.gravityScale = PARTICLE_GRAVITY_SCALE
        body_id  := box2d.CreateBody(world_id, body_def)

        shape_def := box2d.DefaultShapeDef()
        shape_def.density             = PARTICLE_DENSITY
        shape_def.filter.categoryBits = CATEGORY_PARTICLE
        shape_def.filter.maskBits     = CATEGORY_BLOCK | CATEGORY_WALL
        shape_id  := box2d.CreateCircleShape(body_id, shape_def, box2d.Circle {
            center = {},
            radius = pixels_to_metres(10),
        })

        system.particles[i] = {
            body_id  = body_id,
            shape_id = shape_id,
        }
    }

    return system
}

delete_particle_system :: proc(system: ^Particle_System) {
    free(system)
}

update_and_render_particles :: proc(
    renderer:     ^sdl3.Renderer,
    system:       ^Particle_System,
    delta_seconds: f32,
) {
    for i := 0; i < system.count; i += 1 {
        system.particles[i].lifetime = max(system.particles[i].lifetime - delta_seconds, 0.0)
    }

    for i := system.count - 1; i >= 0; i -= 1 {
        particle := &system.particles[i]
        if particle.lifetime == 0 {
            box2d.Body_Disable(particle.body_id)

            system.count -= 1
            slice.swap(system.particles[:], i, system.count)
        }
    }

    for i := 0; i < system.count; i += 1 {
        particle := system.particles[i]
        texture  := particle.texture
        colour   := particle.colour

        // NOTE: This seems like a dumb way to do this
        // TODO: Check to see if there is a better way to do this
        sdl3.SetTextureAlphaMod(texture, u8((particle.lifetime / 2.0) * 255.0))
        sdl3.SetTextureColorMod(texture, colour.components.r, colour.components.g, colour.components.b)

        render_textured_object(renderer, texture, particle.body_id, particle.shape_id)
    }
}

spawn_particle :: proc(
    system:            ^Particle_System,
    texture:           ^sdl3.Texture,
    colour:             graphics.Colour,
    position, velocity: glsl.vec2,
) {
    if system.count < PARTICLE_POOL_SIZE - 1 {
        particle := &system.particles[system.count]

        particle.lifetime = PARTICLE_LIFETIME
        particle.texture  = texture
        particle.colour   = colour

        box2d.Body_SetTransform     (particle.body_id, position, box2d.Body_GetRotation(particle.body_id))
        box2d.Body_Enable           (particle.body_id)
        box2d.Body_SetLinearVelocity(particle.body_id, velocity)

        system.count += 1
    }
}
