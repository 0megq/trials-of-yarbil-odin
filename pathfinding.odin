package game

// import "core:fmt"

game_nav_mesh: NavMesh

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
	start_node_index: int
	end_node_index: int
	{
		// Find the starting/ending index
		start_index := find_cell_index(start, nav_mesh)
		end_index := find_cell_index(end, nav_mesh)

		// If a start or end cell weren't found exit early, returning nil
		if start_index == -1 || end_index == -1 {
			return nil
		}

		// If start and end are inside same cell then exit early and return a straight line path between start and end
		if start_index == end_index {
			path := make([]Vec2, 2, allocator)
			path[0] = start
			path[1] = end
			return path
		}

		start_node_index = find_closest_node_in_cell((end + start) / 2, start_index, nav_mesh)
		end_node_index = find_closest_node_in_cell((end + start) / 2, end_index, nav_mesh)

		// If a start node or an end node were not found then return nil
		if start_node_index == -1 || end_node_index == -1 {
			return nil
		}
	}

	// Get node path via A*
	node_path_indices := astar(start_node_index, end_node_index, nav_mesh)
	if node_path_indices == nil {
		return nil
	}

	// Temporary solution not using funnel algo
	path := make([]Vec2, len(node_path_indices) + 2, allocator)
	path[0] = start
	for node_index, i in node_path_indices {
		path[i + 1] = nav_mesh.nodes[node_index].pos
	}
	path[len(node_path_indices) + 1] = end
	return path


	// return nil
}

// Returns slice of indices to nodes in the navmesh. Heuristic is Euclidean distance. Allocates using context.temp_allocator
astar :: proc(start_index: int, end_index: int, nav_mesh: NavMesh) -> []int {
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

			node := nav_mesh.nodes[connection]
			// Calculate G values
			g := current_value.g + distance(current_node.pos, node.pos)

			// If in open nodes, compare g
			if value, ok := &open_nodes[connection]; ok {
				// If new g is less then update the old g and f value, otherwise don't
				if g < value.g {
					// fmt.println("Replacing g value for %v from %v to %v", connection, value.g, g)
					value.g = g
					value.f -= g - value.g
					value.came_from = current_index
					continue
				}
			}

			// fmt.printfln("Adding %v to open nodes", connection)
			// Else calculate f = g + h (distance to end), and add node to open nodes
			open_nodes[connection] = {
				came_from = current_index,
				f         = g + distance(node.pos, end_node.pos),
				g         = g,
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
