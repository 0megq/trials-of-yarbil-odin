package game

import rl "vendor:raylib"

TextureId :: enum {
	Empty = 0, // 1-99 is items
	Bomb,
	Apple,
	Rock,
	Sword = 100, // 100-199 is weapons
	Stick,
	Player = 200, // 200-299 is entities
	Arrow,
	Tilemap = 300, // 300-399 is environment
	WinCircle,
}

loaded_textures: #sparse[TextureId]rl.Texture2D

// Indexed by ItemId
item_to_texture: #sparse[ItemId]TextureId = {
	.Empty = .Empty,
	.Bomb  = .Bomb,
	.Apple = .Apple,
	.Rock  = .Rock,
	.Sword = .Sword,
	.Stick = .Stick,
}

load_textures :: proc() {
	loaded_textures = {
		.Empty     = {},
		.Bomb      = rl.LoadTexture("assets/bomb.png"),
		.Apple     = rl.LoadTexture("assets/apple.png"),
		.Rock      = rl.LoadTexture("assets/rock.png"),
		.Sword     = rl.LoadTexture("assets/sword.png"),
		.Stick     = rl.LoadTexture("assets/stick.png"),
		.Player    = rl.LoadTexture("assets/samurai.png"),
		.Arrow     = rl.LoadTexture("assets/arrow.png"),
		.Tilemap   = rl.LoadTexture("assets/tileset.png"),
		.WinCircle = rl.LoadTexture("assets/win_circle.png"),
	}
}

unload_textures :: proc() {
	for tex in loaded_textures {
		rl.UnloadTexture(tex)
	}
}
