package wizard

Character_Stats :: struct {
    name:                   string,
    character:              Character,
    action_points_per_camp: int,
    elements:               Elements,

    // backdrop:
}

Character :: enum {
    Old_Man,
    Twins,
}

CHARACTERS := [Character]Character_Stats {
    .Old_Man = {
        name                   = "Old Man",
        character              = .Old_Man,
        action_points_per_camp = 3,
        elements = #partial {
            .Ice  = 3,
            .Fire = 3,
        }
    },

    .Twins = {
        name                   = "Twins",
        character              = .Twins,
        action_points_per_camp = 2,
        elements = #partial {
            .Poison  = 2,
            .Healing = 2,
        }
    },
}
