package game


// import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:reflect"
import rl "vendor:raylib"

TILE_SIZE :: 8
TILEMAP_SIZE :: 200

// Tilemaps are indexed with x, then y. Column major
Tilemap :: [TILEMAP_SIZE][TILEMAP_SIZE]TileData
WallTilemap :: [TILEMAP_SIZE][TILEMAP_SIZE]bool

GRASS_COLOR :: Color{0, 255, 0, 255}
STONE_COLOR :: Color{100, 100, 100, 255}
DIRT_COLOR :: Color{100, 50, 0, 255}
WATER_COLOR :: Color{0, 0, 255, 255}

TileData :: union #no_nil {
	EmptyData,
	GrassData,
	StoneData,
	WaterData,
	DirtData,
}

EmptyData :: struct {
}

GrassData :: struct {
	on_fire:       bool,
	spread_timer:  f32,
	should_spread: bool,
	burnt:         bool,
}

DirtData :: struct {
}

StoneData :: struct {
}

WaterData :: struct {
}

update_tilemap :: proc(world: ^World) {
	tilemap := &world.tilemap
	// Fire spread for grass tiles
	for tile_pos in get_tiles_on_fire(tilemap^) {
		// Update tiles
		tile_data := &tilemap[tile_pos.x][tile_pos.y].(GrassData)
		if !tile_data.burnt {
			// Decrease spread timer
			tile_data.spread_timer -= delta
			if tile_data.spread_timer <= 0 {
				// Spread once timer is done
				if tile_data.should_spread {
					for neighbor_pos in get_neighboring_tiles(tile_pos) {
						if is_valid_tile_pos(neighbor_pos) {
							#partial switch data in tilemap[neighbor_pos.x][neighbor_pos.y] {
							case GrassData:
								if data.on_fire || data.burnt {
									continue
								}
								// Start the firespread for the other tiles as well (set on_fire, spreading, and spread_timer)
								set_tile(
									tilemap,
									neighbor_pos,
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
		perform_attack(world, &fire_attack)
	}
}

is_valid_tile_pos :: proc(pos: Vec2i) -> bool {
	return pos.x >= 0 && pos.x < TILEMAP_SIZE && pos.y >= 0 && pos.y < TILEMAP_SIZE
}

is_tile_walkable :: proc(tm: Tilemap, wall_tm: WallTilemap, pos: Vec2i) -> bool {
	if wall_tm[pos.x][pos.y] {
		return false
	}
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

is_tile_line_walkable :: proc(tm: Tilemap, wall_tm: WallTilemap, start: Vec2, end: Vec2) -> bool {
	start := start
	end := end

	if start.x > end.x { 	// Make sure the start -> end is always left to right (x increases)
		start, end = end, start
	}

	// Check if points are strictly horizontal or strictly vertical
	start_tile := world_to_tilemap(start)
	end_tile := world_to_tilemap(end)
	if start_tile == end_tile {
		return is_tile_walkable(tm, wall_tm, start_tile)
	} else if start_tile.y == end_tile.y { 	// horizontal
		if start_tile.x > end_tile.x { 	// Flip it!
			start_tile.x, end_tile.x = end_tile.x, start_tile.x
		}
		for tile_x in start_tile.x ..= end_tile.x {
			if !is_tile_walkable(tm, wall_tm, {tile_x, start_tile.y}) {
				return false
			}
		}
	} else if start_tile.x == end_tile.x { 	// vertical
		if start_tile.y > end_tile.y { 	// Flip y, if one is bigger than the other
			start_tile.y, end_tile.y = end_tile.y, start_tile.y
		}
		for tile_y in start_tile.y ..= end_tile.y {
			if !is_tile_walkable(tm, wall_tm, {start_tile.x, tile_y}) {
				return false
			}
		}
	} else {
		slope := (start.y - end.y) / (start.x - end.x)
		current := start
		current_tile := start_tile
		// Check first tile
		if !is_tile_walkable(tm, wall_tm, current_tile) {
			return false
		}

		// Loop until we reach the end tile
		for current_tile != end_tile {
			// Get the next tile in the x direction
			x_til_next_tile := f32(current_tile.x + 1) * TILE_SIZE - current.x
			// Get next tile in y direction
			y_til_next_tile := f32(current_tile.y + 1) * TILE_SIZE - current.y
			if slope < 0 {
				y_til_next_tile -= TILE_SIZE // Go up a tile instead if slope is negative (y is decreasing)
			}

			// Move current position and current tile
			if math.abs(y_til_next_tile / slope) < x_til_next_tile {
				// If x distance with y til next tile is smaller, then we move in the y
				current += {y_til_next_tile / slope, y_til_next_tile}
				current_tile.y += i32(math.sign(slope))
			} else {
				// If x til next tile is smaller, then we move in the x
				current += {x_til_next_tile, x_til_next_tile * slope}
				current_tile.x += 1
			}

			// If tile is not walkable return false, otherwise keep going until end
			if !is_tile_walkable(tm, wall_tm, current_tile) {
				return false
			}
		}
	}

	return true
}

get_neighboring_tile_data :: proc(tm: Tilemap, pos: Vec2i) -> [4]TileData {
	return {tm[pos.x][pos.y - 1], tm[pos.x - 1][pos.y], tm[pos.x][pos.y + 1], tm[pos.x + 1][pos.y]}
}

get_neighboring_tiles :: proc(pos: Vec2i) -> [4]Vec2i {
	return {{pos.x, pos.y - 1}, {pos.x - 1, pos.y}, {pos.x, pos.y + 1}, {pos.x + 1, pos.y}}
}

get_neighboring_tiles_diagonal :: proc(pos: Vec2i) -> [8]Vec2i {
	return {
		{pos.x, pos.y - 1},
		{pos.x - 1, pos.y},
		{pos.x, pos.y + 1},
		{pos.x + 1, pos.y},
		{pos.x - 1, pos.y - 1},
		{pos.x - 1, pos.y + 1},
		{pos.x + 1, pos.y + 1},
		{pos.x + 1, pos.y - 1},
	}
}

set_tile :: proc(tm: ^Tilemap, pos: Vec2i, data: TileData) {
	if !is_valid_tile_pos(pos) {
		rl.TraceLog(.ERROR, "Invalid tile position")
		return
	}
	tm[pos.x][pos.y] = data
}

fill_tiles :: proc(tm: ^Tilemap, from: Vec2i, to: Vec2i, data: TileData) {
	if from.x > to.x || from.y > to.y {
		rl.TraceLog(.ERROR, "Invalid range for fill_tile")
	}

	for x in from.x ..= to.x {
		for y in from.y ..= to.y {
			set_tile(tm, {x, y}, data)
		}
	}
}

get_tiles_with_data :: proc(tm: Tilemap, data: TileData, exact_match_only := false) -> []Vec2i {
	result := make([dynamic]Vec2i, context.temp_allocator)
	data_type := reflect.union_variant_typeid(data)

	if exact_match_only {
		for col, x in tm {
			for tile, y in col {
				if reflect.union_variant_typeid(tile) == data_type && tile == data {
					append(&result, Vec2i{i32(x), i32(y)})
				}
			}
		}
		return result[:]
	}

	for col, x in tm {
		for tile, y in col {
			if reflect.union_variant_typeid(tile) == data_type {
				append(&result, Vec2i{i32(x), i32(y)})
			}
		}
	}
	return result[:]
}

get_tiles_on_fire :: proc(tm: Tilemap) -> []Vec2i {
	result := make([dynamic]Vec2i, context.temp_allocator)
	for col, x in tm {
		for tile, y in col {
			if reflect.union_variant_typeid(tile) == GrassData && tile.(GrassData).on_fire {
				append(&result, Vec2i{i32(x), i32(y)})
			}
		}
	}
	return result[:]
}

draw_tilemap :: proc(tm: Tilemap, show_grid := false) {
	start := world_to_tilemap(window_to_world({})) - 1
	end := world_to_tilemap(window_to_world({f32(window_size.x), f32(window_size.y)})) + 1
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
				scale      = 1.1,
				tint       = rl.WHITE,
			}

			switch data in tm[x][y] {
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
get_tiles_in_shape :: proc(shape: Shape, pos: Vec2, extrusion: f32 = 0) -> []Vec2i {
	result := make([dynamic]Vec2i, context.temp_allocator)

	switch s in shape {
	case Circle:
		center_tile := world_to_tilemap(pos + s.pos)
		tile_radius := i32(math.ceil((s.radius + extrusion) / TILE_SIZE))
		start := Vec2i{center_tile.x - tile_radius, center_tile.y - tile_radius}
		end := Vec2i{center_tile.x + tile_radius, center_tile.y + tile_radius}

		start.x = clamp(start.x, 0, TILEMAP_SIZE - 1)
		start.y = clamp(start.y, 0, TILEMAP_SIZE - 1)
		end.x = clamp(end.x, 0, TILEMAP_SIZE - 1)
		end.y = clamp(end.y, 0, TILEMAP_SIZE - 1)

		for x in start.x ..= end.x {
			for y in start.y ..= end.y {
				rect := Rectangle{f32(x * TILE_SIZE), f32(y * TILE_SIZE), TILE_SIZE, TILE_SIZE}
				if rl.CheckCollisionCircleRec(s.pos + pos, s.radius + extrusion, rect) {
					append(&result, Vec2i{x, y})
				}
			}
		}
	case Polygon:

	case Rectangle:
		top_left_tile := world_to_tilemap(pos + {s.x - extrusion, s.y - extrusion})
		bot_right_tile := world_to_tilemap(
			pos + {s.x, s.y} + {s.width + extrusion, s.height + extrusion},
		)
		for x in top_left_tile.x ..= bot_right_tile.x {
			for y in top_left_tile.y ..= bot_right_tile.y {
				append(&result, Vec2i{x, y})
			}
		}
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

load_tilemap :: proc(tm: ^Tilemap, filename: cstring) {
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

save_tilemap :: proc(tm: Tilemap, filename: cstring) {
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
