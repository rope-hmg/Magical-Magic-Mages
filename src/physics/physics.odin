package physics

import "core:math/linalg/glsl"

import "vendor:sdl3"
import "vendor:box2d"

CATEGORY_BALL:     u64: 0x00000000_00000001
CATEGORY_PARTICLE: u64: 0x00000000_00000002
CATEGORY_WALL:     u64: 0x00000000_00000004
CATEGORY_BLOCK:    u64: 0x00000000_00000008

PIXELS_PER_METRE  :: 32.0
METRES_PER_PIXEL  :: 1.0 / PIXELS_PER_METRE

pixels_to_metres_f32  :: #force_inline proc(pixel_distance: f32)        -> f32        { return pixel_distance * METRES_PER_PIXEL }
pixels_to_metres_vec2 :: #force_inline proc(pixel_distance: glsl.vec2)  -> glsl.vec2  { return { pixels_to_metres_f32(pixel_distance.x), pixels_to_metres_f32(pixel_distance.y) } }
pixels_to_metres_rect :: #force_inline proc(pixel_distance: sdl3.FRect) -> sdl3.FRect { return { pixels_to_metres_f32(pixel_distance.x), pixels_to_metres_f32(pixel_distance.y), pixels_to_metres_f32(pixel_distance.w), pixels_to_metres_f32(pixel_distance.h) } }
pixels_to_metres :: proc {
    pixels_to_metres_f32,
    pixels_to_metres_vec2,
    pixels_to_metres_rect,
}

metres_to_pixels_f32  :: #force_inline proc(metres: f32)        -> f32        { return metres * PIXELS_PER_METRE }
metres_to_pixels_vec2 :: #force_inline proc(metres: glsl.vec2)  -> glsl.vec2  { return { metres_to_pixels_f32(metres.x), metres_to_pixels_f32(metres.y) } }
metres_to_pixels_rect :: #force_inline proc(metres: sdl3.FRect) -> sdl3.FRect { return { metres_to_pixels_f32(metres.x), metres_to_pixels_f32(metres.y), metres_to_pixels_f32(metres.w), metres_to_pixels_f32(metres.h) } }
metres_to_pixels :: proc {
    metres_to_pixels_f32,
    metres_to_pixels_vec2,
    metres_to_pixels_rect,
}

render_textured_object :: proc(
    renderer: ^sdl3.Renderer,
    texture:  ^sdl3.Texture,
    body_id:   box2d.BodyId,
    shape_id:  box2d.ShapeId,
) {
    position := metres_to_pixels(box2d.Body_GetPosition(body_id))
    aabb     := box2d.Shape_GetAABB(shape_id)
    extent   := metres_to_pixels(aabb.upperBound - aabb.lowerBound)

    rect := sdl3.FRect {
        x = (position.x - extent.x / 2),
        y = (position.y - extent.y / 2),
        w = extent.x,
        h = extent.y,
    }

    sdl3.RenderTexture(renderer, texture, nil, &rect)
}