package main

import "core:fmt"
import "core:strings"
import "core:math"
import "core:math/linalg/glsl"
import "core:math/rand"
import "core:mem"
import "core:slice"

import "vendor:sdl3"
import "vendor:sdl3/image"
import "vendor:sdl3/ttf"
import "vendor:box2d"

import "game:adventure"
import "game:name"
import "game:wizard"
import "game:entity"
import "game:physics"
import "game:platform"
import "game:graphics"
import "game:graphics/ui"

main :: proc() {
    game: Game
    game_name := name.get_name(); defer delete(game_name)

    platform.run_app(
        game_name,
        &game,
        init,
        quit,
        handle_event,
        update_and_render,
    )
}

// ----------------------------------------------
// Game
// ----------------------------------------------

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
        Title,
        Character_Select,
        Adventure_Select,
        Battle,
        Camp_Fire,
        Post_Game,
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
    select_texture: ^sdl3.Texture,

    // Layout
    scene_height:        f32,
    half_wall_thickness: f32,
    arena_width:         f32,
    arena_height:        f32,
    arena_offsets:       [entity.Turn]glsl.vec2,

    // UI
    ui: struct {
        ctx: ^ui.Context,

        // Battle UI
        player_health: ui.Label,
        player_damage: ui.Label,
        others_health: ui.Label,
        others_damage: ui.Label,

        // Title Screen UI
        play:    ui.Button,
        options: ui.Button,
        quit:    ui.Button,


        // Character Select UI
        select_character: ui.Label,
        select_weapon:    ui.Label,

        // Camp Fire UI
        action_points:      ui.Label,
        continue_journey:   ui.Button,
        rest:               ui.Button,
        investigate:        ui.Button,
        study:              ui.Button,
        current_rank:       ui.Label,
        study_exp:          ui.Label,
        study_cost:         ui.Label,
        investigation_cost: ui.Label,
    },

    // Gameplay
    world_id:        box2d.WorldId,
    arena_id:        box2d.BodyId,
    arena_walls:     [4]box2d.ShapeId,
    player:          wizard.Wizard,
    entities:        entity.Entities,

    // Character Select
    selected_character: wizard.Character,

    // Camp Fire
    have_setup_camp:  bool,
    has_rested:       bool,
    has_investigated: bool,
    has_studied:      bool,
    action_points:    int,

    ball_position:      glsl.vec2,
    ball_escape_vector: glsl.vec2,
    ball_escape_speed:  f32,
    ball_type:          Ball_Type,
    ball_state:         Ball_State,
    ball:               Ball,
}

init :: proc(p: ^platform.Platform, g: ^Game) {
    // TODO: Maybe need to have a `desired_audio_spec`
    g.audio_device = sdl3.OpenAudioDevice(sdl3.AUDIO_DEVICE_DEFAULT_PLAYBACK, nil)

    if g.audio_device == 0 {
        fmt.println("Unable to open audio device:")
        fmt.println(sdl3.GetError())
    } else {
        output_format: sdl3.AudioSpec
        sdl3.GetAudioDeviceFormat(g.audio_device, &output_format, nil)

        g.ui.ctx = ui.make_context(
            p.renderer,
            p.text_engine,
            ttf.OpenFont("assets/fonts/Kenney Pixel.ttf", 24),
            &p.mouse,
        )
        g.ui.ctx.text_padding = 2
        g.ui.ctx.spacing      = 2

        red   := graphics.rgb(200,  60,  60)
        green := graphics.rgb( 60, 200,  60)
        blue  := graphics.rgb( 60,  60, 200)
        grey  := graphics.rgb(200, 200, 200)

        // Battle UI
        g.ui.player_health = ui.create_label(g.ui.ctx, "Health: ", red)
        g.ui.player_damage = ui.create_label(g.ui.ctx, "Damage: ", green)
        g.ui.others_health = ui.create_label(g.ui.ctx, "Health: ", red)
        g.ui.others_damage = ui.create_label(g.ui.ctx, "Damage: ", green)

        // Title Screen UI
        g.ui.play    = ui.create_button(g.ui.ctx, "Play",    green)
        g.ui.options = ui.create_button(g.ui.ctx, "Options", grey)
        g.ui.quit    = ui.create_button(g.ui.ctx, "Quit",    grey)

        // Character Select UI
        g.ui.select_character = ui.create_label(g.ui.ctx, "Select Character", blue)
        g.ui.select_weapon    = ui.create_label(g.ui.ctx, "Select Weapon", blue)

        // Camp Fire UI
        g.ui.action_points      = ui.create_label (g.ui.ctx, "Action Points: ",  grey)
        g.ui.continue_journey   = ui.create_button(g.ui.ctx, "Continue Journey", red)
        g.ui.rest               = ui.create_button(g.ui.ctx, "Rest and Recover", red)
        g.ui.investigate        = ui.create_button(g.ui.ctx, "Investigate",      green)
        g.ui.study              = ui.create_button(g.ui.ctx, "Study Grimoire",   blue)
        g.ui.current_rank       = ui.create_label (g.ui.ctx, "Rank: ",           grey)
        g.ui.study_exp          = ui.create_label (g.ui.ctx, "Progress: ",       grey)
        g.ui.study_cost         = ui.create_label (g.ui.ctx, "Cost: ",           grey)
        g.ui.investigation_cost = ui.create_label (g.ui.ctx, "Cost: ",           grey)

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

        g.arena_height        = f32(p.height) * wizard.ARENA_HEIGHT_FRACTION
        g.arena_width         = f32(p.width)  * wizard.ARENA_WIDTH_FRACTION
        g.scene_height        = f32(p.height) - g.arena_height
        half_wall_height     := f32(p.height) - g.scene_height
        g.half_wall_thickness = f32(8)

        g.arena_offsets = {
            .Player = {             0, g.scene_height },
            .Enemy  = { g.arena_width, g.scene_height },
        }

        left_wall := physics.pixels_to_metres(sdl3.FRect {
            x = g.half_wall_thickness,
            y = half_wall_height + g.scene_height,
            w = g.half_wall_thickness,
            h = half_wall_height,
        })

        mid_wall := physics.pixels_to_metres(sdl3.FRect {
            x = g.arena_width,
            y = half_wall_height + g.scene_height,
            w = g.half_wall_thickness,
            h = half_wall_height,
        })

        right_wall := physics.pixels_to_metres(sdl3.FRect {
            x = f32(p.width) - g.half_wall_thickness,
            y = half_wall_height + g.scene_height,
            w = g.half_wall_thickness,
            h = half_wall_height,
        })

        ceiling := physics.pixels_to_metres(sdl3.FRect {
            x = g.arena_width,
            y = g.half_wall_thickness + g.scene_height,
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
        g.select_texture = image.LoadTexture(p.renderer, "assets/graphics/selectorA.png")
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
            if e.key.scancode == .R {
                wizard.delete_spell_arena(g.entities.entities[.Enemy].arena)

                g.entities.entities[.Enemy] = {
                    health = 100,
                    arena  = wizard.make_spell_arena(
                        g.world_id,
                        adventure.get_test_arena_layout_for_stage(),
                        #partial {
                            .Ice      = 1,
                            .Healing  = 1,
                            .Poison   = 1,
                            .Fire     = 1,
                            .Electric = 1,
                        },
                        g.arena_offsets[.Enemy],
                    ),
                }
            }
    }
}

update_and_render :: proc(p: ^platform.Platform, g: ^Game) {
    switch g.state {
        case .Title:            do_title           (p, g)
        case .Character_Select: do_character_select(p, g)
        case .Adventure_Select: do_adventure_select(p, g)
        case .Battle:           do_battle          (p, g)
        case .Camp_Fire:        do_camp_fire       (p, g)
        case .Post_Game:        do_post_game       (p, g)
    }
}

do_title :: proc(p: ^platform.Platform, g: ^Game) {
    ui.push_layout_scope(g.ui.ctx, ui.column_layout(10, 10))

    if ui.button(g.ui.ctx, g.ui.play) {
        g.state = .Character_Select
    }

    if ui.button(g.ui.ctx, g.ui.options) {

    }

    if ui.button(g.ui.ctx, g.ui.quit) {
        p.running = false
    }
}

do_character_select :: proc(p: ^platform.Platform, g: ^Game) {
    ui.push_spacing_scope(g.ui.ctx, 10)

    TWO_THIRDS :: f32(2.0/3.0)
    ONE_THIRD  :: f32(1.0/3.0)

    // Width
    total_padding := g.ui.ctx.spacing * 2
    width         := f32(p.width) - total_padding

    // Height
    total_padding = g.ui.ctx.spacing * 4
    height       := f32(p.height) - total_padding
    two_thirds   := height * TWO_THIRDS - g.ui.continue_journey.h - g.ui.ctx.text_padding * 2
    one_third    := height * ONE_THIRD

    character_window := sdl3.FRect {
        x = g.ui.ctx.spacing,
        y = g.ui.ctx.spacing,
        w = width,
        h = two_thirds,
    }

    weapon_window := sdl3.FRect {
        x = g.ui.ctx.spacing,
        y = g.ui.ctx.spacing + character_window.h + g.ui.ctx.spacing,
        w = width,
        h = one_third,
    }


    __f32_to_i32 :: #force_inline proc(a: f32) -> i32 {
        return i32(glsl.floor(a))
    }

    {
        ui.push_layout_scope(g.ui.ctx, ui.column_layout(character_window.x, character_window.y))

        sdl3.SetRenderDrawColor(p.renderer, 0, 0, 255, 255)
        sdl3.RenderRect(p.renderer, &character_window)

        clip_rect := sdl3.Rect {
            x = __f32_to_i32(character_window.x),
            y = __f32_to_i32(character_window.y),
            w = __f32_to_i32(character_window.w),
            h = __f32_to_i32(character_window.h),
        }

        sdl3.SetRenderClipRect(p.renderer, &clip_rect)

        ui.label(g.ui.ctx, g.ui.select_character)

        character_card := sdl3.FRect {
            x = character_window.x + g.ui.ctx.spacing,
            y = character_window.y + g.ui.ctx.spacing + g.ui.select_character.h + g.ui.ctx.text_padding * 2,
            w = 100,
            h = 100,
        }

        for character, id in wizard.CHARACTERS {
            // TODO: Make this not gay
            text_surface := ttf.RenderText_Solid(
                g.ui.ctx.font,
                cstring(raw_data(character.name)),
                             len(character.name),
                graphics.rgb(200, 60, 60).sdl_colour,
            )

            text_texture := sdl3.CreateTextureFromSurface(p.renderer, text_surface)

            text_rect := sdl3.FRect {
                x = character_card.x + g.ui.ctx.text_padding * 2,
                y = character_card.y + g.ui.ctx.text_padding,
                w = f32(text_surface.w),
                h = f32(text_surface.h),
            }

            defer sdl3.DestroySurface(text_surface)
            defer sdl3.DestroyTexture(text_texture)

            if id == g.selected_character {
                sdl3.SetRenderDrawColor(p.renderer, 0, 255, 0, 255)
            } else {
                sdl3.SetRenderDrawColor(p.renderer, 0, 0, 255, 255)
            }

            sdl3.RenderRect(p.renderer, &character_card)
            sdl3.RenderTexture(p.renderer, text_texture, nil, &text_rect)

            if sdl3.PointInRectFloat(cast(sdl3.FPoint) platform.mouse_position(p.mouse), character_card) {
                if platform.button_pressed(p.mouse, .Left) {
                    g.selected_character = id
                }
            }

            // TODO: Move to the next row if we hit the end
            character_card.x += character_card.w + g.ui.ctx.spacing
        }

        sdl3.SetRenderClipRect(p.renderer, nil)
    }

    {
        ui.push_layout_scope(g.ui.ctx, ui.column_layout(weapon_window.x, weapon_window.y))

        sdl3.SetRenderDrawColor(p.renderer, 0, 0, 255, 255)
        sdl3.RenderRect(p.renderer, &weapon_window)

        ui.label(g.ui.ctx, g.ui.select_weapon)
    }

    {
        ui.push_layout_scope(g.ui.ctx, ui.column_layout(weapon_window.x, weapon_window.y + weapon_window.h + g.ui.ctx.spacing))

        if ui.button(g.ui.ctx, g.ui.continue_journey) {
            g.player = {
                rank = .White,

                grimoire = {
                    exp  = 0,
                    next = 1,
                },

                stats = &wizard.CHARACTERS[g.selected_character]
            }

            entity := entity.player(&g.entities)
            wizard.delete_spell_arena(entity.arena)

            entity^ = {
                health  = wizard.get_max_health(g.player),
                arena   = wizard.make_spell_arena(
                    g.world_id,
                    wizard.get_arena_layout_for_wizard(g.player),
                    g.player.stats.elements,
                    g.arena_offsets[.Player],
                ),
            }

            g.state         = .Adventure_Select
            g.entities.turn = .Player
        }
    }
}

do_adventure_select :: proc(p: ^platform.Platform, g: ^Game) {
    g.adventure.stage  = 0
    g.adventure.stages = adventure.DRAGON_ADVENTURE

    adventure.init(g.ui.ctx, &g.adventure)

    stage  := adventure.stage(&g.adventure)
    entity := entity.enemy(&g.entities)

    wizard.delete_spell_arena(entity.arena)

    entity^ = {
        health = stage.enemy_health,
        arena  = wizard.make_spell_arena(
            g.world_id,
            stage.arena_layout,
            stage.elements,
            g.arena_offsets[.Enemy],
        ),
    }

    g.state = .Battle
}

do_battle :: proc(p: ^platform.Platform, g: ^Game) {
    // ============
    // !!! Ball !!!
    //

    switch g.ball_state {
        case .Picking_A_Spot:
            ball_info := BALL_INFO[g.ball_type]

            // TODO: Adjust for the second turn
            min_x := g.arena_width * (f32(g.entities.turn) + 0) + (g.half_wall_thickness * 2)
            max_x := g.arena_width * (f32(g.entities.turn) + 1) - (g.half_wall_thickness + ball_info.size_in_pixels)

            g.ball_position = {
                clamp(platform.mouse_position(p.mouse).x - ball_info.size_in_pixels / 2, min_x, max_x),
                g.scene_height + ball_info.size_in_pixels * 2,
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

                valid_colours := entity.current(&g.entities).arena.colours

                spawn_particle(g.particle_system, rand.choice(g.particle_textures[:]), rand.choice(valid_colours), g.ball_position + back  * rand.float32(), back  * 2)
                spawn_particle(g.particle_system, rand.choice(g.particle_textures[:]), rand.choice(valid_colours), g.ball_position + side1 * rand.float32(), side1 * 2)
                spawn_particle(g.particle_system, rand.choice(g.particle_textures[:]), rand.choice(valid_colours), g.ball_position + side2 * rand.float32(), side2 * 2)
            }

            if physics.metres_to_pixels(g.ball_position.y) - ball_info.size_in_pixels /* / 2 */ > f32(p.height) {
                g.ball_state        = .Picking_A_Spot
                g.ball_escape_speed = 1.0

                box2d.DestroyBody(g.ball.body_id)
                current := entity.current(&g.entities)
                  other := entity.other  (&g.entities)

                if current.arena.disabled == len(current.arena.blocks) {
                    elements: wizard.Elements

                    switch g.entities.turn {
                        case .Player: elements = wizard.get_elements(g.player)
                        case .Enemy:  elements = adventure.stage(&g.adventure).elements
                    }

                    wizard.restore_spell_arena(&current.arena, elements)
                }

                // Don't apply damage if it killed itself
                if entity.enemy(&g.entities).health == 0 {
                    g.state = .Camp_Fire
                } else {
                    other.health   = max(other.health - current.damage, 0)
                    current.damage = 0

                    if entity.enemy(&g.entities).health == 0 {
                        g.state = .Camp_Fire
                    }
                }

                entity.advance_turn(&g.entities)

                // if g.turn == .Player {
                //     g.ball_type = g.ball_type == .Basic ? .Blue : .Basic
                // }
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

    for entity in g.entities.entities {
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
        // TODO: Would be good to get the length from the label itself.
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

    player := &g.entities.entities[.Player]
    others := &g.entities.entities[.Enemy]

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

player_do_battle :: proc(p: ^platform.Platform, g: ^Game) {

}

enemy_do_battle :: proc(p: ^platform.Platform, g: ^Game) {
}

do_camp_fire :: proc(p: ^platform.Platform, g: ^Game) {
    should_camp := true

    if !g.have_setup_camp {
        if adventure.is_complete(&g.adventure) {
            g.state     = .Post_Game
            should_camp = false
        } else {
            g.has_rested       = false
            g.has_investigated = false
            g.has_studied      = false
            g.have_setup_camp  = true
            g.action_points   += g.player.stats.action_points_per_camp
        }
    }

    if should_camp {
        {
            // Adventure Progress UI
            // =====================

            PADDING :: f32(5)

            NORMAL_SCALE :: f32(1.2)
              BOSS_SCALE :: f32(1.8)

            x          := f32(0)
            mid_height := g.scene_height / 2

            line_length := f32(100)


            for stage, i in g.adventure.stages {
                is_selected := g.adventure.stage == i

                sdl3.SetRenderDrawColor(p.renderer, 60, 60, 60, 255)
                sdl3.RenderLine(p.renderer, x + PADDING, mid_height, x + line_length - PADDING, mid_height)

                x     += line_length
                scale := stage.is_boss ? BOSS_SCALE : NORMAL_SCALE
                size  := wizard.SPELL_BLOCK_SIZE_IN_PIXELS * scale

                rect := sdl3.FRect {
                    x = x,
                    y = mid_height - size / 2,
                    w = size,
                    h = size,
                }

                sdl3.RenderTexture(p.renderer, g.block_textures[.Basic][.Diamond], nil, &rect)

                label_x := rect.x + (rect.w / 2) - (stage.label.w / 2)
                label_y: f32

                if (i & 1) == 0 { label_y = rect.y + rect.h + PADDING * 2 }
                else            { label_y = rect.y - rect.h + PADDING * 2 - stage.label.h }

                ui.label_at(g.ui.ctx, stage.label, label_x, label_y)

                if is_selected {
                    select_rect := sdl3.FRect {
                        x = x - PADDING,
                        y = mid_height - (size / 2) - PADDING,
                        w = size + PADDING * 2,
                        h = size + PADDING * 2,
                    }

                    sdl3.RenderTexture(p.renderer, g.select_texture, nil, &select_rect)
                }

                x += size
            }
        }

        {
            // TODO: Would be good to get the length from the label itself.
            ACTION_POINTS_OFFSET :: len("Action Points: ")
            HEALTH_OFFSET        :: len("Health: ")
            RANK_OFFSET          :: len("Rank: ")
            PROGRESS_OFFSET      :: len("Progress: ")
            COST_OFFSET          :: len("Cost: ")

            investigation_cost := adventure.investigation_cost(&g.adventure)
            study_exp          := g.player.grimoire.exp
            study_cost         := g.player.grimoire.next
            player_entity      := entity.player(&g.entities)
            max_health         := wizard.get_max_health(g.player)

            now_health_string         := ui.int_to_string(player_entity.health)
            max_health_string         := ui.int_to_string(max_health)
            investigation_cost_string := ui.int_to_string(investigation_cost)
            study_exp_string          := ui.int_to_string(study_exp)
            study_cost_string         := ui.int_to_string(study_cost)
            action_points_string      := ui.int_to_string(g.action_points)
            current_rank_string       := wizard.rank_to_string(g.player.rank)
            health_string             := strings.concatenate({ now_health_string, "/", max_health_string }, context.temp_allocator)
            study_progress_string     := strings.concatenate({ study_exp_string,  "/", study_cost_string }, context.temp_allocator)

            ui.insert_text(g.ui.ctx, &g.ui.player_health,       HEALTH_OFFSET,        health_string)
            ui.insert_text(g.ui.ctx, &g.ui.action_points,       ACTION_POINTS_OFFSET, action_points_string)
            ui.insert_text(g.ui.ctx, &g.ui.current_rank,        RANK_OFFSET,          current_rank_string)
            ui.insert_text(g.ui.ctx, &g.ui.study_exp,           PROGRESS_OFFSET,      study_progress_string)
            ui.insert_text(g.ui.ctx, &g.ui.study_cost,          COST_OFFSET,          study_cost_string)
            ui.insert_text(g.ui.ctx, &g.ui.investigation_cost,  COST_OFFSET,          investigation_cost_string)

            ui.push_layout_scope(g.ui.ctx, ui.column_layout(10, g.scene_height + 10))
            ui.push_spacing_scope(g.ui.ctx, 5)
            ui.push_text_padding_scope(g.ui.ctx, 5)

            ui.label(g.ui.ctx, g.ui.action_points)

            if ui.button(g.ui.ctx, g.ui.continue_journey) {
                wizard.restore_spell_arena(
                    &player_entity.arena,
                    wizard.get_elements(g.player),
                )

                adventure.advance_to_next_stage(&g.adventure)

                wizard.delete_spell_arena(entity.enemy(&g.entities).arena)

                stage := adventure.stage(&g.adventure)

                entity.enemy(&g.entities)^ = {
                    health = stage.enemy_health,
                    arena  = wizard.make_spell_arena(
                        g.world_id,
                        stage.arena_layout,
                        stage.elements,
                        g.arena_offsets[.Enemy],
                    ),
                }

                g.state                 = .Battle
                g.entities.turn         = .Player
                g.have_setup_camp       = false
                g.particle_system.count = 0
            }

            {
                ui.push_layout_scope(g.ui.ctx, ui.row_layout(0, 0, .Left))

                if ui.button(g.ui.ctx, g.ui.rest, g.has_rested) {
                    g.has_rested = true

                    restored_health := int(f32(max_health) * 0.2)
                    new_health      := player_entity.health + restored_health

                    player_entity.health = min(new_health, max_health)
                }

                ui.label(g.ui.ctx, g.ui.player_health)
            }

            {
                ui.push_layout_scope(g.ui.ctx, ui.row_layout(0, 0, .Left))

                if ui.button(
                    g.ui.ctx,
                    g.ui.investigate,
                    g.has_investigated || g.action_points < investigation_cost,
                ) {
                    g.action_points   -= investigation_cost
                    g.has_investigated = true

                    // TODO: Investigate, or whatever
                }

                ui.label(g.ui.ctx, g.ui.investigation_cost)
            }

            {
                ui.push_layout_scope(g.ui.ctx, ui.row_layout(0, 0, .Left))

                if ui.button(
                    g.ui.ctx,
                    g.ui.study,
                    g.has_studied || g.action_points < study_cost,
                ) {
                    g.action_points       -= study_cost
                    g.has_studied          = true
                    g.player.grimoire.exp += 1

                    if g.player.grimoire.exp == g.player.grimoire.next {
                        g.player.grimoire.next += 1
                        g.player.grimoire.exp   = 0

                        g.player.rank = cast(wizard.Rank) min(cast(int) g.player.rank + 1, cast(int) wizard.Rank.Red)

                        // TODO: Upgrade the player's arena
                        // entity.player(&g.entities)

                        health_difference   := max_health - player_entity.health
                        player_entity.health = wizard.get_max_health(g.player) - health_difference
                    }
                }

                ui.label(g.ui.ctx, g.ui.study_exp)
                ui.label(g.ui.ctx, g.ui.study_cost)
                ui.label(g.ui.ctx, g.ui.current_rank)
            }

            ui.delete_text(g.ui.ctx, &g.ui.player_health,      HEALTH_OFFSET,        len(health_string))
            ui.delete_text(g.ui.ctx, &g.ui.action_points,      ACTION_POINTS_OFFSET, len(action_points_string))
            ui.delete_text(g.ui.ctx, &g.ui.current_rank,       RANK_OFFSET,          len(current_rank_string))
            ui.delete_text(g.ui.ctx, &g.ui.study_exp,          PROGRESS_OFFSET,      len(study_progress_string))
            ui.delete_text(g.ui.ctx, &g.ui.study_cost,         COST_OFFSET,          len(study_cost_string))
            ui.delete_text(g.ui.ctx, &g.ui.investigation_cost, COST_OFFSET,          len(investigation_cost_string))
        }
    }
}

do_post_game :: proc(p: ^platform.Platform, g: ^Game) {
    fmt.println("You Win!")

    g.state = .Title
}

hit_block :: proc(g: ^Game, block: ^wizard.Spell_Block) {
    __hit_block :: proc(g: ^Game, block: ^wizard.Spell_Block) {
        ball_info := BALL_INFO[g.ball.type]

        current := entity.current(&g.entities)
          other := entity.other  (&g.entities)

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

        damage_mult: int

        switch g.entities.turn {
            case .Player: damage_mult = int(g.player.rank)
            case .Enemy:  damage_mult = 1
        }

        current.damage += ball_info.basic_damage * damage_mult

        if block.health == 0 {
            box2d.Body_Disable(block.body_id)
            current.arena.disabled += 1
        }

        play_sound(hit_sound)
    }

    current := entity.current(&g.entities)

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
        friction        = 0.0,
        restitution     = 1.0,
    },

    .Blue = {
           basic_damage = 1,
        critical_damage = 8,
        size_in_pixels  = 32,
        friction        = 0.0,
        restitution     = 1.0,
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