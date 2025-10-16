package ui

import "core:fmt"

import "vendor:sdl3"
import "vendor:sdl3/ttf"

import "game:graphics"
import "game:platform"

MAX_LAYOUT_DEPTH :: 16
DISABLED_COLOUR  := graphics.Colour { components = { 60, 60, 60, 255 } }

Context :: struct {
    renderer:    ^sdl3.Renderer,
    text_engine: ^ttf.TextEngine,
    font:        ^ttf.Font,
    mouse:       ^platform.Mouse,

    layout_stack: [MAX_LAYOUT_DEPTH]Layout,
    layout_index: int,

    spacing:      f32,
    text_padding: f32,
}

Layout_Type  :: enum { Row, Column }
Layout_Align :: enum { Left, Right }
Layout_Style :: struct {
    type:  Layout_Type,
    align: Layout_Align,
}

Layout :: struct {
    x_start: f32,
    x:       f32,
    y_start: f32,
    y:       f32,
    w:       f32,
    h:       f32,

    using style: Layout_Style,
}

row_layout :: proc(x, y: f32, align := Layout_Align.Left) -> Layout {
    return {
        x_start = x,
        x       = x,
        y_start = y,
        y       = y,
        type    = .Row,
        align   = align,
    }
}

column_layout :: proc(x, y: f32, align := Layout_Align.Left) -> Layout {
    return {
        x_start = x,
        x       = x,
        y_start = y,
        y       = y,
        type    = .Column,
        align   = align,
    }
}

push_layout :: proc(ctx: ^Context, layout: Layout) {
    if ctx.layout_index < MAX_LAYOUT_DEPTH {
        layout := layout
        parent := _parent_layout(ctx)

        switch parent.style { // TODO: Make this do the right thing
            case { .Row,    .Left  }:
                layout.x_start += parent.x_start
                layout.y_start += parent.y_start
                layout.x       += parent.x
                layout.y       += parent.y
            case { .Row,    .Right }:
                layout.x_start += parent.x_start
                layout.y_start += parent.y_start
                layout.x       += parent.x
                layout.y       += parent.y
            case { .Column, .Left  }:
                layout.x_start += parent.x_start
                layout.y_start += parent.y_start
                layout.x       += parent.x
                layout.y       += parent.y
            case { .Column, .Right }:
                layout.x_start += parent.x_start
                layout.y_start += parent.y_start
                layout.x       += parent.x
                layout.y       += parent.y
        }

        ctx.layout_stack[ctx.layout_index] = layout

        ctx.layout_index += 1
    } else {
        fmt.panicf("No more space in the layout stack")
    }
}

@(deferred_in=pop_layout)
push_layout_scope :: proc(ctx: ^Context, layout: Layout) {
    push_layout(ctx, layout)
}

pop_layout :: proc(ctx: ^Context, layout: Layout) {
    layout := _parent_layout(ctx)
    ctx.layout_index = max(0, ctx.layout_index - 1)

    _apply_layout_to_item(
        ctx,
        layout.w, layout.h,
        proc(ctx: ^Context, x, y: f32, userdata: ^rawptr) -> rawptr { return nil },
        nil,
    )
}

@private _apply_layout_to_item :: proc(
    ctx:      ^Context,
    w, h:     f32,
    render:   proc(ctx: ^Context, x, y: f32, userdata: ^$U) -> $T,
    userdata: ^U,
) -> T {
    result: T

    if ctx.layout_index > 0 {
        layout := &ctx.layout_stack[ctx.layout_index - 1]

        x := layout.x
        y := layout.y

        switch layout.style {
            case { .Row,    .Right }: x = layout.x       - (w + ctx.spacing)
            case { .Column, .Right }: x = layout.x_start - (w + ctx.spacing)
        }

        result = render(ctx, x, y, userdata)

        switch layout.type {
            case .Row:
                layout.w += w
                layout.h  = max(layout.h, h)

                switch layout.align {
                    case .Left:  layout.x += w + ctx.spacing
                    case .Right: layout.x  = x
                }

            case .Column:
                layout.w  = max(layout.w, w)
                layout.h += h
                layout.y += h + ctx.spacing
        }
    }

    return result
}

@private _parent_layout :: proc(ctx: ^Context) -> ^Layout {
    @static NIL_LAYOUT: Layout

    parent := &NIL_LAYOUT
    parent^ = {}

    if ctx.layout_index > 0 {
        parent = &ctx.layout_stack[ctx.layout_index - 1]
    }

    return parent
}

// ----------------------------------------------
// Button
// ----------------------------------------------

Button :: struct {
    colour:   graphics.Colour,
    text:     ^ttf.Text,
    w, h:     f32,
    disabled: bool,
}

create_button :: proc(ctx: ^Context, text: string, colour: graphics.Colour) -> Button {
    button := Button {
        colour   = colour,
        text     = ttf.CreateText(ctx.text_engine, ctx.font, cstring(raw_data(text)), len(text)),
        disabled = false,
    }

    button.w, button.h = _get_padded_width_height(ctx, button.text)

    return button
}

button :: proc(ctx: ^Context, button: Button) -> bool {
    button := button

    return _apply_layout_to_item(
        ctx,
        button.w, button.h,
        proc(ctx: ^Context, x, y: f32, button: ^Button) -> bool {
            button_rect := sdl3.FRect {
                x = x,
                y = y,
                w = button.w,
                h = button.h,
            }

            c := button.disabled ? DISABLED_COLOUR : button.colour
            p := false
            h := false

            if !button.disabled &&
               sdl3.PointInRectFloat(cast(sdl3.FPoint) platform.mouse_position(ctx.mouse^), button_rect)
            {
                c = graphics.lighten(c, 1.2)
                p = platform.button_pressed(ctx.mouse^, .Left)
                h = platform.button_held   (ctx.mouse^, .Left)
            }

            d := graphics.lighten(c, 0.8)
            l := graphics.lighten(c, 1.2)

            // Render Button Background
            // ========================
            _set_render_draw_colour(ctx.renderer, c)
            sdl3.RenderFillRect(ctx.renderer, &button_rect)

            // Render Button Shadow
            // ====================
            shadow_size := ctx.text_padding * 0.6

            _set_render_draw_colour(ctx.renderer, h?d:l)
            sdl3.RenderFillRect(ctx.renderer, &sdl3.FRect{ x=x, y=y, w=button.w, h=shadow_size })
            sdl3.RenderFillRect(ctx.renderer, &sdl3.FRect{ x=x, y=y, w=shadow_size, h=button.h })

            _set_render_draw_colour(ctx.renderer, h?l:d)
            sdl3.RenderFillRect(ctx.renderer, &sdl3.FRect{ x=x, y=y+button.h-shadow_size, w=button.w, h=shadow_size })
            sdl3.RenderFillRect(ctx.renderer, &sdl3.FRect{ x=x+button.w-shadow_size, y=y, w=shadow_size, h=button.h })

            // Render Button Text
            // ==================
            ttf.SetTextColor(button.text, 0, 0, 0, 255)
            ttf.DrawRendererText(button.text, x + ctx.text_padding, y + ctx.text_padding)

            return p
        },
        &button
    )
}

// ----------------------------------------------
// Label
// ----------------------------------------------

Label :: struct {
    colour: graphics.Colour,
    text:   ^ttf.Text,
    w, h:   f32,
}

create_label :: proc(ctx: ^Context, text: string, colour: graphics.Colour) -> Label {
    label := Label {
        colour = colour,
        text   = ttf.CreateText(ctx.text_engine, ctx.font, cstring(raw_data(text)), len(text)),
    }

    label.w, label.h = _get_padded_width_height(ctx, label.text)

    return label
}

label :: proc(ctx: ^Context, label: Label) {
    label := label

    _apply_layout_to_item(
        ctx,
        label.w, label.h,
        proc(ctx: ^Context, x, y: f32, label: ^Label) -> rawptr {
            label_rect := sdl3.FRect {
                x = x,
                y = y,
                w = label.w,
                h = label.h,
            }

            // Render Label Background
            // ========================
            _set_render_draw_colour(ctx.renderer, label.colour)
            sdl3.RenderFillRect(ctx.renderer, &label_rect)

            // Render Label Text
            // ==================
            ttf.SetTextColor(label.text, 0, 0, 0, 255)
            ttf.DrawRendererText(label.text, x + ctx.text_padding, y + ctx.text_padding)

            return nil
        },
        &label,
    )
}

// ----------------------------------------------
// Text Item
// ----------------------------------------------

@private _Text_Ptr :: union {
    ^Button,
    ^Label,
}

insert_text :: proc(ctx: ^Context, text_item: _Text_Ptr, offset: int, insert: string) {
    switch item in text_item {
        case ^Button: item.w, item.h = _insert_text(ctx, item.text, offset, insert)
        case ^Label:  item.w, item.h = _insert_text(ctx, item.text, offset, insert)
    }
}

@private _insert_text :: proc(ctx: ^Context, text: ^ttf.Text, offset: int, insert: string) -> (f32, f32) {
    ttf.InsertTextString(text, i32(offset), cstring(raw_data(insert)), uint(len(insert)))

    return _get_padded_width_height(ctx, text)
}

delete_text :: proc(ctx: ^Context, text_item: _Text_Ptr, offset, length: int) {
    switch item in text_item {
        case ^Button: item.w, item.h = _delete_text(ctx, item.text, offset, length)
        case ^Label:  item.w, item.h = _delete_text(ctx, item.text, offset, length)
    }
}

@private _delete_text :: proc(ctx: ^Context, text: ^ttf.Text, offset, length: int) -> (f32, f32) {
    ttf.DeleteTextString(text, i32(offset), i32(length))

    return _get_padded_width_height(ctx, text)
}

// ----------------------------------------------
// Utility
// ----------------------------------------------

int_to_string :: proc(value: int) -> string {
    @static DIGITS := []u8 { 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39 }

    text: string

    if value == 0 {
        text = "0"
    } else {
        text_length := value < 0 ? 1 : 0
        number      := abs(value)

        for number > 0 {
            text_length += 1
            number      /= 10
        }

        text_digits := make([]u8, text_length, context.temp_allocator)
        number       = abs(value)

        if value < 0 {
            text_digits[0] = 0x2D // -
        }

        for number > 0 {
            text_length -= 1
            digit_index := number % 10
            number       = number / 10

            text_digits[text_length] = DIGITS[digit_index]
        }

        text = transmute(string) text_digits
    }

    return text
}

@private _get_padded_width_height :: proc(ctx: ^Context, text: ^ttf.Text) -> (f32, f32) {
    width:  i32
    height: i32
    if !ttf.GetTextSize(text, &width, &height) {
        width  = 50
        height = 25
    }

    w := f32(width)  + ctx.text_padding * 2
    h := f32(height) + ctx.text_padding * 2

    return w, h
}

@private _set_render_draw_colour :: #force_inline proc(renderer: ^sdl3.Renderer, colour: graphics.Colour) {
    sdl3.SetRenderDrawColor(
        renderer,
        colour.components.r,
        colour.components.g,
        colour.components.b,
        colour.components.a,
    )
}

