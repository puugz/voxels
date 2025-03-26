package main

import "core:math"
import "core:math/linalg"
import "core:math/noise"

import sdl "vendor:sdl3"

CHUNK_SIZE   :: 16
CHUNK_WIDTH  :: CHUNK_SIZE * 2
CHUNK_HEIGHT :: CHUNK_SIZE
CHUNK_DEPTH  :: CHUNK_SIZE * 2
CHUNK_VOLUME :: CHUNK_WIDTH * CHUNK_HEIGHT * CHUNK_DEPTH

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
  using local_position: [3]i8,
  type: Voxel_Type,
}

is_transparent :: #force_inline proc(voxel: ^Voxel) -> bool {
  return voxel == nil || voxel.type == .None || voxel.type == .Glass || voxel.type == .Water
  // return voxel == nil || voxel.type == .None
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
  if local_x < 0 || local_x >= CHUNK_WIDTH ||
     local_y < 0 || local_y >= CHUNK_HEIGHT ||
     local_z < 0 || local_z >= CHUNK_DEPTH {
    return nil
  }
  index := local_z * (CHUNK_WIDTH * CHUNK_HEIGHT) + local_y * CHUNK_WIDTH + local_x
  return &chunk.voxels[index]
}

set_voxel :: #force_inline proc(chunk: ^Chunk, local_x, local_y, local_z: int, type: Voxel_Type) {
  if local_x < 0 || local_x >= CHUNK_WIDTH ||
    local_y < 0 || local_y >= CHUNK_HEIGHT ||
    local_z < 0 || local_z >= CHUNK_DEPTH {
    return
  }
  
  index := local_z * (CHUNK_WIDTH * CHUNK_HEIGHT) + local_y * CHUNK_WIDTH + local_x  
  voxel := &chunk.voxels[index]
  
  voxel.local_position = {i8(local_x), i8(local_y), i8(local_z)}
  voxel.type = type
}

World :: struct {
  // @TODO: Multiple chunks
  chunk: Chunk,
}

// get_chunk :: proc(world: ^World, x, y, z: int) -> ^Chunk {
//   // chunk := &world.chunks[]
// }

generate_world :: proc(world: ^World) {
  chunk := &world.chunk

  SEED    :: 12345
  OCTAVES :: 12

  for i in 0 ..< CHUNK_VOLUME {
    x := i % CHUNK_WIDTH
    // y := i / CHUNK_WIDTH % CHUNK_HEIGHT
    z := i / CHUNK_WIDTH / CHUNK_HEIGHT % CHUNK_DEPTH

    cz := 0 // chunk coords in world
    cx := 0

    nx, nz := f64(x) / f64(CHUNK_WIDTH) - 0.5, f64(z) / f64(CHUNK_DEPTH) - 0.5
    noise_value := int(math.abs(math.floor(
      octave_noise(SEED, {0.1 * (nz + f64(cz)), 0.1 * (nx + f64(cx))}, OCTAVES) * (CHUNK_HEIGHT - 1)
    )))

    for y in 0 ..= noise_value {
      set_voxel(chunk, x, y, z, .Stone)
    }
  }

  copy_cmd_buf := sdl.AcquireGPUCommandBuffer(g_mem.device)
  assert(copy_cmd_buf != nil)
  defer assert(sdl.SubmitGPUCommandBuffer(copy_cmd_buf))

  copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)
  defer sdl.EndGPUCopyPass(copy_pass)

  assert(copy_pass != nil)
  generate_mesh(chunk, copy_pass)
}

render_world :: proc(world: ^World, render_pass: ^sdl.GPURenderPass, cmd_buffer: ^sdl.GPUCommandBuffer, ubo: ^UBO) {
  chunk := &world.chunk
  if chunk.mesh_generated {
    // model_mat := linalg.matrix4_translate(chunk.world_position * CHUNK_SIZE)

    sdl.BindGPUVertexBuffers(render_pass, 0, &(sdl.GPUBufferBinding{ buffer = chunk.vertex_buf }), 1)
    sdl.BindGPUIndexBuffer(render_pass, { buffer = chunk.index_buf }, ._16BIT)
    sdl.PushGPUVertexUniformData(cmd_buffer, 0, ubo, size_of(ubo^))
    // sdl.BindGPUFragmentSamplers(render_pass, 0, &(sdl.GPUTextureSamplerBinding{
    //   texture = g_mem.texture,
    //   sampler = g_mem.sampler,
    // }), 1)
    sdl.DrawGPUIndexedPrimitives(render_pass, u32(len(chunk.indices)), 1, 0, 0, 0)
  }
}
