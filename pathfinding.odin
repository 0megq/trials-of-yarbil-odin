package game

import "core:fmt"

// To be used in a NavMesh
NavCell :: struct {
	verts: [3]Vec2, // Vertices that make up the cell
}

// Stores connections to other nodes
NavNode :: struct {
	pos:         Vec2, // Average of both vertices is the position of the node
	verts:       [2]Vec2, // These are the two vertices of the edge
	connections: [4]int, // Stores indices to connected nodes
}

NavMesh :: struct {
	cells: [dynamic]NavCell,
	nodes: [dynamic]NavNode,
}

// NavGraphConnection :: struct {

// }

// // needed: tile pos, up down left or right.
// // useful: world pos, world pos connecting tiles and edges, which connections exist
// NavGraphNode :: struct {
// 	pos: Vec2,
// 	connections: [4]
// }

// NavGraph :: struct {
// 	nodes: [dynamic]NavNode,
// }

calculate_graph :: proc(mesh: ^NavMesh) {
	clear(&mesh.nodes)
	// Create nodes and calculate centers
	for cell in mesh.cells {
		// Add new nodes to array
		append(
			&mesh.nodes,
			NavNode {
				pos = (cell.verts[0] + cell.verts[1]) / 2,
				verts = {cell.verts[0], cell.verts[1]},
			},
		)
		append(
			&mesh.nodes,
			NavNode {
				pos = (cell.verts[1] + cell.verts[2]) / 2,
				verts = {cell.verts[1], cell.verts[2]},
			},
		)
		append(
			&mesh.nodes,
			NavNode {
				pos = (cell.verts[2] + cell.verts[0]) / 2,
				verts = {cell.verts[2], cell.verts[0]},
			},
		)

		// Set connections
		arr_size := len(mesh.nodes)
		mesh.nodes[arr_size - 3].connections = {arr_size - 2, arr_size - 1, -1, -1}
		mesh.nodes[arr_size - 2].connections = {arr_size - 3, arr_size - 1, -1, -1}
		mesh.nodes[arr_size - 1].connections = {arr_size - 2, arr_size - 3, -1, -1}
	}

	// Remove duplicates, add connections
	for &a, ai in mesh.nodes {
		for bi := ai + 1; bi < len(mesh.nodes); bi += 1 {
			// b is the potential duplicate
			b := mesh.nodes[bi]
			// If vertices match AKA duplicate edge
			if (a.verts[0] == b.verts[0] && a.verts[1] == b.verts[1]) ||
			   (a.verts[1] == b.verts[0] && a.verts[0] == b.verts[1]) {
				// Copy connections
				a.connections[2] = b.connections[0]
				a.connections[3] = b.connections[1]
				// Reconnect connections to b, to a
				for &connection in mesh.nodes[b.connections[0]].connections {
					if connection == bi {
						connection = ai
					}
				}
				for &connection in mesh.nodes[b.connections[1]].connections {
					if connection == bi {
						connection = ai
					}
				}

				// Remove the duplicate (b)
				unordered_remove(&mesh.nodes, bi)

				// Change indices in reaction to unordered_remove
				// If the new length of the nodes array is the greater than the index that we removed, then we need to adjust indices
				// Otherwise, the removed index was at the end and no adjustment is needed
				if len(mesh.nodes) > bi {
					// c is the node that was at the end of the array before the unordered_remove call
					// Now it is at index bi, as a result of the unordered_remove call
					c := mesh.nodes[bi]
					c_prev_index := len(mesh.nodes)
					// Reconnect connections to c_prev_index, to bi (c's new index)
					for &connection in mesh.nodes[c.connections[0]].connections {
						if connection == c_prev_index {
							connection = bi
						}
					}
					for &connection in mesh.nodes[c.connections[1]].connections {
						if connection == c_prev_index {
							connection = bi
						}
					}
				}

				// a is fully saturated now, so we can break out of inner loop to go to next a
				break
			}
		}
	}
}

// TODO: Write this comment
find_path :: proc(
	start: Vec2,
	end: Vec2,
	nav_mesh: NavMesh,
	allocator := context.allocator,
) -> []Vec2 {
	// fmt.println("######\nSearching for path\n######")
	// Get start and end node indices
	start_cell_index: int
	end_cell_index: int
	start_node_index: int
	end_node_index: int
	{
		// Find the starting/ending index
		start_cell_index = find_cell_index(start, nav_mesh)
		end_cell_index = find_cell_index(end, nav_mesh)

		// If a start or end cell weren't found exit early, returning nil
		if start_cell_index == -1 || end_cell_index == -1 {
			return nil
		}

		// If start and end are inside same cell then exit early and return a straight line path between start and end
		if start_cell_index == end_cell_index {
			path := make([]Vec2, 2, allocator)
			path[0] = start
			path[1] = end
			return path
		}

		start_node_index = find_closest_node_in_cell(end, start_cell_index, nav_mesh)
		end_node_index = find_closest_node_in_cell(start, end_cell_index, nav_mesh)

		// If a start node or an end node were not found then return nil
		if start_node_index == -1 || end_node_index == -1 {
			return nil
		}
	}

	// Get node path via A*
	node_path_indices := astar(
		start_node_index,
		end_node_index,
		nav_mesh,
		start_cell_index,
		end_cell_index,
	)
	defer delete(node_path_indices)
	if node_path_indices == nil {
		return nil
	}

	// Getting path without using funnel algo
	// path := make([]Vec2, len(node_path_indices) + 2, allocator)
	// path[0] = start
	// for node_index, i in node_path_indices {
	// 	path[i + 1] = nav_mesh.nodes[node_index].pos
	// }
	// path[len(node_path_indices) + 1] = end
	// return path

	portals := build_portals(node_path_indices, nav_mesh, start, end)
	// fmt.println(portals)
	defer delete(portals)

	return string_pull(portals)
}

// Returns a path through the portals
string_pull :: proc(
	portals: []Vec2,
	max_iterations := -1,
	allocator := context.allocator,
) -> []Vec2 {
	// Indices into portals
	apex_index, left_index, right_index := 0, 0, 0
	portal_apex, portal_left, portal_right := portals[0], portals[0], portals[1]

	path := make([dynamic]Vec2, allocator)
	append(&path, portal_apex)

	iterations := 0
	// Add start point
	for i := 1;
	    i < len(portals) / 2 &&
	    len(path) < len(portals) / 2 &&
	    (max_iterations == -1 || iterations < max_iterations);
	    i += 1 {
		iterations += 1
		left := portals[i * 2 + 0]
		right := portals[i * 2 + 1]

		// Update right vertex
		if triangle_area2({portal_apex, portal_right, right}) <= 0 { 	// If the funnel will tighten
			if portal_apex == portal_right ||
			   triangle_area2({portal_apex, portal_left, right}) > 0 {
				// Tighten funnel
				portal_right = right
				right_index = i
			} else {
				// Right over left, insert left to path and restart scan from portal left point
				append(&path, portal_left)

				// Make current left new apex
				portal_apex = portal_left
				apex_index = left_index

				// Reset portal
				portal_right = portal_apex
				right_index = apex_index

				// Restart scan
				i = apex_index
				continue
			}
		}

		// Update left vertex
		if triangle_area2({portal_apex, portal_left, left}) >= 0 { 	// If the funnel will tighten
			if portal_apex == portal_left ||
			   triangle_area2({portal_apex, portal_right, left}) < 0 {
				// Tighten funnel
				portal_left = left
				left_index = i
			} else {
				// Left over right, insert right to path and restart scan from portal right point
				append(&path, portal_right)

				// Make current right new apex
				portal_apex = portal_right
				apex_index = right_index

				// Reset portal
				portal_left = portal_apex
				left_index = apex_index

				// Restart scan
				i = apex_index
				continue
			}
		}
	}


	// Add last point
	if len(path) < len(portals) / 2 {
		append(&path, portals[len(portals) - 1])
	}

	return path[:]
}

// Allocates result using temp allocator. In [2]Vec2, index 0 is the left and index 1 is the right node
build_portals :: proc(path: []int, nav_mesh: NavMesh, start: Vec2, end: Vec2) -> []Vec2 {
	portals := make([dynamic]Vec2, context.temp_allocator)
	append(&portals, start)
	append(&portals, start)

	prev_node_pos := start
	for node_index in path {
		node := nav_mesh.nodes[node_index]
		v0 := node.verts[0]
		v1 := node.verts[1]

		// If vert 0 is to the left of vert 1 (AKA cross() > 0) when looking from the previous node, then vert 0 is the left side of the portal
		if cross(v0 - prev_node_pos, v1 - prev_node_pos) > 0 {
			append(&portals, v1)
			append(&portals, v0)
		} else {
			append(&portals, v0)
			append(&portals, v1)
		}
		prev_node_pos = node.pos
	}

	append(&portals, end)
	append(&portals, end)
	return portals[:]
}

// Returns slice of indices to nodes in the navmesh. Heuristic is Euclidean distance. Allocates using context.temp_allocator
astar :: proc(
	start_index: int,
	end_index: int,
	nav_mesh: NavMesh,
	start_cell: int,
	end_cell: int,
) -> []int {
	// Initialize open and closed lists
	closed_nodes := make(map[int]int, len(nav_mesh.nodes), context.temp_allocator) // Only stores came from nodes
	open_nodes := make(map[int]struct {
			came_from: int,
			f:         f32,
			g:         f32,
		}, len(nav_mesh.nodes), context.temp_allocator)
	defer delete(closed_nodes)
	defer delete(open_nodes)

	end_node := nav_mesh.nodes[end_index]

	// Start f is just equal to the heuristic
	start_f := distance(nav_mesh.nodes[start_index].pos, nav_mesh.nodes[end_index].pos)
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

		current_node := nav_mesh.nodes[current_index]

		for connection in current_node.connections {
			if connection == -1 {
				break
			}
			// If in closed nodes
			if connection in closed_nodes {
				continue
			}

			connected_node := nav_mesh.nodes[connection]
			// Calculate G values
			g := current_value.g + distance(current_node.pos, connected_node.pos)

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

		// Remove extra nodes in the end cell
		if len(path) > 2 {
			n2 := nav_mesh.nodes[path[2]]
			n2_matches := 0
			n1 := nav_mesh.nodes[path[1]]
			n1_matches := 0
			// Check if 1st and 2nd index nodes are in the end cell
			for vc in nav_mesh.cells[end_cell].verts {
				for vn in n2.verts {
					if vn == vc {
						n2_matches += 1
					}
				}
				for vn in n1.verts {
					if vn == vc {
						n1_matches += 1
					}
				}
			}
			// If matches are 2 or more then they are in the end cell and we can remove the nodes before
			if n2_matches >= 2 {
				ordered_remove(&path, 0)
				ordered_remove(&path, 0)
			} else if n1_matches >= 2 {
				ordered_remove(&path, 0)
			}
		} else if len(path) > 1 {
			n1 := nav_mesh.nodes[path[1]]
			n1_matches := 0
			// Check if 1st index node is in the end cell
			for vc in nav_mesh.cells[end_cell].verts {
				for vn in n1.verts {
					if vn == vc {
						n1_matches += 1
					}
				}
			}
			// If matches are 2 or more then they are in the end cell and we can remove the nodes before
			if n1_matches >= 2 {
				ordered_remove(&path, 0)
			}
		}
		// Remove extra nodes in the start cell
		if len(path) > 2 {
			// n3tol means node 3rd to last
			n3tol := nav_mesh.nodes[path[len(path) - 3]]
			n3tol_matches := 0
			n2tol := nav_mesh.nodes[path[len(path) - 2]]
			n2tol_matches := 0
			// Check if 2nd to last and 3rd to last index nodes are in the start cell
			for vc in nav_mesh.cells[start_cell].verts {
				for vn in n3tol.verts {
					if vn == vc {
						n3tol_matches += 1
					}
				}
				for vn in n2tol.verts {
					if vn == vc {
						n2tol_matches += 1
					}
				}
			}
			// If matches are 2 or more then they are in the start cell and we can remove the nodes after
			if n3tol_matches >= 2 {
				unordered_remove(&path, len(path) - 1)
				unordered_remove(&path, len(path) - 1)
			} else if n2tol_matches >= 2 {
				unordered_remove(&path, len(path) - 1)
			}
		} else if len(path) > 1 {
			// n3tol means node 3rd to last
			n2tol := nav_mesh.nodes[path[len(path) - 2]]
			n2tol_matches := 0
			// Check if 2nd to last index node is in the start cell
			for vc in nav_mesh.cells[start_cell].verts {
				for vn in n2tol.verts {
					if vn == vc {
						n2tol_matches += 1
					}
				}
			}
			// If matches are 2 or more then they are in the start cell and we can remove the nodes after
			if n2tol_matches >= 2 {
				unordered_remove(&path, len(path) - 1)
			}
		}

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

find_closest_node_in_cell :: proc(point: Vec2, cell_index: int, nav_mesh: NavMesh) -> int {
	// Find cell, node pos, and then node index
	cell := nav_mesh.cells[cell_index]

	node_pos: Vec2
	// Find the starting node by getting the closest edge node to the start point
	for v, i in cell.verts {
		edge_point := (v + cell.verts[(i + 1) % 3]) / 2
		// If not set or this edge_point is closer than the current start_node_point
		if i == 0 || length_squared(point - node_pos) > length_squared(point - edge_point) {
			node_pos = edge_point
		}
	}

	// Find node with matching position and return its index
	for node, i in nav_mesh.nodes {
		if node_pos == node.pos {
			return i
		}
	}
	return -1
}

// Finds the cell in nav_mesh that point is in and returns the corresponding index into nav_mesh.cells
find_cell_index :: proc(point: Vec2, nav_mesh: NavMesh) -> int {
	for cell, i in nav_mesh.cells {
		if check_collision_triangle_point(cell.verts, point) {
			return i
		}
	}
	return -1
}

find_path_tiles :: proc(
	start: Vec2,
	end: Vec2,
	tm: Tilemap,
	allocator := context.allocator,
) -> []Vec2 {
	// fmt.println("######\nSearching for path\n######")
	// Get start and end node indices
	start_tile: Vec2i
	end_tile: Vec2i
	{
		start_tile = world_to_tilemap(start)
		end_tile = world_to_tilemap(end)

		// If start and end are inside same cell then exit early and return a straight line path between start and end
		if start_tile == end_tile {
			path := make([]Vec2, 2, allocator)
			path[0] = start
			path[1] = end
			return path
		}

		// If start or end tile are out of bounds then return nil
		if !is_valid_tile_pos(start_tile) || !is_valid_tile_pos(end_tile) {
			return nil
		}
	}

	fmt.println("got to astar")
	// Get node path via A*
	tile_path := astar_tiles(start_tile, end_tile, tm)
	defer delete(tile_path)
	if tile_path == nil {
		return nil
	}
	fmt.println("past to astar")

	// Getting path without using funnel algo
	path := make([]Vec2, len(tile_path) + 2, allocator)
	path[0] = start
	for tile, i in tile_path {
		// Add tile center (that's why we add TILE_SIZE / 2)
		path[i + 1] = tilemap_to_world(tile) + TILE_SIZE / 2
	}
	path[len(tile_path) + 1] = end
	return path

	// portals := build_portals(node_path_indices, nav_mesh, start, end)
	// // fmt.println(portals)
	// defer delete(portals)

	// return string_pull(portals)
}

astar_tiles :: proc(start_tile: Vec2i, end_tile: Vec2i, tm: Tilemap) -> []Vec2i {
	// Initialize open and closed lists
	closed_tiles := make(map[Vec2i]Vec2i, len(nav_mesh.nodes), context.temp_allocator) // Only stores came from nodes
	open_tiles := make(map[Vec2i]struct {
			came_from: Vec2i,
			f:         f32,
			g:         f32,
		}, len(nav_mesh.nodes), context.temp_allocator)
	defer delete(closed_tiles)
	defer delete(open_tiles)

	// Start f is just equal to the heuristic
	start_f := distance_i(start_tile, end_tile)
	open_tiles[start_tile] = {start_tile, start_f, 0}

	fmt.println("starting loop")
	for len(open_tiles) > 0 {
		fmt.printfln("******\n Open Tiles: %#v \nClosed Tiles: %#v", open_tiles, closed_tiles)
		// Get current tile
		current_tile: Vec2i = {-1, -1} // Note: {-1, -1} is not a valid tile pos so it's okay to use it here as a nil value
		current_value: struct {
			came_from: Vec2i,
			f:         f32,
			g:         f32,
		}
		for tile, value in open_tiles {
			// set current_tile if nil
			if current_tile == {-1, -1} {
				current_tile = tile
				current_value = value
				continue
			}

			// set current_tile if cost is less than current cost
			if value.f < current_value.f {
				current_tile = tile
				current_value = value
			}
		}
		fmt.printfln("Current Tile: %v, Values: %v", current_tile, current_value)
		// Delete current tile from open tiles since we are about to fully explore it. Also add it to closed tiles.
		delete_key(&open_tiles, current_tile)
		closed_tiles[current_tile] = current_value.came_from

		// If current tile is equal to end tile then we are done
		// Note: current tile can only equal end tile when end tile has the lowest cost out of all other open tiles
		if current_tile == end_tile {
			break
		}

		for direction in DIRECTIONS_I {
			connected_tile := current_tile + direction
			if !is_valid_tile_pos(connected_tile) ||
			   !is_tile_walkable(connected_tile, tm) ||
			   connected_tile in closed_tiles {
				continue
			}

			// Calculate G values. Take current g and add 1. Distance between two tiles is always 1.
			g := current_value.g + 1

			// If in open tiles, compare g
			if value, ok := &open_tiles[connected_tile]; ok {
				// If new g is less, then update the old g and f value, otherwise don't
				if g < value.g {
					fmt.printfln("Replacing %v g value", connected_tile)
					fmt.println(
						"Replacing g value for %v from %v to %v",
						connected_tile,
						value.g,
						g,
					)
					value.g = g
					// Take away difference in new g and old g
					value.f -= g - value.g
					value.came_from = current_tile
					continue
				}
			} else {
				fmt.printfln("Adding %v to open nodes", connected_tile)
				// Else calculate f = g + h (distance to end), and add node to open nodes
				open_tiles[connected_tile] = {
					came_from = current_tile,
					f         = g + distance_i(connected_tile, end_tile),
					g         = g,
				}
			}

			fmt.println("------")
		}
	}
	fmt.println("got out of loop")

	// If end tile is in the closed tiles then tr
	if _, ok := closed_tiles[end_tile]; ok {
		// Trace path backwards, until start node is found
		path := make([dynamic]Vec2i, context.temp_allocator)
		defer delete(path)
		current_tile := end_tile
		for current_tile != start_tile {
			append(&path, current_tile)
			current_tile = closed_tiles[current_tile] // Set current tile to the tile it came from
		}
		// add the start tile to the path
		append(&path, start_tile)

		// Create slice, result and copy the path values in reverse order
		path_length := len(path)
		result := make([]Vec2i, path_length, context.temp_allocator)
		for v, i in path {
			result[path_length - i - 1] = v
		}
		return result
	}
	// Unable to find path
	return nil
}
