package game

import "core:encoding/json"
import "core:encoding/uuid"
import "core:fmt"
import "core:os"
import "core:testing"

// This file is where previous versions of structs go as well as procedures for converting
// said previous versions to the current version and back
EnemyData1 :: struct {
	id:             uuid.Identifier,
	pos:            Vec2,
	start_disabled: bool,
	look_angle:     f32,
	health:         f32,
	max_health:     f32,
	variant:        u8, // maybe make this an enum
}

Enemy2 :: struct {
	using moving_entity:           MovingEntity,
	post_pos:                      Vec2,
	target:                        Vec2, // target position to use when moving enemy
	// Pereception Stats
	hearing_range:                 f32,
	vision_range:                  f32,
	look_angle:                    f32, // direction they are looking (in degrees facing right going ccw)
	vision_fov:                    f32, // wideness (in degrees)
	vision_points:                 [50]Vec2,
	// Perception Results
	can_see_player:                bool,
	last_seen_player_pos:          Vec2,
	last_seen_player_vel:          Vec2,
	player_in_flee_range:          bool,
	alert_just_detected:           bool,
	last_alert_intensity_detected: f32,
	last_alert:                    Alert,
	// Combat
	attack_charge_range:           f32, // Range for the enemy to start charging
	start_charge_time:             f32,
	current_charge_time:           f32,
	charging:                      bool,
	just_attacked:                 bool,
	// Flinching
	start_flinch_time:             f32,
	current_flinch_time:           f32,
	flinching:                     bool,
	// Idle
	idle_look_timer:               f32,
	idle_look_angle:               f32,
	// Searching
	search_state:                  int,
	// Health
	health:                        f32,
	max_health:                    f32,
	// Pathfinding
	current_path:                  []Vec2,
	current_path_point:            int,
	pathfinding_timer:             f32,
	// State management
	state:                         EnemyState,
	alert_timer:                   f32,
	search_timer:                  f32,
	// Type specific
	data:                          EnemyVariantData,
	// Sprite flash
	flash_opacity:                 f32,
	// Death
	death_timer:                   f32,
	weapon_side:                   int, // top is 1, bottom is -1
	attack_anim_timer:             f32,
}

Enemy1 :: struct {
	using moving_entity:      MovingEntity,
	detection_angle:          f32, // direction they are looking (in degrees facing right going ccw)
	detection_angle_sweep:    f32, // wideness (in degrees)
	detection_range:          f32,
	detection_points:         [50]Vec2,
	attack_charge_range:      f32, // Range for the enemy to start charging
	start_charge_time:        f32,
	current_charge_time:      f32,
	charging:                 bool,
	start_flinch_time:        f32,
	current_flinch_time:      f32,
	flinching:                bool,
	just_attacked:            bool,
	health:                   f32,
	max_health:               f32,
	current_path:             []Vec2,
	current_path_point:       int,
	pathfinding_timer:        f32,
	player_in_range:          bool,
	data:                     EnemyVariantData,
	distracted:               bool,
	distraction_pos:          Vec2,
	distraction_time_emitted: f32,
}

Level4 :: struct {
	version:               int,
	// start player pos
	player_pos:            Vec2,
	// portal pos
	portal_pos:            Vec2,
	// enemies
	enemies:               [dynamic]Enemy3, // This field is used when level editing
	enemy_data:            [dynamic]EnemyData2, // Used for serialization
	// items
	items:                 [dynamic]Item,
	// barrels
	exploding_barrels:     [dynamic]ExplodingBarrel,
	// walls
	walls:                 [dynamic]PhysicsEntity,
	// half walls
	half_walls:            [dynamic]HalfWall,
	// camera bounding box
	bounds:                Rectangle,
	// tutorial
	has_tutorial:          bool,
	// if game should be saved after completing the level
	save_after_completion: bool,
}

Level3 :: struct {
	// start player pos
	player_pos:            Vec2,
	// portal pos
	portal_pos:            Vec2,
	// enemies
	enemies:               [dynamic]Enemy2, // This field is used when level editing
	enemy_data:            [dynamic]EnemyData1, // Used for serialization
	// items
	items:                 [dynamic]Item,
	// barrels
	exploding_barrels:     [dynamic]ExplodingBarrel,
	// walls
	walls:                 [dynamic]PhysicsEntity,
	// half walls
	half_walls:            [dynamic]HalfWall,
	// camera bounding box
	bounds:                Rectangle,
	// tutorial
	has_tutorial:          bool,
	// if game should be saved after completing the level
	save_after_completion: bool,
}

Level1 :: struct {
	// start player pos
	player_pos:        Vec2,
	// portal pos
	portal_pos:        Vec2,
	// enemies
	enemies:           [dynamic]Enemy1,
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

Level2 :: struct {
	// start player pos
	player_pos:        Vec2,
	// portal pos
	portal_pos:        Vec2,
	// enemies
	enemies:           [dynamic]Enemy2,
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
// if clear_memory is true, any allocations in the input that are no longer needed in the result are cleared
// converting is only for serialization purposes anyway, so we don't need to consider other cases, just "how do we want this data to be saved?"
// Note: if possible the convert proc's will not allocate new data, this could be bad, but as of now it works fine with our game.

convert_level3_to_current :: proc(input: Level3) -> Level {
	return convert_level4_to_current(convert_level3_level4(input, true))
}

convert_level4_to_current :: proc(input: Level4) -> Level {
	return convert_level5_to_current(convert_level4_to_level5(input, true))
}

convert_level5_to_current :: proc(input: Level5) -> Level {
	return input
}

convert_level4_to_level5 :: proc(
	input: Level4,
	clear_memory: bool,
	allocator := context.allocator,
) -> (
	result: Level5,
) {
	result.version = 5
	result.player_pos = input.player_pos
	result.portal_pos = input.portal_pos
	result.enemies = input.enemies
	result.enemy_data = input.enemy_data
	result.items = input.items
	result.exploding_barrels = input.exploding_barrels
	result.walls = input.walls
	result.half_walls = input.half_walls
	result.bounds = input.bounds
	result.has_tutorial = input.has_tutorial
	result.save_after_completion = input.save_after_completion

	result.bounce_pads = make([dynamic]BouncePad, allocator)

	return
}

convert_level2_level3 :: proc(
	input: Level2,
	clear_memory: bool,
	allocator := context.allocator,
) -> (
	result: Level3,
) {
	result.player_pos = input.player_pos
	result.portal_pos = input.portal_pos
	result.enemies = nil
	result.enemy_data = make([dynamic]EnemyData1, allocator)
	for enemy in input.enemies {
		append(&result.enemy_data, get_data1_from_enemy2(enemy))
	}
	if clear_memory {
		delete(input.enemies)
	}
	result.items = input.items
	result.exploding_barrels = input.exploding_barrels
	result.walls = input.walls
	result.half_walls = input.half_walls
	result.bounds = input.bounds
	result.has_tutorial = input.has_tutorial
	return
}

convert_level3_level4 :: proc(
	input: Level3,
	clear_memory: bool,
	allocator := context.allocator,
) -> (
	result: Level4,
) {
	result.version = 4
	result.player_pos = input.player_pos
	result.portal_pos = input.portal_pos
	result.enemies = nil
	result.enemy_data = make([dynamic]EnemyData2, allocator)
	for data in input.enemy_data {
		append(&result.enemy_data, get_data2_from_data1(data))
		fmt.println(data.variant)
		fmt.println(result.enemy_data[len(result.enemy_data) - 1].variant)
	}
	if clear_memory {
		delete(input.enemy_data)
		delete(input.enemies)
	}
	result.items = input.items
	result.exploding_barrels = input.exploding_barrels
	result.walls = input.walls
	result.half_walls = input.half_walls
	result.bounds = input.bounds
	result.has_tutorial = input.has_tutorial
	result.save_after_completion = input.save_after_completion
	return
}

get_data2_from_data1 :: proc(e: EnemyData1) -> EnemyData2 {
	variant: EnemyVariant
	switch e.variant {
	case 0:
		variant = .Melee
	case 1:
		variant = .Ranged
	}

	return {e.id, e.pos, e.start_disabled, e.look_angle, e.health, e.max_health, variant}
}

get_data1_from_enemy2 :: proc(e: Enemy2) -> EnemyData1 {
	variant: u8
	switch d in e.data {
	case MeleeEnemyData:
		variant = 0
	case RangedEnemyData:
		variant = 1
	}

	return {e.id, e.pos, e.start_disabled, e.look_angle, e.health, e.max_health, variant}
}

convert_level1_level2 :: proc(
	input: Level1,
	clear_memory: bool,
	allocator := context.allocator,
) -> (
	result: Level2,
) {
	result.player_pos = input.player_pos
	result.portal_pos = input.portal_pos
	result.enemies = make([dynamic]Enemy2, allocator)
	for enemy in input.enemies {
		append(&result.enemies, convert_enemy1_enemy2(enemy, clear_memory, allocator))
	}
	if clear_memory {
		delete(input.enemies)
	}
	result.items = input.items
	result.exploding_barrels = input.exploding_barrels
	result.walls = input.walls
	result.half_walls = input.half_walls
	result.bounds = input.bounds
	result.has_tutorial = input.has_tutorial
	return
}

// Note: Clear memory does not work with this procedure
convert_enemy1_enemy2 :: proc(
	input: Enemy1,
	clear_memory := false,
	allocator := context.allocator,
) -> (
	result: Enemy2,
) {
	result.id = input.id
	result.pos = input.pos
	result.start_disabled = input.start_disabled

	result.health = input.health
	result.max_health = input.max_health

	result.data = input.data

	return
}


convert_file :: proc(
	converter: proc(input: $I, clear_memory: bool, allocator := context.allocator) -> $R,
	load_path: string,
	save_path := "",
) {
	input_data: I = {}
	// load file
	if bytes, ok := os.read_entire_file(load_path, context.temp_allocator); ok {
		// put file in I struct
		if json.unmarshal(data = bytes, ptr = &input_data, allocator = context.temp_allocator) !=
		   nil {
			fmt.println("error parsing json")
		}
	} else {
		fmt.println("error loading file")
	}

	// call procedure
	result_data: R = converter(input_data, true, context.temp_allocator)

	// marshal the struct into json
	if bytes, err := json.marshal(
		result_data,
		allocator = context.temp_allocator,
		opt = {pretty = true},
	); err == nil {
		// save file
		if !os.write_entire_file(save_path if save_path != "" else load_path, bytes) {
			fmt.println("failed to write file")
		}
	} else {
		fmt.println("error marshaling struct into json")
	}
}

convert_level1_level1 :: proc(
	input: Level1,
	clear_memory: bool,
	allocator := context.allocator,
) -> (
	result: Level1,
) {
	return input
}

@(test)
test :: proc(_: ^testing.T) {
	convert_file(convert_level2_level3, "level04.json")
}
