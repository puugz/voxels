package main

import "core:mem"
import "core:log"
import "core:os"
import "core:fmt"
import sdl "vendor:sdl3"

Vertex_Data :: struct {
  pos: vec3,
}

generate_mesh :: proc(chunk: ^Chunk, copy_pass: ^sdl.GPUCopyPass) {
  Face_Side :: enum {
    Top,
    Bottom,
    Left,
    Right,
    Front,
    Back,
  }
  
  add_face :: #force_inline proc(vertices: ^[dynamic]f32, indices: ^[dynamic]u16, xi, yi, zi: int, side: Face_Side) {
    FLOATS_PER_VERTEX :: 3
    
    base_idx := u16(len(vertices) / FLOATS_PER_VERTEX)
    x, y, z := f32(xi), f32(yi), f32(zi)

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

    append(vertices, ..top_left[:])
    append(vertices, ..bot_left[:])
    append(vertices, ..bot_right[:])
    append(vertices, ..top_right[:])

    append(indices,
      0 + base_idx, 1 + base_idx, 2 + base_idx,
      2 + base_idx, 3 + base_idx, 0 + base_idx,
    )
  }
  
  vertices: [dynamic]f32; defer delete(vertices)
  indices:  [dynamic]u16; defer delete(indices)

  // @TODO: greedy meshing
  for i in 0 ..< CHUNK_VOLUME {
    x := i % CHUNK_WIDTH
    y := i / CHUNK_WIDTH % CHUNK_HEIGHT
    z := i / CHUNK_WIDTH / CHUNK_HEIGHT % CHUNK_LENGTH

    voxel := get_voxel(chunk, x, y, z)
    if voxel == nil || voxel.type == .None do continue

    voxel_top    := get_voxel(chunk, x    , y + 1, z    )
    voxel_bottom := get_voxel(chunk, x    , y - 1, z    )
    voxel_left   := get_voxel(chunk, x - 1, y    , z    )
    voxel_right  := get_voxel(chunk, x + 1, y    , z    )
    voxel_front  := get_voxel(chunk, x    , y    , z + 1)
    voxel_back   := get_voxel(chunk, x    , y    , z - 1)
    
    check_face :: #force_inline proc(voxel, other: ^Voxel) -> bool {
      // @TODO: Check neighbouring chunk's voxels
      return other == nil || other.type == .None ||
             (voxel.type != other.type && is_transparent(other))
    }

    // @TODO: Vertex pulling
    if check_face(voxel, voxel_top)    do add_face(&vertices, &indices, x, y, z, .Top)
    if check_face(voxel, voxel_bottom) do add_face(&vertices, &indices, x, y, z, .Bottom)
    if check_face(voxel, voxel_left)   do add_face(&vertices, &indices, x, y, z, .Left)
    if check_face(voxel, voxel_right)  do add_face(&vertices, &indices, x, y, z, .Right)
    if check_face(voxel, voxel_front)  do add_face(&vertices, &indices, x, y, z, .Front)
    if check_face(voxel, voxel_back)   do add_face(&vertices, &indices, x, y, z, .Back)
  }

  vertices_bytes := len(vertices) * size_of(vertices[0])
  indices_bytes  := len(indices)  * size_of(indices[0])

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
  mem.copy(transfer_mem, raw_data(vertices), vertices_bytes)
  mem.copy(transfer_mem[vertices_bytes:], raw_data(indices), indices_bytes)
  sdl.UnmapGPUTransferBuffer(g_mem.device, transfer_buf)

  // upload vertices
  sdl.UploadToGPUBuffer(
    copy_pass,
    { transfer_buffer = transfer_buf },
    { buffer = chunk.vertex_buf, size = u32(vertices_bytes) },
    false,
  )

  // upload indices
  sdl.UploadToGPUBuffer(
    copy_pass,
    { transfer_buffer = transfer_buf, offset = u32(vertices_bytes) },
    { buffer = chunk.index_buf, size = u32(indices_bytes) },
    false,
  )
  
  sdl.ReleaseGPUTransferBuffer(g_mem.device, transfer_buf)

  chunk.mesh_generated = true
  chunk.num_indices    = u32(len(indices))

  log.debug("Mesh generated.")
}
