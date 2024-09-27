package game

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


update_geometry_editor :: proc(w: ^World, e: ^EditorState) {
	update_button(&e.new_shape_but, mouse_pos)

	if e.new_shape_but.status == .Released {
		append(
			&w.walls,
			PhysicsEntity{entity = new_entity(camera.target), shape = Rectangle{0, 0, 20, 20}},
		)
		e.selected_wall_index = len(w.walls) - 1
		e.selected_wall = &w.walls[e.selected_wall_index]
		set_shape_fields_to_selected_shape(e)
	}

	if e.selected_wall != nil {
		update_button(&e.change_shape_but, mouse_pos)
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

	// Deleting shapes
	if rl.IsKeyPressed(.D) && e.selected_wall != nil {
		if rl.IsKeyDown(.LEFT_CONTROL) {
			e.selected_wall = nil
			e.selected_wall_index = -1
		}
		if rl.IsKeyDown(.LEFT_SHIFT) {
			unordered_remove(&w.walls, e.selected_wall_index)
			e.selected_wall = nil
			e.selected_wall_index = -1
		}
	}

	// Selecting shapes
	if rl.IsMouseButtonPressed(.LEFT) {
		for &wall, index in w.walls {
			if check_collision_shape_point(wall.shape, wall.pos, mouse_world_pos) {
				e.selected_wall = &wall
				e.selected_wall_index = index
				set_shape_fields_to_selected_shape(e)
				break
			}
		}
	} else if rl.IsMouseButtonDown(.RIGHT) && e.selected_wall != nil { 	// Moving shape
		e.selected_wall.pos += mouse_world_delta
		set_shape_fields_to_selected_shape(e)
	}
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
	update_number_field(&e.entity_x_field, mouse_pos)
	update_number_field(&e.entity_y_field, mouse_pos)
	e.selected_wall.pos.x = e.entity_x_field.number
	e.selected_wall.pos.y = e.entity_y_field.number
	update_number_field(&e.shape_x_field, mouse_pos)
	update_number_field(&e.shape_y_field, mouse_pos)
	switch &shape in e.selected_wall.shape {
	case Circle:
		update_number_field(&e.radius_field, mouse_pos)
		shape.pos.x = e.shape_x_field.number
		shape.pos.y = e.shape_y_field.number
		shape.radius = e.radius_field.number
	case Polygon:
	// No longer supporting polygon in level editor
	// update_number_field(&rotation_field, mouse_pos)
	// shape.pos.x = e.shape_x_field.number
	// shape.pos.y = e.shape_y_field.number
	// shape.rotation = e.rotation_field.number
	case Rectangle:
		update_number_field(&e.width_field, mouse_pos)
		update_number_field(&e.height_field, mouse_pos)
		shape.x = e.shape_x_field.number
		shape.y = e.shape_y_field.number
		shape.width = e.width_field.number
		shape.height = e.height_field.number
	}
}

draw_geometry_editor_world :: proc(e: ^EditorState) {
	if e.selected_wall != nil {
		draw_shape_lines(e.selected_wall.shape, e.selected_wall.pos, SELECTED_OUTLINE_COLOR)
		rl.DrawCircleV(e.selected_wall.pos, 1, SELECTED_OUTLINE_COLOR)
	}
}

draw_geometry_editor_ui :: proc(e: ^EditorState) {
	if e.selected_wall != nil {
		draw_button(e.change_shape_but)
		draw_shape_fields(e)
	}
	draw_button(e.new_shape_but)
}

draw_shape_fields :: proc(e: ^EditorState) {
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
