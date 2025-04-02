package main

import "core:mem"
import "core:log"
import "core:os"
import "core:fmt"
import sdl "vendor:sdl3"

Face_Side :: enum byte {
  Top,
  Bottom,
  Left,
  Right,
  Front,
  Back,
}

Tex_Coord :: enum byte {
  Top_Left,     // 00
  Top_Right,    // 01
  Bottom_Left,  // 10
  Bottom_Right, // 11
}

Packed_Vertex_Data :: i32
// 00000TTTTVVNNNZZZZZZYYYYYYXXXXXX
//      ^   ^ ^  ^     ^     ^
//      |   | |  Z     Y     X
//      |   | Normal
//      |   TexCoord
//      Voxel type (Excluding None)

pack_vertex_data :: proc(pos: vec3b, normal: Face_Side, texcoord: Tex_Coord, type: Voxel_Type) -> Packed_Vertex_Data {
  return (cast(Packed_Vertex_Data)(int(type) - 1) << 24) |
         (cast(Packed_Vertex_Data)(texcoord) << 21) |
         (cast(Packed_Vertex_Data)(normal)   << 18) |
         (cast(Packed_Vertex_Data)(pos.z)    << 12) |
         (cast(Packed_Vertex_Data)(pos.y)    << 6 ) |
         (cast(Packed_Vertex_Data)(pos.x));
}

generate_mesh :: proc(chunk: ^Chunk, copy_pass: ^sdl.GPUCopyPass) {
  add_face :: #force_inline proc(vertices: ^[dynamic]Packed_Vertex_Data, indices: ^[dynamic]u16, xi, yi, zi: int, side: Face_Side, type: Voxel_Type) {
    base_idx := u16(len(vertices))

    top_left  := vec3b{ byte(xi), byte(yi), byte(zi) }
    bot_left  := vec3b{ byte(xi), byte(yi), byte(zi) }
    bot_right := vec3b{ byte(xi), byte(yi), byte(zi) }
    top_right := vec3b{ byte(xi), byte(yi), byte(zi) }

    switch side {
      case .Left:
        top_left  += {0, 1, 0}
        bot_left  += {0, 0, 0}
        bot_right += {0, 0, 1}
        top_right += {0, 1, 1}
      case .Right:
        top_left  += {1, 1, 1}
        bot_left  += {1, 0, 1}
        bot_right += {1, 0, 0}
        top_right += {1, 1, 0}
      case .Top:
        top_left  += {1, 1, 1}
        bot_left  += {1, 1, 0}
        bot_right += {0, 1, 0}
        top_right += {0, 1, 1}
      case .Bottom:
        top_left  += {0, 0, 1}
        bot_left  += {0, 0, 0}
        bot_right += {1, 0, 0}
        top_right += {1, 0, 1}
      case .Front:
        top_left  += {0, 1, 1}
        bot_left  += {0, 0, 1}
        bot_right += {1, 0, 1}
        top_right += {1, 1, 1}
      case .Back:
        top_left  += {1, 1, 0}
        bot_left  += {1, 0, 0}
        bot_right += {0, 0, 0}
        top_right += {0, 1, 0}
    }

    tl_packed := pack_vertex_data(top_left, side, .Top_Left, type)
    bl_packed := pack_vertex_data(bot_left, side, .Bottom_Left, type)
    br_packed := pack_vertex_data(bot_right, side, .Bottom_Right, type)
    tr_packed := pack_vertex_data(top_right, side, .Top_Right, type)

    //               0          1          2          3
    append(vertices, tl_packed, bl_packed, br_packed, tr_packed)
    append(indices,
      0 + base_idx, 1 + base_idx, 2 + base_idx,
      2 + base_idx, 3 + base_idx, 0 + base_idx,
    )
  }
  
  vertices: [dynamic]Packed_Vertex_Data; defer delete(vertices)
  indices:  [dynamic]u16;                defer delete(indices)

  // @TODO: greedy meshing
  for i in 0 ..< CHUNK_VOLUME {
    x := i % CHUNK_WIDTH
    y := i / CHUNK_WIDTH % CHUNK_HEIGHT
    z := i / CHUNK_WIDTH / CHUNK_HEIGHT % CHUNK_LENGTH

    voxel := get_voxel(chunk, x, y, z)
    if voxel == nil || voxel.type == .None do continue

    wx := int(CHUNK_WIDTH  * chunk.x) + x
    wy := int(CHUNK_HEIGHT * chunk.y) + y
    wz := int(CHUNK_LENGTH * chunk.z) + z

    voxel_top    := get_voxel_world(g_mem.world, wx    , wy + 1, wz    )
    voxel_bottom := get_voxel_world(g_mem.world, wx    , wy - 1, wz    )
    voxel_left   := get_voxel_world(g_mem.world, wx - 1, wy    , wz    )
    voxel_right  := get_voxel_world(g_mem.world, wx + 1, wy    , wz    )
    voxel_front  := get_voxel_world(g_mem.world, wx    , wy    , wz + 1)
    voxel_back   := get_voxel_world(g_mem.world, wx    , wy    , wz - 1)

    check_face :: #force_inline proc(voxel, other: ^Voxel) -> bool {
      return other == nil || other.type == .None// || (voxel.type != other.type && is_transparent(other))
    }

    // @TODO: Vertex pulling
    if check_face(voxel, voxel_top)    do add_face(&vertices, &indices, x, y, z, .Top, voxel.type)
    if check_face(voxel, voxel_bottom) do add_face(&vertices, &indices, x, y, z, .Bottom, voxel.type)
    if check_face(voxel, voxel_left)   do add_face(&vertices, &indices, x, y, z, .Left, voxel.type)
    if check_face(voxel, voxel_right)  do add_face(&vertices, &indices, x, y, z, .Right, voxel.type)
    if check_face(voxel, voxel_front)  do add_face(&vertices, &indices, x, y, z, .Front, voxel.type)
    if check_face(voxel, voxel_back)   do add_face(&vertices, &indices, x, y, z, .Back, voxel.type)
  }

  vertices_bytes := len(vertices) * size_of(vertices[0])
  indices_bytes  := len(indices)  * size_of(indices[0])

  if vertices_bytes == 0 {
    // Don't upload empty mesh to GPU.
    return
  }

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
}
