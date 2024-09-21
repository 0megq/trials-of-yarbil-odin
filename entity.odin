package game

import "core:encoding/uuid"
import rl "vendor:raylib"


Entity :: struct {
	id:  uuid.Identifier,
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
	using moving_entity: MovingEntity,
	detection_range:     f32,
	detection_points:    [50]Vec2,
	attack_charge_range: f32, // Range for the enemy to start charging
	start_charge_time:   f32,
	current_charge_time: f32,
	charging:            bool,
	start_flinch_time:   f32,
	current_flinch_time: f32,
	flinching:           bool,
	just_attacked:       bool,
	health:              f32,
	max_health:          f32,
	current_path:        []Vec2,
	current_path_point:  int,
	pathfinding_timer:   f32,
	player_in_range:     bool,
	data:                EnemyData,
}

EnemyData :: union #no_nil {
	MeleeEnemyData,
	RangedEnemyData,
}

MeleeEnemyData :: struct {
	attack_poly: Polygon, // hitbox of attack
}

RangedEnemyData :: struct {
	flee_range: f32,
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
	current_attack:      Attack,
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
	attack:        Attack,
}

Arrow :: struct {
	using zentity: ZEntity,
	attack:        Attack,
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

EntityType :: enum {
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
	targets:         bit_set[EntityType],
	exclude_targets: [dynamic]uuid.Identifier,
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

new_entity :: proc(pos: Vec2) -> Entity {
	return {uuid.generate_v4(), pos}
}

new_melee_enemy :: proc(pos: Vec2, attack_poly: Polygon) -> Enemy {
	e := new_enemy(pos)
	e.data = MeleeEnemyData{attack_poly}
	return e
}

new_ranged_enemy :: proc(pos: Vec2) -> Enemy {
	e := new_enemy(pos)
	e.data = RangedEnemyData{60}
	e.attack_charge_range = 120
	e.detection_range = 160
	e.health = 60
	e.max_health = 60
	e.start_charge_time = 0.5
	return e
}

new_enemy :: proc(pos: Vec2) -> Enemy {
	return {
		entity = new_entity(pos),
		shape = get_centered_rect({}, {16, 16}),
		detection_range = 80,
		attack_charge_range = 12,
		start_charge_time = 0.3,
		start_flinch_time = 0.2,
		health = 80,
		max_health = 80,
	}
}
