import 'dart:ui' as ui;

import 'package:repaint/repaint.dart';
import 'package:test/test.dart';

void main() => group('Quadtree', () {
      test('Create', () {
        expect(
          () => QuadTree(
            boundary: const ui.Rect.fromLTWH(0, 0, 100, 100),
            capacity: 4,
          ),
          returnsNormally,
        );
      });

      test('Insert', () {
        final qt = QuadTree(
          boundary: const ui.Rect.fromLTWH(0, 0, 100, 100),
          capacity: 4,
        );
        expect(
          () => qt.insert(
            HitBox.rect(
              width: 10,
              height: 10,
              x: 10,
              y: 10,
            ),
          ),
          returnsNormally,
        );
      });

      test('Query', () {
        final qt = QuadTree(
          boundary: const ui.Rect.fromLTWH(0, 0, 100, 100),
          capacity: 4,
        )..insert(
            HitBox.rect(
              width: 10,
              height: 10,
              x: 10,
              y: 10,
            ),
          );
        expect(
          () => qt.query(
            const ui.Rect.fromLTWH(
              10,
              10,
              10,
              10,
            ),
          ),
          returnsNormally,
        );
        expect(
          qt.query(
            const ui.Rect.fromLTWH(
              10,
              10,
              10,
              10,
            ),
          ),
          allOf(
            isNotEmpty,
            hasLength(1),
            contains(
              HitBox.rect(
                width: 10,
                height: 10,
                x: 10,
                y: 10,
              ),
            ),
          ),
        );
      });
    });
