package game

import "core:encoding/json"
import "core:os"
import rl "vendor:raylib"

ENTITY_LOAD_FILE_PATH :: "entity.json"
ENTITY_SAVE_FILE_PATH :: "entity.json"

selected_entity :: ^PhysicsEntity

// This is the only data that gets saved for entities
EntityData :: struct {
	player_pos:        Vec2,
	enemies:           [dynamic]Enemy,
	items:             [dynamic]Item,
	exploding_barrels: [dynamic]ExplodingBarrel,
}

load_entities :: proc() {
	// Load EntityData struct from json file
	// generate new uuid's

	entity_data := EntityData{}

	if bytes, ok := os.read_entire_file(ENTITY_LOAD_FILE_PATH, context.allocator); ok {
		if json.unmarshal(bytes, &entity_data) != nil {
			rl.TraceLog(.WARNING, "Error parsing entity data")
		}
		delete(bytes)
	} else {
		rl.TraceLog(.WARNING, "Error parsing entity data")
	}

	player.pos = entity_data.player_pos
	enemies = entity_data.enemies
	items = entity_data.items
	exploding_barrels = entity_data.exploding_barrels

	rl.TraceLog(.INFO, "Entities Loaded")
}

save_entities :: proc() {
	// Save EntityData struct to json file

	entity_data := EntityData{player.pos, enemies, items, exploding_barrels}

	if bytes, err := json.marshal(
		entity_data,
		allocator = context.allocator,
		opt = {pretty = true},
	); err == nil {
		os.write_entire_file(ENTITY_SAVE_FILE_PATH, bytes)
		delete(bytes)
	} else {
		rl.TraceLog(.WARNING, "Error saving entity data")
	}

	rl.TraceLog(.INFO, "Entities Saved")
}

unload_entities :: proc() {
	// Unload entity data AKA delete memory
	delete(enemies)
	delete(items)
	delete(exploding_barrels)

	rl.TraceLog(.INFO, "Entities Unloaded")
}

update_editor_world :: proc() {
	// select entity
	// use entity shape for this

	// move entity
	// 

	// delete entity
}

draw_entity_editor_world :: proc() {
	// draw selected entity outline
}

draw_entity_editor_ui :: proc() {
	// draw selected entity data
	// draw entity pos
}
