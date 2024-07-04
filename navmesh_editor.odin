package game

import "core:encoding/json"
import "core:fmt"
import "core:math"
import "core:os"
import rl "vendor:raylib"

GRID_SNAP_SIZE :: 5
POINT_SNAP_RADIUS :: 3 // Radius to check for other points to snap to
MOUSE_RADIUS :: 2 // Radius to check for mouse

selected_nav_cell: ^NavCell = nil
selected_nav_cell_index: int = -1

selected_point: ^Vec2 = nil
selected_point_cell_index: int = -1

display_nav_graph: bool

load_navmesh :: proc() {
	if nav_mesh_data, ok := os.read_entire_file("nav_mesh.json", context.allocator); ok {
		if json.unmarshal(nav_mesh_data, &nav_mesh) != nil {
			nav_mesh.cells = make([dynamic]NavCell, context.allocator)
			append(&nav_mesh.cells, NavCell{{{10, 10}, {20, 15}, {10, 0}}})
			nav_mesh.nodes = make([dynamic]NavNode, context.allocator)
		}
		delete(nav_mesh_data)
	} else {
		nav_mesh.cells = make([dynamic]NavCell, context.allocator)
		append(&nav_mesh.cells, NavCell{{{10, 10}, {20, 15}, {10, 0}}})
		nav_mesh.nodes = make([dynamic]NavNode, context.allocator)
	}
	rl.TraceLog(.INFO, "Navmesh Loaded")
}

save_navmesh :: proc() {
	calculate_graph(&nav_mesh)
	if nav_mesh_data, err := json.marshal(nav_mesh, allocator = context.allocator); err == nil {
		os.write_entire_file("nav_mesh.json", nav_mesh_data)
		delete(nav_mesh_data)
	}
	rl.TraceLog(.INFO, "Navmesh Saved")
}

unload_navmesh :: proc() {
	delete(nav_mesh.cells)
	delete(nav_mesh.nodes)
	nav_mesh.cells = nil
	nav_mesh.nodes = nil
}

// init_navmesh :: proc() {
// 	nav_mesh.cells = make([dynamic]NavCell, context.allocator)
// 	append(&nav_mesh.cells, NavCell{{{10, 10}, {20, 15}, {10, 0}}, {-1, -1, -1}, 0})
// }

update_navmesh_editor :: proc(mouse_world_pos: Vec2, mouse_world_delta: Vec2) {
	/* Incomplete Features
	Multiselect and move
	Move close together points together (Ctrl click)
	Triangles must store points in counter-clockwise order
	*/

	// Toggle Graph Display (G)
	if rl.IsKeyPressed(.G) {
		display_nav_graph = !display_nav_graph
	}

	// Deselecting point
	if rl.IsMouseButtonReleased(.LEFT) {
		selected_point = nil
		selected_point_cell_index = -1
	}

	// Select point for move (Left click)
	if rl.IsMouseButtonPressed(.LEFT) && !rl.IsKeyDown(.LEFT_ALT) {
		// In selected cell
		if selected_nav_cell != nil {
			selected_point = nil
			for &v in selected_nav_cell.verts {
				if length(v - mouse_world_pos) <= MOUSE_RADIUS {
					// If there is no point selected or if v is closer to the mouse than the already selected point then set it
					if selected_point == nil ||
					   (selected_point != nil &&
							   length(selected_point^ - mouse_world_pos) >
								   length(v - mouse_world_pos)) {
						selected_point = &v
						selected_point_cell_index = selected_nav_cell_index
					}
				}
			}
		} else if selected_nav_cell == nil { 	// In all cells
			selected_point = nil
			for &cell, ci in nav_mesh.cells {
				for &v in cell.verts {
					if length(v - mouse_world_pos) <= MOUSE_RADIUS {
						// If there is no point selected or if v is closer to the mouse than the already selected point then set it
						if selected_point == nil ||
						   (selected_point != nil &&
								   length(selected_point^ - mouse_world_pos) >
									   length(v - mouse_world_pos)) {
							selected_point = &v
							selected_point_cell_index = ci
						}
					}
				}
			}
		}
	}

	// Move point (Shift to snap)
	if selected_point != nil {
		selected_point^ += mouse_world_delta
		if rl.IsKeyDown(.LEFT_SHIFT) {
			snapped := false
			// Snapping to other points
			for cell, ci in nav_mesh.cells {
				for v in cell.verts {
					if ci == selected_point_cell_index {continue}
					if length(mouse_world_pos - v) <= POINT_SNAP_RADIUS {
						selected_point^ = v
						snapped = true
					}
				}
			}
			// Snapping to grid
			if !snapped {
				selected_point.x = math.round(mouse_world_pos.x / GRID_SNAP_SIZE) * GRID_SNAP_SIZE
				selected_point.y = math.round(mouse_world_pos.y / GRID_SNAP_SIZE) * GRID_SNAP_SIZE
			}
		}
	}

	// New triangle (N)
	if rl.IsKeyPressed(.N) {
		append(
			&nav_mesh.cells,
			NavCell{{mouse_world_pos, mouse_world_pos + {0, 10}, mouse_world_pos + {10, 0}}},
		)
		selected_nav_cell = nil
		selected_nav_cell_index = -1
	}

	// Subdivide triangle in to 4 smaller triangles (T)
	if rl.IsKeyPressed(.T) && selected_nav_cell != nil {
		// Get points
		edge_point0 := (selected_nav_cell.verts[0] + selected_nav_cell.verts[1]) / 2
		edge_point1 := (selected_nav_cell.verts[1] + selected_nav_cell.verts[2]) / 2
		edge_point2 := (selected_nav_cell.verts[2] + selected_nav_cell.verts[0]) / 2
		v0 := selected_nav_cell.verts[0]
		v1 := selected_nav_cell.verts[1]
		v2 := selected_nav_cell.verts[2]

		// Delete triangle
		unordered_remove(&nav_mesh.cells, selected_nav_cell_index)
		selected_nav_cell = nil
		selected_nav_cell_index = -1
		selected_point = nil
		selected_point_cell_index = -1

		// Create 4 smaller triangles
		append(&nav_mesh.cells, NavCell{{edge_point0, edge_point1, edge_point2}})

		append(&nav_mesh.cells, NavCell{{edge_point2, v0, edge_point0}})

		append(&nav_mesh.cells, NavCell{{edge_point0, v1, edge_point1}})

		append(&nav_mesh.cells, NavCell{{edge_point1, v2, edge_point2}})
	}

	// Delete (D)
	if rl.IsKeyPressed(.D) && selected_nav_cell != nil {
		// if rl.IsKeyDown(.LEFT_CONTROL) {
		// 	selected_nav_cell = nil
		// 	selected_nav_cell_index = -1
		// }
		// if rl.IsKeyDown(.LEFT_SHIFT) {
		unordered_remove(&nav_mesh.cells, selected_nav_cell_index)
		selected_nav_cell = nil
		selected_nav_cell_index = -1
		selected_point = nil
		selected_point_cell_index = -1
		// }
	}

	// Select/Deselect triangle (S)
	if !rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.S) {
		selected_nav_cell_index = -1
		for &cell, i in nav_mesh.cells {
			if selected_nav_cell != &cell &&
			   check_collision_triangle_point(cell.verts, mouse_world_pos) {
				selected_nav_cell = &cell
				selected_nav_cell_index = i
				break
			}
		}
		if selected_nav_cell_index == -1 {
			selected_nav_cell = nil
		}
	}

	// Select and move triangle (Alt click drag)
	if rl.IsKeyDown(.LEFT_ALT) && rl.IsMouseButtonDown(.LEFT) && selected_point == nil {
		if selected_nav_cell != nil {
			// Move selected triangle
			selected_nav_cell.verts += {mouse_world_delta, mouse_world_delta, mouse_world_delta}
		} else {
			for &cell, i in nav_mesh.cells {
				if selected_nav_cell != &cell &&
				   check_collision_triangle_point(cell.verts, mouse_world_pos) {
					selected_nav_cell = &cell
					selected_nav_cell_index = i
					break
				}
			}
		}
	}

	// Manual Save (Ctrl + S)
	if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.S) {
		save_navmesh()
	}

	// Manual Load (Ctrl + L)
	if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.L) {
		unload_navmesh()
		load_navmesh()
	}

	/* Completed features
	Pan (middle mouse + drag)
	Zoom (scroll wheel)
	*/
}

draw_navmesh_editor_world :: proc(mouse_world_pos: Vec2) {
	// Draw individual cells in navmesh. Draw points, edges, and fill cells
	for &cell in nav_mesh.cells {
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
			if selected_point == &v ||
			   (selected_point == nil && length(v - mouse_world_pos) <= MOUSE_RADIUS) {
				radius = 2
			}
			rl.DrawCircleV(v, radius, rl.LIGHTGRAY)
		}
	}

	// Show selected cell
	if selected_nav_cell != nil {
		cell := selected_nav_cell
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
			if selected_point == &v ||
			   (selected_point == nil && length(v - mouse_world_pos) <= MOUSE_RADIUS) {
				radius = 2
			}
			rl.DrawCircleV(v, radius, rl.GOLD)
		}
	}

	if display_nav_graph {
		// Draw connections
		for node in nav_mesh.nodes {
			for connection in node.connections {
				if connection < 0 {
					break
				}
				rl.DrawLineV(node.pos, nav_mesh.nodes[connection].pos, rl.GRAY)
			}
		}

		// Draw nodes
		for node in nav_mesh.nodes {
			rl.DrawCircleV(node.pos, 1, rl.BLACK)
		}
	}
}

draw_navmesh_editor_ui :: proc(mouse_world_pos: Vec2) {
	// Display mouse coordinates
	rl.DrawText(fmt.ctprintf("%v", mouse_world_pos), 20, 20, 16, rl.WHITE)
}
