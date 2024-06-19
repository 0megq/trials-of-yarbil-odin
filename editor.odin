package game

import rl "vendor:raylib"

SELECTED_OUTLINE_COLOR :: rl.GREEN
selected_wall: ^PhysicsEntity
selected_wall_index: int = -1

new_shape_but := Button {
	{20, 100, 120, 30},
	"New Shape",
	.Normal,
	{200, 200, 200, 200},
	{150, 150, 150, 200},
	{100, 100, 100, 200},
}

// Game plan:
// Switch case for union type
// When a shape is selected set the fields to their values
// Display and update different fields
// Editing fields changes values of shapes
// Polygon
// Add point button, reorder points

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

update_editor :: proc(
	walls: ^[dynamic]PhysicsEntity,
	mouse_pos: Vec2,
	mouse_delta: Vec2,
	mouse_world_pos: Vec2,
	mouse_world_delta: Vec2,
) {
	update_button(&new_shape_but, mouse_pos)
	update_number_field(&x_field, mouse_pos)
	update_number_field(&y_field, mouse_pos)
	update_number_field(&width_field, mouse_pos)
	update_number_field(&height_field, mouse_pos)

	if new_shape_but.status == .Released {
		append(walls, PhysicsEntity{{}, Circle{{}, 20}})
		selected_wall_index = len(walls) - 1
		selected_wall = &walls[selected_wall_index]
	}

	update_shape_fields(mouse_pos)

	// Deleting shapes
	if rl.IsKeyPressed(.BACKSPACE) && selected_wall != nil {
		unordered_remove(walls, selected_wall_index)
		selected_wall = nil
		selected_wall_index = -1
	}

	// Selecting shapes
	if rl.IsMouseButtonPressed(.LEFT) {
		selected_wall = nil
		for &wall, index in walls {
			if check_collision_shape_point(wall.shape, wall.pos, mouse_world_pos) {
				selected_wall = &wall
				selected_wall_index = index
				break
			}
		}
	} else if rl.IsMouseButtonDown(.LEFT) && selected_wall != nil { 	// Moving shape
		selected_wall.pos += mouse_world_delta
	}
}

update_shape_fields :: proc(mouse_pos: Vec2) {
	if selected_wall != nil {
		switch _ in selected_wall.shape {
			case Circle:

			case Polygon:

			case Rectangle:
		}
	}
}

draw_editor_world :: proc() {
	if selected_wall != nil {
		draw_shape_lines(selected_wall.shape, selected_wall.pos, SELECTED_OUTLINE_COLOR)
	}
}

draw_editor_ui :: proc() {
	draw_shape_fields()
	draw_button(new_shape_but)
}

draw_shape_fields :: proc() {
	draw_number_field(x_field)
	draw_number_field(y_field)
	draw_number_field(width_field)
	draw_number_field(height_field)

}
