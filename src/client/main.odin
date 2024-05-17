package client

import "core:fmt"
import "core:math/linalg/glsl"

import SDL "vendor:sdl2"
import Img "vendor:sdl2/image"
import Mix "vendor:sdl2/mixer"
import Net "vendor:sdl2/net"

SDL_SUCCESS      :: 0
SDL_INIT_FLAGS   :: SDL.INIT_VIDEO | SDL.INIT_AUDIO
MIX_INIT_FLAGS   :: Mix.INIT_OGG   | Mix.INIT_MP3
IMG_INIT_FLAGS   :: Img.INIT_PNG
GL_MAJOR_VERSION :: 4
GL_MINOR_VERSION :: 1
RESOLUTION_X     :: 800
RESOLUTION_Y     :: 600

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

                    window:   ^SDL.Window
                    renderer: ^SDL.Renderer

                    if     create_window_and_renderer(&window, &renderer, name) {
                    defer destroy_window_and_renderer(&window, &renderer)
                        input  := Input  {}
                        assets := Assets {}

                                load_assets(&assets, renderer)
                        defer unload_assets(&assets)

                        game := Game {
                            is_running = true,
                            name       = name,
                            stage      = &Stage_Loading,
                            // camera     = renderer.Camera {
                            //     projection = glsl.mat4Ortho3d(
                            //         0.0,
                            //         RESOLUTION_X,
                            //         0.0,
                            //         RESOLUTION_Y,
                            //         0.1,
                            //         1000.0,
                            //     ),
                            // },
                        }

                        stage_load(game.stage, game, assets)

                        for game.is_running {
                            SDL.SetRenderDrawColor(renderer, 0, 0, 0, 0)
                            SDL.RenderClear(renderer)

                            handle_events(&input)
                            update_and_render(renderer, &game, input, assets)

                            SDL.RenderPresent(renderer)

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

create_window_and_renderer :: proc(window: ^^SDL.Window, renderer: ^^SDL.Renderer, name: cstring) -> bool {
    assert(window   != nil)
    assert(renderer != nil)

    success := false

    window^ = SDL.CreateWindow(
        name,
        SDL.WINDOWPOS_CENTERED,
        SDL.WINDOWPOS_CENTERED,
        RESOLUTION_X,
        RESOLUTION_Y,
        SDL.WINDOW_SHOWN
    )

    if window^ == nil {
        fmt.println("Failed to open a window:")
        fmt.println(SDL.GetError())
    } else {
        DRIVER_INDEX :: -1

        renderer^ = SDL.CreateRenderer(
            window^,
            DRIVER_INDEX,
            SDL.RENDERER_ACCELERATED | SDL.RENDERER_PRESENTVSYNC
        )

        if renderer^ == nil {
            fmt.println("Failed to open a rendering context:")
            fmt.println(SDL.GetError())
        } else {
            success = true
        }
    }

    return success
}

destroy_window_and_renderer :: proc(window: ^^SDL.Window, renderer: ^^SDL.Renderer) {
    SDL.DestroyRenderer(renderer^)
    SDL.DestroyWindow  (window^  )
}

Assets :: struct {
    title:   ^Mix.Music,
    level_1: ^Mix.Music,
    level_2: ^Mix.Music,
    level_3: ^Mix.Music,
    ending:  ^Mix.Music,
    glyphs:  ^SDL.Texture,
    fancy:   ^SDL.Texture,
}

load_assets :: proc(assets: ^Assets, renderer: ^SDL.Renderer) {
    assert(assets != nil)

    assets.title   = Mix.LoadMUS("assets/music/Title Screen.wav")
    assets.level_1 = Mix.LoadMUS("assets/music/Level 1.wav")
    assets.level_2 = Mix.LoadMUS("assets/music/Level 2.wav")
    assets.level_3 = Mix.LoadMUS("assets/music/Level 3.wav")
    assets.ending  = Mix.LoadMUS("assets/music/Ending.wav")
    assets.glyphs  = Img.LoadTexture(renderer, "assets/sprites/gliphs-outlined.png")
    assets.fancy   = Img.LoadTexture(renderer, "assets/sprites/fancy-font.png")
}

unload_assets :: proc(assets: ^Assets) {
    assert(assets != nil)

    Mix.FreeMusic(assets.title)
    Mix.FreeMusic(assets.level_1)
    Mix.FreeMusic(assets.level_2)
    Mix.FreeMusic(assets.level_3)
    Mix.FreeMusic(assets.ending)
    SDL.DestroyTexture(assets.glyphs)
    SDL.DestroyTexture(assets.fancy)
}

Game :: struct {
    is_running: bool,
    name:       cstring,
    stage:      ^Stage,
}

update_and_render :: proc(renderer: ^SDL.Renderer, game: ^Game, input: Input, assets: Assets) {
    assert(game       != nil)
    assert(game.stage != nil)

    if Mix.PlayingMusic() == 0 && game.stage.music != nil {
        Mix.PlayMusic(game.stage.music, -1)
    }

    next_stage := stage_update_and_render(game.stage, renderer, game^, input, assets)

    if next_stage != nil &&
       next_stage != game.stage
    {
        stage_unload(game.stage)
        stage_load  (next_stage, game^, assets)

        if game.stage.music != next_stage.music {
            Mix.FadeOutMusic(150)
        }

        game.stage = next_stage
    }
}
