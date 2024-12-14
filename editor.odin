package game

EditorState :: struct {
	mode:                 EditorMode,
	show_tile_grid:       bool,

	// Entity editor
	selected_entity:      LevelEntityType,
	selected_phys_entity: ^PhysicsEntity,
	entity_mouse_rel_pos: Vec2,

	// Level editor
	portal_selected:      bool,
	portal_mouse_rel_pos: Vec2,
	selected_wall:        ^PhysicsEntity,
	selected_wall_index:  int,
	wall_mouse_rel_pos:   Vec2,
	half_wall_selected:   bool,

	// Level editor ui
	new_shape_but:        Button,
	change_shape_but:     Button,
	entity_x_field:       NumberField,
	entity_y_field:       NumberField,
	shape_x_field:        NumberField,
	shape_y_field:        NumberField,
	width_field:          NumberField,
	height_field:         NumberField,
	radius_field:         NumberField,

	// // Navmesh editor
	// selected_nav_cell:         ^NavCell,
	// selected_nav_cell_index:   int,
	// selected_point:            ^Vec2,
	// selected_point_cell_index: int,

	// Navgraph editor ui
	display_nav_graph:    bool,
	display_test_path:    bool,
	test_path_start:      Vec2,
	test_path_end:        Vec2,
	test_path:            []Vec2,
}
editor_state: EditorState


init_editor_state :: proc(e: ^EditorState) {
	// Level editor
	e.selected_wall_index = -1

	// Level editor ui
	{
		e.new_shape_but = Button {
			{20, 60, 120, 30},
			"New Shape",
			.Normal,
			{200, 200, 200, 200},
			{150, 150, 150, 200},
			{100, 100, 100, 200},
		}

		e.change_shape_but = Button {
			{20, 100, 120, 30},
			"Change Shape",
			.Normal,
			{200, 200, 200, 200},
			{150, 150, 150, 200},
			{100, 100, 100, 200},
		}

		e.entity_x_field = NumberField {
			{20, 390, 200, 40},
			0,
			"0",
			" E.X ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}

		e.entity_y_field = NumberField {
			{20, 450, 200, 40},
			0,
			"0",
			" E.Y ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}

		e.shape_x_field = NumberField {
			{20, 150, 120, 40},
			0,
			"0",
			" S.X ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}

		e.shape_y_field = NumberField {
			{20, 210, 120, 40},
			0,
			"0",
			" S.Y ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}

		e.radius_field = NumberField {
			{20, 270, 120, 40},
			0,
			"0",
			" R ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}

		e.width_field = NumberField {
			{20, 270, 120, 40},
			0,
			"0",
			" W ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}

		e.height_field = NumberField {
			{20, 330, 120, 40},
			0,
			"0",
			" H ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}
	}
}
