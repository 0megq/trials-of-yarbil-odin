package game

import "core:fmt"
import "core:math"

@(private = "file")
fmt_i := fmt._arg_number


square :: proc(num: $T) -> T {
	return num * num
}


ease_out_back :: proc(alpha: f32, multiplier: f32 = 1.0) -> f32 {
	c1: f32 = 1.70158 * multiplier
	c3: f32 = c1 + 1.0
	return 1.0 + c3 * math.pow(alpha - 1.0, 3.0) + c1 * math.pow(alpha - 1.0, 2.0)
}

get_current_frame :: proc(time: f32, start: f32, end: f32, tex: TextureId) -> int {
	frame_count := get_frame_count(tex)
	frame_index := int(math.floor(math.remap(time, start, end, 0, f32(frame_count))))
	if frame_index >= frame_count {
		frame_index -= 1
	}
	return frame_index
}

get_frame_region :: proc(frame: int, tex: TextureId) -> Rectangle {
	frame_count := get_frame_count(tex)
	tex := loaded_textures[tex]
	frame_size := tex.width / i32(frame_count)
	return {f32(frame) * f32(frame_size), 0, f32(frame_size), f32(tex.height)}
}

// Gets the current frame and then returns the rectangular region on the texture.
get_current_frame_region :: proc(time: f32, start: f32, end: f32, tex: TextureId) -> Rectangle {
	return get_frame_region(get_current_frame(time, start, end, tex), tex)
}
