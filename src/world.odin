package main

import "core:math"
import "core:math/linalg"
import "core:math/noise"

import sdl "vendor:sdl3"

CHUNK_SIZE   :: 64
CHUNK_SLICE  :: CHUNK_SIZE * CHUNK_SIZE
CHUNK_VOLUME :: CHUNK_SIZE * CHUNK_SIZE * CHUNK_SIZE

Voxel_Type :: enum {
  None,
  Bedrock,
  Stone,
  Cobblestone,
  Dirt,
  Grass,
  Glass,
  Water,
  Obsidian,
  TNT,
}

Voxel :: struct {
  using local_position: [3]byte,
  type: Voxel_Type,
}

is_transparent :: proc(voxel: ^Voxel) -> bool {
  #partial switch voxel.type {
    case .None, .Glass, .Water: return true
    case:                      return false
  }
}

Chunk :: struct {
  using local_position: [3]int,
  voxels:               [CHUNK_VOLUME]Voxel,

  mesh_generated: bool,
  vertices:       [dynamic]f32,
  indices:        [dynamic]u16,

  vertex_buf: ^sdl.GPUBuffer,
  index_buf:  ^sdl.GPUBuffer,
}

get_voxel :: #force_inline proc(chunk: ^Chunk, local_x, local_y, local_z: int) -> ^Voxel {
  index := local_x + local_y * CHUNK_SLICE + local_z * CHUNK_SLICE
  if index > len(chunk.voxels) || index < 0 do return nil
  return &chunk.voxels[index]
}

set_voxel :: #force_inline proc(chunk: ^Chunk, local_x, local_y, local_z: int, type: Voxel_Type) {
  index := local_x + local_y * CHUNK_SLICE + local_z * CHUNK_SLICE
  if index > len(chunk.voxels) || index < 0 do return
  chunk.voxels[index].type = type
}

World :: struct {
  chunks: [10][10]Chunk,
}

// get_chunk :: proc(world: ^World, x, y, z: int) -> ^Chunk {
//   // chunk := &world.chunks[]
// }

generate_world :: proc(world: ^World) {
  // for x in 0 ..< 10 {
  //   for z in 0 ..< 10 {
  //     chunk := &world.chunks[x][z]

  //     terrain_y := noise.noise_2d(123, {f64(x * CHUNK_SIZE), f64(z * CHUNK_SIZE)})
  //     block_height := int(math.round(CHUNK_SIZE * terrain_y))

  //     set_voxel(chunk, x, block_height, z, .Stone)
  //   }
  // }

  // copy_cmd_buf := sdl.AcquireGPUCommandBuffer(g_mem.device)
  // defer assert(sdl.SubmitGPUCommandBuffer(copy_cmd_buf))

  // copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)
  // defer sdl.EndGPUCopyPass(copy_pass)

  // for x in 0 ..< 10 {
  //   for z in 0 ..< 10 {
  //     chunk := &world.chunks[x][z]
  //     generate_mesh(chunk, copy_pass)
  //   }
  // }
}

render_world :: proc(world: ^World) {
  for x in 0 ..< 10 {
    for z in 0 ..< 10 {
      chunk := &world.chunks[x][z]
      if chunk.mesh_generated {
        // model_mat := linalg.matrix4_translate(chunk.world_position * CHUNK_SIZE)
      }
    }
  }
}
