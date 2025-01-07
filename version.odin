package game

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
	data:                     EnemyData,
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

// if clear_memory is true, any allocations in the input that are no longer needed in the result are cleared

level1_to_level2 :: proc(input: Level1, clear_memory: bool) -> Level2 {
	result.player_pos = input.player_pos
	result.portal_pos = input.portal_pos
	for enemy in input.enemies {
		append(&result.enemies, enemy1_to_enemy2(enemy), clear_memory)
	}
	result.items = input.items
	result.exploding_barrels = input.exploding_barrels
	result.walls = input.walls
	result.half_walls = input.half_walls
	result.bounds = input.bounds
	return
}


enemy1_to_enemy2 :: proc(input: Enemy1, clear_memory: bool) -> (result: Enemy2) {

}
