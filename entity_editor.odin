package game

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:slice"
import rl "vendor:raylib"

ENTITY_LOAD_FILE_PATH :: "entity1.json"
ENTITY_SAVE_FILE_PATH :: "entity1.json"

LEVEL_FILE_PREFIX :: "data/level"
TILEMAP_FILE_PREFIX :: "assets/tilemap"
GAME_FILE_PREFIX :: "data/game"

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
	// enemies
	enemies:           [dynamic]Enemy,
	// items
	items:             [dynamic]Item,
	// barrels
	exploding_barrels: [dynamic]ExplodingBarrel,
	// navmesh
	nav_mesh:          NavMesh,
	// walls
	walls:             [dynamic]PhysicsEntity,
}
// updates made while in an editor mode will be saved here
level: Level
level_tilemap: Tilemap


EditorState :: struct {
	mode:                      EditorMode,

	// Entity editor
	selected_entity:           LevelEntityType,
	selected_phys_entity:      ^PhysicsEntity,

	// Level editor
	selected_wall:             ^Wall,
	selected_wall_index:       int,
	wall_mouse_rel_pos:        Vec2,

	// Level editor ui
	new_shape_but:             Button,
	change_shape_but:          Button,
	entity_x_field:            NumberField,
	entity_y_field:            NumberField,
	shape_x_field:             NumberField,
	shape_y_field:             NumberField,
	width_field:               NumberField,
	height_field:              NumberField,
	radius_field:              NumberField,

	// Navmesh editor
	selected_nav_cell:         ^NavCell,
	selected_nav_cell_index:   int,
	selected_point:            ^Vec2,
	selected_point_cell_index: int,

	// Navmesh editor ui
	display_nav_graph:         bool,
	display_test_path:         bool,
	test_path_start:           Vec2,
	test_path_end:             Vec2,
	test_path:                 []Vec2,
}
editor_state: EditorState


init_editor_state :: proc(e: ^EditorState) {
	// Level editor
	e.selected_wall_index = -1

	// Level editor ui
	{
		e.new_shape_but = Button {
			{20, 60, 120, 30},
			"New Shape",
			.Normal,
			{200, 200, 200, 200},
			{150, 150, 150, 200},
			{100, 100, 100, 200},
		}

		e.change_shape_but = Button {
			{20, 100, 120, 30},
			"Change Shape",
			.Normal,
			{200, 200, 200, 200},
			{150, 150, 150, 200},
			{100, 100, 100, 200},
		}

		e.entity_x_field = NumberField {
			{20, 390, 200, 40},
			0,
			"0",
			" E.X ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}

		e.entity_y_field = NumberField {
			{20, 450, 200, 40},
			0,
			"0",
			" E.Y ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}

		e.shape_x_field = NumberField {
			{20, 150, 120, 40},
			0,
			"0",
			" S.X ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}

		e.shape_y_field = NumberField {
			{20, 210, 120, 40},
			0,
			"0",
			" S.Y ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}

		e.radius_field = NumberField {
			{20, 270, 120, 40},
			0,
			"0",
			" R ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}

		e.width_field = NumberField {
			{20, 270, 120, 40},
			0,
			"0",
			" W ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}

		e.height_field = NumberField {
			{20, 330, 120, 40},
			0,
			"0",
			" H ",
			false,
			0,
			{150, 150, 150, 200},
			{150, 255, 150, 200},
		}
	}

	// Navmesh editor
	e.selected_nav_cell_index = -1
	e.selected_point_cell_index = -1
}

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
			// setup tilemap, navmesh, level geometry
			level.nav_mesh.cells = make([dynamic]NavCell)
			level.nav_mesh.nodes = make([dynamic]NavNode)
			level.walls = make([dynamic]Wall)
		}

		delete(bytes)
	} else {
		rl.TraceLog(.WARNING, "Error parsing level data")
		// setup enemies, items, barrels
		level.enemies = make([dynamic]Enemy)
		level.items = make([dynamic]Item)
		level.exploding_barrels = make([dynamic]ExplodingBarrel)
		// setup tilemap, navmesh, level geometry
		level.nav_mesh.cells = make([dynamic]NavCell)
		level.nav_mesh.nodes = make([dynamic]NavNode)
		level.walls = make([dynamic]Wall)
	}

	rl.TraceLog(.INFO, "Level Loaded")

	level = data
	load_tilemap(
		fmt.tprintf("%s%02d.png", TILEMAP_FILE_PREFIX, game_data.cur_level_idx),
		&level_tilemap,
	)
	tilemap = level_tilemap

	player.pos = level.player_pos

	// We clone the arrays so we don't change the level data when we play the game
	enemies = slice.clone_to_dynamic(level.enemies[:])
	for &enemy in enemies {
		#partial switch &en in enemy.data {
		case MeleeEnemyData:
			en.attack_poly.points = ENEMY_ATTACK_HITBOX_POINTS
		}
	}
	items = slice.clone_to_dynamic(level.items[:])
	exploding_barrels = slice.clone_to_dynamic(level.exploding_barrels[:])

	// These two can stay since gameplay wont affect the navmesh or walls
	nav_mesh.nodes = slice.clone_to_dynamic(level.nav_mesh.nodes[:])
	nav_mesh.cells = slice.clone_to_dynamic(level.nav_mesh.cells[:])
	walls = slice.clone_to_dynamic(level.walls[:])
}

save_level :: proc() {
	// save player pos
	// save enemies, items, barrels
	// save tilemap, navmesh, level geometry

	calculate_graph(&level.nav_mesh)

	data: Level = level
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
	delete(items)
	delete(exploding_barrels)
	delete(nav_mesh.cells)
	delete(nav_mesh.nodes)
	delete(walls)
	// delete level data
	delete(level.enemies)
	delete(level.items)
	delete(level.exploding_barrels)
	delete(level.nav_mesh.cells)
	delete(level.nav_mesh.nodes)
	delete(level.walls)
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
			game_data.player_data = PlayerData {
				health = 100,
			}
		}
		delete(bytes)
	} else {
		rl.TraceLog(.WARNING, "Error parsing game data")
		game_data.cur_level_idx = 0
		game_data.player_data = PlayerData {
			health = 100,
		}
	}

	set_player_data(game_data.player_data)

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
					unordered_remove(&enemies, i)
					break
				}
			}
		case .ExplodingBarrel:
			for barrel, i in level.exploding_barrels {
				if barrel.id == e.selected_phys_entity.id {
					unordered_remove(&exploding_barrels, i)
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
			// creating new enemy
			append(&level.enemies, new_enemy(mouse_world_pos))
		} else if rl.IsKeyPressed(.TWO) {
			append(&level.exploding_barrels, new_exploding_barrel(mouse_world_pos))
		} else if rl.IsKeyPressed(.THREE) {
			append(&level.items, new_item({id = .Apple, count = 1}, mouse_world_pos))
		}
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
	if e.selected_phys_entity != nil {
		rl.DrawText(fmt.ctprintf("%v", e.selected_phys_entity.pos), 30, 60, 20, rl.BLACK)
	}
}

// setup_default_entities :: proc() {
// 	player = new_player({32, 32})
// 	set_player_defaults()
// 	pickup_item({.Sword, 100, 100})
// 	pickup_item({.Bomb, 3, 16})

// 	enemies = make([dynamic]Enemy, context.allocator)
// 	append(&enemies, new_ranged_enemy({300, 40}))
// 	append(&enemies, new_melee_enemy({200, 200}, ENEMY_ATTACK_POLY))
// 	append(&enemies, new_melee_enemy({130, 200}, ENEMY_ATTACK_POLY))
// 	append(&enemies, new_melee_enemy({220, 180}, ENEMY_ATTACK_POLY))
// 	append(&enemies, new_melee_enemy({80, 300}, ENEMY_ATTACK_POLY))

// 	exploding_barrels = make([dynamic]ExplodingBarrel, context.allocator)
// 	append(&exploding_barrels, new_exploding_barrel({24, 64}))

// 	items = make([dynamic]Item, context.allocator)
// 	add_item_to_world({.Sword, 10, 10}, {500, 300})
// 	add_item_to_world({.Bomb, 1, 16}, {200, 50})
// 	add_item_to_world({.Apple, 5, 16}, {100, 50})
// }


set_player_data :: proc(data: PlayerData) {
	player.health = data.health
	player.weapons = data.weapons
	player.items = data.items
	select_weapon(data.selected_weapon_idx)
	player.selected_item_idx = data.selected_item_idx
	player.item_count = data.item_count
	set_player_defaults()
}

get_player_data :: proc() -> PlayerData {
	return {
		player.health,
		player.weapons,
		player.items,
		player.selected_weapon_idx,
		player.selected_item_idx,
		player.item_count,
		player.cur_ability,
	}
}

draw_level :: proc() {
	draw_tilemap(level_tilemap)
	draw_sprite(PLAYER_SPRITE, level.player_pos)

	for enemy in level.enemies {
		draw_shape(enemy.shape, enemy.pos, rl.GREEN)
		rl.DrawCircleLinesV(enemy.pos, enemy.detection_range, rl.YELLOW)
	}

	for barrel in level.exploding_barrels {
		draw_shape(barrel.shape, barrel.pos, rl.RED)
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
}
