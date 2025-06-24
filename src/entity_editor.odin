package game

import "core:fmt"
import "core:math"
import rl "vendor:raylib"


update_entity_editor :: proc(e: ^EditorState) {
	// Ctrl-A
	if rl.IsKeyDown(.LEFT_CONTROL) && rl.IsKeyPressed(.A) {
		e.all_entities_selected = !e.all_entities_selected
		e.selected_entity = .Nil
	}

	if e.all_entities_selected {
		if rl.IsKeyPressed(.UP) {
			level.player_start.y -= TILE_SIZE
			for &enemy in level.enemy_data {
				enemy.pos.y -= TILE_SIZE
			}
			for &barrel in level.exploding_barrels {
				barrel.pos.y -= TILE_SIZE
			}
			for &item in level.items {
				item.pos.y -= TILE_SIZE
			}
		}
		if rl.IsKeyPressed(.DOWN) {
			level.player_start.y += TILE_SIZE
			for &enemy in level.enemy_data {
				enemy.pos.y += TILE_SIZE
			}
			for &barrel in level.exploding_barrels {
				barrel.pos.y += TILE_SIZE
			}
			for &item in level.items {
				item.pos.y += TILE_SIZE
			}
		}
		if rl.IsKeyPressed(.LEFT) {
			level.player_start.x -= TILE_SIZE
			for &enemy in level.enemy_data {
				enemy.pos.x -= TILE_SIZE
			}
			for &barrel in level.exploding_barrels {
				barrel.pos.x -= TILE_SIZE
			}
			for &item in level.items {
				item.pos.x -= TILE_SIZE
			}
		}
		if rl.IsKeyPressed(.RIGHT) {
			level.player_start.x += TILE_SIZE
			for &enemy in level.enemy_data {
				enemy.pos.x += TILE_SIZE
			}
			for &barrel in level.exploding_barrels {
				barrel.pos.x += TILE_SIZE
			}
			for &item in level.items {
				item.pos.x += TILE_SIZE
			}
		}
		return // Skip reset of update function
	}


	// select entity
	outer: if rl.IsMouseButtonPressed(.LEFT) {
		if check_collision_shape_point(PLAYER_SHAPE, level.player_start, mouse_world_pos) {
			e.selected_phys_entity = nil
			e.selected_entity = .Player
			e.entity_mouse_rel_pos = level.player_start - mouse_world_pos
			break outer
		}
		for &data in level.enemy_data {
			if check_collision_shape_point(ENEMY_SHAPE, data.pos, mouse_world_pos) {
				e.selected_phys_entity = nil
				e.selected_entity = .Enemy
				e.selected_enemy = &data
				e.entity_mouse_rel_pos = data.pos - mouse_world_pos
				break outer
			}
		}
		for &barrel in level.exploding_barrels {
			if check_collision_shape_point(barrel.shape, barrel.pos, mouse_world_pos) {
				e.selected_phys_entity = &barrel.physics_entity
				e.selected_entity = .ExplodingBarrel
				e.entity_mouse_rel_pos = barrel.pos - mouse_world_pos
				break outer
			}
		}
		for &item in level.items {
			if check_collision_shape_point(item.shape, item.pos, mouse_world_pos) {
				e.selected_phys_entity = &item.physics_entity
				e.selected_entity = .Item
				e.entity_mouse_rel_pos = item.pos - mouse_world_pos
				break outer
			}
		}
		e.selected_phys_entity = nil
		e.selected_entity = .Nil
	}

	// move entity
	if rl.IsMouseButtonDown(.LEFT) && e.selected_entity != .Nil {
		pos: ^Vec2

		if e.selected_entity == .Player {
			pos = &level.player_start
		} else if e.selected_entity == .Enemy {
			pos = &e.selected_enemy.pos
		} else {
			pos = &e.selected_phys_entity.pos
		}

		snap_size: f32 = 1
		if rl.IsKeyDown(.LEFT_SHIFT) {
			snap_size = TILE_SIZE / 2
		}

		pos.x = math.round((e.entity_mouse_rel_pos.x + mouse_world_pos.x) / snap_size) * snap_size
		pos.y = math.round((e.entity_mouse_rel_pos.y + mouse_world_pos.y) / snap_size) * snap_size
	}

	// rotate enemy
	if rl.IsMouseButtonDown(.RIGHT) && e.selected_entity == .Enemy {
		e.selected_enemy.look_angle = angle(mouse_world_pos - e.selected_enemy.pos)
	}

	// delete entity
	if rl.IsKeyPressed(.DELETE) {
		#partial switch e.selected_entity {
		case .Enemy:
			for data, i in level.enemy_data {
				if data.id == e.selected_enemy.id {
					unordered_remove(&level.enemy_data, i)
					break
				}
			}
		case .ExplodingBarrel:
			if e.selected_phys_entity != nil {
				for barrel, i in level.exploding_barrels {
					if barrel.id == e.selected_phys_entity.id {
						unordered_remove(&level.exploding_barrels, i)
						break
					}
				}
			}
		case .Item:
			if e.selected_phys_entity != nil {
				for item, i in level.items {
					if item.id == e.selected_phys_entity.id {
						unordered_remove(&level.items, i)
						break
					}
				}
			}
		case .Player:
			rl.TraceLog(.WARNING, "You can't delete the player")
		}
		e.selected_phys_entity = nil
		e.selected_entity = .Nil
	}

	// new entity
	if rl.IsKeyDown(.N) {
		if rl.IsKeyPressed(.ONE) {
			// creating new melee enemy
			enemy: Enemy
			enemy.entity = new_entity(mouse_world_pos)
			setup_enemy(&enemy, .Melee)

			append(&level.enemy_data, get_data_from_enemy(enemy))
		} else if rl.IsKeyPressed(.TWO) {
			// creating new melee enemy
			enemy: Enemy
			enemy.entity = new_entity(mouse_world_pos)
			setup_enemy(&enemy, .Ranged)

			append(&level.enemy_data, get_data_from_enemy(enemy))
		} else if rl.IsKeyPressed(.THREE) {
			// creating new item
			item: Item
			item.entity = new_entity(mouse_world_pos)
			item.data = {
				id    = .Bomb,
				count = 1,
			}
			setup_item(&item)

			append(&level.items, item)
		} else if rl.IsKeyPressed(.FOUR) {
			barrel: ExplodingBarrel
			barrel.entity = new_entity(mouse_world_pos)
			setup_exploding_barrel(&barrel)

			append(&level.exploding_barrels, barrel)
		} else if rl.IsKeyPressed(.FIVE) {
			enemy: Enemy
			enemy.entity = new_entity(mouse_world_pos)
			setup_enemy(&enemy, .Turret)

			append(&level.enemy_data, get_data_from_enemy(enemy))
		}
	}

	// copy entity id
	if e.selected_phys_entity != nil && rl.IsKeyPressed(.I) {
		// Copy the regex expression for the first two ints in the id
		rl.SetClipboardText(
			fmt.ctprintf(
				"%v,\\n\\s*%v",
				e.selected_phys_entity.id[0],
				e.selected_phys_entity.id[1],
			),
		)
		rl.TraceLog(.INFO, "ID search copied to clipboard")
	}
	if e.selected_enemy != nil && rl.IsKeyPressed(.I) {
		// Copy the regex expression for the first two ints in the id
		rl.SetClipboardText(
			fmt.ctprintf("%v,\\n\\s*%v", e.selected_enemy.id[0], e.selected_enemy.id[1]),
		)
		rl.TraceLog(.INFO, "ID search copied to clipboard")
	}
}

draw_entity_editor_world :: proc(e: EditorState) {
	// draw selected entity outline
	if e.selected_entity == .Player {
		draw_shape_lines(PLAYER_SHAPE, level.player_start, rl.YELLOW)
	} else if e.selected_entity == .Enemy {
		draw_shape_lines(ENEMY_SHAPE, e.selected_enemy.pos, rl.YELLOW)
	} else if e.selected_entity != .Nil {
		draw_shape_lines(e.selected_phys_entity.shape, e.selected_phys_entity.pos, rl.YELLOW)
	}
}

draw_entity_editor_ui :: proc(e: EditorState) {
	// draw selected entity data
	// draw entity pos
	if e.all_entities_selected {
		rl.DrawText("All entities selected", 30, 60, 20, rl.YELLOW)
	}
	if e.selected_phys_entity != nil {
		rl.DrawText(fmt.ctprintf("%v", e.selected_phys_entity.pos), 30, 60, 20, rl.YELLOW)
	}
	if e.selected_enemy != nil {
		rl.DrawText(fmt.ctprintf("%v", e.selected_enemy.pos), 30, 60, 20, rl.YELLOW)
	}
}
