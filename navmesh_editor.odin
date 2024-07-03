package game

nav_mesh: NavMesh

// load_navmesh_editor_points :: proc() {

// }

// save_navmesh_editor_points :: proc() {

// }

// unload_navmesh_editor_points :: proc() {

// }

init_navmesh_editor :: proc() {
	nav_mesh.cells = make([dynamic]NavCell, context.allocator)
}

deinit_navmesh_editor :: proc() {
	delete(nav_mesh.cells)
	nav_mesh.cells = nil
}

update_navmesh_editor :: proc() {
	// Features
	// Move point (pick closest to mouse within certain radius). Enable snap by pressing shift (Snap to grid and other points)
	// Move connected points together (Hold ctrl)
	// New triangle (N)
	// Select triangle (T)
	// Move entire triangle (drag when selected)
	// Select points only in triangle/cell (P when selected)
	// Delete triangle (ctrl D when selected)
	// Pan (middle mouse + drag)
	// Zoom (scroll wheel)
}

draw_navmesh_editor :: proc() {
	// Draw individual cells in navmesh. Draw points, edges, and fill cells
	// Display mouse coordinates
	// Draw selected triangle if selected
	// Enlarge points the mouse is near
}
