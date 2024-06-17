package game

import "core:strings"
import rl "vendor:raylib"

Color :: rl.Color

ButtonStatus :: enum {
	Normal,
	Hovered,
	Pressed,
	Down,
	Released,
}

Button :: struct {
	rect:          Rectangle,
	text:          string,
	status:        ButtonStatus,
	normal_color:  Color,
	hover_color:   Color,
	pressed_color: Color,
}

update_button :: proc(button: ^Button, mouse_pos: Vec2) {
	touching_mouse := check_collision_shape_point(button.rect, {}, mouse_pos)
	mouse_pressed := rl.IsMouseButtonPressed(.LEFT)
	mouse_down := rl.IsMouseButtonDown(.LEFT)
	mouse_released := rl.IsMouseButtonReleased(.LEFT)
	switch button.status {
	case .Normal:
		if touching_mouse {
			if mouse_pressed { 	// If mouse entered and touching at same instant then register a press
				button.status = .Pressed
			} else if !mouse_down { 	// If mouse is not down before entering then hover
				button.status = .Hovered
			}
		}
	case .Hovered:
		if !touching_mouse {
			button.status = .Normal
		} else if mouse_pressed {
			button.status = .Pressed
		}
	case .Pressed:
		if !touching_mouse {
			button.status = .Normal
		} else if mouse_down {
			button.status = .Down
		} else if mouse_released {
			button.status = .Released
		} else {
			button.status = .Normal
		}
	case .Down:
		if !touching_mouse {
			button.status = .Normal
		} else if mouse_released {
			button.status = .Released
		} else if !mouse_down {
			button.status = .Hovered
		}
	case .Released:
		if touching_mouse {
			if mouse_pressed {
				button.status = .Pressed
			} else {
				button.status = .Hovered
			}
		} else {
			button.status = .Normal
		}
	}
}

draw_button :: proc(button: Button) {
	color: Color
	switch button.status {
	case .Normal:
		color = button.normal_color
	case .Hovered:
		color = button.hover_color
	case .Pressed:
		color = button.pressed_color
	case .Down:
		color = button.pressed_color
	case .Released:
		color = button.hover_color
	}

	rl.DrawRectangleRec(button.rect, color)

	text := strings.clone_to_cstring(button.text, context.temp_allocator)

	font_size: i32 = 20
	text_width := rl.MeasureText(text, font_size)

	text_pos: Vec2 = get_center(button.rect) - {f32(text_width), f32(font_size)} / 2

	rl.DrawText(text, i32(text_pos.x), i32(text_pos.y), font_size, rl.BLACK)
}
