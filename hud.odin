package game

import "core:fmt"
import rl "vendor:raylib"


draw_hud :: proc() {
	slot_size :: 48
	margin :: 16
	// Display items
	if !(level.has_tutorial && tutorial.hide_item_hud) {
		// Show selected item
		{
			selected_item := player.items[player.selected_item_idx]

			pos := Vec2{16, f32(UI_SIZE.y) - slot_size * 2 - margin}
			rl.DrawRectangleV(pos, slot_size, rl.GRAY)
			rl.DrawRectangleLinesEx({pos.x, pos.y, slot_size, slot_size}, 2, rl.GOLD)
			tex := loaded_textures[item_to_texture[selected_item.id]]
			src := Rectangle{0, 0, f32(tex.width), f32(tex.height)}
			dst := Rectangle {
				pos.x + slot_size / 2,
				pos.y + slot_size / 2,
				f32(tex.width) * 3,
				f32(tex.height) * 3,
			}
			if selected_item.count != 0 && selected_item.id != .Empty {
				rl.DrawTexturePro(
					tex,
					src,
					dst,
					{f32(tex.width), f32(tex.height)} * 1.5,
					0,
					rl.WHITE,
				)
				// Show count
				rl.DrawText(
					fmt.ctprintf("% 2d", selected_item.count),
					i32(pos.x) + slot_size / 2,
					i32(pos.y) + slot_size / 2 - 12,
					12,
					rl.BLACK,
				)
			}
		}

		// Show next and prev item when holding item
		// prev item slot
		{
			pos := Vec2{16, f32(UI_SIZE.y) - slot_size * 3 - margin}
			rl.DrawRectangleV(pos, slot_size, rl.GRAY)
			if player.item_count > 2 {
				tex :=
					loaded_textures[item_to_texture[player.items[(player.selected_item_idx - 1) %% player.item_count].id]]
				src := Rectangle{0, 0, f32(tex.width), f32(tex.height)}
				dst := Rectangle {
					pos.x + slot_size / 2,
					pos.y + slot_size / 2,
					f32(tex.width) * 3,
					f32(tex.height) * 3,
				}
				rl.DrawTexturePro(
					tex,
					src,
					dst,
					{f32(tex.width), f32(tex.height)} * 1.5,
					0,
					rl.WHITE,
				)
			}
		}

		// next item slot
		{
			pos := Vec2{16, f32(UI_SIZE.y) - slot_size - margin}
			rl.DrawRectangleV(pos, slot_size, rl.GRAY)
			if player.item_count > 1 {
				tex :=
					loaded_textures[item_to_texture[player.items[(player.selected_item_idx + 1) %% player.item_count].id]]
				src := Rectangle{0, 0, f32(tex.width), f32(tex.height)}
				dst := Rectangle {
					pos.x + slot_size / 2,
					pos.y + slot_size / 2,
					f32(tex.width) * 3,
					f32(tex.height) * 3,
				}
				rl.DrawTexturePro(
					tex,
					src,
					dst,
					{f32(tex.width), f32(tex.height)} * 1.5,
					0,
					rl.WHITE,
				)
			}
		}
	}

	// Display weapons
	if !(level.has_tutorial && tutorial.hide_weapon_hud) {
		// Show 1st (bottom) slot
		{
			pos := Vec2{f32(UI_SIZE.x) - slot_size - margin, f32(UI_SIZE.y) - slot_size - margin}
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
				f32(UI_SIZE.x) - slot_size - margin,
				f32(UI_SIZE.y) - slot_size * 2 - margin,
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
				f32(UI_SIZE.x) - slot_size - margin,
				f32(UI_SIZE.y) - slot_size * (1 + f32(player.selected_weapon_idx)) - margin,
			}

			// Show durability
			if weapon := player.weapons[player.selected_weapon_idx]; weapon.id != .Empty {
				bar_margin :: 4

				durability_bar_length: f32 = slot_size - bar_margin * 2
				durability_bar_height: f32 = durability_bar_length / 4
				durability_bar_base_rec := rl.Rectangle {
					pos.x + bar_margin,
					pos.y + slot_size - durability_bar_height - bar_margin,
					durability_bar_length,
					durability_bar_height,
				}
				rl.DrawRectangleRec(durability_bar_base_rec, rl.BLACK)
				durability_bar_filled_rec := durability_bar_base_rec
				durability_bar_filled_rec.width *= f32(weapon.count) / f32(weapon.max_count)
				rl.DrawRectangleRec(durability_bar_filled_rec, rl.GREEN)
			}

			if player.attacking {
				rl.DrawRectangleRec({pos.x, pos.y, slot_size, slot_size}, Color{0, 0, 0, 70})
			} else if !player.can_attack {
				// Value from 0 to 1. Starts at 1 then decreases
				cooldown_ratio := player.attack_interval_timer / ATTACK_INTERVAL
				// Display
				rl.DrawRectangleRec(
					{
						pos.x + slot_size * (1 - cooldown_ratio),
						pos.y,
						slot_size * cooldown_ratio,
						slot_size,
					},
					Color{0, 0, 0, 70},
				)
			}

			rl.DrawRectangleLinesEx({pos.x, pos.y, slot_size, slot_size}, 2, rl.GOLD)
		}
	}

	// Display ability HUD
	if !(level.has_tutorial && tutorial.disable_ability) {
		// Fire Dash Status
		if player.cur_ability == .FIRE {
			if player.can_fire_dash {
				rl.DrawText("Fire Dash Ready", 16, 16, 20, rl.ORANGE)
			} else {
				rl.DrawText(
					fmt.ctprintf("On Cooldown: %f", player.fire_dash_timer),
					16,
					16,
					20,
					rl.WHITE,
				)
			}
		}
	}
}
