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

Enemy :: struct {
	using moving_entity:    MovingEntity,
	detection_range:        f32,
	knockback_just_applied: bool,
	health:                 f32,
	max_health:             f32,
}

Item :: struct {
	using moving_entity: MovingEntity,
	item_id:             ItemId,
}

Player :: struct {
	using moving_entity: MovingEntity,
	pickup_range:        f32,
	health:              f32,
}

Sprite :: struct {
	tex_id:     TextureId,
	tex_region: rl.Rectangle, // part of the texture that is rendered
	scale:      Vec2, // scale of the sprite
	tex_origin: Vec2, // origin/center of the sprite relative to the texture
	rotation:   f32, // rotation in degress of the sprite
	tint:       rl.Color, // tint of the texture. WHITE will render the texture normally
}
