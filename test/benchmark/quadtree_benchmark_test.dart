import 'dart:collection';
import 'dart:ui' as ui;

import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:flame/collisions.dart' as flame;
import 'package:repaint/repaint.dart';
import 'package:test/test.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

void main() => group(
      'QuadTree benchmark',
      () {
        var report = true;

        /*
          RePaint QuadTree inserts batch v2(RunTime): 220.1505207750028 us.
          RePaint QuadTree inserts batch(RunTime): 818.77475 us.
          Flame QuadTree inserts(RunTime): 30062.470588235294 us.
        */
        test('Inserts', () {
          final repaintBatchV2 = _RePaintQuadTreeInsertsBatchV2Benchmark();
          if (report)
            // ignore: dead_code
            repaintBatchV2.report();
          final repaintBatch = _RePaintQuadTreeInsertsBatchBenchmark();
          if (report)
            // ignore: dead_code
            repaintBatch.report();
          final flame = _FlameQuadTreeInsertsBenchmark();
          if (report)
            // ignore: dead_code
            flame.report();
          if (!report)
            // ignore: dead_code
            expect(
              repaintBatchV2.measure(),
              allOf(
                lessThanOrEqualTo(repaintBatch.measure()),
                lessThanOrEqualTo(flame.measure()),
              ),
            );
        });

        test('Inserts and removes', () {
          final repaintBatchV2 =
              _RePaintQuadTreeInsertsAndRemovesBatchV2Benchmark();
          if (report)
            // ignore: dead_code
            repaintBatchV2.report();
          final repaint = _RePaintQuadTreeInsertsAndRemovesBenchmark();
          if (report)
            // ignore: dead_code
            repaint.report();
          final repaintBatch =
              _RePaintQuadTreeInsertsAndRemovesBatchBenchmark();
          if (report)
            // ignore: dead_code
            repaintBatch.report();
          final flame = _FlameQuadTreeInsertsAndRemovesBenchmark();
          if (report)
            // ignore: dead_code
            flame.report();
          if (!report)
            // ignore: dead_code
            expect(
              repaintBatchV2.measure(),
              lessThanOrEqualTo(flame.measure()),
            );
        });

        test('Static query', () {
          final repaint = _RePaintQuadTreeQueryBenchmark();
          if (report)
            // ignore: dead_code
            repaint.report();
          final flame = _FlameQuadTreeQueryBenchmark();
          if (report)
            // ignore: dead_code
            flame.report();
          if (!report)
            // ignore: dead_code
            expect(repaint.measure(), lessThanOrEqualTo(flame.measure()));
        });
      },
    );

class _RePaintQuadTreeInsertsBatchBenchmark extends BenchmarkBase {
  _RePaintQuadTreeInsertsBatchBenchmark()
      : super('RePaint QuadTree inserts batch');

  late QuadTreeDeprecated qt;

  @override
  void setup() {
    qt = QuadTreeDeprecated(
      boundary: HitBox.square(size: 10000),
      capacity: 25,
    );
    super.setup();
  }

  @override
  void run() {
    qt.clear();
    for (var i = 0; i < 1000; i++) {
      final box = HitBox.square(x: i * 10.0, y: i * 10.0, size: 10);
      qt.insert(box);
    }
    //qt.optimize();
  }
}

class _RePaintQuadTreeInsertsBatchV2Benchmark extends BenchmarkBase {
  _RePaintQuadTreeInsertsBatchV2Benchmark()
      : super('RePaint QuadTree inserts batch v2');

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
    //qt.optimize();
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
    //qt.optimize();
  }
}

class _RePaintQuadTreeInsertsAndRemovesBatchV2Benchmark extends BenchmarkBase {
  _RePaintQuadTreeInsertsAndRemovesBatchV2Benchmark()
      : super('RePaint QuadTree inserts & removes batch V2');

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
      if (id == null) {
        throw Exception('Failed to insert');
      }
      queue.add(id);
    }
    if (qt.length != 100) throw Exception('Failed to insert all');
    while (queue.isNotEmpty) qt.remove(queue.removeFirst(), optimize: false);
    qt.optimize();
    if (qt.length != 0) throw Exception('Failed to remove all');
  }
}

class _RePaintQuadTreeInsertsAndRemovesBenchmark extends BenchmarkBase {
  _RePaintQuadTreeInsertsAndRemovesBenchmark()
      : super('RePaint QuadTree inserts & removes');

  late QuadTreeDeprecated qt;

  @override
  void setup() {
    qt = QuadTreeDeprecated(
      boundary: HitBox.square(size: 1000),
      capacity: 25,
    );
    super.setup();
  }

  @override
  void run() {
    qt.clear();
    final queue = Queue<HitBox>();
    for (var i = 0; i < 100; i++) {
      final box = HitBox.square(size: 10, x: i * 10.0, y: i * 10.0);
      queue.add(box);
      qt.insert(box);
    }
    while (queue.isNotEmpty) qt.remove(queue.removeFirst());
  }
}

class _RePaintQuadTreeInsertsAndRemovesBatchBenchmark extends BenchmarkBase {
  _RePaintQuadTreeInsertsAndRemovesBatchBenchmark()
      : super('RePaint QuadTree inserts & removes batch');

  late QuadTreeDeprecated qt;

  @override
  void setup() {
    qt = QuadTreeDeprecated(
      boundary: HitBox.square(size: 1000),
      capacity: 25,
    );
    super.setup();
  }

  @override
  void run() {
    qt.clear();
    final queue = Queue<HitBox>();
    for (var i = 0; i < 100; i++) {
      final box = HitBox.square(size: 10, x: i * 10.0, y: i * 10.0);
      queue.add(box);
      qt.insert(box);
    }
    while (queue.isNotEmpty) qt.remove(queue.removeFirst(), optimize: false);
    qt.optimize();
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

class _RePaintQuadTreeQueryBenchmark extends BenchmarkBase {
  _RePaintQuadTreeQueryBenchmark() : super('RePaint QuadTree query');

  late QuadTreeDeprecated qt;
  static final camera = HitBox.square(size: 500, x: 250, y: 250);

  @override
  void setup() {
    qt = QuadTreeDeprecated(
      boundary: HitBox.square(size: 1000),
      capacity: 25,
    );
    for (var i = 0; i < 100; i++)
      qt.insert(
        HitBox.rect(
          width: 10,
          height: 10,
          x: i * 10.0,
          y: i * 10.0,
        ),
      );
    super.setup();
  }

  @override
  void run() {
    List<HitBox>? results;
    for (var i = 0; i < 100; i++) results = qt.query(camera);
    if (results == null || results.length < 40)
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
    if (results == null || results.length < 40)
      throw Exception('Not enough results');
  }
}
