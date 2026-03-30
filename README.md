# [Steam Page and Gameplay Trailer](https://store.steampowered.com/app/3320710/Trials_of_Yarbil/)
Trials of Yarbil is a top-down action game where you dash, slash, and explode through floors of goblins. It was developed, with a custom game engine, in Odin (a C-like language) with the Raylib library. It is now out on [Steam](https://store.steampowered.com/app/3320710/Trials_of_Yarbil/).

# [Youtube Devlogs](https://www.youtube.com/watch?v=HNNescv4yIw)
The devlogs created to track the progress of this project can be found [here](https://www.youtube.com/watch?v=HNNescv4yIw).

# Code Samples

## Enemy State Machine
[update_enemy_state world.odin line 2263](https://github.com/0megq/trials-of-yarbil-odin/blob/main/src/world.odin#L2263) houses the **update logic for the enemy behavior state machine**. For the complete enemy update loop see [line 259 of world.odin](https://github.com/0megq/trials-of-yarbil-odin/blob/main/src/world.odin#L259).

## Player Movement
[player_move in world.odin line 2794](https://github.com/0megq/trials-of-yarbil-odin/blob/main/src/world.odin#L2794) implements the **core of the player movement system** including a **dash**.

## Combat
All **attacks are handled** through [perform_attack in world.odin](https://github.com/0megq/trials-of-yarbil-odin/blob/main/src/world.odin#L1485). The **player's attac**k is is implemented on [line 647 of world.odin](https://github.com/0megq/trials-of-yarbil-odin/blob/main/src/world.odin#L647).

## Pathfinding
[pathfinding.odin](https://github.com/0megq/trials-of-yarbil-odin/blob/main/src/pathfinding.odin) implements an AStar and path smoothing algorithm on a tile graph and returns the path through the graph. **Enables enemies to track player around walls.**

## Physics Collision Detection
[shapes.odin](https://github.com/0megq/trials-of-yarbil-odin/blob/main/src/shapes.odin) provides various functions and structs for representing shapes and **detecting and predicting collisions**. [world.odin line 183](https://github.com/0megq/trials-of-yarbil-odin/blob/main/src/world.odin#L183) showcases how **player collisions with walls and exploding barrels are resolved**.

## Tooling
[geometry_editor.odin](https://github.com/0megq/trials-of-yarbil-odin/blob/main/src/geometry_editor.odin) provides** editing for the level geometry, tilemap, and portal position.** It also calculates a graph of nodes based on the tilemap for use in pathfinding.odin.

[entity_editor.odin](https://github.com/0megq/trials-of-yarbil-odin/blob/main/src/entity_editor.odin) provides **editing for creating, moving, and deleting entities**.

## Serialization

[serialize.odin](https://github.com/0megq/trials-of-yarbil-odin/blob/main/src/serialize.odin) provides functions and structs for **saving, loading, and representing game data.**

## Tilemap
[tilemap.odin](https://github.com/0megq/trials-of-yarbil-odin/blob/main/src/tilemap.odin) provides a **custom tilemap implementation** with functionality for saving, loading, and representing a tilemap using an image file to save data.


# Development
1. Install the [Odin language](https://odin-lang.org/docs/install/), using version dev-2025-05.
2. Clone this repository
3. Edit the src files as you wish
4. If you're using VS Code, you should just be able to compile and run using the launch.json configs
5. Otherwise, run `odin run ./src/ -debug -out:build/build.exe` for a debug build and `odin run ./src/ -out:build/yarbil.exe -subsystem:windows` for a release build
