package wizard

import "core:fmt"
import "core:math/linalg/glsl"
import "core:math/rand"

import "vendor:box2d"

import "game:physics"
import "game:graphics"

SPELL_BLOCK_SIZE_IN_PIXELS :: 20

ARENA_HEIGHT_FRACTION :: 2.0 / 3.0
ARENA_WIDTH_FRACTION  :: 1.0 / 2.0

Block_Shape :: enum {
    Diamond,
    Pentagon,
    Square,
    Rectangle,
}

Block_Element :: enum {
    Basic,    // Grey
    Ice,      // Blue
    Healing,  // Green
    Poison,   // Purple
    Fire,     // Red
    Electric, // Yellow
}

Elements :: [Block_Element]int

Block_Colours :: struct #raw_union {
    array:    [6            ]graphics.Colour,
    elements: [Block_Element]graphics.Colour,
}

BLOCK_COLOURS: Block_Colours = {
    elements = {
        .Basic    = { components = { 204, 204, 204, 255 } }, // Grey
        .Ice      = { components = { 108, 189, 235, 255 } }, // Blue
        .Healing  = { components = { 169, 205,  79, 255 } }, // Green
        .Poison   = { components = { 125,  91, 145, 255 } }, // Purple
        .Fire     = { components = { 223,  73,  65, 255 } }, // Red
        .Electric = { components = { 247, 206,  70, 255 } }, // Yellow
    }
}

Block_Scale :: enum { One = 1, Two, Three, Four }

Block_Status :: enum {
    None,
    Burning,
    Frozen,
    Charged,
    Electrified,
}

Spell_Block :: struct {
    shape:    Block_Shape,
    element:  Block_Element,
    scale:    Block_Scale,
    status:   Block_Status,
    health:   int,
    body_id:  box2d.BodyId,
    shape_id: box2d.ShapeId,
}

Spell_Arena :: struct {
    disabled: int,
    blocks:   []Spell_Block,
    elements: Elements,
    colours:  []graphics.Colour,
}

Layout_Block :: struct {
    position: glsl.vec2,
    shape:    Block_Shape,
    scale:    Block_Scale,
}

layout_block_size :: proc(block: Layout_Block) -> (f32, f32) {
    w_mod := block.shape == .Rectangle ? f32(2) : f32(1)

    block_height := SPELL_BLOCK_SIZE_IN_PIXELS * f32(block.scale)
    block_width  := block_height * w_mod

    return block_width, block_height
}

half_layout_block_size_metres :: proc(block: Layout_Block) -> (f32, f32) {
    width, height := layout_block_size(block)
    width_metres  := physics.pixels_to_metres(width)
    height_metres := physics.pixels_to_metres(height)

    return width_metres / 2, height_metres / 2
}

Arena_Layout :: struct {
    blocks:   []Layout_Block,
    elements: [Block_Element]int,
}

@private _polygons: [Block_Shape][Block_Scale]Maybe(box2d.Polygon)

make_spell_arena :: proc(
    world_id:     box2d.WorldId,
    arena_layout: Arena_Layout,
    arena_offset: glsl.vec2,
) -> Spell_Arena {
    //
    // Generate polygons for all scales that exist within the layout
    //
    DEG_TO_RAD      :: f32(glsl.TAU / 360.0)
    pentagon_angle  := 72.0 * DEG_TO_RAD
    pentagon_points := [5]glsl.vec2 {}
    layout          := arena_layout

    half_block_size := physics.pixels_to_metres(SPELL_BLOCK_SIZE_IN_PIXELS / 2)

    for layout_block in layout.blocks {
        polygon       := &_polygons[layout_block.shape][layout_block.scale]
        width, height := half_layout_block_size_metres(layout_block)

        if polygon^ == nil {
            switch layout_block.shape {
                case .Diamond:
                    rotation := box2d.MakeRot(glsl.PI / 4)
                    polygon^  = box2d.MakeOffsetBox(width, height, {}, rotation)

                case .Pentagon:
                    for &point, i in pentagon_points {
                        rotation := box2d.MakeRot(pentagon_angle * f32(i))
                        point     = box2d.RotateVector(rotation, { 0, -height })
                    }

                    pentagon_hull := box2d.ComputeHull(pentagon_points[:])
                    polygon^       = box2d.MakePolygon(pentagon_hull, 0.0)

                case .Square:
                    polygon^ = box2d.MakeSquare(width)

                case .Rectangle:
                    polygon^ = box2d.MakeBox(width, height)
            }
        }
    }

    //
    // Populate the spell blocks using the layout
    //

    blocks := make([]Spell_Block, len(layout.blocks))

    for layout_block, i in layout.blocks {
        width, height := half_layout_block_size_metres(layout_block)
        block_offset  := glsl.vec2 { width, height }

        if layout_block.shape == .Rectangle {
            block_offset.x *= 2
        }

        body_def := box2d.DefaultBodyDef()
        body_def.position = physics.pixels_to_metres(layout_block.position + arena_offset)

        // TODO: Check to see if the block is outside the arena.
        //       If it is, we should print a warning, and delete the block

        shape_def := box2d.DefaultShapeDef()
        shape_def.material.restitution = 1.0
        shape_def.userData             = &blocks[i]
        shape_def.filter.categoryBits  = physics.CATEGORY_BLOCK
        shape_def.filter.maskBits      = physics.CATEGORY_BALL | physics.CATEGORY_PARTICLE

        polygon := _polygons[layout_block.shape][layout_block.scale].(box2d.Polygon)
        body_id := box2d.CreateBody(world_id, body_def)

        blocks[i] = {
            shape    = layout_block.shape,
            scale    = layout_block.scale,
            health   = int(layout_block.scale),
            body_id  = body_id,
            shape_id = box2d.CreatePolygonShape(body_id, shape_def, polygon),
        }
    }

    spell_arena := Spell_Arena {
        blocks   = blocks,
        elements = layout.elements,
    }

    if blocks != nil {
        _add_random_spell_blocks(&spell_arena)

        colour_count := 1

        for count, element in layout.elements {
            if element == .Basic do continue
            if count > 0         do colour_count += 1
        }

        spell_arena.colours    = make([]graphics.Colour, colour_count)
        spell_arena.colours[0] = BLOCK_COLOURS.elements[.Basic]

        index := 1
        for count, element in layout.elements {
            if element == .Basic do continue

            if count > 0 {
                spell_arena.colours[index] = BLOCK_COLOURS.elements[element]
                index += 1
            }
        }
    }

    return spell_arena
}

delete_spell_arena :: proc(spell_arena: Spell_Arena) {
    if spell_arena.blocks != nil {
        for block in spell_arena.blocks {
            // This also destroys the shape, no need to destroy them separately
            box2d.DestroyBody(block.body_id)
        }

        delete(spell_arena.blocks)
        delete(spell_arena.colours)
    }
}

generate_non_overlapping_random_indices :: proc(indices: []int, max_value: int) {
    max_step   := max_value / len(indices)
    last_index := int(rand.uint32()) % max_step

    for &index in indices {
        index        = last_index
        random_step := max(1, int(rand.uint32()) % max_step)
        last_index   = min(last_index + random_step, max_value)
    }

    rand.shuffle(indices)
}

@private _add_random_spell_blocks :: proc(arena: ^Spell_Arena) {
    total_count: int

    for count, element in arena.elements {
        if element == .Basic do continue

        total_count += count
    }

    if total_count > 0 {
        block_count  := len(arena.blocks)
        magic_blocks := min(total_count, block_count)
        indices      := make([]int, magic_blocks, context.temp_allocator)

        generate_non_overlapping_random_indices(indices[:], block_count)

        for count, element in arena.elements {
            if element == .Basic do continue

            for i := magic_blocks - 1; i >= 0; i -= 1 {
                index := indices[i]

                arena.blocks[index].element = element
            }

            magic_blocks -= count
        }
    }
}

restore_spell_arena :: proc(spell_arena: ^Spell_Arena) {
    if spell_arena.blocks != nil {
        spell_arena.disabled = 0

        for &block in spell_arena.blocks {
            box2d.Body_Enable(block.body_id)

            block.element = .Basic
            block.health  = int(block.scale)
        }

        _add_random_spell_blocks(spell_arena)
    }
}

apply_status_effect :: proc(blocks: []Spell_Block, status: Block_Status, count: int) {
    if blocks != nil {
        MAX_ATTEMPTS :: 16

        applied   := 0
        attempted := 0

        for applied != count && attempted != MAX_ATTEMPTS {
            index := int(rand.uint32()) % len(blocks)
            block := &blocks[index]

            if block.health > 0 && block.status == .None {
                block.status = status
                applied     += 1
                attempted    = 0
            } else {
                attempted   += 1
            }
        }
    }
}