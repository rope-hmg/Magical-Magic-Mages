package wizard

import "core:fmt"
import "core:slice"
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
    Frozen,
    Healing,
    Poisoned,
    Burning,
    Charged,
    Electrified,
}

Spell_Block :: struct {
    shape:       Block_Shape,
    element:     Block_Element,
    scale:       Block_Scale,
    status:      Block_Status,
    health:      int,
    arena_index: int, // Don't look
    body_id:     box2d.BodyId,
    shape_id:    box2d.ShapeId,
}

Spell_Arena :: struct {
    disabled:       int,
    enstatused:     int,
    blocks:         []Spell_Block,
    colours:        []graphics.Colour,
    block_counts: Elements,
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
    blocks: []Layout_Block,
}

@private _polygons: [Block_Shape][Block_Scale]Maybe(box2d.Polygon)

make_spell_arena :: proc(
    world_id:     box2d.WorldId,
    arena_layout: Arena_Layout,
    elements:     Elements,
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
        shape_def.material.friction    = 0.0
        shape_def.material.restitution = 1.0
        shape_def.userData             = &blocks[i]
        shape_def.filter.categoryBits  = physics.CATEGORY_BLOCK
        shape_def.filter.maskBits      = physics.CATEGORY_BALL | physics.CATEGORY_PARTICLE

        polygon := _polygons[layout_block.shape][layout_block.scale].(box2d.Polygon)
        body_id := box2d.CreateBody(world_id, body_def)

        blocks[i] = {
            shape       = layout_block.shape,
            scale       = layout_block.scale,
            health      = int(layout_block.scale),
            arena_index = i,
            body_id     = body_id,
            shape_id    = box2d.CreatePolygonShape(body_id, shape_def, polygon),
        }
    }

    spell_arena := Spell_Arena {
        blocks = blocks,
    }

    if blocks != nil {
        _add_random_spell_blocks(&spell_arena, elements)

        colour_count := 1

        for count, element in elements {
            if element == .Basic do continue
            if count > 0         do colour_count += 1
        }

        spell_arena.colours    = make([]graphics.Colour, colour_count)
        spell_arena.colours[0] = BLOCK_COLOURS.elements[.Basic]

        index := 1
        for count, element in elements {
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

disable_block :: proc(arena: ^Spell_Arena, block: ^^Spell_Block) {
    box2d.Body_Disable(block^.body_id)

    // Account for the enstatused blocks when disabling
    if block^.status != .None {
        block^.status     = .None
        arena.enstatused -= 1
    }

    arena.disabled       += 1
    first_disabled_index := len(arena.blocks) - arena.disabled

    _swap_blocks(arena.blocks, block^.arena_index, first_disabled_index)

    // Update the pointer
    block^ = &arena.blocks[first_disabled_index]
}

enable_block :: proc(arena: ^Spell_Arena, block: ^^Spell_Block) {
    box2d.Body_Enable(block^.body_id)

    // Account for the enstatused region
    newly_enabled_index := len(arena.blocks) - arena.disabled - arena.enstatused
    arena.disabled      -= 1

    _swap_blocks(arena.blocks, block^.arena_index, newly_enabled_index)

    // Update the pointer
    block^ = &arena.blocks[newly_enabled_index]
}

enstatus_block :: proc(arena: ^Spell_Arena, block: ^^Spell_Block, status: Block_Status) {
    assert(status != .None, "Use `remove_block_status` to set block.status = .None")

    block^.status = status

    arena.enstatused       += 1
    first_enstatused_index := len(arena.blocks) - arena.disabled - arena.enstatused

    _swap_blocks(arena.blocks, block^.arena_index, first_enstatused_index)

    block^ = &arena.blocks[first_enstatused_index]
}

distatus_block :: proc(arena: ^Spell_Arena, block: ^^Spell_Block) {
    if block^.status != .None {
        block^.status = .None

        newly_distatused_index := len(arena.blocks) - arena.disabled - arena.enstatused
        arena.enstatused       -= 1

        _swap_blocks(arena.blocks, block^.arena_index, newly_distatused_index)

        // Update the pointer
        block^ = &arena.blocks[newly_distatused_index]
    }
}

@private _swap_blocks :: #force_inline proc(blocks: []Spell_Block, i, j: int) {
    if i != j {
        // Swap the blocks
        slice.swap(blocks, i, j)

        // Make sure their indexes are correct
        blocks[i].arena_index = i
        blocks[j].arena_index = j

        // Make sure their userdata pointers are correct
        box2d.Shape_SetUserData(blocks[i].shape_id, &blocks[i])
        box2d.Shape_SetUserData(blocks[j].shape_id, &blocks[j])
    }
}

generate_non_overlapping_random_indices :: proc(indices: []int, array_len: int, array_offset := 0) {
    if array_len > 0 {
        if array_len < len(indices) {
            fmt.println("We shouldn't get here, but if we do... Give me all of them!")

        } else {
            max_step   := array_len / len(indices)
            last_index := rand.int_max(max_step)

            for &index in indices {
                index        = last_index + array_offset
                random_step := max(1, rand.int_max(max_step + 1))
                last_index   = min(last_index + random_step, array_len)
            }
        }
    }
}

@private _add_random_spell_blocks :: proc(arena: ^Spell_Arena, elements: Elements) {
    total_count: int

    for count, element in elements {
        if element == .Basic do continue

        total_count += count
    }

    if total_count > 0 {
        block_count  := len(arena.blocks)
        magic_blocks := min(total_count, block_count)
        indices      := make([]int, magic_blocks, context.temp_allocator)

        generate_non_overlapping_random_indices(indices[:], block_count - arena.disabled)

        rand.shuffle(indices)

        for count, element in elements {
            if element == .Basic do continue

            for i := magic_blocks - 1; i >= 0; i -= 1 {
                index := indices[i]

                arena.blocks[index].element = element
            }

            magic_blocks -= count
        }
    }
}

@private _restore_block :: #force_inline proc(
    block:  ^Spell_Block,
    element: Block_Element = .Basic,
) {
    block.element = element
    block.status  = .None
    block.health  = int(block.scale)
}

restore_spell_arena :: proc(arena: ^Spell_Arena, elements: Elements) {
    if arena.blocks != nil {
        arena.disabled     = 0
        arena.enstatused   = 0
        arena.block_counts = {}

        for &block in arena.blocks {
            box2d.Body_Enable(block.body_id)

            _restore_block(&block)
        }

        _add_random_spell_blocks(arena, elements)
    }
}

enable_n_spell_blocks :: proc(arena: ^Spell_Arena, n: int) -> []^Spell_Block {
    block_count     := min(arena.disabled, n)
    restored_blocks := make([]^Spell_Block, block_count, context.temp_allocator)

    if block_count > 0 {
        indices      := make([]int, block_count, context.temp_allocator)
        offset_point := len(arena.blocks) - arena.disabled

        generate_non_overlapping_random_indices(indices[:], arena.disabled, offset_point)

        missing_elements: bit_set[Block_Element]

        for count, element in arena.block_counts {
            if count < 0 do missing_elements += { element }
        }

        for &index in indices {
            block := &arena.blocks[index]
            enable_block(arena, &block)

            index = block.arena_index

            block_count                 -= 1
            restored_blocks[block_count] = block
        }

        __restore_block :: proc(
            arena:            ^Spell_Arena,
            index:             int,
            element:           Block_Element,
            missing_elements: ^bit_set[Block_Element],
        ) {
            block := &arena.blocks[index]
            _restore_block(block, element)

            arena.block_counts[element] += 1

            if arena.block_counts[element] == 0 {
                missing_elements^ -= { element }
            }
        }

        start := 0

        // Always restore at least one healing block if we can
        if .Healing in missing_elements {
            __restore_block(arena, indices[start], .Healing, &missing_elements)
            start += 1
        }

        for i := start;
            i  < len(indices);
            i += 1
        {
            element, ok := rand.choice_bit_set(missing_elements)
            __restore_block(arena, indices[i], element, &missing_elements)
        }
    }

    return restored_blocks
}

// Applies a status effect to up to n currently active blocks
enstatus_n_spell_blocks :: proc(arena: ^Spell_Arena, status: Block_Status, count: int) {
    distatused_count := len(arena.blocks) - arena.disabled - arena.enstatused
         index_count := min(count, distatused_count)

    if index_count > 0 {
        indices := make([]int, index_count, context.temp_allocator)

        generate_non_overlapping_random_indices(indices[:], distatused_count)

        for i := index_count - 1; i >= 0; i -= 1 {
            index := indices[i]
            block := &arena.blocks[index]

            enstatus_block(arena, &block, status)
        }
    }
}

move_healing_block :: proc(arena: ^Spell_Arena, old_block: ^Spell_Block) {
    if arena.block_counts[.Healing] < 0 {
        placed_healing := false

        for i := 0;
            i < len(arena.blocks) && !placed_healing;
            i += 1
        {
            if i != old_block.arena_index {
                block := &arena.blocks[i]

                if block.element == .Basic {
                    block.element  = .Healing
                    placed_healing = true
                }
            }
        }

        if !placed_healing {
            old_block.element = .Healing
        }

        arena.block_counts[.Healing] += 1
    }
}