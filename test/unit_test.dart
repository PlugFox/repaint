import 'package:flutter/widgets.dart';
import 'package:repaint/repaint.dart';
import 'package:test/test.dart';

import 'src/repainter_fake.dart';

void main() {
  group('Time', () {
    test('Seconds', () {
      const duration = Duration(seconds: 5);
      expect(
        duration.inSeconds * Duration.millisecondsPerSecond,
        equals(5 * 1000),
      );
      expect(
        duration.inSeconds *
            Duration.millisecondsPerSecond *
            Duration.microsecondsPerMillisecond,
        equals(5 * 1000 * 1000),
      );
      expect(
        duration.inSeconds * Duration.microsecondsPerSecond,
        equals(5 * 1000 * 1000),
      );
    });

    test('Delta', () {
      const elapsed = Duration(seconds: 15);
      const previous = Duration(seconds: 14);
      final delta = elapsed - previous;
      final ms = delta.inMicroseconds / Duration.microsecondsPerMillisecond;
      expect(ms, equals(1000));
    });

    test('Frame rate', () {
      const frameRate = 60;
      const deltaMs = 1000 / frameRate;
      expect(deltaMs, equals(1000 / 60));
    });
  });

  group('Unit', () {
    test('Instance', () {
      final widget = RePaint(painter: RePainterFake());
      expect(
        widget,
        allOf(
          isNotNull,
          isA<Widget>(),
          isA<LeafRenderObjectWidget>(),
          isA<RePaint>().having(
            (w) => w.painter,
            'painter',
            allOf(
              isNotNull,
              isA<RePainter>(),
              isA<RePainterBase>(),
              isA<RePainterFake>(),
            ),
          ),
        ),
      );
      expect(
        widget.createElement(),
        isA<RePaintElement>().having(
          (e) => e.widget,
          'widget',
          same(widget),
        ),
      );
      expect(
        widget.createRenderObject(RePaintElement(widget)),
        isA<RePaintBox>()
            .having(
              (r) => r.painter,
              'painter',
              allOf(
                isNotNull,
                isA<RePainter>(),
                isA<RePainterBase>(),
                isA<RePainterFake>(),
              ),
            )
            .having(
              (r) => r.context,
              'context',
              allOf(
                isNotNull,
                isA<BuildContext>(),
                isA<Element>(),
                isA<RePaintElement>(),
              ),
            )
            .having(
              (r) => r.isRepaintBoundary,
              'isRepaintBoundary',
              true,
            )
            .having(
              (r) => r.painter,
              'painter',
              same(widget.painter),
            )
            .having(
              (r) => r.size,
              'size',
              equals(Size.zero),
            ),
      );
    });
  });
}
