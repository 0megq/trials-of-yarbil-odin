package game

import "core:fmt"
import "core:math"

@(private = "file")
fmt_i := fmt._arg_number


square :: proc(num: $T) -> T {
	return num * num
}

// moves the current value to the target by delta, ensures that you don't go past the target. 
// delta is expected to be a positive magnitude
move_towards :: proc(current: f32, target: f32, delta: f32) -> f32 {
	dir := math.sign(target - current)
	new := current + delta * dir

	if dir > 0 {
		return min(new, target)
	} else {
		return max(new, target)
	}
}

ease_out_back :: proc(alpha: f32, multiplier: f32 = 1.0) -> f32 {
	c1: f32 = 1.70158 * multiplier
	c3: f32 = c1 + 1.0
	return 1.0 + c3 * math.pow(alpha - 1.0, 3.0) + c1 * math.pow(alpha - 1.0, 2.0)
}

get_current_hframe :: proc(time: f32, start: f32, end: f32, total_hframes: i32) -> i32 {
	frame_index := i32(math.floor(math.remap(time, start, end, 0, f32(total_hframes))))
	if frame_index >= total_hframes {
		frame_index -= 1
	}
	return frame_index
}

get_frame_size :: proc(tex: TextureId) -> Vec2i {
	frame_count := get_frame_count(tex)
	tex := loaded_textures[tex]
	return Vec2i{tex.width / frame_count.x, tex.height / frame_count.y}
}

get_frame_region :: proc(frame: Vec2i, tex: TextureId) -> Rectangle {
	frame_size := get_frame_size(tex)
	return {
		f32(frame.x * frame_size.x),
		f32(frame.y * frame_size.y),
		f32(frame_size.x),
		f32(frame_size.y),
	}
}

// Gets the current frame and then returns the rectangular region on the texture. ONLY works for 
get_current_frame_region :: proc(
	time: f32,
	start: f32,
	end: f32,
	tex: TextureId,
	total_hframes: i32 = -1,
	vframe: i32 = 0,
) -> Rectangle {
	total_hframes := total_hframes
	if total_hframes == -1 {
		total_hframes = get_frame_count(tex).x
	}
	return get_frame_region(
		{i32(get_current_hframe(time, start, end, total_hframes)), vframe},
		tex,
	)
}
