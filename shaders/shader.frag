#version 460

/*
https://www.reddit.com/r/sdl/comments/1ir4kq0/heads_up_about_sets_and_bindings_if_youre_using/?rdt=36407
Compute Pipelines:

set 0: Read-Only storage textures and buffers
set 1: Read-Write storage textures and buffers
set 2: Uniform buffers

Graphics Pipelines:

set 0: Samplers, textures and storage buffers available to the vertex shader
set 1: Uniform buffers available to the vertex shader
set 2: Samplers, textures and storage buffers available to the fragment shader
set 3: Uniform buffers available to the fragment shader
*/

layout(location=0) in flat int v_normal_idx;
layout(location=1) in vec2 v_texcoord;
layout(location=2) in flat int v_voxel_type;

layout(location=0) out vec4 v_frag_color;

layout(set=2, binding=0) uniform sampler2D u_texture;

#define Face_Top    vec3( 0, +1,  0)
#define Face_Bottom vec3( 0, -1,  0)
#define Face_Left   vec3(+1,  0,  0)
#define Face_Right  vec3(-1,  0,  0)
#define Face_Front  vec3( 0,  0, -1)
#define Face_Back   vec3( 0,  0, +1)

const vec3 NORMALS[] = {
  Face_Top,
  Face_Bottom,
  Face_Left,
  Face_Right,
  Face_Front,
  Face_Back,
};

#define ATLAS_WIDTH   256
#define ATLAS_HEIGHT  256
#define TILE_SIZE     16

#define Voxel_Grass             0
#define Voxel_Dirt              1
#define Voxel_Stone             2
#define Voxel_Stone_Slab        3
#define Voxel_Cobblestone       4
#define Voxel_Oak_Planks        5
#define Voxel_Oak_Log           6
#define Voxel_Oak_Leaves        7
#define Voxel_Bricks            8
#define Voxel_TNT               9
#define Voxel_Sand              10
#define Voxel_Gravel            11
#define Voxel_Iron_Block        12
#define Voxel_Gold_Block        13
#define Voxel_Diamond_Block     14
#define Voxel_Chest             15
#define Voxel_Gold_Ore          16
#define Voxel_Iron_Ore          17
#define Voxel_Coal_Ore          18
#define Voxel_Diamond_Ore       19
#define Voxel_Redstone_Ore      20
#define Voxel_Bookshelf         21
#define Voxel_Mossy_Cobblestone 22
#define Voxel_Obsidian          23
#define Voxel_Crafting_Table    24
#define Voxel_Furnace           25
#define Voxel_Furnace_On        26
#define Voxel_Snow              27
#define Voxel_Snowy_Grass       28
#define Voxel_Wool              29
#define Voxel_Netherrack        30
#define Voxel_Glowstone         31
#define Voxel_Sponge            32
#define Voxel_Bedrock           33
#define Voxel_Glass             34
#define Voxel_Water             35
#define Voxel_Lava              36

vec2 uv_offset(vec3 block_face) {
  vec2 offset = vec2(0);

  switch (v_voxel_type) {
    case Voxel_Grass: {
      if (block_face == Face_Top) {
        offset = vec2(0, 0);
      } else if (block_face == Face_Bottom) {
        offset = vec2(2, 0);
      } else {
        offset = vec2(3, 0);
      }
      break;
    }

    case Voxel_Dirt:        offset = vec2(2, 0); break;
    case Voxel_Stone:       offset = vec2(1, 0); break;
    case Voxel_Stone_Slab: {
      if (block_face == Face_Top || block_face == Face_Bottom) {
        offset = vec2(6, 0);
      } else {
        offset = vec2(5, 0);
      }
      break;
    }

    case Voxel_Cobblestone: offset = vec2(0, 1); break;
    case Voxel_Oak_Planks:  offset = vec2(4, 0); break;
    case Voxel_Oak_Log: {
      if (block_face == Face_Top || block_face == Face_Bottom) {
        offset = vec2(5, 1);
      } else {
        offset = vec2(4, 1);
      }
      break;
    }

    case Voxel_Oak_Leaves: offset = vec2(5, 3); break;
    case Voxel_Bricks: offset = vec2(7, 0); break;
    case Voxel_TNT: {
      if (block_face == Face_Top) {
        offset = vec2(9, 0);
      } else if (block_face == Face_Bottom) {
        offset = vec2(10, 0);
      } else {
        offset = vec2(8, 0);
      }
      break;
    }

    case Voxel_Sand:          offset = vec2(2, 1); break;
    case Voxel_Gravel:        offset = vec2(3, 1); break;
    case Voxel_Iron_Block:    offset = vec2(6, 1); break;
    case Voxel_Gold_Block:    offset = vec2(7, 1); break;
    case Voxel_Diamond_Block: offset = vec2(8, 1); break;
    case Voxel_Chest: {
      if (block_face == Face_Front) {
        offset = vec2(11, 1);
      } else if (block_face == Face_Top || block_face == Face_Bottom) {
        offset = vec2(9, 1);
      } else {
        offset = vec2(10, 1);
      }
      break;
    }

    case Voxel_Gold_Ore:     offset = vec2(0, 2); break;
    case Voxel_Iron_Ore:     offset = vec2(1, 2); break;
    case Voxel_Coal_Ore:     offset = vec2(2, 2); break;
    case Voxel_Diamond_Ore:  offset = vec2(2, 3); break;
    case Voxel_Redstone_Ore: offset = vec2(3, 3); break;
    case Voxel_Bookshelf: {
      if (block_face == Face_Top || block_face == Face_Bottom) {
        offset = vec2(4, 0); // oak planks
      } else {
        offset = vec2(3, 2);
      }
      break;
    }

    case Voxel_Mossy_Cobblestone: offset = vec2(4, 2); break;
    case Voxel_Obsidian:          offset = vec2(5, 2); break;
    case Voxel_Crafting_Table: {
      if (block_face == Face_Top) {
        offset = vec2(11, 2);
      } else if (block_face == Face_Bottom) {
        offset = vec2(4, 0); // oak planks
      } else if (block_face == Face_Front || block_face == Face_Back) {
        offset = vec2(11, 3);
      } else {
        offset = vec2(12, 3);
      }
      break;
    }

    case Voxel_Furnace:
    case Voxel_Furnace_On: {
      if (block_face == Face_Front) {
        if (v_voxel_type == Voxel_Furnace) {
          // not burning
          offset = vec2(12, 2);
        } else {
          // burning
          offset = vec2(13, 3);
        }
      } else if (block_face == Face_Top || block_face == Face_Bottom) {
        offset = vec2(14, 3);
      } else {
        offset = vec2(13, 2);
      }
      break;
    }

    case Voxel_Snow: offset = vec2(2, 4); break;
    case Voxel_Snowy_Grass: {
      if (block_face == Face_Top) {
        offset = vec2(2, 4); // snow
      } else if (block_face == Face_Bottom) {
        offset = vec2(2, 0);
      } else {
        offset = vec2(4, 4);
      }
      break;
    }

    case Voxel_Wool:       offset = vec2(0, 4); break;
    case Voxel_Netherrack: offset = vec2(7, 6); break;
    case Voxel_Glowstone:  offset = vec2(9, 6); break;
    case Voxel_Sponge:     offset = vec2(0, 3); break;
    case Voxel_Bedrock:    offset = vec2(1, 1); break;
    case Voxel_Glass:      offset = vec2(1, 3);   break;
    case Voxel_Water:      offset = vec2(13, 12); break;
    case Voxel_Lava:       offset = vec2(13, 14); break;

    // missing texture
    default: offset = vec2(0, 14); break;
  }
  return vec2(
    (offset.x + v_texcoord.x) * TILE_SIZE / ATLAS_WIDTH,
    (offset.y + v_texcoord.y) * TILE_SIZE / ATLAS_WIDTH
  );
}

void main() {
  vec3 normal    = NORMALS[v_normal_idx];
  vec3 light_dir = normalize(vec3(0.8, 1, 0.3));

  float ambient  = 0.6;
  float diffuse  = max(dot(normal, light_dir), 0.0);
  float lighting = diffuse + ambient;

  vec2 uv = uv_offset(normal);

  vec4 tex_color = texture(u_texture, uv);
  if (tex_color.a < 0.1) discard;

  vec3 final_color = tex_color.rgb * lighting;
  v_frag_color = vec4(final_color, 1.0);
}
