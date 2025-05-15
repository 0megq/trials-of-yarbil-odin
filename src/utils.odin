package game

import "core:math"

square :: proc(num: $T) -> T {
	return num * num
}


ease_out_back :: proc(alpha: f32, multiplier: f32 = 1.0) -> f32 {
	c1: f32 = 1.70158 * multiplier
	c3: f32 = c1 + 1.0
	return 1.0 + c3 * math.pow(alpha - 1.0, 3.0) + c1 * math.pow(alpha - 1.0, 2.0)
}
