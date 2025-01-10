package game

import "core:encoding/json"
import "core:fmt"
import "core:os"
import "core:testing"

// This file is where previous versions of structs go as well as procedures for converting
// said previous versions to the current version and back


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

get_data1_from_enemy2 :: proc(e: Enemy2) -> EnemyData1 {
	variant: u8
	switch d in e.data {
	case MeleeEnemyData:
		variant = 0
	case RangedEnemyData:
		variant = 1
	}

	return {e.id, e.pos, e.start_disabled, e.health, e.max_health, variant}
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
	convert_file(convert_level2_level3, "data/level00.json")
	convert_file(convert_level2_level3, "data/level01.json")
	convert_file(convert_level2_level3, "data/level02.json")
	convert_file(convert_level2_level3, "data/level03.json")
	convert_file(convert_level2_level3, "data/level04.json")
	convert_file(convert_level2_level3, "data/level99.json")
}
