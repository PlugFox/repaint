/*float evalColor(float time, float scale, float min, float max) {
    return ((sin(time / scale) + 1.0f) / 2.0f) * ((max - min) + min);
}*/

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('math', () {
    test('interpolation', () {
      double interpolate(double a, double b, double t) => a + (b - a) * t;
      expect(interpolate(0, 1, 0), 0);
      expect(interpolate(0, 1, 1), 1);
      expect(interpolate(0, 1, 0.5), 0.5);
      expect(interpolate(0, 1, 0.25), 0.25);
      expect(interpolate(0, 1, 0.75), 0.75);
      print(interpolate(0, 4, 0.5));
    });

    test('clamp', () {
      double clamp(double value, double min, double max) =>
          math.min(math.max(value, min), max);
      expect(clamp(0, 0, 1), 0);
      expect(clamp(1, 0, 1), 1);
      expect(clamp(0.5, 0, 1), 0.5);
      expect(clamp(0.25, 0, 1), 0.25);
      expect(clamp(0.75, 0, 1), 0.75);
    });

    test('Time sinus', () {
      double evalColor(
        double time, {
        double scale = 4,
        double min = 0,
        double max = 1,
      }) =>
          ((math.sin(time * scale * math.pi) + 1) / 2) * (max - min) + min;
      final values = <double>[
        for (var i = 0; i < 30; i++) (i % 10) / 10,
      ];
      /* print(values
          .map((e) => e)
          .map(evalColor)
          .map((e) => e.toStringAsFixed(2))
          .join('\n')); */
    });
  });
}
