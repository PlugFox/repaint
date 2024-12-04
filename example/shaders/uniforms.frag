#version 300 es // OpenGL ES 3.0

#ifdef GL_ES
precision mediump float;
#endif

//#include <flutter/runtime_effect.glsl>

#define PI 3.1415926538

uniform vec2 iResolution; // viewport resolution (in pixels)
uniform float iTime; // time in seconds since the shader started

out vec4 fragColor;

float interpolate(float a, float b, float t) {
    return a + (b - a) * t;
}

float colorSin(float time) {
    return (sin(time * 2.0f * PI) + 1.0f) / 2.0f;
}

float colorCos(float time) {
    return (cos(time * 2.0f * PI) + 1.0f) / 2.0f;
}

float colorSinSlow(float time) {
    return (sin(time * 2.0f * PI / 4.0f) + 1.0f) / 2.0f;
}

void main() {
    //vec2 currentPos = FlutterFragCoord().xy;
    float r = colorSin(iTime);
    float g = colorCos(iTime);
    fragColor = vec4(r, g, .0f, 1.0f);
}