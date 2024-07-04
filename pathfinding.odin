package game

nav_mesh: NavMesh

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

// Allocates using temp allocator
find_path :: proc(start: Vec2, end: Vec2, nav_mesh: NavMesh) -> []Vec2 {
	// start_index := find_cell_index(start, nav_mesh)
	// end_index := find_cell_index(end, nav_mesh)
	return nil
}

// Returns indices to nodes in the navmesh
astar :: proc() -> []int {
	return nil
}

// Edges make g(x) just as easy, and allow funnel algo to work easily
// 
// g(x)
// h(x)

// Finds the cell in nav_mesh that point is in and returns the corresponding index into nav_mesh.cells
find_cell_index :: proc(point: Vec2, nav_mesh: NavMesh) -> int {
	for cell, i in nav_mesh.cells {
		if check_collision_triangle_point(cell.verts, point) {
			return i
		}
	}
	return -1
}
