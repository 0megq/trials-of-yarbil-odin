package game


// To be used in a NavMesh
NavCell :: struct {
	verts:         [3]Vec2, // Vertices that make up the cell
	adj_cells:     [3]int, // Index to adjacent cells in NavMesh
	num_adj_cells: int,
}

NavMesh :: struct {
	cells: [dynamic]NavCell,
}
