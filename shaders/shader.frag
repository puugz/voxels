#version 460

layout(location=0) in flat int v_normal;
layout(location=1) in vec2 v_texcoord;

layout(location=0) out vec4 v_frag_color;

layout(set=2, binding=0) uniform sampler2D u_texture;

const vec3 NORMALS[] = {
  vec3( 0, +1,  0), // Top
  vec3( 0, -1,  0), // Bottom
  vec3(+1,  0,  0), // Left
  vec3(-1,  0,  0), // Right
  vec3( 0,  0, -1), // Front
  vec3( 0,  0, +1), // Back
};

void main() {
  vec3 normal    = NORMALS[v_normal];
  vec3 light_dir = normalize(vec3(0.8, 1, 0.3));

  float ambient  = 0.3;
  float diffuse  = max(dot(normal, light_dir), 0.0);
  float lighting = diffuse + ambient;
  
  vec3 tex_color   = texture(u_texture, v_texcoord).rgb;
  vec3 final_color = tex_color * lighting;

  v_frag_color = vec4(final_color, 1.0);
}
