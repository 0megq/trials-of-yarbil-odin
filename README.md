Trials of Yarbil is a top-down roguelike being developed, without a game engine, in Odin with the Raylib library for release on [Steam](https://store.steampowered.com/app/3320710/Trials_of_Yarbil/) in Q2 2025.

# Code To Look Out For
## Pathfinding Code
pathfinding.odin implements an AStar and path smoothing algorithm on a given graph and returns the path.

## Tools and Editor Code
geometry_editor.odin provides editing functionality to edit the level geometry, level tilemap, and move the portal position. It also calculates a graph of nodes based on the tilemap for use in pathfinding.odin.
entity_editor.odin provides editing for creating, moving, and deleting entities.
navmesh_editor.odin is an editor for creating and editing a navmesh defined by triangles. It is no longer in use.

## Serialization Code
serialize.odin provides functions and structs for saving, loading, and representing game data.
tilemap.odin provides functionality for saving, loading, and representing a tilemap using an image file to save data.

## Collision Detection Code
shapes.odin provides various functions and structs for representing shapes and detecting collisions.

## Physics Code
game.odin acts as the entry point and gameloop of the project. All physics simulation is weaved into the gameplay code and happens inside this file.
