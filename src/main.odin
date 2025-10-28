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
import "game:relic"

main :: proc() {
    game      := new(Game)
    game_name := name.get_name(); defer delete(game_name)

    platform.run_app(
        game_name,
        game,
        init,
        quit,
        handle_event,
        update_and_render,
    )
}

// ----------------------------------------------
// Game
// ----------------------------------------------

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

    // Assets
    sounds: struct {
        hit_wall:      platform.Audio,
        hit_basic:     platform.Audio,
        hit_frozen:    platform.Audio,
        hit_refresher: platform.Audio,
        hit_activator: platform.Audio,
        hit_freezer:   platform.Audio,
        hit_poisoner:  platform.Audio,
    },

    ball_textures: [Ball_Type]^sdl3.Texture,

    block_textures: [wizard.Block_Element][wizard.Block_Shape]^sdl3.Texture,

    burning_textures:       [4]^sdl3.Texture,
    burning_texture_index:  int,
    burning_animation_time: f32,

    particle_textures:   [9]^sdl3.Texture,
    particle_spawn_time: f32,
    particle_system:     ^physics.Particle_System,

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
    relics:          relic.Relics,

    // Ball stuff ( ͡° ͜ʖ ͡°)
    ball_count:      int,
    ball_state:      Ball_State,
    ball_position:   glsl.vec2,

    balls: [256]Ball, // I _am_ the suffix

       run_stats: Battle_Stats,
    battle_stats: Battle_Stats,

    // Character Select ( ͡ʘ ͜ʖ ͡ʘ)
    selected_character: wizard.Character,

    // Camp Fire
    have_setup_camp:  bool,
    has_rested:       bool,
    has_investigated: bool,
    has_studied:      bool,
    action_points:    int,
}

Battle_Stats :: struct {
    damage:            [entity.Turn]Damage_Stats,
    poison:            [entity.Turn]Damage_Stats,
    health_gained:     [entity.Turn]int,
    blocks_hit:        [entity.Turn][wizard.Block_Element]int,
    relic_proc_counts: [relic.Relic]int,
}

Damage_Stats :: struct {
    damage_done:              int,
    highest_damage:           int,

    potential_damage_done:    int,
    potential_highest_damage: int,
}

merge_and_clear_stats :: proc(a, b: ^Battle_Stats) {
    for &stats, turn in a.damage {
        stats.damage_done              += b.damage[turn].damage_done
        stats.highest_damage           += b.damage[turn].highest_damage
        stats.potential_damage_done    += b.damage[turn].potential_damage_done
        stats.potential_highest_damage += b.damage[turn].potential_highest_damage
    }

    for &stats, turn in a.poison {
        stats.damage_done              += b.poison[turn].damage_done
        stats.highest_damage           += b.poison[turn].highest_damage
        stats.potential_damage_done    += b.poison[turn].potential_damage_done
        stats.potential_highest_damage += b.poison[turn].potential_highest_damage
    }

    for &count, turn in a.health_gained {
        count += b.health_gained[turn]
    }

    for &blocks, turn in a.blocks_hit {
        for &count, element in blocks {
            count += b.blocks_hit[turn][element]
        }
    }

    for &count, relic in a.relic_proc_counts {
        count += b.relic_proc_counts[relic]
    }

    b^ = {}
}

init :: proc(p: ^platform.Platform, g: ^Game) {
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
        hit_wall      = platform.load_wav("assets/audio/hit_wall.wav",            p.audio_device, &p.output_format),
        hit_basic     = platform.load_wav("assets/audio/hit_basic_block.wav",     p.audio_device, &p.output_format),
        hit_frozen    = platform.load_wav("assets/audio/hit_critical_block.wav",  p.audio_device, &p.output_format),
        hit_refresher = platform.load_wav("assets/audio/hit_refresher_block.wav", p.audio_device, &p.output_format),
        hit_activator = platform.load_wav("assets/audio/hit_activator_block.wav", p.audio_device, &p.output_format),
        hit_freezer   = platform.load_wav("assets/audio/hit_freezer_block.wav",   p.audio_device, &p.output_format),
        hit_poisoner  = platform.load_wav("assets/audio/hit_poisoner_block.wav",  p.audio_device, &p.output_format),
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

    g.ball_state    = .Picking_A_Spot
    g.ball_textures = {
        .Basic = image.LoadTexture(p.renderer, "assets/graphics/particles/circle_03.png"),
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

    for &ball in g.balls {
        // brøther

        ball_info := BALL_INFO[.Basic]
        body_def  := box2d.DefaultBodyDef()
        body_def.type           = .dynamicBody
        body_def.isBullet       = true
        body_def.fixedRotation  = false // Not sure about this?
        body_def.isEnabled      = false

        circle := box2d.Circle {
            center = {},
            radius = physics.pixels_to_metres(ball_info.size_in_pixels * 0.5)
        }

        shape_def := box2d.DefaultShapeDef()
        shape_def.material.friction    = ball_info.friction
        shape_def.material.restitution = ball_info.restitution
        shape_def.enableHitEvents      = true

        ball.body_id  = box2d.CreateBody(g.world_id, body_def)
        ball.shape_id = box2d.CreateCircleShape(ball.body_id, shape_def, circle)
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

    g.particle_system = physics.make_particle_system(g.world_id)
    g.status_texture = image.LoadTexture(p.renderer, "assets/graphics/particles/circle_02.png")
    g.select_texture = image.LoadTexture(p.renderer, "assets/graphics/selectorA.png")
}

quit :: proc(p: ^platform.Platform, g: ^Game) {
    physics.delete_particle_system(g.particle_system)

    if g.ui.ctx != nil {
        if g.ui.ctx.font != nil { ttf.CloseFont(g.ui.ctx.font) }

        free(g.ui.ctx)
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
                            .Ice      = 0,
                            .Healing  = 3,
                            .Poison   = 0,
                            .Fire     = 0,
                            .Electric = 0,
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
            //       Which means removing the allocations, because we
            //       all know gays love to allocate in the middle of
            //       their loops.
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

            g.relics = {}

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

            g.relics.active = {}
            relic.add(&g.relics, .Protective_Aura)
            relic.add(&g.relics, .Weaken_Blocks)
            relic.add(&g.relics, .Harden_Blocks)

            for &block in entity.arena.blocks {
                proc_relics_by_type(p, g, .On_Player_Block_Restored, { block = &block })
            }

            g.state = .Adventure_Select
        }
    }
}

begin_next_stage :: proc(p: ^platform.Platform, g: ^Game) {
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

    for &block in entity.arena.blocks {
        proc_relics_by_type(p, g, .On_Enemy_Block_Restored, { block = &block })
    }

    fmt.printfln("%#v", g.battle_stats)
    merge_and_clear_stats(&g.run_stats, &g.battle_stats)

    g.state         = .Battle
    g.entities.turn = .Player
}

do_adventure_select :: proc(p: ^platform.Platform, g: ^Game) {
    g.adventure.stage  = 0
    g.adventure.stages = adventure.DRAGON_ADVENTURE

    adventure.init(g.ui.ctx, &g.adventure)
    begin_next_stage(p, g)
}

do_battle :: proc(p: ^platform.Platform, g: ^Game) {
    // ============
    // !!! Ball !!!
    //

    switch g.ball_state {
        case .Picking_A_Spot:
            ball_info := BALL_INFO[.Basic]

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

            sdl3.RenderTexture(p.renderer, g.ball_textures[.Basic], nil, &rect)

            if platform.button_pressed(p.mouse, .Left) {
                g.ball_state = .Aiming
            }

        case .Aiming:
            ball_info := BALL_INFO[.Basic]
            rect      := sdl3.FRect {
                x = g.ball_position.x,
                y = g.ball_position.y,
                w = ball_info.size_in_pixels,
                h = ball_info.size_in_pixels,
            }

            sdl3.RenderTexture(p.renderer, g.ball_textures[.Basic], nil, &rect)

            if platform.button_released(p.mouse, .Left) {
                character := g.player.stats.character
                stage     := adventure.stage(&g.adventure)

                switch g.entities.turn {
                    case .Player: PLAYER_HOOKS[character    ].on_shoot_ball(p, g)
                    case .Enemy:   ENEMY_HOOKS[stage.monster].on_shoot_ball(p, g)
                }

                g.ball_state = .Flying_About_The_Place
            }

        case .Flying_About_The_Place:
            // Lu oh oop
            #reverse for &ball, i in g.balls[:g.ball_count] {
                ball_info := BALL_INFO[ball.type]

                physics.render_textured_object(
                    p.renderer,
                    g.ball_textures[ball.type],
                    ball.body_id,
                    ball.shape_id,
                )

                ball_position := box2d.Body_GetPosition      (ball.body_id)
                ball_velocity  := box2d.Body_GetLinearVelocity(ball.body_id)
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

                    physics.spawn_particle(g.particle_system, rand.choice(g.particle_textures[:]), rand.choice(valid_colours), ball_position + back  * rand.float32(), back  * 2)
                    physics.spawn_particle(g.particle_system, rand.choice(g.particle_textures[:]), rand.choice(valid_colours), ball_position + side1 * rand.float32(), side1 * 2)
                    physics.spawn_particle(g.particle_system, rand.choice(g.particle_textures[:]), rand.choice(valid_colours), ball_position + side2 * rand.float32(), side2 * 2)
                }

                // If the ball has fallen off the bottom of the arena then turn is over.
                if physics.metres_to_pixels(ball_position.y) - ball_info.size_in_pixels /* / 2 */ > f32(p.height) {
                    // TODO: Bool Pool
                    box2d.Body_Disable(ball.body_id)

                    // MFW Testicular Torsion
                    slice.swap(g.balls[:], g.ball_count, i)

                    g.ball_count -= 1
                }

                if g.ball_count == 0 {
                    // TODO: when all the balls have dropped, hee speaks like _this_: give me the l oh oops.
                    g.ball_state = .Picking_A_Spot

                    current   := entity.current(&g.entities)
                    other     := entity.other  (&g.entities)
                    enemy     := entity.enemy  (&g.entities)
                    character := g.player.stats.character
                    stage     := adventure.stage(&g.adventure)

                    if current.arena.disabled == len(current.arena.blocks) {
                        elements:  wizard.Elements
                        proc_type: relic.Proc_Type

                        switch g.entities.turn {
                            case .Player:
                                elements  = wizard.get_elements(g.player)
                                proc_type = .On_Player_Block_Restored

                            case .Enemy:
                                elements  = adventure.stage(&g.adventure).elements
                                proc_type = .On_Enemy_Block_Restored
                        }

                        wizard.restore_spell_arena(&current.arena, elements)

                        for &block in current.arena.blocks {
                            proc_relics_by_type(p, g, proc_type, { block = &block })
                        }
                    }

                    __compute_damage :: proc(
                        p:        ^platform.Platform,
                        g:        ^Game,
                        score:    ^int,
                        stats:    ^Damage_Stats,
                        proc_type: relic.Proc_Type,
                        hook:      proc(p: ^platform.Platform, g: ^Game, score: ^int),
                    ) {
                        stats.potential_damage_done   += score^
                        stats.potential_highest_damage = max(stats.potential_highest_damage, score^)

                        proc_relics_by_type(p, g, proc_type, { damage = score })
                        hook               (p, g, score)

                        stats.damage_done   += score^
                        stats.highest_damage = max(stats.highest_damage, score^)
                    }

                    // We should only apply the damage if the enemy is still alive
                    // This may seem pointless, but the enemy can kill itself. This
                    // saves the player from being hurt by dead enemies.
                    if enemy.health != 0 {
                        switch g.entities.turn {
                            case .Player: // We're hitting the enemey
                                __compute_damage(
                                    p, g,
                                    &current.damage,
                                    &g.battle_stats.damage[.Player],
                                    .On_Enemy_Hit,
                                    ENEMY_HOOKS[stage.monster].on_take_damage,
                                )

                            case .Enemy: // We're being hit by the enemy
                                __compute_damage(
                                    p, g,
                                    &current.damage,
                                    &g.battle_stats.damage[.Enemy],
                                    .On_Player_Hit,
                                    PLAYER_HOOKS[character].on_take_damage,
                                )
                        }

                        other.health   = max(other.health - current.damage, 0)
                        current.damage = 0
                    }

                    if enemy.health == 0 {
                        g.state = .Camp_Fire
                    }

                    // Apply poison damage if the enemey is not dead
                    if enemy.health != 0 {
                        poison_damage := int(bool(current.poison)) * 10 // Maybe relic for multiply?

                        switch g.entities.turn {
                            case .Player: // We're being poisoned
                                __compute_damage(
                                    p, g,
                                    &poison_damage,
                                    &g.battle_stats.poison[.Enemy],
                                    .On_Player_Poisoned,
                                    PLAYER_HOOKS[character].on_take_poison,
                                )

                            case .Enemy: // We're being hit by the enemy
                                __compute_damage(
                                    p, g,
                                    &poison_damage,
                                    &g.battle_stats.poison[.Player],
                                    .On_Enemy_Poisoned,
                                    ENEMY_HOOKS[stage.monster].on_take_poison,
                                )
                        }

                        current.health = max(current.health - poison_damage, 0)
                        current.poison = max(current.poison - 1,             0)
                    }

                    if enemy.health == 0 {
                        g.state = .Camp_Fire
                    }

                    switch g.entities.turn {
                        case .Player: PLAYER_HOOKS[character    ].on_turn_end(p, g)
                        case .Enemy:   ENEMY_HOOKS[stage.monster].on_turn_end(p, g)
                    }

                    entity.advance_turn(&g.entities)

                    switch g.entities.turn {
                        case .Player: PLAYER_HOOKS[character    ].on_turn_start(p, g)
                        case .Enemy:   ENEMY_HOOKS[stage.monster].on_turn_start(p, g)
                    }
                }

                // If the ball's physics body has gone to sleep then it has got stuck
                // somewhere. We try to give it a little nudge, and increase the power
                // incase it didn't make it out.
                if !box2d.Body_IsAwake(ball.body_id) {
                    box2d.Body_SetLinearVelocity(ball.body_id, ball.escape_vector * ball.escape_speed)
                    box2d.Body_SetAwake         (ball.body_id, true)

                    ball.escape_speed    *=  1.2
                    ball.escape_vector.x *= -1.0
                }
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

                physics.render_textured_object(p.renderer, texture, block.body_id, block.shape_id)

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

                        case .Frozen:      element = .Ice
                        case .Healing:     element = .Healing
                        case .Poisoned:    element = .Poison
                        case .Burning:     element = .Fire
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

    physics.update_and_render_particles(p.renderer, g.particle_system, p.delta_seconds)

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
            platform.play_sound(g.sounds.hit_wall)
        } else {
            block := cast(^wizard.Spell_Block) user_data
            hit_block(p, g, &block)
        }
    }
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

                for &block in player_entity.arena.blocks {
                    proc_relics_by_type(p, g, .On_Player_Block_Restored, { block = &block })
                }

                g.have_setup_camp       = false
                g.particle_system.count = 0

                adventure.advance_to_next_stage(&g.adventure)
                begin_next_stage(p, g)
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

hit_block :: proc(p: ^platform.Platform, g: ^Game, block: ^^wizard.Spell_Block) {
    __hit_block :: proc(p: ^platform.Platform, g: ^Game, block: ^^wizard.Spell_Block) {
        // TODO: "It'll be extremely obvious, when we have a different ball and it doesnt do anything"
        // - Hector
        ball_info := BALL_INFO[.Basic]

        current := entity.current(&g.entities)
          other := entity.other  (&g.entities)

        restore_healing := false

        switch block^.element {
            case .Basic:
                platform.play_sound(g.sounds.hit_basic)

            case .Fire:
                wizard.enstatus_n_spell_blocks(&other.arena, .Burning, 4)
                // platform.play_sound(g.sounds.hit_burner)

            case .Healing:
                // We need to defer the restoration until after the block has been
                // destroyed, otherwise we may not restore a healing block.
                restore_healing = true
                // platform.play_sound(g.sounds.hit_healer)

            case .Electric:
                // wizard.enstatus_n_spell_blocks(&other.arena, .Electrified, 4)

                // TODO: Ray cast in four directions to find blocks to
                //       charge.
                //       Charged blocks get the status applied to them
                //       Timer, charged blocks propagate in one direction
                //       One time, charged blocks break and trigger.

                // platform.play_sound(g.sounds.hit_electrifier)

            case .Ice:
                wizard.enstatus_n_spell_blocks(&other.arena, .Frozen, 4)
                platform.play_sound(g.sounds.hit_freezer)

            case .Poison:
                wizard.enstatus_n_spell_blocks(&other.arena, .Poisoned, 4)
                platform.play_sound(g.sounds.hit_poisoner)
        }

        current.arena.block_counts                [block^.element] -= 1
        g.battle_stats.blocks_hit[g.entities.turn][block^.element] += 1

        block^.health -= 1
        block^.element = .Basic // Magic blocks only last a single hit

        if block^.health == 0 {
            wizard.disable_block(&current.arena, block)
        }

        // We want to restore after the current block is removed
        // Otherwise it's possible to soft lock yourself our of healing
        // blocks
        if restore_healing {
            enabled_blocks := wizard.enable_n_spell_blocks(&current.arena, 4)

            if len(enabled_blocks) == 0 {
                // No blocks were destroyed, but we still want to have our healing block back.
                wizard.move_healing_block(&current.arena, block^)
            }

            if len(enabled_blocks) == 1 {
                // Since only one block was destroyed, it will be restored as a healing block.
                // This is nice, but it is easily exploited. We shouuld remove the element, and
                // find a new place for it.
                block^.element = .Basic
                wizard.move_healing_block(&current.arena, block^)
            }

            for &block in enabled_blocks {
                switch g.entities.turn {
                    case .Player: proc_relics_by_type(p, g, .On_Player_Block_Restored, { block = block })
                    case .Enemy:  proc_relics_by_type(p, g, .On_Enemy_Block_Restored,  { block = block })
                }
            }

            wizard.enstatus_n_spell_blocks(&current.arena, .Healing, 4)
        }

        damage_mult: int

        switch g.entities.turn {
            case .Player: damage_mult = int(g.player.rank)
            case .Enemy:  damage_mult = 1
        }

        current.damage += ball_info.damage * damage_mult
    }

    current := entity.current(&g.entities)

    character := g.player.stats.character
    stage     := adventure.stage(&g.adventure)

    switch g.entities.turn {
        case .Player: PLAYER_HOOKS[character    ].on_block_hit(p, g, block^)
        case .Enemy:   ENEMY_HOOKS[stage.monster].on_block_hit(p, g, block^)
    }

    proc_relics_by_type(p, g, .On_Block_Hit, { block = block^ })

    switch block^.status {
        case .None:
            __hit_block(p, g, block)

        case .Frozen:
            platform.play_sound(g.sounds.hit_frozen)

        case .Healing:
            __hit_block(p, g, block)

            max_health: int

            switch g.entities.turn {
                case .Player: max_health = wizard.get_max_health(g.player)
                case .Enemy:  max_health = stage.enemy_health
            }

            new_health    := min(current.health + 5, max_health)
            delta_health  := new_health - current.health
            current.health = new_health

            g.battle_stats.health_gained[g.entities.turn] += delta_health

        case .Poisoned:
            current.poison += 1

            __hit_block(p, g, block)

        case .Burning:
            // TODO: platform.play_sound(hit_burning_sound)
            current.health -= 1

            __hit_block(p, g, block)

        case .Charged:
            __hit_block(p, g, block)

        case .Electrified:
            __hit_block(p, g, block)
    }

    wizard.distatus_block(&current.arena, block)
}

// ----------------------------------------------
// Balls
// ----------------------------------------------

Ball_State :: enum {
    Picking_A_Spot,
    Aiming,
    Flying_About_The_Place,
}

Ball_Type :: enum {
    Basic,
    // Vertical_Laser,
    // Horizontal_Laser,
}

Ball_Info :: struct {
    name:   string,
    damage: int,

    on_block_hit: proc(p: ^platform.Platform, g: ^Game, b: ^wizard.Spell_Block),

    size_in_pixels: f32,
    friction:       f32,
    restitution:    f32,
    // Other interesting properties
}

BALL_INFO := [Ball_Type]Ball_Info {
    .Basic = {
        name   = "Magic Missile",
        damage = 3,

        on_block_hit = _nil_on_block_hit,

        size_in_pixels  = 16,
        friction        = 0.0,
        restitution     = 1.0,
    },
}

Ball :: struct {
    escape_vector: glsl.vec2,
    escape_speed:  f32,
    type:          Ball_Type,
    body_id:       box2d.BodyId,
    shape_id:      box2d.ShapeId,
}

create_ball :: proc(g: ^Game, position, velocity: glsl.vec2) {
    ball := &g.balls[g.ball_count]

    position := physics.pixels_to_metres(position)
    velocity := physics.pixels_to_metres(velocity)

    box2d.Body_SetTransform     (ball.body_id, position, box2d.Body_GetRotation(ball.body_id))
    box2d.Body_SetLinearVelocity(ball.body_id, velocity)
    box2d.Body_Enable           (ball.body_id)

    ball.escape_vector = { 1, -1 }
    ball.escape_speed  = f32(1.0)

    g.ball_count += 1
}
