#version 460

layout(set=1, binding=0) uniform UBO {
  mat4 mvp;
};

layout(location=0) in vec3 a_position;
layout(location=1) in vec3 a_color;
layout(location=2) in vec2 a_texcoord;

layout(location=0) out vec3 v_color;
layout(location=1) out vec2 v_texcoord;

void main() {
  v_color     = a_color;
  v_texcoord  = a_texcoord;
  gl_Position = mvp * vec4(a_position, 1.);
}
