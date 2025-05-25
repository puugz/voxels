package main

import "core:log"
import "core:math"
import "core:math/linalg"
import sdl "vendor:sdl3"

MOVE_SPEED       :: 30
LOOK_SENSITIVITY :: 0.1

Camera :: struct {
  using position: vec3,
  direction:      vec3,
  yaw, pitch:     f32,
}

init_camera :: proc(camera: ^Camera) {
  _ = sdl.SetWindowRelativeMouseMode(g_mem.window, g_mem.mouse_locked)

  spawn_x := f32(WORLD_WIDTH * CHUNK_WIDTH) * 0.5
  spawn_y := f32(WORLD_HEIGHT * CHUNK_WIDTH)
  spawn_z := f32(WORLD_LENGTH * CHUNK_LENGTH) * 0.5
  camera.position = {spawn_x, spawn_y, spawn_z}
}

update_camera :: proc(camera: ^Camera) {
  move_input: vec2
  if key_down(.W) do move_input.y += 1
  if key_down(.S) do move_input.y -= 1
  if key_down(.D) do move_input.x += 1
  if key_down(.A) do move_input.x -= 1

  move_input  = linalg.normalize0(move_input)
  look_input := g_mem.mouse_delta * LOOK_SENSITIVITY if g_mem.mouse_locked else {}

  camera.yaw   = math.wrap(camera.yaw - look_input.x, 360)
  camera.pitch = math.clamp(camera.pitch - look_input.y, -89.9, 89.9)

  look_mat := linalg.matrix3_from_yaw_pitch_roll(linalg.to_radians(camera.yaw), linalg.to_radians(camera.pitch), 0)

  forward  := look_mat * WORLD_FORWARD
  right    := look_mat * WORLD_RIGHT
  move_dir := forward * move_input.y + right * move_input.x

  speed_multiplier := f32(1)
  if key_down(.SPACE)  do move_dir += WORLD_UP
  if key_down(.LSHIFT) do move_dir -= WORLD_UP
  if key_down(.LCTRL)  do speed_multiplier = 2

  motion := move_dir * MOVE_SPEED * speed_multiplier * g_mem.delta_time

  camera.position += motion
  camera.direction = forward
}

view_matrix :: #force_inline proc(camera: ^Camera) -> mat4 {
  return linalg.matrix4_look_at_f32(camera.position, camera.position + camera.direction, WORLD_UP)
}

raycast :: proc(camera: ^Camera, max_distance: f32 = 100.0) -> (hit: bool, pos, normal: vec3) {
  origin    := camera.position
  direction := linalg.normalize(camera.direction)

  // init ray
  current_pos := origin
  step        := linalg.sign(direction)

  // calculate delta and max
  delta := vec3{
    direction.x != 0 ? math.abs(1.0 / direction.x) : f32(math.F32_MAX),
    direction.y != 0 ? math.abs(1.0 / direction.y) : f32(math.F32_MAX),
    direction.z != 0 ? math.abs(1.0 / direction.z) : f32(math.F32_MAX),
  }

  // calculate initial side distances
  current_block := vec3{
    math.floor(current_pos.x),
    math.floor(current_pos.y),
    math.floor(current_pos.z),
  }

  side_dist: vec3
  for i in 0 ..< 3 {
    if direction[i] > 0 {
      side_dist[i] = (current_block[i] + 1 - current_pos[i]) * delta[i]
    } else {
      side_dist[i] = (current_pos[i] - current_block[i]) * delta[i]
    }
  }

  // DDA algorithm
  for distance: f32 = 0; distance < max_distance; {
    // find which direction to step in
    if side_dist.x < side_dist.y && side_dist.x < side_dist.z {
      distance         = side_dist.x
      side_dist.x     += delta.x
      current_block.x += step.x
      normal           = {-step.x, 0, 0}
    } else if side_dist.y < side_dist.z {
      distance         = side_dist.y
      side_dist.y     += delta.y
      current_block.y += step.y
      normal           = {0, -step.y, 0}
    } else {
      distance         = side_dist.z
      side_dist.z     += delta.z
      current_block.z += step.z
      normal           = {0, 0, -step.z}
    }
  
    // check if hit a block
    x, y, z := int(current_block.x), int(current_block.y), int(current_block.z)
    voxel := get_voxel_world(g_mem.world, x, y, z)
    if voxel != nil && voxel.type != .None {
      return true, {f32(x), f32(y), f32(z)}, normal
    }
  }

  return false, {}, {}
}
