package graphics

import "core:math"

import "vendor:sdl3"

Colour :: struct #raw_union {
    components: [4]u8,
    sdl_colour: sdl3.Color,
    value:      u32,
}

rgb :: proc(r, g, b: u8) -> Colour {
    return {
        components = { r, g, b, 255 },
    }
}

lighten :: proc(colour: Colour, percent: f32) -> Colour {
    hsl  := _rgb_to_hsl(colour)
    hsl.l = clamp(hsl.l * percent, 0.0, 1.0)
    rgb  := _hsl_to_rgb(hsl, colour.components.a)

    return rgb
}

@private _HSL_Colour :: struct { h, s, l: f32 }

@private _rgb_to_hsl :: proc(colour: Colour) -> _HSL_Colour {
    r := f32(colour.components.r) / 255.0
    g := f32(colour.components.g) / 255.0
    b := f32(colour.components.b) / 255.0

    h, s, l: f32

    min := min(r, g, b)
    max := max(r, g, b)

    d := max - min

         if d   == 0.0 { h = 0.0 }
    else if max == r   { h = (g - b) / math.remainder(d, 6.0) }
    else if max == g   { h = (b - r) / d + 2.0 }
    else if max == b   { h = (r - g) / d + 4.0 }

    l = (min + max) / 2.0

    if d == 0.0 { s = 0 }
    else        { s = d / (1 - abs(2.0 * l - 1.0)) }

    h *= 60.0

    return { h, s, l }
}

@private _hsl_to_rgb :: proc(colour: _HSL_Colour, a: u8) -> Colour {
    h := colour.h
    s := colour.s
    l := colour.l

    rgb: [3]f32

    c  := (1.0 - abs(2.0 * l - 1.0)) * s
    hp := h / 60.0
    x  := c * (1 - abs(math.remainder(hp, 2.0) - 1.0))

         if math.is_nan(h) { rgb = {0, 0, 0} }
    else if hp <= 1.0      { rgb = {c, x, 0} }
    else if hp <= 2.0      { rgb = {x, c, 0} }
    else if hp <= 3.0      { rgb = {0, c, x} }
    else if hp <= 4.0      { rgb = {0, x, c} }
    else if hp <= 5.0      { rgb = {x, 0, c} }
    else if hp <= 6.0      { rgb = {c, 0, x} }

    m := l - c * 0.5

    r := u8(math.round(255.0 * (rgb[0] + m)))
    g := u8(math.round(255.0 * (rgb[1] + m)))
    b := u8(math.round(255.0 * (rgb[2] + m)))

    return { components = { r, g, b, a } }
}