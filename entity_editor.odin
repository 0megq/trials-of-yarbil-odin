package game

import "core:encoding/json"
import "core:fmt"
import "core:os"
import rl "vendor:raylib"

ENTITY_LOAD_FILE_PATH :: "entity1.json"
ENTITY_SAVE_FILE_PATH :: "entity1.json"

LEVEL_SAVE_PREFIX :: "level"
GAME_SAVE_PREFIX :: "game"


// This is the only data that gets saved for entities
EntityData :: struct {
	player_data:       PlayerData1,
	enemies:           [dynamic]Enemy,
	items:             [dynamic]Item,
	exploding_barrels: [dynamic]ExplodingBarrel,
}
PlayerData1 :: struct {
	moving_entity:       MovingEntity,
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
	player_data:     PlayerData,
	// current level index
	cur_level_index: int,
}

// Used for serialization and level editor
LevelData :: struct {
	// start player pos
	player_pos:        Vec2,
	// enemies
	enemies:           [dynamic]Enemy,
	// items
	items:             [dynamic]Item,
	// barrels
	exploding_barrels: [dynamic]ExplodingBarrel,
	// tilemap file
	tilemap_file:      string,
	// navmesh
	nav_mesh:          NavMesh,
	// walls
	walls:             [dynamic]PhysicsEntity,
}
// updates made while in an editor mode will be saved here
cur_level_data: LevelData


EditorState :: struct {
	mode:                      EditorMode,

	// Entity editor
	selected_entity:           EntityType,
	selected_phys_entity:      ^PhysicsEntity,

	// Level editor
	selected_wall:             ^Wall,
	selected_wall_index:       int,
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
	// unload level
	// load level
}

load_level :: proc() {
	// set player pos
	// setup enemies, items, barrels
	// setup tilemap, navmesh, level geometry

	// keep player data and other persistent information
}

save_level :: proc(level_index: int) {
	// save player pos
	// save enemies, items, barrels
	// save tilemap, navmesh, level geometry

	data: LevelData = {}

	if bytes, err := json.marshal(data, allocator = context.allocator, opt = {pretty = true});
	   err == nil {
		level_save_path := fmt.tprintf("%s%02b.json", LEVEL_SAVE_PREFIX, level_index)
		os.write_entire_file(level_save_path, bytes)
		delete(bytes)
	} else {
		rl.TraceLog(.WARNING, "Error saving level data")
	}

	rl.TraceLog(.INFO, "Level Saved")
}

unload_level :: proc() {
	// delete enemies, items, barrels
	// delete tilemap, navmesh, level geometry
}

reload_game_data :: proc() {
	// unload
	// load
}

load_game_data :: proc() {
	// load player data
	// load current level id
	// load current level from its id
}

save_game_data :: proc() {
	// save player data
	// get current level id and save it
}

unload_game_data :: proc() {
	// delete any allocated memory related to game data
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
			set_player_data(data.player_data)
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

	data := EntityData{get_player_data(), enemies, items, exploding_barrels}

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

update_entity_editor :: proc(e: ^EditorState) {
	// select entity
	outer: if rl.IsMouseButtonPressed(.LEFT) {
		if check_collision_shape_point(player.shape, player.pos, mouse_world_pos) {
			e.selected_phys_entity = &player.physics_entity
			e.selected_entity = player
			break outer
		}
		for &enemy in enemies {
			if check_collision_shape_point(enemy.shape, enemy.pos, mouse_world_pos) {
				e.selected_phys_entity = &enemy.physics_entity
				e.selected_entity = enemy
				break outer
			}
		}
		for &barrel in exploding_barrels {
			if check_collision_shape_point(barrel.shape, barrel.pos, mouse_world_pos) {
				e.selected_phys_entity = &barrel.physics_entity
				e.selected_entity = barrel
				break outer
			}
		}
		for &item in items {
			if check_collision_shape_point(item.shape, item.pos, mouse_world_pos) {
				e.selected_phys_entity = &item.physics_entity
				e.selected_entity = item
				break outer
			}
		}
		e.selected_phys_entity = nil
		e.selected_entity = {}
	}

	// move entity
	if rl.IsMouseButtonDown(.LEFT) && e.selected_phys_entity != nil {
		e.selected_phys_entity.pos += mouse_world_delta
	}

	// delete entity
	if e.selected_phys_entity != nil && rl.IsKeyPressed(.DELETE) {
		#partial switch en in e.selected_entity {
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
		e.selected_phys_entity = nil
		e.selected_entity = {}
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

draw_entity_editor_world :: proc(e: EditorState) {
	// draw selected entity outline
	if e.selected_phys_entity != nil {
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

setup_default_entities :: proc() {
	player = new_player({32, 32})
	set_player_defaults()
	pickup_item({.Sword, 100, 100})
	pickup_item({.Bomb, 3, 16})

	enemies = make([dynamic]Enemy, context.allocator)
	append(&enemies, new_ranged_enemy({300, 40}))
	append(&enemies, new_melee_enemy({200, 200}, ENEMY_ATTACK_POLY))
	append(&enemies, new_melee_enemy({130, 200}, ENEMY_ATTACK_POLY))
	append(&enemies, new_melee_enemy({220, 180}, ENEMY_ATTACK_POLY))
	append(&enemies, new_melee_enemy({80, 300}, ENEMY_ATTACK_POLY))

	exploding_barrels = make([dynamic]ExplodingBarrel, context.allocator)
	append(&exploding_barrels, new_exploding_barrel({24, 64}))

	items = make([dynamic]Item, context.allocator)
	add_item_to_world({.Sword, 10, 10}, {500, 300})
	add_item_to_world({.Bomb, 1, 16}, {200, 50})
	add_item_to_world({.Apple, 5, 16}, {100, 50})
}


set_player_data :: proc(data: PlayerData1) {
	player.moving_entity = data.moving_entity
	player.health = data.health
	player.weapons = data.weapons
	player.items = data.items
	select_weapon(data.selected_weapon_idx)
	player.selected_item_idx = data.selected_item_idx
	player.item_count = data.item_count
	set_player_defaults()
}

get_player_data :: proc() -> PlayerData1 {
	return {
		player.moving_entity,
		player.health,
		player.weapons,
		player.items,
		player.selected_weapon_idx,
		player.selected_item_idx,
		player.item_count,
		player.cur_ability,
	}
}
