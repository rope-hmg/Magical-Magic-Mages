package client


import SDL "vendor:sdl2"
import Mix "vendor:sdl2/mixer"

Stage_Id :: enum {
    Loading,
    Title,
    Credits,
    Level_1,
    Level_2,
    Level_3,
    Ending,
}

Loading_Data :: struct {}

loading_load :: proc(loading_data: ^Loading_Data) {}
loading_unload :: proc(loading_data: ^Loading_Data) {}
loading_update_and_render :: proc(loading_data: ^Loading_Data, assets: Assets) -> ^Stage {
    Stage_Title  .music = assets.title
    Stage_Credits.music = assets.title
    Stage_Level_1.music = assets.level_1
    Stage_Level_2.music = assets.level_2
    Stage_Level_3.music = assets.level_3
    Stage_Ending .music = assets.ending
    return &Stage_Title
}

Credits_Data :: struct {
// Music: Juhani Junkala
}

credits_load :: proc(credits_data: ^Credits_Data) {}
credits_unload :: proc(credits_data: ^Credits_Data) {}
credits_update_and_render :: proc(credits_data: ^Credits_Data) -> ^Stage { return nil }

Level_1_Data :: struct {}

level_1_load :: proc(level_data: ^Level_1_Data) {}
level_1_unload :: proc(level_data: ^Level_1_Data) {}
level_1_update_and_render :: proc(level_data: ^Level_1_Data) -> ^Stage { return nil }

Level_2_Data :: struct {}

level_2_load :: proc(level_data: ^Level_2_Data) {}
level_2_unload :: proc(level_data: ^Level_2_Data) {}
level_2_update_and_render :: proc(level_data: ^Level_2_Data) -> ^Stage { return nil }

Level_3_Data :: struct {}

level_3_load :: proc(level_data: ^Level_3_Data) {}
level_3_unload :: proc(level_data: ^Level_3_Data) {}
level_3_update_and_render :: proc(level_data: ^Level_3_Data) -> ^Stage { return nil }

Ending_Data :: struct {}

ending_load :: proc(ending_data: ^Ending_Data) {}
ending_unload :: proc(ending_data: ^Ending_Data) {}
ending_update_and_render :: proc(ending_data: ^Ending_Data) -> ^Stage { return nil }

Stage_Data :: union {
    Loading_Data,
    Title_Data,
    Credits_Data,
    Level_1_Data,
    Level_2_Data,
    Level_3_Data,
    Ending_Data,
}

Stage :: struct {
    id:     Stage_Id,
    music: ^Mix.Music,
    data:   Stage_Data,
}

Stage_Loading := Stage { id = .Loading, data = Loading_Data {} }
Stage_Title   := Stage { id = .Title,   data = Title_Data   {} }
Stage_Credits := Stage { id = .Credits, data = Credits_Data {} }
Stage_Level_1 := Stage { id = .Level_1, data = Level_1_Data {} }
Stage_Level_2 := Stage { id = .Level_2, data = Level_2_Data {} }
Stage_Level_3 := Stage { id = .Level_3, data = Level_3_Data {} }
Stage_Ending  := Stage { id = .Ending,  data = Ending_Data  {} }

stage_load :: proc(stage: ^Stage, game: Game) {
    switch stage.id {
        case .Loading: loading_load(auto_cast &stage.data)
        case .Title:     title_load(auto_cast &stage.data, game.name)
        case .Credits: credits_load(auto_cast &stage.data)
        case .Level_1: level_1_load(auto_cast &stage.data)
        case .Level_2: level_2_load(auto_cast &stage.data)
        case .Level_3: level_3_load(auto_cast &stage.data)
        case .Ending:   ending_load(auto_cast &stage.data)
    }
}

stage_unload :: proc(stage: ^Stage) {
    switch stage.id {
        case .Loading: loading_unload(auto_cast &stage.data)
        case .Title:     title_unload(auto_cast &stage.data)
        case .Credits: credits_unload(auto_cast &stage.data)
        case .Level_1: level_1_unload(auto_cast &stage.data)
        case .Level_2: level_2_unload(auto_cast &stage.data)
        case .Level_3: level_3_unload(auto_cast &stage.data)
        case .Ending:   ending_unload(auto_cast &stage.data)
    }
}

stage_update_and_render :: proc(stage: ^Stage, renderer: ^SDL.Renderer, game: Game, input: Input, assets: Assets) -> ^Stage {
    next_stage: ^Stage

    switch stage.id {
        case .Loading: next_stage = loading_update_and_render(auto_cast &stage.data, assets)
        case .Title:   next_stage =   title_update_and_render(auto_cast &stage.data, renderer, assets)
        case .Credits: next_stage = credits_update_and_render(auto_cast &stage.data)
        case .Level_1: next_stage = level_1_update_and_render(auto_cast &stage.data)
        case .Level_2: next_stage = level_2_update_and_render(auto_cast &stage.data)
        case .Level_3: next_stage = level_3_update_and_render(auto_cast &stage.data)
        case .Ending:  next_stage =  ending_update_and_render(auto_cast &stage.data)
    }

    if just_pressed(input, .Title)   { next_stage = &Stage_Title   }
    if just_pressed(input, .Level_1) { next_stage = &Stage_Level_1 }
    if just_pressed(input, .Level_2) { next_stage = &Stage_Level_2 }
    if just_pressed(input, .Level_3) { next_stage = &Stage_Level_3 }
    if just_pressed(input, .Ending)  { next_stage = &Stage_Ending  }

    return next_stage
}
