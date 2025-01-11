import 'dart:collection';
import 'dart:ui' as ui;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:flame/collisions.dart' as flame;
import 'package:repaint/repaint.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

// TODO(plugfox): Написать бенчмарк на поиск лучшего capacity для QuadTree
// Mike Matiunin <plugfox@gmail.com>, 08 January 2025

void main() => group(
      'QuadTree benchmark',
      () {
        var report = true;

        /*
          RePaint QuadTree inserts 2(RunTime): 876.593 us.
          RePaint QuadTree inserts(RunTime): 1124.549 us.
          Flame QuadTree inserts(RunTime): 26043.75 us.
        */
        test('Inserts', () {
          final repaint2 = _RePaintQuadTreeInserts2Benchmark();
          if (report)
            // ignore: dead_code
            repaint2.report();
          final repaint = _RePaintQuadTreeInsertsBenchmark();
          if (report)
            // ignore: dead_code
            repaint.report();
          if (repaint.qt.length != 1000)
            throw Exception('Failed to insert all');
          final errors = repaint.qt.healthCheck();
          //if (errors.isNotEmpty) throw Exception(errors.join('\n'));
          expect(errors, isEmpty);
          final flame = _FlameQuadTreeInsertsBenchmark();
          if (report)
            // ignore: dead_code
            flame.report();
          if (!report)
            // ignore: dead_code
            expect(
              repaint.measure(),
              lessThanOrEqualTo(flame.measure()),
            );
        });

        /*
          RePaint QuadTree inserts & removes 2(RunTime): 110.91873528782367 us.
          RePaint QuadTree inserts & removes(RunTime): 120.44225120432381 us.
          Flame QuadTree inserts & removes(RunTime): 2268.315 us.
        */
        test('Inserts and removes', () {
          final repaint2 = _RePaintQuadTreeInsertsAndRemoves2Benchmark();
          if (report)
            // ignore: dead_code
            repaint2.report();
          final repaint = _RePaintQuadTreeInsertsAndRemovesBenchmark();
          if (report)
            // ignore: dead_code
            repaint.report();
          final errors = repaint.qt.healthCheck();
          //if (errors.isNotEmpty) throw Exception(errors.join('\n'));
          expect(errors, isEmpty);
          final flame = _FlameQuadTreeInsertsAndRemovesBenchmark();
          if (report)
            // ignore: dead_code
            flame.report();
          if (!report)
            // ignore: dead_code
            expect(
              repaint.measure(),
              lessThanOrEqualTo(flame.measure()),
            );
        });

        /*
          RePaint QuadTree query ids(RunTime): 569.046 us.
          RePaint QuadTree query map(RunTime): 1259.431 us.
          RePaint QuadTree query(RunTime): 1589.3613193403298 us.
          Flame QuadTree query(RunTime): 2431.795 us.
        */
        test('Static query', () {
          // ~ 560 us to query, 567 us.
          final repaintIds = _RePaintQuadTreeQueryIdsBenchmark();
          if (report)
            // ignore: dead_code
            repaintIds.report();
          var errors = repaintIds.qt.healthCheck();
          //if (errors.isNotEmpty) throw Exception(errors.join('\n'));
          expect(errors, isEmpty);
          // ~ + 510 us to query & + 500 us to create hash map, 1170 us.
          final repaintMap = _RePaintQuadTreeQueryMapBenchmark();
          if (report)
            // ignore: dead_code
            repaintMap.report();
          errors = repaintMap.qt.healthCheck();
          //if (errors.isNotEmpty) throw Exception(errors.join('\n'));
          expect(errors, isEmpty);
          // ~ + 1000 us. to query and + 900 us to create hash map, 1945 us
          final repaintB = _RePaintQuadTreeQueryBenchmark();
          if (report)
            // ignore: dead_code
            repaintB.report();
          errors = repaintB.qt.healthCheck();
          //if (errors.isNotEmpty) throw Exception(errors.join('\n'));
          expect(errors, isEmpty);
          final flame = _FlameQuadTreeQueryBenchmark();
          if (report)
            // ignore: dead_code
            flame.report();
          if (!report)
            // ignore: dead_code
            expect(repaintB.measure(), lessThanOrEqualTo(flame.measure()));
        });

        /*
          RePaint QuadTree move(RunTime): 199.9547 us.
          Flame QuadTree move(RunTime): 306.89086614173226 us.
        */
        test('Move', () {
          final repaint = _RePaintQuadTreeMoveBenchmark();
          if (report)
            // ignore: dead_code
            repaint.report();
          final errors = repaint.qt.healthCheck();
          //if (errors.isNotEmpty) throw Exception(errors.join('\n'));
          expect(errors, isEmpty);
          final flame = _FlameQuadTreeMoveBenchmark();
          if (report)
            // ignore: dead_code
            flame.report();
          if (!report)
            // ignore: dead_code
            expect(repaint.measure(), lessThanOrEqualTo(flame.measure()));
        });

        /*
          6: 4797.539325842697 us. Max depth 10 nodes
          8: 4889.759550561797 us. Max depth 9 nodes
          10: 3929.9825174825173 us. Max depth 8 nodes
          12: 3874.2534965034965 us. Max depth 8 nodes
          14: 3927.8164335664337 us. Max depth 7 nodes
          16: 3682.304195804196 us. Max depth 7 nodes
          18: 3289.215892053973 us. Max depth 7 nodes
          20: 3391.6356821589206 us. Max depth 7 nodes
          22: 3264.529235382309 us. Max depth 6 nodes
          24: 3314.206896551724 us. Max depth 6 nodes
          26: 3485.5034965034965 us. Max depth 6 nodes
          28: 3630.701048951049 us. Max depth 6 nodes
          30: 3602.9562937062938 us. Max depth 6 nodes
        */
        test('Capacity', () {
          final results = <int, String>{};
          for (var i = 6; i < 32; i += 2) {
            final repaint = _RePaintQuadTreeCapacityBenchmark(i);
            final us = repaint.measure();
            results[i] = '$us us. Max depth ${repaint.maxDepth} nodes';
            final errors = repaint.qt.healthCheck();
            //if (errors.isNotEmpty) throw Exception(errors.join('\n'));
            expect(errors, isEmpty);
          }
          if (report)
            // ignore: dead_code, avoid_print
            print(
                results.entries.map((e) => '${e.key}: ${e.value}').join('\n'));
        });
      },
    );

class _RePaintQuadTreeInserts2Benchmark extends BenchmarkBase {
  _RePaintQuadTreeInserts2Benchmark() : super('RePaint QuadTree inserts 2');

  late QT qt;

  @override
  void setup() {
    qt = QT(
      boundary: const ui.Rect.fromLTWH(0, 0, 10000, 10000),
      capacity: 25,
    );
    super.setup();
  }

  @override
  void run() {
    qt.clear();
    for (var i = 0; i < 1000; i++) {
      final box = ui.Rect.fromLTWH(i * 10.0, i * 10.0, 10, 10);
      qt.insert(box);
    }
    qt.optimize();
  }
}

class _RePaintQuadTreeInsertsBenchmark extends BenchmarkBase {
  _RePaintQuadTreeInsertsBenchmark() : super('RePaint QuadTree inserts');

  late QuadTree qt;

  @override
  void setup() {
    qt = QuadTree(
      boundary: const ui.Rect.fromLTWH(0, 0, 10000, 10000),
      capacity: 25,
    );
    super.setup();
  }

  @override
  void run() {
    qt.clear();
    for (var i = 0; i < 1000; i++) {
      final box = ui.Rect.fromLTWH(i * 10.0, i * 10.0, 10, 10);
      qt.insert(box);
    }
    qt.optimize();
  }
}

class _FlameQuadTreeInsertsBenchmark extends BenchmarkBase {
  _FlameQuadTreeInsertsBenchmark() : super('Flame QuadTree inserts');

  static final Vector2 _size = Vector2.all(10);
  late flame.QuadTree qt;

  @override
  void setup() {
    qt = flame.QuadTree<flame.Hitbox<flame.ShapeHitbox>>(
      mainBoxSize: const ui.Rect.fromLTWH(0, 0, 10000, 10000),
      maxObjects: 25,
      maxDepth: 10,
    );
    super.setup();
  }

  @override
  void run() {
    qt.clear();
    for (var i = 0; i < 1000; i++) {
      final box = flame.RectangleHitbox(
        size: _size,
        position: Vector2(i * 10.0, i * 10.0),
      );
      qt.add(box);
    }
    qt.optimize();
  }
}

class _RePaintQuadTreeInsertsAndRemoves2Benchmark extends BenchmarkBase {
  _RePaintQuadTreeInsertsAndRemoves2Benchmark()
      : super('RePaint QuadTree inserts & removes 2');

  late QT qt;

  @override
  void setup() {
    qt = QT(
      boundary: const ui.Rect.fromLTWH(0, 0, 1000, 1000),
      capacity: 25,
    );
    super.setup();
  }

  @override
  void run() {
    qt.clear();
    final queue = Queue<int>();
    for (var i = 0; i < 100; i++) {
      final box = ui.Rect.fromLTWH(i * 10.0, i * 10.0, 10, 10);
      final id = qt.insert(box);
      queue.add(id);
    }
    if (qt.length != 100) throw Exception('Failed to insert all');
    while (queue.isNotEmpty)
      if (!qt.remove(queue.removeFirst()))
        throw Exception('Failed to remove object');
    qt.optimize();
    if (qt.length != 0) throw Exception('Failed to remove all');
  }
}

class _RePaintQuadTreeInsertsAndRemovesBenchmark extends BenchmarkBase {
  _RePaintQuadTreeInsertsAndRemovesBenchmark()
      : super('RePaint QuadTree inserts & removes');

  late QuadTree qt;

  @override
  void setup() {
    qt = QuadTree(
      boundary: const ui.Rect.fromLTWH(0, 0, 1000, 1000),
      capacity: 25,
    );
    super.setup();
  }

  @override
  void run() {
    qt.clear();
    final queue = Queue<int>();
    for (var i = 0; i < 100; i++) {
      final box = ui.Rect.fromLTWH(i * 10.0, i * 10.0, 10, 10);
      final id = qt.insert(box);
      queue.add(id!);
    }
    if (qt.length != 100) throw Exception('Failed to insert all');
    while (queue.isNotEmpty) qt.remove(queue.removeFirst());
    qt.optimize();
    if (qt.length != 0) throw Exception('Failed to remove all');
  }
}

class _FlameQuadTreeInsertsAndRemovesBenchmark extends BenchmarkBase {
  _FlameQuadTreeInsertsAndRemovesBenchmark()
      : super('Flame QuadTree inserts & removes');

  static final Vector2 _size = Vector2.all(10);
  late flame.QuadTree qt;

  @override
  void setup() {
    qt = flame.QuadTree<flame.Hitbox<flame.ShapeHitbox>>(
      mainBoxSize: const ui.Rect.fromLTWH(0, 0, 1000, 1000),
      maxObjects: 25,
      maxDepth: 10,
    );
    super.setup();
  }

  @override
  void run() {
    qt.clear();
    final queue = Queue<flame.RectangleHitbox>();
    for (var i = 0; i < 100; i++) {
      final box = flame.RectangleHitbox(
        size: _size,
        position: Vector2(i * 10.0, i * 10.0),
      );
      queue.add(box);
      qt.add(box);
    }
    while (queue.isNotEmpty) qt.remove(queue.removeFirst());
    qt.optimize();
  }
}

class _RePaintQuadTreeQueryIdsBenchmark extends BenchmarkBase {
  _RePaintQuadTreeQueryIdsBenchmark() : super('RePaint QuadTree query ids');

  late QuadTree qt;
  static const camera = ui.Rect.fromLTWH(250, 250, 500, 500);

  @override
  void setup() {
    qt = QuadTree(
      boundary: const ui.Rect.fromLTWH(0, 0, 1000, 1000),
      capacity: 25,
    );
    for (var i = 0; i < 100; i++)
      qt.insert(ui.Rect.fromLTWH(i * 10.0, i * 10.0, 10, 10));
    super.setup();
  }

  @override
  void run() {
    List<int>? results;
    for (var i = 0; i < 100; i++) results = qt.queryIds(camera);
    // 52 results
    if (results == null || results.length != 52)
      throw Exception('Not enough results');
  }
}

class _RePaintQuadTreeQueryMapBenchmark extends BenchmarkBase {
  _RePaintQuadTreeQueryMapBenchmark() : super('RePaint QuadTree query map');

  late QuadTree qt;
  static const camera = ui.Rect.fromLTWH(250, 250, 500, 500);

  @override
  void setup() {
    qt = QuadTree(
      boundary: const ui.Rect.fromLTWH(0, 0, 1000, 1000),
      capacity: 25,
    );
    for (var i = 0; i < 100; i++)
      qt.insert(ui.Rect.fromLTWH(i * 10.0, i * 10.0, 10, 10));
    super.setup();
  }

  @override
  void run() {
    Map<int, ui.Rect>? results;
    for (var i = 0; i < 100; i++) results = qt.queryMap(camera);
    // 52 results
    if (results == null || results.length != 52)
      throw Exception('Not enough results');
  }
}

class _RePaintQuadTreeQueryBenchmark extends BenchmarkBase {
  _RePaintQuadTreeQueryBenchmark() : super('RePaint QuadTree query');

  late QuadTree qt;
  static const camera = ui.Rect.fromLTWH(250, 250, 500, 500);

  @override
  void setup() {
    qt = QuadTree(
      boundary: const ui.Rect.fromLTWH(0, 0, 1000, 1000),
      capacity: 25,
    );
    for (var i = 0; i < 100; i++)
      qt.insert(ui.Rect.fromLTWH(i * 10.0, i * 10.0, 10, 10));
    super.setup();
  }

  @override
  void run() {
    Map<int, ui.Rect>? results;
    for (var i = 0; i < 100; i++) results = qt.query(camera).toMap();
    // 52 results
    if (results == null || results.length != 52)
      throw Exception('Not enough results');
  }
}

class _FlameQuadTreeQueryBenchmark extends BenchmarkBase {
  _FlameQuadTreeQueryBenchmark() : super('Flame QuadTree query');

  late flame.QuadTree qt;
  static final camera =
      flame.RectangleHitbox(size: Vector2.all(500), position: Vector2.all(250));

  @override
  void setup() {
    qt = flame.QuadTree<flame.Hitbox<flame.ShapeHitbox>>(
      mainBoxSize: const ui.Rect.fromLTWH(0, 0, 1000, 1000),
      maxObjects: 25,
      maxDepth: 10,
    );
    final size = Vector2.all(10);
    for (var i = 0; i < 100; i++)
      qt.add(
        flame.RectangleHitbox(
          size: size,
          position: Vector2(i * 10.0, i * 10.0),
        ),
      );
    // Add camera bounds
    qt.add(camera);
    camera.aabb;
    super.setup();
  }

  @override
  void run() {
    List<Object>? results;
    for (var i = 0; i < 100; i++)
      results = qt
          .query(camera)
          .entries
          .single
          .value
          .where((box) => box.aabb.intersectsWithAabb2(camera.aabb))
          .toList(growable: false);
    // 52 results + camera
    if (results == null || results.length != 53)
      throw Exception('Not enough results');
  }
}

class _RePaintQuadTreeMoveBenchmark extends BenchmarkBase {
  _RePaintQuadTreeMoveBenchmark() : super('RePaint QuadTree move');

  late QuadTree qt;

  @override
  void setup() {
    qt = QuadTree(
      boundary: const ui.Rect.fromLTWH(0, 0, 1000, 1000),
      capacity: 25,
    );
    for (var i = 0; i < 100; i++)
      qt.insert(ui.Rect.fromLTWH(i * 10.0, i * 10.0, 10, 10));
    super.setup();
  }

  @override
  void run() {
    final id = qt.insert(const ui.Rect.fromLTWH(0, 0, 10, 10));
    if (id == null) throw Exception('Failed to insert');
    for (var i = 0; i < 1000; i++) qt.move(id, i.toDouble(), i.toDouble());
    final pos = qt.get(id);
    if (pos.left != 999 || pos.top != 999) throw Exception('Failed to move');
    qt
      ..remove(id)
      ..optimize();
  }
}

class _FlameQuadTreeMoveBenchmark extends BenchmarkBase {
  _FlameQuadTreeMoveBenchmark() : super('Flame QuadTree move');

  late flame.QuadTree qt;

  @override
  void setup() {
    qt = flame.QuadTree<flame.Hitbox<flame.ShapeHitbox>>(
      mainBoxSize: const ui.Rect.fromLTWH(0, 0, 1000, 1000),
      maxObjects: 25,
      maxDepth: 10,
    );
    final size = Vector2.all(10);
    for (var i = 0; i < 100; i++)
      qt.add(
        flame.RectangleHitbox(
          size: size,
          position: Vector2(i * 10.0, i * 10.0),
        ),
      );
    super.setup();
  }

  @override
  void run() {
    final rect = flame.RectangleHitbox(
      size: Vector2.all(10),
      position: Vector2.zero(),
    );
    qt.add(rect);
    for (var i = 0; i < 1000; i++)
      rect.position = Vector2(i.toDouble(), i.toDouble());
    if (qt.hasMoved(rect) != true) throw Exception('Failed to move');
    //if (pos.left != 999 || pos.top != 999) throw Exception('Failed to move');
    qt
      ..remove(rect)
      ..optimize();
  }
}

class _RePaintQuadTreeCapacityBenchmark extends BenchmarkBase {
  _RePaintQuadTreeCapacityBenchmark(this.capacity)
      : super('RePaint QuadTree capacity: $capacity');

  late QuadTree qt;
  final int capacity;
  static const ui.Rect camera = ui.Rect.fromLTWH(250, 250, 100, 100);
  int maxDepth = 0;

  @override
  void setup() {
    qt = QuadTree(
      boundary: const ui.Rect.fromLTWH(0, 0, 1000, 1000),
      capacity: capacity,
    );
    super.setup();
  }

  @override
  void run() {
    // Clear
    qt.clear();
    final queue = Queue<int>();

    // Insert
    for (var i = 0; i < 1000; i++) {
      final box = ui.Rect.fromLTWH(i * 1.0, i * 1.0, 10, 10);
      final id = qt.insert(box);
      queue.add(id!);
    }
    if (qt.length != 1000) throw Exception('Failed to insert all');

    // Move
    final id = qt.insert(const ui.Rect.fromLTWH(0, 0, 10, 10));
    if (id == null) throw Exception('Failed to insert');
    for (var i = 0; i < 1000; i++) qt.move(id, i * 1.0, i * 1.0);
    final pos = qt.get(id);
    if (pos.left != 999 || pos.top != 999) throw Exception('Failed to move');
    qt.remove(id);

    // Query
    List<int>? results;
    for (var i = 0; i < 100; i++) results = qt.queryIds(camera);
    if (results == null || results.isEmpty)
      throw Exception('Not enough results');

    // Visit and find max depth
    qt.visit((node) {
      if (node.leaf && node.depth > maxDepth) maxDepth = node.depth;
      return true;
    });

    // Remove
    while (queue.isNotEmpty) qt.remove(queue.removeFirst());
    // Optimize
    qt.optimize();
    if (qt.length != 0) throw Exception('Failed to remove all');
  }
}
