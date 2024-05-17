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
    Select,
}

Actions :: bit_set[Action]

key_map := map[SDL.Keycode]Action {
    .NUM0  = .Title,
    .NUM1  = .Level_1,
    .NUM2  = .Level_2,
    .NUM3  = .Level_3,
    .NUM4  = .Ending,
    .SPACE  = .Pause,
    .RETURN = .Select,
}

btn_map := map[u8]Action {
    SDL.BUTTON_LEFT   = .Select,
    SDL.BUTTON_MIDDLE = .Select,
    SDL.BUTTON_RIGHT  = .Select,
    SDL.BUTTON_X1     = .Select,
    SDL.BUTTON_X2     = .Select,
}

Input :: struct {
    c_actions:       Actions,
    p_actions:       Actions,
    cursor_position: SDL.Point,
    cursor_delta:    SDL.Point,
    clicks:          u8,
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

            case .MOUSEBUTTONDOWN: {
                input.clicks = event.button.clicks
                button      := event.button.button

                if action, ok := btn_map[button]; ok {
                    input.c_actions += { action }
                }
            }

            case .MOUSEBUTTONUP: {
                input.clicks = event.button.clicks
                button      := event.button.button

                if action, ok := btn_map[button]; ok {
                    input.c_actions -= { action }
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
