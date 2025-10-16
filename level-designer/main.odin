package ld_main

import "base:runtime"

import "core:fmt"
import "core:math/linalg/glsl"
import "core:slice"
import "core:encoding/json"
import "core:mem"

import "vendor:sdl3"
import "vendor:sdl3/image"
import "vendor:sdl3/ttf"

import "game:platform"
import "game:wizard"
import "game:graphics"
import "game:graphics/ui"

main :: proc() {
    ld: Level_Designer

    platform.run_app(
        "Level Designer",
        &ld,
        init,
        quit,
        handle_event,
        update_and_render,
    )
}

// ----------------------------------------------
// Level Designer
// ----------------------------------------------

MAX_BLOCKS :: 256

Level_Designer :: struct {
    block_textures: [wizard.Block_Shape]^sdl3.Texture,

    ui: struct {
        ctx: ^ui.Context,

        // File Tool Bar
         new_level: ui.Button,
        save_level: ui.Button,
        load_level: ui.Button,

        // Block Spawners
        spawn_diamond:   ui.Button,
        spawn_pentagon:  ui.Button,
        spawn_square:    ui.Button,
        spawn_rectangle: ui.Button,

        // Selected Controls
        increment_size: ui.Button,
        decrement_size: ui.Button,
        scale_label:    ui.Label,
        delete:         ui.Button,
    },

    arena_rect: sdl3.FRect,
    arena_min:  glsl.vec2,
    arena_max:  glsl.vec2,

    level:    wizard.Arena_Layout,
    used:     int,
    selected: int,
    spawned:  bool,
    select_d: glsl.vec2,
}

init :: proc(p: ^platform.Platform, g: ^Level_Designer) {
    g.block_textures = {
        .Diamond   = image.LoadTexture(p.renderer, "assets/graphics/element_grey_diamond.png"),
        .Pentagon  = image.LoadTexture(p.renderer, "assets/graphics/element_grey_polygon.png"),
        .Square    = image.LoadTexture(p.renderer, "assets/graphics/element_grey_square.png"),
        .Rectangle = image.LoadTexture(p.renderer, "assets/graphics/element_grey_rectangle.png"),
    }

    g.ui.ctx             = new(ui.Context)
    g.ui.ctx.renderer    = p.renderer
    g.ui.ctx.text_engine = p.text_engine
    g.ui.ctx.font        = ttf.OpenFont("assets/fonts/Kenney Rocket.ttf", 12)
    g.ui.ctx.mouse       = &p.mouse

    g.ui.ctx.spacing      = 5.0
    g.ui.ctx.text_padding = 5.0

    if g.ui.ctx.font == nil {
        fmt.println("Unable to open font")
        fmt.println(sdl3.GetError())
    }

    g.level.blocks = make([]wizard.Layout_Block, MAX_BLOCKS)
    g.selected     = -1

    arena_width  := f32(p.width)  * wizard.ARENA_WIDTH_FRACTION
    arena_height := f32(p.height) * wizard.ARENA_HEIGHT_FRACTION

    g.arena_rect = sdl3.FRect {
        x = (f32(p.width)  - arena_width) / 2,
        y = (f32(p.height) - arena_height),
        w = arena_width,
        h = arena_height,
    }

    g.arena_min = glsl.vec2 { g.arena_rect.x,                  g.arena_rect.y                  }
    g.arena_max = glsl.vec2 { g.arena_rect.x + g.arena_rect.w, g.arena_rect.y + g.arena_rect.h }

    g.ui. new_level = ui.create_button(g.ui.ctx, "New",  graphics.rgb(60, 200, 60))
    g.ui.save_level = ui.create_button(g.ui.ctx, "Save", graphics.rgb(60, 60, 200))
    g.ui.load_level = ui.create_button(g.ui.ctx, "Load", graphics.rgb(60, 60, 200))

    g.ui.spawn_diamond   = ui.create_button(g.ui.ctx, "Diamond (D)",   graphics.rgb(200, 200, 200))
    g.ui.spawn_pentagon  = ui.create_button(g.ui.ctx, "Pentagon (P)",  graphics.rgb(200, 200, 200))
    g.ui.spawn_square    = ui.create_button(g.ui.ctx, "Square (S)",    graphics.rgb(200, 200, 200))
    g.ui.spawn_rectangle = ui.create_button(g.ui.ctx, "Rectangle (R)", graphics.rgb(200, 200, 200))

    g.ui.increment_size = ui.create_button(g.ui.ctx, "+",      graphics.rgb(60, 60, 200))
    g.ui.decrement_size = ui.create_button(g.ui.ctx, "-",      graphics.rgb(60, 60, 200))
    g.ui.scale_label    = ui.create_label (g.ui.ctx, "Scale:", graphics.rgb(200, 200, 200))
    g.ui.delete         = ui.create_button(g.ui.ctx, "Delete", graphics.rgb(200, 60, 60))
}

quit :: proc(p: ^platform.Platform, g: ^Level_Designer) {
    for texture in g.block_textures {
        if texture != nil { sdl3.DestroyTexture(texture) }
    }

    // for button in g.file_bar {
    //     if button.text != nil { ttf.DestroyText(button.text) }
    // }

    if g.ui.ctx != nil {
        if g.ui.ctx.font != nil { ttf.CloseFont(g.ui.ctx.font) }

        free(g.ui.ctx)
    }
}

handle_event :: proc(p: ^platform.Platform, g: ^Level_Designer, e: sdl3.Event) {
    #partial switch e.type {
        case .KEY_UP:
            #partial switch e.key.scancode {
                case .D: spawn_block(g, .Diamond)
                case .P: spawn_block(g, .Pentagon)
                case .S: spawn_block(g, .Square)
                case .R: spawn_block(g, .Rectangle)

                case .EQUALS, .KP_PLUS: increment_block_size(_selected_block(g))
                case .MINUS, .KP_MINUS: decrement_block_size(_selected_block(g))

                case .BACKSPACE, .DELETE: delete_selected_block(g)
            }
    }
}

update_and_render :: proc(p: ^platform.Platform, g: ^Level_Designer) {
    m_position     := platform.mouse_position(p.mouse)
    mouse_in_arena := sdl3.PointInRectFloat(cast(sdl3.FPoint) m_position, g.arena_rect)

    // File Tool Bar
    // =============
    __save_dialog_function :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: i32) {
        context = runtime.default_context()

        g := cast(^Level_Designer) userdata

        if filelist == nil {
            fmt.println("Error while saving level")
            fmt.println(sdl3.GetError())
        } else {
            // We're going to assume there is only one entry in the filelist
            // since we don't support saving to multiple files anyway.
            file := filelist[0]

            if file != nil {
                saveable_level := wizard.Arena_Layout {
                    blocks   = g.level.blocks[:g.used],
                    elements = g.level.elements,
                }

                for &block in saveable_level.blocks {
                    block.position -= g.arena_min
                }

                options := json.Marshal_Options {
                    spec       = .JSON5,
                    pretty     = true,
                    use_spaces = true,
                    spaces     = 4,
                }

                data, error := json.marshal(saveable_level, options)

                // TODO: Report these errors back to the user somehow.
                //       A popup window would be terrible, but easy.
                if error != nil {
                    fmt.println("Failed to save", error)
                } else {
                    success := sdl3.SaveFile(file, raw_data(data), len(data))

                    delete(data)

                    if !success {
                        fmt.println("Failed to save", file)
                        fmt.println(sdl3.GetError())
                    }
                }

                for &block in saveable_level.blocks {
                    block.position += g.arena_min
                }
            }
        }
    }

    __load_dialog_function :: proc "c" (userdata: rawptr, filelist: [^]cstring, filter: i32) {
        context = runtime.default_context()

        g := cast(^Level_Designer) userdata

        if filelist == nil {
            fmt.println("Error while loading level")
            fmt.println(sdl3.GetError())
        } else {
            // We're going to assume there is only one entry in the filelist
            // since we disallowed selecting multiple files.
            file := filelist[0]
            size := uint(0)
            data := sdl3.LoadFile(file, &size)

            if data == nil {
                fmt.println("Unable to load", file)
                fmt.println(sdl3.GetError())
            } else {
                defer sdl3.free(data)

                json_data := (cast([^]u8) data)[:size]
                loaded_level: wizard.Arena_Layout

                // TODO: Check the error
                json.unmarshal(json_data, &loaded_level)

                // Swap the loaded blocks into the editor's level
                g.used = len(loaded_level.blocks)

                mem.copy_non_overlapping(
                    raw_data(g.level.blocks),
                    raw_data(loaded_level.blocks),
                    size_of(wizard.Layout_Block) * g.used,
                )

                for &block in g.level.blocks {
                    block.position += g.arena_min
                }

                delete(loaded_level.blocks)
            }
        }

        for i := 0; true; i += 1 {
            file := filelist[i]

            if file == nil {
                break
            } else {
                fmt.println(file)
            }
        }
    }

    __new_level :: proc(g: ^Level_Designer) {
        g.used           = 0
        g.level.elements = {}
    }

    __save_level :: proc(p: ^platform.Platform, g: ^Level_Designer) {
        sdl3.ShowSaveFileDialog(__save_dialog_function, g, p.window, nil, 0, "src/wizard/layouts")
    }

    __load_level :: proc(p: ^platform.Platform, g: ^Level_Designer) {
        sdl3.ShowOpenFileDialog(__load_dialog_function, g, p.window, nil, 0, "src/wizard/layouts", false)
    }

    {
        ui.push_layout_scope(g.ui.ctx, ui.row_layout(10, 10))

        if g.used > 0 { g.ui.new_level.colour = graphics.rgb(200, 60, 60) }
        else          { g.ui.new_level.colour = graphics.rgb(60, 200, 60) }

        if ui.button(g.ui.ctx, g.ui. new_level) do  __new_level(g)
        if ui.button(g.ui.ctx, g.ui.save_level) do __save_level(p, g)
        if ui.button(g.ui.ctx, g.ui.load_level) do __load_level(p, g)
    }


    // Block Spawners
    // ==============
    {
        ui.push_layout_scope(g.ui.ctx, ui.column_layout(g.arena_rect.x, g.arena_rect.y, .Right))

        if ui.button(g.ui.ctx, g.ui.spawn_diamond)   do spawn_block(g, .Diamond)
        if ui.button(g.ui.ctx, g.ui.spawn_pentagon)  do spawn_block(g, .Pentagon)
        if ui.button(g.ui.ctx, g.ui.spawn_square)    do spawn_block(g, .Square)
        if ui.button(g.ui.ctx, g.ui.spawn_rectangle) do spawn_block(g, .Rectangle)

        if g.selected == -1 {
            g.ui.increment_size.disabled = true
            g.ui.decrement_size.disabled = true
            g.ui.delete        .disabled = true
        } else {
            g.ui.increment_size.disabled = false
            g.ui.decrement_size.disabled = false
            g.ui.delete        .disabled = false
        }

        {
            ui.push_layout_scope(g.ui.ctx, ui.row_layout(0, 0, .Right))

            block := _selected_block(g)

            // NOTE: These are rendered backwards because
            //       the row is right aligned.
            if ui.button(g.ui.ctx, g.ui.increment_size) do increment_block_size(block)
            if ui.button(g.ui.ctx, g.ui.decrement_size) do decrement_block_size(block)

            ui.label(g.ui.ctx, g.ui.scale_label)
        }

        if ui.button(g.ui.ctx, g.ui.delete) {
            delete_selected_block(g)
        }
    }

    // Level
    // =====
    __block_mid_point_offset :: proc(block: wizard.Layout_Block) -> glsl.vec2 {
        width, height    := wizard.layout_block_size(block)
        mid_point_offset := glsl.vec2 { width, height } / 2

        return mid_point_offset
    }

    sdl3.SetRenderDrawColor(p.renderer, 0, 255, 0, 255)
    sdl3.RenderRect(p.renderer, &g.arena_rect)

    hovered := -1

    for i := 0; i < g.used; i += 1 {
        block         := g.level.blocks[i]
        width, height := wizard.layout_block_size(block)

        texture := g.block_textures[block.shape]
        rect    := sdl3.FRect {
            x = block.position.x - width  / 2,
            y = block.position.y - height / 2,
            w = width,
            h = height,
        }

        if sdl3.PointInRectFloat(cast(sdl3.FPoint) m_position, rect) {
            hovered = i
        }

        sdl3.RenderTexture(p.renderer, texture, nil, &rect)

             if g.selected == i { sdl3.SetRenderDrawColor(p.renderer,   0, 255, 0, 255) }
        else if hovered    == i { sdl3.SetRenderDrawColor(p.renderer, 255,   0, 0, 255) }
        else                    { sdl3.SetRenderDrawColor(p.renderer,   0,   0, 0, 255) }

        sdl3.RenderRect(p.renderer, &rect)
    }

    __move_block :: proc(g: ^Level_Designer, m_position: glsl.vec2) {
        block            := _selected_block(g)
        mid_point_offset := __block_mid_point_offset(block^)

        block.position = glsl.clamp(
            m_position + g.select_d,
            g.arena_min + mid_point_offset,
            g.arena_max - mid_point_offset,
        )
    }

    if mouse_in_arena {
        if platform.button_pressed(p.mouse, .Left) {
            if hovered == -1 {
                g.selected = -1
            } else {
                block := &g.level.blocks[hovered]

                g.select_d = block.position - m_position
                g.selected = hovered
            }
        } else if platform.button_held(p.mouse, .Left) {
            __move_block(g, m_position)
        } else {
            // Do nothing
        }
    }

    if g.spawned {
        g.spawned = false
        __move_block(g, m_position)
    }
}

spawn_block :: proc(g: ^Level_Designer, shape: wizard.Block_Shape) {
    if g.used < MAX_BLOCKS {
        g.selected = g.used
        g.spawned  = true

        block      := &g.level.blocks[g.used]
        block.shape = shape
        block.scale = .One

        g.used += 1
    }
}

increment_block_size :: #force_inline proc(block: ^wizard.Layout_Block) { block.scale = cast(wizard.Block_Scale) min(4, int(block.scale) + 1) }
decrement_block_size :: #force_inline proc(block: ^wizard.Layout_Block) { block.scale = cast(wizard.Block_Scale) max(1, int(block.scale) - 1) }

delete_selected_block :: proc(g: ^Level_Designer) {
    if g.selected != -1 {
        g.used -= 1

        slice.swap(g.level.blocks, g.selected, g.used)
        g.selected = -1
    }
}

@private _selected_block :: proc(g: ^Level_Designer) -> ^wizard.Layout_Block {
    block := _nil_block()

    if g.selected != -1 {
        block = &g.level.blocks[g.selected]
    }

    return block
}

@private _nil_block :: #force_inline proc() -> ^wizard.Layout_Block {
    @static NIL_BLOCK: wizard.Layout_Block

    nil_block := &NIL_BLOCK
    nil_block^ = {}

    return nil_block
}
