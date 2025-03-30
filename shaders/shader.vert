#version 460

layout(set=1, binding=0) uniform UBO {
  mat4 mvp;
};

layout(location=0) in vec3 a_position;
layout(location=1) in vec2 a_texcoord;
layout(location=2) in uint a_normal;

// layout(location=0) out vec3 v_color;
layout(location=1) out vec2 v_texcoord;
layout(location=2) out uint v_normal;

void main() {
  // float r = fract(sin(gl_VertexIndex * 12.9898) * 43758.5453);
  // float g = fract(sin(gl_VertexIndex * 78.233) * 43758.5453);
  // float b = fract(sin(gl_VertexIndex * 45.164) * 43758.5453);
  // v_color = vec3(r, g, b);

  v_normal   = a_normal;
  v_texcoord = a_texcoord;
  gl_Position = mvp * vec4(a_position, 1.);
}
