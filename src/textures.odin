package game

import rl "vendor:raylib"

TextureId :: enum {
	Empty = 0, // 1-99 is items
	Bomb,
	// Apple,
	// Rock,
	Sword = 100, // 100-199 is weapons
	Bow,
	// Stick,
	Player = 200, // 200-299 is entities
	EnemyBasic2,
	EnemyBasic,
	EnemyBasicFlash,
	EnemyBasicDeath,
	EnemyRanged,
	EnemyRangedFlash,
	EnemyRangedDeath,
	TurretBase,
	TurretHead,
	Arrow,
	ExplodingBarrel,
	Tilemap = 300, // 300-399 is environment
	WinCircle,
	TitleScreen = 400, // 400-499 is UI
	TitleScreen2,
	HitVfx = 500, // 500-599 is Vfx and others
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
	// img_dir :: "res/images/"
	// for id in TextureId {
	// 	loaded_textures[id] = rl.LoadTexture(fmt.ctprint(img_dir, id, ".png", sep = ""))
	// }
	loaded_textures = {
		.Empty            = {},
		.Bomb             = rl.LoadTexture("res/images/bomb.png"),
		// .Apple           = rl.LoadTexture("res/images/apple.png"),
		// .Rock            = rl.LoadTexture("res/images/rock.png"),
		.Sword            = rl.LoadTexture("res/images/sword.png"),
		.Bow              = rl.LoadTexture("res/images/bow.png"),
		// .Stick           = rl.LoadTexture("res/images/stick.png"),
		.Player           = rl.LoadTexture("res/images/samurai.png"),
		.EnemyBasic2      = rl.LoadTexture("res/images/enemy_basic2.png"),
		.EnemyBasic       = rl.LoadTexture("res/images/enemy_basic.png"),
		.EnemyBasicFlash  = rl.LoadTexture("res/images/enemy_basic_flash.png"),
		.EnemyBasicDeath  = rl.LoadTexture("res/images/enemy_basic_death.png"),
		.EnemyRanged      = rl.LoadTexture("res/images/enemy_ranged.png"),
		.EnemyRangedFlash = rl.LoadTexture("res/images/enemy_ranged_flash.png"),
		.EnemyRangedDeath = rl.LoadTexture("res/images/enemy_ranged_death.png"),
		.TurretBase       = rl.LoadTexture("res/images/turret_base.png"),
		.TurretHead       = rl.LoadTexture("res/images/turret_head.png"),
		.Arrow            = rl.LoadTexture("res/images/arrow.png"),
		.ExplodingBarrel  = rl.LoadTexture("res/images/exploding_barrel.png"),
		.Tilemap          = rl.LoadTexture("res/images/tileset.png"),
		.WinCircle        = rl.LoadTexture("res/images/win_circle.png"),
		.TitleScreen      = rl.LoadTexture("res/images/title_screen.png"),
		.TitleScreen2     = rl.LoadTexture("res/images/title_screen2.png"),
		.HitVfx           = rl.LoadTexture("res/images/hitfx.png"),
	}
	// rl.SetTextureFilter(loaded_textures[.Player], .BILINEAR)
}

unload_textures :: proc() {
	for tex in loaded_textures {
		rl.UnloadTexture(tex)
	}
}

get_frame_count :: proc(tex: TextureId) -> Vec2i {
	#partial switch tex {
	case .HitVfx:
		return {4, 1}
	case .EnemyBasicDeath:
		return {7, 1}
	case .EnemyBasic2:
		return {7, 8}
	case .EnemyRangedDeath:
		return {7, 1}
	case .Bow:
		return {4, 1}
	}
	return 1
}
