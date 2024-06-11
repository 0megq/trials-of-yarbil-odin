package game

import rl "vendor:raylib"

TextureId :: enum {
	Player,
}

loaded_textures: [TextureId]rl.Texture2D

load_textures :: proc() {
	loaded_textures = {
		.Player = rl.LoadTexture("assets/samurai.png"),
	}
}

unload_textures :: proc() {
	for tex in loaded_textures {
		rl.UnloadTexture(tex)
	}
}
