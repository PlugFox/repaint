import 'dart:typed_data';
import 'dart:ui' as ui;

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
            boundary: const ui.Rect.fromLTWH(0, 0, 100, 100),
            capacity: 6,
          ),
          returnsNormally,
        );
      });

      test('Insert', () {
        final qt = QuadTree(
          boundary: const ui.Rect.fromLTWH(0, 0, 100, 100),
          capacity: 6,
        );
        expect(qt.length, equals(0));
        expect(
          () => qt.insert(const ui.Rect.fromLTWH(10, 10, 10, 10)),
          returnsNormally,
        );
        expect(qt.length, equals(1));
        expect(
          () => qt.insert(const ui.Rect.fromLTWH(10, 10, 10, 10)),
          returnsNormally,
        );
        expect(qt.length, equals(2));
      });

      test('Move', () {
        final qt = QuadTree(
          boundary: const ui.Rect.fromLTWH(0, 0, 100, 100),
          capacity: 6,
        );
        final id = qt.insert(const ui.Rect.fromLTWH(10, 10, 10, 10));
        expect(id, isNotNull);
        expect(() => qt.move(id, 10, 10), returnsNormally);
        expect(() => qt.move(id, 20, 20), returnsNormally);
        expect(qt.length, equals(1));
      });

      test('Remove', () {
        final qt = QuadTree(
          boundary: const ui.Rect.fromLTWH(0, 0, 100, 100),
          capacity: 6,
        );
        final id = qt.insert(const ui.Rect.fromLTWH(10, 10, 10, 10));
        expect(id, isNotNull);
        expect(qt.length, equals(1));
        expect(() => qt.remove(id), returnsNormally);
        expect(qt.length, equals(0));
      });

      test('Query', () {
        final qt = QuadTree(
          boundary: const ui.Rect.fromLTWH(0, 0, 100, 100),
          capacity: 6,
        )..insert(const ui.Rect.fromLTWH(10, 10, 10, 10));
        expect(
          () => qt.query(const ui.Rect.fromLTWH(10, 10, 10, 10)),
          returnsNormally,
        );
        var result = qt.query(const ui.Rect.fromLTWH(10, 10, 10, 10));
        expect(
          result,
          isA<QuadTree$QueryResult>()
              .having(
                (qr) => qr.isEmpty,
                'isEmpty',
                isFalse,
              )
              .having(
                (qr) => qr.isNotEmpty,
                'isNotEmpty',
                isTrue,
              )
              .having(
                (qr) => qr.length,
                'length',
                1,
              ),
        );
        final map = result.toMap();
        expect(
          map,
          allOf(
            isA<Map<int, ui.Rect>>(),
            hasLength(1),
          ),
        );
      });

      test('Create/Move/Query/Remove/Optimize/Clear', () {
        final qt = QuadTree(
          boundary: const ui.Rect.fromLTWH(0, 0, 10000, 50000),
          capacity: 6,
        );
        expect(qt.length, equals(0));
        expect(qt.nodes, equals(0));
        for (var i = 0; i < 10; i++) {
          expect(
            () => qt.insert(ui.Rect.fromLTWH(i * 10.0, i * 10.0, 10, 10)),
            returnsNormally,
          );
        }
        expect(qt.length, equals(10));
        expect(qt.nodes, greaterThan(0));
        expect(() => qt.get(10), returnsNormally);
        expect(
          qt.get(10),
          allOf(
            isNotNull,
            isA<ui.Rect>(),
          ),
        );
        for (var i = 0; i < 10; i++) {
          expect(
            () => qt.move(10, i * 10.0, i * 10.0),
            returnsNormally,
          );
        }
        expect(qt.length, equals(10));
        expect(
          qt.query(const ui.Rect.fromLTWH(5, 5, 1000, 1000)).length,
          equals(10),
        );
        expect(qt.optimize, returnsNormally);
        expect(
          qt.query(const ui.Rect.fromLTWH(5, 5, 1000, 1000)).length,
          equals(10),
        );
        expect(qt.length, equals(10));
        expect(() => qt.remove(9), returnsNormally);
        expect(() => qt.remove(5), returnsNormally);
        expect(qt.length, equals(8));
        expect(
          qt.queryIds(const ui.Rect.fromLTWH(-10000, -10000, 20000, 20000)),
          allOf(
            isA<List<int>>(),
            hasLength(8),
            containsAll([0, 1, 2, 3, 4, 6, 7, 8]),
          ),
        );
        expect(qt.optimize, returnsNormally);
        expect(qt.healthCheck(), isEmpty);
        expect(qt.clear, returnsNormally);
      });
    });
