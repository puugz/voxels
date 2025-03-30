package main

import "core:math/noise"

octave_noise :: proc(seed: i64, coord: noise.Vec2, $octaves: int) -> (value: f32) {
	#assert(octaves > 0)

	when octaves == 1 {
		return noise.noise_2d(seed, coord)
	} else {
		freq := f64(1.0)
		scale := f32(1.0)
		for octave in 0 ..< octaves {
			value += noise.noise_2d(seed, freq * coord) * scale
			scale /= 2.0
			freq *= 2.0
		}
		return value / 2.0
	}
}

octave_noise_3d :: proc(seed: i64, coord: noise.Vec3, $octaves: int) -> (value: f32) {
	#assert(octaves > 0)

	when octaves == 1 {
		return noise.noise_3d_improve_xz(seed, coord)
	} else {
		freq := f64(1.0)
		scale := f32(1.0)
		for octave in 0 ..< octaves {
			value += noise.noise_3d_improve_xz(seed, freq * coord) * scale
			scale /= 2.0
			freq *= 2.0
		}
		return value / 2.0
	}
}
