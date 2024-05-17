package client

import "base:runtime"

import "core:fmt"
import "core:math"

import SDL "vendor:sdl2"

Text_Item :: struct {
    glyphs: []^Glyph,
    texture:  ^SDL.Texture,
    bounds:    SDL.Rect,
    scale:     i32,
}

Glyph :: struct {
    spacing: i32,
    glyph_x: i32,
    glyph_y: i32,
}

make_text_item_from_cstring :: proc(text: cstring, x, y, scale: i32, texture: ^SDL.Texture) -> Text_Item {
    len  := len(text)
    text := transmute(runtime.Raw_Cstring) text

    return make_text_item_from_ascii_bytes(text.data, i32(len), x, y, scale, texture)
}

make_text_item_from_string :: proc(text: string, x, y, scale: i32, texture: ^SDL.Texture) -> Text_Item {
    text := transmute(runtime.Raw_String) text

    return make_text_item_from_ascii_bytes(text.data, i32(text.len), x, y, scale, texture)
}

make_text_item_from_ascii_bytes :: proc(bytes: [^]byte, len: i32, x, y, scale: i32, texture: ^SDL.Texture) -> Text_Item {
    assert(bytes != nil)

    text := Text_Item {}
    text.glyphs  = make([]^Glyph, len)
    text.texture = texture
    text.scale   = scale

    width: i32 = 0
    for i: i32 = 0; i < len; i += 1 {
        b := bytes[i]
        g := &fancy_glyphs[b]

        width += g.spacing

        text.glyphs[i] = g
    }

    for text.scale * width >  RESOLUTION_X do text.scale -= 1
    if  text.scale         <= 0            do text.scale  = 1

    text.bounds = SDL.Rect {
        x = (RESOLUTION_X - (width * text.scale)) / 2, // TODO: Think of a way to allow different x
        y = y,
        w = width        * text.scale,
        h = GLYPH_TILE_H * text.scale,
    }

    return text
}

make_text_item :: proc {
    make_text_item_from_string,
    make_text_item_from_cstring,
    make_text_item_from_ascii_bytes,
}

render_text_item :: proc(renderer: ^SDL.Renderer, using text_item: Text_Item, animation: Text_Animation = IDENTITY) {
    assert(renderer != nil)
    assert(glyphs   != nil)
    assert(texture  != nil)

    src_rect := SDL.Rect {
        w = GLYPH_TILE_W,
        h = GLYPH_TILE_H,
    }

    dst_rect := SDL.Rect {
        x = bounds.x,
        y = bounds.y,
        w = GLYPH_TILE_W * scale,
        h = GLYPH_TILE_H * scale,
    }

    for glyph, i in glyphs {
        src_rect.x = GLYPH_TILE_W * glyph.glyph_x
        src_rect.y = GLYPH_TILE_H * glyph.glyph_y

        transformed := animation.transform(dst_rect, i32(i), scale, animation.user_data)

        SDL.RenderFillRect(renderer, &transformed)
        SDL.RenderCopy    (renderer, texture, &src_rect, &transformed)

        dst_rect.x += glyph.spacing * scale
    }
}

delete_text_item :: proc(text_item: Text_Item) {
    delete(text_item.glyphs)
}

Text_Animation :: struct {
    user_data: rawptr,
    transform: proc(SDL.Rect, i32, i32, rawptr) -> SDL.Rect,
}

IDENTITY :: Text_Animation {
    user_data = nil,
    transform = proc(rect: SDL.Rect, index, scale: i32, user_data: rawptr) -> SDL.Rect {
        return rect
    },
}

make_wave_animation :: proc() -> Text_Animation {
    // TODO: Think about removing this allocation. We probably don't need to put it on the heap.
    animation_t := new(f32)

    return Text_Animation {
        user_data = animation_t,
        transform = proc(rect: SDL.Rect, index, scale: i32, user_data: rawptr) -> SDL.Rect {
            assert(user_data != nil)

            animation_t  := cast(^f32) user_data
            result       := rect
            result.y     += i32(math.sin(animation_t^ + f32(index)) * f32(scale))
            animation_t^ += 0.005

            return result
        },
    }
}

delete_animation :: proc(animation: Text_Animation) {
    assert(animation.user_data != nil)
    free  (animation.user_data)
}

fancy_glyphs := [256]Glyph {
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
