#version 460

layout(set=1, binding=0) uniform UBO {
  mat4 mvp;
};

layout(location=0) in vec3 a_pos;
layout(location=1) in vec3 a_col;

layout(location=0) out vec3 v_color;

void main() {
  v_color = a_col;
  gl_Position = mvp * vec4(a_pos, 1.);
}
