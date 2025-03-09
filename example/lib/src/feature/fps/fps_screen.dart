import 'package:flutter/material.dart';
import 'package:repaint/repaint.dart';
import 'package:repaintexample/src/common/widget/app.dart';

/// {@template fps_screen}
/// FpsScreen widget.
/// {@endtemplate}
class FpsScreen extends StatefulWidget {
  /// {@macro fps_screen}
  const FpsScreen({
    super.key, // ignore: unused_element
  });

  @override
  State<FpsScreen> createState() => _FpsScreenState();
}

class _FpsScreenState extends State<FpsScreen> {
  final RePainter _painter = FrameRateGraph();

  Widget fps(int? frameRate) {
    int second = 0;
    int counter = 0;
    int result = 0;
    return SizedBox.square(
      dimension: 128,
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: RePaint.inline(
              frameRate: frameRate,
              repaintBoundary: true,
              render: (box, state, canvas) {
                final now = DateTime.now();
                if (now.second != second) {
                  second = now.second;
                  result = counter;
                  counter = 0;
                }
                counter++;
                canvas.drawRect(
                  Offset.zero & box.size,
                  Paint()
                    ..color = Colors.black
                    ..style = PaintingStyle.fill,
                );
                final text = TextPainter(
                  maxLines: 1,
                  text: TextSpan(
                    text: 'FPS: $result',
                    style: const TextStyle(
                      height: 1,
                      color: Colors.white,
                      fontSize: 24,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  textDirection: TextDirection.ltr,
                )..layout();
                text.paint(
                  canvas,
                  Offset(
                    box.size.width / 2 - text.width / 2,
                    box.size.height / 2 - text.height / 2,
                  ),
                );
              },
            ),
          ),
          Positioned(
            left: 8,
            top: 8,
            height: 12,
            right: 8,
            child: Text(
              'Frame rate limit: ${frameRate ?? 'unlimited'}',
              style: const TextStyle(
                height: 1,
                color: Colors.white,
                fontSize: 9,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('FPS'),
          leading: BackButton(
            onPressed: () => App.pop(context),
          ),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: SizedBox(
                  width: 128 * 4 + 8 * 3,
                  height: 128 * 3 + 8 * 2,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      SizedBox(
                        width: 128 * 4 + 8 * 3,
                        height: 128,
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Expanded(child: fps(0)),
                            const SizedBox(width: 8),
                            Expanded(child: fps(15)),
                            const SizedBox(width: 8),
                            Expanded(child: fps(24)),
                            const SizedBox(width: 8),
                            Expanded(child: fps(30)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: 128 * 4 + 8 * 3,
                        height: 128,
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            Expanded(child: fps(60)),
                            const SizedBox(width: 8),
                            Expanded(child: fps(90)),
                            const SizedBox(width: 8),
                            Expanded(child: fps(120)),
                            const SizedBox(width: 8),
                            Expanded(child: fps(null)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 128,
                        child: RePaint(
                          painter: _painter,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

final class FrameRateGraph extends RePainterBase {
  final List<int> _updates = <int>[];
  final List<int> _renders = <int>[];
  int _updatesSync = 0;
  int _rendersSync = 0;

  final Paint _bgPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.fill
    ..isAntiAlias = false;

  final Paint _linePaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 2
    ..strokeCap = StrokeCap.square
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;

  final Paint _fgPaint = Paint()
    ..color = Colors.white38
    ..strokeWidth = 1
    ..strokeCap = StrokeCap.square
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;

  final Paint _updatesPaint = Paint()
    ..color = Colors.blue
    ..style = PaintingStyle.fill
    ..isAntiAlias = false;

  final Paint _rendersPaint = Paint()
    ..color = Colors.red
    ..style = PaintingStyle.fill
    ..isAntiAlias = false;

  final TextPainter _text = TextPainter(
    maxLines: 1,
    textDirection: TextDirection.ltr,
  );

  void _addUpdate() {
    final newSync = DateTime.now().millisecondsSinceEpoch;
    if (newSync - _updatesSync < Duration.millisecondsPerSecond) {
      _updates[_updates.length - 1]++;
    } else {
      _updates.add(1);
      _updatesSync = newSync;
    }
  }

  void _addRender() {
    final newSync = DateTime.now().millisecondsSinceEpoch;
    if (newSync - _rendersSync < Duration.millisecondsPerSecond) {
      _renders.last++;
    } else {
      _renders.add(1);
      _rendersSync = newSync;
    }
  }

  @override
  void update(RePaintBox box, Duration elapsed, double delta) {
    _addUpdate();
  }

  @override
  void paint(covariant RePaintBox box, PaintingContext context) {
    _addRender();

    final canvas = context.canvas;

    // Draw background
    canvas.drawRect(
      Offset.zero & box.size,
      _bgPaint,
    );

    canvas.save();
    canvas.translate(8, 8);
    {
      // Draw chart
      final size = Size(box.size.width - 16, box.size.height - 16);
      canvas.clipRect(
        Rect.fromLTRB(-2, -2, size.width + 2, size.height + 2),
        doAntiAlias: false,
      );

      // Draw last 60 updates
      final updates = _updates.reversed.take(60).toList(growable: false);
      final w = size.width / 60;
      final h = size.height / 120;
      for (var i = 0; i < updates.length; i++) {
        final x = size.width - i * w - 8;
        final y = size.height - updates[i] * h;
        canvas.drawRect(
          Rect.fromLTWH(x, y, w, updates[i] * h),
          _updatesPaint,
        );
      }

      // Draw last 60 renders
      final renders = _renders.reversed.take(60).toList(growable: false);
      for (var i = 0; i < renders.length; i++) {
        final x = size.width - i * w - 8;
        final y = size.height - renders[i] * h;
        canvas.drawRect(
          Rect.fromLTWH(x, y, w, renders[i] * h),
          _rendersPaint,
        );
      }

      // Draw FPS lines
      const fps = <int>[120, 90, 60, 30];
      for (final f in fps) {
        final y = size.height - size.height * f / 120;
        canvas.drawLine(
          Offset(0, y),
          Offset(size.width, y),
          _fgPaint,
        );
        _text
          ..text = TextSpan(
            text: '$f',
            style: const TextStyle(
              height: 1,
              color: Colors.white,
              fontSize: 10,
              overflow: TextOverflow.ellipsis,
            ),
          )
          ..layout()
          ..paint(
            canvas,
            Offset(4, y + 1),
          );
      }
      canvas.drawLine(
        Offset(size.width + 1, 0),
        Offset(size.width + 1, size.height),
        _fgPaint,
      );

      // Draw legend
      _text
        ..text = TextSpan(
          text: 'Updates: ${updates.length > 1 ? updates[1] : '_'}/s',
          style: const TextStyle(
            height: 1,
            color: Colors.blue,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            overflow: TextOverflow.clip,
          ),
        )
        ..layout(maxWidth: 96)
        ..paint(
          canvas,
          const Offset(32, 4),
        )
        ..text = TextSpan(
          text: 'Renders: ${renders.length > 1 ? renders[1] : '_'}/s',
          style: const TextStyle(
            height: 1,
            color: Colors.red,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            overflow: TextOverflow.clip,
          ),
        )
        ..layout(maxWidth: 96)
        ..paint(
          canvas,
          const Offset(128, 4),
        );

      // Draw chart lines
      canvas
        ..drawLine(
          const Offset(0, 0),
          Offset(0, size.height),
          _linePaint,
        )
        ..drawLine(
          Offset(0, size.height),
          Offset(size.width + 1, size.height),
          _linePaint,
        );
    }

    canvas.restore();
  }
}
