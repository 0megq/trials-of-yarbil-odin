package game


// import "core:fmt"
import rl "vendor:raylib"

TILE_SIZE :: 8
TILEMAP_SIZE :: 200

TileData :: union {
	GrassData,
	StoneData,
	WaterData,
	WallData,
}

GrassData :: struct {
	on_fire: bool,
}

StoneData :: struct {}

WaterData :: struct {}

WallData :: struct {}

set_tile :: proc(pos: Vec2i, data: TileData) {
	// No bounds checking
	tilemap[pos.x][pos.y] = data
}

fill_tiles :: proc(from: Vec2i, to: Vec2i, data: TileData) {
	if from.x > to.x || from.y > to.y {
		rl.TraceLog(.ERROR, "Invalid range for fill_tile")
	}

	for x in from.x ..= to.x {
		for y in from.y ..= to.y {
			set_tile({x, y}, data)
		}
	}
}

draw_tilemap :: proc() {
	start := world_to_tilemap(screen_to_world({})) - 1
	end := (world_to_tilemap(screen_to_world({f32(WINDOW_SIZE.x), f32(WINDOW_SIZE.y)})) + 1)
	start.x = clamp(start.x, 0, TILEMAP_SIZE - 1)
	start.y = clamp(start.y, 0, TILEMAP_SIZE - 1)
	end.x = clamp(end.x, 0, TILEMAP_SIZE - 1)
	end.y = clamp(end.y, 0, TILEMAP_SIZE - 1)

	for x in start.x ..< end.x {
		for y in start.y ..< end.y {
			sprite := Sprite {
				tex_id     = .Tilemap,
				tex_region = {0, 0, TILE_SIZE, TILE_SIZE},
				tex_origin = {},
				scale      = 1,
				tint       = rl.WHITE,
			}

			switch data in tilemap[x][y] {
			case GrassData:
				sprite.tex_region.y = TILE_SIZE
			case WaterData:

			case StoneData:
				sprite.tex_region.x = TILE_SIZE
			case WallData:
				sprite.tex_region.x = TILE_SIZE
				sprite.tex_region.y = TILE_SIZE
			}

			draw_sprite(sprite, {f32(x), f32(y)} * TILE_SIZE)

			// rl.DrawRectangleLines(
			// 	i32(x) * TILE_SIZE,
			// 	i32(y) * TILE_SIZE,
			// 	TILE_SIZE,
			// 	TILE_SIZE,
			// 	rl.BLACK,
			// )
		}
	}
}


world_to_tilemap :: proc(pos: Vec2) -> Vec2i {
	return {i32(pos.x) / TILE_SIZE, i32(pos.y) / TILE_SIZE}
}
