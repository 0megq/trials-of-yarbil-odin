package game

import "base:runtime"
import "core:fmt"
import "core:strconv"
import "core:strings"
import rl "vendor:raylib"

Color :: rl.Color

BUTTON_FONT_SIZE :: 16
NUMBER_FIELD_FONT_SIZE :: 20
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

// Finish this
// Add remove and add buttons
// Swap buttons
// Plan for making this work
// Example
// My points
// 1| x: 10 | y: 20 | + x ^
// + adds a point beneath
// x removes the point
// ^ moves the point up
// update function
// 1. update all the number fields and buttons
// 2. responds to button
// set function

// misc to do
// field and button returns true when its state is changed

VecSliceField :: struct {
	rect:                 Rectangle,
	allocator:            runtime.Allocator,
	default_field:        NumberField,
	fields:               [][2]NumberField,
	default_field_button: Button,
	field_buttons:        [][3]ButtonStatus, // For +, x, ^
	label:                string,
	color:                Color,
}

NumberField :: struct {
	rect:           Rectangle,
	number:         f32,
	current_string: string,
	label:          string,
	selected:       bool,
	cursor_pos:     i32,
	normal_color:   Color,
	selected_color: Color,
}

show_text_cursor: bool = false

set_number_field_value :: proc(field: ^NumberField, value: f32) {
	field.number = value
	delete(field.current_string, context.allocator)
	field.current_string = fmt.aprint(field.number)
}

set_vec_slice_field_value :: proc(slice_field: ^VecSliceField, values: []Vec2) {
	delete_vec_slice(slice_field)
	// Allocate new slices
	slice_field.fields = make([][2]NumberField, len(values), slice_field.allocator)
	slice_field.field_buttons = make([][3]ButtonStatus, len(values), slice_field.allocator)
	//
	for &point, i in slice_field.fields {
		point[0].number = values[i].x
		point[1].number = values[i].y
	}
}

// get_vec_slice_values :: proc(
// 	slice_field: VecSliceField,
// 	allocator := context.temp_allocator,
// ) -> (
// 	result: []Vec2,
// ) {
// 	result = make([]Vec2, )
// }

delete_vec_slice :: proc(slice_field: ^VecSliceField) {
	// NOTE: num field strings do not need to be freed because they should be allocated on the stack ("x", "y")
	delete(slice_field.fields)
	delete(slice_field.field_buttons)
}

update_vec_slice_field :: proc(slice_field: ^VecSliceField, mouse_pos: Vec2) -> bool {

	// for num_field, i in slice_field.fields {

	// }
	return false
}

update_number_field :: proc(field: ^NumberField, mouse_pos: Vec2, offset := Vec2{}) -> bool {
	rect := field.rect
	rect.x += offset.x
	rect.y += offset.y
	number_changed := false
	// Get all keys pressed
	if rl.IsMouseButtonPressed(.LEFT) {
		if check_collision_shape_point(rect, {}, mouse_pos) {
			if !field.selected {
				field.selected = true
				delete(field.current_string, context.allocator)
				field.current_string = fmt.aprint(field.number)
			}

			if len(field.current_string) > 0 {
				label_text := strings.clone_to_cstring(field.label, context.temp_allocator)
				label_width := f32(rl.MeasureText(label_text, NUMBER_FIELD_FONT_SIZE))

				// Getting cursor position - TODO: Make this work on a per character basis rather than averaging
				text_width := rl.MeasureText(
					strings.clone_to_cstring(field.current_string, context.temp_allocator),
					NUMBER_FIELD_FONT_SIZE,
				)
				avg_character_width := text_width / i32(len(field.current_string))
				text_start :=
					rect.x + label_width + (rect.width - label_width - f32(text_width)) / 2
				field.cursor_pos = i32((mouse_pos.x - text_start)) / avg_character_width
				// bounds
				field.cursor_pos = max(field.cursor_pos, 0)
				field.cursor_pos = min(field.cursor_pos, i32(len(field.current_string)))
			}
		} else if field.selected { 	// Cancel the input if clicked outside of field
			field.selected = false
			delete(field.current_string, context.allocator)
			field.current_string = fmt.aprint(field.number)
		}
	}

	if field.selected {
		for key := rl.GetKeyPressed(); key != .KEY_NULL; key = rl.GetKeyPressed() {
			add_char :: proc(field: ^NumberField, input_char: string) {
				start := ""
				if field.cursor_pos != 0 {
					start = strings.cut(field.current_string, 0, int(field.cursor_pos))
				}

				end := strings.cut(
					field.current_string,
					int(field.cursor_pos),
					len(field.current_string) - int(field.cursor_pos),
				)
				delete(field.current_string, context.allocator)
				field.current_string = strings.join({start, input_char, end}, "")
				field.cursor_pos += 1
			}
			#partial switch key {
			case .ENTER:
				field.selected = false
				if value, ok := strconv.parse_f32(field.current_string); ok {
					field.number = value
					number_changed = true
				}
				delete(field.current_string, context.allocator)
				field.current_string = fmt.aprint(field.number)
			case .BACKSPACE:
				if field.cursor_pos > 0 {
					// Delete the number before the cursor position

					start := ""
					if field.cursor_pos != 1 {
						start = strings.cut(field.current_string, 0, int(field.cursor_pos) - 1)
					}
					end := strings.cut(
						field.current_string,
						int(field.cursor_pos),
						len(field.current_string) - int(field.cursor_pos),
					)
					delete(field.current_string, context.allocator)
					field.current_string = strings.join({start, end}, "")
					field.cursor_pos -= 1
				}
			case .DELETE:
				if field.cursor_pos < i32(len(field.current_string)) {
					// Delete the number after the cursor position
					start := ""
					if field.cursor_pos != 0 {
						start = strings.cut(field.current_string, 0, int(field.cursor_pos))
					}

					end := strings.cut(
						field.current_string,
						int(field.cursor_pos) + 1,
						len(field.current_string) - int(field.cursor_pos),
					)
					delete(field.current_string, context.allocator)
					field.current_string = strings.join({start, end}, "")
				}
			case .LEFT:
				if field.cursor_pos > 0 {
					field.cursor_pos -= 1
				}
			case .RIGHT:
				number_length := i32(len(field.current_string))
				if field.cursor_pos < number_length {
					field.cursor_pos += 1
				}
			case .HOME:
				field.cursor_pos = 0
			case .END:
				field.cursor_pos = i32(len(field.current_string))
			case .PERIOD:
				add_char(field, ".")
			case .MINUS:
				add_char(field, "-")
			case:
				if (key >= .ZERO && key <= .NINE) {
					add_char(field, fmt.tprint(int(key - .ZERO)))
				}
			}
		}
	}
	return number_changed
}

// Returns true if the button status was changed. Offset is used to offset the button's rectangle when checking for collision with mouse
update_button :: proc(button: ^Button, mouse_pos: Vec2, offset := Vec2{}) -> bool {
	rect := button.rect
	rect.x += offset.x
	rect.y += offset.y
	prev_status := button.status
	touching_mouse := check_collision_shape_point(rect, {}, mouse_pos)
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
	return button.status != prev_status
}

draw_vec_slice_field :: proc(field: VecSliceField) {

}

draw_number_field :: proc(field: NumberField, offset := Vec2{}) {
	rect := field.rect
	rect.x += offset.x
	rect.y += offset.y
	// Draw label
	label_text := strings.clone_to_cstring(field.label, context.temp_allocator)
	label_width := f32(rl.MeasureText(label_text, NUMBER_FIELD_FONT_SIZE))
	label_pos: Vec2i = {i32(rect.x), i32(rect.y + rect.height / 2) - NUMBER_FIELD_FONT_SIZE / 2}
	rl.DrawRectangle(
		label_pos.x,
		i32(rect.y),
		i32(label_width),
		i32(rect.height),
		field.normal_color,
	)
	rl.DrawText(label_text, label_pos.x, label_pos.y, NUMBER_FIELD_FONT_SIZE, rl.BLACK)

	// Draw Rectangle
	color := field.selected_color if field.selected else field.normal_color
	rl.DrawRectangleRec(
		{rect.x + label_width, rect.y, rect.width - label_width, rect.height},
		color,
	)

	// Draw field value
	text := strings.clone_to_cstring(field.current_string, context.temp_allocator)
	text_width := f32(rl.MeasureText(text, NUMBER_FIELD_FONT_SIZE))
	text_pos: Vec2 = {
		rect.x + label_width + (rect.width - label_width - text_width) / 2,
		rect.y + (rect.height - NUMBER_FIELD_FONT_SIZE) / 2,
	}

	rl.DrawText(text, i32(text_pos.x), i32(text_pos.y), NUMBER_FIELD_FONT_SIZE, rl.BLACK)

	if field.selected && show_text_cursor {
		avg_character_width := text_width / f32(len(text))
		line_x := text_pos.x + f32(field.cursor_pos) * avg_character_width
		rl.DrawLineV({line_x, text_pos.y}, {line_x, text_pos.y + NUMBER_FIELD_FONT_SIZE}, rl.BLACK)
		rl.DrawLineV(
			{line_x, text_pos.y + NUMBER_FIELD_FONT_SIZE},
			{line_x + avg_character_width, text_pos.y + NUMBER_FIELD_FONT_SIZE},
			rl.BLACK,
		)
	}
}

draw_button :: proc(button: Button, offset := Vec2{}) {
	rect := button.rect
	rect.x += offset.x
	rect.y += offset.y
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

	rl.DrawRectangleRec(rect, color)

	text := strings.clone_to_cstring(button.text, context.temp_allocator)

	text_width := rl.MeasureText(text, BUTTON_FONT_SIZE)

	text_pos: Vec2 = get_center(rect) - {f32(text_width), f32(BUTTON_FONT_SIZE)} / 2

	rl.DrawText(text, i32(text_pos.x), i32(text_pos.y), BUTTON_FONT_SIZE, rl.BLACK)
}

toggle_text_cursor :: proc() {
	show_text_cursor = !show_text_cursor
}
