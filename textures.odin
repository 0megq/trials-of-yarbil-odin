package game

import rl "vendor:raylib"

TextureId :: enum {
	Nil = 0, // 1-99 is items
	Bomb,
	Apple,
	Sword = 100, // 100-199 is weapons
	Player = 200, // 200-299 is entities
	Arrow,
	Tilemap = 300, // 300-399 is environment
}

Sprite :: struct {
	tex_id:     TextureId,
	tex_region: rl.Rectangle, // part of the texture that is rendered
	scale:      Vec2, // scale of the sprite
	tex_origin: Vec2, // origin/center of the sprite relative to the texture. (0, 0) is top left corner
	rotation:   f32, // rotation in degress of the sprite
	tint:       rl.Color, // tint of the texture. WHITE will render the texture normally
}

SpriteId :: enum {
	Nil,
	Player,
	Enemy,
	ItemApple,
	ItemSword,
	Bomb,
	Arrow,
}

sprites: #sparse[SpriteId]Sprite

loaded_textures: #sparse[TextureId]rl.Texture2D

// Indexed by ItemId
item_to_texture: #sparse[ItemId]TextureId = {
	.Nil   = .Nil,
	.Bomb  = .Bomb,
	.Apple = .Apple,
	.Sword = .Sword,
}

load_textures :: proc() {
	loaded_textures = {
		.Nil     = {},
		.Bomb    = rl.LoadTexture("assets/bomb.png"),
		.Apple   = rl.LoadTexture("assets/apple.png"),
		.Sword   = rl.LoadTexture("assets/sword.png"),
		.Player  = rl.LoadTexture("assets/samurai.png"),
		.Arrow   = rl.LoadTexture("assets/arrow.png"),
		.Tilemap = rl.LoadTexture("assets/tilemap.png"),
	}
}

unload_textures :: proc() {
	for tex in loaded_textures {
		rl.UnloadTexture(tex)
	}
}
