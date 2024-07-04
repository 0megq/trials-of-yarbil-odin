package game

nav_mesh: NavMesh

// To be used in a NavMesh
NavCell :: struct {
	verts: [3]Vec2, // Vertices that make up the cell
}

// Stores connections to other nodes and the cell it is a part of
NavNode :: struct {
	using pos:        Vec2,
	connections:      [3]int, // Stores indices into the nodes field of NavMesh
	num_connections:  int,
	connection_edges: [3][2]Vec2, // Stores corresponding edges (portals) to the indices in connections field...
	// First index of [2]Vec2 is the left point and second index is the right
}

NavMesh :: struct {
	cells: [dynamic]NavCell,
	nodes: [dynamic]NavNode,
}

calculate_graph :: proc(mesh: ^NavMesh) {
	clear(&mesh.nodes)
	// Create nodes and calculate centers
	for cell in mesh.cells {
		node: NavNode
		// Calculate position of node (center of cell, which is the average of cells vertices)
		node.pos = (cell.verts[0] + cell.verts[1] + cell.verts[2]) / 3
		node.connections = {-1, -1, -1}
		append(&mesh.nodes, node)
	}

	// Find connections and connection edges
	for main_cell, i in mesh.cells {
		main_node := &mesh.nodes[i]
		for j := i + 1; j < len(mesh.cells); j += 1 {
			other_cell := mesh.cells[j]
			other_node := &mesh.nodes[j]

			if main_node.num_connections == 3 { 	// If all connections already set
				break
			}

			if other_node.num_connections == 3 { 	// If all connections already set
				continue
			}

			// Get matching vertices
			matching_verts: [dynamic]Vec2 = make([dynamic]Vec2, context.temp_allocator)
			defer delete(matching_verts)

			outer: for vc in main_cell.verts {
				for vo in other_cell.verts {
					if vo == vc {
						append(&matching_verts, vc)
						continue outer
					}
				}
			}

			// If there are 2 matching vertices then there is a connection
			if len(matching_verts) == 2 {
				main_node.connections[main_node.num_connections] = j // Copy index of other
				other_node.connections[other_node.num_connections] = i // Copy index of main
				main_node.num_connections += 1
				other_node.num_connections += 1
				// Storing the connection edges in proper order (left and right)
				{
					to_other := other_node.pos - main_node.pos
					to_v0 := matching_verts[0] - main_node.pos
					// Known bug: it is possible that both vertices are on one side of to_other in certain cases
					// This could be fixed by using edges instead of centers for our node positions
					// This means the connection on the graph could go through somewhere that isn't part of the navmesh
					// This is undefined behavior
					if cross(to_other, to_v0) > 0 { 	// If v0 is to the right of the connection from main to other
						// Flip the values at index 0 and 1 so that index 0 stores the vertice to the left of main when looking at other
						matching_verts[0], matching_verts[1] = matching_verts[1], matching_verts[0]
					}
					main_node.connection_edges[0] = matching_verts[0] // Store leftside point of main
					main_node.connection_edges[1] = matching_verts[1] // Store rightside point of main
					other_node.connection_edges[0] = matching_verts[1] // Store leftside point of other
					other_node.connection_edges[1] = matching_verts[0] // Store rightside point of other
				}
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
