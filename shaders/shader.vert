#version 460

layout (set = 1, binding = 0) uniform UBO {
  mat4 mvp;
};

void main() {
  vec4 pos;

         if (gl_VertexIndex == 0) {
    pos = vec4(-0.5, -0.5, -3.0, 1.0);
  } else if (gl_VertexIndex == 1) {
    pos = vec4( 0,    0.5, -3.0, 1.0);
  } else if (gl_VertexIndex == 2) {
    pos = vec4( 0.5, -0.5, -3.0, 1.0);
  }

  gl_Position = mvp * pos;
}
