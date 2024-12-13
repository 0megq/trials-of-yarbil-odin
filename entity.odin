package game

import "core:encoding/uuid"
import rl "vendor:raylib"

// EntityType :: union {
// 	Entity,
// 	PhysicsEntity,
// 	MovingEntity,
// 	ExplodingBarrel,
// 	Enemy,
// 	Player,
// 	Item,
// 	ZEntity,
// 	ProjectileWeapon,
// 	Arrow,
// 	Bomb,
// }


EntityType :: enum {
	Player,
	Enemy,
	Item,
	Arrow,
	Bomb,
	ExplodingBarrel,
	ProjectileWeapon,
	Wall,
}

Entity :: struct {
	id:             uuid.Identifier,
	pos:            Vec2,
	queue_free:     bool,
	start_disabled: bool,
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

// Wall :: PhysicsEntity

Wall :: struct {
	using physics_entity: PhysicsEntity,
	height: f32,
}

ExplodingBarrel :: struct {
	using moving_entity: MovingEntity,
	health:              f32, // When health reaches 0
	max_health:          f32,
	// Explosion radius and explosion power are the same for all barrels. those values are stored in constants
}

Enemy :: struct {
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

EnemyState :: enum {
	Idle,
	Distracted,
	Chasing,
	Charging,
	Attacking,
	Flinching,
	Fleeing,
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
	using moving_entity:   MovingEntity, // velocity is only valid while playing game. position and id should be saved. shape is const
	pickup_range:          f32, // const
	health:                f32, // should save
	max_health:            f32, // const
	weapons:               [2]ItemData, // should save
	items:                 [6]ItemData, // should save
	selected_weapon_idx:   int, // should save
	selected_item_idx:     int, // should save
	item_count:            int, // should save
	cur_ability:           MovementAbility, // should save
	holding_item:          bool, // valid only while playing game
	item_hold_time:        f32, // valid only while playing game
	charging_weapon:       bool, // valid only while playing game
	weapon_charge_time:    f32, // valid only while playing game
	weapon_switched:       bool, // valid only while playing game
	item_switched:         bool, // valid only while playing game
	attacking:             bool, // valid only while playing game
	cur_attack:            Attack, // valid only while playing game
	cur_weapon_anim:       WeaponAnimation, // valid only while playing game
	attack_dur_timer:      f32, // valid only while playing game
	can_attack:            bool, // valid only while playing game
	attack_interval_timer: f32, // valid only while playing game
	attack_poly:           Polygon, // valid only while playing game
	surfing:               bool, // valid only while playing game
	can_fire_dash:         bool, // valid only while playing game
	fire_dash_timer:       f32, // valid only while playing game
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

Rock :: struct {
	using zentity: ZEntity,
	attack:        Attack,
}

Arrow :: struct {
	using zentity: ZEntity,
	attack:        Attack,
	source:        uuid.Identifier,
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

LevelEntityType :: enum {
	Nil,
	Player,
	Enemy,
	ExplodingBarrel,
	Item,
}

Distraction :: struct {
	pos:          Vec2,
	time_emitted: f32,
	consumed:     bool,
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
	exclude_targets: [dynamic]uuid.Identifier,
}

AttackData :: union {
	ExplosionAttackData,
	SwordAttackData,
	FireAttackData,
	ProjectileAttackData,
	SurfAttackData,
	ArrowAttackData,
	RockAttackData,
}

SwordAttackData :: struct {}

FireAttackData :: struct {}

SurfAttackData :: struct {}

ExplosionAttackData :: struct {
	burn_instantly: bool,
}

ProjectileAttackData :: struct {
	projectile_idx:        int,
	speed_damage_ratio:    f32,
	speed_durablity_ratio: int,
}

ArrowAttackData :: struct {
	arrow_idx:          int,
	speed_damage_ratio: f32,
}

RockAttackData :: struct {
	rock_idx:           int,
	speed_damage_ratio: f32,
}

new_entity :: proc(pos: Vec2) -> Entity {
	return {uuid.generate_v4(), pos, false, false}
}

setup_melee_enemy :: proc(enemy: ^Enemy) {
	setup_enemy(enemy)
	if type_of(enemy.data) == MeleeEnemyData &&
	   enemy.data.(MeleeEnemyData).attack_poly.points != nil {
		delete(enemy.data.(MeleeEnemyData).attack_poly.points)
	}
	enemy.data = MeleeEnemyData{Polygon{{}, ENEMY_ATTACK_HITBOX_POINTS, 0}}
	enemy.detection_range = 80
	enemy.attack_charge_range = 12
	enemy.start_charge_time = 0.3
	enemy.start_flinch_time = 0.2
	enemy.detection_angle_sweep = 115
	max_health_setter(&enemy.health, &enemy.max_health, 80)
}

setup_ranged_enemy :: proc(enemy: ^Enemy) {
	setup_enemy(enemy)
	enemy.data = RangedEnemyData{60}
	enemy.detection_range = 160
	enemy.attack_charge_range = 120
	enemy.start_charge_time = 0.5
	enemy.start_flinch_time = 0.2
	enemy.detection_angle_sweep = 115
	max_health_setter(&enemy.health, &enemy.max_health, 60)
}

setup_enemy :: proc(enemy: ^Enemy) {
	enemy.shape = get_centered_rect({}, {16, 16})
}

setup_exploding_barrel :: proc(barrel: ^ExplodingBarrel) {
	barrel.shape = Circle{{}, 6}
	max_health_setter(&barrel.health, &barrel.max_health, 50)
}

setup_item :: proc(item: ^Item) {
	item.shape = Circle{{}, 4}
}

setup_player :: proc(player: ^Player) {
	player.can_fire_dash = true
	player.shape = PLAYER_SHAPE
	player.pickup_range = 16
	player.can_attack = true
	max_health_setter(&player.health, &player.max_health, 100)
}

max_health_setter :: proc(health: ^f32, cur_max_health: ^f32, new_max_health: f32) {
	// Set health
	if health^ == cur_max_health^ || health^ >= new_max_health {
		health^ = new_max_health
	}
	// Set max health
	cur_max_health^ = new_max_health
}
