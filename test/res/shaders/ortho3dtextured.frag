#version 450 core
in vec2 fragCoord;
out vec4 fragColor;

uniform sampler2D tex;

void main() {
    fragColor = texture(tex, fragCoord);
    // fragColor = vec4(1.0, 0.0, 0.0, 1.0);
}
