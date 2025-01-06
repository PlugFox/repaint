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
        test('Inserts', () {
          final a = _RePaintQuadTreeInsertsBenchmark();
          //a.report();
          final b = _FlameQuadTreeInsertsBenchmark();
          //b.report();
          expect(a.measure(), lessThanOrEqualTo(b.measure()));
        });

        test('Query', () {
          final a = _RePaintQuadTreeQueryBenchmark();
          a.report();
          final b = _FlameQuadTreeQueryBenchmark();
          b.report();
        });
      },
    );

class _RePaintQuadTreeInsertsBenchmark extends BenchmarkBase {
  _RePaintQuadTreeInsertsBenchmark() : super('RePaint QuadTree inserts');

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
    for (var i = 0; i < 100; i++)
      qt.insert(
        HitBox.rect(
          width: 10,
          height: 10,
          x: i * 10.0,
          y: i * 10.0,
        ),
      );
    qt.clear();
  }
}

class _FlameQuadTreeInsertsBenchmark extends BenchmarkBase {
  _FlameQuadTreeInsertsBenchmark() : super('Flame QuadTree inserts');

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
    for (var i = 0; i < 100; i++)
      qt.add(
        flame.RectangleHitbox(
          size: _size,
          position: Vector2(i * 10.0, i * 10.0),
        ),
      );
    qt.clear();
  }
}

class _RePaintQuadTreeQueryBenchmark extends BenchmarkBase {
  _RePaintQuadTreeQueryBenchmark() : super('RePaint QuadTree query');

  late QuadTree qt;

  @override
  void setup() {
    qt = QuadTree(
      boundary: const ui.Rect.fromLTWH(0, 0, 1000, 1000),
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
    final results = Queue<HitBox>();
    const view = ui.Rect.fromLTWH(250, 250, 500, 500);
    for (var i = 0; i < 100; i++) results.addAll(qt.query(view));
    if (results.isEmpty) throw Exception('No results');
  }
}

class _FlameQuadTreeQueryBenchmark extends BenchmarkBase {
  _FlameQuadTreeQueryBenchmark() : super('Flame QuadTree query');

  late flame.QuadTree qt;
  static final flame.RectangleHitbox camera = flame.RectangleHitbox(
    size: Vector2.all(500),
    position: Vector2.all(250),
  );

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
    super.setup();
  }

  @override
  void run() {
    final results = Queue<List<Object>>();
    for (var i = 0; i < 100; i++) results.addAll(qt.query(camera).values);
    if (results.isEmpty) throw Exception('No results');
  }
}
