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
          RePaint QuadTree inserts(RunTime): 1312.946 us.
          Flame QuadTree inserts(RunTime): 30701.432835820895 us.
        */
        test('Inserts', () {
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
          RePaint QuadTree inserts & removes(RunTime): 133.5937792017087 us.
          Flame QuadTree inserts & removes(RunTime): 2411.84125 us.
        */
        test('Inserts and removes', () {
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
          RePaint QuadTree query(RunTime): 800.08575 us.
          Flame QuadTree query(RunTime): 2261.023 us.
        */
        test('Static query', () {
          final repaint = _RePaintQuadTreeQueryBenchmark();
          if (report)
            // ignore: dead_code
            repaint.report();
          final errors = repaint.qt.healthCheck();
          //if (errors.isNotEmpty) throw Exception(errors.join('\n'));
          expect(errors, isEmpty);
          final flame = _FlameQuadTreeQueryBenchmark();
          if (report)
            // ignore: dead_code
            flame.report();
          if (!report)
            // ignore: dead_code
            expect(repaint.measure(), lessThanOrEqualTo(flame.measure()));
        });

        /*
          RePaint QuadTree move(RunTime): 122.40191533487861 us.
          Flame QuadTree move(RunTime): 286.3479948253558 us.
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
      },
    );

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
    List<int>? results;
    for (var i = 0; i < 100; i++) results = qt.queryIds(camera);
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
