#version 460

layout(set=1, binding=0) uniform UBO {
  mat4 mvp;
};

layout(location=0) in int a_data;
// 000000000VVNNNZZZZZZYYYYYYXXXXXX
//          ^ ^  ^     ^     ^
//          | |  Z     Y     X
//          | Normal
//          TexCoord

layout(location=0) out int v_normal;
layout(location=1) out vec2 v_texcoord;

#define MASK_6BITS 63
#define MASK_3BITS 7
#define MASK_2BITS 3

const vec2 TEXCOORDS[] = {
  vec2(0, 0), // Top_Left
  vec2(1, 0), // Top_Right
  vec2(0, 1), // Bottom_Left
  vec2(1, 1), // Bottom_Right
};

void main() {
  int x        =  a_data        & MASK_6BITS;
  int y        = (a_data >> 6)  & MASK_6BITS;
  int z        = (a_data >> 12) & MASK_6BITS;
  int normal   = (a_data >> 18) & MASK_3BITS;
  int texcoord = (a_data >> 21) & MASK_2BITS;

  vec3 position = vec3(float(x), float(y), float(z));

  v_normal   = normal;
  v_texcoord = TEXCOORDS[texcoord];
  gl_Position = mvp * vec4(position, 1.);
}
