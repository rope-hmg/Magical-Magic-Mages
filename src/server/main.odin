package server

import "core:fmt"

import SDL "vendor:sdl2"
import Net "vendor:sdl2/net"

SDL_SUCCESS     :: 0
SDL_INIT_FLAGS  :: SDL.INIT_TIMER | SDL.INIT_EVENTS
MAX_CLIENTS     :: 4
MAX_PACKET_SIZE :: 0xFF

Client :: struct {
    in_use: bool,
    socket: Net.TCPsocket,
}

main :: proc() {
    if SDL.Init(SDL_INIT_FLAGS) != SDL_SUCCESS {
        fmt.println("Failed to initialise SDL:")
        fmt.println(SDL.GetError())
    } else {
        defer SDL.Quit()

        if Net.Init() != 0 {
            fmt.println("Failed to initialise SDL_Net:")
            fmt.println(Net.GetError())
        } else {
            defer Net.Quit()

            ip: Net.IPaddress
            if Net.ResolveHost(&ip, nil, 25006) != 0 {
                fmt.println("Failed to resolve host:")
                fmt.println(Net.GetError())
            } else {

                server_socket := Net.TCP_Open(&ip)
                if server_socket == nil {
                    fmt.println("Failed to open socket:")
                    fmt.println(Net.GetError())
                } else {
                    defer Net.TCP_Close(server_socket)

                    clients: [MAX_CLIENTS]Client

                    is_running := true

                    for is_running {
                        handle_events()
                        update(server_socket, &clients)
                    }

                    clean_up_clients(clients)
                }
            }
        }
    }
}

clean_up_clients :: proc(clients: [MAX_CLIENTS]Client) {
    for client in clients {
        if client.in_use {
            Net.TCP_Close(client.socket)
        }
    }
}

handle_events :: proc() {
    event: SDL.Event

    for SDL.PollEvent(&event) {
        #partial switch event.type {
            case .QUIT: {
                is_running = false
            }
        }
    }
}

update :: proc(server_socket: Net.TCPsocket, clients: ^[MAX_CLIENTS]Client) {
    if Net.SocketReady(server_socket) {
        max_clients_reached := true

        for &client in clients {
            if !client.in_use {
                client_socket := Net.TCP_Accept(server_socket)

                if client_socket == nil {
                    fmt.println("Failed to accept client:")
                    fmt.println(Net.GetError())
                } else {
                    client.in_use = true
                    client.socket = client_socket
                    max_clients_reached = false
                }

                break
            }
        }

        if max_clients_reached {
            fmt.println("Could not accept connection! Max clients reached")
        }
    }

    for client in clients {
        if client.in_use {
            if Net.SocketReady(client.socket) {
                fmt.println("Client ready to receive data")


                // packet := [MAX_PACKET_SIZE]byte
                // packet_len := Net.TCP_Recv(client.socket, &packet, MAX_PACKET_SIZE)

                // if packet_len <= 0 {
                //     fmt.println("Client disconnected")
                //     client.in_use = false
                // } else {
                //     fmt.println("Received packet:")
                //     fmt.println(packet)
                // }
            }
        }
    }
}
