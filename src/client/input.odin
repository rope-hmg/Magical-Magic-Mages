package client

import SDL "vendor:sdl2"

Action:: enum {
    Quit,
    Pause,
    Title,
    Level_1,
    Level_2,
    Level_3,
    Ending,
}

Actions :: bit_set[Action]

key_map := map[SDL.Keycode]Action {
    .SPACE = .Pause,
    .NUM0  = .Title,
    .NUM1  = .Level_1,
    .NUM2  = .Level_2,
    .NUM3  = .Level_3,
    .NUM4  = .Ending,
}

Input :: struct {
    c_actions:       Actions,
    p_actions:       Actions,
    cursor_position: SDL.Point,
    cursor_delta:    SDL.Point,
}

handle_events :: proc(input: ^Input) {
    event: SDL.Event
    input.p_actions = input.c_actions

    for SDL.PollEvent(&event) {
        #partial switch event.type {
            case .QUIT: {
                input.c_actions += { .Quit }
            }

            case .KEYDOWN: {
                key := event.key.keysym.sym

                if action, ok := key_map[key]; ok {
                    input.c_actions += { action }
                }
            }

            case .KEYUP: {
                key := event.key.keysym.sym

                if action, ok := key_map[key]; ok {
                    input.c_actions -= { action }
                }
            }

            case .MOUSEMOTION: {
                input.cursor_position = SDL.Point {
                    x = event.motion.x,
                    y = event.motion.y,
                }

                input.cursor_delta = SDL.Point {
                    x = event.motion.xrel,
                    y = event.motion.yrel,
                }
            }
        }
    }
}

just_pressed :: proc(input: Input, action: Action) -> bool {
    return action     in input.c_actions &&
           action not_in input.p_actions
}

just_released :: proc(input: Input, action: Action) -> bool {
    return action not_in input.c_actions &&
           action     in input.p_actions
}

pressed :: proc(input: Input, action: Action) -> bool {
    return action in input.c_actions
}

released :: proc(input: Input, action: Action) -> bool {
    return action not_in input.c_actions
}
