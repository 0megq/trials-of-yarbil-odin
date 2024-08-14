package game

import rl "vendor:raylib"


Entity :: struct {
	pos: Vec2,
}

PhysicsEntity :: struct {
	// Acts as a static physics body
	using entity: Entity,
	shape:        Shape,
}

MovingEntity :: struct {
	// Acts as a moving physics body
	using physics_entity: PhysicsEntity,
	vel:                  Vec2,
}

ExplodingBarrel :: struct {
	using moving_entity: MovingEntity,
	health:              f32, // When health reaches 0
	// Explosion radius and explosion power are the same for all barrels. those values are stored in constants
}

Enemy :: struct {
	using moving_entity:    MovingEntity,
	detection_range:        f32,
	detection_points:       [50]Vec2,
	attack_charge_range:    f32,
	start_charge_time:      f32,
	current_charge_time:    f32,
	charging:               bool,
	start_flinch_time:      f32,
	current_flinch_time:    f32,
	flinching:              bool,
	just_attacked:          bool,
	attack_poly:            Polygon,
	knockback_just_applied: bool,
	health:                 f32,
	max_health:             f32,
	current_path:           []Vec2,
	current_path_point:     int,
	pathfinding_timer:      f32,
	player_in_range:        bool,
}

Item :: struct {
	using moving_entity: MovingEntity,
	data:                ItemData,
}

Player :: struct {
	using moving_entity: MovingEntity,
	pickup_range:        f32,
	health:              f32,
	max_health:          f32,
	weapons:             [2]ItemData,
	items:               [6]ItemData,
	selected_weapon_idx: int,
	selected_item_idx:   int,
	item_count:          int,
	holding_item:        bool,
	item_hold_time:      f32,
	charging_weapon:     bool,
	weapon_charge_time:  f32,
	weapon_switched:     bool, // Only true for 1 frame
	item_switched:       bool,
	attacking:           bool,
}

ZEntity :: struct {
	using moving_entity: MovingEntity,
	z:                   f32,
	vel_z:               f32,
	rot:                 f32,
	rot_vel:             f32,
	sprite:              Sprite,
}

ProjectileWeapon :: struct {
	using zentity: ZEntity,
	data:          ItemData,
}

Bomb :: struct {
	using zentity: ZEntity,
	time_left:     f32,
}

Fire :: struct {
	using circle: Circle,
	time_left:    f32,
}

Sprite :: struct {
	tex_id:     TextureId,
	tex_region: rl.Rectangle, // part of the texture that is rendered
	scale:      Vec2, // scale of the sprite
	tex_origin: Vec2, // origin/center of the sprite relative to the texture. (0, 0) is top left corner
	rotation:   f32, // rotation in degress of the sprite
	tint:       rl.Color, // tint of the texture. WHITE will render the texture normally
}

new_enemy :: proc(pos: Vec2, attack_poly: Polygon) -> Enemy {
	return {
		pos = pos,
		shape = get_centered_rect({}, {16, 16}),
		detection_range = 80,
		attack_charge_range = 12,
		start_charge_time = 0.2,
		start_flinch_time = 0.2,
		attack_poly = attack_poly,
		knockback_just_applied = false,
		health = 80,
		max_health = 80,
	}
}
