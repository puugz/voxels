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
  camera.position = {8, 8, 32}
  _ = sdl.SetWindowRelativeMouseMode(g_mem.window, g_mem.mouse_locked)
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
