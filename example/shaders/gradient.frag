#version 300 es // OpenGL ES 3.0

#ifdef GL_ES
precision mediump float;
#endif

//#include <flutter/runtime_effect.glsl>

uniform vec2 iResolution; // viewport resolution (in pixels)
uniform float iTime; // time in seconds since the shader started

out vec4 fragColor;

void main() {
    vec2 uv = gl_FragCoord.xy / iResolution; // coordinates
    uv = vec2(uv.x, 1.0f - uv.y); // normalized coordinates 0..1
    vec3 c = vec3(uv.x * uv.y);
    fragColor = vec4(c, 1.0f); // red, green, blue, alpha
}