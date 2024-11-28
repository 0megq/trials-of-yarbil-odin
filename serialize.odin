package game

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:slice"
import rl "vendor:raylib"

ENTITY_LOAD_FILE_PATH :: "entity1.json"
ENTITY_SAVE_FILE_PATH :: "entity1.json"

LEVEL_FILE_PREFIX :: "./data/level"
TILEMAP_FILE_PREFIX :: "./data/tilemap"
GAME_FILE_PREFIX :: "./data/game"

PLAYER_SHAPE :: Rectangle{-6, -6, 12, 12}

// This is the only data that gets saved for entities
EntityData :: struct {
	player_data:       PlayerData,
	enemies:           [dynamic]Enemy,
	items:             [dynamic]Item,
	exploding_barrels: [dynamic]ExplodingBarrel,
}

PlayerData :: struct {
	// player health
	health:              f32,
	max_health:          f32,
	// player inventory
	weapons:             [2]ItemData,
	items:               [6]ItemData,
	selected_weapon_idx: int,
	selected_item_idx:   int,
	item_count:          int,
	// current ability
	ability:             MovementAbility,
}

// Used for serialization
GameData :: struct {
	// player data
	player_data:   PlayerData,
	// current level index
	cur_level_idx: int,
}

// Used for serialization and level editor
Level :: struct {
	// start player pos
	player_pos:        Vec2,
	// portal pos
	portal_pos:        Vec2,
	// enemies
	enemies:           [dynamic]Enemy,
	// items
	items:             [dynamic]Item,
	// barrels
	exploding_barrels: [dynamic]ExplodingBarrel,
	// walls
	walls:             [dynamic]PhysicsEntity,
	// camera bounding box
	bounds:            Rectangle,
}
// updates made while in an editor mode will be saved here
level: Level
level_tilemap: Tilemap


reload_level :: proc() {
	unload_level()
	load_level()
}

load_level :: proc() {
	data := Level{}

	level_file := fmt.tprintf("%s%02d.json", LEVEL_FILE_PREFIX, game_data.cur_level_idx)
	if bytes, ok := os.read_entire_file(level_file, context.allocator); ok {
		if json.unmarshal(bytes, &data) != nil {
			rl.TraceLog(.WARNING, "Error parsing level data")
			// setup enemies, items, barrels
			level.enemies = make([dynamic]Enemy)
			level.items = make([dynamic]Item)
			level.exploding_barrels = make([dynamic]ExplodingBarrel)
			// setup level geometry
			level.walls = make([dynamic]Wall)
		}

		delete(bytes)
	} else {
		rl.TraceLog(.WARNING, "Error parsing level data")
		// setup enemies, items, barrels
		level.enemies = make([dynamic]Enemy)
		level.items = make([dynamic]Item)
		level.exploding_barrels = make([dynamic]ExplodingBarrel)
		// setup level geometry
		level.walls = make([dynamic]Wall)
	}

	level = data

	rl.TraceLog(.INFO, "Level Loaded")


	// Update constants
	for &enemy in level.enemies {
		switch data in enemy.data {
		case MeleeEnemyData:
			setup_melee_enemy(&enemy)
		case RangedEnemyData:
			setup_ranged_enemy(&enemy)
		}
	}

	for &barrel in level.exploding_barrels {
		setup_exploding_barrel(&barrel)
	}

	for &item in level.items {
		setup_item(&item)
	}

	player.pos = level.player_pos
	player.vel = {} // we may need to reset other player values
	setup_player(&player)

	load_tilemap(
		fmt.ctprintf("%s%02d.png", TILEMAP_FILE_PREFIX, game_data.cur_level_idx),
		&level_tilemap,
	)
	tilemap = level_tilemap

	// We clone the arrays so we don't change the level data when we play the game
	enemies = slice.clone_to_dynamic(level.enemies[:])
	items = slice.clone_to_dynamic(level.items[:])
	exploding_barrels = slice.clone_to_dynamic(level.exploding_barrels[:])

	walls = slice.clone_to_dynamic(level.walls[:])
	place_walls_and_calculate_graph()
}

save_level :: proc() {
	// save player pos
	// save enemies, items, barrels
	// save tilemap, level geometry

	data: Level = level
	place_walls_and_calculate_graph()
	save_tilemap(
		fmt.ctprintf("%s%02d.png", TILEMAP_FILE_PREFIX, game_data.cur_level_idx),
		level_tilemap,
	)

	if bytes, err := json.marshal(data, allocator = context.allocator, opt = {pretty = true});
	   err == nil {
		level_save_path := fmt.tprintf("%s%02d.json", LEVEL_FILE_PREFIX, game_data.cur_level_idx)
		os.write_entire_file(level_save_path, bytes)
		delete(bytes)
	} else {
		rl.TraceLog(.WARNING, "Error saving level data")
	}

	rl.TraceLog(.INFO, "Level Saved")
}

unload_level :: proc() {
	// delete world data
	delete(enemies)
	enemies = nil
	delete(items)
	items = nil
	delete(exploding_barrels)
	exploding_barrels = nil
	delete(walls)
	walls = nil
	// delete level data
	delete(level.enemies)
	level.enemies = nil
	delete(level.items)
	level.items = nil
	delete(level.exploding_barrels)
	level.exploding_barrels = nil
	delete(level.walls)
	level.walls = nil

	rl.TraceLog(.INFO, "Level Unloaded")
}

reload_game_data :: proc(game_idx := 0) {
	unload_game_data()
	load_game_data(game_idx)
}

load_game_data :: proc(game_idx := 0) {
	game_file := fmt.tprintf("%s%02d.json", GAME_FILE_PREFIX, game_idx)
	if bytes, ok := os.read_entire_file(game_file, context.allocator); ok {
		if json.unmarshal(bytes, &game_data) != nil {
			rl.TraceLog(.WARNING, "Error parsing game data")
			game_data.cur_level_idx = 0
			game_data.player_data = {}
		}
		delete(bytes)
	} else {
		rl.TraceLog(.WARNING, "Error parsing game data")
		game_data.cur_level_idx = 0
		game_data.player_data = {}
	}

	// Reset all player values
	player = {}
	set_player_data(game_data.player_data)
	setup_player(&player)

	rl.TraceLog(.INFO, "GameData Loaded")
}

save_game_data :: proc(game_idx := 0) {
	// save player data
	game_data.player_data = get_player_data()

	// get current level id and save it
	if bytes, err := json.marshal(game_data, allocator = context.allocator, opt = {pretty = true});
	   err == nil {
		game_save_path := fmt.tprintf("%s%02d.json", GAME_FILE_PREFIX, game_idx)
		os.write_entire_file(game_save_path, bytes)
		delete(bytes)
	} else {
		rl.TraceLog(.WARNING, "Error saving GameData")
	}

	rl.TraceLog(.INFO, "GameData Saved")
}

unload_game_data :: proc() {
	rl.TraceLog(.INFO, "GameData Unloaded")
}


set_player_data :: proc(data: PlayerData) {
	player.health = data.health
	player.max_health = data.max_health
	player.weapons = data.weapons
	player.items = data.items
	select_weapon(data.selected_weapon_idx)
	player.selected_item_idx = data.selected_item_idx
	player.item_count = data.item_count
	player.cur_ability = data.ability
	setup_player(&player)
}

get_player_data :: proc() -> PlayerData {
	return {
		player.health,
		player.max_health,
		player.weapons,
		player.items,
		player.selected_weapon_idx,
		player.selected_item_idx,
		player.item_count,
		player.cur_ability,
	}
}

draw_level :: proc(show_tile_grid := false) {
	draw_tilemap(level_tilemap, show_tile_grid)
	draw_sprite(PLAYER_SPRITE, level.player_pos)

	for enemy in level.enemies {
		draw_sprite(ENEMY_SPRITE, enemy.pos)
		rl.DrawCircleLinesV(enemy.pos, enemy.detection_range, rl.YELLOW)
	}

	for barrel in level.exploding_barrels {
		draw_sprite(BARREL_SPRITE, barrel.pos)
	}

	for item in level.items {
		tex_id := item_to_texture[item.data.id]
		tex := loaded_textures[tex_id]
		sprite: Sprite = {
			tex_id,
			{0, 0, f32(tex.width), f32(tex.height)},
			{1, 1},
			{f32(tex.width) / 2, f32(tex.height) / 2},
			0,
			rl.LIGHTGRAY, // Slight darker tint
		}


		draw_sprite(sprite, item.pos)
	}

	// level.tilemap_file
	for wall in level.walls {
		draw_shape(wall.shape, wall.pos, rl.GRAY)
	}

	rl.DrawRectangleRec(level.bounds, {0, 0, 120, 100})
}