// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:repaint/repaint.dart';
import 'package:repaintexample/src/common/widget/app.dart';
import 'package:repaintexample/src/feature/performance_overlay/performance_overlay_screen.dart';

/// {@template sunflower_screen}
/// SunflowerScreen widget.
/// {@endtemplate}
class SunflowerScreen extends StatefulWidget {
  /// {@macro sunflower_screen}
  const SunflowerScreen({
    super.key, // ignore: unused_element
  });

  @override
  State<SunflowerScreen> createState() => _SunflowerScreenState();
}

class _SunflowerScreenState extends State<SunflowerScreen> {
  final ValueNotifier<int> _progress = ValueNotifier<int>(50);
  final SunflowerPainter _painter = SunflowerPainter(max: 20000);

  @override
  void initState() {
    super.initState();
    _progress.addListener(_updateSeeds);
    _updateSeeds();
  }

  void _updateSeeds() => _painter.setProgress(_progress.value);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _painter.setTheme(Theme.of(context));
  }

  @override
  void dispose() {
    _progress
      ..removeListener(_updateSeeds)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sunflower'),
        leading: BackButton(
          onPressed: () => App.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: FittedBox(
                      alignment: Alignment.center,
                      fit: BoxFit.scaleDown,
                      clipBehavior: Clip.none,
                      child: SizedBox.square(
                        dimension: 720,
                        child: RePaint(
                          painter: _painter,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8.0),
                SizedBox(
                  height: 72,
                  child: FittedBox(
                    alignment: Alignment.center,
                    fit: BoxFit.scaleDown,
                    clipBehavior: Clip.none,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        SizedBox(
                          width: 300,
                          child: ValueListenableBuilder<int>(
                            valueListenable: _progress,
                            builder: (context, value, child) => Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Slider(
                                  min: 0,
                                  max: 100,
                                  value: value.toDouble(),
                                  onChanged: (val) => _progress.value =
                                      val.round().clamp(0, 100),
                                ),
                                Text(
                                  '$value% (${_painter._seeds} seeds)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox.square(
                          dimension: 48,
                          child: IconButton(
                            icon: const Icon(Icons.bug_report),
                            onPressed: () =>
                                _painter.switchPerformanceOverlay(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SunflowerPainter extends PerformanceOverlayPainter {
  SunflowerPainter({
    int max = 10000,
  })  : _maxSeeds = max,
        _positions = Float32List(max * 6),
        _colors = Int32List(max * 3),
        _vertices = Vertices.raw(
          VertexMode.triangles,
          Float32List(0),
          colors: Int32List(0),
        ),
        _theme = ThemeData.light() {
    _initVertices();
  }

  /// Speed of the sunflower animation
  static const double speed = 0.001;

  /// Sunflower padding to the edge of the canvas 0..1
  static const double padding = 0.3;

  /// Tau (τ) is the ratio of a circle's circumference to its radius
  static const double tau = math.pi * 2;

  /// Phi (φ) is the golden ratio (1 + √5) / 2
  static final double phi = (math.sqrt(5) + 1) / 2;

  static double _lerpDouble(double a, double b, double t) =>
      a * (1.0 - t) + b * t;

  static Offset _lerpOffset(Offset a, Offset b, double t) =>
      Offset(_lerpDouble(a.dx, b.dx, t), _lerpDouble(a.dy, b.dy, t));

  static Offset _evalOuter(double radius, int max, int i) {
    final theta = i * tau / (max - 1);
    final r = radius;
    return Offset(r * math.cos(theta), r * math.sin(theta));
  }

  static Offset _evalInner(double radius, int max, int i) {
    final theta = i * tau / phi;
    final r = math.sqrt(i / (max + 0.5)) * radius * (1 - padding);
    return Offset(r * math.cos(theta), r * math.sin(theta));
  }

  final int _maxSeeds;
  int _seeds = 0;

  ThemeData _theme;

  final Float32List _positions;

  final Int32List _colors;

  Vertices _vertices;

  void _initVertices() {
    _vertices = Vertices.raw(
      VertexMode.triangles,
      _positions,
      colors: _colors,
    );
  }

  void setProgress(int progress) => _seeds = (_maxSeeds * progress) ~/ 100;

  void setTheme(ThemeData theme) => _theme = theme;

  /// Генерирует вершины равнобедренного треугольника, вписанного в окружность
  /// с радиусом [radius] и центром в точке [center].
  static List<double> generateIsoscelesPoints(
    Offset center, [
    double radius = 6,
  ]) {
    // Угол между вершинами треугольника в радианах
    const angleStep = 2 * math.pi / 3; // 120 градусов
    // Начальный угол
    const startAngle = -math.pi / 2; // Вершина треугольника направлена вверх
    // Создаем массив для хранения точек треугольника
    final result = List<double>.filled(6, 0, growable: false);
    // Заполняем массив точками треугольника
    for (var i = 0, x = 0, y = 1; x < 5; i++, x += 2, y += 2) {
      final angle = startAngle + angleStep * i;
      result[x] = center.dx + radius * math.cos(angle);
      result[y] = center.dy + radius * math.sin(angle);
    }
    return result;
  }

  @override
  void internalUpdate(RePaintBox box, Duration elapsed, double delta) {
    final size = box.size;
    final radius = size.shortestSide / 2; // Радиус окружности
    final center = size.center(Offset.zero); // Центр окружности
    final outerDotColor = _theme.colorScheme.primary.value;
    final innerDotColor = _theme.colorScheme.secondary.value;

    // 120 градусов
    const angleStep = 2 * math.pi / 3;
    // Начальный угол (вершина треугольника направлена вверх)
    const startAngle = -math.pi / 2;
    // Добавляем вращение в зависимости от времени
    final rotationAngle =
        elapsed.inMilliseconds / 1000.0 * math.pi; // Скорость вращения
    // Устанавливаем вершины треугольника
    for (var i = 0; i < _maxSeeds; i++) {
      final isOuter = i < _seeds;
      // Центр треугольника
      final triCenter = center +
          (isOuter
              ? _evalOuter(radius, _maxSeeds, i)
              : _evalInner(radius, _maxSeeds, i));
      final triRadius = isOuter ? 20.0 : 40.0;
      final triPositionOffset = i * 6;
      final triColorOffset = i * 3;
      for (var j = 0, x = 0, y = 1; j < 3; j++, x += 2, y += 2) {
        final angle = startAngle + angleStep * j + rotationAngle;
        // Устанавливаем вершины треугольника
        _positions[triPositionOffset + x] =
            triCenter.dx + triRadius * math.cos(angle);
        _positions[triPositionOffset + y] =
            triCenter.dy + triRadius * math.sin(angle);
        // Устанавливаем цвета вершин
        _colors[triColorOffset + j] = isOuter ? outerDotColor : innerDotColor;
      }
    }
    _vertices = Vertices.raw(
      VertexMode.triangles,
      _positions,
      colors: _colors,
    );
  }

  @override
  void internalPaint(RePaintBox box, PaintingContext context) {
    final canvas = context.canvas;
    var paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 4
      ..isAntiAlias = false
      ..blendMode = BlendMode.src
      ..filterQuality = FilterQuality.none;

    canvas.drawRect(
      Offset.zero & box.size,
      paint..color = _theme.canvasColor,
    );

    canvas.drawVertices(
      _vertices,
      BlendMode.src,
      paint,
    );
  }
}
