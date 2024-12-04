// https://thebookofshaders.com/02/
// https://docs.flutter.dev/ui/design/graphics/fragment-shaders

#version 460 core

#ifdef GL_ES
precision mediump float;
#endif

//#include <flutter/runtime_effect.glsl>

out vec4 fragColor;

void main() {
    //vec2 currentPos = FlutterFragCoord().xy;
    fragColor = vec4(1.0, 0.0, 0.5, 1.0);
}