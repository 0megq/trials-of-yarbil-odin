package game

import rl "vendor:raylib"

SELECTED_OUTLINE_COLOR :: rl.GREEN
selected_wall: ^PhysicsEntity
selected_wall_index: int = -1

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

new_shape_but := Button {
	{20, 60, 120, 30},
	"New Shape",
	.Normal,
	{200, 200, 200, 200},
	{150, 150, 150, 200},
	{100, 100, 100, 200},
}

change_shape_but := Button {
	{20, 100, 120, 30},
	"Change Shape",
	.Normal,
	{200, 200, 200, 200},
	{150, 150, 150, 200},
	{100, 100, 100, 200},
}

entity_x_field := NumberField {
	{20, 390, 200, 40},
	0,
	"0",
	" E.X ",
	false,
	0,
	{150, 150, 150, 200},
	{150, 255, 150, 200},
}

entity_y_field := NumberField {
	{20, 450, 200, 40},
	0,
	"0",
	" E.Y ",
	false,
	0,
	{150, 150, 150, 200},
	{150, 255, 150, 200},
}

x_field := NumberField {
	{20, 150, 120, 40},
	0,
	"0",
	" X ",
	false,
	0,
	{150, 150, 150, 200},
	{150, 255, 150, 200},
}

y_field := NumberField {
	{20, 210, 120, 40},
	0,
	"0",
	" Y ",
	false,
	0,
	{150, 150, 150, 200},
	{150, 255, 150, 200},
}

radius_field := NumberField {
	{20, 270, 120, 40},
	0,
	"0",
	" R ",
	false,
	0,
	{150, 150, 150, 200},
	{150, 255, 150, 200},
}

width_field := NumberField {
	{20, 270, 120, 40},
	0,
	"0",
	" W ",
	false,
	0,
	{150, 150, 150, 200},
	{150, 255, 150, 200},
}

height_field := NumberField {
	{20, 330, 120, 40},
	0,
	"0",
	" H ",
	false,
	0,
	{150, 150, 150, 200},
	{150, 255, 150, 200},
}

rotation_field := NumberField {
	{20, 270, 120, 40},
	0,
	"0",
	" R ",
	false,
	0,
	{150, 150, 150, 200},
	{150, 255, 150, 200},
}

update_editor :: proc(
	walls: ^[dynamic]PhysicsEntity,
	mouse_pos: Vec2,
	mouse_delta: Vec2,
	mouse_world_pos: Vec2,
	mouse_world_delta: Vec2,
	camera_target: Vec2,
) {
	update_button(&new_shape_but, mouse_pos)

	if new_shape_but.status == .Released {
		append(walls, PhysicsEntity{pos = camera_target, shape = Rectangle{0, 0, 20, 20}})
		selected_wall_index = len(walls) - 1
		selected_wall = &walls[selected_wall_index]
		set_shape_fields_to_selected()
	}

	if selected_wall != nil {
		update_button(&change_shape_but, mouse_pos)
		if change_shape_but.status == .Released {
			switch shape in selected_wall.shape {
			case Circle:
				selected_wall.shape = Polygon{}
			case Polygon:
				delete(shape.points)
				selected_wall.shape = Rectangle{}
			case Rectangle:
				selected_wall.shape = Circle{}
			}
		}
		update_shape_fields(mouse_pos)
	}

	// Deleting shapes
	if rl.IsKeyPressed(.D) && selected_wall != nil {
		if rl.IsKeyDown(.LEFT_CONTROL) {
			selected_wall = nil
			selected_wall_index = -1
		}
		if rl.IsKeyDown(.LEFT_SHIFT) {
			unordered_remove(walls, selected_wall_index)
			selected_wall = nil
			selected_wall_index = -1
		}
	}

	// Selecting shapes
	if rl.IsMouseButtonPressed(.LEFT) {
		for &wall, index in walls {
			if check_collision_shape_point(wall.shape, wall.pos, mouse_world_pos) {
				selected_wall = &wall
				selected_wall_index = index
				set_shape_fields_to_selected()
				break
			}
		}
	} else if rl.IsMouseButtonDown(.RIGHT) && selected_wall != nil { 	// Moving shape
		selected_wall.pos += mouse_world_delta
		set_shape_fields_to_selected()
	}
}

set_shape_fields_to_selected :: proc() {
	set_number_field_value(&entity_x_field, selected_wall.pos.x)
	set_number_field_value(&entity_y_field, selected_wall.pos.y)
	switch shape in selected_wall.shape {
	case Circle:
		set_number_field_value(&x_field, shape.pos.x)
		set_number_field_value(&y_field, shape.pos.y)
		set_number_field_value(&radius_field, shape.radius)
	case Polygon:
		set_number_field_value(&x_field, shape.pos.x)
		set_number_field_value(&y_field, shape.pos.y)
		set_number_field_value(&rotation_field, shape.rotation)
	//TODO: Implement points and rotation
	case Rectangle:
		set_number_field_value(&x_field, shape.x)
		set_number_field_value(&y_field, shape.y)
		set_number_field_value(&width_field, shape.width)
		set_number_field_value(&height_field, shape.height)
	}
}

update_shape_fields :: proc(mouse_pos: Vec2) {
	update_number_field(&entity_x_field, mouse_pos)
	update_number_field(&entity_y_field, mouse_pos)
	selected_wall.pos.x = entity_x_field.number
	selected_wall.pos.y = entity_y_field.number
	update_number_field(&x_field, mouse_pos)
	update_number_field(&y_field, mouse_pos)
	switch &shape in selected_wall.shape {
	case Circle:
		update_number_field(&radius_field, mouse_pos)
		shape.pos.x = x_field.number
		shape.pos.y = y_field.number
		shape.radius = radius_field.number
	case Polygon:
		update_number_field(&rotation_field, mouse_pos)
		shape.pos.x = x_field.number
		shape.pos.y = y_field.number
		shape.rotation = rotation_field.number
	//TODO: Implement points and rotation
	case Rectangle:
		update_number_field(&width_field, mouse_pos)
		update_number_field(&height_field, mouse_pos)
		shape.x = x_field.number
		shape.y = y_field.number
		shape.width = width_field.number
		shape.height = height_field.number
	}
}

draw_editor_world :: proc() {
	if selected_wall != nil {
		draw_shape_lines(selected_wall.shape, selected_wall.pos, SELECTED_OUTLINE_COLOR)
		rl.DrawCircleV(selected_wall.pos, 1, SELECTED_OUTLINE_COLOR)
	}
}

draw_editor_ui :: proc() {
	if selected_wall != nil {
		draw_button(change_shape_but)
		draw_shape_fields()
	}
	draw_button(new_shape_but)
}

draw_shape_fields :: proc() {
	draw_number_field(entity_x_field)
	draw_number_field(entity_y_field)
	draw_number_field(x_field)
	draw_number_field(y_field)
	switch _ in selected_wall.shape {
	case Circle:
		draw_number_field(radius_field)
	case Polygon:
		draw_number_field(rotation_field)
	//TODO: Implement points and rotation
	case Rectangle:
		draw_number_field(width_field)
		draw_number_field(height_field)
	}
}
