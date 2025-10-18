package adventure

DRAGON_ADVENTURE := []Stage {
    //  0: Spider
    {
        arena_layout_data = #load("./layouts/dragon_adventure_spider.json"),
        name              = "Forbidden Forest",

        enemy_health = 3,
        environment  = .Forest,

        elements = #partial {
            .Electric = 2,
        },

        next_stage = 1,
    },

    // 1: Skeleton
    {
        arena_layout_data = #load("./layouts/dragon_adventure_skeleton.json"),
        name              = "Forgotten Ruins",

        enemy_health = 100,
        environment  = .Forest_Ruins,

        elements = #partial {
            .Healing = 2,
        },

        next_stage = 2,
    },

    //  2: Giant Toad Boss
    {
        arena_layout_data = #load("./layouts/dragon_adventure_toad.json"),
        name              = "The Deep Forest",

        enemy_health = 100,
        is_boss      = true,
        environment  = .Deep_Forest,

        elements = #partial {
            .Healing = 2,
            .Poison  = 4,
        },

        next_stage = 3,
    },

    // 3: Wolf
    {
        arena_layout_data = #load("./layouts/dragon_adventure_wolf.json"),
        name              = "Foothills",

        enemy_health = 100,
        environment  = .Foothills,

        elements = #partial {
            .Electric = 3,
        },

        next_stage = 4,
    },

    // 4: Goblin Shaman
    {
        arena_layout_data = #load("./layouts/dragon_adventure_goblin.json"),
        name              = "Goblin Tunnels",

        enemy_health = 100,
        environment  = .Cave,

        elements = #partial {
            .Poison = 3,
        },

        next_stage = 5,
    },

    // 5: Troll Boss
    {
        arena_layout_data = #load("./layouts/dragon_adventure_troll.json"),
        name              = "",

        enemy_health = 100,
        is_boss      = true,
        environment  = .Cave,
        choices      = { 6, 8 },
    },

    // 6: Ice Dragon (Baby)
    {
        arena_layout_data = #load("./layouts/dragon_adventure_baby_dragon.json"),
        name              = "",

        enemy_health = 100,
        environment  = .Ice_Cave,

        elements = #partial {
            .Ice = 4,
        },

        next_stage = 7,
    },

    // 7: Ice Dragon
    {
        arena_layout_data = #load("./layouts/dragon_adventure_dragon.json"),
        name              = "",

        enemy_health = 100,
        is_boss      = true,
        environment  = .Ice_Cave,

        elements = #partial {
            .Ice = 8,
        },
    },

    // 8: Fire Dragon (Baby)
    {
        arena_layout_data = #load("./layouts/dragon_adventure_baby_dragon.json"),
        name              = "",

        enemy_health = 100,
        environment  = .Lava_Cave,

        elements = #partial {
            .Fire = 4,
        },

        next_stage = 9,
    },

    // 9: Fire Dragon
    {
        arena_layout_data = #load("./layouts/dragon_adventure_dragon.json"),
        name              = "",

        enemy_health = 100,
        is_boss      = true,
        environment  = .Lava_Cave,

        elements = #partial {
            .Fire = 8,
        },
    },
}