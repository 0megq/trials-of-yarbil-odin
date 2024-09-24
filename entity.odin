package game

import "core:mem"
import rl "vendor:raylib"

MAX_ENTITY_COUNT :: 1024
SWORD_ANIMATION_START :: WeaponAnimation{-70, -160, 70, 160, 0, 0, -70, -160}


ArchetypeID :: enum {
	Nil = 0,
	Player = 1,
	MeleeEnemy = 2,
	RangedEnemy = 3,
	ExplodingBarrel = 4,
	Bomb = 5,
	Obstacle = 6,
	Item = 7,
	Arrow = 8,
	ProjectileWeapon = 9,
	Max,
}

Entity :: struct {
	// basic
	is_valid:              bool,
	id:                    int,
	arch:                  ArchetypeID,
	// physics
	pos:                   Vec2,
	vel:                   Vec2,
	// other
	health:                f32,
	// item
	item_data:             ItemData,
	// z entity
	z:                     f32,
	z_vel:                 f32,
	rot:                   f32,
	rot_vel:               f32,
	attack:                Attack,
	// bomb
	time_till_explosion:   f32,
	// enemy
	cur_path:              []Vec2, // no serialization
	cur_path_index:        int,
	recalc_path_timer:     f32,
	player_in_range:       bool,
	detection_points:      [50]Vec2, // potentially make this a pointer to avoid memory explosion (stack overflow)
	// attacking and hurting
	cant_attack:           bool,
	attack_dur_time_left:  f32,
	attack_cool_time_left: f32,
	cur_charge_time:       f32,
	flinch_time_left:      f32, // no serialization
	attack_poly:           Polygon,
	state:                 EntityState,

	// state that is derived by archetype and does not need serialization. remains constant
	attack_charge_range:   f32, // Range for the enemy to start charging
	attack_dur_time:       f32,
	attack_cool_time:      f32,
	charge_time:           f32,
	flinch_time:           f32,
	flee_range:            f32,
	pickup_range:          f32,
	sprite_id:             SpriteId,
	shape:                 Shape,
	max_health:            f32,
	has_physics:           bool,
	z_enabled:             bool,
	rot_enabled:           bool,
	acceleration:          f32,
	friction:              f32,
	max_speed:             f32,
	harsh_friction:        f32,

	// state that is valid for a single frame
	frame:                 EntityFrame,
	last_frame:            EntityFrame,
}

EntityHandle :: struct {
	id:    int,
	index: int,
}

// Data that is only valid for a single frame
EntityFrame :: struct {
	just_attacked:     bool,
	item_switched:     bool,
	weapon_switched:   bool,
	is_creation:       bool,
	acceleration_axis: Vec2,
}

EntityState :: enum {
	Nil       = 0,
	Idle      = 1,
	Attacking = 2, // in the middle of an attack
	Charging  = 3, // charging attack or charging weapon to throw
	Holding   = 4, // holding item
	Moving    = 5,
	Flinching = 6,
}

World :: struct {
	id_count:    int,
	entities:    [MAX_ENTITY_COUNT]Entity,

	// player specific data
	player_data: PlayerData,
}
world: ^World = nil

WorldFrame :: struct {
	player: ^Entity,
}
world_frame: WorldFrame

PlayerData :: struct {
	weapons:             [2]ItemData,
	items:               [6]ItemData,
	item_count:          int,
	selected_weapon_idx: int,
	selected_item_idx:   int,
	cur_item_time:       f32,
	surfing:             bool,
	cur_ability:         MovementAbility,
	can_fire_dash:       bool,
	fire_dash_timer:     f32,

	// weapon-related variables
	sword_animation:     WeaponAnimation,
}

WeaponAnimation :: struct {
	// Constants
	cpos_top_rotation:    f32,
	csprite_top_rotation: f32,
	cpos_bot_rotation:    f32,
	csprite_bot_rotation: f32,

	// For animation purposes
	pos_rotation_vel:     f32, // Simulates the rotation of the arc of the swing
	sprite_rotation_vel:  f32, // Simulates the rotation of the sprite

	// Weapon rotations
	pos_cur_rotation:     f32,
	sprite_cur_rotation:  f32,
}

entity_create :: proc() -> ^Entity {
	entity_found: ^Entity = nil
	for i in 1 ..< MAX_ENTITY_COUNT {
		existing_entity: ^Entity = &world.entities[i]
		if (!existing_entity.is_valid) {
			entity_found = existing_entity
			break
		}
	}

	if entity_found == nil {
		rl.TraceLog(.ERROR, "No more free entities")
	}
	entity_found.is_valid = true

	world.id_count += 1
	entity_found.id = world.id_count
	entity_found.frame.is_creation = true

	return entity_found
}

handle_from_entity :: proc(en: ^Entity) -> EntityHandle {
	index := mem.ptr_sub(en, &world.entities[0])
	return {en.id, index}
}

entity_from_handle :: proc(handle: EntityHandle) -> ^Entity {
	en: ^Entity = &world.entities[handle.index]
	if en.id == handle.id {
		return en
	} else {
		return get_nil_entity()
	}
}

entity_zero_immediately :: proc(en: ^Entity) {
	en^ = {}
}

get_nil_entity :: proc() -> ^Entity {
	return &world.entities[0]
}

is_nil :: proc(en: ^Entity) -> bool {
	return en == get_nil_entity()
}

get_player :: proc() -> ^Entity {
	return world_frame.player
}

setup_player :: proc(en: ^Entity) {
	en.arch = .Player

	en.max_speed = 80
	en.acceleration = 1500
	en.friction = 750
	en.harsh_friction = 2000
	en.attack_dur_time = 0.15
	en.attack_cool_time = 0.4
}

Fire :: struct {
	using circle: Circle,
	time_left:    f32,
}


AttackTarget :: enum {
	Player,
	Enemy,
	Wall,
	ExplodingBarrel,
	Bomb,
	Item,
	Tile,
}

Attack :: struct {
	pos:             Vec2,
	shape:           Shape,
	damage:          f32,
	knockback:       f32,
	direction:       Vec2,
	data:            AttackData,
	targets:         bit_set[AttackTarget],
	exclude_targets: [MAX_ENTITY_COUNT]EntityHandle,
}

AttackData :: union {
	ExplosionAttackData,
	SwordAttackData,
	FireAttackData,
	ProjectileAttackData,
	SurfAttackData,
	ArrowAttackData,
}

SwordAttackData :: struct {}

FireAttackData :: struct {}

SurfAttackData :: struct {}

ExplosionAttackData :: struct {}

ProjectileAttackData :: struct {
	projectile_idx:        int,
	speed_damage_ratio:    f32,
	speed_durablity_ratio: int,
}

ArrowAttackData :: struct {
	arrow_idx:          int,
	speed_damage_ratio: f32,
}


// new_entity :: proc(pos: Vec2) -> Entity {
// 	return {uuid.generate_v4(), pos}
// }

// new_melee_enemy :: proc(pos: Vec2, attack_poly: Polygon) -> Enemy {
// 	e := new_enemy(pos)
// 	e.data = MeleeEnemyData{attack_poly}
// 	return e
// }

// new_ranged_enemy :: proc(pos: Vec2) -> Enemy {
// 	e := new_enemy(pos)
// 	e.data = RangedEnemyData{60}
// 	e.attack_charge_range = 120
// 	e.detection_range = 160
// 	e.health = 60
// 	e.max_health = 60
// 	e.start_charge_time = 0.5
// 	return e
// }

// new_enemy :: proc(pos: Vec2) -> Enemy {
// 	return {
// 		entity = new_entity(pos),
// 		shape = get_centered_rect({}, {16, 16}),
// 		detection_range = 80,
// 		attack_charge_range = 12,
// 		start_charge_time = 0.3,
// 		start_flinch_time = 0.2,
// 		health = 80,
// 		max_health = 80,
// 	}
// }
