package game

import rl "vendor:raylib"

SELECTED_OUTLINE_COLOR :: rl.GREEN
selected_wall: ^PhysicsEntity
selected_wall_index: int = -1

// TODO: Make the editor render outside the game canvas.
new_shape := Button {
	{10, 100, 150, 30},
	"New Shape",
	.Normal,
	{200, 200, 200, 255},
	{150, 150, 150, 255},
	{100, 100, 100, 255},
}

update_editor :: proc(walls: ^[dynamic]PhysicsEntity, mouse_pos: Vec2, mouse_delta: Vec2) {
	update_button(&new_shape, mouse_pos)
	update_number_field(nil, mouse_pos)

	if new_shape.status == .Released {
		append(walls, PhysicsEntity{{}, Circle{{}, 20}})
		selected_wall_index = len(walls) - 1
		selected_wall = &walls[selected_wall_index]
	}

	// Update property fields ui
	if selected_wall != nil {
		update_number_field(nil, mouse_pos)
	}

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
			if check_collision_shape_point(wall.shape, wall.pos, mouse_pos) {
				selected_wall = &wall
				selected_wall_index = index
				break
			}
		}
	} else if rl.IsMouseButtonDown(.LEFT) && selected_wall != nil { 	// Moving shape
		selected_wall.pos += mouse_delta
	}
}

draw_editor :: proc() {
	draw_button(new_shape)
	if selected_wall != nil {
		draw_shape_lines(selected_wall.shape, selected_wall.pos, SELECTED_OUTLINE_COLOR)
	}

}
