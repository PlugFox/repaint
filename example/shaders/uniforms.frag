#version 300 es // OpenGL ES 3.0

#ifdef GL_ES
precision mediump float;
#endif

#include <flutter/runtime_effect.glsl>

#define PI 3.1415926538

uniform vec2 iResolution; // viewport resolution (in pixels)
uniform vec2 iMouse; // mouse pixel coords
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

void main() {
    // gl_FragCoord.xy - координаты текущего пикселя в пикселях
    // Отсчет начинается в левом нижнем углу
    //vec2 uv = gl_FragCoord.xy / iResolution; // normalized coordinates

    // Flutter меряет координаты в пикселях, а не в диапазоне от 0.0 до 1.0
    // Отсчет начинается в левом верхнем углу
    vec2 pos = FlutterFragCoord().xy; // current pixel coordinates

    // Нормализуем координаты в диапазон от 0.0 до 1.0
    vec2 uv = pos / iResolution; // normalized coordinates

    // Цвета зависят от времени
    float r = colorSin(iTime); // red (0.0 to 1.0)
    float g = colorCos(iTime / 4.0f); // green (0.0 to 1.0)
    float b = interpolate(0.5f, 1.0f, colorSin(iTime / 2.0f)); // blue (0.5 to 1.0)

    // Разбиваем экран на 4 части, каждая часть будет рисовать что-то свое
    if(uv.x < 0.5f && uv.y < 0.5f) {
        // Верхний левый угол
        // Заливаем градиентом зависимым от времени
        fragColor = vec4(r, g, b, 1.0f);
    } else if(uv.x > 0.5f && uv.y < 0.5f) {
        // Верхний правый угол
        // Рисум круг вокруг мыши с радиусом 5 пикселей
        vec2 mouse = iMouse / iResolution; // normalized mouse coordinates
        float dst = 10.0f;
        if(mouse.x > 0.5f && mouse.y < 0.5f) {
            // Мышь в верхнем правом углу
            dst = abs(distance(iMouse.xy, pos.xy)); // distance from mouse to pixel
        }
        if(dst < 5.0f) {
            // Дистанция от мыши до пикселя меньше 5 пикселей - рисуем круг
            fragColor = vec4(uv.x, uv.y, uv.x * uv.y, 1.0f);
        } else {
            // Дистанция от мыши до пикселя больше 5 пикселей - инвертируем градиент
            fragColor = vec4(1.0f - uv.x, 1.0f - uv.y, 1.0f - uv.x * uv.y, 1.0f);
        }
    } else if(uv.x < 0.5f && uv.y > 0.5f) {
        // Нижний левый угол
        // Высвечиваем расстояние от мыши до центра прямоугольника
        vec2 mouse = iMouse / iResolution; // normalized mouse coordinates
        if(mouse.x < 0.5f && mouse.y > 0.5f) {
            float dst = distance(mouse.xy, vec2(0.25f, 0.75f));
            // Чем ближе мышь к центру, тем светлее цвет
            fragColor = vec4(1 - (dst * 4), 1 - (dst * 4), 1 - (dst * 4), 1.0f);
        } else {
            // Если мышь не в нижнем левом углу - черный цвет
            fragColor = vec4(0, 0, 0, 1.0f);
        }
    } else if(uv.x > 0.5f && uv.y > 0.5f) {
        // Нижний правый угол
        // Заливаем цветом зависимым от координаты и времени
        fragColor = vec4(uv.x * 4 * r, uv.y * 4 * g, b, 1.0f);
    }
}