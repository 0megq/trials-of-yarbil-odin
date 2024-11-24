package game

import "core:fmt"
import rl "vendor:raylib"


update_entity_editor :: proc(e: ^EditorState) {
	// select entity
	outer: if rl.IsMouseButtonPressed(.LEFT) {
		if check_collision_shape_point(PLAYER_SHAPE, level.player_pos, mouse_world_pos) {
			e.selected_phys_entity = nil
			e.selected_entity = .Player
			break outer
		}
		for &enemy in level.enemies {
			if check_collision_shape_point(enemy.shape, enemy.pos, mouse_world_pos) {
				e.selected_phys_entity = &enemy.physics_entity
				e.selected_entity = .Enemy
				break outer
			}
		}
		for &barrel in level.exploding_barrels {
			if check_collision_shape_point(barrel.shape, barrel.pos, mouse_world_pos) {
				e.selected_phys_entity = &barrel.physics_entity
				e.selected_entity = .ExplodingBarrel
				break outer
			}
		}
		for &item in level.items {
			if check_collision_shape_point(item.shape, item.pos, mouse_world_pos) {
				e.selected_phys_entity = &item.physics_entity
				e.selected_entity = .Item
				break outer
			}
		}
		e.selected_phys_entity = nil
		e.selected_entity = .Nil
	}

	// move entity
	if rl.IsMouseButtonDown(.LEFT) && e.selected_entity != .Nil {
		if e.selected_entity == .Player {
			level.player_pos += mouse_world_delta
		} else {
			e.selected_phys_entity.pos += mouse_world_delta
		}
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
			setup_melee_enemy(&enemy)

			append(&level.enemies, enemy)
		} else if rl.IsKeyPressed(.TWO) {
			// creating new melee enemy
			enemy: Enemy
			enemy.entity = new_entity(mouse_world_pos)
			setup_ranged_enemy(&enemy)

			append(&level.enemies, enemy)
		} else if rl.IsKeyPressed(.THREE) {
			// creating new item
			item: Item
			item.entity = new_entity(mouse_world_pos)
			item.data = {
				id    = .Apple,
				count = 1,
			}
			setup_item(&item)

			append(&level.items, item)
		} else if rl.IsKeyPressed(.FOUR) {
			barrel: ExplodingBarrel
			barrel.entity = new_entity(mouse_world_pos)
			setup_exploding_barrel(&barrel)

			append(&level.exploding_barrels, barrel)
		}
	}

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
	rl.DrawCircleV(level.portal_pos, PORTAL_RADIUS, {50, 50, 50, 255})
}

draw_entity_editor_ui :: proc(e: EditorState) {
	// draw selected entity data
	// draw entity pos
	if e.selected_phys_entity != nil {
		rl.DrawText(fmt.ctprintf("%v", e.selected_phys_entity.pos), 30, 60, 20, rl.BLACK)
	}
}
