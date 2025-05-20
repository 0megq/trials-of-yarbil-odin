package game

import "core:math"
import "core:slice"

NavGraphNode :: struct {
	pos:         Vec2,
	connections: [4]int,
}

NavGraph :: struct {
	nodes: [dynamic]NavGraphNode,
}

calculate_graph_from_tiles :: proc(graph: ^NavGraph, tm: Tilemap, wall_tm: WallTilemap) {
	if graph.nodes == nil {
		graph.nodes = make([dynamic]NavGraphNode)
	} else {
		clear(&graph.nodes)
	}
	for x in 0 ..< TILEMAP_SIZE {
		for y in 0 ..< TILEMAP_SIZE {
			if is_tile_walkable(tm, wall_tm, {i32(x), i32(y)}) {
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

// Allocates result using context.allocator
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

// Allocates result using context.allocator
path_smooth_tiles :: proc(
	path: []int,
	start: Vec2,
	end: Vec2,
	graph: NavGraph,
	tm: Tilemap,
	wall_tm: WallTilemap,
) -> []Vec2 {
	result := make([dynamic]Vec2, context.allocator)
	defer delete(result)
	append(&result, start)
	// Create a line of sight check
	last_pos_added := start
	prev_pos := start
	for node_index in path {
		node_pos := graph.nodes[node_index].pos
		if !is_tile_line_walkable(tm, wall_tm, last_pos_added, node_pos) {
			append(&result, prev_pos)
			last_pos_added = prev_pos
		}
		prev_pos = node_pos
	}
	// Check the position before the end
	if !is_tile_line_walkable(tm, wall_tm, last_pos_added, end) {
		append(&result, prev_pos)
		last_pos_added = prev_pos
	}
	append(&result, end)

	return slice.clone(result[:])
}
