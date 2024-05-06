package main

import "core:fmt"
import "core:strings"

import SDL       "vendor:sdl2"
import SDL_Image "vendor:sdl2/image"
import SDL_Mixer "vendor:sdl2/mixer"
import SDL_Net   "vendor:sdl2/net"
import GL        "vendor:OpenGL"

SDL_SUCCESS :: 0
 INIT_FLAGS :: SDL.INIT_VIDEO     | SDL.INIT_AUDIO
MIXER_FLAGS :: SDL_Mixer.INIT_OGG | SDL_Mixer.INIT_MP3
IMAGE_FLAGS :: SDL_Image.INIT_PNG

GL_MAJOR_VERSION :: 3
GL_MINOR_VERSION :: 3

main :: proc() {
    if SDL.Init(INIT_FLAGS) != SDL_SUCCESS {
        fmt.println("Failed to initialise SDL:")
        fmt.println(SDL.GetError())
    } else {
        defer SDL.Quit()

        if SDL_Image.Init(IMAGE_FLAGS) != IMAGE_FLAGS  {
            fmt.println("Failed to initialise SDL_Image:")
            fmt.println(SDL.GetError())
        } else {
            defer SDL_Image.Quit()

            if SDL_Mixer.Init(MIXER_FLAGS) != i32(MIXER_FLAGS) {
                fmt.println("Failed to initialise SDL_Mixer:")
                fmt.println(SDL.GetError())
            } else {
                defer SDL_Mixer.Quit()

                SDL_Mixer.OpenAudio(
                    SDL_Mixer.DEFAULT_FREQUENCY,
                    SDL_Mixer.DEFAULT_FORMAT,
                    SDL_Mixer.DEFAULT_CHANNELS,
                    2048,
                )
                defer SDL_Mixer.CloseAudio()

                if SDL_Net.Init() != 0 {
                    fmt.println("Failed to initialise SDL_Net:")
                    fmt.println(SDL_Net.GetError())
                } else {
                    defer SDL_Net.Quit()

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
                        is_close_requested := false

                        for !is_close_requested {
                            event: SDL.Event

                            for SDL.PollEvent(&event) {
                                #partial switch event.type {
                                    case .QUIT: {
                                        is_close_requested = true
                                    }
                                }
                            }

                            GL.Clear(GL.COLOR_BUFFER_BIT)
                            SDL.GL_SwapWindow(window)
                        }
                    }
                }
            }
        }
    }
}
