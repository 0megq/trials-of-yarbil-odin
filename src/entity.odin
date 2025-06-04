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
	attack_out:                    bool,
	attack:                        Attack,
	attack_state_timer:            f32,
	lunge_time:                    f32,
	// Flinching
	start_flinch_time:             f32,
	current_flinch_time:           f32,
	// Idle
	idle_look_timer:               f32,
	idle_look_angle:               f32,
	// Health
	health:                        f32,
	max_health:                    f32,
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
	flee_range:                    f32,
	attack_poly:                   Polygon,
	max_speed:                     f32,
	draw_proc:                     proc(e: Enemy3, in_editor := false),
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
	can_fire_dash:         bool, // valid only while playing game
	fire_dash_timer:       f32, // valid only while playing game
	fire_dash_ready_time:  f32,
	weapon_side:           int, // top is 1, bottom is -1
	attack_anim_timer:     f32,
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

SwordAttackData :: struct {
}

FireAttackData :: struct {
}

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
	enemy.hearing_range = 160
	enemy.vision_range = 100
	enemy.vision_fov = 120
	enemy.max_speed = 60
	enemy.attack_charge_range = 40
	enemy.start_charge_time = 0.3
	enemy.start_flinch_time = 0.2
	enemy.lunge_time = 0.1
	enemy.tex = .EnemyBasic2
	enemy.draw_proc = draw_melee_enemy
	max_health_setter(&enemy.health, &enemy.max_health, 80)
}

setup_ranged_enemy :: proc(enemy: ^Enemy) {
	enemy.flee_range = 60
	enemy.hearing_range = 160
	enemy.vision_range = 120
	enemy.vision_fov = 120
	enemy.max_speed = 60
	enemy.attack_charge_range = 120
	enemy.start_charge_time = 0.6
	enemy.start_flinch_time = 0.2
	enemy.draw_proc = draw_enemy
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

	base_tex := loaded_textures[.TurretBase]
	base_sprite := Sprite {
		tex_id     = .TurretBase,
		tex_origin = Vec2{f32(base_tex.width), f32(base_tex.height)} / 2,
		tex_region = Rectangle{0, 0, f32(base_tex.width), f32(base_tex.height)},
		rotation   = 0,
		scale      = 1,
		tint       = rl.WHITE,
	}

	draw_sprite(base_sprite, e.pos)

	head_tex := loaded_textures[.TurretHead]
	head_sprite := Sprite {
		tex_id     = .TurretHead,
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
	if e.state == .Charging {
		shake_amount :: 0.5
		e.pos += vector_from_angle(rand.float32() * 360) * shake_amount
	}

	// DEBUG: Draw collision shape
	// draw_shape(enemy.shape, e.pos, rl.GREEN)
	// draw vision and post range
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
	// sprite.rotation = e.look_angle
	if e.look_angle < -90 || e.look_angle > 90 {
		flipped = true
		sprite.scale.x = -1
		// sprite.rotation += 180
	}

	// Flash sprite
	flash_sprite := sprite
	flash_sprite.tex_region = get_frame_region({0, 1}, e.tex)
	flash_sprite.tex_origin = sprite.tex_origin
	flash_sprite.tint = {
		255,
		255,
		255,
		u8(math.clamp(math.remap(e.flash_opacity, 0, 1, 0, 255), 0, 255)),
	}

	// Draw sprites
	draw_sprite(sprite, e.pos)
	draw_sprite(flash_sprite, e.pos)


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

	attack_area_color := rl.Color{255, 255, 255, 120}
	if e.attack_out {
		attack_area_color = rl.Color{255, 0, 0, 120}
	}
	// Draw weapons and attack vfx
	if e.state != .Dying {
		// position, rotate, and animate sprite based on look direction and attack animation
		sprite_rotation: f32
		pos_rotation: f32
		if e.attack_state_timer > 0 && e.state == .Attacking && e.sub_state == 1 {
			alpha: f32 = math.remap(e.attack_state_timer, ATTACK_ANIM_TIME, 0, 0, 1)
			pos_rotation =
				math.remap(ease_out_back(alpha), 0, 1, -1, 1) *
				sword_pos_max_rotation *
				f32(e.weapon_side)
			sprite_rotation =
				math.remap(ease_out_back(alpha), 0, 1, -1, 1) *
				sword_sprite_max_rotation *
				f32(e.weapon_side)
		} else {
			pos_rotation = sword_pos_max_rotation * f32(e.weapon_side)
			sprite_rotation = sword_sprite_max_rotation * f32(e.weapon_side)
		}


		tex_id := TextureId.Sword
		tex := loaded_textures[tex_id]

		sword_sprite: Sprite = {
			tex_id     = tex_id,
			tex_region = {0, 0, f32(tex.width), f32(tex.height)},
			scale      = 1,
			tex_origin = {0, 1},
			rotation   = 0,
			tint       = rl.WHITE,
		}
		sprite_pos := e.pos

		// if flipped {
		// 	sword_sprite.scale.x = -1
		// 	sword_sprite.rotation += 180
		// }

		// position and rotation offset
		sword_sprite.rotation = sprite_rotation

		radius :: 5
		offset: Vec2 : {2, 0}
		sprite_pos += offset + radius * vector_from_angle(pos_rotation)

		// Rotate sprite and rotate its position to face mouse
		sword_sprite.rotation += e.look_angle
		sprite_pos = rotate_about_origin(sprite_pos, e.pos, e.look_angle)
		draw_sprite(sword_sprite, sprite_pos)

		// Draw hitbox
		// when ODIN_DEBUG do draw_shape(e.attack_poly, e.pos, attack_area_color)

		// Draw Vfx slash
		if e.attack_state_timer > 0 && e.state == .Attacking && e.sub_state == 1 {
			// Setup sprite
			vfx_tex := loaded_textures[.HitVfx]
			vfx_sprite := Sprite {
				tex_id     = .HitVfx,
				tex_region = {},
				scale      = 1,
				tex_origin = {0, f32(vfx_tex.height) / 2},
				rotation   = e.attack_poly.rotation,
				tint       = rl.WHITE,
			}
			// Animate
			vfx_sprite.tex_region = get_current_frame_region(
				e.attack_state_timer,
				ATTACK_ANIM_TIME,
				0,
				vfx_sprite.tex_id,
			)
			// Draw
			draw_sprite(vfx_sprite, e.pos)
		}
	}


	// Display state
	when ODIN_DEBUG {
		draw_text(
			e.pos + {0, -8},
			{0, 1},
			fmt.ctprint(e.state, e.sub_state),
			rl.GetFontDefault(),
			6,
			1,
			rl.WHITE,
		)
	}


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
draw_enemy :: proc(e: Enemy, in_editor := false) {
	e := e
	if e.variant == .Melee && e.state == .Charging {
		shake_amount :: 0.5
		e.pos += vector_from_angle(rand.float32() * 360) * shake_amount
	}

	// DEBUG: Draw collision shape
	// draw_shape(enemy.shape, e.pos, rl.GREEN)
	when ODIN_DEBUG do if in_editor {
		rl.DrawCircleLinesV(e.pos, e.vision_range, rl.YELLOW)
		rl.DrawCircleV(e.pos, ENEMY_POST_RANGE, {255, 0, 0, 100})
	}

	// when ODIN_DEBUG {
	// 	rl.DrawCircleLinesV(e.pos, e.attack_charge_range, rl.GREEN)
	// }

	// Setup sprites
	sprite: Sprite
	sprite.tex_region = get_frame_region(e.frame, e.tex)
	frame_size := get_frame_size(sprite.tex_id)
	sprite.tex_origin = {f32(frame_size.x), f32(frame_size.y)} / 2

	// if e.state == .Charging {
	// 	sprite.tex_id = .EnemyBasic2
	// }
	// if e.state == .Attacking {
	// 	sprite.tex_id = .EnemyBasic2
	// 	sprite.tex_region = get_current_frame_region(
	// 		e.attack_full_timer,
	// 		0,
	// 		0.1 + ATTACK_ANIM_TIME + 0.5,
	// 		sprite.tex_id,
	// 	)
	// }

	// Looking
	flipped := false
	sprite.rotation = e.look_angle
	if sprite.rotation < -90 || sprite.rotation > 90 {
		flipped = true
		sprite.scale = {-1, 1}
		sprite.rotation += 180
	}

	// Animate when death
	// if e.state == .Dying {
	// 	sprite.tex_id = .EnemyBasicDeath
	// 	sprite.tex_region = get_current_frame_region(
	// 		e.death_timer,
	// 		0,
	// 		ENEMY_DEATH_ANIMATION_TIME,
	// 		sprite.tex_id,
	// 	)
	// }

	// Flash sprite
	flash_sprite := sprite
	flash_sprite.tint = {
		255,
		255,
		255,
		u8(math.clamp(math.remap(e.flash_opacity, 0, 1, 0, 255), 0, 255)),
	}
	flash_sprite.tex_id = .EnemyBasicFlash

	// Switch to ranged version
	if e.variant == .Ranged {
		sprite.tex_id = .EnemyRanged
		if e.state == .Dying {
			sprite.tex_id = .EnemyRangedDeath
		}
		flash_sprite.tex_id = .EnemyRangedFlash
	}

	// Draw sprites
	draw_sprite(sprite, e.pos)
	draw_sprite(flash_sprite, e.pos)


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

	attack_area_color := rl.Color{255, 255, 255, 120}
	if e.attack_out {
		attack_area_color = rl.Color{255, 0, 0, 120}
	}
	// Draw weapons and attack vfx
	if e.state != .Dying {
		#partial switch e.variant {
		case .Melee:
			// position, rotate, and animate sprite based on look direction and attack animation
			sprite_rotation: f32
			pos_rotation: f32
			if e.attack_state_timer > 0 && e.state == .Attacking && e.sub_state == 1 {
				alpha: f32 = math.remap(e.attack_state_timer, ATTACK_ANIM_TIME, 0, 0, 1)
				pos_rotation =
					math.remap(ease_out_back(alpha), 0, 1, -1, 1) *
					sword_pos_max_rotation *
					f32(e.weapon_side)
				sprite_rotation =
					math.remap(ease_out_back(alpha), 0, 1, -1, 1) *
					sword_sprite_max_rotation *
					f32(e.weapon_side)
			} else {
				pos_rotation = sword_pos_max_rotation * f32(e.weapon_side)
				sprite_rotation = sword_sprite_max_rotation * f32(e.weapon_side)
			}


			tex_id := TextureId.Sword
			tex := loaded_textures[tex_id]

			sword_sprite: Sprite = {
				tex_id     = tex_id,
				tex_region = {0, 0, f32(tex.width), f32(tex.height)},
				scale      = 1,
				tex_origin = {0, 1},
				rotation   = 0,
				tint       = rl.WHITE,
			}
			sprite_pos := e.pos

			// if flipped {
			// 	sword_sprite.scale.x = -1
			// 	sword_sprite.rotation += 180
			// }

			// position and rotation offset
			sword_sprite.rotation = sprite_rotation

			radius :: 5
			offset: Vec2 : {2, 0}
			sprite_pos += offset + radius * vector_from_angle(pos_rotation)

			// Rotate sprite and rotate its position to face mouse
			sword_sprite.rotation += e.look_angle
			sprite_pos = rotate_about_origin(sprite_pos, e.pos, e.look_angle)
			draw_sprite(sword_sprite, sprite_pos)

			// Draw hitbox
			// when ODIN_DEBUG do draw_shape(e.attack_poly, e.pos, attack_area_color)

			// Draw Vfx slash
			if e.attack_state_timer > 0 && e.state == .Attacking && e.sub_state == 1 {
				// Setup sprite
				vfx_tex := loaded_textures[.HitVfx]
				vfx_sprite := Sprite {
					tex_id     = .HitVfx,
					tex_region = {},
					scale      = 1,
					tex_origin = {0, f32(vfx_tex.height) / 2},
					rotation   = e.attack_poly.rotation,
					tint       = rl.WHITE,
				}
				// Animate
				vfx_sprite.tex_region = get_current_frame_region(
					e.attack_state_timer,
					ATTACK_ANIM_TIME,
					0,
					vfx_sprite.tex_id,
				)
				// Draw
				draw_sprite(vfx_sprite, e.pos)
			}
		case .Ranged:
			tex_id := TextureId.Bow
			tex := loaded_textures[tex_id]
			// Animate
			anim_length := e.start_charge_time
			anim_cur := math.clamp(e.current_charge_time, 0, anim_length)
			if e.state != .Charging {
				anim_cur = anim_length
			}

			frame_count := int(get_frame_count(tex_id).x)
			frame_index := int(
				math.floor(math.remap(anim_cur, anim_length, 0, 0, f32(frame_count))),
			)
			if frame_index >= frame_count {
				frame_index -= 1
			}

			frame_size := tex.width / i32(frame_count)

			bow_sprite: Sprite = {
				tex_id     = tex_id,
				tex_region = {
					f32(frame_index) * f32(frame_size),
					0,
					f32(frame_size),
					f32(tex.height),
				},
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
	}


	// Display state
	when ODIN_DEBUG {
		draw_text(
			e.pos + {0, -8},
			{0, 1},
			fmt.ctprint(e.state, e.sub_state),
			rl.GetFontDefault(),
			6,
			1,
			rl.WHITE,
		)
	}


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

setup_enemy :: proc(enemy: ^Enemy) {
	enemy.post_pos = enemy.pos
	enemy.shape = get_centered_rect({}, {16, 16})
	enemy.weapon_side = 1
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
	player.can_fire_dash = true
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
