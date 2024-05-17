package client

import SDL "vendor:sdl2"

Action:: enum {
    Quit,
    Pause,
    Key_Select,
    Mouse_Select,
    Menu_Up,
    Menu_Down,
}

Actions :: bit_set[Action]

key_map := map[SDL.Keycode]Action {
    .SPACE  = .Pause,
    .RETURN = .Key_Select,

    .UP     = .Menu_Up,
    .DOWN   = .Menu_Down,
    .W      = .Menu_Up,
    .S      = .Menu_Down,
}

btn_map := map[u8]Action {
    SDL.BUTTON_LEFT   = .Mouse_Select,
    SDL.BUTTON_MIDDLE = .Mouse_Select,
    SDL.BUTTON_RIGHT  = .Mouse_Select,
    SDL.BUTTON_X1     = .Mouse_Select,
    SDL.BUTTON_X2     = .Mouse_Select,
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
