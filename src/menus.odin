package game


setup_main_menu :: proc() {
	// Place and position buttons
	but_count: f32 = 2
	but_height: f32 = 60
	but_width: f32 = 200
	but_margin: f32 = 20
	all_button_size: f32 = but_count * but_height + (but_count - 1) * but_margin
	cur_y := f32(UI_SIZE.y) / 2 - all_button_size / 2
	cur_x := f32(UI_SIZE.x) / 2

	main_menu.play_button.rect = get_centered_rect({cur_x, cur_y}, {but_width, but_height})

	cur_y += but_height + but_margin
	main_menu.quit_button.rect = get_centered_rect({cur_x, cur_y}, {but_width, but_height})

	// Text Setup
	main_menu.play_button.text = "Play"
	main_menu.quit_button.text = "Quit"

	// Colors
	style := ButtonStyle {
		normal_color  = {255, 255, 255, 255},
		hover_color   = {200, 200, 200, 255},
		pressed_color = {180, 180, 180, 255},
	}
	main_menu.play_button.style = style
	main_menu.quit_button.style = style
}

setup_pause_menu :: proc() {
	// Place and position buttons
	but_count: f32 = 2
	but_height: f32 = 0.1 * f32(UI_SIZE.y)
	but_width: f32 = 0.2 * f32(UI_SIZE.x)
	but_margin: f32 = 0.3 * but_height
	all_button_size: f32 = but_count * but_height + (but_count - 1) * but_margin
	cur_y := f32(UI_SIZE.y) / 2 - all_button_size / 2
	cur_x := f32(UI_SIZE.x) / 2

	pause_menu.resume_button.rect = get_centered_rect({cur_x, cur_y}, {but_width, but_height})

	cur_y += but_height + but_margin
	pause_menu.main_menu_button.rect = get_centered_rect({cur_x, cur_y}, {but_width, but_height})

	// Text Setup
	pause_menu.resume_button.text = "Resume"
	pause_menu.main_menu_button.text = "Main Menu"

	// Colors
	style := ButtonStyle {
		normal_color  = {255, 255, 255, 255},
		hover_color   = {200, 200, 200, 255},
		pressed_color = {180, 180, 180, 255},
	}
	pause_menu.resume_button.style = style
	pause_menu.main_menu_button.style = style
}
