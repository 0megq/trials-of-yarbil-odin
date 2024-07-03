package game

nav_mesh: NavMesh

// To be used in a NavMesh
NavCell :: struct {
	verts:         [3]Vec2, // Vertices that make up the cell
	adj_cells:     [3]int, // Index to adjacent cells in NavMesh
	num_adj_cells: int,
}

NavMesh :: struct {
	cells: [dynamic]NavCell,
}

// Finds all adjacent triangle cells. Sets adj_cells and num_adj_cells for all cells in the nav mesh
reconnect_cells :: proc(mesh: NavMesh) {
	// Disconnect cells
	for &cell in mesh.cells {
		cell.adj_cells = {-1, -1, -1}
		cell.num_adj_cells = 0
	}

	// Reconnect cells
	for &main_cell, main_index in mesh.cells {
		if main_cell.num_adj_cells == 3 {
			continue
		}

		for other_index := main_index + 1; other_index < len(mesh.cells); other_index += 1 {
			other_cell := &mesh.cells[other_index]
			if other_cell.num_adj_cells < 3 && are_connected(main_cell, other_cell^) {
				main_cell.adj_cells[main_cell.num_adj_cells] = other_index
				other_cell.adj_cells[other_cell.num_adj_cells] = main_index
				main_cell.num_adj_cells += 1
				other_cell.num_adj_cells += 1
			}

			if main_cell.num_adj_cells == 3 {
				break
			}
		}
	}
}

// Returns true if the two cells have two vertices that match (sharing an edge)
are_connected :: proc(a: NavCell, b: NavCell) -> bool {
	matches := 0
	outer: for va in a.verts {
		for vb in b.verts {
			if vb == va {
				matches += 1
				continue outer
			}
		}
	}
	return matches >= 2
}
