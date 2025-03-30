#version 460

layout(location=0) in vec3 v_color;
layout(location=1) in flat uint v_normal;

layout(location=0) out vec4 v_frag_color;

// layout(set=2, binding=0) uniform sampler2D u_texture;

const vec3 NORMALS[] = {
  vec3( 0, +1,  0),
  vec3( 0, -1,  0),
  vec3(+1,  0,  0),
  vec3(-1,  0,  0),
  vec3( 0,  0, -1),
  vec3( 0,  0, +1),
};

const float AMBIENT = 0.3;

void main() {
  vec3 normal = NORMALS[v_normal];

  vec3 light_dir = normalize(vec3(0.8, 1, 0.3));
  float ambient = 0.3;
  float diffuse = max(dot(normal, light_dir), 0.0);
  float lighting = diffuse + ambient;
  
  // slight gamma correction
  // vec3 final_color = pow(v_color * lighting, vec3(1.0/2.2));
  vec3 final_color = v_color * lighting;
  
  v_frag_color = vec4(final_color, 1.0);
  // v_frag_color = texture(u_texture, v_texcoord);// * vec4(v_color, 1.0);
}
