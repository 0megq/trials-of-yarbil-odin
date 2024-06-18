package game

import "core:fmt"
import "core:strings"
import "core:strconv"
import rl "vendor:raylib"

Color :: rl.Color

BUTTON_FONT_SIZE :: 16
NUMBER_FIELD_FONT_SIZE :: 12
TEXT_CURSOR_TOGGLE_INTERVAL :: 0.5

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

NumberField :: struct {
	rect:           Rectangle,
	number:   		f32,
	selected:       bool,
	cursor_pos:     i32,
	normal_color:   Color,
	selected_color: Color,
}

show_text_cursor: bool = false

update_number_field :: proc(field: ^NumberField, mouse_pos: Vec2) {
	// Get all keys pressed
	if field.selected {
		for key := rl.GetKeyPressed(); key != .KEY_NULL; key = rl.GetKeyPressed() {
			validate_number_input :: proc(field: ^NumberField, input_char: string) {
				string_number := fmt.tprint(field.number)
				// Add the number at the cursor position
				new_string := strings.join([]string{string_number, input_char}, "")
				if value, ok := strconv.parse_f32(new_string); ok {
					field.number = value
					field.cursor_pos += 1
				}
			}
			#partial switch key {
			case .ENTER:
				field.selected = false
			case .BACKSPACE: // TODO
				field.cursor_pos -= 1
			case .DELETE: // TODO

			case .LEFT:
				if field.cursor_pos > 0 {
					field.cursor_pos -= 1
				}
			case .RIGHT:
				number_length := i32(len(fmt.tprint(field.number)))
				if field.cursor_pos < number_length {
					field.cursor_pos += 1
				}
			case .HOME:
				field.cursor_pos = 0
			case .END:
				field.cursor_pos = i32(len(fmt.tprint(field.number)))
			case .PERIOD:
				validate_number_input(field, ".")
			case .MINUS:
				validate_number_input(field, "-")
			case:
				if (key >= .ZERO && key <= .NINE)  {
					validate_number_input(field, fmt.tprint(int(key - .ZERO)))
				}
			}
		}
	} else {
		if check_collision_shape_point(field.rect, {}, mouse_pos) && rl.IsMouseButtonPressed(.LEFT) {
			field.selected = true

			// Getting cursor position - TODO: Make this work on a per character basis rather than averaging
			str := fmt.ctprintf("%v", field.number)

			text_width := rl.MeasureText(str, NUMBER_FIELD_FONT_SIZE)
			avg_character_width := text_width / i32(len(str))
			text_start := field.rect.x + (field.rect.width - f32(text_width)) / 2
			field.cursor_pos = i32((mouse_pos.x - text_start)) / avg_character_width
			// bounds
			field.cursor_pos = max(field.cursor_pos, 0)
			field.cursor_pos = min(field.cursor_pos, i32(len(str)))
		}
	}
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

draw_number_field :: proc(field: NumberField) {
	color := field.selected_color if field.selected else field.normal_color

	rl.DrawRectangleRec(field.rect, color)

	text := fmt.ctprintf("%v", field.number)

	text_width := rl.MeasureText(text, NUMBER_FIELD_FONT_SIZE)

	text_pos: Vec2 = get_center(field.rect) - {f32(text_width), f32(NUMBER_FIELD_FONT_SIZE)} / 2

	rl.DrawText(text, i32(text_pos.x), i32(text_pos.y), NUMBER_FIELD_FONT_SIZE, rl.BLACK)

	if field.selected && show_text_cursor {
		line_x := text_pos.x + f32(field.cursor_pos * text_width) / f32(len(text))
		rl.DrawLineV({line_x, text_pos.y}, {line_x, text_pos.y + NUMBER_FIELD_FONT_SIZE}, rl.BLACK)
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

	text_width := rl.MeasureText(text, BUTTON_FONT_SIZE)

	text_pos: Vec2 = get_center(button.rect) - {f32(text_width), f32(BUTTON_FONT_SIZE)} / 2

	rl.DrawText(text, i32(text_pos.x), i32(text_pos.y), BUTTON_FONT_SIZE, rl.BLACK)
}

toggle_text_cursor :: proc() {
	show_text_cursor = !show_text_cursor
}

