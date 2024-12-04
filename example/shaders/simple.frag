#version 460 core

#ifdef GL_ES
// For mobile and web devices, precision mediump is recommended
precision mediump float;
#endif

//#include <flutter/runtime_effect.glsl>

out vec4 pc_fragColor;

// https://thebookofshaders.com/02/
// https://docs.flutter.dev/ui/design/graphics/fragment-shaders
void main() {
    //vec2 currentPos = FlutterFragCoord().xy;
    pc_fragColor = vec4(1.0, 0.0, 0.5, 1.0); // red, green, blue, alpha
}