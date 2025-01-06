import 'package:benchmark_harness/benchmark_harness.dart';
import 'package:repaint/src/collisions/hitbox.dart';

// $ dart run test/benchmark/hitbox_benchmark_test.dart
//
// $ dart compile exe -o benchmark/hitbox_benchmark.exe benchmark/hitbox_benchmark.dart
// $ benchmark/hitbox_benchmark.exe
void main() {
  (<BenchmarkBase>[
    HitBoxLeftBenchmark(),
    HitBoxRightBenchmark(),
  ].map<({String name, double us})>(_measure).toList(growable: false)
        ..sort((a, b) => a.us.compareTo(b.us)))
      .map<String>((e) => 'Benchmark ${e.name}: ${e.us.toStringAsFixed(2)} us')
      .forEach(print); // ignore: avoid_print
}

({String name, double us}) _measure(BenchmarkBase benchmark) =>
    (name: benchmark.name, us: benchmark.measure());

class HitBoxLeftBenchmark extends BenchmarkBase {
  HitBoxLeftBenchmark() : super('HitBoxLeft');

  final HitBox hitBox = HitBox.square(size: 100);
  double left = 0;

  @override
  void run() {
    hitBox.move(10, 0);
    left = hitBox.left;
  }

  @override
  void exercise() {
    for (var i = 0; i < 100; i++) {
      run();
    }
  }

  @override
  void teardown() {
    if (left == 0.0) throw Exception('HitBox.left is 0.0');
    super.teardown();
  }
}

class HitBoxRightBenchmark extends BenchmarkBase {
  HitBoxRightBenchmark() : super('HitBoxRight');

  final HitBox hitBox = HitBox.square(size: 100);
  double right = 0;

  @override
  void setup() {
    hitBox.move(10, 0);
    super.setup();
  }

  @override
  void run() {
    hitBox.move(10, 0);
    right = hitBox.right;
  }

  @override
  void exercise() {
    for (var i = 0; i < 100; i++) {
      run();
    }
  }

  @override
  void teardown() {
    if (right == 0.0) throw Exception('HitBox.right is 0.0');
    super.teardown();
  }
}
