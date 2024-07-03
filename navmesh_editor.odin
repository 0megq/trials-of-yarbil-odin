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

}

draw_navmesh_editor :: proc() {

}
