package renderer

import "core:fmt"
import "core:math/bits"
import "core:strings"

import SDL "vendor:sdl2"
import GL  "vendor:OpenGL"

@private create_shader :: proc(shader_type: u32, shader_path: string, extension: string) -> u32 {
    shader: u32  = 0
    shader_path := strings.concatenate({ shader_path, extension, "\x00" })
    defer delete(shader_path)

    file_size: uint
    file_name := strings.unsafe_string_to_cstring(shader_path)
    file_data := SDL.LoadFile(rawptr(file_name), &file_size)

    if file_data == nil {
        fmt.println("Failed to load shader file:", shader_path)
        fmt.println(SDL.GetError())
    } else {
        defer SDL.free(file_data)

        assert(file_size > 0)
        assert(file_size < bits.I32_MAX)
        shader = GL.CreateShader(shader_type)
        file_size :=     i32(file_size)
        file_data := cstring(file_data)

        GL.ShaderSource (shader, 1, &file_data, &file_size)
        GL.CompileShader(shader)

        error_message := strings.concatenate({ "Shader compilation failed for: ", shader_path, " with error:" })
        status_is_good(
            shader,
            GL.COMPILE_STATUS,
            GL.GetShaderiv,
            GL.GetShaderInfoLog,
            error_message,
        )
    }

    return shader
}

@private Get_Fn :: proc "c" (object: u32, param_name:  u32,               params:  [^]i32, loc := #caller_location)
@private Log_Fn :: proc "c" (object: u32, buffer_size: i32, length: ^i32, infoLog: [^]u8,  loc := #caller_location)

@private status_is_good :: proc(
    object:  u32,
    status:  u32,
    get_fn:  Get_Fn,
    log_fn:  Log_Fn,
    message: string,
) -> bool {
    success: i32
    get_fn(object, status, &success)

    if success == 0 {
        info_size: i32
        get_fn(object, GL.INFO_LOG_LENGTH, &info_size)

        info_log := make([]u8, info_size + 1)
        defer delete(info_log)

        log_fn(object, info_size, nil, raw_data(info_log))

        fmt.println(message, transmute(string) info_log)
    }

    return bool(success)
}
