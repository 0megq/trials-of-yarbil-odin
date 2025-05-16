package game

import "core:encoding/uuid"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:slice"
import rl "vendor:raylib"

// world data
World :: struct {
	player:            Player,
	enemies:           [dynamic]Enemy,
	disabled_enemies:  [dynamic]Enemy,
	items:             [dynamic]Item,
	disabled_items:    [dynamic]Item,
	exploding_barrels: [dynamic]ExplodingBarrel,
	tilemap:           Tilemap,
	wall_tilemap:      WallTilemap,
	nav_graph:         NavGraph,
	walls:             [dynamic]Wall,
	half_walls:        [dynamic]HalfWall,
	bombs:             [dynamic]Bomb,
	arrows:            [dynamic]Arrow,
	fires:             [dynamic]Fire,
	alerts:            [dynamic]Alert,
}

// pause_game: f32 = 0

screen_shake_time: f32 = 0
screen_shake_intensity: f32 = 1

world_update :: proc() {
	// Perform Queued World Actions (death and deletion). Remove things from the previous frame
	if main_world.player.queue_free {
		on_player_death()
		main_world.player.queue_free = false
	}
	#reverse for barrel, i in main_world.exploding_barrels { 	// This needs to be in reverse since we are removing
		if barrel.queue_free {
			unordered_remove(&main_world.exploding_barrels, i)
		}
	}

	// Check player collision with portal
	player_at_portal = check_collision_shapes(
		Circle{{}, PORTAL_RADIUS},
		level.portal_pos,
		main_world.player.shape,
		main_world.player.pos,
	)
	// Do next level stuff
	if all_enemies_dying(main_world) &&
	   is_control_pressed(controls.use_portal) &&
	   player_at_portal {
		if game_data.cur_level_idx == 12 {
			queue_menu_change(.Win)
		} else {
			// if not last level
			game_data.cur_level_idx += 1
			clear_temp_entities(&main_world)
			reload_level(&main_world)
		}
	}

	update_world_camera_and_mouse_pos()

	// Tick down screen shake
	screen_shake_time -= delta

	if (speedrun_timer == 0 && main_world.player.vel != 0) ||
	   (speedrun_timer != 0 && !all_enemies_dying(main_world)) {
		speedrun_timer += delta
	}

	// TUTORIAL ACTIONS
	for &action in tutorial.actions {
		if check_condition(&action.condition, action.invert_condition, main_world) &&
		   check_condition(&action.condition2, action.invert_condition2, main_world) &&
		   check_condition(&action.condition3, action.invert_condition3, main_world) {
			switch data in action.action {
			case EnableEntityAction:
				#partial switch data.type {
				case .Item:
					#reverse for item, i in main_world.disabled_items {
						if item.id == data.id {
							append(&main_world.items, item)
							if !data.should_clone {
								unordered_remove(&main_world.disabled_items, i)
							}
							break
						}
					}
				case .Enemy:
					#reverse for enemy, i in main_world.disabled_enemies {
						if enemy.id == data.id {
							append(&main_world.enemies, enemy)
							if !data.should_clone {
								unordered_remove(&main_world.disabled_enemies, i)
							}
							break
						}
					}
				}
			case SetTutorialFlagAction:
				flag: ^bool = get_tutorial_flag_from_name(data.flag_name)
				if flag != nil {
					flag^ = data.value
				}
			case PrintMessageAction:
				fmt.println(data.message)
			}
		}
	}

	// FIX THIS. This stops the rest of the proc, including collecting input stuff which is kind of bad!!!
	// if pause_game > 0 {
	// 	pause_game -= delta
	// 	return
	// }

	// Fire spread and other tile updates
	update_tilemap(&main_world)

	// fire dash timer
	if !main_world.player.can_fire_dash {
		main_world.player.fire_dash_timer -= delta
		if main_world.player.fire_dash_timer <= 0 {
			main_world.player.can_fire_dash = true
		}
	} else {
		main_world.player.fire_dash_ready_time += delta
	}

	if !(level.has_tutorial && tutorial.disable_ability) &&
	   is_control_pressed(controls.movement_ability) {
		move_successful := false
		if main_world.player.can_fire_dash {
			move_successful = true
			main_world.player.can_fire_dash = false
			main_world.player.fire_dash_timer = FIRE_DASH_COOLDOWN
			main_world.player.fire_dash_ready_time = 0

			main_world.player.vel = normalize(get_directional_input()) * 400
			fire := Fire{{main_world.player.pos, FIRE_DASH_RADIUS}, FIRE_DASH_FIRE_DURATION}
			append(&main_world.fires, fire)
			attack := Attack {
				pos       = main_world.player.pos,
				shape     = Circle{{}, FIRE_DASH_RADIUS},
				damage    = 10,
				knockback = 100,
				targets   = {.Bomb, .Enemy, .ExplodingBarrel, .Tile},
				data      = ExplosionAttackData{true},
			}
			perform_attack(&main_world, &attack)
		}
		if move_successful {
			stop_player_attack(&main_world.player)
			main_world.player.charging_weapon = false
			main_world.player.holding_item = false
		}
	}

	player_move(&main_world.player, delta)
	for wall in main_world.walls {
		_, normal, depth := resolve_collision_shapes(
			main_world.player.shape,
			main_world.player.pos,
			wall.shape,
			wall.pos,
		)
		// fmt.printfln("%v, %v, %v", collide, normal, depth)
		if depth > 0 {
			main_world.player.pos -= normal * depth
			main_world.player.vel = slide(main_world.player.vel, normal)
		}
	}
	for wall in main_world.half_walls {
		_, normal, depth := resolve_collision_shapes(
			main_world.player.shape,
			main_world.player.pos,
			wall.shape,
			wall.pos,
		)
		// fmt.printfln("%v, %v, %v", collide, normal, depth)
		if depth > 0 {
			main_world.player.pos -= normal * depth
			main_world.player.vel = slide(main_world.player.vel, normal)
		}
	}
	for &barrel in main_world.exploding_barrels {
		if barrel.queue_free {
			continue
		}
		_, normal, depth := resolve_collision_shapes(
			main_world.player.shape,
			main_world.player.pos,
			barrel.shape,
			barrel.pos,
		)
		// fmt.printfln("%v, %v, %v", collide, normal, depth)
		if depth > 0 {
			// player.pos -= normal * depth
			barrel_vel_along_normal := proj(barrel.vel, normal)
			player_vel_along_normal := proj(main_world.player.vel, normal)
			barrel.vel -= barrel_vel_along_normal
			main_world.player.vel -= player_vel_along_normal
			barrel.vel += (barrel_vel_along_normal + player_vel_along_normal) / 2
			main_world.player.vel += (barrel_vel_along_normal + player_vel_along_normal) / 2
			barrel.pos += normal * depth
		}
	}

	if length_squared(main_world.player.vel) >= square(f32(PLAYER_SPEED_DISTRACTION_THRESHOLD)) {
		seconds_above_distraction_threshold += delta
	} else {
		seconds_above_distraction_threshold = 0
	}
	if seconds_above_distraction_threshold >= SPEED_SECOND_THRESHOLD {
		append(
			&main_world.alerts,
			Alert {
				pos = main_world.player.pos,
				range = 90,
				base_intensity = 0.8,
				base_duration = 1,
				decay_rate = 1,
				time_emitted = f32(rl.GetTime()),
			},
		)
	}


	#reverse for &fire, i in main_world.fires {
		fire.time_left -= delta
		if fire.time_left <= 0 {
			unordered_remove(&main_world.fires, i)
		}
	}

	/* -------------------------------------------------------------------------- */
	/*                               MARK:Enemy Loop                              */
	/* -------------------------------------------------------------------------- */
	enemy_loop: #reverse for &enemy, idx in main_world.enemies {
		/* ---------------------------- Tutorial Dummies ---------------------------- */
		if level.has_tutorial && tutorial.enable_enemy_dummies {
			damage_enemy(&main_world, idx, 0)
		}

		// Sprite flash
		if enemy.flash_opacity > 0 {
			enemy.flash_opacity -=
				delta /
				(enemy.flash_opacity *
						enemy.flash_opacity *
						enemy.flash_opacity *
						enemy.flash_opacity)
		}

		/* -------------------------------- Flinching ------------------------------- */
		enemy.target = enemy.pos
		if enemy.flinching {
			enemy.current_flinch_time -= delta
			if enemy.current_flinch_time <= 0 {
				enemy.flinching = false
			}
		} else {
			/* --------------------------- Update Vision Cone --------------------------- */
			{
				for &p, i in enemy.vision_points {
					dir := vector_from_angle(
						f32(i) * enemy.vision_fov / f32(len(enemy.vision_points) - 1) +
						enemy.look_angle -
						enemy.vision_fov / 2,
					)
					if i == len(enemy.vision_points) - 1 {
						p = enemy.pos
						break
					}
					t := cast_ray_through_walls(main_world.walls[:], enemy.pos, dir)
					if t < enemy.vision_range {
						p = enemy.pos + t * dir
					} else {
						p = enemy.pos + enemy.vision_range * dir
					}
				}
			}

			/* -------------------------- Check For Player LOS -------------------------- */
			{
				enemy.can_see_player = check_collsion_circular_concave_circle(
					enemy.vision_points[:],
					enemy.pos,
					{main_world.player.pos, 8},
				)
				if enemy.can_see_player {
					enemy.last_seen_player_pos = main_world.player.pos
					enemy.last_seen_player_vel = main_world.player.vel
				}
			}

			/* ---------------------------- Player Flee Check --------------------------- */
			{
				#partial switch data in enemy.data {
				case RangedEnemyData:
					enemy.player_in_flee_range = check_collision_shapes(
						Circle{{}, data.flee_range},
						enemy.pos,
						main_world.player.shape,
						main_world.player.pos,
					)
				}
			}

			/* ------------------------------ Check Alerts ------------------------------ */
			if alert_states: bit_set[EnemyState] = {.Alerted, .Idle, .Searching};
			   enemy.state in alert_states { 	// If enemy is in a state that can detect alerts
				enemy.alert_just_detected = false
				detected_alert: Alert
				detected_effective_intensity: f32 = 0
				for alert in main_world.alerts {
					effective_intensity := get_effective_intensity(alert)
					// get effective range
					effective_enemy_range :=
						effective_intensity *
						(enemy.vision_range if alert.is_visual else enemy.hearing_range)

					// check los if alert is visual
					can_detect := !alert.is_visual || check_collsion_circular_concave_circle(
							enemy.vision_points[:],
							enemy.pos,
							{alert.pos, 2}, // 2 is an arbitrary radius. Should work here.
						)

					detected :=
						can_detect &&
						distance_squared(enemy.pos, alert.pos) <
							square(min(effective_enemy_range, alert.range)) &&
						alert.time_emitted > enemy.last_alert.time_emitted

					if detected {
						if effective_intensity > detected_effective_intensity ||
						   (effective_intensity == detected_effective_intensity &&
								   distance_squared(enemy.pos, alert.pos) <
									   distance_squared(enemy.pos, detected_alert.pos)) {
							detected_alert = alert
							detected_effective_intensity = effective_intensity
						}
					}
				}
				// Check if alert is relevant
				if detected_effective_intensity > 0 &&
				   (detected_effective_intensity > get_effective_intensity(enemy.last_alert) ||
						   enemy.state != .Alerted) {
					enemy.alert_just_detected = true
					enemy.last_alert_intensity_detected = detected_effective_intensity
					enemy.last_alert = detected_alert
				}
			}

			/* ------------------------------ Update State ------------------------------ */
			{
				fully_dead := update_enemy_state(&enemy, delta)
				if fully_dead {
					unordered_remove(&main_world.enemies, idx)
					_on_enemy_fully_dead()

					continue enemy_loop
				}
			}
		}

		/* -------------------------- Movement and Collsion ------------------------- */
		enemy_move(&enemy, delta)

		for wall in main_world.walls {
			_, normal, depth := resolve_collision_shapes(
				enemy.shape,
				enemy.pos,
				wall.shape,
				wall.pos,
			)
			if depth > 0 {
				enemy.pos -= normal * depth
				enemy.vel = slide(enemy.vel, normal)
			}
		}
		for wall in main_world.half_walls {
			_, normal, depth := resolve_collision_shapes(
				enemy.shape,
				enemy.pos,
				wall.shape,
				wall.pos,
			)
			if depth > 0 {
				enemy.pos -= normal * depth
				enemy.vel = slide(enemy.vel, normal)
			}
		}
	}

	/* ------------------------------ Update Alerts ----------------------------- */
	#reverse for &alert, i in main_world.alerts {
		if get_time_left(alert) <= 0 || get_effective_intensity(alert) <= 0 {
			unordered_remove(&main_world.alerts, i)
		}
	}


	#reverse for &entity in main_world.exploding_barrels {
		generic_move(&entity, 1000, delta)
		for wall in main_world.walls {
			_, normal, depth := resolve_collision_shapes(
				entity.shape,
				entity.pos,
				wall.shape,
				wall.pos,
			)
			// fmt.printfln("%v, %v, %v", collide, normal, depth)
			if depth > 0 {
				entity.pos -= normal * depth
				entity.vel = slide(entity.vel, normal)
			}
			_, pnormal, pdepth := resolve_collision_shapes(
				entity.shape,
				entity.pos,
				main_world.player.shape,
				main_world.player.pos,
			)
			if pdepth > 0 {
				main_world.player.pos += pnormal * pdepth
			}
		}
		for wall in main_world.half_walls {
			_, normal, depth := resolve_collision_shapes(
				entity.shape,
				entity.pos,
				wall.shape,
				wall.pos,
			)
			// fmt.printfln("%v, %v, %v", collide, normal, depth)
			if depth > 0 {
				entity.pos -= normal * depth
				entity.vel = slide(entity.vel, normal)
			}
			_, pnormal, pdepth := resolve_collision_shapes(
				entity.shape,
				entity.pos,
				main_world.player.shape,
				main_world.player.pos,
			)
			if pdepth > 0 {
				main_world.player.pos += pnormal * pdepth
			}
		}
	}

	#reverse for &bomb, i in main_world.bombs {
		zentity_move(&bomb, 300, 50, delta)
		should_explode := false
		for wall in main_world.walls {
			_, normal, depth := resolve_collision_shapes(
				bomb.shape,
				bomb.pos,
				wall.shape,
				wall.pos,
			)
			// fmt.printfln("%v, %v, %v", collide, normal, depth)
			if depth > 0 {
				bomb.pos -= normal * depth
				bomb.vel = slide(bomb.vel, normal)
				should_explode = true
			}
		}
		for enemy in main_world.enemies {
			if enemy.state == .Death {
				continue
			}
			_, normal, depth := resolve_collision_shapes(
				bomb.shape,
				bomb.pos,
				enemy.shape,
				enemy.pos,
			)
			// fmt.printfln("%v, %v, %v", collide, normal, depth)
			if depth > 0 {
				bomb.pos -= normal * depth
				bomb.vel = slide(bomb.vel, normal)
				should_explode = true
			}
		}
		for barrel in main_world.exploding_barrels {
			if barrel.queue_free {
				continue
			}
			_, normal, depth := resolve_collision_shapes(
				bomb.shape,
				bomb.pos,
				barrel.shape,
				barrel.pos,
			)
			// fmt.printfln("%v, %v, %v", collide, normal, depth)
			if depth > 0 {
				bomb.pos -= normal * depth
				bomb.vel = slide(bomb.vel, normal)
				should_explode = true
			}
		}
		if bomb.z <= 0 { 	// if on ground, then start ticking
			should_explode = true
		}
		if should_explode {
			explosion_radius: f32 = 16
			append(&main_world.fires, Fire{Circle{bomb.pos, explosion_radius}, 0.5})
			perform_attack(
				&main_world,
				&{
					targets = {.Player, .Enemy, .ExplodingBarrel, .Tile},
					damage = 20,
					knockback = 20,
					pos = bomb.pos,
					shape = Circle{{}, explosion_radius},
					data = ExplosionAttackData{true},
				},
			)
			append(
				&main_world.alerts,
				Alert {
					pos = bomb.pos,
					range = 60,
					base_intensity = 1.1,
					base_duration = 0.5,
					decay_rate = 2,
					time_emitted = f32(rl.GetTime()),
				},
			)
			unordered_remove(&main_world.bombs, i)
		}
	}

	#reverse for &arrow, i in main_world.arrows {
		zentity_move(&arrow, 300, 30, delta)

		speed_damage_ratio :: 25

		arrow.attack.pos = arrow.pos
		arrow.attack.shape = arrow.shape
		arrow.attack.data = ArrowAttackData{i, speed_damage_ratio}

		// if the arrow hit something while performing its attack, then delete it
		if perform_attack(&main_world, &arrow.attack) == -1 {
			delete_arrow(i)
			continue
		}

		if arrow.z <= 0 {
			delete_arrow(i)
		}
	}

	// weapon attack
	if is_control_down(controls.fire) {
		if main_world.player.weapons[main_world.player.selected_weapon_idx].id >= .Sword {
			fire_selected_weapon(&main_world.player)
			main_world.player.holding_item = false // Cancel item hold
			main_world.player.charging_weapon = false // cancel charge
		}
	}

	// Handle player charging/holding item
	if main_world.player.holding_item {
		if main_world.player.item_switched || is_control_pressed(controls.cancel) {
			main_world.player.holding_item = false
		} else if is_control_released(controls.use_item) {
			use_bomb(&main_world)
			main_world.player.holding_item = false
		}

		main_world.player.item_hold_time += delta
	}
	// Start player holding item
	if is_control_pressed(controls.use_item) &&
	   main_world.player.items[main_world.player.selected_item_idx].id != .Empty {
		stop_player_attack(&main_world.player) // Cancel attack
		main_world.player.charging_weapon = false // Cancel charge
		main_world.player.holding_item = true
		main_world.player.item_hold_time = 0
	}

	if main_world.player.attacking {
		if main_world.player.attack_dur_timer <= 0 {
			stop_player_attack(&main_world.player)
		} else {
			main_world.player.attack_dur_timer -= delta

			perform_attack(&main_world, &main_world.player.cur_attack)
			append(
				&main_world.alerts,
				Alert {
					pos = main_world.player.pos,
					range = 60,
					base_intensity = 0.9,
					base_duration = 0.5,
					decay_rate = 2,
					time_emitted = f32(rl.GetTime()),
				},
			)
		}
	} else if !main_world.player.can_attack { 	// If right after attack finished then countdown attack interval timer until done
		if main_world.player.attack_interval_timer <= 0 {
			main_world.player.can_attack = true
		}
		main_world.player.attack_interval_timer -= delta
	}

	// animate attack
	if main_world.player.attack_anim_timer > 0 {
		main_world.player.attack_anim_timer -= delta
	}

	// Item pickup
	if is_control_pressed(controls.pickup) {
		closest_item_idx := -1
		closest_item_dist_sqrd := math.INF_F32
		for item, i in main_world.items {
			if check_collision_shapes(
				Circle{{}, main_world.player.pickup_range},
				main_world.player.pos,
				item.shape,
				item.pos,
			) {
				dist_sqrd := distance_squared(item.pos, main_world.player.pos)
				if closest_item_idx == -1 || dist_sqrd < closest_item_dist_sqrd {
					closest_item_idx = i
					closest_item_dist_sqrd = dist_sqrd
				}
			}
		}
		if closest_item_idx != -1 {
			item := main_world.items[closest_item_idx]
			if pickup_item(&main_world.player, item.data) {
				unordered_remove(&main_world.items, closest_item_idx)
			}
		}
		// DEBUG: Player inventory
		// fmt.printfln(
		// 	"weapons: %v, items: %v, selected_weapon: %v, selected_item: %v",
		// 	player.weapons,
		// 	player.items,
		// 	player.selected_weapon_idx,
		// 	player.selected_item_idx,
		// )

	}
}

draw_world :: proc(world: World) {
	if editor_state.mode != .None {
		draw_level(editor_state.show_tile_grid)
	}

	switch editor_state.mode {
	case .Level:
		draw_geometry_editor_world(world, editor_state)
	case .Entity:
		draw_entity_editor_world(editor_state)
	case .Tutorial:
		draw_tutorial_editor_world(editor_state)
	case .None:
		draw_tilemap(world.tilemap)

		for fire in world.fires {
			rl.DrawCircleV(fire.pos, fire.radius, rl.ORANGE)
		}

		// Draw portal
		light_blue :: Color{42, 110, 224, 255}
		portal_color := light_blue if all_enemies_dying(world) else Color{33, 14, 95, 255}
		rl.DrawCircleV(level.portal_pos, PORTAL_RADIUS, portal_color)

		// Draw arrow to portal if level finished and player is at least 64 units away
		if all_enemies_dying(world) && !player_at_portal {
			angle_to_portal := angle(level.portal_pos - world.player.pos)
			arrow_polygon := Polygon {
				world.player.pos,
				{{14, -3}, {24, 0}, {14, 3}},
				angle_to_portal,
			}
			draw_polygon(arrow_polygon, light_blue)
		}

		// Draw portal prompts
		if player_at_portal {
			prompt: cstring
			prompt = "Press E"
			if !all_enemies_dying(world) {
				prompt = "Kill All Enemies"
			}
			size := rl.MeasureTextEx(rl.GetFontDefault(), prompt, 6, 1)
			rl.DrawTextEx(
				rl.GetFontDefault(),
				prompt,
				level.portal_pos - {size.x / 2, size.y + 1},
				6,
				1,
				rl.WHITE,
			)
		}

		// Draw items
		for item in world.items {
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

			if check_collision_shapes(
				Circle{{}, world.player.pickup_range},
				world.player.pos,
				item.shape,
				item.pos,
			) {
				prompt: cstring = "Press E"
				size := rl.MeasureTextEx(rl.GetFontDefault(), prompt, 4, 1)
				rl.DrawTextEx(
					rl.GetFontDefault(),
					prompt,
					item.pos - {size.x / 2, size.y + 2},
					4,
					1,
					rl.WHITE,
				)
			}
		}

		// Draw walls and half walls
		for wall in world.walls {
			draw_shape(wall.shape, wall.pos, {88, 88, 102, 255})
		}

		for wall in world.half_walls {
			draw_shape(wall.shape, wall.pos, {153, 157, 167, 255})
		}

		// Draw in world level prompts
		if level.has_tutorial {
			for &prompt in tutorial.prompts {
				if !prompt.on_screen {
					font_size: f32 = 6
					spacing: f32 = 1
					text := fmt.ctprint(prompt.text)
					pos := get_centered_text_pos(prompt.pos, text, font_size, spacing)

					if check_condition(&prompt.condition, prompt.invert_condition, world) &&
					   check_condition(&prompt.condition2, prompt.invert_condition2, world) &&
					   check_condition(&prompt.condition3, prompt.invert_condition3, world) {
						rl.DrawTextEx(
							rl.GetFontDefault(),
							text,
							pos,
							font_size,
							spacing,
							{200, 200, 255, 255},
						)
					} else {
						when ODIN_DEBUG {
							text_size := rl.MeasureTextEx(
								rl.GetFontDefault(),
								text,
								font_size,
								spacing,
							)
							rl.DrawRectangleLinesEx(
								{pos.x, pos.y, text_size.x, text_size.y},
								0.5,
								rl.YELLOW,
							)
						}
					}
				}
			}

		}

		// :draw enemy
		for enemy in world.enemies {
			// DEBUG: Draw collision shape
			// draw_shape(enemy.shape, enemy.pos, rl.GREEN)

			// Setup sprites
			sprite := ENEMY_BASIC_SPRITE

			// Looking
			sprite.rotation = enemy.look_angle
			if sprite.rotation < -90 || sprite.rotation > 90 {
				sprite.scale = {-1, 1}
				sprite.rotation += 180
			}

			// Animate when death
			if enemy.state == .Death {
				sprite.tex_id = .EnemyBasicDeath
				frame_count := get_frames(.EnemyBasicDeath)
				frame_index := int(
					math.floor(
						math.remap(
							enemy.death_timer,
							0,
							ENEMY_DEATH_ANIMATION_TIME,
							0,
							f32(frame_count),
						),
					),
				)
				if frame_index >= frame_count {
					frame_index -= 1
				}
				tex := loaded_textures[.EnemyBasicDeath]
				frame_size := tex.width / i32(frame_count)
				sprite.tex_region = {
					f32(frame_index) * f32(frame_size),
					0,
					f32(frame_size),
					f32(tex.height),
				}
			}

			// Flash sprite
			flash_sprite := sprite
			flash_sprite.tint = {
				255,
				255,
				255,
				u8(math.clamp(math.remap(enemy.flash_opacity, 0, 1, 0, 255), 0, 255)),
			}
			flash_sprite.tex_id = .EnemyBasicFlash

			// Switch to ranged version
			if _, ok := enemy.data.(RangedEnemyData); ok {
				sprite.tex_id = .EnemyRanged
				if enemy.state == .Death {
					sprite.tex_id = .EnemyRangedDeath
				}
				flash_sprite.tex_id = .EnemyRangedFlash
			}

			// Draw sprites
			draw_sprite(sprite, enemy.pos)
			draw_sprite(flash_sprite, enemy.pos)

			// Draw health bar
			if enemy.state != .Death {
				health_bar_length: f32 = 20
				health_bar_height: f32 = 5
				health_bar_base_rec := get_centered_rect(
					{enemy.pos.x, enemy.pos.y - 20},
					{health_bar_length, health_bar_height},
				)
				rl.DrawRectangleRec(health_bar_base_rec, rl.BLACK)
				health_bar_filled_rec := health_bar_base_rec
				health_bar_filled_rec.width *= enemy.health / enemy.max_health
				rl.DrawRectangleRec(health_bar_filled_rec, rl.RED)
			}

			// DEBUG: Draw ID
			// rl.DrawTextEx(
			// 	rl.GetFontDefault(),
			// 	fmt.ctprintf(uuid.to_string(enemy.id, context.temp_allocator)),
			// 	enemy.pos + {0, -10},
			// 	8,
			// 	2,
			// 	rl.YELLOW,
			// )

			attack_area_color := rl.Color{255, 255, 255, 120}
			if enemy.just_attacked {
				attack_area_color = rl.Color{255, 0, 0, 120}
			}
			if enemy.state != .Death && (enemy.charging || enemy.just_attacked) {
				bar_length: f32 = 3
				bar_height: f32 = 10
				bar_base_rec := get_centered_rect(
					{enemy.pos.x, enemy.pos.y},
					{bar_length, bar_height},
				)
				rl.DrawRectangleRec(bar_base_rec, rl.BLACK)
				bar_filled_rec := bar_base_rec
				bar_filled_rec.height *= enemy.current_charge_time / enemy.start_charge_time
				rl.DrawRectangleRec(bar_filled_rec, rl.DARKGREEN)

				switch data in enemy.data {
				case MeleeEnemyData:
					draw_shape(data.attack_poly, enemy.pos, attack_area_color)
				case RangedEnemyData:

				}
			}

			// Draw vision area
			// when ODIN_DEBUG {
			// 	rl.DrawCircleLinesV(enemy.pos, enemy.vision_range, rl.YELLOW)
			// 	for p, i in enemy.vision_points {
			// 		rl.DrawLineV(
			// 			p,
			// 			enemy.vision_points[(i + 1) % len(enemy.vision_points)],
			// 			rl.YELLOW,
			// 		)
			// 	}
			// }

			// DEBUG: Enemy path
			// if enemy.current_path != nil {
			// 	for point in enemy.current_path {
			// 		rl.DrawCircleV(point, 2, rl.RED)
			// 	}
			// }
		}

		// when ODIN_DEBUG {
		// 	for alert in world.alerts {
		// 		rl.DrawCircleLinesV(alert.pos, alert.range, rl.RED)
		// 	}
		// }

		for barrel in world.exploding_barrels {
			if barrel.queue_free {
				continue
			}
			draw_sprite(BARREL_SPRITE, barrel.pos)
		}

		for &entity in world.bombs {
			entity.sprite.scale = entity.z + 1
			draw_sprite(entity.sprite, entity.pos)
		}

		for &entity in world.arrows {
			entity.sprite.scale = entity.z + 1
			draw_sprite(entity.sprite, entity.pos)
		}

		// :draw player
		{
			player := world.player
			// Player Sprite
			draw_sprite(PLAYER_SPRITE, player.pos)

			// Draw Item
			if player.holding_item && player.items[player.selected_item_idx].id != .Empty {
				draw_item(player.items[player.selected_item_idx].id, player.pos)
			}

			// Draw Weapon

			// Animate pos and sprite rotation
			pos_rotation: f32
			sprite_rotation: f32
			if player.attack_anim_timer > 0 {
				alpha: f32 = math.remap(player.attack_anim_timer, ATTACK_ANIM_TIME, 0, 0, 1)
				pos_rotation =
					math.remap(ease_out_back(alpha), 0, 1, -1, 1) *
					sword_pos_max_rotation *
					f32(player.weapon_side)
				sprite_rotation =
					math.remap(ease_out_back(alpha), 0, 1, -1, 1) *
					sword_sprite_max_rotation *
					f32(player.weapon_side)
			} else {
				pos_rotation = sword_pos_max_rotation * f32(player.weapon_side)
				sprite_rotation = sword_sprite_max_rotation * f32(player.weapon_side)
			}

			if !player.holding_item && player.weapons[player.selected_weapon_idx].id != .Empty {
				draw_weapon(
					player.weapons[player.selected_weapon_idx].id,
					player.pos,
					false,
					pos_rotation,
					sprite_rotation,
				)
			}

			// Vfx slash
			if player.attacking {
				frame_count := get_frames(.HitVfx)
				frame_index := int(
					math.floor(
						math.remap(
							ATTACK_DURATION - main_world.player.attack_dur_timer,
							0,
							ATTACK_DURATION,
							0,
							f32(frame_count),
						),
					),
				)
				if frame_index >= frame_count {
					frame_index -= 1
				}
				tex := loaded_textures[.HitVfx]
				frame_size := tex.width / i32(frame_count)
				sprite := Sprite {
					tex_id     = .HitVfx,
					tex_region = {
						f32(frame_index) * f32(frame_size),
						0,
						f32(frame_size),
						f32(tex.height),
					},
					scale      = 1,
					tex_origin = {0, f32(tex.height) / 2},
					rotation   = player.attack_poly.rotation,
					tint       = rl.WHITE,
				}
				draw_sprite(sprite, player.pos)
			}

			/* Health Bar */
			health_bar_length: f32 = 20
			health_bar_height: f32 = 5
			health_bar_base_rec := get_centered_rect(
				{player.pos.x, player.pos.y - 20},
				{health_bar_length, health_bar_height},
			)
			rl.DrawRectangleRec(health_bar_base_rec, rl.BLACK)
			health_bar_filled_rec := health_bar_base_rec
			health_bar_filled_rec.width *= player.health / player.max_health
			rl.DrawRectangleRec(health_bar_filled_rec, rl.RED)
			/* End of Health Bar */

			// when ODIN_DEBUG {
			// 	if !player.holding_item &&
			// 	   player.weapons[player.selected_weapon_idx].id >= .Sword {
			// 		attack_hitbox_color := rl.Color{255, 255, 255, 120}
			// 		if player.attacking {
			// 			attack_hitbox_color = rl.Color{255, 0, 0, 120}
			// 		}
			// 		draw_shape(player.attack_poly, player.pos, attack_hitbox_color)
			// 	}
			// }

			// DEBUG: Player pickup range
			// draw_shape_lines(Circle{{}, player.pickup_range}, player.pos, rl.DARKBLUE)
			// DEBUG: Collision shape
			// draw_shape(player.shape, player.pos, rl.RED)
		}
	}
}

draw_world_ui :: proc(world: World) {
	if world_camera.zoom != window_over_game {
		rl.DrawText(fmt.ctprintf("Zoom: x%v", world_camera.zoom), 24, 700, 16, rl.BLACK)
	}

	if editor_state.mode != .None {
		// Display mouse coordinates
		rl.DrawText(fmt.ctprintf("%v", mouse_world_pos), 20, 20, 16, rl.WHITE)
		if editor_state.show_tile_grid {
			rl.DrawText(
				fmt.ctprintf("%v", Vec2i{i32(mouse_world_pos.x), i32(mouse_world_pos.y)} / 8),
				20,
				40,
				16,
				rl.WHITE,
			)
		}
	}

	switch editor_state.mode {
	case .Level:
		draw_geometry_editor_ui(editor_state)
		rl.DrawText("Level Editor", 1300, 32, 16, rl.WHITE)

	case .Entity:
		draw_entity_editor_ui(editor_state)
		rl.DrawText("Entity Editor", 1300, 32, 16, rl.WHITE)
	case .Tutorial:
		draw_tutorial_editor_ui(editor_state)
		rl.DrawText("Tutorial Editor", 1300, 32, 16, rl.WHITE)
	case .None:
		if !(level.has_tutorial && tutorial.hide_all_hud) {
			draw_hud(world.player)
		}
		// when ODIN_DEBUG { 	// Draw player coordinates
		// 	rl.DrawText(fmt.ctprintf("%v", world.player.pos), 1200, 16, 20, rl.WHITE)
		// }


		if all_enemies_dying(world) {
			if level.save_after_completion && completion_show_time < max_show_time {
				completion_show_time += delta
				is_on := int(math.floor(completion_show_time / flash_interval)) % 2 == 0
				if is_on {
					message: cstring = "Progress saved!"
					font_size: f32 = 36
					spacing: f32 = 1
					pos := get_centered_text_pos(
						{f32(UI_SIZE.x) * 0.5, f32(UI_SIZE.y) * 0.5},
						message,
						font_size,
						spacing,
					)
					rl.DrawTextEx(
						rl.GetFontDefault(),
						message,
						pos,
						font_size,
						spacing,
						{200, 255, 200, 255},
					)
				}

			}

			message: cstring = "All enemies defeated. Head to the portal."
			font_size: f32 = 24
			spacing: f32 = 1
			pos := get_centered_text_pos(
				{f32(UI_SIZE.x) / 2, f32(UI_SIZE.y) * 0.95},
				message,
				font_size,
				spacing,
			)
			rl.DrawTextEx(rl.GetFontDefault(), message, pos, font_size, spacing, rl.DARKGREEN)
		}

		// draw on screen tutorial prompt
		if level.has_tutorial {
			#reverse for &prompt in tutorial.prompts {
				if prompt.on_screen {
					center := prompt.pos * {f32(UI_SIZE.x), f32(UI_SIZE.y)}
					font_size: f32 = 24
					spacing: f32 = 1
					text := fmt.ctprint(prompt.text)
					pos := get_centered_text_pos(center, text, font_size, spacing)

					if check_condition(&prompt.condition, prompt.invert_condition, world) &&
					   check_condition(&prompt.condition2, prompt.invert_condition2, world) &&
					   check_condition(&prompt.condition3, prompt.invert_condition3, world) {
						rl.DrawTextEx(
							rl.GetFontDefault(),
							text,
							pos,
							font_size,
							spacing,
							{200, 200, 255, 255},
						)
					} else {
						// when ODIN_DEBUG {
						// 	text_size := rl.MeasureTextEx(
						// 		rl.GetFontDefault(),
						// 		text,
						// 		font_size,
						// 		spacing,
						// 	)
						// 	rl.DrawRectangleLinesEx(
						// 		{pos.x, pos.y, text_size.x, text_size.y},
						// 		1,
						// 		rl.YELLOW,
						// 	)
						// }
					}
				}
			}
		}
	}

	// rl.DrawText(fmt.ctprintf("FPS: %v", rl.GetFPS()), 600, 20, 16, rl.BLACK)
}

// Update World Camera and get World mouse input
update_world_camera_and_mouse_pos :: proc() {
	world_camera.offset = {f32(window_size.x), f32(window_size.y)} / 2
	if editor_state.mode == .None {
		world_camera.zoom = window_over_game
		world_camera.target = main_world.player.pos
		// Screenshake effect
		if screen_shake_time > 0 {
			world_camera.target += vector_from_angle(rand.float32() * 360) * screen_shake_intensity
		}
		// Camera smoothing
		// world_camera.target = exp_decay(
		// 	world_camera.target,
		// 	player.pos + normalize(mouse_world_pos - player.pos) * 32,
		// 	2,
		// 	delta,
		// )

		// camera.target = 0
		// camera.target = fit_camera_target_to_level_bounds(player.pos)
	} else {
		world_camera.zoom += rl.GetMouseWheelMove() * 0.2 * world_camera.zoom
		world_camera.zoom = max(0.1, world_camera.zoom)
		if math.abs(world_camera.zoom - window_over_game) < 0.2 {
			world_camera.zoom = window_over_game
		}

		if rl.IsMouseButtonDown(.MIDDLE) {
			world_camera.target -= mouse_world_delta
		}
	}
	mouse_world_pos = window_to_world(mouse_window_pos)
	mouse_world_delta = mouse_window_delta / world_camera.zoom
}

// Clears entities and reloads game data and level
on_player_death :: proc() {
	clear_temp_entities(&main_world)
	// Reload the game data. Maybe we don't need to reload game data each time
	reload_game_data()
	// Reload the level
	reload_level(&main_world)
}

check_condition :: proc(condition: ^Condition, invert_condition: bool, world: World) -> bool {
	passed_condition := false
	switch &c in condition {
	case EntityCountCondition:
		#partial switch c.type {
		case .Enemy:
			passed_condition = len(world.enemies) == c.count
		case:
		}

	case EntityExistsCondition:
		#partial switch c.type {
		case .Enemy:
			for enemy in world.enemies {
				if enemy.id == c.id {
					passed_condition = true
					break
				}
			}
			if c.check_disabled {
				for enemy in world.disabled_enemies {
					if enemy.id == c.id {
						passed_condition = true
						break
					}
				}
			}
		case .Item:
			for item in world.items {
				if item.id == c.id {
					passed_condition = true
					break
				}
			}
			if c.check_disabled {
				for item in world.disabled_items {
					if item.id == c.id {
						passed_condition = true
						break
					}
				}
			}
		case:
		}
	case InventorySlotsFilledCondition:
		if c.weapon {
			count := 0
			for weapon in world.player.weapons {
				if weapon.id != .Empty {
					count += 1
				}
			}
			passed_condition = count == c.count

		} else {
			passed_condition = world.player.item_count == c.count
		}
	case KeyPressedCondition:
		if rl.IsKeyPressed(c.key) {
			c.fulfilled = true
		}
		passed_condition = c.fulfilled
	case PlayerInAreaCondition:
		passed_condition = check_collision_shapes(world.player.shape, world.player.pos, c.area, {})
	case EnemyInStateCondition:
		for enemy in world.enemies {
			if enemy.id == c.id {
				passed_condition = enemy.state == c.state
			}
		}
	case PlayerHealthCondition:
		target_health := c.health
		if c.max_health {
			target_health = world.player.max_health
		}
		switch c.check {
		case -2:
			passed_condition = world.player.health < target_health
		case -1:
			passed_condition = world.player.health <= target_health
		case 0:
			passed_condition = world.player.health == target_health
		case 1:
			passed_condition = world.player.health >= target_health
		case 2:
			passed_condition = world.player.health > target_health
		}
	case:
		passed_condition = true
	}
	// this is a shortcut for inverting the value of passed_condition using XOR
	return passed_condition ~ invert_condition
}

// :attack
perform_attack :: proc(using world: ^World, attack: ^Attack) -> (targets_hit: int) {
	EXPLOSION_DAMAGE_MULTIPLIER :: 10
	// Perform attack
	switch data in attack.data {
	case SwordAttackData:
		// Attack all targets
		if .Enemy in attack.targets {
			#reverse for &enemy, i in enemies {
				// Exclude enemy
				if _, exclude_found := slice.linear_search(attack.exclude_targets[:], enemy.id);
				   exclude_found {
					continue
				}

				if enemy.state == .Death {
					continue
				}

				// Check for collision and apply knockback and damage
				if check_collision_shapes(attack.shape, attack.pos, enemy.shape, enemy.pos) {
					just_killed := damage_enemy(world, i, attack.damage)
					enemy.vel += attack.direction * attack.knockback
					if just_killed {
						enemy.vel += attack.direction * attack.knockback
						screen_shake_time = .05
						screen_shake_intensity = 1.5
					}
					append(&attack.exclude_targets, enemy.id)
					targets_hit += 1
					play_sound(.SwordHit)
					// pause_game = 0.05
				}
			}
		}
		if .ExplodingBarrel in attack.targets {
			for &barrel in exploding_barrels {
				// Exclude
				if _, exclude_found := slice.linear_search(attack.exclude_targets[:], barrel.id);
				   exclude_found || barrel.queue_free {
					continue
				}

				// Check for collision and apply knockback and damage
				if check_collision_shapes(attack.shape, attack.pos, barrel.shape, barrel.pos) {
					barrel.vel += attack.direction * attack.knockback
					damage_exploding_barrel(&main_world, &barrel, attack.damage)
					append(&attack.exclude_targets, barrel.id)
					targets_hit += 1
				}
			}
		}
		if .Bomb in attack.targets {
			#reverse for &bomb in bombs {
				// Exclude
				if _, exclude_found := slice.linear_search(attack.exclude_targets[:], bomb.id);
				   exclude_found {
					continue
				}

				// Check for collision and apply knockback and damage
				if check_collision_shapes(attack.shape, attack.pos, bomb.shape, bomb.pos) {
					bomb.vel += attack.direction * attack.knockback
					append(&attack.exclude_targets, bomb.id)
					targets_hit += 1
				}
			}
		}
		if .Player in attack.targets {
			// Exclude
			if _, exclude_found := slice.linear_search(attack.exclude_targets[:], player.id);
			   !exclude_found {
				// Check for collision and apply knockback and damage
				if check_collision_shapes(attack.shape, attack.pos, player.shape, player.pos) {
					player.vel += attack.direction * attack.knockback
					damage_player(&player, attack.damage)
					append(&attack.exclude_targets, player.id)
					targets_hit += 1
				}
			}
		}
	case ExplosionAttackData:
		if .Enemy in attack.targets {
			#reverse for &enemy, i in enemies {
				// Check for collision and apply knockback and damage
				if check_collision_shapes(attack.shape, attack.pos, enemy.shape, enemy.pos) {
					// Knockback
					enemy.vel += normalize(enemy.pos - attack.pos) * attack.knockback
					// Damage
					damage_enemy(&main_world, i, attack.damage)
					targets_hit += 1
				}
			}
		}
		if .Player in attack.targets {
			if check_collision_shapes(attack.shape, attack.pos, player.shape, player.pos) {
				player.vel += normalize(player.pos - attack.pos) * attack.knockback
				damage_player(&player, attack.damage)
				targets_hit += 1
			}
		}
		if .ExplodingBarrel in attack.targets {
			for &barrel in exploding_barrels {
				if barrel.queue_free {
					continue
				}
				// Check for collision and apply knockback and damage
				if check_collision_shapes(attack.shape, attack.pos, barrel.shape, barrel.pos) {
					barrel.vel += normalize(barrel.pos - attack.pos) * attack.knockback
					damage_exploding_barrel(
						&main_world,
						&barrel,
						attack.damage * EXPLOSION_DAMAGE_MULTIPLIER,
					)
					targets_hit += 1
				}
			}
		}

		if .Bomb in attack.targets {
			#reverse for &bomb in bombs {
				// Exclude
				if _, exclude_found := slice.linear_search(attack.exclude_targets[:], bomb.id);
				   exclude_found {
					continue
				}

				// Check for collision and apply knockback and damage
				if check_collision_shapes(attack.shape, attack.pos, bomb.shape, bomb.pos) {
					bomb.vel += normalize(bomb.pos - attack.pos) * attack.knockback
					append(&attack.exclude_targets, bomb.id)
					targets_hit += 1
				}
			}
		}

		if .Tile in attack.targets {
			tiles := get_tiles_in_shape(attack.shape, attack.pos)
			for tile in tiles {
				#partial switch tile_data in tilemap[tile.x][tile.y] {
				case GrassData:
					if data.burn_instantly {
						tilemap[tile.x][tile.y] = GrassData{false, 0, false, true}
					} else {
						tile_should_spread := rand.choice([]bool{true, false})
						tilemap[tile.x][tile.y] = GrassData{true, 1, tile_should_spread, false}
					}
				}
			}
		}
	case FireAttackData:
		if .Enemy in attack.targets {
			#reverse for &enemy, i in enemies {
				if check_collision_shapes(attack.shape, attack.pos, enemy.shape, enemy.pos) {
					// Damage
					damage_enemy(&main_world, i, attack.damage, false)
					targets_hit += 1
				}
			}
		}
		if .ExplodingBarrel in attack.targets {
			for &barrel in main_world.exploding_barrels {
				if barrel.queue_free {
					continue
				}

				if check_collision_shapes(attack.shape, attack.pos, barrel.shape, barrel.pos) {
					// Damage
					damage_exploding_barrel(&main_world, &barrel, attack.damage)
					targets_hit += 1
				}
			}
		}
		if .Player in attack.targets {
			if check_collision_shapes(attack.shape, attack.pos, player.shape, player.pos) {
				damage_player(&player, attack.damage)
			}
		}
	// case ProjectileAttackData:
	// weapon := &projectile_weapons[data.projectile_idx]
	// if .Wall in attack.targets {
	// 	for wall in walls {
	// 		_, normal, depth := resolve_collision_shapes(
	// 			weapon.shape,
	// 			weapon.pos,
	// 			wall.shape,
	// 			wall.pos,
	// 		)

	// 		if depth > 0 {
	// 			// Only damage the weapon if the wall is not already excluded
	// 			if _, exclude_found := slice.linear_search(attack.exclude_targets[:], wall.id);
	// 			   !exclude_found {
	// 				// Add to exclude
	// 				append(&attack.exclude_targets, wall.id)
	// 				// Durability
	// 				weapon.data.count -=
	// 					int(math.abs(dot(normal, weapon.vel))) / data.speed_durablity_ratio
	// 				if weapon.data.count <= 0 {
	// 					delete_projectile_weapon(data.projectile_idx)
	// 					return -1
	// 				}
	// 			}

	// 			// Resolve collision
	// 			weapon.pos -= normal * depth
	// 			weapon.vel = slide(weapon.vel, normal)
	// 		}
	// 	}
	// }

	// if .Enemy in attack.targets {
	// 	#reverse for enemy, i in enemies {
	// 		_, normal, depth := resolve_collision_shapes(
	// 			weapon.shape,
	// 			weapon.pos,
	// 			enemy.shape,
	// 			enemy.pos,
	// 		)

	// 		if depth > 0 {
	// 			// Only damage if enemy is not already excluded
	// 			if _, exclude_found := slice.linear_search(
	// 				attack.exclude_targets[:],
	// 				enemy.id,
	// 			); !exclude_found {
	// 				// Add to exclude
	// 				append(&attack.exclude_targets, enemy.id)
	// 				// Damage
	// 				damage_enemy(
	// 					i,
	// 					math.abs(dot(normal, weapon.vel)) / data.speed_damage_ratio,
	// 				)
	// 				// Durability
	// 				weapon.data.count -=
	// 					int(math.abs(dot(normal, weapon.vel))) / data.speed_durablity_ratio
	// 				if weapon.data.count <= 0 {
	// 					delete_projectile_weapon(data.projectile_idx)
	// 					return -1
	// 				}
	// 			}

	// 			// Resolve collision
	// 			weapon.pos -= normal * depth
	// 			weapon.vel = slide(weapon.vel, normal)
	// 		}
	// 	}
	// }

	// if .ExplodingBarrel in attack.targets {
	// 	for barrel, i in exploding_barrels {
	// 		if barrel.queue_free {
	// 			continue
	// 		}
	// 		_, normal, depth := resolve_collision_shapes(
	// 			weapon.shape,
	// 			weapon.pos,
	// 			barrel.shape,
	// 			barrel.pos,
	// 		)

	// 		if depth > 0 {
	// 			// Only damage if enemy is not already excluded
	// 			if _, exclude_found := slice.linear_search(
	// 				attack.exclude_targets[:],
	// 				barrel.id,
	// 			); !exclude_found {
	// 				// Add to exclude
	// 				append(&attack.exclude_targets, barrel.id)
	// 				// Damage
	// 				damage_exploding_barrel(
	// 					i,
	// 					math.abs(dot(normal, weapon.vel)) / data.speed_damage_ratio,
	// 				)
	// 				// Durability
	// 				weapon.data.count -=
	// 					int(math.abs(dot(normal, weapon.vel))) / data.speed_durablity_ratio
	// 				if weapon.data.count <= 0 {
	// 					delete_projectile_weapon(data.projectile_idx)
	// 					return -1
	// 				}
	// 			}

	// 			// Resolve collision
	// 			weapon.pos -= normal * depth
	// 			weapon.vel = slide(weapon.vel, normal)
	// 		}
	// 	}
	// }

	// // case SurfAttackData:
	// if .Enemy in attack.targets {
	// 	#reverse for &enemy, i in enemies {
	// 		if check_collision_shapes(attack.shape, attack.pos, enemy.shape, enemy.pos) {
	// 			// Knockback
	// 			enemy.vel = normalize(enemy.pos - attack.pos) * attack.knockback
	// 			// Damage
	// 			damage_enemy(i, attack.damage)
	// 			targets_hit += 1
	// 		}
	// 	}
	// }
	// if .ExplodingBarrel in attack.targets {
	// 	for &barrel, i in exploding_barrels {
	// 		if barrel.queue_free {
	// 			continue
	// 		}
	// 		if check_collision_shapes(attack.shape, attack.pos, barrel.shape, barrel.pos) {
	// 			// Knockback
	// 			barrel.vel = normalize(barrel.pos - attack.pos) * attack.knockback
	// 			// Damage
	// 			damage_exploding_barrel(i, attack.damage)
	// 			targets_hit += 1
	// 		}
	// 	}
	// }
	// if .Bomb in attack.targets {
	// 	#reverse for &bomb in bombs {
	// 		if check_collision_shapes(attack.shape, attack.pos, bomb.shape, bomb.pos) {
	// 			// Knockback
	// 			bomb.vel = normalize(bomb.pos - attack.pos) * attack.knockback
	// 			targets_hit += 1
	// 		}
	// 	}
	// }
	case ArrowAttackData:
		arrow := &arrows[data.arrow_idx]
		if .Wall in attack.targets {
			for wall in walls {
				_, _, depth := resolve_collision_shapes(
					arrow.shape,
					arrow.pos,
					wall.shape,
					wall.pos,
				)

				if depth > 0 {
					return -1
				}
			}
		}

		if .Enemy in attack.targets {
			#reverse for enemy, i in enemies {
				// Don't hurt the source of the arrow
				if enemy.id == arrows[data.arrow_idx].source {
					continue
				}
				if enemy.state == .Death {
					continue
				}
				_, normal, depth := resolve_collision_shapes(
					arrow.shape,
					arrow.pos,
					enemy.shape,
					enemy.pos,
				)

				if depth > 0 {
					// Damage
					damage_enemy(
						world,
						i,
						math.abs(dot(normal, arrow.vel)) / data.speed_damage_ratio,
					)

					return -1
				}
			}
		}

		if .ExplodingBarrel in attack.targets {
			for &barrel in exploding_barrels {
				if barrel.queue_free {
					continue
				}

				_, normal, depth := resolve_collision_shapes(
					arrow.shape,
					arrow.pos,
					barrel.shape,
					barrel.pos,
				)

				if depth > 0 {
					// Damage
					damage_exploding_barrel(
						world,
						&barrel,
						math.abs(dot(normal, arrow.vel)) / data.speed_damage_ratio,
					)

					return -1
				}
			}
		}

		if .Player in attack.targets && player.id != arrows[data.arrow_idx].source {
			_, normal, depth := resolve_collision_shapes(
				arrow.shape,
				arrow.pos,
				player.shape,
				player.pos,
			)

			if depth > 0 {
				damage_player(
					&world.player,
					math.abs(dot(normal, arrow.vel)) / data.speed_damage_ratio,
				)

				return -1
			}
		}
	// case RockAttackData:
	// rock := &rocks[data.rock_idx]
	// if .Wall in attack.targets {
	// 	for wall in walls {
	// 		_, _, depth := resolve_collision_shapes(rock.shape, rock.pos, wall.shape, wall.pos)

	// 		if depth > 0 {
	// 			return -1
	// 		}
	// 	}
	// }

	// if .Enemy in attack.targets {
	// 	#reverse for enemy, i in enemies {
	// 		_, normal, depth := resolve_collision_shapes(
	// 			rock.shape,
	// 			rock.pos,
	// 			enemy.shape,
	// 			enemy.pos,
	// 		)

	// 		if depth > 0 {
	// 			// Damage
	// 			damage_enemy(i, math.abs(dot(normal, rock.vel)) / data.speed_damage_ratio)

	// 			return -1
	// 		}
	// 	}
	// }

	// if .ExplodingBarrel in attack.targets {
	// 	for barrel, i in exploding_barrels {
	// 		if barrel.queue_free {
	// 			continue
	// 		}

	// 		_, normal, depth := resolve_collision_shapes(
	// 			rock.shape,
	// 			rock.pos,
	// 			barrel.shape,
	// 			barrel.pos,
	// 		)

	// 		if depth > 0 {
	// 			// Damage
	// 			damage_exploding_barrel(
	// 				i,
	// 				math.abs(dot(normal, rock.vel)) / data.speed_damage_ratio,
	// 			)

	// 			return -1
	// 		}
	// 	}
	// }
	}
	return
}

bomb_explosion :: proc(world: ^World, pos: Vec2, radius: f32) {
}

// Empties the dyn arrays for all temporary entities like bombs or arrows
clear_temp_entities :: proc(world: ^World) {
	clear(&world.bombs)
	clear(&world.arrows)
	clear(&world.fires)
	clear(&world.alerts)
}

// Moves entity with current velocity and slows down with friction. no max speed
generic_move :: proc(e: ^MovingEntity, friction: f32, delta: f32) {
	friction_dir: Vec2 = -normalize(e.vel)
	friction_v := friction_dir * friction * delta

	e.vel += friction_v
	// Account for friction overshooting when slowing down
	if math.sign(e.vel.x) == math.sign(friction_v.x) {
		e.vel.x = 0
	}
	if math.sign(e.vel.y) == math.sign(friction_v.y) {
		e.vel.y = 0
	}
	e.pos += e.vel * delta
}

zentity_move :: proc(e: ^ZEntity, friction: f32, gravity: f32, delta: f32) {
	// Z movement
	{
		// Apply gravity
		if e.vel_z > 0 || e.z > 0 {
			e.vel_z -= gravity * delta
			e.z += e.vel_z * delta
		}
		// Snap to ground
		if e.z < 0 {
			e.z = 0
			if e.vel_z < 0 {
				e.vel_z = 0
			}
		}
	}

	// 2D Movement
	{
		// Apply friction if on ground
		if e.z <= 0 {
			friction_dir: Vec2 = -normalize(e.vel)
			friction_v := friction_dir * friction * delta

			e.vel += friction_v
			// Account for friction overshooting when slowing down
			if math.sign(e.vel.x) == math.sign(friction_v.x) {
				e.vel.x = 0
			}
			if math.sign(e.vel.y) == math.sign(friction_v.y) {
				e.vel.y = 0
			}
		}

		e.rot += e.rot_vel * delta
		e.pos += e.vel * delta
	}
	// Update collision shape and sprite to match new rotation
	#partial switch &s in e.shape {
	case Polygon:
		s.rotation = e.rot
	}
	e.sprite.rotation = e.rot
}

cast_ray_through_walls :: proc(walls: []PhysicsEntity, start: Vec2, dir: Vec2) -> f32 {
	min_t := math.INF_F32
	for wall in walls {
		t := cast_ray(start, dir, wall.shape, wall.pos)
		if t == -1 {
			continue
		}

		if t < min_t {
			min_t = t
		}
	}
	return min_t
}

// MARK: Item and Weapons
use_bomb :: proc(world: ^World) {
	// get selected item ItemId
	item_data := world.player.items[world.player.selected_item_idx]
	assert(item_data.id == .Bomb, "Expected a bomb")

	to_mouse := normalize(mouse_world_pos - world.player.pos)

	// use item
	tex := loaded_textures[.Bomb]
	sprite: Sprite = {.Bomb, {0, 0, f32(tex.width), f32(tex.height)}, {1, 1}, {1, 2}, 0, rl.WHITE}

	sprite.rotation += angle(to_mouse)

	base_vel := f32(360) // This value is arbitrary. Make it a constant
	append(
		&world.bombs,
		Bomb {
			entity = new_entity(world.player.pos + rotate_vector({-5, 3}, angle(to_mouse))),
			shape = Rectangle{-1, 0, 3, 3},
			vel = to_mouse * base_vel,
			z = 0,
			vel_z = 10,
			sprite = sprite,
			time_left = BOMB_EXPLOSION_TIME,
		},
	)
	add_to_selected_item_count(&world.player, -1)
}

remove_selected_item_from_inv :: proc(player: ^Player) {
	player.item_count -= 1

	last_item_idx := len(player.items) - 1

	is_last_slot_selected := player.selected_item_idx == last_item_idx
	if is_last_slot_selected {
		player.items[player.selected_item_idx].id = .Empty
		player.selected_item_idx = 0
		return
	}

	// Shift items
	for i := player.selected_item_idx + 1; i < len(player.items); i += 1 {
		// Copy value to prev index
		player.items[i - 1] = player.items[i]
	}
	player.items[last_item_idx].id = .Empty
}

// Adds or removes to the count of selected item
// Excess will be negative if count goes below 0
add_to_selected_item_count :: proc(player: ^Player, to_add: int) -> (excess: int) {
	item_data := &player.items[player.selected_item_idx]
	if item_data.id == .Empty || is_weapon(item_data.id) || item_data.count <= 0 {
		assert(false, "Invalid item data!")
	}
	item_data.count += to_add
	if item_data.count <= 0 {
		// Deselect item if count <= 0
		excess = item_data.count
		item_data.count = 0
		remove_selected_item_from_inv(player)
	}
	return
}

// :attack player
fire_selected_weapon :: proc(player: ^Player) -> int {
	// get selected weapon ItemId
	weapon_data := player.weapons[player.selected_weapon_idx]
	if weapon_data.id < .Sword {
		assert(false, "can't use weapon with empty or item id")
	}
	// to_mouse := normalize(mouse_world_pos - player.pos)

	// Fire weapon
	#partial switch weapon_data.id {
	case .Sword:
		if player.can_attack {
			// Attack
			player.attack_poly.rotation = angle(mouse_world_pos - player.pos)
			player.attack_dur_timer = ATTACK_DURATION
			player.attack_interval_timer = ATTACK_INTERVAL
			player.attack_anim_timer = ATTACK_ANIM_TIME
			player.attacking = true
			player.cur_attack = Attack {
				pos             = player.pos,
				shape           = player.attack_poly,
				damage          = SWORD_DAMAGE,
				knockback       = SWORD_KNOCKBACK,
				direction       = normalize(mouse_world_pos - player.pos),
				data            = SwordAttackData{},
				targets         = {.Enemy, .Bomb, .ExplodingBarrel},
				exclude_targets = make([dynamic]uuid.Identifier, context.allocator),
			}
			player.can_attack = false

			// Sound
			play_sound(.SwordSlash)

			// Switch side
			player.weapon_side = -player.weapon_side
		}
	// case .Stick:
	// 	if player.can_attack {
	// 		// Attack
	// 		player.attack_poly.rotation = angle(mouse_world_pos - player.pos)
	// 		player.attack_dur_timer = ATTACK_DURATION
	// 		player.attack_interval_timer = ATTACK_INTERVAL
	// 		player.attacking = true
	// 		player.cur_attack = Attack {
	// 			pos             = player.pos,
	// 			shape           = player.attack_poly,
	// 			damage          = STICK_DAMAGE,
	// 			knockback       = STICK_KNOCKBACK,
	// 			direction       = normalize(mouse_world_pos - player.pos),
	// 			data            = SwordAttackData{},
	// 			targets         = {.Enemy, .Bomb, .ExplodingBarrel},
	// 			exclude_targets = make([dynamic]uuid.Identifier, context.allocator),
	// 		}
	// 		player.can_attack = false

	// 		// Animation
	// 		if player.cur_weapon_anim.pos_cur_rotation ==
	// 		   player.cur_weapon_anim.cpos_top_rotation { 	// Animate down
	// 			player.cur_weapon_anim.pos_rotation_vel =
	// 				(player.cur_weapon_anim.cpos_bot_rotation -
	// 					player.cur_weapon_anim.cpos_top_rotation) /
	// 				ATTACK_DURATION
	// 			player.cur_weapon_anim.sprite_rotation_vel =
	// 				(player.cur_weapon_anim.csprite_bot_rotation -
	// 					player.cur_weapon_anim.csprite_top_rotation) /
	// 				ATTACK_DURATION
	// 		} else { 	// Animate up
	// 			player.cur_weapon_anim.pos_rotation_vel =
	// 				(player.cur_weapon_anim.cpos_top_rotation -
	// 					player.cur_weapon_anim.cpos_bot_rotation) /
	// 				ATTACK_DURATION
	// 			player.cur_weapon_anim.sprite_rotation_vel =
	// 				(player.cur_weapon_anim.csprite_top_rotation -
	// 					player.cur_weapon_anim.csprite_bot_rotation) /
	// 				ATTACK_DURATION
	// 		}
	// 	}
	}
	return 0
}

select_weapon :: proc(player: ^Player, idx: int) {
	player.selected_weapon_idx = idx
	#partial switch player.weapons[idx].id {
	case .Sword:
		player.attack_poly.points = SWORD_HITBOX_POINTS
	// case .Stick:
	// 	player.attack_poly.points = STICK_HITBOX_POINTS
	// 	player.cur_weapon_anim = STICK_ANIMATION_DEFAULT
	}
}

// Tries to add an item in the player's inventory. Returns false if player's inventory is full
pickup_item :: proc(player: ^Player, data: ItemData) -> bool {
	if !is_weapon(data.id) {
		for &item in player.items {
			if item.id == .Empty {
				item = data
				player.item_count += 1
				return true
			} else if item.id == data.id {
				item.count += data.count
				return true
			}
		}
	} else {
		not_selected_idx: int = 0 if player.selected_weapon_idx == 1 else 1
		if player.weapons[player.selected_weapon_idx].id == .Empty {
			player.weapons[player.selected_weapon_idx] = data
			select_weapon(player, player.selected_weapon_idx)
			return true // success!
		} else if player.weapons[not_selected_idx].id == .Empty {
			player.weapons[not_selected_idx] = data
			// select_weapon(not_selected_idx)
			return true
		}
		//  else {
		// Drop current weapon
		// NOTE: Create a different function. drop_item() could drop an item, not a weapon here
		// if item_data := drop_item(); item_data.id != .Empty {
		// 	add_item_to_world(item_data, player.pos)
		// }
		// player.weapons[player.selected_weapon_idx] = data // copy data
		// select_weapon(player.selected_weapon_idx) // select weapon
		// return true
		// }
	}
	return false
}

// Removes the currently selected and active item/weapon from player's inventory and returns its ItemData
drop_item :: proc(player: ^Player) -> ItemData {
	deselect_weapon :: proc(player: ^Player) {
		player.charging_weapon = false
		stop_player_attack(player)
	}

	deselect_item :: proc(player: ^Player) {
		player.holding_item = false
	}


	if !player.holding_item {
		// If selected weapon is not empty
		if player.weapons[player.selected_weapon_idx].id != .Empty {
			weapon_data := player.weapons[player.selected_weapon_idx]
			player.weapons[player.selected_weapon_idx].id = .Empty
			deselect_weapon(player)
			return weapon_data
		}
	} else {
		// If a item is selected and it is not empty
		if player.items[player.selected_item_idx].id != .Empty {
			item_data := player.items[player.selected_item_idx]
			remove_selected_item_from_inv(player)
			deselect_item(player)
			return item_data
		}
	}
	return {}
}

draw_item :: proc(item: ItemId, player_pos: Vec2) {
	to_mouse := normalize(mouse_world_pos - player_pos)
	tex_id := item_to_texture[item]
	tex := loaded_textures[tex_id]
	sprite: Sprite = {
		tex_id,
		{0, 0, f32(tex.width), f32(tex.height)},
		{1, 1},
		{f32(tex.width) / 2, f32(tex.height) / 2},
		0,
		rl.WHITE,
	}

	sprite_pos := player_pos + {-5, 3}
	sprite.scale = 1

	sprite.rotation += angle(to_mouse)
	sprite_pos = rotate_about_origin(sprite_pos, player_pos, angle(to_mouse))
	draw_sprite(sprite, sprite_pos)
}

draw_weapon :: proc(
	weapon: ItemId,
	player_pos: Vec2,
	charging: bool,
	pos_rotation: f32,
	sprite_rotation: f32,
) {
	to_mouse := normalize(mouse_world_pos - player_pos)
	tex_id := item_to_texture[weapon]
	tex := loaded_textures[tex_id]
	sprite: Sprite = {tex_id, {0, 0, f32(tex.width), f32(tex.height)}, {1, 1}, {}, 0, rl.WHITE}
	#partial switch weapon {
	case .Sword:
		sprite.tex_origin = {0, 1}
	// case .Stick:
	// 	sprite.tex_origin = {0, 8}
	}

	sprite_pos := player_pos
	// Set rotation and position based on if sword is on top or not
	sprite.rotation = sprite_rotation

	radius :: 4
	offset: Vec2 : {2, 0}
	sprite_pos += offset + radius * vector_from_angle(pos_rotation)

	// Rotate sprite and rotate its position to face mouse
	sprite.rotation += angle(to_mouse)
	sprite_pos = rotate_about_origin(sprite_pos, player_pos, angle(to_mouse))
	draw_sprite(sprite, sprite_pos)
}

// MARK: Alerts
get_effective_intensity :: proc(alert: Alert) -> f32 {
	time_elapsed := f32(rl.GetTime()) - alert.time_emitted
	return alert.base_intensity - alert.decay_rate * time_elapsed
}

get_time_left :: proc(alert: Alert) -> f32 {
	return alert.base_duration - (f32(rl.GetTime()) - alert.time_emitted)
}

// MARK: Enemy
enemy_move :: proc(e: ^Enemy, delta: f32) {
	max_speed: f32 = 80.0
	#partial switch data in e.data {
	case RangedEnemyData:
		max_speed = 60.0
	}

	// if e.can_see_player {
	// 	// keep base speed
	// } else if e.distracted {
	// 	max_speed *= 0.8 // 80% speed when distracted
	// } else {
	// 	max_speed *= 0.5 // 50% speed when wandering
	// }

	acceleration: f32 = 400.0
	friction: f32 = 240.0
	harsh_friction: f32 = 500.0

	desired_vel: Vec2
	steering: Vec2
	if !e.flinching && e.target != e.pos {
		desired_vel = normalize(e.target - e.pos) * max_speed
		steering = desired_vel - e.vel
	}

	acceleration_v := normalize(steering) * acceleration * delta

	friction_dir: Vec2 = -normalize(e.vel)
	if length(e.vel) > max_speed {
		friction = harsh_friction
	}
	friction_v := normalize(friction_dir) * friction * delta

	// Prevent friction overshooting when deaccelerating
	// if math.sign(e.vel.x) == sign(friction_dir.x) {e.vel.x = 0}
	// if math.sign(e.vel.y) == sign(friction_dir.y) {e.vel.y = 0}

	if length(e.vel + acceleration_v + friction_v) > max_speed && length(e.vel) <= max_speed { 	// If overshooting above max speed
		e.vel = normalize(e.vel + acceleration_v + friction_v) * max_speed
	} else if length(e.vel + acceleration_v + friction_v) < max_speed &&
	   length(e.vel) > max_speed &&
	   angle_between(e.vel, acceleration_v) <= 90 { 	// If overshooting below max speed
		e.vel = normalize(e.vel + acceleration_v + friction_v) * max_speed
	} else {
		e.vel += acceleration_v
		e.vel += friction_v
		// Account for friction overshooting when slowing down
		if acceleration_v.x == 0 && math.sign(e.vel.x) == math.sign(friction_v.x) {
			e.vel.x = 0
		}
		if acceleration_v.y == 0 && math.sign(e.vel.y) == math.sign(friction_v.y) {
			e.vel.y = 0
		}
	}

	// fmt.printfln(
	// 	"id: %v, steering (mag): %v, steering: %v, desired vel: %v, path: %v, path_point: %v, target: %v",
	// 	uuid.to_string(e.id, context.temp_allocator),
	// 	length(steering),
	// 	steering,
	// 	desired_vel,
	// 	e.current_path,
	// 	e.current_path_point,
	// 	target,
	// )

	e.pos += e.vel * delta
}

// Returns true if enemy is fully dead (at the end of death state)
update_enemy_state :: proc(enemy: ^Enemy, delta: f32) -> bool {
	// enemy.can_see_player = false // temp: prevent enemy from seeing player: stop combat
	switch enemy.state {
	case .Idle:
		if distance_squared(enemy.pos, enemy.post_pos) > square(f32(ENEMY_POST_RANGE)) {
			// use pathfinding to return to post
			update_enemy_pathing(enemy, delta, enemy.post_pos, main_world)
			lerp_look_angle(
				enemy,
				angle(enemy.target - enemy.pos) + f32(math.sin(rl.GetTime()) * 10),
				delta,
			)
			enemy.idle_look_angle = enemy.look_angle
			enemy.idle_look_timer = 2
		} else {
			enemy.idle_look_timer -= delta
			if enemy.idle_look_timer <= 0 {
				enemy.idle_look_timer = rand.float32_range(5, 15)
				enemy.idle_look_angle = enemy.look_angle + rand.float32_range(-90, 90)
				for enemy.idle_look_angle > 180 {
					enemy.idle_look_angle -= 360
				}
				for enemy.idle_look_angle < -180 {
					enemy.idle_look_angle += 360
				}
			}
			lerp_look_angle(
				enemy,
				enemy.idle_look_angle + f32(math.sin(rl.GetTime() * 2) * 10),
				delta,
			)
		}
		// fmt.println(enemy.look_angle)
		// fmt.println(enemy.idle_look_angle)

		if enemy.can_see_player {
			if enemy.player_in_flee_range {
				change_enemy_state(enemy, .Fleeing, main_world)
			} else {
				change_enemy_state(enemy, .Combat, main_world)
			}
		} else if enemy.alert_just_detected {
			change_enemy_state(enemy, .Alerted, main_world)
		}
	case .Alerted:
		enemy.alert_timer -= delta

		// look at or investigate distraction
		if enemy.last_alert_intensity_detected > 0.8 &&
		   distance_squared(enemy.pos, enemy.last_alert.pos) > 500 {
			update_enemy_pathing(enemy, delta, enemy.last_alert.pos, main_world)
		}
		lerp_look_angle(
			enemy,
			angle(enemy.last_alert.pos - enemy.pos) + f32(math.sin(rl.GetTime()) * 40),
			delta,
		)


		if enemy.can_see_player {
			if enemy.player_in_flee_range {
				change_enemy_state(enemy, .Fleeing, main_world)
			} else {
				change_enemy_state(enemy, .Combat, main_world)
			}
		} else if enemy.alert_just_detected { 	// if new alert is detected
			change_enemy_state(enemy, .Alerted, main_world)
		} else if enemy.alert_timer <= 0 {
			// once alert wears off, go back to idle
			change_enemy_state(enemy, .Idle, main_world)
		}
	case .Combat:
		lerp_look_angle(enemy, angle(main_world.player.pos - enemy.pos), delta)

		// Attacking
		enemy.just_attacked = false
		if enemy.charging {
			enemy.current_charge_time -= delta
			if enemy.current_charge_time <= 0 {
				enemy.just_attacked = true
				enemy.charging = false
				switch data in enemy.data {
				case MeleeEnemyData:
					damage :: 5
					knockback :: 100
					perform_attack(
						&main_world,
						&Attack {
							targets         = {.Bomb, .ExplodingBarrel, .Player},
							damage          = damage,
							knockback       = knockback,
							data            = SwordAttackData{},
							pos             = enemy.pos,
							shape           = data.attack_poly,
							exclude_targets = make(
								[dynamic]uuid.Identifier, // We don't want to reuse this
								context.temp_allocator,
							),
							direction       = vector_from_angle(data.attack_poly.rotation),
						},
					)
				case RangedEnemyData:
					// launch arrow
					to_player := normalize(main_world.player.pos - enemy.pos)
					tex := loaded_textures[.Arrow]
					arrow_sprite := Sprite {
						.Arrow,
						{0, 0, f32(tex.width), f32(tex.height)},
						{1, 1},
						{f32(tex.width) / 2, f32(tex.height) / 2},
						0,
						rl.WHITE,
					}
					append(
						&main_world.arrows,
						Arrow {
							entity = new_entity(enemy.pos),
							shape = Circle{{}, 4},
							vel = to_player * 300,
							z = 0,
							vel_z = 8,
							rot = angle(to_player),
							sprite = arrow_sprite,
							attack = Attack{targets = {.Player, .Wall, .ExplodingBarrel, .Enemy}},
							source = enemy.id,
						},
					)
				}
			}
		}

		// chasing
		if !enemy.charging {
			// use pathfinding to chase player
			update_enemy_pathing(enemy, delta, main_world.player.pos, main_world)
		}

		// if player is in attack range, start attacking
		if !enemy.flinching &&
		   !enemy.charging &&
		   enemy.can_see_player &&
		   check_collision_shapes(
			   Circle{{}, enemy.attack_charge_range},
			   enemy.pos,
			   main_world.player.shape,
			   main_world.player.pos,
		   ) {
			switch &data in enemy.data {
			case MeleeEnemyData:
				data.attack_poly.rotation = angle(main_world.player.pos - enemy.pos)
				enemy.charging = true
				enemy.current_charge_time = enemy.start_charge_time
			case RangedEnemyData:
				if !check_collision_shapes(
					Circle{{}, data.flee_range},
					enemy.pos,
					main_world.player.shape,
					main_world.player.pos,
				) {
					enemy.charging = true
					enemy.current_charge_time = enemy.start_charge_time
				}
			}
		}


		if !enemy.can_see_player {
			change_enemy_state(enemy, .Searching, main_world)
		} else if enemy.player_in_flee_range {
			change_enemy_state(enemy, .Fleeing, main_world)
		}
	case .Fleeing:
		// Run directly away from player
		enemy.target = enemy.pos + (enemy.pos - main_world.player.pos)
		lerp_look_angle(enemy, angle(main_world.player.pos - enemy.pos), delta)
		if !enemy.can_see_player {
			change_enemy_state(enemy, .Searching, main_world)
		} else if !enemy.player_in_flee_range {
			change_enemy_state(enemy, .Combat, main_world)
		}

	case .Searching:
		switch enemy.search_state {
		case 0:
			// 1 go to last seen player pos
			if distance_squared(enemy.pos, enemy.last_seen_player_pos) >
			   square(f32(ENEMY_SEARCH_TOLERANCE)) {
				enemy.search_timer += delta // accumulate search timer
				update_enemy_pathing(enemy, delta, enemy.last_seen_player_pos, main_world)
				lerp_look_angle(
					enemy,
					angle(enemy.target - enemy.pos) + f32(math.sin(8 * rl.GetTime())) * 5,
					delta,
				)
			} else {
				enemy.search_timer *= 2
				enemy.search_state = 1
			}
		case 1:
			// 2 look around
			lerp_look_angle(
				enemy,
				angle(enemy.last_seen_player_vel) + f32(math.sin(rl.GetTime()) * 20),
				delta,
			)

			enemy.search_timer -= delta
			if enemy.search_timer <= 0 {
				enemy.search_timer = 1.0
				enemy.search_state = 2
			}
		case 2:
			// 3 follow last seen player velocity
			enemy.target = enemy.pos + enemy.last_seen_player_vel
			lerp_look_angle(
				enemy,
				angle(enemy.target - enemy.pos) + f32(math.sin(8 * rl.GetTime())) * 5,
				delta,
			)
			enemy.search_timer -= delta
			if enemy.search_timer <= 0 {
				enemy.search_timer = 6.0
				enemy.search_state = 3
			}
		case 3:
			// 4 look around
			lerp_look_angle(
				enemy,
				angle(enemy.last_seen_player_vel) + f32(2 * math.sin(rl.GetTime()) * 40),
				delta,
			)
			enemy.search_timer -= delta
			if enemy.search_timer <= 0 {
				// Go back to idle
				enemy.search_state = 4
			}
		}

		if enemy.can_see_player {
			if enemy.player_in_flee_range {
				change_enemy_state(enemy, .Fleeing, main_world)
			} else {
				change_enemy_state(enemy, .Combat, main_world)
			}
		} else if enemy.alert_just_detected {
			change_enemy_state(enemy, .Alerted, main_world)
		} else if enemy.search_state == 4 {
			change_enemy_state(enemy, .Idle, main_world)
		}
	case .Death:
		// Wait still stopped then animate
		// if length(enemy.vel) < 1 {
		enemy.death_timer += delta
		// }
		return enemy.death_timer >= ENEMY_DEATH_ANIMATION_TIME
	}
	return false
}

change_enemy_state :: proc(enemy: ^Enemy, state: EnemyState, world: World) {
	// Exit state code
	switch enemy.state {
	case .Idle:

	case .Alerted:

	case .Combat:

	case .Fleeing:

	case .Searching:

	case .Death:
	}

	// Enter state code
	switch state {
	case .Idle:
		enemy.idle_look_timer = 2
		if distance_squared(enemy.pos, enemy.post_pos) > square(f32(ENEMY_POST_RANGE)) {
			start_enemy_pathing(enemy, world, enemy.post_pos)
		}
	case .Alerted:
		base_duration :: 5
		// Reset alert timer
		enemy.alert_timer = base_duration + enemy.last_alert_intensity_detected * 2

		// Determine if we look at or investigate alert
		if enemy.last_alert_intensity_detected > 0.8 {
			start_enemy_pathing(enemy, world, enemy.last_alert.pos)
		}
	case .Combat:
		start_enemy_pathing(enemy, world, world.player.pos)
	case .Fleeing:

	case .Searching:
		enemy.search_timer = 0
		enemy.search_state = 0
		start_enemy_pathing(enemy, world, enemy.last_seen_player_pos)
	case .Death:
		// Start death animation
		enemy.death_timer = 0
	}
	fmt.printfln("Enemy: %v, from %v to %v", enemy.id[0], enemy.state, state)

	enemy.state = state
}

// returns true if enemy was just killed
// :damage enemy
damage_enemy :: proc(world: ^World, enemy_idx: int, amount: f32, should_flinch := true) -> bool {
	enemy := &world.enemies[enemy_idx]
	if enemy.state == .Death {
		return false
	}
	enemy.health -= amount
	if enemy.health <= 0 {
		enemy.flinching = false
		enemy.flash_opacity = 0
		enemy.current_flinch_time = 0
		change_enemy_state(&world.enemies[enemy_idx], .Death, world^)
		_on_enemy_dying()
		return true
	} else if should_flinch {
		enemy.charging = false
		enemy.flinching = true
		enemy.current_flinch_time = enemy.start_flinch_time
		enemy.flash_opacity = 1
	}
	return false
}

_on_enemy_dying :: proc() {
	// Reset player dash
	main_world.player.fire_dash_timer = 0
	if all_enemies_dying(main_world) {
		_on_all_enemies_dying()
	}
}

_on_all_enemies_dying :: proc() {
	// Have some nice feedback here, audio or visual works
	if level.save_after_completion {
		main_world.player.health = main_world.player.max_health
		game_data.cur_level_idx += 1
		save_game_data()
		game_data.cur_level_idx -= 1

		// start the visuals
		completion_show_time = 0
	}
}

_on_enemy_fully_dead :: proc() {
	if all_enemies_dead(main_world) {
		_on_all_enemies_fully_dead()
	}
}

_on_all_enemies_fully_dead :: proc() {

}

all_enemies_dead :: proc(world: World) -> bool {
	return len(world.enemies) + len(world.disabled_enemies) == 0
}

all_enemies_dying :: proc(world: World) -> bool {
	for enemy in world.enemies {
		if enemy.state != .Death {
			return false
		}
	}
	for enemy in world.disabled_enemies {
		if enemy.state != .Death {
			return false
		}
	}
	return true
}

lerp_look_angle :: proc(enemy: ^Enemy, target_angle: f32, delta: f32) {
	enemy.look_angle = exp_decay_angle(enemy.look_angle, target_angle, 4, delta)
}

start_enemy_pathing :: proc(enemy: ^Enemy, world: World, dest: Vec2) {
	if enemy.current_path != nil {
		delete(enemy.current_path)
	}
	enemy.current_path = find_path_tiles(
		enemy.pos,
		dest,
		world.nav_graph,
		world.tilemap,
		world.wall_tilemap,
	)
	enemy.current_path_point = 1
	enemy.pathfinding_timer = ENEMY_PATHFINDING_TIME
}

// Counts down the pathfinding timer and recalculates the path if necessary
// Also, sets the enemy's target to the current path point, if there is a path to follow. Returns true if there is path to follow
update_enemy_pathing :: proc(enemy: ^Enemy, delta: f32, dest: Vec2, world: World) -> bool {
	enemy.pathfinding_timer -= delta
	if enemy.pathfinding_timer < 0 || enemy.current_path_point >= len(enemy.current_path) {
		start_enemy_pathing(enemy, world, dest)
	}
	if enemy.current_path != nil && enemy.current_path_point < len(enemy.current_path) {
		enemy.target = enemy.current_path[enemy.current_path_point]
		if distance_squared(enemy.pos, enemy.current_path[enemy.current_path_point]) < 16 { 	// Enemy is at the point (tolerance of 16)
			enemy.current_path_point += 1
		}
		return true
	}
	return false
}

// MARK: Player
player_move :: proc(p: ^Player, delta: f32) {
	max_speed: f32 = PLAYER_BASE_MAX_SPEED
	// Slow down player
	if p.holding_item || p.charging_weapon || p.attacking {
		max_speed = PLAYER_BASE_MAX_SPEED / 2
	}
	acceleration: f32 = PLAYER_BASE_ACCELERATION
	friction: f32 = PLAYER_BASE_FRICTION
	harsh_friction: f32 = PLAYER_BASE_HARSH_FRICTION

	input := get_directional_input()
	acceleration_v := normalize(input) * acceleration * delta

	friction_dir: Vec2 = -normalize(p.vel)
	if length(p.vel) > max_speed {
		friction = harsh_friction
	}
	friction_v := normalize(friction_dir) * friction * delta

	// Prevent friction overshooting when deaccelerating
	// if math.sign(p.vel.x) == sign(friction_dir.x) {p.vel.x = 0}
	// if math.sign(p.vel.y) == sign(friction_dir.y) {p.vel.y = 0}

	if length(p.vel + acceleration_v + friction_v) > max_speed && length(p.vel) <= max_speed { 	// If overshooting above max speed
		p.vel = normalize(p.vel + acceleration_v + friction_v) * max_speed
	} else if length(p.vel + acceleration_v + friction_v) < max_speed &&
	   length(p.vel) > max_speed &&
	   angle_between(p.vel, acceleration_v) <= 90 { 	// If overshooting below max speed
		p.vel = normalize(p.vel + acceleration_v + friction_v) * max_speed
	} else {
		p.vel += acceleration_v
		p.vel += friction_v
		// Account for friction overshooting when slowing down
		if acceleration_v.x == 0 && math.sign(p.vel.x) == math.sign(friction_v.x) {
			p.vel.x = 0
		}
		if acceleration_v.y == 0 && math.sign(p.vel.y) == math.sign(friction_v.y) {
			p.vel.y = 0
		}
	}

	p.pos += p.vel * delta

	// fmt.printfln(
	// 	"speed: %v, vel: %v fric vector: %v, acc vector: %v, acc length: %v",
	// 	length(e.vel),
	// 	e.vel,
	// 	friction_v,
	// 	acceleration_v,
	// 	length(acceleration_v),
	// )
}

damage_player :: proc(player: ^Player, amount: f32) {
	player.health -= amount
	player.health = max(player.health, 0)
	if player.health <= 0 {
		// Player is dead reload the level
		// TODO: make an actual player death animation
		fmt.println("you dead D:")
		player.queue_free = true
	}
}

heal_player :: proc(player: ^Player, amount: f32) {
	player.health += amount
	player.health = min(player.health, player.max_health)
}

// Cancel attack and clean up memory
stop_player_attack :: proc(player: ^Player) {
	if player.attacking {
		player.attacking = false
		delete(player.cur_attack.exclude_targets)
	}
}

// MARK: Other
damage_exploding_barrel :: proc(world: ^World, barrel: ^ExplodingBarrel, amount: f32) {
	if barrel.queue_free {
		return
	}
	barrel.health -= amount
	if barrel.health <= 0 {
		// KABOOM!!!
		// Visual
		fire := Fire{Circle{barrel.pos, 60}, 2}
		barrel.queue_free = true

		append(&world.fires, fire)
		// Damage
		perform_attack(
			world,
			&{
				targets = {.Player, .Enemy, .ExplodingBarrel, .Bomb, .Tile},
				damage = 40,
				knockback = 400,
				pos = fire.pos,
				shape = Circle{{}, fire.radius},
				data = ExplosionAttackData{false},
			},
		)
	}
}

delete_arrow :: proc(idx: int) {
	unordered_remove(&main_world.arrows, idx)
}

// ScreenShakeIntensity :: enum {
// 	Small,
// 	Medium,
// 	High,
// 	VeryHigh,
// }

// start_screen_shake :: proc(length: f32, intensity: ScreenShakeIntensity) {
// 	if screen_shake.intensity <= intensity 
// }
