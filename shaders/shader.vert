#version 460

layout(set=1, binding=0) uniform UBO {
  mat4 mvp;
};

layout(location=0) in int a_data;
// 000000TTTVVNNNZZZZZZYYYYYYXXXXXX
//       ^  ^ ^  ^     ^     ^
//       |  | |  Z     Y     X
//       |  | Normal
//       |  TexCoord
//       Voxel type (Excluding None)

layout(location=0) out int v_normal_idx;
layout(location=1) out vec2 v_texcoord;
layout(location=2) out int v_voxel_type;

const vec2 TEXCOORDS[] = {
  vec2(0, 0), // Top_Left
  vec2(1, 0), // Top_Right
  vec2(0, 1), // Bottom_Left
  vec2(1, 1), // Bottom_Right
};

int bits(int n) {
  return (1 << n) - 1;
}

void main() {
  float x = float((a_data)       & bits(6));
  float y = float((a_data >> 6)  & bits(6));
  float z = float((a_data >> 12) & bits(6));
  v_normal_idx =           (a_data >> 18) & bits(3);
  v_texcoord   = TEXCOORDS[(a_data >> 21) & bits(2)];
  v_voxel_type =           (a_data >> 24) & bits(4);

  gl_Position = mvp * vec4(vec3(x, y, z), 1.);
}
