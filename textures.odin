package game

import rl "vendor:raylib"

TextureId :: enum {
	Empty = 0, // 1-99 is items
	Bomb,
	Apple,
	Sword = 100, // 100-199 is weapons
	Player = 200, // 200-299 is entities
	Arrow,
	Tilemap = 300, // 300-399 is environment
}

loaded_textures: #sparse[TextureId]rl.Texture2D

// Indexed by ItemId
item_to_texture: #sparse[ItemId]TextureId = {
	.Empty = .Empty,
	.Bomb  = .Bomb,
	.Apple = .Apple,
	.Sword = .Sword,
}

load_textures :: proc() {
	loaded_textures = {
		.Empty   = {},
		.Bomb    = rl.LoadTexture("assets/bomb.png"),
		.Apple   = rl.LoadTexture("assets/apple.png"),
		.Sword   = rl.LoadTexture("assets/sword.png"),
		.Player  = rl.LoadTexture("assets/samurai.png"),
		.Arrow   = rl.LoadTexture("assets/arrow.png"),
		.Tilemap = rl.LoadTexture("assets/tileset.png"),
	}
}

unload_textures :: proc() {
	for tex in loaded_textures {
		rl.UnloadTexture(tex)
	}
}
