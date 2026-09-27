#version 450 core
layout (location = 0) in vec2 pos;
layout (location = 1) in vec4 frag;
uniform float offset;
uniform mat4 projection;
out vec4 color;
void main() {
    gl_Position = projection * vec4(pos.x, pos.y, 0.0, 1.0);
    color = frag;
}
