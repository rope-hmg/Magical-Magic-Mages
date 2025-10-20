package graphics

import "vendor:sdl3"

@(deferred_in_out=pop_render_draw_colour)
push_render_draw_colour_scope :: #force_inline proc(renderer: ^sdl3.Renderer, colour: Colour) -> Colour {
    old_colour: Colour

    sdl3.GetRenderDrawColor(
        renderer,
        &old_colour.components.r,
        &old_colour.components.g,
        &old_colour.components.b,
        &old_colour.components.a,
    )

    sdl3.SetRenderDrawColor(
        renderer,
        colour.components.r,
        colour.components.g,
        colour.components.b,
        colour.components.a,
    )

    return old_colour
}

pop_render_draw_colour :: #force_inline proc(renderer: ^sdl3.Renderer, new_colour, old_colour: Colour) {
    sdl3.SetRenderDrawColor(
        renderer,
        old_colour.components.r,
        old_colour.components.g,
        old_colour.components.b,
        old_colour.components.a,
    )
}
