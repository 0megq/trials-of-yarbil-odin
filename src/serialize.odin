package game

import "core:encoding/json"
import "core:encoding/uuid"
import "core:fmt"
import "core:os"
import "core:slice"
import rl "vendor:raylib"

ENTITY_LOAD_FILE_PATH :: "entity1.json"
ENTITY_SAVE_FILE_PATH :: "entity1.json"

LEVEL_FILE_PREFIX :: "./data/level"
TILEMAP_FILE_PREFIX :: "./data/tilemap"
GAME_FILE_PREFIX :: "./data/game"
TUTORIAL_FILE_PREFIX :: "./data/tutorial"

PLAYER_SHAPE :: Rectangle{-6, -6, 12, 12}

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

Condition :: union {
	EntityCountCondition,
	EntityExistsCondition,
	InventorySlotsFilledCondition,
	KeyPressedCondition,
	PlayerInAreaCondition,
	EnemyInStateCondition,
	PlayerHealthCondition,
}

EnemyInStateCondition :: struct {
	id:    uuid.Identifier,
	state: EnemyState,
}

PlayerInAreaCondition :: struct {
	area: Rectangle,
}

// Checks the count of entities of the specified type in the active entity arrays
EntityCountCondition :: struct {
	type:  EntityType,
	count: int,
}

// Checks if the entity with the given type and id exists in the active entity arrays
EntityExistsCondition :: struct {
	type:           EntityType,
	id:             uuid.Identifier,
	check_disabled: bool,
}

PlayerHealthCondition :: struct {
	health:     f32,
	max_health: bool,
	check:      int, // -2 is less than, -1 is less than or equal to, 0 is equal to, 1 is greater than or equal to, 2, is greater than
}

EntityAtPositionCondition :: struct {
	type:   EntityType,
	pos:    Vec2,
	radius: f32,
}

InventorySlotsFilledCondition :: struct {
	count:  int,
	weapon: bool, // if true, this will check the weapon slots instead of the item slots
}

KeyPressedCondition :: struct {
	key:       rl.KeyboardKey,
	fulfilled: bool,
}

TutorialPrompt :: struct {
	pos:               Vec2,
	text:              string,
	condition:         Condition,
	invert_condition:  bool,
	condition2:        Condition,
	invert_condition2: bool,
	condition3:        Condition,
	invert_condition3: bool,
	on_screen:         bool, // if true, the prompt will appear on screen instead of in world
}

TutorialAction :: struct {
	action:            ActionData,
	condition:         Condition,
	invert_condition:  bool,
	condition2:        Condition,
	invert_condition2: bool,
	condition3:        Condition,
	invert_condition3: bool,
}

ActionData :: union {
	EnableEntityAction,
	SetTutorialFlagAction,
	PrintMessageAction,
}

PrintMessageAction :: struct {
	message: string,
}

EnableEntityAction :: struct {
	type:         EntityType,
	id:           uuid.Identifier,
	should_clone: bool,
}

SetTutorialFlagAction :: struct {
	flag_name: string,
	value:     bool,
}
// MARK: Tutorial
Tutorial :: struct {
	prompts:              [dynamic]TutorialPrompt,
	actions:              [dynamic]TutorialAction,
	hide_item_hud:        bool,
	hide_weapon_hud:      bool,
	hide_dash_hud:        bool,
	disable_ability:      bool,
	hide_speedrun_timer:  bool,
	hide_all_hud:         bool,
	enable_enemy_dummies: bool,
	disable_throwing:     bool,
	disable_switching:    bool,
	disable_dropping:     bool,
}

get_tutorial_flag_from_name :: proc(name: string) -> ^bool {
	switch name {
	case "hide_item_hud":
		return &tutorial.hide_item_hud
	case "hide_weapon_hud":
		return &tutorial.hide_weapon_hud
	case "disable_ability":
		return &tutorial.disable_ability
	case "hide_all_hud":
		return &tutorial.hide_all_hud
	case "enable_enemy_dummies":
		return &tutorial.enable_enemy_dummies
	case "disable_throwing":
		return &tutorial.disable_throwing
	case "disable_switching":
		return &tutorial.disable_switching
	case "disable_dropping":
		return &tutorial.disable_dropping
	}
	return nil
}

EnemyData :: EnemyData1
EnemyData1 :: struct {
	id:             uuid.Identifier,
	pos:            Vec2,
	start_disabled: bool,
	look_angle:     f32,
	health:         f32,
	max_health:     f32,
	variant:        u8, // maybe make this an enum
}

// Used for serialization and level editor
Level :: Level3
Level3 :: struct {
	// start player pos
	player_pos:        Vec2,
	// portal pos
	portal_pos:        Vec2,
	// enemies
	enemies:           [dynamic]Enemy2, // This field is only used when level editing
	enemy_data:        [dynamic]EnemyData1, // Only used for serialization
	// items
	items:             [dynamic]Item,
	// barrels
	exploding_barrels: [dynamic]ExplodingBarrel,
	// walls
	walls:             [dynamic]PhysicsEntity,
	// half walls
	half_walls:        [dynamic]HalfWall,
	// camera bounding box
	bounds:            Rectangle,
	// tutorial
	has_tutorial:      bool,
}
// updates made while in an editor mode will be saved here
level: Level
level_tilemap: Tilemap
tutorial: Tutorial

// MARK: Level
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
			level.enemy_data = make([dynamic]EnemyData)
			level.items = make([dynamic]Item)
			level.exploding_barrels = make([dynamic]ExplodingBarrel)
			// setup level geometry
			level.walls = make([dynamic]Wall)
			level.half_walls = make([dynamic]HalfWall)
		}

		delete(bytes)
	} else {
		rl.TraceLog(.WARNING, "Error loading level data")
		// setup enemies, items, barrels
		level.enemies = make([dynamic]Enemy)
		level.enemy_data = make([dynamic]EnemyData)
		level.items = make([dynamic]Item)
		level.exploding_barrels = make([dynamic]ExplodingBarrel)
		// setup level geometry
		level.walls = make([dynamic]Wall)
		level.half_walls = make([dynamic]HalfWall)
	}

	level = data

	rl.TraceLog(.INFO, "Level Loaded")

	for data in level.enemy_data {
		append(&level.enemies, get_enemy_from_data(data))
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

	world_camera = rl.Camera2D {
		target = player.pos + normalize(mouse_world_pos - player.pos) * 16,
		zoom   = window_over_game,
		offset = ({f32(window_size.x), f32(window_size.y)} / 2),
	}


	load_tilemap(
		fmt.ctprintf("%s%02d.png", TILEMAP_FILE_PREFIX, game_data.cur_level_idx),
		&level_tilemap,
	)
	tilemap = level_tilemap

	// We clone the arrays so we don't change the level data when we play the game
	enemies = slice.clone_to_dynamic(level.enemies[:])
	disabled_enemies = make([dynamic]Enemy)
	#reverse for enemy, i in enemies {
		if enemy.start_disabled {
			append(&disabled_enemies, enemy)
			unordered_remove(&enemies, i)
		}
	}
	items = slice.clone_to_dynamic(level.items[:])
	disabled_items = make([dynamic]Item)
	#reverse for item, i in items {
		if item.start_disabled {
			append(&disabled_items, item)
			unordered_remove(&items, i)
		}
	}
	exploding_barrels = slice.clone_to_dynamic(level.exploding_barrels[:])

	walls = slice.clone_to_dynamic(level.walls[:])
	half_walls = slice.clone_to_dynamic(level.half_walls[:])
	place_walls_and_calculate_graph()

	// Load tutorial if it exists
	if level.has_tutorial {
		_load_tutorial()
	}
}

save_level :: proc() {
	// save player pos
	// save enemies, items, barrels
	// save tilemap, level geometry

	data: Level = level
	clear(&data.enemy_data)
	for enemy in data.enemies {
		append(&data.enemy_data, get_data_from_enemy(enemy))
	}
	data.enemies = nil
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
	if level.has_tutorial {
		// _save_tutorial() 
	}
}

unload_level :: proc() {
	if level.has_tutorial {
		_unload_tutorial()
	}
	// delete world data
	delete(enemies)
	enemies = nil
	delete(disabled_enemies)
	disabled_enemies = nil
	delete(items)
	items = nil
	delete(disabled_items)
	disabled_items = nil
	delete(exploding_barrels)
	exploding_barrels = nil
	delete(walls)
	walls = nil
	delete(half_walls)
	half_walls = nil
	// delete level data
	delete(level.enemy_data)
	level.enemy_data = nil
	delete(level.items)
	level.items = nil
	delete(level.exploding_barrels)
	level.exploding_barrels = nil
	delete(level.walls)
	level.walls = nil
	delete(level.half_walls)
	level.half_walls = nil

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
		rl.TraceLog(.WARNING, "Error loading game data")
		game_data.cur_level_idx = 0
		game_data.player_data = {}
	}

	// Reset all player values
	player = {}
	set_player_data(game_data.player_data)
	reset_speedrun_timer()

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


_load_tutorial :: proc() {
	tutorial_file := fmt.tprintf("%s%02d.json", TUTORIAL_FILE_PREFIX, game_data.cur_level_idx)
	if bytes, ok := os.read_entire_file(tutorial_file, context.allocator); ok {
		if err := json.unmarshal(bytes, &tutorial); err != nil {
			rl.TraceLog(.WARNING, "Error parsing tutorial data:")
		}
		delete(bytes)
	} else {
		rl.TraceLog(.WARNING, "Error loading tutorial data")
	}

	rl.TraceLog(.INFO, "Tutorial Loaded")
}

_save_tutorial :: proc() {
	if bytes, err := json.marshal(tutorial, allocator = context.allocator, opt = {pretty = true});
	   err == nil {
		tutorial_save_path := fmt.tprintf(
			"%s%02d.json",
			TUTORIAL_FILE_PREFIX,
			game_data.cur_level_idx,
		)
		os.write_entire_file(tutorial_save_path, bytes)
		delete(bytes)
	} else {
		rl.TraceLog(.WARNING, "Error saving tutorial data")
	}

	rl.TraceLog(.INFO, "Tutorial Saved")
}

_unload_tutorial :: proc() {
	for prompt in tutorial.prompts {
		delete(prompt.text, context.allocator)
	}
	delete(tutorial.prompts)
	for action in tutorial.actions {
		switch data in action.action {
		case PrintMessageAction:
			delete(data.message)
		case SetTutorialFlagAction:
			delete(data.flag_name)
		case EnableEntityAction:

		case:

		}
	}
	delete(tutorial.actions)
	tutorial = {}
	rl.TraceLog(.INFO, "Tutorial Unloaded")
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

get_enemy_from_data :: proc(data: EnemyData) -> (e: Enemy) {
	e.id = data.id
	e.pos = data.pos
	e.health = data.health
	e.max_health = data.max_health
	e.start_disabled = data.start_disabled
	e.look_angle = data.look_angle
	e.idle_look_angle = data.look_angle
	switch data.variant {
	case 0:
		setup_melee_enemy(&e)
	case 1:
		setup_ranged_enemy(&e)
	}
	return
}

get_data_from_enemy :: proc(e: Enemy) -> EnemyData {
	variant: u8
	switch d in e.data {
	case MeleeEnemyData:
		variant = 0
	case RangedEnemyData:
		variant = 1
	}

	return {e.id, e.pos, e.start_disabled, e.look_angle, e.health, e.max_health, variant}
}

draw_level :: proc(show_tile_grid := false) {
	draw_tilemap(level_tilemap, show_tile_grid)

	rl.DrawCircleV(level.portal_pos, PORTAL_RADIUS, {50, 50, 50, 255})

	for wall in level.half_walls {
		draw_shape(wall.shape, wall.pos, rl.LIGHTGRAY)
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

	for enemy in level.enemies {
		rl.DrawCircleLinesV(enemy.pos, enemy.vision_range, rl.YELLOW)
		rl.DrawCircleV(enemy.pos, ENEMY_POST_RANGE, {255, 0, 0, 100})

		sprite := ENEMY_SPRITE
		sprite.rotation = enemy.look_angle

		if sprite.rotation < -90 || sprite.rotation > 90 {
			sprite.scale = {-1, 1}
			sprite.rotation += 180
		}
		draw_sprite(sprite, enemy.pos)
	}

	for barrel in level.exploding_barrels {
		draw_sprite(BARREL_SPRITE, barrel.pos)
	}

	draw_sprite(PLAYER_SPRITE, level.player_pos)

	rl.DrawRectangleRec(level.bounds, {0, 0, 120, 100})

	// if level.has_tutorial {
	// 	for prompt in tutorial.prompts {
	// 		if !prompt.on_screen {
	// 			font_size: f32 = 6
	// 			spacing: f32 = 1
	// 			text := fmt.ctprint(prompt.text)
	// 			pos := get_centered_text_pos(prompt.pos, text, font_size, spacing)
	// 			text_size := rl.MeasureTextEx(rl.GetFontDefault(), text, font_size, spacing)
	// 			rl.DrawRectangleLinesEx({pos.x, pos.y, text_size.x, text_size.y}, 0.5, rl.YELLOW)
	// 		}
	// 	}
	// }
}
