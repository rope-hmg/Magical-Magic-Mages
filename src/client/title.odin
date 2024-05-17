package client

import "base:runtime"

import "core:fmt"
import "core:math"

import SDL "vendor:sdl2"

GLYPH_TILE_W :: 8
GLYPH_TILE_H :: 16
ENTRY_COUNT  :: 4
ENTRY_TEXT   := [ENTRY_COUNT]string {
    "Play",
    "Options",
    "Credits",
    "Quit",
}

Title_Data :: struct {
    title_text: Text_Item,
    options:    [ENTRY_COUNT]Text_Item,
    selected:   i32,
    animation:  Text_Animation,
}

title_load :: proc(title_data: ^Title_Data, title: cstring, assets: Assets) {
    title_data.title_text = make_text_item(title, 0, 10, 4, assets.fancy)

    for i: i32 = 0; i < ENTRY_COUNT; i += 1 {
        title_data.options[i] = make_text_item(ENTRY_TEXT[i], 0, 100 + i * (GLYPH_TILE_H + 20), 2, assets.fancy)
    }

    title_data.animation = make_wave_animation()
}

title_unload :: proc(using title_data: ^Title_Data) {
    assert(title_data != nil)

    delete_animation(title_data.animation)
    delete_text_item(title_text)

    for i := 0; i < ENTRY_COUNT; i += 1 {
        delete_text_item(title_data.options[i])
    }
}

title_update_and_render :: proc(title_data: ^Title_Data, renderer: ^SDL.Renderer, input: Input) -> ^Stage {
    assert(title_data != nil)
    assert(renderer   != nil)

    SDL.SetRenderDrawColor(renderer, 255, 0, 0, 0)
    render_text_item(renderer, title_data.title_text, title_data.animation)

    for i: i32 = 0; i < ENTRY_COUNT; i += 1 {
        entry    := &title_data.options[i]
        position := input.cursor_position

        if SDL.PointInRect(&position, &entry.bounds) {
            title_data.selected = i
        }

        animation := IDENTITY

        if title_data.selected == i {
            SDL.SetRenderDrawColor(renderer, 0, 255, 0, 0)
            animation = title_data.animation
        } else {
            SDL.SetRenderDrawColor(renderer, 255, 0, 0, 0)
        }

        render_text_item(renderer, entry^, animation)
    }

    return nil
}
