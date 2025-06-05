package game

import "core:math/rand"
import rl "vendor:raylib"

SoundId :: enum {
	SwordSlash,
	SwordHit,
	SwordKill,
	PlayerHurt,
}

loaded_sounds: [SoundId]rl.Sound

MAX_SOUNDS :: 10
sound_pool: [SoundId][MAX_SOUNDS]rl.Sound
sound_pool_cur: [SoundId]int
pitch_variation: [SoundId]f32 = {
	.SwordSlash = 0.1,
	.SwordHit   = 0,
	.SwordKill  = 0,
	.PlayerHurt = 0,
}

init_audio_and_load_sounds :: proc() {
	rl.InitAudioDevice()
	load_sounds()
}

load_sounds :: proc() {
	loaded_sounds = {
		.SwordSlash = rl.LoadSound("res/sound/sword_slash.mp3"),
		.SwordHit   = rl.LoadSound("res/sound/sword_hit.mp3"),
		.SwordKill  = rl.LoadSound("res/sound/sword_kill.mp3"),
		.PlayerHurt = rl.LoadSound("res/sound/player_hurt.mp3"),
	}
	for &pool, id in sound_pool {
		for &alias in pool {
			alias = rl.LoadSoundAlias(loaded_sounds[id])
		}
	}
}

play_sound :: proc(sound: SoundId) {
	pool := sound_pool[sound]
	pool_ptr := &sound_pool_cur[sound]
	pitch := 1 + pitch_variation[sound] * rand.float32_range(-1, 1)
	rl.SetSoundPitch(pool[pool_ptr^], pitch)
	rl.PlaySound(pool[pool_ptr^])
	pool_ptr^ += 1
	if pool_ptr^ >= MAX_SOUNDS {
		pool_ptr^ = 0
	}
}

close_audio_and_unload_sounds :: proc() {
	unload_sounds()
	rl.CloseAudioDevice()
}

unload_sounds :: proc() {
	for pool in sound_pool {
		for alias in pool {
			rl.UnloadSoundAlias(alias)
		}
	}
	for sound in loaded_sounds {
		rl.UnloadSound(sound)
	}
}
