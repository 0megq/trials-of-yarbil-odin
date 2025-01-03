package game

import "core:math"

// To be used in a NavMesh
// NavCell :: struct {
// 	verts: [3]Vec2, // Vertices that make up the cell
// }

// // Stores connections to other nodes
// NavNode :: struct {
// 	pos:         Vec2, // Average of both vertices is the position of the node
// 	verts:       [2]Vec2, // These are the two vertices of the edge
// 	connections: [4]int, // Stores indices to connected nodes
// }

// NavMesh :: struct {
// 	cells: [dynamic]NavCell,
// 	nodes: [dynamic]NavNode,
// }

// NavGraphConnection :: struct {

// }

// needed: tile pos, up down left or right.
// useful: world pos, world pos connecting tiles and edges, which connections exist
NavGraphNode :: struct {
	pos:         Vec2,
	connections: [4]int,
}

NavGraph :: struct {
	nodes: [dynamic]NavGraphNode,
}


calculate_tile_graph :: proc(graph: ^NavGraph, tm: Tilemap, wall_tm: WallTilemap) {
	if graph.nodes == nil {
		graph.nodes = make([dynamic]NavGraphNode)
	} else {
		clear(&graph.nodes)
	}
	for x in 0 ..< TILEMAP_SIZE {
		for y in 0 ..< TILEMAP_SIZE {
			if is_tile_walkable({i32(x), i32(y)}, tm, wall_tm) {
				append(
					&graph.nodes,
					NavGraphNode{tilemap_to_world_centered({i32(x), i32(y)}), {-1, -1, -1, -1}},
				)
			}
		}
	}

	for &a, ai in graph.nodes {
		for bi := ai + 1; bi < len(graph.nodes); bi += 1 {
			b := &graph.nodes[bi]
			// They are right next to each other
			if distance_squared(b.pos, a.pos) <= TILE_SIZE * TILE_SIZE + 1 {
				// Set the connection on a
				for c, i in a.connections {
					if c == -1 {
						a.connections[i] = bi
						break
					}
				}
				// Set the connection on b
				for c, i in b.connections {
					if c == -1 {
						b.connections[i] = ai
						break
					}
				}
			}
		}
	}
}

find_path_tiles :: proc(
	start: Vec2,
	end: Vec2,
	graph: NavGraph,
	tm: Tilemap,
	wall_tm: WallTilemap,
) -> []Vec2 {
	// fmt.println("######\nSearching for path\n######")
	// Get start and end node indices
	start_index: int = -1
	end_index: int = -1
	{
		min_dist_to_start_sqrd: f32 = math.INF_F32
		min_dist_to_end_sqrd: f32 = math.INF_F32
		for node, i in graph.nodes {
			dist_to_start_sqrd := distance_squared(node.pos, start)
			if dist_to_start_sqrd < min_dist_to_start_sqrd {
				min_dist_to_start_sqrd = dist_to_start_sqrd
				start_index = i
			}

			dist_to_end_sqrd := distance_squared(node.pos, end)
			if dist_to_end_sqrd < min_dist_to_end_sqrd {
				min_dist_to_end_sqrd = dist_to_end_sqrd
				end_index = i
			}
		}

		for node, i in graph.nodes {
			if node.pos == start {
				start_index = i
				continue
			}
			if node.pos == end {
				end_index = i
				continue
			}
		}

		if start_index == -1 || end_index == -1 {
			return nil
		}

		// If start and end are inside same cell then exit early and return a straight line path between start and end
		if start_index == end_index {
			path := make([]Vec2, 2, context.allocator)
			path[0] = start
			path[1] = end
			return path
		}
	}

	// Get node path via A*
	node_path := astar_tiles(start_index, end_index, graph)
	defer delete(node_path)
	if node_path == nil {
		return nil
	}

	// Getting path without using funnel algo
	// path := make([]Vec2, len(node_path) + 2, allocator)
	// path[0] = start
	// for node, i in node_path {
	// 	path[i + 1] = graph.nodes[node].pos
	// }
	// path[len(node_path) + 1] = end
	// return path

	return path_smooth_tiles(node_path, start, end, graph, tm, wall_tm)

	// portals := build_tile_portals(node_path, start, end)
	// defer delete(portals)

	// return string_pull(portals)
}


// Returns slice of indices to nodes in the navmesh. Heuristic is Euclidean distance. Allocates using context.temp_allocator
astar_tiles :: proc(start_index: int, end_index: int, graph: NavGraph) -> []int {
	// Initialize open and closed lists
	closed_nodes := make(map[int]int, len(graph.nodes), context.temp_allocator) // Only stores came from nodes
	open_nodes := make(map[int]struct {
			came_from: int,
			f:         f32,
			g:         f32,
		}, len(graph.nodes), context.temp_allocator)
	defer delete(closed_nodes)
	defer delete(open_nodes)

	end_node := graph.nodes[end_index]

	// Start f is just equal to the heuristic
	start_f := distance(graph.nodes[start_index].pos, graph.nodes[end_index].pos)
	open_nodes[start_index] = {start_index, start_f, 0}

	for len(open_nodes) > 0 {
		// fmt.printfln("******\n Open Nodes: %#v \nClosed Nodes: %#v", open_nodes, closed_nodes)
		// Get current index
		current_index := -1
		current_value: struct {
			came_from: int,
			f:         f32,
			g:         f32,
		}
		for index, value in open_nodes {
			if current_index == -1 {
				current_index = index
				current_value = value
				continue
			}

			if value.f < current_value.f {
				current_index = index
				current_value = value
			}
		}
		// fmt.printfln("Current Index: %v, Values: %v", current_index, current_value)
		delete_key(&open_nodes, current_index)
		closed_nodes[current_index] = current_value.came_from

		if current_index == end_index {
			break
		}

		current_node := graph.nodes[current_index]

		for connection in current_node.connections {
			if connection == -1 {
				break
			}
			// If in closed nodes
			if connection in closed_nodes {
				continue
			}

			connected_node := graph.nodes[connection]
			// Calculate G values. Distance to next tile is always the size of a tile
			g := current_value.g + TILE_SIZE

			// If in open nodes, compare g
			if value, ok := &open_nodes[connection]; ok {
				// If new g is less then update the old g and f value, otherwise don't
				if g < value.g {
					// fmt.printfln("Replacing %v g value", connection)
					// fmt.println("Replacing g value for %v from %v to %v", connection, value.g, g)
					value.g = g
					value.f -= g - value.g
					value.came_from = current_index
					continue
				}
			} else {
				// fmt.printfln("Adding %v to open nodes", connection)
				// Else calculate f = g + h (distance to end), and add node to open nodes
				open_nodes[connection] = {
					came_from = current_index,
					f         = g + distance(connected_node.pos, end_node.pos),
					g         = g,
				}
			}

			// fmt.println("------")
		}
	}
	if _, ok := closed_nodes[end_index]; ok {
		// Trace path backwards
		path := make([dynamic]int, context.temp_allocator)
		defer delete(path)
		current_index := end_index
		for current_index != start_index {
			append(&path, current_index)
			current_index = closed_nodes[current_index]
		}
		append(&path, start_index)

		// Create slice result and copy the path values in reverse order
		path_length := len(path)
		result := make([]int, path_length, context.temp_allocator)
		for v, i in path {
			result[path_length - i - 1] = v
		}
		return result
	} else {
		// Unable to find path
		return nil
	}
}

path_smooth_tiles :: proc(
	path: []int,
	start: Vec2,
	end: Vec2,
	graph: NavGraph,
	tm: Tilemap,
	wall_tm: WallTilemap,
) -> []Vec2 {
	result := make([dynamic]Vec2, context.allocator)
	append(&result, start)
	// Create a line of sight check
	last_pos_added := start
	prev_pos := start
	for node_index in path {
		node_pos := graph.nodes[node_index].pos
		if !is_tile_line_walkable(last_pos_added, node_pos, tm, wall_tm) {
			append(&result, prev_pos)
			last_pos_added = prev_pos
		}
		prev_pos = node_pos
	}
	// Check the position before the end
	if !is_tile_line_walkable(last_pos_added, end, tm, wall_tm) {
		append(&result, prev_pos)
		last_pos_added = prev_pos
	}
	append(&result, end)

	return result[:]
}

is_tile_line_walkable :: proc(start: Vec2, end: Vec2, tm: Tilemap, wall_tm: WallTilemap) -> bool {
	start := start
	end := end

	if start.x > end.x { 	// Make sure the start -> end is always left to right (x increases)
		start, end = end, start
	}

	// Check if points are strictly horizontal or strictly vertical
	start_tile := world_to_tilemap(start)
	end_tile := world_to_tilemap(end)
	if start_tile == end_tile {
		return is_tile_walkable(start_tile, tm, wall_tm)
	} else if start_tile.y == end_tile.y { 	// horizontal
		if start_tile.x > end_tile.x { 	// Flip it!
			start_tile.x, end_tile.x = end_tile.x, start_tile.x
		}
		for tile_x in start_tile.x ..= end_tile.x {
			if !is_tile_walkable({tile_x, start_tile.y}, tm, wall_tm) {
				return false
			}
		}
	} else if start_tile.x == end_tile.x { 	// vertical
		if start_tile.y > end_tile.y { 	// Flip y, if one is bigger than the other
			start_tile.y, end_tile.y = end_tile.y, start_tile.y
		}
		for tile_y in start_tile.y ..= end_tile.y {
			if !is_tile_walkable({start_tile.x, tile_y}, tm, wall_tm) {
				return false
			}
		}
	} else {
		slope := (start.y - end.y) / (start.x - end.x)
		current := start
		current_tile := start_tile
		// Check first tile
		if !is_tile_walkable(current_tile, tm, wall_tm) {
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
			if !is_tile_walkable(current_tile, tm, wall_tm) {
				return false
			}
		}
	}

	return true
}

// calculate_graph :: proc(mesh: ^NavMesh) {
// 	clear(&mesh.nodes)
// 	// Create nodes and calculate centers
// 	for cell in mesh.cells {
// 		// Add new nodes to array
// 		append(
// 			&mesh.nodes,
// 			NavNode {
// 				pos = (cell.verts[0] + cell.verts[1]) / 2,
// 				verts = {cell.verts[0], cell.verts[1]},
// 			},
// 		)
// 		append(
// 			&mesh.nodes,
// 			NavNode {
// 				pos = (cell.verts[1] + cell.verts[2]) / 2,
// 				verts = {cell.verts[1], cell.verts[2]},
// 			},
// 		)
// 		append(
// 			&mesh.nodes,
// 			NavNode {
// 				pos = (cell.verts[2] + cell.verts[0]) / 2,
// 				verts = {cell.verts[2], cell.verts[0]},
// 			},
// 		)

// 		// Set connections
// 		arr_size := len(mesh.nodes)
// 		mesh.nodes[arr_size - 3].connections = {arr_size - 2, arr_size - 1, -1, -1}
// 		mesh.nodes[arr_size - 2].connections = {arr_size - 3, arr_size - 1, -1, -1}
// 		mesh.nodes[arr_size - 1].connections = {arr_size - 2, arr_size - 3, -1, -1}
// 	}

// 	// Remove duplicates, add connections
// 	for &a, ai in mesh.nodes {
// 		for bi := ai + 1; bi < len(mesh.nodes); bi += 1 {
// 			// b is the potential duplicate
// 			b := mesh.nodes[bi]
// 			// If vertices match AKA duplicate edge
// 			if (a.verts[0] == b.verts[0] && a.verts[1] == b.verts[1]) ||
// 			   (a.verts[1] == b.verts[0] && a.verts[0] == b.verts[1]) {
// 				// Copy connections
// 				a.connections[2] = b.connections[0]
// 				a.connections[3] = b.connections[1]
// 				// Reconnect connections to b, to a
// 				for &connection in mesh.nodes[b.connections[0]].connections {
// 					if connection == bi {
// 						connection = ai
// 					}
// 				}
// 				for &connection in mesh.nodes[b.connections[1]].connections {
// 					if connection == bi {
// 						connection = ai
// 					}
// 				}

// 				// Remove the duplicate (b)
// 				unordered_remove(&mesh.nodes, bi)

// 				// Change indices in reaction to unordered_remove
// 				// If the new length of the nodes array is the greater than the index that we removed, then we need to adjust indices
// 				// Otherwise, the removed index was at the end and no adjustment is needed
// 				if len(mesh.nodes) > bi {
// 					// c is the node that was at the end of the array before the unordered_remove call
// 					// Now it is at index bi, as a result of the unordered_remove call
// 					c := mesh.nodes[bi]
// 					c_prev_index := len(mesh.nodes)
// 					// Reconnect connections to c_prev_index, to bi (c's new index)
// 					for &connection in mesh.nodes[c.connections[0]].connections {
// 						if connection == c_prev_index {
// 							connection = bi
// 						}
// 					}
// 					for &connection in mesh.nodes[c.connections[1]].connections {
// 						if connection == c_prev_index {
// 							connection = bi
// 						}
// 					}
// 				}

// 				// a is fully saturated now, so we can break out of inner loop to go to next a
// 				break
// 			}
// 		}
// 	}
// }

// // TODO: Write this comment
// find_path :: proc(
// 	start: Vec2,
// 	end: Vec2,
// 	nav_mesh: NavMesh,
// 	allocator := context.allocator,
// ) -> []Vec2 {
// 	// fmt.println("######\nSearching for path\n######")
// 	// Get start and end node indices
// 	start_cell_index: int
// 	end_cell_index: int
// 	start_node_index: int
// 	end_node_index: int
// 	{
// 		// Find the starting/ending index
// 		start_cell_index = find_cell_index(start, nav_mesh)
// 		end_cell_index = find_cell_index(end, nav_mesh)

// 		// If a start or end cell weren't found exit early, returning nil
// 		if start_cell_index == -1 || end_cell_index == -1 {
// 			return nil
// 		}

// 		// If start and end are inside same cell then exit early and return a straight line path between start and end
// 		if start_cell_index == end_cell_index {
// 			path := make([]Vec2, 2, allocator)
// 			path[0] = start
// 			path[1] = end
// 			return path
// 		}

// 		start_node_index = find_closest_node_in_cell(end, start_cell_index, nav_mesh)
// 		end_node_index = find_closest_node_in_cell(start, end_cell_index, nav_mesh)

// 		// If a start node or an end node were not found then return nil
// 		if start_node_index == -1 || end_node_index == -1 {
// 			return nil
// 		}
// 	}

// 	// Get node path via A*
// 	node_path_indices := astar(
// 		start_node_index,
// 		end_node_index,
// 		nav_mesh,
// 		start_cell_index,
// 		end_cell_index,
// 	)
// 	defer delete(node_path_indices)
// 	if node_path_indices == nil {
// 		return nil
// 	}

// 	// Getting path without using funnel algo
// 	// path := make([]Vec2, len(node_path_indices) + 2, allocator)
// 	// path[0] = start
// 	// for node_index, i in node_path_indices {
// 	// 	path[i + 1] = nav_mesh.nodes[node_index].pos
// 	// }
// 	// path[len(node_path_indices) + 1] = end
// 	// return path

// 	portals := build_portals(node_path_indices, nav_mesh, start, end)
// 	// fmt.println(portals)
// 	defer delete(portals)

// 	return string_pull(portals)
// }

// // Returns a path through the portals
// string_pull :: proc(
// 	portals: []Vec2,
// 	max_iterations := -1,
// 	allocator := context.allocator,
// ) -> []Vec2 {
// 	// Indices into portals
// 	apex_index, left_index, right_index := 0, 0, 0
// 	portal_apex, portal_left, portal_right := portals[0], portals[0], portals[1]

// 	path := make([dynamic]Vec2, allocator)
// 	append(&path, portal_apex)

// 	iterations := 0
// 	// Add start point
// 	for i := 1;
// 	    i < len(portals) / 2 &&
// 	    len(path) < len(portals) / 2 &&
// 	    (max_iterations == -1 || iterations < max_iterations);
// 	    i += 1 {
// 		iterations += 1
// 		left := portals[i * 2 + 0]
// 		right := portals[i * 2 + 1]

// 		// Update right vertex
// 		if triangle_area2({portal_apex, portal_right, right}) <= 0 { 	// If the funnel will tighten
// 			if portal_apex == portal_right ||
// 			   triangle_area2({portal_apex, portal_left, right}) > 0 {
// 				// Tighten funnel
// 				portal_right = right
// 				right_index = i
// 			} else {
// 				// Right over left, insert left to path and restart scan from portal left point
// 				append(&path, portal_left)

// 				// Make current left new apex
// 				portal_apex = portal_left
// 				apex_index = left_index

// 				// Reset portal
// 				portal_right = portal_apex
// 				right_index = apex_index

// 				// Restart scan
// 				i = apex_index
// 				continue
// 			}
// 		}

// 		// Update left vertex
// 		if triangle_area2({portal_apex, portal_left, left}) >= 0 { 	// If the funnel will tighten
// 			if portal_apex == portal_left ||
// 			   triangle_area2({portal_apex, portal_right, left}) < 0 {
// 				// Tighten funnel
// 				portal_left = left
// 				left_index = i
// 			} else {
// 				// Left over right, insert right to path and restart scan from portal right point
// 				append(&path, portal_right)

// 				// Make current right new apex
// 				portal_apex = portal_right
// 				apex_index = right_index

// 				// Reset portal
// 				portal_left = portal_apex
// 				left_index = apex_index

// 				// Restart scan
// 				i = apex_index
// 				continue
// 			}
// 		}
// 	}


// 	// Add last point
// 	if len(path) < len(portals) / 2 {
// 		append(&path, portals[len(portals) - 1])
// 	}

// 	return path[:]
// }

// // Allocates result using temp allocator. In [2]Vec2, index 0 is the left and index 1 is the right node
// build_portals :: proc(path: []int, nav_mesh: NavMesh, start: Vec2, end: Vec2) -> []Vec2 {
// 	portals := make([dynamic]Vec2, context.temp_allocator)
// 	append(&portals, start)
// 	append(&portals, start)

// 	prev_node_pos := start
// 	for node_index in path {
// 		node := nav_mesh.nodes[node_index]
// 		v0 := node.verts[0]
// 		v1 := node.verts[1]

// 		// If vert 0 is to the left of vert 1 (AKA cross() > 0) when looking from the previous node, then vert 0 is the left side of the portal
// 		if cross(v0 - prev_node_pos, v1 - prev_node_pos) > 0 {
// 			append(&portals, v1)
// 			append(&portals, v0)
// 		} else {
// 			append(&portals, v0)
// 			append(&portals, v1)
// 		}
// 		prev_node_pos = node.pos
// 	}

// 	append(&portals, end)
// 	append(&portals, end)
// 	return portals[:]
// }

// // Returns slice of indices to nodes in the navmesh. Heuristic is Euclidean distance. Allocates using context.temp_allocator
// astar :: proc(
// 	start_index: int,
// 	end_index: int,
// 	nav_mesh: NavMesh,
// 	start_cell: int,
// 	end_cell: int,
// ) -> []int {
// 	// Initialize open and closed lists
// 	closed_nodes := make(map[int]int, len(nav_mesh.nodes), context.temp_allocator) // Only stores came from nodes
// 	open_nodes := make(map[int]struct {
// 			came_from: int,
// 			f:         f32,
// 			g:         f32,
// 		}, len(nav_mesh.nodes), context.temp_allocator)
// 	defer delete(closed_nodes)
// 	defer delete(open_nodes)

// 	end_node := nav_mesh.nodes[end_index]

// 	// Start f is just equal to the heuristic
// 	start_f := distance(nav_mesh.nodes[start_index].pos, nav_mesh.nodes[end_index].pos)
// 	open_nodes[start_index] = {start_index, start_f, 0}

// 	for len(open_nodes) > 0 {
// 		// fmt.printfln("******\n Open Nodes: %#v \nClosed Nodes: %#v", open_nodes, closed_nodes)
// 		// Get current index
// 		current_index := -1
// 		current_value: struct {
// 			came_from: int,
// 			f:         f32,
// 			g:         f32,
// 		}
// 		for index, value in open_nodes {
// 			if current_index == -1 {
// 				current_index = index
// 				current_value = value
// 				continue
// 			}

// 			if value.f < current_value.f {
// 				current_index = index
// 				current_value = value
// 			}
// 		}
// 		// fmt.printfln("Current Index: %v, Values: %v", current_index, current_value)
// 		delete_key(&open_nodes, current_index)
// 		closed_nodes[current_index] = current_value.came_from

// 		if current_index == end_index {
// 			break
// 		}

// 		current_node := nav_mesh.nodes[current_index]

// 		for connection in current_node.connections {
// 			if connection == -1 {
// 				break
// 			}
// 			// If in closed nodes
// 			if connection in closed_nodes {
// 				continue
// 			}

// 			connected_node := nav_mesh.nodes[connection]
// 			// Calculate G values
// 			g := current_value.g + distance(current_node.pos, connected_node.pos)

// 			// If in open nodes, compare g
// 			if value, ok := &open_nodes[connection]; ok {
// 				// If new g is less then update the old g and f value, otherwise don't
// 				if g < value.g {
// 					// fmt.printfln("Replacing %v g value", connection)
// 					// fmt.println("Replacing g value for %v from %v to %v", connection, value.g, g)
// 					value.g = g
// 					value.f -= g - value.g
// 					value.came_from = current_index
// 					continue
// 				}
// 			} else {
// 				// fmt.printfln("Adding %v to open nodes", connection)
// 				// Else calculate f = g + h (distance to end), and add node to open nodes
// 				open_nodes[connection] = {
// 					came_from = current_index,
// 					f         = g + distance(connected_node.pos, end_node.pos),
// 					g         = g,
// 				}
// 			}

// 			// fmt.println("------")
// 		}
// 	}
// 	if _, ok := closed_nodes[end_index]; ok {
// 		// Trace path backwards
// 		path := make([dynamic]int, context.temp_allocator)
// 		defer delete(path)
// 		current_index := end_index
// 		for current_index != start_index {
// 			append(&path, current_index)
// 			current_index = closed_nodes[current_index]
// 		}
// 		append(&path, start_index)

// 		// Remove extra nodes in the end cell
// 		if len(path) > 2 {
// 			n2 := nav_mesh.nodes[path[2]]
// 			n2_matches := 0
// 			n1 := nav_mesh.nodes[path[1]]
// 			n1_matches := 0
// 			// Check if 1st and 2nd index nodes are in the end cell
// 			for vc in nav_mesh.cells[end_cell].verts {
// 				for vn in n2.verts {
// 					if vn == vc {
// 						n2_matches += 1
// 					}
// 				}
// 				for vn in n1.verts {
// 					if vn == vc {
// 						n1_matches += 1
// 					}
// 				}
// 			}
// 			// If matches are 2 or more then they are in the end cell and we can remove the nodes before
// 			if n2_matches >= 2 {
// 				ordered_remove(&path, 0)
// 				ordered_remove(&path, 0)
// 			} else if n1_matches >= 2 {
// 				ordered_remove(&path, 0)
// 			}
// 		} else if len(path) > 1 {
// 			n1 := nav_mesh.nodes[path[1]]
// 			n1_matches := 0
// 			// Check if 1st index node is in the end cell
// 			for vc in nav_mesh.cells[end_cell].verts {
// 				for vn in n1.verts {
// 					if vn == vc {
// 						n1_matches += 1
// 					}
// 				}
// 			}
// 			// If matches are 2 or more then they are in the end cell and we can remove the nodes before
// 			if n1_matches >= 2 {
// 				ordered_remove(&path, 0)
// 			}
// 		}
// 		// Remove extra nodes in the start cell
// 		if len(path) > 2 {
// 			// n3tol means node 3rd to last
// 			n3tol := nav_mesh.nodes[path[len(path) - 3]]
// 			n3tol_matches := 0
// 			n2tol := nav_mesh.nodes[path[len(path) - 2]]
// 			n2tol_matches := 0
// 			// Check if 2nd to last and 3rd to last index nodes are in the start cell
// 			for vc in nav_mesh.cells[start_cell].verts {
// 				for vn in n3tol.verts {
// 					if vn == vc {
// 						n3tol_matches += 1
// 					}
// 				}
// 				for vn in n2tol.verts {
// 					if vn == vc {
// 						n2tol_matches += 1
// 					}
// 				}
// 			}
// 			// If matches are 2 or more then they are in the start cell and we can remove the nodes after
// 			if n3tol_matches >= 2 {
// 				unordered_remove(&path, len(path) - 1)
// 				unordered_remove(&path, len(path) - 1)
// 			} else if n2tol_matches >= 2 {
// 				unordered_remove(&path, len(path) - 1)
// 			}
// 		} else if len(path) > 1 {
// 			// n3tol means node 3rd to last
// 			n2tol := nav_mesh.nodes[path[len(path) - 2]]
// 			n2tol_matches := 0
// 			// Check if 2nd to last index node is in the start cell
// 			for vc in nav_mesh.cells[start_cell].verts {
// 				for vn in n2tol.verts {
// 					if vn == vc {
// 						n2tol_matches += 1
// 					}
// 				}
// 			}
// 			// If matches are 2 or more then they are in the start cell and we can remove the nodes after
// 			if n2tol_matches >= 2 {
// 				unordered_remove(&path, len(path) - 1)
// 			}
// 		}

// 		// Create slice result and copy the path values in reverse order
// 		path_length := len(path)
// 		result := make([]int, path_length, context.temp_allocator)
// 		for v, i in path {
// 			result[path_length - i - 1] = v
// 		}
// 		return result
// 	} else {
// 		// Unable to find path
// 		return nil
// 	}
// }

// find_closest_node_in_cell :: proc(point: Vec2, cell_index: int, nav_mesh: NavMesh) -> int {
// 	// Find cell, node pos, and then node index
// 	cell := nav_mesh.cells[cell_index]

// 	node_pos: Vec2
// 	// Find the starting node by getting the closest edge node to the start point
// 	for v, i in cell.verts {
// 		edge_point := (v + cell.verts[(i + 1) % 3]) / 2
// 		// If not set or this edge_point is closer than the current start_node_point
// 		if i == 0 || length_squared(point - node_pos) > length_squared(point - edge_point) {
// 			node_pos = edge_point
// 		}
// 	}

// 	// Find node with matching position and return its index
// 	for node, i in nav_mesh.nodes {
// 		if node_pos == node.pos {
// 			return i
// 		}
// 	}
// 	return -1
// }

// // Finds the cell in nav_mesh that point is in and returns the corresponding index into nav_mesh.cells
// find_cell_index :: proc(point: Vec2, nav_mesh: NavMesh) -> int {
// 	for cell, i in nav_mesh.cells {
// 		if check_collision_triangle_point(cell.verts, point) {
// 			return i
// 		}
// 	}
// 	return -1
// }
// 
// build_tile_portals :: proc(path: []int, start: Vec2, end: Vec2) -> []Vec2 {
// 	portals := make([dynamic]Vec2, context.allocator)
// 	append(&portals, start)
// 	append(&portals, start)

// 	prev_node_pos := start
// 	for node_index in path {
// 		node := graph.nodes[node_index]
// 		prev_to_midpoint := (node.pos - prev_node_pos) / 2
// 		midpoint := prev_node_pos + prev_to_midpoint

// 		v0 := midpoint + perpindicular(prev_to_midpoint)
// 		v1 := midpoint - perpindicular(prev_to_midpoint)

// 		// If vert 0 is to the left of vert 1 (AKA cross() > 0) when looking from the previous node, then vert 0 is the left side of the portal
// 		if cross(v0 - prev_node_pos, v1 - prev_node_pos) > 0 {
// 			append(&portals, v1)
// 			append(&portals, v0)
// 		} else {
// 			append(&portals, v0)
// 			append(&portals, v1)
// 		}
// 		prev_node_pos = node.pos
// 	}

// 	append(&portals, end)
// 	append(&portals, end)
// 	return portals[:]
// }
