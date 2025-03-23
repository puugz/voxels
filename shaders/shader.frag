#version 460

layout(location=0) in vec3 v_color;
layout(location=1) in vec2 v_texcoord;

layout(location=0) out vec4 v_frag_color;

layout(set=2, binding=0) uniform sampler2D u_texture;

void main() {
  v_frag_color = texture(u_texture, v_texcoord);// * vec4(v_color, 1.0);
}
