package game

import "core:fmt"
import rl "vendor:raylib"


draw_hud :: proc() {
	// Display items
	slot_size :: 48
	margin :: 16
	// Show selected item
	{
		pos := Vec2{16, f32(WINDOW_SIZE.y) - slot_size * 2 - margin}
		rl.DrawRectangleV(pos, slot_size, rl.GRAY)
		tex := loaded_textures[item_to_texture[player.items[player.selected_item_idx].id]]
		src := Rectangle{0, 0, f32(tex.width), f32(tex.height)}
		dst := Rectangle {
			pos.x + slot_size / 2,
			pos.y + slot_size / 2,
			f32(tex.width) * 3,
			f32(tex.height) * 3,
		}
		rl.DrawTexturePro(tex, src, dst, {f32(tex.width), f32(tex.height)} * 1.5, 0, rl.WHITE)
	}

	// Show next and prev item when holding item
	if player.holding_item {
		// prev slot
		if player.item_count > 2 {
			pos := Vec2{16, f32(WINDOW_SIZE.y) - slot_size * 3 - margin}
			rl.DrawRectangleV(pos, slot_size, rl.GRAY)
			tex :=
				loaded_textures[item_to_texture[player.items[(player.selected_item_idx - 1) %% player.item_count].id]]
			src := Rectangle{0, 0, f32(tex.width), f32(tex.height)}
			dst := Rectangle {
				pos.x + slot_size / 2,
				pos.y + slot_size / 2,
				f32(tex.width) * 3,
				f32(tex.height) * 3,
			}
			rl.DrawTexturePro(tex, src, dst, {f32(tex.width), f32(tex.height)} * 1.5, 0, rl.WHITE)
		}

		// next slot
		if player.item_count > 1 {
			pos := Vec2{16, f32(WINDOW_SIZE.y) - slot_size - margin}
			rl.DrawRectangleV(pos, slot_size, rl.GRAY)
			tex :=
				loaded_textures[item_to_texture[player.items[(player.selected_item_idx + 1) %% player.item_count].id]]
			src := Rectangle{0, 0, f32(tex.width), f32(tex.height)}
			dst := Rectangle {
				pos.x + slot_size / 2,
				pos.y + slot_size / 2,
				f32(tex.width) * 3,
				f32(tex.height) * 3,
			}
			rl.DrawTexturePro(tex, src, dst, {f32(tex.width), f32(tex.height)} * 1.5, 0, rl.WHITE)
		}
	}

	// Display weapons
	// Show 1st (bottom) slot
	{
		pos := Vec2 {
			f32(WINDOW_SIZE.x) - slot_size - margin,
			f32(WINDOW_SIZE.y) - slot_size - margin,
		}
		rl.DrawRectangleV(pos, slot_size, rl.GRAY)
		tex := loaded_textures[item_to_texture[player.weapons[0].id]]
		src := Rectangle{0, 0, f32(tex.width), f32(tex.height)}
		dst := Rectangle {
			pos.x + slot_size / 2,
			pos.y + slot_size / 2,
			f32(tex.width) * 3,
			f32(tex.height) * 3,
		}
		rl.DrawTexturePro(tex, src, dst, {f32(tex.width), f32(tex.height)} * 1.5, 0, rl.WHITE)
	}

	// Show 2nd (top) slot
	{
		pos := Vec2 {
			f32(WINDOW_SIZE.x) - slot_size - margin,
			f32(WINDOW_SIZE.y) - slot_size * 2 - margin,
		}
		rl.DrawRectangleV(pos, slot_size, rl.GRAY)
		tex := loaded_textures[item_to_texture[player.weapons[1].id]]
		src := Rectangle{0, 0, f32(tex.width), f32(tex.height)}
		dst := Rectangle {
			pos.x + slot_size / 2,
			pos.y + slot_size / 2,
			f32(tex.width) * 3,
			f32(tex.height) * 3,
		}
		rl.DrawTexturePro(tex, src, dst, {f32(tex.width), f32(tex.height)} * 1.5, 0, rl.WHITE)
	}

	// Show weapon selection
	{
		pos := Vec2 {
			f32(WINDOW_SIZE.x) - slot_size - margin,
			f32(WINDOW_SIZE.y) - slot_size * (1 + f32(player.selected_weapon_idx)) - margin,
		}
		rl.DrawRectangleLinesEx({pos.x, pos.y, slot_size, slot_size}, 3, rl.GOLD)
	}


	// Display Fire Dash Status
	if current_ability == .FIRE {
		if can_fire_dash {
			rl.DrawText("Fire Dash Ready", 1000, 16, 20, rl.ORANGE)
		} else {
			rl.DrawText(fmt.ctprintf("On Cooldown: %f", fire_dash_timer), 1000, 16, 20, rl.WHITE)
		}
	}
}
