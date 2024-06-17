package game

import rl "vendor:raylib"

SELECTED_OUTLINE_COLOR :: rl.GREEN
selected_wall: ^PhysicsEntity
selected_wall_index: int = -1

my_but := Button {
	{200, 400, 50, 30},
	"hello",
	.Normal,
	{200, 200, 200, 255},
	{150, 150, 150, 255},
	{100, 100, 100, 255},
}

update_editor :: proc(walls: ^[dynamic]PhysicsEntity, mouse_pos: Vec2) {


	if rl.IsKeyPressed(.BACKSPACE) && selected_wall != nil {
		unordered_remove(walls, selected_wall_index)
		selected_wall = nil
		selected_wall_index = -1
	}

	if rl.IsMouseButtonPressed(.LEFT) {
		selected_wall = nil
		for &wall, index in walls {
			if check_collision_shape_point(wall.shape, wall.pos, mouse_pos) {
				selected_wall = &wall
				selected_wall_index = index
				break
			}
		}
	}
}

draw_editor :: proc() {
	draw_button(my_but)
	if selected_wall != nil {
		draw_shape_lines(selected_wall.shape, selected_wall.pos, SELECTED_OUTLINE_COLOR)
	}

}
