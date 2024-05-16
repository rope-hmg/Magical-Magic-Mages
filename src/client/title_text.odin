package client

import "base:runtime"

import "core:math"

import SDL "vendor:sdl2"

Glyph :: struct {
    spacing: i32,
    glyph_x: i32,
    glyph_y: i32,
}

fancy_glyps := [256]Glyph {
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph { spacing = 8, glyph_x = 26, glyph_y = 1 }, // SPACE
    Glyph { spacing = 4, glyph_x = 37, glyph_y = 0 }, // !
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph { spacing = 8, glyph_x = 35, glyph_y = 0 }, // 0
    Glyph { spacing = 4, glyph_x = 26, glyph_y = 0 }, // 1
    Glyph { spacing = 8, glyph_x = 27, glyph_y = 0 }, // 2
    Glyph { spacing = 7, glyph_x = 28, glyph_y = 0 }, // 3
    Glyph { spacing = 8, glyph_x = 29, glyph_y = 0 }, // 4
    Glyph { spacing = 8, glyph_x = 30, glyph_y = 0 }, // 5
    Glyph { spacing = 8, glyph_x = 31, glyph_y = 0 }, // 6
    Glyph { spacing = 8, glyph_x = 32, glyph_y = 0 }, // 7
    Glyph { spacing = 8, glyph_x = 33, glyph_y = 0 }, // 8
    Glyph { spacing = 8, glyph_x = 34, glyph_y = 0 }, // 9
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph { spacing = 8, glyph_x = 0,  glyph_y = 0 }, // A
    Glyph { spacing = 8, glyph_x = 1,  glyph_y = 0 }, // B
    Glyph { spacing = 8, glyph_x = 2,  glyph_y = 0 }, // C
    Glyph { spacing = 8, glyph_x = 3,  glyph_y = 0 }, // D
    Glyph { spacing = 8, glyph_x = 4,  glyph_y = 0 }, // E
    Glyph { spacing = 8, glyph_x = 5,  glyph_y = 0 }, // F
    Glyph { spacing = 8, glyph_x = 6,  glyph_y = 0 }, // G
    Glyph { spacing = 8, glyph_x = 7,  glyph_y = 0 }, // H
    Glyph { spacing = 4, glyph_x = 8,  glyph_y = 0 }, // I
    Glyph { spacing = 5, glyph_x = 9,  glyph_y = 0 }, // J
    Glyph { spacing = 8, glyph_x = 10, glyph_y = 0 }, // K
    Glyph { spacing = 8, glyph_x = 11, glyph_y = 0 }, // L
    Glyph { spacing = 8, glyph_x = 12, glyph_y = 0 }, // M
    Glyph { spacing = 8, glyph_x = 13, glyph_y = 0 }, // N
    Glyph { spacing = 8, glyph_x = 14, glyph_y = 0 }, // O
    Glyph { spacing = 8, glyph_x = 15, glyph_y = 0 }, // P
    Glyph { spacing = 8, glyph_x = 16, glyph_y = 0 }, // Q
    Glyph { spacing = 8, glyph_x = 17, glyph_y = 0 }, // R
    Glyph { spacing = 8, glyph_x = 18, glyph_y = 0 }, // S
    Glyph { spacing = 8, glyph_x = 19, glyph_y = 0 }, // T
    Glyph { spacing = 8, glyph_x = 20, glyph_y = 0 }, // U
    Glyph { spacing = 8, glyph_x = 21, glyph_y = 0 }, // V
    Glyph { spacing = 8, glyph_x = 22, glyph_y = 0 }, // W
    Glyph { spacing = 8, glyph_x = 23, glyph_y = 0 }, // X
    Glyph { spacing = 8, glyph_x = 24, glyph_y = 0 }, // Y
    Glyph { spacing = 8, glyph_x = 25, glyph_y = 0 }, // Z
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph { spacing = 8, glyph_x = 0,  glyph_y = 1 }, // a
    Glyph { spacing = 8, glyph_x = 1,  glyph_y = 1 }, // b
    Glyph { spacing = 8, glyph_x = 2,  glyph_y = 1 }, // c
    Glyph { spacing = 8, glyph_x = 3,  glyph_y = 1 }, // d
    Glyph { spacing = 8, glyph_x = 4,  glyph_y = 1 }, // e
    Glyph { spacing = 8, glyph_x = 5,  glyph_y = 1 }, // f
    Glyph { spacing = 8, glyph_x = 6,  glyph_y = 1 }, // g
    Glyph { spacing = 8, glyph_x = 7,  glyph_y = 1 }, // h
    Glyph { spacing = 4, glyph_x = 8,  glyph_y = 1 }, // i
    Glyph { spacing = 5, glyph_x = 9,  glyph_y = 1 }, // j
    Glyph { spacing = 8, glyph_x = 10, glyph_y = 1 }, // k
    Glyph { spacing = 4, glyph_x = 11, glyph_y = 1 }, // l
    Glyph { spacing = 8, glyph_x = 12, glyph_y = 1 }, // m
    Glyph { spacing = 8, glyph_x = 13, glyph_y = 1 }, // n
    Glyph { spacing = 8, glyph_x = 14, glyph_y = 1 }, // o
    Glyph { spacing = 8, glyph_x = 15, glyph_y = 1 }, // p
    Glyph { spacing = 8, glyph_x = 16, glyph_y = 1 }, // q
    Glyph { spacing = 8, glyph_x = 17, glyph_y = 1 }, // r
    Glyph { spacing = 8, glyph_x = 18, glyph_y = 1 }, // s
    Glyph { spacing = 8, glyph_x = 19, glyph_y = 1 }, // t
    Glyph { spacing = 8, glyph_x = 20, glyph_y = 1 }, // u
    Glyph { spacing = 8, glyph_x = 21, glyph_y = 1 }, // v
    Glyph { spacing = 8, glyph_x = 22, glyph_y = 1 }, // w
    Glyph { spacing = 8, glyph_x = 23, glyph_y = 1 }, // x
    Glyph { spacing = 8, glyph_x = 24, glyph_y = 1 }, // y
    Glyph { spacing = 8, glyph_x = 25, glyph_y = 1 }, // z
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
    Glyph {},
}

Title_Text :: struct {
    glyphs:      []^Glyph,
    width:       i32,
    scale:       i32,
    start_x:     i32,
    animation_t: f32,
}

title_text_load :: proc(title_text: ^Title_Text, title: cstring) {
    assert(title_text != nil)

    title_len        := len(title)
    title_bytes      := transmute(runtime.Raw_Cstring) title
    title_text.glyphs = make([]^Glyph, title_len)

    title_text.scale       = 4
    title_text.width       = 0
    title_text.animation_t = 0

    for i := 0; i < title_len; i += 1 {
        b := title_bytes.data[i]
        g := &fancy_glyps[b]

        title_text.width    += g.spacing
        title_text.glyphs[i] = g
    }

    for title_text.width * title_text.scale > RESOLUTION_X do title_text.scale -= 1
    if  title_text.scale <= 0                              do title_text.scale  = 1

    title_text.start_x = (RESOLUTION_X - (title_text.width * title_text.scale)) / 2
}

title_text_unload :: proc(title_text: ^Title_Text) {
    assert(title_text != nil)
    delete(title_text.glyphs)
    title_text.glyphs = nil
}

title_text_update_and_render :: proc(title_text: ^Title_Text, renderer: ^SDL.Renderer, assets: Assets) {
    assert(renderer   != nil)
    assert(title_text != nil)

    GLYPH_TILE_W :: 8
    GLYPH_TILE_H :: 16

    next_x: i32 = title_text.start_x
    next_y: i32 = 10

    title_text.animation_t += 0.05

    src_rect := SDL.Rect {
        w = GLYPH_TILE_W,
        h = GLYPH_TILE_H,
    }

    dst_rect := SDL.Rect {
        w = GLYPH_TILE_W * title_text.scale,
        h = GLYPH_TILE_H * title_text.scale,
    }

    for glyph, index in title_text.glyphs {
        src_rect.x = GLYPH_TILE_W * glyph.glyph_x
        src_rect.y = GLYPH_TILE_H * glyph.glyph_y

        dst_rect.x = next_x
        dst_rect.y = next_y + i32(math.sin(title_text.animation_t + f32(index)) * f32(title_text.scale))

        next_x += glyph.spacing * title_text.scale

        SDL.SetRenderDrawColor(renderer, 255, 0, 0, 0)
        SDL.RenderFillRect    (renderer, &dst_rect)
        SDL.RenderCopy        (renderer, assets.fancy, &src_rect, &dst_rect)
    }
}
