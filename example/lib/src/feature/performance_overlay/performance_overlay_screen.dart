import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:repaint/repaint.dart';

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
        body: RePaint(
          painter: _repainter,
        ),
      );
}

final class PerformanceOverlayPainter extends RePainterBase {
  int _optionsMask = 0;
  final Map<String, String> _metrics = <String, String>{};

  void setOptionsMask(Set<PerformanceOverlayOption> optionsMask) =>
      _optionsMask =
          optionsMask.fold(0, (mask, option) => mask | (1 << option.index));

  @override
  void mount(RePaintBox box, PipelineOwner owner) {
    setOptionsMask(PerformanceOverlayOption.values.toSet());
    _metrics.clear();
  }

  void _paintPerformanceOverlayLayer(Rect rect, PaintingContext context) =>
      context.addLayer(PerformanceOverlayLayer(
        overlayRect: rect,
        optionsMask: _optionsMask,
      ));

  void _paintMetricsLayer(Rect rect, PaintingContext context) {
    final buffer = StringBuffer();
    for (final (int _, MapEntry(key: String label, value: String value))
        in _metrics.entries.indexed) {
      buffer.writeln('$label: $value');
    }
    final text = buffer.toString();
    if (text.isEmpty) return;
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width);
    textPainter.paint(context.canvas, rect.topLeft);
  }

  @override
  void update(RePaintBox box, Duration elapsed, double delta) {
    // Update the scene.
  }

  @override
  void paint(RePaintBox box, PaintingContext context) {
    const maxWidth = 480.0;
    final canvas = context.canvas;
    final paintBounds = box.paintBounds;
    canvas
      ..drawRect(
        paintBounds,
        Paint()
          ..color = Colors.lightBlue.withOpacity(0.5)
          ..style = PaintingStyle.fill
          ..strokeWidth = 2,
      )
      ..save() /* ..transform(Matrix4.identity().scaled(.5, .5).storage) */;
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
    _paintMetricsLayer(metricsRect, context);
    _paintPerformanceOverlayLayer(perfRect, context);
    context.canvas.restore();
  }
}
