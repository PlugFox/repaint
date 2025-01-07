import 'dart:typed_data';
import 'dart:ui';

import 'package:repaint/repaint.dart';
import 'package:test/test.dart';

void main() => group('Quadtree', () {
      test('Bytes', () {
        const capacity = 10;
        const objectSize = 5;
        const nodeSize = capacity * objectSize;

        final data = Float32List(64 * nodeSize);
        final ids = Uint32List.sublistView(data);
        expect(ids.length, data.length);

        // First object in node 0
        ids[0] = 0;
        data
          ..[1] = 10
          ..[2] = 10
          ..[3] = 48
          ..[4] = 24;

        // First object in node 1
        ids[nodeSize + 0] = 1;
        data
          ..[nodeSize + 1] = 20
          ..[nodeSize + 2] = 30
          ..[nodeSize + 3] = 12
          ..[nodeSize + 4] = 32;

        var id = 0;
        var idsView = Uint32List.sublistView(
          data,
          id * nodeSize,
          id * nodeSize + nodeSize,
        );
        var dataView = Float32List.sublistView(
          data,
          id * nodeSize,
          id * nodeSize + nodeSize,
        );

        expect(dataView.length, nodeSize);
        expect(idsView.length, dataView.length);
        expect(idsView[0], 0);
        expect(dataView[1], 10);
        expect(dataView[2], 10);
        expect(dataView[3], 48);
        expect(dataView[4], 24);

        id = 1;
        idsView = Uint32List.sublistView(
          data,
          id * nodeSize,
          id * nodeSize + nodeSize,
        );
        dataView = Float32List.sublistView(
          data,
          id * nodeSize,
          id * nodeSize + nodeSize,
        );

        expect(idsView.length, nodeSize);
        expect(idsView[0], 1);
        expect(dataView.length, nodeSize);
        expect(dataView[1], 20);
        expect(dataView[2], 30);
        expect(dataView[3], 12);
        expect(dataView[4], 32);
      });

      test('Create', () {
        expect(
          () => QuadTree(
            boundary: const Rect.fromLTWH(0, 0, 100, 100),
            capacity: 4,
          ),
          returnsNormally,
        );
      });

      test('Insert', () {
        final qt = QuadTree(
          boundary: const Rect.fromLTWH(0, 0, 100, 100),
          capacity: 4,
        );
        expect(
          () => qt.insert(const Rect.fromLTWH(10, 10, 10, 10)),
          returnsNormally,
        );
      });

      /* test('Query', () {
        final qt = QuadTree(
          boundary: const Rect.fromLTWH(0, 0, 100, 100),
          capacity: 4,
        )..insert(const Rect.fromLTWH(10, 10, 10, 10));
        expect(
          () => qt.query(
            HitBox.rect(
              width: 10,
              height: 10,
              x: 10,
              y: 10,
            ),
          ),
          returnsNormally,
        );
        expect(
          qt.query(
            HitBox.square(
              size: 10,
              x: 10,
              y: 10,
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
        expect(
          qt.query(
            HitBox.square(
              size: 10,
            ),
          ),
          isEmpty,
        );
      }); */
    });
