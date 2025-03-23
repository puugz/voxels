package main

import sdl "vendor:sdl3"

process_input_events :: proc(event: ^sdl.Event) {
  #partial switch event.type {
    case .KEY_DOWN:
      if !g_mem.key_down[event.key.scancode] {
        g_mem.key_pressed[event.key.scancode] = true
      }
      g_mem.key_down[event.key.scancode] = true

    case .KEY_UP:
      if g_mem.key_down[event.key.scancode] {
        g_mem.key_released[event.key.scancode] = true
      }
      g_mem.key_down[event.key.scancode] = false

    case .MOUSE_BUTTON_DOWN:
      if !g_mem.mouse_down[event.button.button] {
        g_mem.mouse_pressed[event.button.button] = true
      }
      g_mem.mouse_down[event.button.button] = true

    case .MOUSE_BUTTON_UP:
      if g_mem.mouse_down[event.button.button] {
        g_mem.mouse_released[event.button.button] = true
      }
      g_mem.mouse_down[event.button.button] = false
    
    case .MOUSE_WHEEL:
      g_mem.scroll_delta = event.wheel.mouse_y

    case .MOUSE_MOTION:
      g_mem.mouse_delta = { event.motion.xrel, event.motion.yrel }
      g_mem.mouse_pos   = { event.motion.x,    event.motion.y }
  }
}

key_pressed :: proc(key: sdl.Scancode, consume := true) -> bool {
  pressed := g_mem.key_pressed[key]
  if pressed && consume do g_mem.key_pressed[key] = false
  return pressed
}

key_released :: proc(key: sdl.Scancode, consume := true) -> bool {
  released := g_mem.key_released[key]
  if released && consume do g_mem.key_released[key] = false
  return released
}

key_down :: proc(key: sdl.Scancode) -> bool {
  return g_mem.key_down[key]
}

mouse_pressed :: proc(button: byte, consume := true) -> bool {
  pressed := g_mem.mouse_pressed[button]
  if pressed && consume do g_mem.mouse_pressed[button] = false
  return pressed
}

mouse_released :: proc(button: byte, consume := true) -> bool {
  released := g_mem.mouse_released[button]
  if released && consume do g_mem.mouse_released[button] = false
  return released
}

mouse_down :: proc(button: byte) -> bool {
  return g_mem.mouse_down[button]
}

