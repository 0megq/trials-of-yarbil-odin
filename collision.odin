package game

import "core:fmt"
import "core:math"

check_collision_polygons :: proc(a: []Vec2, b: []Vec2) -> bool {
	p1 := a
	p2 := b
	for i in 0 ..< 2 {
		if i == 1 {
			p2 = a
			p1 = b
		}
		// fmt.printfln("p1 %v, p2: %v", p1, p2)
		fmt.printfln("hello")
		for index in 0 ..< len(p1) {
			// Get perpindicular vector (axes) to normal
			edge := p1[index] - p1[(index + 1) %% len(p1)]
			normal := edge.yx * {-1, 1}
			fmt.printfln(
				"p1[index]: %v, p1[index+1]: %v, edge: %v, normal: %v",
				p1[index],
				p1[(index + 1) %% len(p1)],
				edge,
				normal,
			)
			// Project p1 onto axes and get min and max
			p1_min: f32 = math.F32_MAX
			p1_max: f32 = -math.F32_MIN
			for v in p1 {
				dot := dot(v, normal)
				p1_min = min(p1_min, dot)
				p1_max = max(p1_max, dot)
			}
			p2_min: f32 = math.F32_MAX
			p2_max: f32 = -math.F32_MIN
			for v in p2 {
				dot := dot(v, normal)
				p2_min = min(p2_min, dot)
				p2_max = max(p2_max, dot)
			}
			if p1_max < p2_min || p2_max < p1_min {
				fmt.printfln("yooo")
				return false
			}
		}
	}

	return true
}
