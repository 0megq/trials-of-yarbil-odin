package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

SELECTED_OUTLINE_COLOR :: rl.GREEN

/*
polygon point interface
- references polygon's slice. uses same slice
- new slice when a point is added
- new slice when a point is removed
- reorder slice
- 


add point (adds point at end of points slice)
remove point (removes specific point) - x button next to each point
reorder point? maybe - swap two adjacent points
special point field
	- x and y number fields
	- delete point button
	- reorder upwards
points field is a dynamic array of point fields

move and/or create points with mouse
*/

wall_tilemap: WallTilemap


update_geometry_editor :: proc(e: ^EditorState) {
	update_button(&e.new_shape_but, mouse_ui_pos)

	// New shape
	if e.new_shape_but.status == .Released {
		if rl.IsKeyDown(.LEFT_CONTROL) {
			append(
				&level.half_walls,
				HalfWall{entity = new_entity(world_camera.target), shape = Rectangle{0, 0, 8, 8}},
			)
			e.selected_wall_index = len(level.half_walls) - 1
			e.selected_wall = &level.half_walls[e.selected_wall_index]
			e.half_wall_selected = true
		} else {
			append(
				&level.walls,
				PhysicsEntity {
					entity = new_entity(world_camera.target),
					shape = Rectangle{0, 0, 8, 8},
				},
			)
			e.selected_wall_index = len(level.walls) - 1
			e.selected_wall = &level.walls[e.selected_wall_index]
			e.half_wall_selected = false
		}
		set_shape_fields_to_selected_shape(e)
	}

	// Updating fields
	if e.selected_wall != nil {
		update_button(&e.change_shape_but, mouse_ui_pos)
		if e.change_shape_but.status == .Released {
			switch shape in e.selected_wall.shape {
			case Circle:
				e.selected_wall.shape = Rectangle{}
			case Polygon:
			// Not supporting polygon
			// delete(shape.points)
			// selected_wall.shape = Rectangle{}
			case Rectangle:
				e.selected_wall.shape = Circle{}
			}
		}
		update_shape_fields(e)
	}

	// Delete (delete)
	if rl.IsKeyPressed(.DELETE) && e.selected_wall != nil {
		if e.half_wall_selected {
			unordered_remove(&level.half_walls, e.selected_wall_index)
		} else {
			unordered_remove(&level.walls, e.selected_wall_index)
		}
		e.selected_wall = nil
		e.selected_wall_index = -1
	}

	// Deselect (CTRL + D)
	if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.D) && e.selected_wall != nil {
		e.selected_wall = nil
		e.selected_wall_index = -1
	}

	// Selecting shapes
	if rl.IsMouseButtonPressed(.LEFT) {
		for &wall, index in level.walls {
			if check_collision_shape_point(wall.shape, wall.pos, mouse_world_pos) {
				e.selected_wall = &wall
				e.selected_wall_index = index
				e.half_wall_selected = false
				set_shape_fields_to_selected_shape(e)
				break
			}
		}

		for &wall, index in level.half_walls {
			if check_collision_shape_point(wall.shape, wall.pos, mouse_world_pos) {
				e.selected_wall = &wall
				e.selected_wall_index = index
				e.half_wall_selected = true
				set_shape_fields_to_selected_shape(e)
				break
			}
		}
	} else if rl.IsMouseButtonPressed(.RIGHT) && e.selected_wall != nil {
		e.wall_mouse_rel_pos = e.selected_wall.pos - mouse_world_pos
	}

	// Move shape (SHIFT to snap to tile grid)
	if rl.IsMouseButtonDown(.RIGHT) && e.selected_wall != nil {
		snap_size: f32 = 1
		if rl.IsKeyDown(.LEFT_SHIFT) {
			snap_size = TILE_SIZE
		}

		e.selected_wall.pos.x =
			math.round((e.wall_mouse_rel_pos.x + mouse_world_pos.x) / snap_size) * snap_size
		e.selected_wall.pos.y =
			math.round((e.wall_mouse_rel_pos.y + mouse_world_pos.y) / snap_size) * snap_size
		set_shape_fields_to_selected_shape(e)
	}

	// Increasing/decreasing size of rectangle walls by tile size
	if e.selected_wall != nil {
		#partial switch &wall in e.selected_wall.shape {
		case Rectangle:
			{
				original_width := wall.width
				original_height := wall.height
				if rl.IsKeyDown(.LEFT_SHIFT) {
					if rl.IsKeyDown(.LEFT) {
						wall.width -= TILE_SIZE
					} else if rl.IsKeyDown(.RIGHT) {
						wall.width += TILE_SIZE
					}

					if rl.IsKeyDown(.UP) {
						wall.height -= TILE_SIZE
					} else if rl.IsKeyDown(.DOWN) {
						wall.height += TILE_SIZE
					}
				} else {
					if rl.IsKeyPressed(.LEFT) {
						wall.width -= TILE_SIZE
					} else if rl.IsKeyPressed(.RIGHT) {
						wall.width += TILE_SIZE
					}

					if rl.IsKeyPressed(.UP) {
						wall.height -= TILE_SIZE
					} else if rl.IsKeyPressed(.DOWN) {
						wall.height += TILE_SIZE
					}
				}
				if original_height != wall.height || original_width != wall.width {
					set_shape_fields_to_selected_shape(e)
				}
			}
		}
	}

	// Selecting and moving portal
	if rl.IsMouseButtonPressed(.LEFT) {
		if check_collision_shape_point(
			Circle{{}, PORTAL_RADIUS},
			level.portal_pos,
			mouse_world_pos,
		) {
			e.portal_selected = true
			e.portal_mouse_rel_pos = level.portal_pos - mouse_world_pos
		} else {
			e.portal_selected = false
		}
	}
	if e.portal_selected && rl.IsMouseButtonDown(.LEFT) {
		snap_size: f32 = 1
		if rl.IsKeyDown(.LEFT_SHIFT) {
			snap_size = TILE_SIZE
		}

		level.portal_pos.x =
			math.round((e.portal_mouse_rel_pos.x + mouse_world_pos.x) / snap_size) * snap_size
		level.portal_pos.y =
			math.round((e.portal_mouse_rel_pos.y + mouse_world_pos.y) / snap_size) * snap_size
	}

	// tilemap editor
	if e.selected_wall == nil {
		mouse_tile_pos := world_to_tilemap(mouse_world_pos)
		switch {
		case rl.IsKeyDown(.ONE):
			level_tilemap[mouse_tile_pos.x][mouse_tile_pos.y] = GrassData{}
		case rl.IsKeyDown(.TWO):
			level_tilemap[mouse_tile_pos.x][mouse_tile_pos.y] = DirtData{}
		case rl.IsKeyDown(.THREE):
			level_tilemap[mouse_tile_pos.x][mouse_tile_pos.y] = StoneData{}
		case rl.IsKeyDown(.FOUR):
			level_tilemap[mouse_tile_pos.x][mouse_tile_pos.y] = WaterData{}
		case rl.IsKeyDown(.ZERO):
			level_tilemap[mouse_tile_pos.x][mouse_tile_pos.y] = EmptyData{}
		}
	}

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
			fmt.println("calculating...")
			e.test_path = find_path_tiles(
				e.test_path_start,
				e.test_path_end,
				nav_graph,
				level_tilemap,
				wall_tilemap,
			)
			fmt.println(e.test_path)
		} else if rl.IsKeyDown(.LEFT_CONTROL) {
			place_walls_and_calculate_graph()
		} else { 	// Toggle path display
			e.display_test_path = !e.display_test_path
		}
	}

	// Toggle Graph Display (G)
	if rl.IsKeyPressed(.G) {
		e.display_nav_graph = !e.display_nav_graph
	}

	if e.selected_wall != nil && rl.IsKeyPressed(.I) {
		// Copy the regex expression for the first two ints in the id
		rl.SetClipboardText(
			fmt.ctprintf("%v,\\n\\s*%v", e.selected_wall.id[0], e.selected_wall.id[1]),
		)
	}
}

place_walls_and_calculate_graph :: proc() {
	// Place wall tiles based on wall geometry
	wall_tilemap = false
	for wall in level.walls {
		tiles := get_tile_shape_collision(wall.shape, wall.pos, 0.1)
		for tile in tiles {
			wall_tilemap[tile.x][tile.y] = true
		}
	}
	for half_wall in level.half_walls {
		tiles := get_tile_shape_collision(half_wall.shape, half_wall.pos, 0.1)
		for tile in tiles {
			wall_tilemap[tile.x][tile.y] = true
		}
	}
	// calculate graph
	calculate_tile_graph(&nav_graph, level_tilemap, wall_tilemap)
}

set_shape_fields_to_selected_shape :: proc(e: ^EditorState) {
	set_number_field_value(&e.entity_x_field, e.selected_wall.pos.x)
	set_number_field_value(&e.entity_y_field, e.selected_wall.pos.y)
	switch shape in e.selected_wall.shape {
	case Circle:
		set_number_field_value(&e.shape_x_field, shape.pos.x)
		set_number_field_value(&e.shape_y_field, shape.pos.y)
		set_number_field_value(&e.radius_field, shape.radius)
	case Polygon:
	// set_number_field_value(&x_field, shape.pos.x)
	// set_number_field_value(&y_field, shape.pos.y)
	// set_number_field_value(&rotation_field, shape.rotation)
	//TODO: Implement points and rotation
	case Rectangle:
		set_number_field_value(&e.shape_x_field, shape.x)
		set_number_field_value(&e.shape_y_field, shape.y)
		set_number_field_value(&e.width_field, shape.width)
		set_number_field_value(&e.height_field, shape.height)
	}
}

update_shape_fields :: proc(e: ^EditorState) {
	update_number_field(&e.entity_x_field, mouse_ui_pos)
	update_number_field(&e.entity_y_field, mouse_ui_pos)
	e.selected_wall.pos.x = e.entity_x_field.number
	e.selected_wall.pos.y = e.entity_y_field.number
	update_number_field(&e.shape_x_field, mouse_ui_pos)
	update_number_field(&e.shape_y_field, mouse_ui_pos)
	switch &shape in e.selected_wall.shape {
	case Circle:
		update_number_field(&e.radius_field, mouse_ui_pos)
		shape.pos.x = e.shape_x_field.number
		shape.pos.y = e.shape_y_field.number
		shape.radius = e.radius_field.number
	case Polygon:
	// No longer supporting polygon in level editor
	// update_number_field(&rotation_field, mouse_ui_pos)
	// shape.pos.x = e.shape_x_field.number
	// shape.pos.y = e.shape_y_field.number
	// shape.rotation = e.rotation_field.number
	case Rectangle:
		update_number_field(&e.width_field, mouse_ui_pos)
		update_number_field(&e.height_field, mouse_ui_pos)
		shape.x = e.shape_x_field.number
		shape.y = e.shape_y_field.number
		shape.width = e.width_field.number
		shape.height = e.height_field.number
	}
}

draw_geometry_editor_world :: proc(e: EditorState) {
	if e.portal_selected {
		rl.DrawCircleLinesV(level.portal_pos, PORTAL_RADIUS, SELECTED_OUTLINE_COLOR)
	}
	if e.selected_wall != nil {
		draw_shape_lines(e.selected_wall.shape, e.selected_wall.pos, SELECTED_OUTLINE_COLOR)
		rl.DrawCircleV(e.selected_wall.pos, 1, SELECTED_OUTLINE_COLOR)
	}

	if e.display_nav_graph {
		// Draw connections
		for node in nav_graph.nodes {
			for connection in node.connections {
				if connection < 0 {
					break
				}
				rl.DrawLineV(node.pos, nav_graph.nodes[connection].pos, rl.GRAY)
			}
		}

		// Draw nodes
		for node in nav_graph.nodes {
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

draw_geometry_editor_ui :: proc(e: EditorState) {
	if e.selected_wall != nil {
		draw_button(e.change_shape_but)
		draw_shape_fields(e)
	}
	draw_button(e.new_shape_but)

	if e.display_test_path {
		for point in e.test_path {
			rl.DrawTextEx(
				rl.GetFontDefault(),
				fmt.ctprint(point),
				world_to_ui(point),
				16,
				2,
				rl.WHITE,
			)
		}
	}
}

draw_shape_fields :: proc(e: EditorState) {
	draw_number_field(e.entity_x_field)
	draw_number_field(e.entity_y_field)
	draw_number_field(e.shape_x_field)
	draw_number_field(e.shape_y_field)
	switch _ in e.selected_wall.shape {
	case Circle:
		draw_number_field(e.radius_field)
	case Polygon:
	// draw_number_field(rotation_field)
	//TODO: Implement points and rotation
	case Rectangle:
		draw_number_field(e.width_field)
		draw_number_field(e.height_field)
	}
}
