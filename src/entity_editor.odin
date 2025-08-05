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
			level.player_pos.y -= TILE_SIZE
			for &enemy in level.enemies {
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
			level.player_pos.y += TILE_SIZE
			for &enemy in level.enemies {
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
			level.player_pos.x -= TILE_SIZE
			for &enemy in level.enemies {
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
			level.player_pos.x += TILE_SIZE
			for &enemy in level.enemies {
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
		if check_collision_shape_point(PLAYER_SHAPE, level.player_pos, mouse_world_pos) {
			e.selected_phys_entity = nil
			e.selected_entity = .Player
			e.entity_mouse_rel_pos = level.player_pos - mouse_world_pos
			break outer
		}
		for &enemy in level.enemies {
			if check_collision_shape_point(enemy.shape, enemy.pos, mouse_world_pos) {
				e.selected_phys_entity = &enemy.physics_entity
				e.selected_entity = .Enemy
				e.selected_enemy = &enemy
				e.entity_mouse_rel_pos = enemy.pos - mouse_world_pos
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
			pos = &level.player_pos
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
	if e.selected_phys_entity != nil && rl.IsKeyPressed(.DELETE) {
		#partial switch e.selected_entity {
		case .Enemy:
			for enemy, i in level.enemies {
				if enemy.id == e.selected_phys_entity.id {
					unordered_remove(&level.enemies, i)
					break
				}
			}
		case .ExplodingBarrel:
			for barrel, i in level.exploding_barrels {
				if barrel.id == e.selected_phys_entity.id {
					unordered_remove(&level.exploding_barrels, i)
					break
				}
			}
		case .Item:
			for item, i in level.items {
				if item.id == e.selected_phys_entity.id {
					unordered_remove(&level.items, i)
					break
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

			append(&level.enemies, enemy)
		} else if rl.IsKeyPressed(.TWO) {
			// creating new melee enemy
			enemy: Enemy
			enemy.entity = new_entity(mouse_world_pos)
			setup_enemy(&enemy, .Ranged)

			append(&level.enemies, enemy)
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
			turret: Enemy
			turret.entity = new_entity(mouse_world_pos)
			setup_enemy(&turret, .Turret)

			append(&level.enemies, turret)
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
}

draw_entity_editor_world :: proc(e: EditorState) {
	// draw selected entity outline
	if e.selected_entity == .Player {
		draw_shape_lines(PLAYER_SHAPE, level.player_pos, rl.YELLOW)
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
}
