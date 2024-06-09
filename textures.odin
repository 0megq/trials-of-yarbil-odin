package game

import rl "vendor:raylib"

TextureId :: enum {
	Player,
}

textures: [TextureId]rl.Texture2D

load_textures :: proc() {
	textures = {
		.Player = rl.LoadTexture("assets/samurai.png"),
	}
}

unload_textures :: proc() {
	for tex in textures {
		rl.UnloadTexture(tex)
	}
}
