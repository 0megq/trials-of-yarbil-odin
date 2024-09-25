package game

import "core:encoding/json"
import "core:fmt"
import "core:os"
import rl "vendor:raylib"

ENTITY_LOAD_FILE_PATH :: "entity.json"
ENTITY_SAVE_FILE_PATH :: "entity.json"

selected_entity: EntityType
selected_phys_entity: ^PhysicsEntity

// This is the only data that gets saved for entities
EntityData :: struct {
	player_pos:        Vec2,
	enemies:           [dynamic]Enemy,
	items:             [dynamic]Item,
	exploding_barrels: [dynamic]ExplodingBarrel,
}

load_entities :: proc() {
	// Load EntityData struct from json file
	// generate new uuid's

	data := EntityData{}

	if bytes, ok := os.read_entire_file(ENTITY_LOAD_FILE_PATH, context.allocator); ok {
		if json.unmarshal(bytes, &data) != nil {
			rl.TraceLog(.WARNING, "Error parsing entity data")
			setup_default_entities()
		} else {
			player = new_player(data.player_pos)
			enemies = data.enemies
			items = data.items
			exploding_barrels = data.exploding_barrels
		}

		delete(bytes)
	} else {
		rl.TraceLog(.WARNING, "Error parsing entity data")
		setup_default_entities()
	}

	rl.TraceLog(.INFO, "Entities Loaded")
}

save_entities :: proc() {
	// Save EntityData struct to json file

	data := EntityData{player.pos, enemies, items, exploding_barrels}

	if bytes, err := json.marshal(data, allocator = context.allocator, opt = {pretty = true});
	   err == nil {
		os.write_entire_file(ENTITY_SAVE_FILE_PATH, bytes)
		delete(bytes)
	} else {
		rl.TraceLog(.WARNING, "Error saving entity data")
	}

	rl.TraceLog(.INFO, "Entities Saved")
}

unload_entities :: proc() {
	// Unload entity data AKA delete memory
	delete(enemies)
	delete(items)
	delete(exploding_barrels)

	rl.TraceLog(.INFO, "Entities Unloaded")
}

update_entity_editor :: proc() {
	// select entity
	outer: if rl.IsMouseButtonPressed(.LEFT) {
		if check_collision_shape_point(player.shape, player.pos, mouse_world_pos) {
			selected_phys_entity = &player.physics_entity
			selected_entity = player
			break outer
		}
		for &enemy in enemies {
			if check_collision_shape_point(enemy.shape, enemy.pos, mouse_world_pos) {
				selected_phys_entity = &enemy.physics_entity
				selected_entity = enemy
				break outer
			}
		}
		for &barrel in exploding_barrels {
			if check_collision_shape_point(barrel.shape, barrel.pos, mouse_world_pos) {
				selected_phys_entity = &barrel.physics_entity
				selected_entity = barrel
				break outer
			}
		}
		for &item in items {
			if check_collision_shape_point(item.shape, item.pos, mouse_world_pos) {
				selected_phys_entity = &item.physics_entity
				selected_entity = item
				break outer
			}
		}
		selected_phys_entity = nil
		selected_entity = {}
	}

	// move entity
	if rl.IsMouseButtonDown(.LEFT) && selected_phys_entity != nil {
		selected_phys_entity.pos += mouse_world_delta
	}

	// delete entity
	if selected_phys_entity != nil && rl.IsKeyPressed(.DELETE) {
		#partial switch en in selected_entity {
		case Enemy:
			for enemy, i in enemies {
				if enemy.id == en.id {
					unordered_remove(&enemies, i)
					break
				}
			}
		case ExplodingBarrel:
			for barrel, i in exploding_barrels {
				if barrel.id == en.id {
					unordered_remove(&exploding_barrels, i)
					break
				}
			}
		case Item:
			for item, i in items {
				if item.id == en.id {
					unordered_remove(&items, i)
					break
				}
			}
		case Player:
			rl.TraceLog(.WARNING, "You can't delete the player")
		}
		selected_phys_entity = nil
		selected_entity = {}
	}

	// new entity
	if rl.IsKeyDown(.N) {
		if rl.IsKeyPressed(.ONE) {
			// creating new enemy
			append(&enemies, new_enemy(mouse_world_pos))
		} else if rl.IsKeyPressed(.TWO) {
			append(&exploding_barrels, new_exploding_barrel(mouse_world_pos))
		} else if rl.IsKeyPressed(.THREE) {
			add_item_to_world({id = .Apple, count = 1}, mouse_world_pos)
		}
	}

	// manual save
	if rl.IsKeyPressed(.S) {
		save_entities()
	}

	// manual load
	if rl.IsKeyPressed(.L) {
		unload_entities()
		load_entities()
	}
}

draw_entity_editor_world :: proc() {
	// draw selected entity outline
	if selected_phys_entity != nil {
		draw_shape_lines(selected_phys_entity.shape, selected_phys_entity.pos, rl.YELLOW)
	}
}

draw_entity_editor_ui :: proc() {
	// draw selected entity data
	// draw entity pos
	if selected_phys_entity != nil {
		rl.DrawText(fmt.ctprintf("%v", selected_phys_entity.pos), 30, 60, 20, rl.BLACK)
	}

}

setup_default_entities :: proc() {
	player = new_player({32, 32})
	pickup_item({.Sword, 100, 100})
	pickup_item({.Bomb, 3, 16})

	enemies = make([dynamic]Enemy, context.allocator)
	append(&enemies, new_ranged_enemy({300, 40}))
	append(&enemies, new_melee_enemy({200, 200}, enemy_attack_poly))
	append(&enemies, new_melee_enemy({130, 200}, enemy_attack_poly))
	append(&enemies, new_melee_enemy({220, 180}, enemy_attack_poly))
	append(&enemies, new_melee_enemy({80, 300}, enemy_attack_poly))

	exploding_barrels = make([dynamic]ExplodingBarrel, context.allocator)
	append(&exploding_barrels, new_exploding_barrel({24, 64}))

	items = make([dynamic]Item, context.allocator)
	add_item_to_world({.Sword, 10, 10}, {500, 300})
	add_item_to_world({.Bomb, 1, 16}, {200, 50})
	add_item_to_world({.Apple, 5, 16}, {100, 50})
}
