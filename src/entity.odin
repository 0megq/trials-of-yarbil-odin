package game

import "core:encoding/uuid"
import "core:fmt"
import "core:math"
import "core:math/rand"
import rl "vendor:raylib"

@(private = "file")
fmt_i := fmt._arg_number

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

Wall :: PhysicsEntity

HalfWall :: struct {
	using physics_entity: PhysicsEntity,
	// In case we need to add extra things
}

ExplodingBarrel :: struct {
	using moving_entity: MovingEntity,
	health:              f32, // When health reaches 0
	max_health:          f32,
	// Explosion radius and explosion power are the same for all barrels. those values are stored in constants
}

Enemy :: Enemy3
Enemy3 :: struct {
	using moving_entity:           MovingEntity,
	post_pos:                      Vec2,
	target:                        Vec2, // target position to use when moving enemy
	variant:                       EnemyVariant,
	tex:                           TextureId,
	frame:                         Vec2i,
	// Pereception Data
	look_angle:                    f32, // direction they are looking (in degrees facing right going ccw)
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
	current_charge_time:           f32,
	attack_out:                    bool,
	attack:                        Attack,
	attack_state_timer:            f32,
	// Flinching
	current_flinch_time:           f32,
	// Idle
	idle_look_timer:               f32,
	idle_look_angle:               f32,
	// Health
	health:                        f32,
	// Pathfinding
	current_path:                  []Vec2,
	current_path_point:            int,
	pathfinding_timer:             f32,
	// State management
	state:                         EnemyState,
	sub_state:                     int,
	alert_timer:                   f32,
	search_timer:                  f32,
	// Sprite flash
	flash_opacity:                 f32,
	// Death
	death_timer:                   f32,
	weapon_side:                   int, // top is 1, bottom is -1
	attack_poly:                   Polygon,
	super_armor:                   bool,
	using const_data:              ConstEnemyData,
}

ConstEnemyData :: struct {
	hearing_range:        f32,
	vision_range:         f32,
	attack_charge_range:  f32, // Range for the enemy to start charging
	flee_range:           f32,
	vision_fov:           f32, // wideness (in degrees)
	start_charge_time:    f32,
	lunge_speed:          f32,
	lunge_time:           f32,
	attack_out_time:      f32,
	attack_recovery_time: f32,
	start_flinch_time:    f32,
	max_health:           f32,
	max_speed:            f32,
	draw_proc:            proc(e: Enemy3, in_editor := false),
}

EnemyState :: enum {
	Idle,
	Alerted,
	Chasing,
	Charging,
	Attacking,
	Fleeing,
	Searching,
	Flinching,
	Dying,
}

EnemyVariant :: enum {
	Melee,
	Ranged,
	Turret,
}

EnemyVariantData :: union #no_nil {
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
	attack_dur_timer:      f32, // valid only while playing game
	can_attack:            bool, // valid only while playing game
	attack_interval_timer: f32, // valid only while playing game
	attack_poly:           Polygon, // valid only while playing game
	surfing:               bool, // valid only while playing game
	can_dash:              bool, // valid only while playing game
	dash_dur_timer:        f32,
	dash_cooldown_timer:   f32, // valid only while playing game
	dash_ready_time:       f32,
	weapon_side:           int, // top is 1, bottom is -1
	attack_anim_timer:     f32,
	flip_sprite:           bool,
	flash_opacity:         f32,
}

ZEntity :: struct {
	using moving_entity: MovingEntity,
	z:                   f32,
	vel_z:               f32,
	rot:                 f32,
	rot_vel:             f32,
	sprite:              Sprite,
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

Alert :: struct {
	pos:            Vec2,
	range:          f32,
	base_intensity: f32,
	base_duration:  f32,
	decay_rate:     f32,
	is_visual:      bool,
	time_emitted:   f32,
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
	ArrowAttackData,
}

SwordAttackData :: struct {}

FireAttackData :: struct {}

ExplosionAttackData :: struct {
	burn_instantly: bool,
}

ArrowAttackData :: struct {
	arrow_idx: int,
}


new_entity :: proc(pos: Vec2) -> Entity {
	return {uuid.generate_v4(), pos, false, false}
}

setup_melee_enemy :: proc(enemy: ^Enemy) {
	delete(enemy.attack_poly.points)
	enemy.attack_poly = Polygon{{}, ENEMY_ATTACK_HITBOX_POINTS, 0}
	enemy.tex = .enemy_basic
	enemy.flee_range = 20
	enemy.hearing_range = 160
	enemy.vision_range = 100
	enemy.vision_fov = 180
	enemy.max_speed = 60
	enemy.attack_charge_range = 40
	enemy.start_charge_time = 0.2
	enemy.start_flinch_time = 0.2
	enemy.lunge_speed = 200
	enemy.lunge_time = 0.15
	enemy.attack_out_time = 0.2
	enemy.attack_recovery_time = 0.5
	enemy.draw_proc = draw_melee_enemy
	max_health_setter(&enemy.health, &enemy.max_health, 80)
}

setup_ranged_enemy :: proc(enemy: ^Enemy) {
	enemy.tex = .enemy_ranged
	enemy.flee_range = 60
	enemy.hearing_range = 160
	enemy.vision_range = 120
	enemy.vision_fov = 120
	enemy.max_speed = 60
	enemy.attack_charge_range = 120
	enemy.start_charge_time = 0.6
	enemy.start_flinch_time = 0.2
	enemy.draw_proc = draw_ranged_enemy
	max_health_setter(&enemy.health, &enemy.max_health, 80)
}

setup_turret_enemy :: proc(enemy: ^Enemy) {
	enemy.hearing_range = 160
	enemy.vision_range = 120
	enemy.vision_fov = 360
	enemy.max_speed = 0
	enemy.attack_charge_range = 120
	enemy.start_charge_time = 0.5
	enemy.start_flinch_time = 0.27
	enemy.draw_proc = draw_turret

}

draw_turret :: proc(e: Enemy, in_editor := false) {
	if in_editor {
		rl.DrawCircleLinesV(e.pos, e.vision_range, rl.YELLOW)
		// rl.DrawCircleV(e.pos, ENEMY_POST_RANGE, {255, 0, 0, 100})
	}

	base_tex := loaded_textures[.turret_base]
	base_sprite := Sprite {
		tex_id     = .turret_base,
		tex_origin = Vec2{f32(base_tex.width), f32(base_tex.height)} / 2,
		tex_region = Rectangle{0, 0, f32(base_tex.width), f32(base_tex.height)},
		rotation   = 0,
		scale      = 1,
		tint       = rl.WHITE,
	}

	draw_sprite(base_sprite, e.pos)

	head_tex := loaded_textures[.turret_head]
	head_sprite := Sprite {
		tex_id     = .turret_head,
		tex_origin = Vec2{2.5, 2.5},
		tex_region = Rectangle{0, 0, f32(head_tex.width), f32(head_tex.height)},
		rotation   = e.look_angle,
		scale      = 1,
		tint       = rl.WHITE,
	}

	draw_sprite(head_sprite, e.pos)
}

draw_melee_enemy :: proc(e: Enemy, in_editor := false) {
	e := e
	// shake when charging
	shake_amount: f32
	if e.state == .Charging {
		shake_amount = 0.5
	} else if e.state == .Flinching {
		shake_amount = 0.5
	}
	e.pos += vector_from_angle(rand.float32() * 360) * shake_amount

	// DEBUG: Draw collision shape
	// draw_shape(e.shape, e.pos, rl.GREEN)
	// draw vision and post range
	when ODIN_DEBUG do if in_editor {
		rl.DrawCircleLinesV(e.pos, e.vision_range, rl.YELLOW)
		rl.DrawCircleV(e.pos, ENEMY_POST_RANGE, {255, 0, 0, 100})
	}

	// when ODIN_DEBUG {
	// 	rl.DrawCircleLinesV(e.pos, e.flee_range, rl.GREEN)
	// }

	// Setup sprites
	sprite: Sprite
	sprite.scale = 1
	sprite.tex_id = e.tex
	sprite.tint = {255, 255, 255, 255}
	sprite.tex_region = get_frame_region(e.frame, e.tex)
	frame_size := get_frame_size(sprite.tex_id)
	sprite.tex_origin = {f32(frame_size.x), f32(frame_size.y)} / 2

	// Looking
	flipped := false
	if e.look_angle < -90 || e.look_angle > 90 {
		flipped = true
		sprite.scale.x = -1
	}

	// Look arrow
	// draw_polygon({e.pos, {{5, -10}, {10, 0}, {5, 10}}, e.look_angle}, rl.WHITE)

	// Draw sprites
	rl.BeginShaderMode(shader)
	col_override: [4]f32 = {1, 1, 1, math.round(e.flash_opacity - 0.1)}
	if e.state == .Charging && (e.current_charge_time < 0.05) {
		col_override = {0, 1, 1, 1}
	}
	rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "col_override"), &col_override, .VEC4)
	draw_sprite(sprite, e.pos)


	// Draw health bar
	if e.state != .Dying {
		health_bar_length: f32 = 20
		health_bar_height: f32 = 5
		health_bar_base_rec := get_centered_rect(
			{e.pos.x, e.pos.y - 20},
			{health_bar_length, health_bar_height},
		)
		rl.DrawRectangleRec(health_bar_base_rec, rl.BLACK)
		health_bar_filled_rec := health_bar_base_rec
		health_bar_filled_rec.width *= e.health / e.max_health
		rl.DrawRectangleRec(health_bar_filled_rec, rl.RED)
	}


	// DEBUG: Draw ID
	// rl.DrawTextEx(
	// 	rl.GetFontDefault(),
	// 	fmt.ctprintf(uuid.to_string(enemy.id, context.temp_allocator)),
	// 	e.pos + {0, -10},
	// 	8,
	// 	2,
	// 	rl.YELLOW,
	// )

	// attack_area_color := rl.Color{255, 255, 255, 120}
	// if e.attack_out {
	// 	attack_area_color = rl.Color{255, 0, 0, 120}
	// }
	// // Draw weapons and attack vfx
	// if e.state != .Dying {
	// 	// Draw hitbox
	// 	when ODIN_DEBUG do draw_shape(e.attack_poly, e.pos, attack_area_color)
	// }

	rl.EndShaderMode()

	// Display state
	// when ODIN_DEBUG {
	// 	draw_text(
	// 		e.pos + {0, -8},
	// 		{0, 1},
	// 		fmt.ctprint(e.state, e.sub_state),
	// 		rl.GetFontDefault(),
	// 		6,
	// 		1,
	// 		rl.WHITE,
	// 	)
	// }


	// Draw vision area
	// when ODIN_DEBUG {
	// 	rl.DrawCircleLinesV(e.pos, e.vision_range, rl.YELLOW)
	// 	for p, i in e.vision_points {
	// 		rl.DrawLineV(
	// 			p,
	// 			e.vision_points[(i + 1) % len(e.vision_points)],
	// 			rl.YELLOW,
	// 		)
	// 	}
	// }

	// DEBUG: e path
	// if e.current_path != nil {
	// 	for point in e.current_path {
	// 		rl.DrawCircleV(point, 2, rl.RED)
	// 	}
	// }
}


// Draw proc for ranged and melee enemies
draw_ranged_enemy :: proc(e: Enemy, in_editor := false) {
	e := e
	// Shake when charging or flinching
	shake_amount: f32
	if e.state == .Charging {
		shake_amount = 0.5
	} else if e.state == .Flinching {
		shake_amount = 0.5
	}
	e.pos += vector_from_angle(rand.float32() * 360) * shake_amount

	// DEBUG: Draw collision shape
	// draw_shape(e.shape, e.pos, rl.GREEN)
	when ODIN_DEBUG do if in_editor {
		rl.DrawCircleLinesV(e.pos, e.vision_range, rl.YELLOW)
		rl.DrawCircleV(e.pos, ENEMY_POST_RANGE, {255, 0, 0, 100})
	}

	// when ODIN_DEBUG {
	// 	rl.DrawCircleLinesV(e.pos, e.attack_charge_range, rl.GREEN)
	// }

	// Setup sprites
	sprite: Sprite
	sprite.scale = 1
	sprite.tex_id = e.tex
	sprite.tint = {255, 255, 255, 255}
	sprite.tex_region = get_frame_region(e.frame, e.tex)
	frame_size := get_frame_size(sprite.tex_id)
	sprite.tex_origin = {f32(frame_size.x), f32(frame_size.y)} / 2

	// Looking
	flipped := false
	if e.look_angle < -90 || e.look_angle > 90 {
		flipped = true
		sprite.scale.x = -1
	}

	// Look arrow
	// draw_polygon({e.pos, {{5, -10}, {10, 0}, {5, 10}}, e.look_angle}, rl.WHITE)

	// Draw sprites
	rl.BeginShaderMode(shader)
	col_override: [4]f32 = {1, 1, 1, math.round(e.flash_opacity - 0.1)}
	if e.state == .Charging && (e.current_charge_time < 0.05) {
		col_override = {0, 1, 1, 1}
	}
	rl.SetShaderValue(shader, rl.GetShaderLocation(shader, "col_override"), &col_override, .VEC4)
	draw_sprite(sprite, e.pos)


	// Draw health bar
	if e.state != .Dying {
		health_bar_length: f32 = 20
		health_bar_height: f32 = 5
		health_bar_base_rec := get_centered_rect(
			{e.pos.x, e.pos.y - 20},
			{health_bar_length, health_bar_height},
		)
		rl.DrawRectangleRec(health_bar_base_rec, rl.BLACK)
		health_bar_filled_rec := health_bar_base_rec
		health_bar_filled_rec.width *= e.health / e.max_health
		rl.DrawRectangleRec(health_bar_filled_rec, rl.RED)
	}

	// DEBUG: Draw ID
	// rl.DrawTextEx(
	// 	rl.GetFontDefault(),
	// 	fmt.ctprintf(uuid.to_string(enemy.id, context.temp_allocator)),
	// 	e.pos + {0, -10},
	// 	8,
	// 	2,
	// 	rl.YELLOW,
	// )
	// Draw weapons and attack vfx
	if e.state != .Dying {
		tex_id := TextureId.bow
		tex := loaded_textures[tex_id]
		// Animate
		anim_length := e.start_charge_time
		anim_cur := math.clamp(e.current_charge_time, 0, anim_length)
		if e.state != .Charging {
			anim_cur = anim_length
		}

		frame_count := int(get_frame_count(tex_id).x)
		frame_index := int(math.floor(math.remap(anim_cur, anim_length, 0, 0, f32(frame_count))))
		if frame_index >= frame_count {
			frame_index -= 1
		}

		frame_size := tex.width / i32(frame_count)

		bow_sprite: Sprite = {
			tex_id     = tex_id,
			tex_region = {f32(frame_index) * f32(frame_size), 0, f32(frame_size), f32(tex.height)},
			scale      = 1,
			tex_origin = {7.5, 7.5},
			rotation   = 0,
			tint       = rl.WHITE,
		}
		sprite_pos := e.pos

		if flipped {
			bow_sprite.scale.x = -1
			bow_sprite.rotation += 180
		}

		// rotation offset
		// bow_sprite.rotation = 0

		// position offset
		offset: Vec2 : {5, 0}
		sprite_pos += offset

		// Rotate sprite and rotate its position to face mouse
		bow_sprite.rotation += e.look_angle
		sprite_pos = rotate_about_origin(sprite_pos, e.pos, e.look_angle)
		draw_sprite(bow_sprite, sprite_pos)
	}

	rl.EndShaderMode()

	// Display state
	// when ODIN_DEBUG {
	// 	draw_text(
	// 		e.pos + {0, -8},
	// 		{0, 1},
	// 		fmt.ctprint(e.state, e.sub_state),
	// 		rl.GetFontDefault(),
	// 		6,
	// 		1,
	// 		rl.WHITE,
	// 	)
	// }


	// Draw vision area
	// when ODIN_DEBUG {
	// 	rl.DrawCircleLinesV(e.pos, e.vision_range, rl.YELLOW)
	// 	for p, i in e.vision_points {
	// 		rl.DrawLineV(
	// 			p,
	// 			e.vision_points[(i + 1) % len(e.vision_points)],
	// 			rl.YELLOW,
	// 		)
	// 	}
	// }

	// DEBUG: e path
	// if e.current_path != nil {
	// 	for point in e.current_path {
	// 		rl.DrawCircleV(point, 2, rl.RED)
	// 	}
	// }
}

setup_enemy :: proc(enemy: ^Enemy, variant: EnemyVariant) {
	enemy.post_pos = enemy.pos
	enemy.shape = get_centered_rect({}, {16, 16})
	enemy.weapon_side = 1
	enemy.variant = variant
	change_enemy_state(enemy, .Idle, main_world)
	switch enemy.variant {
	case .Melee:
		setup_melee_enemy(enemy)
	case .Ranged:
		setup_ranged_enemy(enemy)
	case .Turret:
		setup_turret_enemy(enemy)
	}
}

setup_exploding_barrel :: proc(barrel: ^ExplodingBarrel) {
	barrel.shape = Circle{{}, 6}
	max_health_setter(&barrel.health, &barrel.max_health, 50)
}

setup_item :: proc(item: ^Item) {
	item.shape = Circle{{}, 4}
}

setup_player :: proc(player: ^Player) {
	player.can_dash = true
	player.weapon_side = 1
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

draw_sprite :: proc(sprite: Sprite, pos: Vec2) {
	tex := loaded_textures[sprite.tex_id]
	dst_rec := Rectangle {
		pos.x,
		pos.y,
		f32(sprite.tex_region.width) * math.abs(sprite.scale.x), // scale the sprite. a negative would mess this up
		f32(sprite.tex_region.height) * math.abs(sprite.scale.y),
	}

	src_rec := Rectangle {
		sprite.tex_region.x,
		sprite.tex_region.y,
		sprite.tex_region.width * math.sign(sprite.scale.x), // Flip the texture, based off sprite scale
		sprite.tex_region.height * math.sign(sprite.scale.y),
	}

	rl.DrawTexturePro(
		tex,
		src_rec,
		dst_rec,
		sprite.tex_origin * abs(sprite.scale),
		sprite.rotation,
		sprite.tint,
	)
}
