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
              'Frame rate: ${frameRate ?? 'unlimited'}',
              style: const TextStyle(
                height: 1,
                color: Colors.white,
                fontSize: 10,
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
                  height: 128 * 2 + 8,
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
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
