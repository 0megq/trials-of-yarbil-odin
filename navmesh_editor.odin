package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

NAVMESH_GRID_SNAP_SIZE :: 5
POINT_SNAP_RADIUS :: 3 // Radius to check for other points to snap to
MOUSE_RADIUS :: 2 // Radius to check for mouse

update_navmesh_editor :: proc(e: ^EditorState) {
	/* Incomplete Features
	Multiselect and move
	Move close together points together (Ctrl click)
	Triangles must store points in counter-clockwise order
	*/

	// Astar test operations
	// Set start/end (Right click, + Alt for end)
	if e.display_test_path && rl.IsMouseButtonPressed(.RIGHT) {
		if rl.IsKeyDown(.LEFT_SHIFT) {
			e.test_path_end = mouse_world_pos
		} else {
			e.test_path_start = mouse_world_pos
		}
	}

	if rl.IsKeyPressed(.A) {
		if rl.IsKeyDown(.LEFT_SHIFT) { 	// Calculate path
			if e.test_path != nil {
				delete(e.test_path)
			}
			e.test_path = find_path(e.test_path_start, e.test_path_end, level.nav_mesh)
		} else { 	// Toggle path display
			e.display_test_path = !e.display_test_path
		}
	}

	// Toggle Graph Display (G)
	if rl.IsKeyPressed(.G) {
		e.display_nav_graph = !e.display_nav_graph
	}

	// Deselecting point
	if rl.IsMouseButtonReleased(.LEFT) {
		e.selected_point = nil
		e.selected_point_cell_index = -1
	}

	// Select point for move (Left click)
	if rl.IsMouseButtonPressed(.LEFT) && !rl.IsKeyDown(.LEFT_ALT) {
		// In selected cell
		if e.selected_nav_cell != nil {
			e.selected_point = nil
			for &v in e.selected_nav_cell.verts {
				if length(v - mouse_world_pos) <= MOUSE_RADIUS {
					// If there is no point selected or if v is closer to the mouse than the already selected point then set it
					if e.selected_point == nil ||
					   (e.selected_point != nil &&
							   length(e.selected_point^ - mouse_world_pos) >
								   length(v - mouse_world_pos)) {
						e.selected_point = &v
						e.selected_point_cell_index = e.selected_nav_cell_index
					}
				}
			}
		} else if e.selected_nav_cell == nil { 	// In all cells
			e.selected_point = nil
			for &cell, ci in level.nav_mesh.cells {
				for &v in cell.verts {
					if length(v - mouse_world_pos) <= MOUSE_RADIUS {
						// If there is no point selected or if v is closer to the mouse than the already selected point then set it
						if e.selected_point == nil ||
						   (e.selected_point != nil &&
								   length(e.selected_point^ - mouse_world_pos) >
									   length(v - mouse_world_pos)) {
							e.selected_point = &v
							e.selected_point_cell_index = ci
						}
					}
				}
			}
		}
	}

	// Move point (Click and drag. Shift to snap)
	if e.selected_point != nil {
		e.selected_point^ += mouse_world_delta
		if rl.IsKeyDown(.LEFT_SHIFT) {
			snapped := false
			// Snapping to other points
			for cell, ci in level.nav_mesh.cells {
				for v in cell.verts {
					if ci == e.selected_point_cell_index {continue}
					if length(mouse_world_pos - v) <= POINT_SNAP_RADIUS {
						e.selected_point^ = v
						snapped = true
					}
				}
			}
			// Snapping to grid
			if !snapped {
				e.selected_point.x =
					math.round(mouse_world_pos.x / NAVMESH_GRID_SNAP_SIZE) * NAVMESH_GRID_SNAP_SIZE
				e.selected_point.y =
					math.round(mouse_world_pos.y / NAVMESH_GRID_SNAP_SIZE) * NAVMESH_GRID_SNAP_SIZE
			}
		}
	}

	// New triangle (N)
	if rl.IsKeyPressed(.N) {
		append(
			&level.nav_mesh.cells,
			NavCell{{mouse_world_pos, mouse_world_pos + {0, 10}, mouse_world_pos + {10, 0}}},
		)
		e.selected_nav_cell = nil
		e.selected_nav_cell_index = -1
	}

	// Subdivide triangle in to 4 smaller triangles (T)
	if rl.IsKeyPressed(.T) && e.selected_nav_cell != nil {
		// Get points
		edge_point0 := (e.selected_nav_cell.verts[0] + e.selected_nav_cell.verts[1]) / 2
		edge_point1 := (e.selected_nav_cell.verts[1] + e.selected_nav_cell.verts[2]) / 2
		edge_point2 := (e.selected_nav_cell.verts[2] + e.selected_nav_cell.verts[0]) / 2
		v0 := e.selected_nav_cell.verts[0]
		v1 := e.selected_nav_cell.verts[1]
		v2 := e.selected_nav_cell.verts[2]

		// Delete triangle
		unordered_remove(&level.nav_mesh.cells, e.selected_nav_cell_index)
		e.selected_nav_cell = nil
		e.selected_nav_cell_index = -1
		e.selected_point = nil
		e.selected_point_cell_index = -1

		// Create 4 smaller triangles
		append(&level.nav_mesh.cells, NavCell{{edge_point0, edge_point1, edge_point2}})

		append(&level.nav_mesh.cells, NavCell{{edge_point2, v0, edge_point0}})

		append(&level.nav_mesh.cells, NavCell{{edge_point0, v1, edge_point1}})

		append(&level.nav_mesh.cells, NavCell{{edge_point1, v2, edge_point2}})
	}

	// Delete (D)
	if rl.IsKeyPressed(.D) && e.selected_nav_cell != nil {
		// if rl.IsKeyDown(.LEFT_CONTROL) {
		// 	selected_nav_cell = nil
		// 	selected_nav_cell_index = -1
		// }
		// if rl.IsKeyDown(.LEFT_SHIFT) {
		unordered_remove(&level.nav_mesh.cells, e.selected_nav_cell_index)
		e.selected_nav_cell = nil
		e.selected_nav_cell_index = -1
		e.selected_point = nil
		e.selected_point_cell_index = -1
		// }
	}

	// Select/Deselect triangle (S)
	if !rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.S) {
		e.selected_nav_cell_index = -1
		for &cell, i in level.nav_mesh.cells {
			if e.selected_nav_cell != &cell &&
			   check_collision_triangle_point(cell.verts, mouse_world_pos) {
				e.selected_nav_cell = &cell
				e.selected_nav_cell_index = i
				break
			}
		}
		if e.selected_nav_cell_index == -1 {
			e.selected_nav_cell = nil
		}
	}

	// Select and move triangle (Alt click drag)
	if rl.IsKeyDown(.LEFT_ALT) && rl.IsMouseButtonDown(.LEFT) && e.selected_point == nil {
		if e.selected_nav_cell != nil {
			// Move selected triangle
			e.selected_nav_cell.verts += {mouse_world_delta, mouse_world_delta, mouse_world_delta}
		} else {
			for &cell, i in level.nav_mesh.cells {
				if e.selected_nav_cell != &cell &&
				   check_collision_triangle_point(cell.verts, mouse_world_pos) {
					e.selected_nav_cell = &cell
					e.selected_nav_cell_index = i
					break
				}
			}
		}
	}
}

draw_navmesh_editor_world :: proc(e: EditorState) {
	// Draw individual cells in navmesh. Draw points, edges, and fill cells
	for &cell in level.nav_mesh.cells {
		// Fill
		rl.DrawTriangle(cell.verts[0], cell.verts[1], cell.verts[2], Color{0, 120, 120, 150})

		// Edges
		for vi in 0 ..< len(cell.verts) {
			rl.DrawLineV(cell.verts[vi], cell.verts[(vi + 1) % len(cell.verts)], rl.BLACK)
		}

		// Points
		for &v in cell.verts {
			radius: f32 = 1

			// Enlarge points the mouse is near (if triangle is selected then only those of that triangle)
			if e.selected_point == &v ||
			   (e.selected_point == nil && length(v - mouse_world_pos) <= MOUSE_RADIUS) {
				radius = 2
			}
			rl.DrawCircleV(v, radius, rl.LIGHTGRAY)
		}
	}

	// Show selected cell
	if e.selected_nav_cell != nil {
		cell := e.selected_nav_cell
		// Fill
		rl.DrawTriangle(cell.verts[0], cell.verts[1], cell.verts[2], Color{0, 120, 0, 100})

		// Edges
		for vi in 0 ..< len(cell.verts) {
			rl.DrawLineV(cell.verts[vi], cell.verts[(vi + 1) % len(cell.verts)], rl.GOLD)
		}

		// Points
		for &v in cell.verts {
			radius: f32 = 1

			// Enlarge points the mouse is near (if triangle is selected then only those of that triangle)
			if e.selected_point == &v ||
			   (e.selected_point == nil && length(v - mouse_world_pos) <= MOUSE_RADIUS) {
				radius = 2
			}
			rl.DrawCircleV(v, radius, rl.GOLD)
		}
	}

	if e.display_nav_graph {
		// Draw connections
		for node in level.nav_mesh.nodes {
			for connection in node.connections {
				if connection < 0 {
					break
				}
				rl.DrawLineV(node.pos, level.nav_mesh.nodes[connection].pos, rl.GRAY)
			}
		}

		// Draw nodes
		for node in level.nav_mesh.nodes {
			rl.DrawCircleV(node.pos, 1, rl.BLACK)
		}
	}

	if e.display_test_path {
		rl.DrawCircleV(e.test_path_start, 2, rl.BLUE)
		rl.DrawCircleV(e.test_path_end, 2, rl.GREEN)

		for i in 0 ..< len(e.test_path) - 1 {
			rl.DrawLineV(e.test_path[i], e.test_path[i + 1], rl.ORANGE)
		}
		for point in e.test_path {
			rl.DrawCircleV(point, 1, rl.RED)
		}
	}
}

draw_navmesh_editor_ui :: proc(e: EditorState) {

	if e.display_nav_graph {
		for node, i in level.nav_mesh.nodes {
			rl.DrawTextEx(
				rl.GetFontDefault(),
				fmt.ctprintf("%v", i),
				world_to_screen(node.pos),
				24,
				2,
				rl.WHITE,
			)
		}
	}
}
