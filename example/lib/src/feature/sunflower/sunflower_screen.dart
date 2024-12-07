import 'dart:math' as math;

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
  final SunflowerPainter _painter = SunflowerPainter();

  @override
  void initState() {
    super.initState();
    _progress.addListener(_updateSeeds);
  }

  void _updateSeeds() => _painter.setProgress(_progress.value);

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
                                  '$value%',
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

  void setProgress(int progress) => _seeds = (_maxSeeds * progress) ~/ 100;

  @override
  void internalUpdate(RePaintBox box, Duration elapsed, double delta) {}

  @override
  void internalPaint(RePaintBox box, PaintingContext context) {
    final canvas = context.canvas;
    final size = box.size;
    final radius = size.shortestSide / 2;
    final center = size.center(Offset.zero);
    final outerDotRadius = (size.shortestSide / _maxSeeds) * 10;
    final innerDotRadius = (size.shortestSide / _maxSeeds) * 10;
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

    var j = 0;
    paint = Paint()
      ..color = Colors.deepPurple
      ..style = PaintingStyle.fill
      ..strokeWidth = 4
      ..isAntiAlias = false
      ..blendMode = BlendMode.src
      ..filterQuality = FilterQuality.none;
    for (var i = 0; i < _seeds; i++) {
      canvas.drawCircle(
        center + _evalOuter(radius, _maxSeeds, i),
        outerDotRadius,
        paint,
      );
      j++;
    }
    paint = Paint()
      ..color = Colors.deepOrange
      ..style = PaintingStyle.fill
      ..strokeWidth = 4
      ..isAntiAlias = false
      ..blendMode = BlendMode.src
      ..filterQuality = FilterQuality.none;
    for (var i = _seeds; i < _maxSeeds; i++) {
      canvas.drawCircle(
        center + _evalInner(radius, _maxSeeds, i),
        innerDotRadius,
        paint,
      );
      j++;
    }
    if (j != _maxSeeds) {
      throw StateError('Invalid seed count: $j');
    }
  }
}
