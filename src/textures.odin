package game

import "core:fmt"
import rl "vendor:raylib"

TextureId :: enum {
	nil = 0, // 1-99 is items
	bomb,
	// Apple,
	// Rock,
	sword = 100, // 100-199 is weapons
	bow,
	// Stick,
	player = 200, // 200-299 is entities
	enemy_basic,
	enemy_ranged,
	turret_base,
	turret_head,
	arrow,
	exploding_barrel,
	tileset = 300, // 300-399 is environment
	win_circle,
	title_screen = 400, // 400-499 is UI
	title_screen2,
	hit_vfx = 500, // 500-599 is Vfx and others
}

loaded_textures: #sparse[TextureId]rl.Texture2D

// Indexed by ItemId
item_to_texture: #sparse[ItemId]TextureId = {
	.Empty = .nil,
	.Bomb  = .bomb,
	// .Apple = .Apple,
	// .Rock  = .Rock,
	.Sword = .sword,
	// .Stick = .Stick,
}

load_textures :: proc() {
	img_dir :: "res/images/"

	for id in TextureId {
		if id == nil do continue
		loaded_textures[id] = rl.LoadTexture(fmt.ctprint(img_dir, id, ".png", sep = ""))
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
	case .hit_vfx:
		return {4, 1}
	case .enemy_basic:
		return {7, 8}
	case .bow:
		return {4, 1}
	}
	return 1
}
