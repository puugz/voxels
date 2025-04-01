package main

import "core:log"
import "core:time"
import "core:math"
import "core:math/linalg"
import "core:math/noise"

import sdl "vendor:sdl3"

CHUNK_SIZE   :: 32
CHUNK_WIDTH  :: CHUNK_SIZE
CHUNK_HEIGHT :: CHUNK_SIZE
CHUNK_LENGTH :: CHUNK_SIZE
CHUNK_VOLUME :: CHUNK_WIDTH * CHUNK_HEIGHT * CHUNK_LENGTH

Voxel_Type :: enum byte {
  None,
  Bedrock,
  Stone,
  Cobblestone,
  Dirt,
  Grass,
  Glass,
  Water,
  Oak_Log,
  Oak_Leaves,
}

Voxel :: struct {
  using local_position: [3]i8,
  type: Voxel_Type,
}

is_transparent :: #force_inline proc(voxel: ^Voxel) -> bool {
  return voxel == nil || voxel.type == .None || voxel.type == .Glass || voxel.type == .Water
}

Chunk :: struct {
  using local_position: [3]byte,
  voxels:               [CHUNK_VOLUME]Voxel,

  mesh_generated: bool,
  num_indices:    u32,

  vertex_buf: ^sdl.GPUBuffer,
  index_buf:  ^sdl.GPUBuffer,
}

get_voxel_world :: #force_inline proc(world: ^World, world_x, world_y, world_z: int) -> ^Voxel {
  cx, cy, cz := world_to_chunk(world_x, world_y, world_z)
  if cx < 0 || cx >= WORLD_WIDTH ||
     cy < 0 || cy >= WORLD_HEIGHT ||
     cz < 0 || cz >= WORLD_LENGTH {
    return nil
  }
  chunk := &world.chunks[cx][cy][cz]

  if chunk != nil {
    lx, ly, lz := world_to_local_pos(world_x, world_y, world_z)
    return get_voxel(chunk, lx, ly, lz)
  }
  return nil
}

get_voxel :: #force_inline proc(chunk: ^Chunk, local_x, local_y, local_z: int) -> ^Voxel {
  if local_x < 0 || local_x >= CHUNK_WIDTH ||
     local_y < 0 || local_y >= CHUNK_HEIGHT ||
     local_z < 0 || local_z >= CHUNK_LENGTH {
    return nil
  }
  index := local_z * (CHUNK_WIDTH * CHUNK_HEIGHT) + local_y * CHUNK_WIDTH + local_x
  return &chunk.voxels[index]
}

set_voxel :: #force_inline proc(chunk: ^Chunk, local_x, local_y, local_z: int, type: Voxel_Type) {
  if local_x < 0 || local_x >= CHUNK_WIDTH ||
    local_y < 0 || local_y >= CHUNK_HEIGHT ||
    local_z < 0 || local_z >= CHUNK_LENGTH {
    return
  }
  
  index := local_z * (CHUNK_WIDTH * CHUNK_HEIGHT) + local_y * CHUNK_WIDTH + local_x  
  voxel := &chunk.voxels[index]

  voxel.local_position = {i8(local_x), i8(local_y), i8(local_z)}
  voxel.type = type
}

world_to_chunk :: proc(world_x, world_y, world_z: int) -> (chunk_x, chunk_y, chunk_z: int) {
  chunk_x = world_x / CHUNK_WIDTH
  chunk_y = world_y / CHUNK_HEIGHT
  chunk_z = world_z / CHUNK_LENGTH
  
  if world_x < 0 do chunk_x = (world_x + 1) / CHUNK_WIDTH - 1
  if world_y < 0 do chunk_y = (world_y + 1) / CHUNK_HEIGHT - 1
  if world_z < 0 do chunk_z = (world_z + 1) / CHUNK_LENGTH - 1
  
  return
}

world_to_local_pos :: proc(world_x, world_y, world_z: int) -> (local_x, local_y, local_z: int) {
  local_x = world_x % CHUNK_WIDTH
  local_y = world_y % CHUNK_HEIGHT
  local_z = world_z % CHUNK_LENGTH
  
  if local_x < 0 do local_x += CHUNK_WIDTH
  if local_y < 0 do local_y += CHUNK_HEIGHT
  if local_z < 0 do local_z += CHUNK_LENGTH
  
  return
}

// @TODO: Sliding window implementation (load/unload chunks as camera moves around)
WORLD_WIDTH  :: 8
WORLD_HEIGHT :: 8
WORLD_LENGTH :: 8

World :: struct {
  chunks: [WORLD_WIDTH][WORLD_HEIGHT][WORLD_LENGTH]Chunk,
}

generate_world :: proc(world: ^World) {
  log.debug("Generating world...")
  start := time.now()
  defer {
    diff := time.diff(start, time.now())
    ms   := time.duration_milliseconds(diff)
    log.debugf("Took %.0f ms.", ms)
  }

  copy_cmd_buf := sdl.AcquireGPUCommandBuffer(g_mem.device)
  assert(copy_cmd_buf != nil)
  defer assert(sdl.SubmitGPUCommandBuffer(copy_cmd_buf))

  copy_pass := sdl.BeginGPUCopyPass(copy_cmd_buf)
  defer sdl.EndGPUCopyPass(copy_pass)
  assert(copy_pass != nil)

  seed := i64(12345)
  // seed := time.now()._nsec

  for cx in 0 ..< WORLD_WIDTH {
    for cy in 0 ..< WORLD_HEIGHT {
      for cz in 0 ..< WORLD_LENGTH {
        chunk := &world.chunks[cx][cy][cz]
        chunk.local_position = {byte(cx), byte(cy), byte(cz)}

        OCTAVES :: 5
        NOISE_SCALE :: 2
      
        for i in 0 ..< CHUNK_VOLUME {
          x := i % CHUNK_WIDTH
          y := i / CHUNK_WIDTH % CHUNK_HEIGHT
          z := i / CHUNK_WIDTH / CHUNK_HEIGHT % CHUNK_LENGTH

          wx := f64(cx * CHUNK_WIDTH  + x)
          wy := f64(cy * CHUNK_HEIGHT + y)
          wz := f64(cz * CHUNK_LENGTH + z)

          nx := wx / f64(CHUNK_WIDTH  * WORLD_WIDTH)  - 0.5
          ny := wy / f64(CHUNK_HEIGHT * WORLD_HEIGHT) - 0.5
          nz := wz / f64(CHUNK_LENGTH * WORLD_LENGTH) - 0.5

          noise_value := octave_noise_3d(seed, {
            NOISE_SCALE * nz,
            NOISE_SCALE * ny,
            NOISE_SCALE * nx,
          }, OCTAVES)// * (CHUNK_HEIGHT * WORLD_HEIGHT - 1)

          normalized_noise := (noise_value + 1) * 0.5
          terrain_height := int(normalized_noise * CHUNK_HEIGHT * WORLD_HEIGHT)

          if int(wy) <= terrain_height {
            block_type := Voxel_Type.Stone
            if int(wy) == 0 {
              block_type = .Bedrock
            } else if int(wy) == terrain_height {
              block_type = .Grass
            } else if int(wy) > terrain_height - 4 {
              block_type = .Dirt
            }
            set_voxel(chunk, x, y, z, block_type)
          }
        }
      }
    }
  }

  for cx in 0 ..< WORLD_WIDTH {
    for cy in 0 ..< WORLD_HEIGHT {
      for cz in 0 ..< WORLD_LENGTH {
        generate_mesh(&world.chunks[cx][cy][cz], copy_pass)
      }
    }
  }
}

render_world :: proc(world: ^World, render_pass: ^sdl.GPURenderPass, cmd_buffer: ^sdl.GPUCommandBuffer) {
  for cx in 0 ..< WORLD_WIDTH {
    for cy in 0 ..< WORLD_HEIGHT {
      for cz in 0 ..< WORLD_LENGTH {
        chunk := &world.chunks[cx][cy][cz]
    
        if chunk.mesh_generated {
          model_mat := linalg.matrix4_translate(vec3{
            f32(cx * CHUNK_WIDTH),
            f32(cy * CHUNK_HEIGHT),
            f32(cz * CHUNK_LENGTH),
          })
        
          ubo := UBO {
            mvp = g_mem.proj_mat * view_matrix(&g_mem.camera) * model_mat,
          }
      
          sdl.BindGPUVertexBuffers(render_pass, 0, &(sdl.GPUBufferBinding{ buffer = chunk.vertex_buf }), 1)
          sdl.BindGPUIndexBuffer(render_pass, { buffer = chunk.index_buf }, ._16BIT)
          sdl.PushGPUVertexUniformData(cmd_buffer, 0, &ubo, size_of(ubo))
          sdl.BindGPUFragmentSamplers(render_pass, 0, &(sdl.GPUTextureSamplerBinding{
            texture = g_mem.atlas_texture,
            sampler = g_mem.atlas_sampler,
          }), 1)
          sdl.DrawGPUIndexedPrimitives(render_pass, chunk.num_indices, 1, 0, 0, 0)
        }
      }
    }
  }
}
