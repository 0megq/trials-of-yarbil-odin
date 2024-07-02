package game


NavMesh :: struct {}
// slice of Vec2 representing concave polygon
// slice of slice of indices into concave polygon. each slice of indices represents a convex polygon
// this is used for making sure we dont got outside the nav mesh. used later for the funnel algo
// slice of dynamic array of indices. this slice is indexed by the vertex indices
// this is used for A* to find a path from the start to end
