package game


// import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:reflect"
import rl "vendor:raylib"

TILE_SIZE :: 8
TILEMAP_SIZE :: 200

Tilemap :: [TILEMAP_SIZE][TILEMAP_SIZE]TileData

GRASS_COLOR :: Color{0, 255, 0, 255}
STONE_COLOR :: Color{100, 100, 100, 255}
DIRT_COLOR :: Color{100, 50, 0, 255}
WATER_COLOR :: Color{0, 0, 255, 255}
WALL_COLOR :: Color{0, 0, 50, 255}

TileData :: union #no_nil {
	EmptyData,
	GrassData,
	StoneData,
	WaterData,
	WallData,
	DirtData,
}

EmptyData :: struct {}

GrassData :: struct {
	on_fire:       bool,
	spread_timer:  f32,
	should_spread: bool,
	burnt:         bool,
}

DirtData :: struct {}

StoneData :: struct {}

WaterData :: struct {}

WallData :: struct {}


update_tilemap :: proc() {
	// Fire spread for grass tiles
	for tile_pos in get_tiles_on_fire() {
		// Update tiles
		tile_data := &tilemap[tile_pos.x][tile_pos.y].(GrassData)
		if !tile_data.burnt {
			// Decrease spread timer
			tile_data.spread_timer -= delta
			if tile_data.spread_timer <= 0 {
				// Spread once timer is done
				if tile_data.should_spread {
					for t in get_neighboring_tiles(tile_pos) {
						if is_valid_tile_pos(t) {
							#partial switch data in tilemap[t.x][t.y] {
							case GrassData:
								if data.on_fire || data.burnt {
									continue
								}
								// Start the firespread for the other tiles as well (set on_fire, spreading, and spread_timer)
								set_tile(
									t,
									GrassData{true, 1, rand.choice([]bool{false, true}), false},
								)
							}

						}
					}
				}
				tile_data.on_fire = false
				tile_data.burnt = true
			}
		}

		// Deal damage
		fire_attack := Attack {
			shape   = Rectangle{0, 0, TILE_SIZE, TILE_SIZE},
			data    = FireAttackData{},
			pos     = Vec2{f32(tile_pos.x), f32(tile_pos.y)} * TILE_SIZE,
			damage  = FIRE_TILE_DAMAGE * delta,
			targets = {.ExplodingBarrel, .Player, .Enemy},
		}
		perform_attack(&fire_attack)
	}
}

is_valid_tile_pos :: proc(pos: Vec2i) -> bool {
	return pos.x >= 0 && pos.x < TILEMAP_SIZE && pos.y >= 0 && pos.y < TILEMAP_SIZE
}

is_tile_walkable :: proc(pos: Vec2i, tm: Tilemap) -> bool {
	#partial switch d in tm[pos.x][pos.y] {
	case DirtData:
		return true
	case StoneData:
		return true
	case GrassData:
		return true
	}
	return false
}

get_neighboring_tile_data :: proc(pos: Vec2i) -> [4]TileData {
	return {
		tilemap[pos.x][pos.y - 1],
		tilemap[pos.x - 1][pos.y],
		tilemap[pos.x][pos.y + 1],
		tilemap[pos.x + 1][pos.y],
	}
}

get_neighboring_tiles :: proc(pos: Vec2i) -> [4]Vec2i {
	return {{pos.x, pos.y - 1}, {pos.x - 1, pos.y}, {pos.x, pos.y + 1}, {pos.x + 1, pos.y}}
}

set_tile :: proc(pos: Vec2i, data: TileData) {
	if !is_valid_tile_pos(pos) {
		rl.TraceLog(.ERROR, "Invalid tile position")
		return
	}
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

get_tiles_with_data :: proc(
	tilemap: Tilemap,
	data: TileData,
	exact_match_only := false,
) -> []Vec2i {
	result := make([dynamic]Vec2i, context.temp_allocator)
	data_type := reflect.union_variant_typeid(data)

	if exact_match_only {
		for col, x in tilemap {
			for tile, y in col {
				if reflect.union_variant_typeid(tile) == data_type && tile == data {
					append(&result, Vec2i{i32(x), i32(y)})
				}
			}
		}
		return result[:]
	}

	for col, x in tilemap {
		for tile, y in col {
			if reflect.union_variant_typeid(tile) == data_type {
				append(&result, Vec2i{i32(x), i32(y)})
			}
		}
	}
	return result[:]
}

get_tiles_on_fire :: proc() -> []Vec2i {
	result := make([dynamic]Vec2i, context.temp_allocator)
	for col, x in tilemap {
		for tile, y in col {
			if reflect.union_variant_typeid(tile) == GrassData && tile.(GrassData).on_fire {
				append(&result, Vec2i{i32(x), i32(y)})
			}
		}
	}
	return result[:]
}

draw_tilemap :: proc(tilemap: Tilemap, show_grid := false) {
	start := world_to_tilemap(screen_to_world({})) - 1
	end := world_to_tilemap(screen_to_world({f32(WINDOW_SIZE.x), f32(WINDOW_SIZE.y)})) + 1
	start.x = clamp(start.x, 0, TILEMAP_SIZE - 1)
	start.y = clamp(start.y, 0, TILEMAP_SIZE - 1)
	end.x = clamp(end.x, 0, TILEMAP_SIZE - 1)
	end.y = clamp(end.y, 0, TILEMAP_SIZE - 1)
	for x in start.x ..= end.x {
		for y in start.y ..= end.y {
			sprite := Sprite {
				tex_id     = .Tilemap,
				tex_region = {0, 0, TILE_SIZE, TILE_SIZE},
				tex_origin = {},
				scale      = 1,
				tint       = rl.WHITE,
			}

			switch data in tilemap[x][y] {
			case GrassData:
				sprite.tex_region.x = 1
				sprite.tex_region.y = 1
				if data.on_fire {
					sprite.tex_region.x = 2
				} else if data.burnt {
					sprite.tex_region.x = 3
				}
			case DirtData:
				sprite.tex_region.y = 1
			case WaterData:
				sprite.tex_region.x = 2
			case StoneData:
				sprite.tex_region.x = 1
			case WallData:
				sprite.tex_region.x = 3
			case EmptyData:

			}

			sprite.tex_region.x *= TILE_SIZE
			sprite.tex_region.y *= TILE_SIZE

			draw_sprite(sprite, tilemap_to_world({x, y}))

			// rl.DrawRectangleLines(
			// 	i32(x) * TILE_SIZE,
			// 	i32(y) * TILE_SIZE,
			// 	TILE_SIZE,
			// 	TILE_SIZE,
			// 	rl.BLACK,
			// )
		}
	}

	if show_grid {
		for x in start.x ..= end.x {
			for y in start.y ..= end.y {
				rl.DrawRectangleLines(
					i32(x) * TILE_SIZE,
					i32(y) * TILE_SIZE,
					TILE_SIZE,
					TILE_SIZE,
					{100, 100, 100, 100},
				)
			}
		}
	}
}

// Allocates using temp allocator. 
get_tile_shape_collision :: proc(shape: Shape, pos: Vec2) -> []Vec2i {
	result := make([dynamic]Vec2i, context.temp_allocator)

	switch s in shape {
	case Circle:
		center_tile := world_to_tilemap(pos + s.pos)
		tile_radius := i32(math.ceil(s.radius / TILE_SIZE))
		start := Vec2i{center_tile.x - tile_radius, center_tile.y - tile_radius}
		end := Vec2i{center_tile.x + tile_radius, center_tile.y + tile_radius}

		start.x = clamp(start.x, 0, TILEMAP_SIZE - 1)
		start.y = clamp(start.y, 0, TILEMAP_SIZE - 1)
		end.x = clamp(end.x, 0, TILEMAP_SIZE - 1)
		end.y = clamp(end.y, 0, TILEMAP_SIZE - 1)

		for x in start.x ..= end.x {
			for y in start.y ..= end.y {
				rect := Rectangle{f32(x * TILE_SIZE), f32(y * TILE_SIZE), TILE_SIZE, TILE_SIZE}
				if rl.CheckCollisionCircleRec(s.pos + pos, s.radius, rect) {
					append(&result, Vec2i{x, y})
				}
			}
		}
	case Polygon:

	case Rectangle:
	}
	return result[:]
}

world_to_tilemap :: proc(pos: Vec2) -> Vec2i {
	return {i32(pos.x), i32(pos.y)} / TILE_SIZE
}

tilemap_to_world :: proc(pos: Vec2i) -> Vec2 {
	return {f32(pos.x), f32(pos.y)} * TILE_SIZE
}

tilemap_to_world_centered :: proc(pos: Vec2i) -> Vec2 {
	return {f32(pos.x), f32(pos.y)} * TILE_SIZE + TILE_SIZE / 2
}

load_tilemap :: proc(filename: cstring, tm: ^Tilemap) {
	img := rl.LoadImage(filename)
	defer rl.UnloadImage(img)
	if rl.IsImageReady(img) {
		for x in 0 ..< TILEMAP_SIZE {
			for y in 0 ..< TILEMAP_SIZE {
				switch rl.GetImageColor(img, i32(x), i32(y)) {
				case GRASS_COLOR:
					tm[x][y] = GrassData{}
				case STONE_COLOR:
					tm[x][y] = StoneData{}
				case WATER_COLOR:
					tm[x][y] = WaterData{}
				case WALL_COLOR:
					tm[x][y] = WallData{}
				case DIRT_COLOR:
					tm[x][y] = DirtData{}
				case:
					tm[x][y] = EmptyData{}
				}
			}
		}
	} else {
		rl.TraceLog(.WARNING, "Tilemap image not ready")
	}
}


save_tilemap :: proc(filename: cstring, tm: Tilemap) {
	img := tilemap_to_image(tm)

	rl.ExportImage(img, filename)

	unload_tilemap_image(img)
}

tilemap_to_image :: proc(tm: Tilemap) -> rl.Image {
	pixels: []Color = make([]Color, TILEMAP_SIZE * TILEMAP_SIZE, context.allocator)

	for x in 0 ..< TILEMAP_SIZE {
		for y in 0 ..< TILEMAP_SIZE {
			color: Color

			switch data in tm[x][y] {
			case GrassData:
				color = GRASS_COLOR
			case StoneData:
				color = STONE_COLOR
			case WaterData:
				color = WATER_COLOR
			case WallData:
				color = WALL_COLOR
			case DirtData:
				color = DIRT_COLOR
			case EmptyData:
				color = {}
			}


			pixels[x + y * TILEMAP_SIZE] = color
		}
	}

	image := rl.Image {
		data    = raw_data(pixels),
		width   = TILEMAP_SIZE,
		height  = TILEMAP_SIZE,
		mipmaps = 1,
		format  = .UNCOMPRESSED_R8G8B8A8,
	}

	return image
}

unload_tilemap_image :: proc(img: rl.Image) {
	free(img.data, context.allocator)
}
