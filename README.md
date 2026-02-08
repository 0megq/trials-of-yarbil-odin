# [Steam Page](https://store.steampowered.com/app/3320710/Trials_of_Yarbil/)
Trials of Yarbil is a top-down action hack and slash being developed, without a game engine, in Odin with the Raylib library that is NOW out on [Steam](https://store.steampowered.com/app/3320710/Trials_of_Yarbil/)

# Development
1. Install the [Odin language](https://odin-lang.org/docs/install/), using version dev-2025-05.
2. Clone this repository
3. Edit the src files as you wish
4. If you're using VS Code, you should just be able to compile and run using the launch.json configs
5. Otherwise, run `odin run ./src/ -debug -out:build/build.exe` for a debug build and `odin run ./src/ -out:build/yarbil.exe -subsystem:windows` for a release build

# Some Cool Code I've Written Throughout the Project

## Pathfinding Code

**pathfinding.odin** implements an AStar and path smoothing algorithm on a tile graph and returns the path through the graph.

## Tools and Editor Code

**geometry_editor.odin** provides editing for the level geometry, tilemap, and portal position. It also calculates a graph of nodes based on the tilemap for use in pathfinding.odin.

**entity_editor.odin** provides editing for creating, moving, and deleting entities.

## Serialization Code

**serialize.odin** provides functions and structs for saving, loading, and representing game data.

**tilemap.odin** provides functionality for saving, loading, and representing a tilemap using an image file to save data.

## Collision Detection Code

**shapes.odin** provides various functions and structs for representing shapes and detecting and predicting collisions.

## Physics and Gameplay Code

**world.odin** houses all physics simulation along with gameplay code that manages entities like the player, enemy, and exploding barrels.
