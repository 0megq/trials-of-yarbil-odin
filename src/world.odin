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


world_update :: proc(world: ^World) {
	update_tilemap(world)
}

perform_attack :: proc(world: ^World, attack: ^Attack) -> (targets_hit: int) {
	using world
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

				// Check for collision and apply knockback and damage
				if check_collision_shapes(attack.shape, attack.pos, enemy.shape, enemy.pos) {
					enemy.vel += attack.direction * attack.knockback
					damage_enemy(i, attack.damage)
					append(&attack.exclude_targets, enemy.id)
					targets_hit += 1
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
					damage_exploding_barrel(&barrel, attack.damage)
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
					damage_enemy(i, attack.damage)
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
					damage_exploding_barrel(&barrel, attack.damage * EXPLOSION_DAMAGE_MULTIPLIER)
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
					damage_enemy(i, attack.damage, false)
					targets_hit += 1
				}
			}
		}
		if .ExplodingBarrel in attack.targets {
			for &barrel, i in exploding_barrels {
				if barrel.queue_free {
					continue
				}

				if check_collision_shapes(attack.shape, attack.pos, barrel.shape, barrel.pos) {
					// Damage
					damage_exploding_barrel(&barrel, attack.damage)
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
				_, normal, depth := resolve_collision_shapes(
					arrow.shape,
					arrow.pos,
					enemy.shape,
					enemy.pos,
				)

				if depth > 0 {
					// Damage
					damage_enemy(i, math.abs(dot(normal, arrow.vel)) / data.speed_damage_ratio)

					return -1
				}
			}
		}

		if .ExplodingBarrel in attack.targets {
			for barrel, i in exploding_barrels {
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
						i,
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

all_enemies_dead :: proc(world: World) -> bool {
	return len(world.enemies) + len(world.disabled_enemies) == 0
}

bomb_explosion :: proc(world: ^World, pos: Vec2, radius: f32) {
	append(&world.fires, Fire{Circle{pos, radius}, 0.5})
}

// Empties the dyn arrays for all temporary entities like bombs or arrows
clear_temp_entities :: proc(world: ^World) {
	clear(&world.bombs)
	clear(&world.arrows)
	clear(&world.fires)
	clear(&world.alerts)
}

// MARK: Item
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

			// Animation
			if player.cur_weapon_anim.pos_cur_rotation ==
			   player.cur_weapon_anim.cpos_top_rotation { 	// Animate down
				player.cur_weapon_anim.pos_rotation_vel =
					(player.cur_weapon_anim.cpos_bot_rotation -
						player.cur_weapon_anim.cpos_top_rotation) /
					ATTACK_DURATION
				player.cur_weapon_anim.sprite_rotation_vel =
					(player.cur_weapon_anim.csprite_bot_rotation -
						player.cur_weapon_anim.csprite_top_rotation) /
					ATTACK_DURATION
			} else { 	// Animate up
				player.cur_weapon_anim.pos_rotation_vel =
					(player.cur_weapon_anim.cpos_top_rotation -
						player.cur_weapon_anim.cpos_bot_rotation) /
					ATTACK_DURATION
				player.cur_weapon_anim.sprite_rotation_vel =
					(player.cur_weapon_anim.csprite_top_rotation -
						player.cur_weapon_anim.csprite_bot_rotation) /
					ATTACK_DURATION
			}
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
		player.cur_weapon_anim = SWORD_ANIMATION_DEFAULT
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
	cur_weapon_anim: WeaponAnimation,
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
	sprite.rotation = cur_weapon_anim.sprite_cur_rotation
	// The value 4 and {2, 0} are both constants here
	sprite_pos += {2, 0} + 4 * vector_from_angle(cur_weapon_anim.pos_cur_rotation)

	// Rotate sprite and rotate its position to face mouse
	sprite.rotation += angle(to_mouse)
	sprite_pos = rotate_about_origin(sprite_pos, player_pos, angle(to_mouse))
	draw_sprite(sprite, sprite_pos)
}

// MARK: Player
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
