package main

import "core:fmt"
import "core:strings"

import SDL "vendor:sdl2"
import Img "vendor:sdl2/image"
import Mix "vendor:sdl2/mixer"
import Net "vendor:sdl2/net"
import GL  "vendor:OpenGL"

SDL_SUCCESS      :: 0
SDL_INIT_FLAGS   :: SDL.INIT_VIDEO | SDL.INIT_AUDIO
MIX_INIT_FLAGS   :: Mix.INIT_OGG   | Mix.INIT_MP3
IMG_INIT_FLAGS   :: Img.INIT_PNG
GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

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

                    window := SDL.CreateWindow(
                        name,
                        SDL.WINDOWPOS_CENTERED,
                        SDL.WINDOWPOS_CENTERED,
                        800,// settings.resolution_x,
                        600,// settings.resolution_y,
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
                        GL.ClearColor(0.1, 0.2, 0.3, 1.0)

                        SDL.GL_MakeCurrent(window, gl_context)

                        if SDL.GL_SetSwapInterval(1) != SDL_SUCCESS {
                            fmt.println("Warning: Unable to set VSync!")
                            fmt.println(SDL.GetError())
                        }

                        fmt.println("Hello,", name)

                        game := Game {
                            is_running = true,
                            name       = name,
                            this_stage = Stage.Title,
                            next_stage = Stage.Title,
                        }

                        input  := Input  {}
                        assets := Assets {}

                                load_assets(&assets)
                        defer unload_assets(&assets)

                        for game.is_running {
                            event: SDL.Event

                            for SDL.PollEvent(&event) {
                                #partial switch event.type {
                                    case .QUIT: {
                                        game.is_running = false
                                    }

                                    case .KEYDOWN: {
                                        key := event.key.keysym.sym

                                        if key == .NUM0 { game.next_stage = .Title   }
                                        if key == .NUM1 { game.next_stage = .Level_1 }
                                        if key == .NUM2 { game.next_stage = .Level_2 }
                                        if key == .NUM3 { game.next_stage = .Level_3 }
                                        if key == .NUM4 { game.next_stage = .Ending  }
                                    }
                                }
                            }

                            update_and_render(&game, input, assets)

                            GL.Clear(GL.COLOR_BUFFER_BIT)
                            SDL.GL_SwapWindow(window)
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
}

Input :: struct {

}

music_channel: i32 = 0

play_music :: proc(track: ^Mix.Music) {
    if Mix.PlayingMusic() == 0 {
        Mix.PlayMusic(track, -1)
    }
}

update_and_render :: proc(game: ^Game, input: Input, assets: Assets) {
    assert(game != nil)

    if game.this_stage != game.next_stage {
        Mix.FadeOutMusic(150)
        game.this_stage = game.next_stage
    }

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
}
