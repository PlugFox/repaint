import 'dart:math' as math;
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
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Sunflower'),
          leading: BackButton(
            onPressed: () => App.pop(context),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
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
                  child: Center(
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
      );
}

class SunflowerPainter extends PerformanceOverlayPainter {
  SunflowerPainter({
    int max = 10000,
  }) : _maxSeeds = max;

  /// Sunflower padding to the edge of the canvas 0..1
  static const double padding = 0.15;

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

  ThemeData _theme = ThemeData.light();

  Vertices _vertices = Vertices(
    VertexMode.triangles,
    <Offset>[],
    colors: <Color>[],
  );

  void setProgress(int progress) => _seeds = (_maxSeeds * progress) ~/ 100;

  void setTheme(ThemeData theme) => _theme = theme;

  /// Генерирует вершины равнобедренного треугольника, вписанного в окружность
  /// с радиусом [radius] и центром в точке [center].
  static List<Offset> generateIsoscelesTriangle(Offset center,
      [double radius = 6]) {
    // Угол между вершинами треугольника в радианах
    const angleStep = 2 * math.pi / 3; // 120 градусов
    // Начальный угол
    const startAngle = -math.pi / 2; // Вершина треугольника направлена вверх
    // Вычисляем три вершины треугольника
    return List<Offset>.generate(
      3,
      (index) {
        final angle = startAngle + angleStep * index;
        return Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        );
      },
      growable: false,
    );
  }

  @override
  void internalUpdate(RePaintBox box, Duration elapsed, double delta) {
    final size = box.size;
    final radius = size.shortestSide / 2;
    final center = size.center(Offset.zero);
    /* final outerDotRadius = (size.shortestSide / _maxSeeds) * 10;
    final innerDotRadius = (size.shortestSide / _maxSeeds) * 10; */
    _vertices = Vertices(
      VertexMode.triangles,
      <Offset>[
        for (var i = 0; i < _seeds; i++)
          ...generateIsoscelesTriangle(
            center + _evalOuter(radius, _maxSeeds, i),
            7,
          ),
        for (var i = _seeds; i < _maxSeeds; i++)
          ...generateIsoscelesTriangle(
            center + _evalInner(radius, _maxSeeds, i),
            10,
          ),
      ],
      colors: <Color>[
        for (var i = 0; i < _seeds; i++) ...const [
          Colors.deepPurple,
          Colors.blue,
          Colors.lightBlue,
        ],
        for (var i = _seeds; i < _maxSeeds; i++) ...const [
          Colors.deepOrange,
          Colors.orange,
          Colors.amber,
        ],
      ],
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

    /* canvas.drawRect(
      Offset.zero & size,
      paint..color = Colors.lightBlue,
    ); */

    /* paint.color = Colors.deepPurple;
    for (var i = 0; i < _seeds; i++) {
      canvas.drawCircle(
        center + _evalOuter(radius, _maxSeeds, i),
        outerDotRadius,
        paint,
      );
    }
    paint.color = Colors.deepOrange;
    for (var i = _seeds; i < _maxSeeds; i++) {
      canvas.drawCircle(
        center + _evalInner(radius, _maxSeeds, i),
        innerDotRadius,
        paint,
      );
    } */

    canvas.drawVertices(
      _vertices,
      BlendMode.src,
      paint,
    );
  }
}
