import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repaint/repaint.dart';

import 'src/repainter_fake.dart';

void main() {
  group('Widget', () {
    testWidgets(
      'Pump RePaint',
      (tester) async {
        final painter = RePainterFake();
        final widget = RePaint(painter: painter);
        await tester.pumpWidget(widget);
        expect(find.byWidget(widget), allOf(isNotNull, findsOneWidget));
        expect(
          find.byType(RePaint).evaluate(),
          allOf(isNotNull, isNotEmpty, hasLength(1)),
        );
        final context = find.byType(RePaint).evaluate().single;
        expect(
          context,
          allOf(
            isNotNull,
            isA<Element>(),
            isA<RePaintElement>()
                .having(
                  (e) => e.widget,
                  'widget',
                  same(widget),
                )
                .having(
                  (e) => e.renderObject,
                  'renderObject',
                  allOf(
                    isNotNull,
                    isA<RenderObject>(),
                    isA<RePaintBox>(),
                  ),
                ),
          ),
        );
        await tester.pumpWidget(RePaint(painter: painter));
        expect(find.byType(RePaint), findsOneWidget);
        final box =
            find.byType(RePaint).evaluate().single.renderObject as RePaintBox;
        expect(
          box,
          allOf(
            isNotNull,
            isA<RenderObject>(),
            isA<RePaintBox>()
                .having(
                  (r) => r.context.widget,
                  'painter',
                  allOf(
                    isNotNull,
                    isA<Widget>(),
                    isA<LeafRenderObjectWidget>(),
                    isA<RePaint>(),
                    isNot(same(widget)),
                  ),
                )
                .having(
                  (r) => r.painter,
                  'painter',
                  allOf(
                    isNotNull,
                    isA<RePainter>(),
                    isA<RePainterBase>(),
                    isA<RePainterFake>(),
                    same(painter),
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
                    same(context),
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
                  (r) => r.attached,
                  'attached',
                  true,
                )
                .having(
                  (r) => r.owner,
                  'owner',
                  isNotNull,
                )
                .having(
                  (r) => r.hasSize,
                  'hasSize',
                  isTrue,
                )
                .having(
                  (r) => r.size,
                  'size',
                  allOf(
                    isNotNull,
                    isA<Size>(),
                    isNot(equals(Size.zero)),
                  ),
                ),
          ),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        expect(find.byWidget(widget), findsNothing);
        expect(box.attached, isFalse);
      },
    );

    testWidgets('Implicit', (tester) async {
      await tester.pumpWidget(RePaint.inline(
        setUp: (box) => Paint()..color = Colors.red,
        frameRate: 60,
        update: (box, paint, _) =>
            paint..color = paint.color == Colors.red ? Colors.blue : Colors.red,
        render: (box, paint, canvas) =>
            canvas.drawRect(Offset.zero & box.size, paint),
        tearDown: (paint) {},
      ));
      expect(find.byType(RePaint), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 32));
      expect(find.byType(RePaint), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(RePaint), findsNothing);
    });

    testWidgets('Implicit empty', (tester) async {
      await tester.pumpWidget(RePaint.inline(
        render: (_, __, ___) {},
      ));
      expect(find.byType(RePaint), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 32));
      expect(find.byType(RePaint), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(RePaint), findsNothing);
    });
  });
}
