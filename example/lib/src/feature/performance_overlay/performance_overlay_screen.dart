// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:repaint/repaint.dart';
import 'package:repaintexample/src/common/widget/app.dart';

/// {@template performance_overlay_screen}
/// PerformanceOverlayScreen widget.
/// {@endtemplate}
class PerformanceOverlayScreen extends StatefulWidget {
  /// {@macro performance_overlay_screen}
  const PerformanceOverlayScreen({
    super.key, // ignore: unused_element
  });

  @override
  State<PerformanceOverlayScreen> createState() =>
      _PerformanceOverlayScreenState();
}

class _PerformanceOverlayScreenState extends State<PerformanceOverlayScreen> {
  final RePainter _repainter = PerformanceOverlayPainter();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Performance Overlay'),
          leading: BackButton(
            onPressed: () => App.pop(context),
          ),
        ),
        body: SafeArea(
          child: RePaint(
            painter: _repainter,
          ),
        ),
      );
}

class PerformanceOverlayPainter extends RePainterBase {
  PerformanceOverlayPainter();

  int _optionsMask = 0;

  /// Metrics.
  /// 0 - Current second.
  /// 1 - FPS (frames per second)
  /// 2 - Update time (μs)
  /// 3 - Paint time (μs)
  /// 4 - Render time (μs)
  final List<int> _metrics = List<int>.generate(12, (_) => 0, growable: false);
  String _metricsText = '';
  final Stopwatch _stopwatch = Stopwatch();

  /// Set the options mask.
  void _setOptionsMask(Set<PerformanceOverlayOption> optionsMask) =>
      _optionsMask =
          optionsMask.fold(0, (mask, option) => mask | (1 << option.index));

  @override
  @mustCallSuper
  void mount(RePaintBox box, PipelineOwner owner) {
    _setOptionsMask(PerformanceOverlayOption.values.toSet());
    _clearMetrics();
    _stopwatch
      ..reset()
      ..start();
  }

  @override
  @mustCallSuper
  void unmount() {
    _clearMetrics();
    _stopwatch.stop();
    _metricsText = '';
  }

  void _clearMetrics() {
    for (var i = 1; i < _metrics.length; i++) _metrics[i] = 0;
  }

  void _increment(int index, [int value = 1]) => _metrics[index] += value;

  void _paintPerformanceOverlayLayer(Rect rect, PaintingContext context) =>
      context.addLayer(PerformanceOverlayLayer(
        overlayRect: rect,
        optionsMask: _optionsMask,
      ));

  void _paintMetricsLayer(Rect rect, PaintingContext context) {
    if (_metricsText.isEmpty) return;
    final textPainter = TextPainter(
      text: TextSpan(
        text: _metricsText,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          height: 1.0,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width);
    textPainter.paint(context.canvas, rect.topLeft);
  }

  @mustCallSuper
  void internalUpdate(RePaintBox box, Duration elapsed, double delta) {}

  @override
  @nonVirtual
  void update(RePaintBox box, Duration elapsed, double delta) {
    final begin = _stopwatch.elapsed;
    internalUpdate(box, elapsed, delta);
    if (elapsed.inSeconds case int seconds when seconds != _metrics[0]) {
      final buffer = StringBuffer()
        /* ..writeln('Current second: ${_metrics[0]}') */
        ..writeln(
            '${_metrics[1]} fps, ${(1000 / _metrics[1]).toStringAsFixed(2)} ms/f')
        ..writeln('update time: ${(_metrics[2] / 1000).toStringAsFixed(2)} ms')
        ..writeln('paint time: ${(_metrics[3] / 1000).toStringAsFixed(2)} ms')
        ..writeln('render time: ${(_metrics[4] / 1000).toStringAsFixed(2)} ms');
      _metricsText = buffer.toString();
      _clearMetrics();
      _metrics[0] = seconds;
    }
    _increment(2, (_stopwatch.elapsed - begin).inMicroseconds);
  }

  @mustCallSuper
  void internalPaint(RePaintBox box, PaintingContext context) {}

  @override
  @nonVirtual
  void paint(RePaintBox box, PaintingContext context) {
    const maxWidth = 480.0;
    final canvas = context.canvas;
    final paintBounds = box.paintBounds;
    var begin = _stopwatch.elapsed;
    internalPaint(box, context);
    canvas.save();
    final cardPaint = Paint()
      ..color = Colors.black26
      ..style = PaintingStyle.fill
      ..blendMode = BlendMode.srcOver
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;
    var rect = Rect.fromLTWH(
      8,
      8,
      math.min(paintBounds.width - 16, maxWidth),
      math.min(paintBounds.height - 16, 128 * 3 + 16),
    );
    // Draw card for performance & metrics.
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      cardPaint,
    );
    final perfRect = Rect.fromLTWH(
      rect.left,
      rect.top,
      rect.width,
      rect.height * 2 / 3 - 8,
    );
    final metricsRect = Rect.fromLTWH(
      perfRect.left,
      rect.top + perfRect.height,
      perfRect.width,
      rect.height - perfRect.height,
    ).deflate(8); // Padding
    _paintMetricsLayer(metricsRect, context); // Paint metrics
    _paintPerformanceOverlayLayer(perfRect, context); // Paint performance
    context.canvas.restore();
    _increment(3, (_stopwatch.elapsed - begin).inMicroseconds);
    begin = _stopwatch.elapsed;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _increment(1);
      _increment(4, (_stopwatch.elapsed - begin).inMicroseconds);
    });
  }
}
