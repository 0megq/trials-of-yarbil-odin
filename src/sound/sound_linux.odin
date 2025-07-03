#+build linux
package sound

/*

Helpers for playing sound via FMOD.

Built to be a standalone package with no external dependencies.

*/

import fcore "fmod/core"
import fstudio "fmod/studio"

// you could use this during the build step to generate an enum list of sounds, that way you
// don't need to manually match it with the event:/name thing. But it's kinda overkill tbh.
// just typey typey
//import fsbank "fmod/fsbank"

import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:log"
import "core:strings"

Vec2 :: [2]f32

state: struct {
	initialized:     bool,
	sound_ticks:     u64,
	system:          ^fstudio.SYSTEM,
	core_system:     ^fcore.SYSTEM,
	bank:            ^fstudio.BANK,
	strings_bank:    ^fstudio.BANK,
	master_ch_group: ^fcore.CHANNELGROUP,
	sound_emitters:  [dynamic]Sound_Emitter,
}

Sound_Emitter :: struct {
	event:            ^fstudio.EVENTINSTANCE,
	last_update_tick: u64,
	unique_id:        string,
}

INVALID_POS :: Vec2{99999, 99999}

init :: proc() {
	fmt.println("WARNING: sound.odin is not implemented for linux")
}

update :: proc(listener_pos: Vec2, master_volume: f32) {

}

play :: proc(name: string, pos := INVALID_POS, cooldown_ms: f32 = 40.0) -> ^fstudio.EVENTINSTANCE {
	return nil
}

// note, this is separate to make it work with a fixed timestep
update_sound_emitters :: proc() {

}

/*

Call every frame to continuously play a sound, and have it auto-stop playing when it no longer gets called.

unique_id gets appended to the name. This identifies the sound. Leave blank if you're absolutely sure you'll
only have one playing at a time and don't need to care about unique identification (like main menu music)

Passing position will update its position each frame.

Example for playing a sound at an entity's position continuously:

```
enemy: ^Entity  
unique_id := fmt.tprint(enemy.handle.id)  
play_emitter("event:/ambient_enemy_groan", unique_id, pos=enemy.pos)
```
*/
play_continuously :: proc(name: string, unique_id: string, pos := INVALID_POS) {
}

stop :: proc(event: ^fstudio.EVENTINSTANCE) -> bool {
	return false
}

update_pos :: proc(event: ^fstudio.EVENTINSTANCE, pos: Vec2) -> bool {
	return false
}
