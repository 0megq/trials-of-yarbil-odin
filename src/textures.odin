package game

import rl "vendor:raylib"

TextureId :: enum {
	Empty = 0, // 1-99 is items
	Bomb,
	// Apple,
	// Rock,
	Sword = 100, // 100-199 is weapons
	// Stick,
	Player = 200, // 200-299 is entities
	Enemy,
	Arrow,
	ExplodingBarrel,
	Tilemap = 300, // 300-399 is environment
	WinCircle,
}

loaded_textures: #sparse[TextureId]rl.Texture2D

// Indexed by ItemId
item_to_texture: #sparse[ItemId]TextureId = {
	.Empty = .Empty,
	.Bomb  = .Bomb,
	// .Apple = .Apple,
	// .Rock  = .Rock,
	.Sword = .Sword,
	// .Stick = .Stick,
}

load_textures :: proc() {
	loaded_textures = {
		.Empty           = {},
		.Bomb            = rl.LoadTexture("res/images/bomb.png"),
		// .Apple           = rl.LoadTexture("res/images/apple.png"),
		// .Rock            = rl.LoadTexture("res/images/rock.png"),
		.Sword           = rl.LoadTexture("res/images/sword.png"),
		// .Stick           = rl.LoadTexture("res/images/stick.png"),
		.Player          = rl.LoadTexture("res/images/samurai.png"),
		.Enemy           = rl.LoadTexture("res/images/enemy.png"),
		.Arrow           = rl.LoadTexture("res/images/arrow.png"),
		.ExplodingBarrel = rl.LoadTexture("res/images/exploding_barrel.png"),
		.Tilemap         = rl.LoadTexture("res/images/tileset.png"),
		.WinCircle       = rl.LoadTexture("res/images/win_circle.png"),
	}
	// rl.SetTextureFilter(loaded_textures[.Player], .BILINEAR)
}

unload_textures :: proc() {
	for tex in loaded_textures {
		rl.UnloadTexture(tex)
	}
}
