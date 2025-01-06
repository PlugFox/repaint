import 'package:flutter/widgets.dart';
import 'package:repaint/repaint.dart';
import 'package:test/test.dart';

import '../fake/repainter_fake.dart';

void main() => group('Repaint', () {
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
