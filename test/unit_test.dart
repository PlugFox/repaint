import 'package:test/test.dart';

import 'unit/quadtree_test.dart' as quadtree_test;
import 'unit/repaint_test.dart' as repaint_test;
import 'unit/util_test.dart' as util_test;

void main() {
  group('Unit', () {
    util_test.main();
    repaint_test.main();
    quadtree_test.main();
  });
}
