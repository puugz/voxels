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
  check_face :: #force_inline proc(voxel, other: ^Voxel) -> bool {
    return other == nil || other.type == .None
    // if other == nil do return true
    // return is_transparent(other)
    // return other.type == .None || (voxel.type != other.type && is_transparent(other))
  }

  Face_Side :: enum {
    Top,
    Bottom,
    Left,
    Right,
    Front,
    Back,
  }
  
  add_face :: #force_inline proc(chunk: ^Chunk, xi, yi, zi: int, side: Face_Side) {
    base_idx := u16(len(chunk.vertices) / 3)

    x, y, z := f32(xi), f32(yi), f32(zi)

    if xi == 0 && yi == 4 && zi == 31 {
      fmt.println("break")
    }

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
    x := i % CHUNK_WIDTH
    y := i / CHUNK_WIDTH % CHUNK_HEIGHT
    z := i / CHUNK_WIDTH / CHUNK_HEIGHT % CHUNK_DEPTH

    voxel := get_voxel(chunk, x, y, z)
    if voxel == nil || voxel.type == .None do continue

    // @TODO: Check surrounding chunk voxels
    voxel_top    := get_voxel(chunk, x    , y + 1, z    )
    voxel_bottom := get_voxel(chunk, x    , y - 1, z    )
    voxel_left   := get_voxel(chunk, x - 1, y    , z    )
    voxel_right  := get_voxel(chunk, x + 1, y    , z    )
    voxel_front  := get_voxel(chunk, x    , y    , z + 1)
    voxel_back   := get_voxel(chunk, x    , y    , z - 1)

    if x == 0 && y == 4 && z == 31 {
      // my chunk is 32x16x32 but when i get the voxel_left which for this position,
      // should be [-1, 4, 31] i get this one instead [31, 3, 31]

      fmt.println("b")
      // assert(is_transparent(voxel_top),     fmt.tprint("%v", voxel_top))
      // assert(!is_transparent(voxel_bottom), fmt.tprint("%v", voxel_bottom))
      assert(is_transparent(voxel_left),    fmt.tprint("%v", voxel_left)) // THIS ONE IS THE PROBLEM
      // assert(!is_transparent(voxel_right),  fmt.tprint("%v", voxel_right))
      // assert(is_transparent(voxel_front),   fmt.tprint("%v", voxel_front))
      // assert(is_transparent(voxel_back),    fmt.tprint("%v", voxel_back))
    }
    
    // @TODO: Vertex pulling
    if check_face(voxel, voxel_top)    do add_face(chunk, x, y, z, .Top)
    if check_face(voxel, voxel_bottom) do add_face(chunk, x, y, z, .Bottom)
    if check_face(voxel, voxel_left)   do add_face(chunk, x, y, z, .Left)
    if check_face(voxel, voxel_right)  do add_face(chunk, x, y, z, .Right)
    if check_face(voxel, voxel_front)  do add_face(chunk, x, y, z, .Front)
    if check_face(voxel, voxel_back)   do add_face(chunk, x, y, z, .Back)
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

  log.debug("len(vertices):", len(chunk.vertices))
  log.debug("len(indices): ", len(chunk.indices))
  log.debug("vertices_bytes:", vertices_bytes)
  log.debug("indices_bytes: ", indices_bytes)

  // assert(vertices_bytes > 0)
  // assert(indices_bytes > 0)
  assert(chunk.vertex_buf != nil)
  assert(chunk.index_buf != nil)

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

  // vertices_handle, err := os.open("debug_vertices.txt", os.O_TRUNC | os.O_CREATE | os.O_RDWR)
  // defer os.close(vertices_handle)
  // for c in chunk.vertices {
  //   fmt.fprintfln(vertices_handle, "%v, ", c)
  // }

  // indices_handle, err2 := os.open("debug_indices.txt", os.O_TRUNC | os.O_CREATE | os.O_RDWR)
  // defer os.close(indices_handle)
  // for c in chunk.indices {
  //   fmt.fprintfln(indices_handle, "%v, ", c)
  // }

  log.debug("Mesh generated.")

  chunk.mesh_generated = true
}
