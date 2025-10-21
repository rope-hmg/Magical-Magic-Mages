package platform

import "core:math/linalg/glsl"
import "core:fmt"

import "vendor:sdl3"
import "vendor:sdl3/ttf"

Platform :: struct {
    window:       ^sdl3.Window,
    width:         i32,
    height:        i32,
    renderer:     ^sdl3.Renderer,
    audio_device:  sdl3.AudioDeviceID,
    output_format: sdl3.AudioSpec,
    text_engine:  ^ttf.TextEngine,
    mouse:         Mouse,
    running:       bool,
    delta_seconds: f32,
}

run_app :: proc(
    app_name:          cstring,
    game:              ^$Game,
    init:              proc(p: ^Platform, g: ^Game),
    quit:              proc(p: ^Platform, g: ^Game),
    handle_event:      proc(p: ^Platform, g: ^Game, e: sdl3.Event),
    update_and_render: proc(p: ^Platform, g: ^Game),
) {
    if !sdl3.Init({ .VIDEO, .EVENTS, .AUDIO }) {
        fmt.println("Failed to initialise subsystems:")
        fmt.println(sdl3.GetError())
    } else {
        if !ttf.Init() {
            fmt.println("Unable to initialise SDL_TTF")
            fmt.println(sdl3.GetError())
        } else {
            platform := Platform {
                width  = 1152,
                height = 864,

                // TODO: Maybe need to have a `desired_audio_spec`
                audio_device = sdl3.OpenAudioDevice(sdl3.AUDIO_DEVICE_DEFAULT_PLAYBACK, nil),
            }

            if platform.audio_device == 0 {
                fmt.println("Unable to open audio device:")
                fmt.println(sdl3.GetError())
            } else {
                defer sdl3.CloseAudioDevice(platform.audio_device)

                sdl3.GetAudioDeviceFormat(platform.audio_device, &platform.output_format, nil)

                if !sdl3.CreateWindowAndRenderer(
                    app_name, platform.width, platform.height, {},
                    &platform.window,
                    &platform.renderer,
                ) {
                    fmt.println("Unable to open window and create graphics context:")
                    fmt.println(sdl3.GetError())
                } else {
                    defer sdl3.DestroyRenderer(platform.renderer)
                    defer sdl3.DestroyWindow  (platform.window)

                    platform.text_engine = ttf.CreateRendererTextEngine(platform.renderer)

                    defer if platform.text_engine != nil {
                        ttf.DestroyRendererTextEngine(platform.text_engine)
                    }

                    // Time Tracking
                    // =============

                    display_id   := sdl3.GetDisplayForWindow  (platform.window)
                    display_mode := sdl3.GetCurrentDisplayMode(display_id)
                    refresh_rate := display_mode.refresh_rate

                    platform.delta_seconds = 1 / (refresh_rate == 0 ? 60 : refresh_rate)

                    // Sync RenderPresent with every vertical refresh
                    if !sdl3.SetRenderVSync(platform.renderer, 1) {
                        fmt.println("Failed to set vysnc")
                    }

                    // Intialisation
                    // =============

                          init(&platform, game)
                    defer quit(&platform, game)

                    // Main Loop
                    // =========

                    platform.running = true
                    frame_tick      := sdl3.GetTicks()

                    for platform.running {
                        platform.mouse.previous = platform.mouse.current

                        event: sdl3.Event

                        for sdl3.PollEvent(&event) {
                            #partial switch event.type {
                                case .QUIT: platform.running = false

                                case .MOUSE_MOTION:      _update_mouse_position(&platform.mouse, event.motion)
                                case .MOUSE_BUTTON_UP:   _update_mouse_buttons (&platform.mouse, event.button)
                                case .MOUSE_BUTTON_DOWN: _update_mouse_buttons (&platform.mouse, event.button)
                            }

                            handle_event(&platform, game, event)
                        }

                        update_and_render(&platform, game)

                        sdl3.SetRenderDrawColor(platform.renderer, 0, 0, 0, 255)
                        sdl3.RenderPresent(platform.renderer)
                        sdl3.RenderClear  (platform.renderer)

                        free_all(context.temp_allocator)

                        new_tick              := sdl3.GetTicks()
                        platform.delta_seconds = cast(f32) (new_tick - frame_tick) / 1000.0
                        frame_tick             =            new_tick
                    }
                }
            }
        }
    }
}

// ----------------------------------------------
// Input
// ----------------------------------------------


Key :: sdl3.Scancode

Button  :: enum { Left, Right }
Buttons :: bit_set[Button]

Mouse_Instance :: struct {
    position: glsl.vec2,
    buttons:  Buttons,

}

Mouse :: struct {
    current:  Mouse_Instance,
    previous: Mouse_Instance,
}

@private _update_mouse_position :: #force_inline proc(m: ^Mouse, e: sdl3.MouseMotionEvent) {
    m.current.position.x = e.x
    m.current.position.y = e.y
}

@private _update_mouse_buttons :: #force_inline proc(m: ^Mouse, e: sdl3.MouseButtonEvent) {
    button: Button

    if e.button == sdl3.BUTTON_LEFT  { button = .Left  }
    if e.button == sdl3.BUTTON_RIGHT { button = .Right }

    if e.down { m.current.buttons += { button } }
    else      { m.current.buttons -= { button } }

}

mouse_position :: #force_inline proc(m: Mouse) -> glsl.vec2 { return m.current.position }
mouse_delta    :: #force_inline proc(m: Mouse) -> glsl.vec2 { return m.current.position - m.previous.position }

button_held     :: #force_inline proc(m: Mouse, b: Button) -> bool { return b     in m.current.buttons }
button_pressed  :: #force_inline proc(m: Mouse, b: Button) -> bool { return b     in m.current.buttons && b not_in m.previous.buttons }
button_released :: #force_inline proc(m: Mouse, b: Button) -> bool { return b not_in m.current.buttons && b     in m.previous.buttons }


// ----------------------------------------------
// Audio
// ----------------------------------------------

Audio :: struct {
    format:  sdl3.AudioSpec,
    stream: ^sdl3.AudioStream,

    buffer_data: [^]u8,
    buffer_len:  i32,
}

load_wav :: proc(
    path:           cstring,
    output_device:  sdl3.AudioDeviceID,
    output_format: ^sdl3.AudioSpec,
) -> Audio {
    audio_format: sdl3.AudioSpec
    buffer_data:  [^]u8
    buffer_len:   u32

    sdl3.LoadWAV(path, &audio_format, &buffer_data, &buffer_len)

    audio_stream := sdl3.CreateAudioStream(&audio_format, output_format)

    sdl3.BindAudioStream(output_device, audio_stream)

    return {
        format      = audio_format,
        stream      = audio_stream,
        buffer_data = buffer_data,
        buffer_len  = i32(buffer_len),
    }
}

play_sound :: #force_inline proc(sound: Audio) {
    sdl3.PutAudioStreamData(sound.stream, sound.buffer_data, sound.buffer_len)
}
