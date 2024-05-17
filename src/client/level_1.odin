package client

import "core:math"

import SDL "vendor:sdl2"

Level_1_Data :: struct {}

level_1_load :: proc(level_data: ^Level_1_Data) {}

level_1_unload :: proc(level_data: ^Level_1_Data) {}

level_1_update_and_render :: proc(level_data: ^Level_1_Data, renderer: ^SDL.Renderer) -> ^Stage {
    SDL.SetRenderDrawColor(renderer, 255, 255, 255, 255)

    for e in LEVEL_1_GRAPH.edges {
        from := LEVEL_1_GRAPH.nodes[e.from]
        to   := LEVEL_1_GRAPH.nodes[e.to]

        SDL.RenderDrawLine(renderer, from.x, from.y, to.x, to.y)
    }

    T : f32 : 0.25

    for e in LEVEL_1_GRAPH.edges {
        from := LEVEL_1_GRAPH.nodes[e.from]
        to   := LEVEL_1_GRAPH.nodes[e.to]

        obstacle_rect := SDL.Rect {
            x = i32(math.lerp(f32(from.x), f32(to.x), T)) - 5,
            y = i32(math.lerp(f32(from.y), f32(to.y), T)) - 5,
            w = 10,
            h = 10,
        }

        switch e.obstacle {
            case .None:

            case .Tree:
                SDL.SetRenderDrawColor(renderer, 0,   255, 0,   255)
                SDL.RenderFillRect    (renderer, &obstacle_rect)

            case .Rock:
                SDL.SetRenderDrawColor(renderer, 100, 100, 100, 255)
                SDL.RenderFillRect    (renderer, &obstacle_rect)
        }
    }

    SDL.SetRenderDrawColor(renderer, 0, 255, 0, 255)

    half_size: i32 = 10

    for n in LEVEL_1_GRAPH.nodes {
        node_rect := SDL.Rect {
            x = n.x - half_size,
            y = n.y - half_size,
            w = half_size * 2,
            h = half_size * 2,
        }

        SDL.RenderFillRect(renderer, &node_rect)
    }

    return nil
}

Node_Kind :: enum {
    Boss,
    Camp,
    Field,
    Ruin,
    Spawn,
    Village,
}

Node :: struct {
    kind: Node_Kind,
    x:    i32,
    y:    i32,

    edge: struct {
        offset: i32,
        count:  i32,
    },
}

Obstacle :: enum {
    None,
    Tree,
    Rock,
}

Edge :: struct {
    from:     i32,
    to:       i32,
    obstacle: Obstacle,
}

Graph :: struct {
    nodes: []Node,
    edges: []Edge,
}

//--------------------------------------------------------------
// Level 1 Graph
//--------------------------------------------------------------

//            F2---F5---F8
//            /    |     \
// S0---R1---F3----C6----F9---V11---B12
//            \    |     /
//            F4---F7---F10

LEVEL_1_GRAPH := Graph {
    nodes = {
        { kind = .Spawn,   x = 100, y = 300, edge = { offset = 0,  count = 1  } },
        { kind = .Ruin,    x = 200, y = 300, edge = { offset = 1,  count = 2  } },
        { kind = .Field,   x = 300, y = 250, edge = { offset = 3,  count = 2  } },
        { kind = .Field,   x = 300, y = 300, edge = { offset = 5,  count = 4  } },
        { kind = .Field,   x = 300, y = 350, edge = { offset = 9,  count = 2  } },
        { kind = .Field,   x = 400, y = 250, edge = { offset = 11, count = 3  } },
        { kind = .Camp,    x = 400, y = 300, edge = { offset = 14, count = 4  } },
        { kind = .Field,   x = 400, y = 350, edge = { offset = 18, count = 3  } },
        { kind = .Field,   x = 500, y = 250, edge = { offset = 21, count = 2  } },
        { kind = .Field,   x = 500, y = 300, edge = { offset = 23, count = 4  } },
        { kind = .Field,   x = 500, y = 350, edge = { offset = 27, count = 2  } },
        { kind = .Village, x = 600, y = 300, edge = { offset = 29, count = 2  } },
        { kind = .Boss,    x = 700, y = 300, edge = { offset = 31, count = 1  } },
    },

    edges = {
        { from = 0,  to = 1,  obstacle = .None },
        { from = 1,  to = 0,  obstacle = .None },
        { from = 1,  to = 3,  obstacle = .None },
        { from = 2,  to = 3,  obstacle = .None },
        { from = 2,  to = 5,  obstacle = .None },
        { from = 3,  to = 1,  obstacle = .None },
        { from = 3,  to = 2,  obstacle = .None },
        { from = 3,  to = 4,  obstacle = .None },
        { from = 3,  to = 6,  obstacle = .Rock },
        { from = 4,  to = 3,  obstacle = .None },
        { from = 4,  to = 7,  obstacle = .None },
        { from = 5,  to = 2,  obstacle = .None },
        { from = 5,  to = 6,  obstacle = .None },
        { from = 5,  to = 8,  obstacle = .None },
        { from = 6,  to = 3,  obstacle = .Tree },
        { from = 6,  to = 5,  obstacle = .None },
        { from = 6,  to = 7,  obstacle = .None },
        { from = 6,  to = 9,  obstacle = .None },
        { from = 7,  to = 4,  obstacle = .None },
        { from = 7,  to = 6,  obstacle = .None },
        { from = 7,  to = 10, obstacle = .None },
        { from = 8,  to = 5,  obstacle = .None },
        { from = 8,  to = 9,  obstacle = .None },
        { from = 9,  to = 6,  obstacle = .None },
        { from = 9,  to = 8,  obstacle = .None },
        { from = 9,  to = 10, obstacle = .None },
        { from = 9,  to = 11, obstacle = .None },
        { from = 10, to = 7,  obstacle = .None },
        { from = 10, to = 9,  obstacle = .None },
        { from = 11, to = 9,  obstacle = .None },
        { from = 11, to = 12, obstacle = .None },
        { from = 12, to = 11, obstacle = .None },
    },
}
