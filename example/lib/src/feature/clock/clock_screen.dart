import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:repaint/repaint.dart';
import 'package:repaintexample/src/common/widget/app.dart';

class ClockScreen extends StatelessWidget {
  const ClockScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Clock'),
          leading: BackButton(
            onPressed: () => App.pop(context),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: RePaint.inline<Paint>(
              frameRate: 1,
              setUp: (box) => Paint()
                ..color = Colors.black
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2,
              render: (box, paint, canvas) {
                final size = box.size; // Get the size of the box
                final now = DateTime.now(); // Get the current time

                final center = size.center(Offset.zero);
                final radius = size.shortestSide / 3;

                // Draw the clock face
                canvas.drawCircle(center, radius, paint);

                final textPainter = TextPainter(
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.ltr,
                );

                // Draw the clock numbers
                for (int i = 1; i <= 12; i++) {
                  final angle =
                      math.pi / 6 * (i - 3); // Positioning the numbers
                  final numberPosition = Offset(
                    center.dx + radius * 0.8 * math.cos(angle),
                    center.dy + radius * 0.8 * math.sin(angle),
                  );

                  textPainter
                    ..text = TextSpan(
                      text: '$i',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: radius * 0.15,
                      ),
                    )
                    ..layout()
                    ..paint(
                      canvas,
                      numberPosition -
                          Offset(textPainter.width / 2, textPainter.height / 2),
                    );
                }

                // Draw the hour hand
                final hourAngle =
                    math.pi / 6 * (now.hour % 12 + now.minute / 60) -
                        math.pi / 2;
                final hourHandLength = radius * 0.5;
                paint
                  ..color = Colors.black
                  ..strokeWidth = 4;
                canvas.drawLine(
                  center,
                  Offset(
                    center.dx + hourHandLength * math.cos(hourAngle),
                    center.dy + hourHandLength * math.sin(hourAngle),
                  ),
                  paint,
                );

                // Draw the minute hand
                final minuteAngle = math.pi / 30 * now.minute - math.pi / 2;
                final minuteHandLength = radius * 0.7;
                paint
                  ..color = Colors.blue
                  ..strokeWidth = 3;
                canvas.drawLine(
                  center,
                  Offset(
                    center.dx + minuteHandLength * math.cos(minuteAngle),
                    center.dy + minuteHandLength * math.sin(minuteAngle),
                  ),
                  paint,
                );

                // Draw the second hand
                final secondAngle = math.pi / 30 * now.second - math.pi / 2;
                final secondHandLength = radius * 0.9;
                paint
                  ..color = Colors.red
                  ..strokeWidth = 2;
                canvas.drawLine(
                  center,
                  Offset(
                    center.dx + secondHandLength * math.cos(secondAngle),
                    center.dy + secondHandLength * math.sin(secondAngle),
                  ),
                  paint,
                );
              },
            ),
          ),
        ),
      );
}
