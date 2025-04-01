#version 460

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

#define Voxel_Bedrock     0
#define Voxel_Stone       1
#define Voxel_Cobblestone 2
#define Voxel_Dirt        3
#define Voxel_Grass       4
#define Voxel_Glass       5
#define Voxel_Water       6
#define Voxel_Oak_Log     7
#define Voxel_Oak_Leaves  8

vec2 uv_offset(vec3 block_face) {
  vec2 offset = vec2(0);

  switch (v_voxel_type) {
    case Voxel_Bedrock:     offset = vec2(1, 1); break;
    case Voxel_Stone:       offset = vec2(1, 0); break;
    case Voxel_Cobblestone: offset = vec2(0, 1); break;
    case Voxel_Dirt:        offset = vec2(2, 0); break;
    case Voxel_Grass:
      if (block_face == Face_Top) {
        offset = vec2(0, 0);
      } else if (block_face == Face_Bottom) {
        offset = vec2(2, 0);
      } else {
        offset = vec2(3, 0);
      }
      break;
    case Voxel_Glass: offset = vec2(1, 3);   break;
    case Voxel_Water: offset = vec2(13, 12); break;
    case Voxel_Oak_Log:
      if (block_face == Face_Top || block_face == Face_Bottom) {
        offset = vec2(5, 1);
      } else {
        offset = vec2(4, 1);
      }
      break;
    case Voxel_Oak_Leaves: offset = vec2(5, 3); break;
    default: break;
  }
  return vec2(
    (offset.x + v_texcoord.x) * TILE_SIZE / ATLAS_WIDTH,
    (offset.y + v_texcoord.y) * TILE_SIZE / ATLAS_WIDTH
  );
}

void main() {
  vec3 normal    = NORMALS[v_normal_idx];
  vec3 light_dir = normalize(vec3(0.8, 1, 0.3));

  float ambient  = 0.3;
  float diffuse  = max(dot(normal, light_dir), 0.0);
  float lighting = diffuse + ambient;

  vec2 uv = uv_offset(normal);
  
  // vec3 tex_color   = texture(u_texture, v_texcoord).rgb;
  vec3 tex_color   = texture(u_texture, uv).rgb;
  // vec3 tex_color = vec3(uv.x, uv.y, 0);
  vec3 final_color = tex_color * lighting;

  v_frag_color = vec4(final_color, 1.0);
}
