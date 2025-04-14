package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"

update_tutorial_editor :: proc(e: ^EditorState) {
	// selection
	if rl.IsMouseButtonPressed(.LEFT) {
		e.selected_prompt = nil
		e.selected_prompt_idx = -1
		for &prompt, idx in tutorial.prompts {
			rect := get_prompt_rect(prompt)
			mouse_pos := mouse_ui_pos if prompt.on_screen else mouse_world_pos
			if rl.CheckCollisionPointRec(mouse_pos, rect) {
				e.selected_prompt = &prompt
				e.selected_prompt_idx = idx
				e.prompt_mouse_rel_pos =
					{rect.x, rect.y} + {rect.width, rect.height} / 2 - mouse_pos
				break
			}
		}
	}

	// moving
	if rl.IsMouseButtonDown(.LEFT) && e.selected_prompt != nil {
		snap_size: f32 = 0.01 if e.selected_prompt.on_screen else 1

		if !e.selected_prompt.on_screen {
			e.selected_prompt.pos.x =
				math.round((e.prompt_mouse_rel_pos.x + mouse_world_pos.x) / snap_size) * snap_size
			e.selected_prompt.pos.y =
				math.round((e.prompt_mouse_rel_pos.y + mouse_world_pos.y) / snap_size) * snap_size
		} else {
			e.selected_prompt.pos.x =
				math.round(
					(e.prompt_mouse_rel_pos.x + mouse_ui_pos.x) / f32(UI_SIZE.x) / snap_size,
				) *
				snap_size
			e.selected_prompt.pos.y =
				math.round(
					(e.prompt_mouse_rel_pos.y + mouse_ui_pos.y) / f32(UI_SIZE.y) / snap_size,
				) *
				snap_size
		}
	}
}

get_prompt_rect :: proc(prompt: TutorialPrompt) -> Rectangle {
	center := prompt.pos if !prompt.on_screen else prompt.pos * {f32(UI_SIZE.x), f32(UI_SIZE.y)}
	font_size: f32 = 24 if prompt.on_screen else 6
	spacing: f32 = 1
	text := fmt.ctprint(prompt.text)
	pos := get_centered_text_pos(center, text, font_size, spacing)
	size := rl.MeasureTextEx(rl.GetFontDefault(), text, font_size, spacing)
	return Rectangle{pos.x, pos.y, size.x, size.y}
}

draw_tutorial_editor_world :: proc(e: EditorState) {
	for &prompt in tutorial.prompts {
		if !prompt.on_screen {
			font_size: f32 = 6
			spacing: f32 = 1
			text := fmt.ctprint(prompt.text)
			pos := get_centered_text_pos(prompt.pos, text, font_size, spacing)
			rl.DrawTextEx(rl.GetFontDefault(), text, pos, font_size, spacing, rl.WHITE)

			rec := get_prompt_rect(prompt)
			rl.DrawLineEx(
				{rec.x + rec.width / 2, rec.y},
				{rec.x + rec.width / 2, rec.y + rec.height},
				0.5,
				rl.RED,
			)
			rl.DrawLineEx(
				{rec.x, rec.y + rec.height / 2},
				{rec.x + rec.width, rec.y + rec.height / 2},
				0.5,
				rl.RED,
			)
			rl.DrawRectangleLinesEx(rec, 1, rl.YELLOW)
		}
	}
}

draw_tutorial_editor_ui :: proc(e: EditorState) {
	draw_hud({})
	rl.DrawLineEx({f32(UI_SIZE.x) / 2, 0}, {f32(UI_SIZE.x) / 2, f32(UI_SIZE.y)}, 3, rl.RED)
	rl.DrawLineEx({0, f32(UI_SIZE.y) / 2}, {f32(UI_SIZE.x), f32(UI_SIZE.y) / 2}, 3, rl.RED)

	for prompt in tutorial.prompts {
		if prompt.on_screen {
			center := prompt.pos * {f32(UI_SIZE.x), f32(UI_SIZE.y)}
			font_size: f32 = 24
			spacing: f32 = 1
			text := fmt.ctprint(prompt.text)
			pos := get_centered_text_pos(center, text, font_size, spacing)
			rl.DrawTextEx(rl.GetFontDefault(), text, pos, font_size, spacing, rl.WHITE)

			rec := get_prompt_rect(prompt)
			rl.DrawLineEx(
				{rec.x + rec.width / 2, rec.y},
				{rec.x + rec.width / 2, rec.y + rec.height},
				1,
				rl.RED,
			)
			rl.DrawLineEx(
				{rec.x, rec.y + rec.height / 2},
				{rec.x + rec.width, rec.y + rec.height / 2},
				1,
				rl.RED,
			)
			rl.DrawRectangleLinesEx(rec, 1, rl.YELLOW)
		}
	}

}
