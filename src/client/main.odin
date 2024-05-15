package client

import "core:fmt"
import "core:math/linalg/glsl"
import "core:strings"

import SDL "vendor:sdl2"
import Img "vendor:sdl2/image"
import Mix "vendor:sdl2/mixer"
import Net "vendor:sdl2/net"
import GL  "vendor:OpenGL"

import "../renderer"

SDL_SUCCESS      :: 0
SDL_INIT_FLAGS   :: SDL.INIT_VIDEO | SDL.INIT_AUDIO
MIX_INIT_FLAGS   :: Mix.INIT_OGG   | Mix.INIT_MP3
IMG_INIT_FLAGS   :: Img.INIT_PNG
GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 1

main :: proc() {
    if SDL.Init(SDL_INIT_FLAGS) != SDL_SUCCESS {
        fmt.println("Failed to initialise SDL:")
        fmt.println(SDL.GetError())
    } else {
        defer SDL.Quit()

        if Img.Init(IMG_INIT_FLAGS) != IMG_INIT_FLAGS  {
            fmt.println("Failed to initialise SDL_Image:")
            fmt.println(SDL.GetError())
        } else {
            defer Img.Quit()

            if Mix.Init(MIX_INIT_FLAGS) != i32(MIX_INIT_FLAGS) {
                fmt.println("Failed to initialise SDL_Mixer:")
                fmt.println(SDL.GetError())
            } else {
                defer Mix.Quit()

                Mix.OpenAudio(
                    Mix.DEFAULT_FREQUENCY,
                    Mix.DEFAULT_FORMAT,
                    Mix.DEFAULT_CHANNELS,
                    2048,
                )
                defer Mix.CloseAudio()

                if Net.Init() != 0 {
                    fmt.println("Failed to initialise SDL_Net:")
                    fmt.println(Net.GetError())
                } else {
                    defer Net.Quit()

                    name := get_name()
                    defer delete(name)

                    SETTINGS_RESOLUTION_X :: 800
                    SETTINGS_RESOLUTION_Y :: 600

                    window := SDL.CreateWindow(
                        name,
                        SDL.WINDOWPOS_CENTERED,
                        SDL.WINDOWPOS_CENTERED,
                        SETTINGS_RESOLUTION_X,
                        SETTINGS_RESOLUTION_Y,
                        SDL.WINDOW_SHOWN | SDL.WINDOW_OPENGL
                    )
                    defer SDL.DestroyWindow(window)

                    SDL.GL_SetAttribute(SDL.GLattr.CONTEXT_MAJOR_VERSION, GL_MAJOR_VERSION)
                    SDL.GL_SetAttribute(SDL.GLattr.CONTEXT_MINOR_VERSION, GL_MINOR_VERSION)
                    SDL.GL_SetAttribute(SDL.GLattr.CONTEXT_PROFILE_MASK, i32(SDL.GLprofile.CORE))

                    gl_context := SDL.GL_CreateContext(window)
                    if gl_context == nil {
                        fmt.println("Failed to create OpenGL context:")
                        fmt.println(SDL.GetError())
                    } else {
                        defer SDL.GL_DeleteContext(gl_context)

                        GL.load_up_to(GL_MAJOR_VERSION, GL_MINOR_VERSION, SDL.gl_set_proc_address)
                        GL.ClearColor(0.3, 0.2, 0.1, 1.0)

                        SDL.GL_MakeCurrent(window, gl_context)

                        if SDL.GL_SetSwapInterval(1) != SDL_SUCCESS {
                            fmt.println("Warning: Unable to set VSync!")
                            fmt.println(SDL.GetError())
                        }

                        input  := Input  {}
                        assets := Assets {}

                                load_assets(&assets)
                        defer unload_assets(&assets)

                        game := Game {
                            is_running = true,
                            name       = name,
                            this_stage = Stage.Title,
                            next_stage = Stage.Title,
                            camera     = renderer.Camera {
                                projection = glsl.mat4Ortho3d(
                                    0.0,
                                    SETTINGS_RESOLUTION_X,
                                    0.0,
                                    SETTINGS_RESOLUTION_Y,
                                    0.1,
                                    1000.0,
                                ),
                            },
                            renderer = renderer.Renderer {
                                variant = renderer.Quad_Batch_Renderer {}
                            },
                        }

                              renderer.render_init   (&game.renderer, "src/renderer/basic")
                        defer renderer.render_destroy(&game.renderer)


                        for game.is_running {
                            width:  i32
                            height: i32
                            SDL.GL_GetDrawableSize(window, &width, &height)
                            GL.Viewport(0, 0, width, height)
                            GL.Clear(GL.COLOR_BUFFER_BIT)

                            handle_events(&input)
                            update_and_render(&game, input, assets)

                            SDL.GL_SwapWindow(window)

                            if pressed(input, .Quit) {
                                game.is_running = false
                            }
                        }
                    }
                }
            }
        }
    }
}

Assets :: struct {
    title:   ^Mix.Music,
    level_1: ^Mix.Music,
    level_2: ^Mix.Music,
    level_3: ^Mix.Music,
    ending:  ^Mix.Music,
    gliphs:  ^SDL.Surface,
}

load_assets :: proc(assets: ^Assets) {
    assert(assets != nil)

    assets.title   = Mix.LoadMUS("assets/music/Title Screen.wav")
    assets.level_1 = Mix.LoadMUS("assets/music/Level 1.wav")
    assets.level_2 = Mix.LoadMUS("assets/music/Level 2.wav")
    assets.level_3 = Mix.LoadMUS("assets/music/Level 3.wav")
    assets.ending  = Mix.LoadMUS("assets/music/Ending.wav")
    assets.gliphs  = Img.Load("assets/sprites/gliphs-outlined.png")
}

unload_assets :: proc(assets: ^Assets) {
    assert(assets != nil)

    Mix.FreeMusic(assets.title)
    Mix.FreeMusic(assets.level_1)
    Mix.FreeMusic(assets.level_2)
    Mix.FreeMusic(assets.level_3)
    Mix.FreeMusic(assets.ending)
    SDL.FreeSurface(assets.gliphs)
}

Stage :: enum {
    Title,
    Credits,
    Level_1,
    Level_2,
    Level_3,
    Ending,
}

Game :: struct {
    is_running: bool,
    name:       cstring,
    this_stage: Stage,
    next_stage: Stage,
    camera:     renderer.Camera,
    renderer:   renderer.Renderer,
}

music_channel: i32 = 0

play_music :: proc(track: ^Mix.Music) {
    if Mix.PlayingMusic() == 0 {
        Mix.PlayMusic(track, -1)
    }
}

update_and_render :: proc(game: ^Game, input: Input, assets: Assets) {
    assert(game != nil)

    if just_pressed(input, .Title)   { game.next_stage = .Title   }
    if just_pressed(input, .Level_1) { game.next_stage = .Level_1 }
    if just_pressed(input, .Level_2) { game.next_stage = .Level_2 }
    if just_pressed(input, .Level_3) { game.next_stage = .Level_3 }
    if just_pressed(input, .Ending)  { game.next_stage = .Ending  }

    if game.this_stage != game.next_stage {
        Mix.FadeOutMusic(150)
        game.this_stage = game.next_stage
    }

    // TEMP (combat)
    // END TEMP

    renderer.render_begin(&game.renderer)

    // for y := 0; y < 10; y += 1 {
    //     for x := 0; x < 10; x += 1 {
    //         renderer.quad_batch_push_quad(
    //             &game.renderer,
    //             glsl.vec2 { f32(x * 10), f32(y * 10) },
    //             glsl.vec2 { 10, 10 },
    //             renderer.WHITE,
    //         )
    //     }
    // }

    switch game.this_stage {
        case .Title:
            play_music(assets.title)

        case .Credits:
            play_music(assets.title)
            // Music: Juhani Junkala

        case .Level_1:
            play_music(assets.level_1)

        case .Level_2:
            play_music(assets.level_2)

        case .Level_3:
            play_music(assets.level_3)

        case .Ending:
            play_music(assets.ending)
    }

    renderer.render_flush(&game.renderer, game.camera)
}
