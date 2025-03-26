package main

import "core:mem"
import sdl "vendor:sdl3"

Vertex_Data :: struct {
  pos: vec3,
}

generate_mesh :: proc(chunk: ^Chunk, copy_pass: ^sdl.GPUCopyPass) {
  check_face :: #force_inline proc(voxel, other: ^Voxel) -> bool {
    return other.type == .None || (voxel.type != other.type && is_transparent(other))
  }

  Face_Side :: enum {
    Top,
    Bottom,
    Left,
    Right,
    Front,
    Back,
  }
  
  add_face :: #force_inline proc(chunk: ^Chunk, voxel: ^Voxel, side: Face_Side) {
    base_idx := u16(len(chunk.vertices) / 3)

    x, y, z := f32(voxel.x), f32(voxel.y), f32(voxel.z)

    top_left  := vec3{x, y, z}
    bot_left  := vec3{x, y, z}
    bot_right := vec3{x, y, z}
    top_right := vec3{x, y, z}

    switch side {
      case .Left:
        top_left  += {-0.5,  0.5, -0.5}
        bot_left  += {-0.5, -0.5, -0.5}
        bot_right += {-0.5, -0.5,  0.5}
        top_right += {-0.5,  0.5,  0.5}
      case .Right:
        top_left  += { 0.5,  0.5,  0.5}
        bot_left  += { 0.5, -0.5,  0.5}
        bot_right += { 0.5, -0.5, -0.5}
        top_right += { 0.5,  0.5, -0.5}
      case .Top:
        top_left  += { 0.5,  0.5,  0.5}
        bot_left  += { 0.5,  0.5, -0.5}
        bot_right += {-0.5,  0.5, -0.5}
        top_right += {-0.5,  0.5,  0.5}
      case .Bottom:
        top_left  += {-0.5, -0.5,  0.5}
        bot_left  += {-0.5, -0.5, -0.5}
        bot_right += { 0.5, -0.5, -0.5}
        top_right += { 0.5, -0.5,  0.5}
      case .Front:
        top_left  += {-0.5,  0.5,  0.5}
        bot_left  += {-0.5, -0.5,  0.5}
        bot_right += { 0.5, -0.5,  0.5}
        top_right += { 0.5,  0.5,  0.5}
      case .Back:
        top_left  += { 0.5,  0.5, -0.5}
        bot_left  += { 0.5, -0.5, -0.5}
        bot_right += {-0.5, -0.5, -0.5}
        top_right += {-0.5,  0.5, -0.5}
    }

    append(&chunk.vertices, ..top_left[:])
    append(&chunk.vertices, ..bot_left[:])
    append(&chunk.vertices, ..bot_right[:])
    append(&chunk.vertices, ..top_right[:])

    append(&chunk.indices,
      0 + base_idx, 1 + base_idx, 2 + base_idx,
      2 + base_idx, 3 + base_idx, 0 + base_idx,
    )
  }

  // @TODO: greedy meshing
  for i in 0 ..< CHUNK_VOLUME {
    x := i % CHUNK_SIZE
    y := i / CHUNK_SIZE % CHUNK_SIZE
    z := i / CHUNK_SIZE / CHUNK_SIZE % CHUNK_SIZE

    voxel := get_voxel(chunk, x, y, z)
    if voxel == nil do continue

    // @TODO: Check surrounding chunk voxels
    voxel_top    := get_voxel(chunk, x    , y + 1, z    )
    voxel_bottom := get_voxel(chunk, x    , y - 1, z    )
    voxel_left   := get_voxel(chunk, x - 1, y    , z    )
    voxel_right  := get_voxel(chunk, x + 1, y    , z    )
    voxel_front  := get_voxel(chunk, x    , y    , z + 1)
    voxel_back   := get_voxel(chunk, x    , y    , z - 1)
    
    // @TODO: Vertex pulling
    if check_face(voxel, voxel_top)    do add_face(chunk, voxel, .Top)
    if check_face(voxel, voxel_bottom) do add_face(chunk, voxel, .Bottom)
    if check_face(voxel, voxel_left)   do add_face(chunk, voxel, .Left)
    if check_face(voxel, voxel_right)  do add_face(chunk, voxel, .Right)
    if check_face(voxel, voxel_front)  do add_face(chunk, voxel, .Front)
    if check_face(voxel, voxel_back)   do add_face(chunk, voxel, .Back)
  }

  vertices_bytes := len(chunk.vertices) * size_of(f32)
  indices_bytes  := len(chunk.indices)  * size_of(u16)

  chunk.vertex_buf = sdl.CreateGPUBuffer(g_mem.device, {
    usage = {.VERTEX},
    size  = u32(vertices_bytes),
  })
  chunk.index_buf = sdl.CreateGPUBuffer(g_mem.device, {
    usage = {.INDEX},
    size  = u32(indices_bytes),
  })

  // @TODO: use 1 transfer buffer for all?
  transfer_buf := sdl.CreateGPUTransferBuffer(g_mem.device, {
    usage = .UPLOAD,
    size  = u32(vertices_bytes + indices_bytes), // +indices
  })
  assert(transfer_buf != nil)

  transfer_mem := cast([^]byte) sdl.MapGPUTransferBuffer(g_mem.device, transfer_buf, false)
  mem.copy(transfer_mem, raw_data(chunk.vertices), vertices_bytes)
  mem.copy(transfer_mem[vertices_bytes:], raw_data(chunk.indices), indices_bytes)
  sdl.UnmapGPUTransferBuffer(g_mem.device, transfer_buf)

  // upload vertices
  sdl.UploadToGPUBuffer(
    copy_pass,
    { transfer_buffer = transfer_buf },
    { buffer = g_mem.vertex_buf, size = u32(vertices_bytes) },
    false,
  )

  // upload indices
  sdl.UploadToGPUBuffer(
    copy_pass,
    { transfer_buffer = transfer_buf, offset = u32(vertices_bytes) },
    { buffer = g_mem.index_buf, size = u32(indices_bytes) },
    false,
  )
  
  sdl.ReleaseGPUTransferBuffer(g_mem.device, transfer_buf)

  chunk.mesh_generated = true
}
