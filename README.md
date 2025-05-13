Trials of Yarbil is a top-down action hack and slash being developed, without a game engine, in Odin with the Raylib library for release on [Steam](https://store.steampowered.com/app/3320710/Trials_of_Yarbil/) in 2025.

# Code To Look Out For

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
