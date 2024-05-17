# Magical Magic Mages

A turn based game where you play as a mage and fight through stuff

# Building

To build the game you need to have the following tools installed:

- [Odin](https://odin-lang.org)
- [SDL2](https://www.libsdl.org)

We're also using the following SDL [extension libraries](https://wiki.libsdl.org/SDL2/Libraries): Image, Mixer, and Net.

Then you can build and run the game with:

```sh
make client
make server
```
# Alpha Roadmap:

- [x] Main Menu
- [ ] Level 1
    - [ ] Overworld Map
        - [ ] Graph
        - [ ] Player Movement
        - [ ] Enemy Movement
        - [ ] Obstacles
        - [ ] Encounters
            - [ ] Villages      (V)
            - [ ] Fields        (F)
            - [ ] Enemy Camps   (C)
            - [ ] Ancient Ruins (R)
    - [ ] Battle Mode
        - [ ] Spell Casting
        - [ ] Relic Effects
    - [ ] Enemies
        - [ ] Mage Neophyte
        - [ ] Mage Acolyte
    - [ ] Boss
        - [ ] Mage General

# Beta Roadmap:

- [ ] Graphics
- [ ] Options Menu
- [ ] Level 2
    - [ ] Map
    - [ ] Enemies
    - [ ] Boss
        - [ ] Mage Generals
- [ ] Level 3
    - [ ] Map
    - [ ] Enemies
    - [ ] Boss
        - [ ] Mage King

# Release Roadmap:

- [ ] Graphics
- [ ] Credits Menu
- [ ] Intro Cutscene
- [ ] Map Editor
- [ ] Multiplayer
    - [ ] 1v1
    - [ ] 2v2
