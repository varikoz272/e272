#version 450 core
layout (location = 0) in vec3 pos;
layout (location = 1) in vec2 texCoord;

uniform mat4 projection;
uniform mat4 view;        
uniform mat4 model;       

out vec2 fragCoord;

void main() {
    gl_Position = projection * view * model * vec4(pos, 1.0);
    fragCoord = texCoord;
}
