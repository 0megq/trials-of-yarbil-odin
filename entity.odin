package game

import rl "vendor:raylib"


Entity :: struct {
	pos: Vec2,
}

StaticEntity :: struct {
	using entity: Entity,
	size:         Vec2,
}

PhysicsEntity :: struct {
	using entity: Entity,
	vel:          Vec2,
	size:         Vec2,
}

Enemy :: struct {
	using physics_entity: PhysicsEntity,
	detection_range:      f32,
	knockback_applied:    bool,
}

Item :: struct {
	using physics_entity: PhysicsEntity,
	item_id:              ItemId,
}

Player :: struct {
	using physics_entity: PhysicsEntity,
	pickup_range:         f32,
}

Sprite :: struct {
	tex_id:     TextureId,
	tex_region: rl.Rectangle, // part of the texture that is rendered
	scale:      Vec2, // scale of the sprite
	tex_origin: Vec2, // origin/center of the sprite relative
	rotation:   f32, // rotation in degress of the sprite
	tint:       rl.Color, // tint of the texture. WHITE will render the texture normally
}
