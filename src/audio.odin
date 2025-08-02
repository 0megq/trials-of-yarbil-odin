package game

import "core:math/rand"
import "core:prof/spall"
import rl "vendor:raylib"

SoundId :: enum {
	SwordSlash,
	SwordHit,
	SwordKill,
	PlayerHurt,
	EnemyLunge,
	Explosion,
	small_explosion,
	tick,
	enemy_spot_player,
}

loaded_sounds: [SoundId]rl.Sound
loaded_music: rl.Music

MAX_SOUNDS :: 10
sound_pool: [SoundId][MAX_SOUNDS]rl.Sound
sound_pool_cur: [SoundId]int
pitch_variation: [SoundId]f32 = {
	.SwordSlash        = 0.1,
	.SwordHit          = 0.1,
	.SwordKill         = 0,
	.PlayerHurt        = 0.1,
	.EnemyLunge        = 0.1,
	.Explosion         = 0.1,
	.tick              = 0.1,
	.small_explosion   = 0.1,
	.enemy_spot_player = 0.1,
}

init_audio_and_load_sounds :: proc() {
	rl.InitAudioDevice()
	load_sounds()
	load_and_play_music()
}

load_and_play_music :: proc() {
	loaded_music = rl.LoadMusicStream("res/sound/botw.mp3")
	loaded_music.looping = true
	rl.PlayMusicStream(loaded_music)
	rl.PauseMusicStream(loaded_music)
}

update_music :: proc() {
	rl.UpdateMusicStream(loaded_music)
}

load_sounds :: proc() {
	loaded_sounds = {
		.SwordSlash        = rl.LoadSound("res/sound/sword_slash.mp3"),
		.SwordHit          = rl.LoadSound("res/sound/sword_hit.mp3"),
		.SwordKill         = rl.LoadSound("res/sound/sword_kill.mp3"),
		.PlayerHurt        = rl.LoadSound("res/sound/player_hurt.mp3"),
		.EnemyLunge        = rl.LoadSound("res/sound/enemy_lunge.mp3"),
		.Explosion         = rl.LoadSound("res/sound/explosion.mp3"),
		.tick              = rl.LoadSound("res/sound/tick.mp3"),
		.small_explosion   = rl.LoadSound("res/sound/small_explosion.mp3"),
		.enemy_spot_player = rl.LoadSound("res/sound/enemy_spot_player.mp3"),
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
	unload_music()
	rl.CloseAudioDevice()
}

unload_music :: proc() {
	rl.UnloadMusicStream(loaded_music)
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
