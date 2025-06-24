package game

import "core:strings"
import rl "vendor:raylib"

EditorState :: struct {
	mode:                  EditorMode,
	show_tile_grid:        bool,

	// Tutorial editor
	selected_prompt:       ^TutorialPrompt,
	selected_prompt_idx:   int,
	prompt_mouse_rel_pos:  Vec2,

	// Tutorial editor ui
	// new_prompt_button:    Button,
	// prompt_buttons:       [dynamic]Button,

	// Entity editor
	selected_entity:       LevelEntityType,
	selected_phys_entity:  ^PhysicsEntity,
	selected_enemy:        ^EnemyData,
	entity_mouse_rel_pos:  Vec2,
	all_entities_selected: bool,

	// Level editor
	portal_selected:       bool,
	portal_mouse_rel_pos:  Vec2,
	selected_wall:         ^PhysicsEntity,
	selected_wall_index:   int,
	wall_mouse_rel_pos:    Vec2,
	half_wall_selected:    bool,
	all_geometry_selected: bool,

	// Level editor ui
	new_shape_but:         Button,
	change_shape_but:      Button,
	entity_x_field:        NumberField,
	entity_y_field:        NumberField,
	shape_x_field:         NumberField,
	shape_y_field:         NumberField,
	width_field:           NumberField,
	height_field:          NumberField,
	radius_field:          NumberField,

	// // Navmesh editor
	// selected_nav_cell:         ^NavCell,
	// selected_nav_cell_index:   int,
	// selected_point:            ^Vec2,
	// selected_point_cell_index: int,

	// Navgraph editor ui
	display_nav_graph:     bool,
	display_test_path:     bool,
	test_path_start:       Vec2,
	test_path_end:         Vec2,
	test_path:             []Vec2,
}
editor_state: EditorState


init_editor_state :: proc(e: ^EditorState, first := false) {
	if !first {
		destruct_editor_state(e)
	}

	// Tutorial editor
	e.selected_prompt = nil
	e.selected_prompt_idx = -1

	// Tutorial editor ui
	{
		// e.new_prompt_button = Button {
		// 	{20, 60, 120, 30},
		// 	"New Prompt",
		// 	.Normal,
		// 	{200, 200, 200, 200},
		// 	{150, 150, 150, 200},
		// 	{100, 100, 100, 200},
		// }
		// base := Button {
		// 	{20, 60, 120, 30},
		// 	"Text",
		// 	.Normal,
		// 	{200, 200, 200, 200},
		// 	{150, 150, 150, 200},
		// 	{100, 100, 100, 200},
		// }
		// for prompt in tutorial.prompts {
		// 	append(&e.prompt_buttons, Button{})
		// }
	}

	// Entity editor
	e.selected_entity = .Nil
	e.selected_phys_entity = nil

	// Level editor
	e.portal_selected = false
	e.selected_wall = nil
	e.selected_wall_index = -1

	// Level editor ui
	{
		e.new_shape_but = Button {
			{20, 60, 120, 30},
			"New Shape",
			.Normal,
			{{200, 200, 200, 200}, {150, 150, 150, 200}, {100, 100, 100, 200}},
		}

		e.change_shape_but = Button {
			{20, 100, 120, 30},
			"Change Shape",
			.Normal,
			{{200, 200, 200, 200}, {150, 150, 150, 200}, {100, 100, 100, 200}},
		}

		e.entity_x_field = NumberField {
			{20, 390, 200, 40},
			0,
			strings.clone("0"),
			" E.X ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}

		e.entity_y_field = NumberField {
			{20, 450, 200, 40},
			0,
			strings.clone("0"),
			" E.Y ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}

		e.shape_x_field = NumberField {
			{20, 150, 120, 40},
			0,
			strings.clone("0"),
			" S.X ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}

		e.shape_y_field = NumberField {
			{20, 210, 120, 40},
			0,
			strings.clone("0"),
			" S.Y ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}

		e.radius_field = NumberField {
			{20, 270, 120, 40},
			0,
			strings.clone("0"),
			" R ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}

		e.width_field = NumberField {
			{20, 270, 120, 40},
			0,
			strings.clone("0"),
			" W ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}

		e.height_field = NumberField {
			{20, 330, 120, 40},
			0,
			strings.clone("0"),
			" H ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}
	}
}

destruct_editor_state :: proc(e: ^EditorState) {
	delete(e.entity_x_field.current_string)
	delete(e.entity_y_field.current_string)
	delete(e.shape_x_field.current_string)
	delete(e.shape_y_field.current_string)
	delete(e.radius_field.current_string)
	delete(e.width_field.current_string)
	delete(e.height_field.current_string)
}

draw_level :: proc(show_tile_grid := false) {
	draw_tilemap(level_tilemap, show_tile_grid)

	rl.DrawCircleV(level.portal_pos, PORTAL_RADIUS, {50, 50, 50, 255})

	for wall in level.half_walls {
		in_current_stage :=
			wall.enter_stage_idx <= level.cur_stage_idx &&
			level.cur_stage_idx <= wall.exit_stage_idx
		if !in_current_stage do continue
		draw_shape(wall.shape, wall.pos, rl.LIGHTGRAY)
	}

	for item in level.items {
		in_current_stage :=
			item.enter_stage_idx <= level.cur_stage_idx &&
			level.cur_stage_idx <= item.exit_stage_idx
		if !in_current_stage do continue
		tex_id := item_to_texture[item.data.id]
		tex := loaded_textures[tex_id]
		sprite: Sprite = {
			tex_id,
			{0, 0, f32(tex.width), f32(tex.height)},
			{1, 1},
			{f32(tex.width) / 2, f32(tex.height) / 2},
			0,
			rl.LIGHTGRAY, // Slight darker tint
		}

		draw_sprite(sprite, item.pos)
	}

	for wall in level.walls {
		in_current_stage :=
			wall.enter_stage_idx <= level.cur_stage_idx &&
			level.cur_stage_idx <= wall.exit_stage_idx
		if !in_current_stage do continue
		draw_shape(wall.shape, wall.pos, rl.GRAY)
	}

	for data in level.enemy_data {
		in_current_stage :=
			data.enter_stage_idx <= level.cur_stage_idx &&
			level.cur_stage_idx <= data.exit_stage_idx
		if !in_current_stage do continue
		enemy := get_enemy_from_data(data, .Nil)
		enemy.draw_proc(enemy, true)
	}

	for barrel in level.exploding_barrels {
		in_current_stage :=
			barrel.enter_stage_idx <= level.cur_stage_idx &&
			level.cur_stage_idx <= barrel.exit_stage_idx
		if !in_current_stage do continue
		draw_sprite(BARREL_SPRITE, barrel.pos)
	}

	draw_sprite(PLAYER_SPRITE, level.player_start)

	rl.DrawRectangleRec(level.bounds, {0, 0, 120, 100})

	// if level.has_tutorial {
	// 	for prompt in tutorial.prompts {
	// 		if !prompt.on_screen {
	// 			font_size: f32 = 6
	// 			spacing: f32 = 1
	// 			text := fmt.ctprint(prompt.text)
	// 			pos := get_centered_text_pos(prompt.pos, text, font_size, spacing)
	// 			text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, font_size, spacing)
	// 			rl.DrawRectangleLinesEx({pos.x, pos.y, text_size.x, text_size.y}, 0.5, rl.YELLOW)
	// 		}
	// 	}
	// }
}
