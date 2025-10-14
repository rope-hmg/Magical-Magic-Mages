package main

import "core:fmt"
import "core:math"
import "core:math/linalg/glsl"
import "core:math/rand"
import "core:mem"
import "core:slice"

import "vendor:sdl3"
import "vendor:sdl3/image"
import "vendor:sdl3/ttf"
import "vendor:box2d"

import "game:name"
import "game:wizard"
import "game:physics"
import "game:platform"
import "game:graphics"
import "game:graphics/ui"

Key :: sdl3.Scancode

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
    particle_system := new(Particle_System)

    for i := 0; i < PARTICLE_POOL_SIZE; i += 1 {
        body_def := box2d.DefaultBodyDef()
        body_def.isEnabled    = false
        body_def.type         = .dynamicBody
        body_def.gravityScale = PARTICLE_GRAVITY_SCALE
        body_id  := box2d.CreateBody(world_id, body_def)

        shape_def := box2d.DefaultShapeDef()
        shape_def.density             = PARTICLE_DENSITY
        shape_def.filter.categoryBits = physics.CATEGORY_PARTICLE
        shape_def.filter.maskBits     = physics.CATEGORY_BLOCK | physics.CATEGORY_WALL
        shape_id  := box2d.CreateCircleShape(body_id, shape_def, box2d.Circle {
            center = {},
            radius = physics.pixels_to_metres(10),
        })

        particle_system.particles[i] = {
            body_id  = body_id,
            shape_id = shape_id,
        }
    }

    return particle_system
}

spawn_particle :: proc(system: ^Particle_System, texture: ^sdl3.Texture, colour: graphics.Colour, position, velocity: glsl.vec2) {
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

render_textured_physics_object :: proc(
    renderer: ^sdl3.Renderer,
    texture:  ^sdl3.Texture,
    body_id:   box2d.BodyId,
    shape_id:  box2d.ShapeId,
) {
    position := physics.metres_to_pixels(box2d.Body_GetPosition(body_id))
    aabb     := box2d.Shape_GetAABB(shape_id)
    extent   := physics.metres_to_pixels(aabb.upperBound - aabb.lowerBound)

    rect := sdl3.FRect {
        x = (position.x - extent.x / 2),
        y = (position.y - extent.y / 2),
        w = extent.x,
        h = extent.y,
    }

    sdl3.RenderTexture(renderer, texture, nil, &rect)
}

main :: proc() {
    game_name := name.get_name(); defer delete(game_name)
    width     := i32(1152)
    height    := i32(864)

    game: Game

    platform.run_app(
        game_name, width, height,
        &game,
        init,
        quit,
        handle_event,
        update_and_render,
    )
}

Sounds :: struct {
    hit_wall:      Audio,
    hit_basic:     Audio,
    hit_frozen:    Audio,
    hit_refresher: Audio,
    hit_activator: Audio,
    hit_freezer:   Audio,
    hit_poisoner:  Audio,
}

Game :: struct {
    state: enum {
        Character_Select,
        Bounce_Balls,
        Post_Fight_Scene,
    },

    adventure: adventure.Adventure,

    // Application Stuff
    audio_device:  sdl3.AudioDeviceID,

    // Assets
    sounds:        Sounds,
    ball_textures: [Ball_Type]^sdl3.Texture,

    block_textures: [wizard.Block_Element][wizard.Block_Shape]^sdl3.Texture,

    burning_textures:       [4]^sdl3.Texture,
    burning_texture_index:  int,
    burning_animation_time: f32,

    particle_textures:   [9]^sdl3.Texture,
    particle_spawn_time: f32,
    particle_system:     ^Particle_System,

    status_texture: ^sdl3.Texture,

    // Layout
    scene_area_height:   f32,
    half_wall_thickness: f32,
    arena_width:         f32,

    // UI
    ui: struct {
        ctx: ^ui.Context,

        player_health: ui.Label,
        player_damage: ui.Label,
        others_health: ui.Label,
        others_damage: ui.Label,
    },

    // Gameplay
    world_id:        box2d.WorldId,
    arena_id:        box2d.BodyId,
    arena_walls:     [4]box2d.ShapeId,
    entities:        [2]wizard.Entity,
    enttity_damamge: [2]int,
    arena_rects:     [2]sdl3.Rect,
    turn:            int,

    ball_position:      glsl.vec2,
    ball_escape_vector: glsl.vec2,
    ball_escape_speed:  f32,
    ball_type:          Ball_Type,
    ball_state:         Ball_State,
    ball:               Ball,

    damage_score: int,
}

current_entity :: #force_inline proc(g: ^Game) -> ^wizard.Entity {
    return &g.entities[g.turn]
}

other_entity :: #force_inline proc(g: ^Game) -> ^wizard.Entity {
    return &g.entities[g.turn~1]
}

init :: proc(p: ^platform.Platform, g: ^Game) {
    // TODO: Maybe need to have a `desired_audio_spec`
    g.audio_device = sdl3.OpenAudioDevice(sdl3.AUDIO_DEVICE_DEFAULT_PLAYBACK, nil)
    g.state = .Bounce_Balls

    if g.audio_device == 0 {
        fmt.println("Unable to open audio device:")
        fmt.println(sdl3.GetError())
    } else {
        output_format: sdl3.AudioSpec
        sdl3.GetAudioDeviceFormat(g.audio_device, &output_format, nil)

        g.ui.ctx              = new(ui.Context)
        g.ui.ctx.renderer     = p.renderer
        g.ui.ctx.text_engine  = p.text_engine
        g.ui.ctx.font         = ttf.OpenFont("assets/fonts/Kenney Pixel.ttf", 24)
        g.ui.ctx.text_padding = 2
        g.ui.ctx.spacing      = 2

        g.ui.player_health = ui.create_label(g.ui.ctx, "Health: ", graphics.rgb(200, 60, 60))
        g.ui.player_damage = ui.create_label(g.ui.ctx, "Damage: ", graphics.rgb(60, 200, 60))
        g.ui.others_health = ui.create_label(g.ui.ctx, "Health: ", graphics.rgb(200, 60, 60))
        g.ui.others_damage = ui.create_label(g.ui.ctx, "Damage: ", graphics.rgb(60, 200, 60))

        g.sounds = {
            hit_wall      = load_wav("assets/audio/hit_wall.wav",            g.audio_device, &output_format),
            hit_basic     = load_wav("assets/audio/hit_basic_block.wav",     g.audio_device, &output_format),
            hit_frozen    = load_wav("assets/audio/hit_critical_block.wav",  g.audio_device, &output_format),
            hit_refresher = load_wav("assets/audio/hit_refresher_block.wav", g.audio_device, &output_format),
            hit_activator = load_wav("assets/audio/hit_activator_block.wav", g.audio_device, &output_format),
            hit_freezer   = load_wav("assets/audio/hit_freezer_block.wav",   g.audio_device, &output_format),
            hit_poisoner  = load_wav("assets/audio/hit_poisoner_block.wav",  g.audio_device, &output_format),
        }

        world_def := box2d.DefaultWorldDef()
        world_def.gravity = { 0.0, 20.0 }

        g.world_id = box2d.CreateWorld(world_def)
        g.arena_id = box2d.CreateBody(g.world_id, box2d.DefaultBodyDef())

        wall_shape_def := box2d.DefaultShapeDef()
        wall_shape_def.filter.categoryBits = physics.CATEGORY_WALL
        wall_shape_def.filter.maskBits     = physics.CATEGORY_PARTICLE | physics.CATEGORY_BALL

        g.scene_area_height   = f32(160)
        g.half_wall_thickness = f32(8)
        g.arena_width         = f32(p.width / 2)
        half_wall_height     := f32(p.height) - g.scene_area_height

        left_wall := physics.pixels_to_metres(sdl3.FRect {
            x = g.half_wall_thickness,
            y = half_wall_height + g.scene_area_height,
            w = g.half_wall_thickness,
            h = half_wall_height,
        })

        mid_wall := physics.pixels_to_metres(sdl3.FRect {
            x = g.arena_width,
            y = half_wall_height + g.scene_area_height,
            w = g.half_wall_thickness,
            h = half_wall_height,
        })

        right_wall := physics.pixels_to_metres(sdl3.FRect {
            x = f32(p.width) - g.half_wall_thickness,
            y = half_wall_height + g.scene_area_height,
            w = g.half_wall_thickness,
            h = half_wall_height,
        })

        ceiling := physics.pixels_to_metres(sdl3.FRect {
            x = g.arena_width,
            y = g.half_wall_thickness + g.scene_area_height,
            w = g.arena_width,
            h = g.half_wall_thickness
        })

        g.arena_walls = {
            box2d.CreatePolygonShape(g.arena_id, wall_shape_def, box2d.MakeOffsetBox( left_wall.w,  left_wall.h, {  left_wall.x,  left_wall.y }, box2d.MakeRot(0))),
            box2d.CreatePolygonShape(g.arena_id, wall_shape_def, box2d.MakeOffsetBox(  mid_wall.w,   mid_wall.h, {   mid_wall.x,   mid_wall.y }, box2d.MakeRot(0))),
            box2d.CreatePolygonShape(g.arena_id, wall_shape_def, box2d.MakeOffsetBox(right_wall.w, right_wall.h, { right_wall.x, right_wall.y }, box2d.MakeRot(0))),
            box2d.CreatePolygonShape(g.arena_id, wall_shape_def, box2d.MakeOffsetBox(   ceiling.w,    ceiling.h, {    ceiling.x,    ceiling.y }, box2d.MakeRot(0))),
        }

        g.ball_escape_vector = { 1, -1 }
        g.ball_escape_speed  = 1.0

        g.ball_type     = .Basic
        g.ball_state    = .Picking_A_Spot
        g.ball_textures = {
            .Basic = image.LoadTexture(p.renderer, "assets/graphics/ballGrey.png"),
            .Blue  = image.LoadTexture(p.renderer, "assets/graphics/ballBlue.png"),
        }

        g.block_textures = {
            .Basic = {
                .Diamond   = image.LoadTexture(p.renderer, "assets/graphics/element_grey_diamond.png"),
                .Pentagon  = image.LoadTexture(p.renderer, "assets/graphics/element_grey_polygon.png"),
                .Square    = image.LoadTexture(p.renderer, "assets/graphics/element_grey_square.png"),
                .Rectangle = image.LoadTexture(p.renderer, "assets/graphics/element_grey_rectangle.png"),
            },
            .Fire = {
                .Diamond   = image.LoadTexture(p.renderer, "assets/graphics/element_red_diamond.png"),
                .Pentagon  = image.LoadTexture(p.renderer, "assets/graphics/element_red_polygon.png"),
                .Square    = image.LoadTexture(p.renderer, "assets/graphics/element_red_square.png"),
                .Rectangle = image.LoadTexture(p.renderer, "assets/graphics/element_red_rectangle.png"),
            },
            .Healing = {
                .Diamond   = image.LoadTexture(p.renderer, "assets/graphics/element_green_diamond.png"),
                .Pentagon  = image.LoadTexture(p.renderer, "assets/graphics/element_green_polygon.png"),
                .Square    = image.LoadTexture(p.renderer, "assets/graphics/element_green_square.png"),
                .Rectangle = image.LoadTexture(p.renderer, "assets/graphics/element_green_rectangle.png"),
            },
            .Electric = {
                .Diamond   = image.LoadTexture(p.renderer, "assets/graphics/element_yellow_diamond.png"),
                .Pentagon  = image.LoadTexture(p.renderer, "assets/graphics/element_yellow_polygon.png"),
                .Square    = image.LoadTexture(p.renderer, "assets/graphics/element_yellow_square.png"),
                .Rectangle = image.LoadTexture(p.renderer, "assets/graphics/element_yellow_rectangle.png"),
            },
            .Ice = {
                .Diamond   = image.LoadTexture(p.renderer, "assets/graphics/element_blue_diamond.png"),
                .Pentagon  = image.LoadTexture(p.renderer, "assets/graphics/element_blue_polygon.png"),
                .Square    = image.LoadTexture(p.renderer, "assets/graphics/element_blue_square.png"),
                .Rectangle = image.LoadTexture(p.renderer, "assets/graphics/element_blue_rectangle.png"),
            },
            .Poison = {
                .Diamond   = image.LoadTexture(p.renderer, "assets/graphics/element_purple_diamond.png"),
                .Pentagon  = image.LoadTexture(p.renderer, "assets/graphics/element_purple_polygon.png"),
                .Square    = image.LoadTexture(p.renderer, "assets/graphics/element_purple_square.png"),
                .Rectangle = image.LoadTexture(p.renderer, "assets/graphics/element_purple_rectangle.png"),
            },
        }

        g.burning_textures = {
            image.LoadTexture(p.renderer, "assets/graphics/particles/flame_01.png"),
            image.LoadTexture(p.renderer, "assets/graphics/particles/flame_02.png"),
            image.LoadTexture(p.renderer, "assets/graphics/particles/flame_03.png"),
            image.LoadTexture(p.renderer, "assets/graphics/particles/flame_04.png"),
        }

        g.burning_animation_time = f32(0.2)

        for texture in g.burning_textures {
            sdl3.SetTextureColorMod(texture, 255, 0, 0)
        }

        g.particle_textures = {
            image.LoadTexture(p.renderer, "assets/graphics/particles/star_01.png"),
            image.LoadTexture(p.renderer, "assets/graphics/particles/star_02.png"),
            image.LoadTexture(p.renderer, "assets/graphics/particles/star_03.png"),
            image.LoadTexture(p.renderer, "assets/graphics/particles/star_04.png"),
            image.LoadTexture(p.renderer, "assets/graphics/particles/star_05.png"),
            image.LoadTexture(p.renderer, "assets/graphics/particles/star_06.png"),
            image.LoadTexture(p.renderer, "assets/graphics/particles/star_07.png"),
            image.LoadTexture(p.renderer, "assets/graphics/particles/star_08.png"),
            image.LoadTexture(p.renderer, "assets/graphics/particles/star_09.png"),
        }

        g.particle_system = make_particle_system(g.world_id)
        g.status_texture = image.LoadTexture(p.renderer, "assets/graphics/particles/circle_02.png")

        g.arena_rects[0] = {   0, 160, 400, 460 }
        g.arena_rects[1] = { 400, 160, 400, 460 }

        player := wizard.Wizard {
            rank = .White,
        }

        g.entities[0] = {
            health  = 100,
            arena   = wizard.make_spell_arena(
                g.world_id, wizard.get_arena_layout_for_wizard(player),
                0, 160, 400, 460, // g.arena_rects[0]
            ),
            variant = player,
        }
    }
}

quit :: proc(p: ^platform.Platform, g: ^Game) {
    if g.ui.ctx != nil {
        if g.ui.ctx.font != nil { ttf.CloseFont(g.ui.ctx.font) }

        free(g.ui.ctx)
    }

    if g.audio_device != 0 {
        sdl3.CloseAudioDevice(g.audio_device)
    }
}

handle_event :: proc(p: ^platform.Platform, g: ^Game, e: sdl3.Event) {
    #partial switch e.type {
        case .KEY_UP:
            if e.key.scancode == Key.R {
                wizard.delete_spell_arena(g.entities[1].arena)

                g.entities[1] = {
                    health = 100,
                    arena  = wizard.make_spell_arena(
                        g.world_id, adventure.get_test_arena_layout_for_stage(),
                        400, 160, 400, 460, // g.arena_rects[1]
                    ),
                    variant = wizard.Beast {}
                }
            }
    }
}

update_and_render :: proc(p: ^platform.Platform, g: ^Game) {
    switch g.state {
        case .Character_Select:

        case .Bounce_Balls:
            bounce_balls(p, g)

        case .Post_Fight_Scene:
    }
}

bounce_balls :: proc(p: ^platform.Platform, g: ^Game) {
    // ============
    // !!! Ball !!!
    //

    switch g.ball_state {
        case .Picking_A_Spot:
            ball_info := BALL_INFO[g.ball_type]

            // TODO: Adjust for the second turn
            min_x := g.arena_width * f32(g.turn + 0) + (g.half_wall_thickness * 2)
            max_x := g.arena_width * f32(g.turn + 1) - (g.half_wall_thickness + ball_info.size_in_pixels)

            g.ball_position = {
                clamp(platform.mouse_position(p.mouse).x - ball_info.size_in_pixels / 2, min_x, max_x),
                g.scene_area_height + ball_info.size_in_pixels * 2,
            }

            rect := sdl3.FRect {
                x = g.ball_position.x,
                y = g.ball_position.y,
                w = ball_info.size_in_pixels,
                h = ball_info.size_in_pixels,
            }

            sdl3.RenderTexture(p.renderer, g.ball_textures[g.ball_type], nil, &rect)

            if platform.button_pressed(p.mouse, .Left) {
                g.ball_state = .Aiming
            }

        case .Aiming:
            ball_info := BALL_INFO[g.ball_type]
            rect      := sdl3.FRect {
                x = g.ball_position.x,
                y = g.ball_position.y,
                w = ball_info.size_in_pixels,
                h = ball_info.size_in_pixels,
            }

            sdl3.RenderTexture(p.renderer, g.ball_textures[g.ball_type], nil, &rect)

            if platform.button_released(p.mouse, .Left) {
                g.ball       = create_ball(g.world_id, g.ball_position, platform.mouse_position(p.mouse) - g.ball_position, g.ball_type)
                g.ball_state = .Flying_About_The_Place
            }

        case .Flying_About_The_Place:
            ball_info := BALL_INFO[g.ball.type]

            render_textured_physics_object(
                p.renderer,
                g.ball_textures[g.ball.type],
                g.ball.body_id,
                g.ball.shape_id,
            )

            g.ball_position = box2d.Body_GetPosition      (g.ball.body_id)
            ball_velocity  := box2d.Body_GetLinearVelocity(g.ball.body_id)
            ball_speed     := glsl.length(ball_velocity)

            g.particle_spawn_time += p.delta_seconds

            if g.particle_spawn_time >= (1 / ball_speed) * 0.6 {
                g.particle_spawn_time = 0.0

                back  := glsl.normalize(ball_velocity) * physics.pixels_to_metres(ball_info.size_in_pixels * -0.5)
                side1 := glsl.vec2 {  back.y, -back.x }
                side2 := glsl.vec2 { -back.y,  back.x }

                sides := []glsl.vec2 { side1, side2 }
                back  += rand.choice(sides) * 0.2

                valid_colours := current_entity(g).arena.colours

                spawn_particle(g.particle_system, rand.choice(g.particle_textures[:]), rand.choice(valid_colours), g.ball_position + back  * rand.float32(), back  * 2)
                spawn_particle(g.particle_system, rand.choice(g.particle_textures[:]), rand.choice(valid_colours), g.ball_position + side1 * rand.float32(), side1 * 2)
                spawn_particle(g.particle_system, rand.choice(g.particle_textures[:]), rand.choice(valid_colours), g.ball_position + side2 * rand.float32(), side2 * 2)
            }

            if physics.metres_to_pixels(g.ball_position.y) - ball_info.size_in_pixels /* / 2 */ > f32(p.height) {
                g.ball_state        = .Picking_A_Spot
                g.damage_score      = 0
                g.ball_escape_speed = 1.0

                box2d.DestroyBody(g.ball.body_id)
                current := current_entity(g)
                  other :=   other_entity(g)

                if current.arena.disabled == len(current.arena.blocks) {
                    wizard.restore_spell_arena(&current.arena)
                }

                  other.health -= current.damage
                current.damage  = 0

                if other.variant != nil && other.health <= 0 {
                    other.health = 100
                    fmt.println("You win!")
                }

                g.turn ~= 1

                if g.turn == 0 {
                    g.ball_type = g.ball_type == .Basic ? .Blue : .Basic
                }
            }

            if !box2d.Body_IsAwake(g.ball.body_id) {
                box2d.Body_SetLinearVelocity(g.ball.body_id, g.ball_escape_vector * g.ball_escape_speed)
                box2d.Body_SetAwake         (g.ball.body_id, true)

                g.ball_escape_speed    *=  1.2
                g.ball_escape_vector.x *= -1.0
            }
    }

    // ==============
    // !!! Blocks !!!
    //

    sdl3.SetRenderDrawColor(p.renderer, 255, 0, 0, 255)

    for entity in g.entities {
        for block in entity.arena.blocks {
            if box2d.Body_IsEnabled(block.body_id) {
                texture := g.block_textures[block.element][block.shape]

                render_textured_physics_object(p.renderer, texture, block.body_id, block.shape_id)

                // position := box2d.Body_GetPosition(block.body_id)
                // polygon  := box2d.Shape_GetPolygon(block.shape_id)

                // for i, j := polygon.count - 1, i32(0);
                //        j  < polygon.count;
                //     i, j  = j, j + 1
                // {
                //     p1 := physics.metres_to_pixels(position + polygon.vertices[i])
                //     p2 := physics.metres_to_pixels(position + polygon.vertices[j])

                //     sdl3.RenderLine(p.renderer, p1.x, p1.y, p2.x, p2.y)
                // }

                if block.status != .None {
                    // TODO: Improve this whole thing. It looks awful.
                    element: wizard.Block_Element

                    switch block.status {
                        case .None: panic("Well that's weird")

                        case .Burning:     element = .Fire
                        case .Frozen:      element = .Ice
                        case .Charged:     element = .Electric
                        case .Electrified: element = .Electric
                    }

                    position := physics.metres_to_pixels(box2d.Body_GetPosition(block.body_id))
                    aabb     := box2d.Shape_GetAABB(block.shape_id)
                    extent   := physics.metres_to_pixels(aabb.upperBound - aabb.lowerBound)
                    size     := max(extent.x, extent.y) + 10.0
                    offset   := size / 2.0

                    rect := sdl3.FRect {
                        x = position.x - offset,
                        y = position.y - offset,
                        w = size,
                        h = size,
                    }

                    colour := wizard.BLOCK_COLOURS.elements[element].components

                    sdl3.SetTextureColorMod(g.status_texture, colour.r, colour.g, colour.b)
                    sdl3.RenderTexture(p.renderer, g.status_texture, nil, &rect)
                }
            }
        }
    }

    // =================
    // !!! Particles !!!
    //

    for i := 0; i < g.particle_system.count; i += 1 {
        g.particle_system.particles[i].lifetime = max(0.0, g.particle_system.particles[i].lifetime - p.delta_seconds)
    }

    for i := g.particle_system.count - 1; i >= 0; i -= 1 {
        particle := &g.particle_system.particles[i]
        if particle.lifetime == 0 {
            box2d.Body_Disable(particle.body_id)

            g.particle_system.count -= 1
            slice.swap(g.particle_system.particles[:], i, g.particle_system.count)
        }
    }

    for i := 0; i < g.particle_system.count; i += 1 {
        particle := g.particle_system.particles[i]
        texture  := particle.texture
        colour   := particle.colour

        // NOTE: This seems like a dumb way to do this
        // TODO: Check to see if there is a better way to do this
        sdl3.SetTextureAlphaMod(texture, u8((particle.lifetime / 2.0) * 255.0))
        sdl3.SetTextureColorMod(texture, colour.components.r, colour.components.g, colour.components.b)
        render_textured_physics_object(p.renderer, texture, particle.body_id, particle.shape_id)
    }

    // ======================
    // !!! User Interface !!!
    //

    __draw_health_and_damage_ui :: proc(
        ctx:              ^ui.Context,
        x, y:              f32,
        align:             ui.Layout_Align,
        h_label, d_label: ^ui.Label,
        health, damage:    int,
    ) {
        HEALTH_OFFSET :: len("Health: ")
        DAMAGE_OFFSET :: len("Damage: ")

        ui.push_layout_scope(ctx, ui.column_layout(x, y, align))

        health_string := ui.int_to_string(health)
        damage_string := ui.int_to_string(damage)

        ui.insert_text(ctx, h_label, HEALTH_OFFSET, health_string)
        ui.insert_text(ctx, d_label, DAMAGE_OFFSET, damage_string)

        ui.label(ctx, h_label^)
        ui.label(ctx, d_label^)

        ui.delete_text(ctx, h_label, HEALTH_OFFSET, len(health_string))
        ui.delete_text(ctx, d_label, DAMAGE_OFFSET, len(damage_string))
    }

    player := &g.entities[0]
    others := &g.entities[1]

    __draw_health_and_damage_ui(g.ui.ctx,                10, 10, .Left,  &g.ui.player_health, &g.ui.player_damage, player.health, player.damage)
    __draw_health_and_damage_ui(g.ui.ctx, f32(p.width) - 10, 10, .Right, &g.ui.others_health, &g.ui.others_damage, others.health, others.damage)

    // =================
    // !!! Arena     !!!
    //

    sdl3.SetRenderDrawColor(p.renderer, 0, 255, 0, 255)

    for wall, i in g.arena_walls {
        polygon  := box2d.Shape_GetPolygon(wall)
        position := physics.metres_to_pixels(polygon.centroid)
        aabb     := box2d.Shape_GetAABB(wall)
        extent   := physics.metres_to_pixels(aabb.upperBound - aabb.lowerBound)

        rect := sdl3.FRect {
            x = position.x - extent.x / 2,
            y = position.y - extent.y / 2,
            w = extent.x,
            h = extent.y,
        }

        sdl3.RenderFillRect(p.renderer, &rect)
    }

    // =================
    // !!! Physics   !!!
    //

    SUB_STEP_COUNT :: 4
    box2d.World_Step(g.world_id, p.delta_seconds, SUB_STEP_COUNT)

    events := box2d.World_GetContactEvents(g.world_id)

    for i: i32 = 0; i < events.hitCount; i += 1 {
        event     := events.hitEvents[i]
        user_data := box2d.Shape_GetUserData(event.shapeIdA)

        if user_data == nil {
            play_sound(g.sounds.hit_wall)
        } else {
            hit_block(g, cast(^wizard.Spell_Block) user_data)
        }
    }
}

hit_block :: proc(g: ^Game, block: ^wizard.Spell_Block) {
    __hit_block :: proc(g: ^Game, block: ^wizard.Spell_Block) {
        ball_info := BALL_INFO[g.ball.type]

        current := current_entity(g)
          other :=   other_entity(g)

        hit_sound: Audio

        switch block.element {
            case .Basic:
                hit_sound = g.sounds.hit_basic

            case .Fire:
                wizard.apply_status_effect(other.arena.blocks, .Burning, 4)

            case .Healing:

            case .Electric:
                // wizard.apply_status_effect(other.arena, .Electrified, 4)

                // TODO: Ray cast in four directions to find blocks to
                //       charge.
                //       Charged blocks get the status applied to them
                //       Timer, charged blocks propagate in one direction
                //       One time, charged blocks break and trigger.

            case .Ice:
                wizard.apply_status_effect(other.arena.blocks, .Frozen, 4)

                hit_sound = g.sounds.hit_freezer

            case .Poison:
                hit_sound = g.sounds.hit_poisoner
        }

        block.health -= 1
        block.element = .Basic // Magic blocks only last a single hit

        current.damage += ball_info.basic_damage

        if block.health == 0 {
            box2d.Body_Disable(block.body_id)
            current.arena.disabled += 1
        }

        play_sound(hit_sound)
    }

    current := current_entity(g)

    switch block.status {
        case .Charged: fallthrough
        case .None:
            __hit_block(g, block)

        case .Burning:
            // TODO: play_sound(hit_burning_sound)
            current.health -= 1
            block.status    = .None

            __hit_block(g, block)

        case .Frozen:
            play_sound(g.sounds.hit_frozen)
            block.status = .None

        case .Electrified:
    }
}

Audio :: struct {
    format:  sdl3.AudioSpec,
    stream: ^sdl3.AudioStream,

    buffer_data: [^]u8,
    buffer_len:  i32,
}

load_wav :: proc(path: cstring, output_device: sdl3.AudioDeviceID, output_format: ^sdl3.AudioSpec) -> Audio {
    audio_format: sdl3.AudioSpec
    buffer_data:  [^]u8
    buffer_len:   u32

    sdl3.LoadWAV(path, &audio_format, &buffer_data, &buffer_len)

    audio_stream := sdl3.CreateAudioStream(&audio_format, output_format)

    sdl3.BindAudioStream(output_device, audio_stream)

    return {
        format      = audio_format,
        stream      = audio_stream,
        buffer_data = buffer_data,
        buffer_len  = i32(buffer_len),
    }
}

play_sound :: #force_inline proc(sound: Audio) {
    sdl3.PutAudioStreamData(sound.stream, sound.buffer_data, sound.buffer_len)
}

Ball_State :: enum {
    Picking_A_Spot,
    Aiming,
    Flying_About_The_Place,
}

Ball_Type :: enum {
    Basic,
    Blue,
}

Ball_Info :: struct {
       basic_damage: int,
    critical_damage: int,

    size_in_pixels: f32,
    friction:       f32,
    restitution:    f32,
    // Other interesting properties
}

BALL_INFO := [Ball_Type]Ball_Info {
    .Basic = {
           basic_damage = 2,
        critical_damage = 3,
        size_in_pixels  = 16,
        friction        = 0.1,
        restitution     = 0.5,
    },

    .Blue = {
           basic_damage = 1,
        critical_damage = 8,
        size_in_pixels  = 32,
        friction        = 0.1,
        restitution     = 0.6,
    }
}

Ball :: struct {
    type:     Ball_Type,
    body_id:  box2d.BodyId,
    shape_id: box2d.ShapeId,
}

create_ball :: proc(world_id: box2d.WorldId, position, velocity: glsl.vec2, type: Ball_Type) -> Ball {
    ball_info := BALL_INFO[type]
    body_def  := box2d.DefaultBodyDef()
    body_def.position       = physics.pixels_to_metres(position)
    body_def.linearVelocity = physics.pixels_to_metres(velocity)
    body_def.type           = .dynamicBody
    body_def.isBullet       = true
    body_def.fixedRotation  = false // Not sure about this?

    circle := box2d.Circle {
        center = {},
        radius = physics.pixels_to_metres(ball_info.size_in_pixels * 0.5)
    }

    shape_def := box2d.DefaultShapeDef()
    shape_def.material.friction    = ball_info.friction
    shape_def.material.restitution = ball_info.restitution
    shape_def.enableHitEvents      = true

    body_id  := box2d.CreateBody(world_id, body_def)
    shape_id := box2d.CreateCircleShape(body_id, shape_def, circle)

    return { type, body_id, shape_id }
}