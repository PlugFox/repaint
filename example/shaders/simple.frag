#version 300 es // OpenGL ES 3.0
//#version 460 core // OpenGL 4.6 Core Profile

#ifdef GL_ES
// For mobile and web devices, precision mediump is recommended
precision mediump float;
#endif

//#include <flutter/runtime_effect.glsl>

out vec4 pc_fragColor;

// https://thebookofshaders.com/02/
// https://docs.flutter.dev/ui/design/graphics/fragment-shaders
// https://github.com/Hixie/sky_engine/tree/master/impeller/entity/shaders
// https://github.com/Hixie/sky_engine/tree/master/impeller/compiler/shader_lib/flutter/runtime_effect.glsl
void main() {
    //vec2 currentPos = FlutterFragCoord().xy;
    pc_fragColor = vec4(1.0f, 0.0f, 0.5f, 1.0f); // red, green, blue, alpha
}