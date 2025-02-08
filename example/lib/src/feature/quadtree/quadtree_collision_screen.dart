import 'dart:collection';
import 'dart:developer';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:repaint/repaint.dart';
import 'package:repaintexample/src/common/widget/app.dart';
import 'package:repaintexample/src/feature/quadtree/quadtree_camera.dart';

/// {@template quadtree_screen}
/// QuadTreeCollisionScreen widget.
/// {@endtemplate}
class QuadTreeCollisionScreen extends StatefulWidget {
  /// {@macro quadtree_screen}
  const QuadTreeCollisionScreen({
    super.key, // ignore: unused_element
  });

  @override
  State<QuadTreeCollisionScreen> createState() =>
      _QuadTreeCollisionScreenState();
}

/// State for widget QuadTreeCollisionScreen.
class _QuadTreeCollisionScreenState extends State<QuadTreeCollisionScreen> {
  final QuadTreeCollisionPainter painter = QuadTreeCollisionPainter();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('QuadTreeCollision'),
          leading: BackButton(
            onPressed: () => App.pop(context),
          ),
        ),
        body: SafeArea(
          child: RePaint(
            painter: painter,
          ),
        ),
      );
}

class CollisionRectObject {
  CollisionRectObject({
    required this.id,
    required this.rect,
    required this.velocity,
  });

  final int id;
  Rect rect;
  Vector2d velocity;

  // Only small rects can be moved
  bool get canBeMoved => rect.width < 128 && rect.height < 128;

  double get diagonalLength =>
      sqrt(rect.width * rect.width + rect.height * rect.height);

  Iterable<Vector2d> get vertices {
    return [
      Vector2d(rect.left, rect.bottom),
      Vector2d(rect.right, rect.bottom),
      Vector2d(rect.right, rect.top),
      Vector2d(rect.left, rect.top),
    ];
  }

  Vector2d get absoluteCenter => Vector2d(rect.center.dx, rect.center.dy);

  @override
  int get hashCode {
    const int prime1 = 73856093;
    const int prime2 = 19349663;
    const int prime3 = 83492791;
    return _hashCode ??= (id * 37 +
            (id * prime1) +
            ((rect.left * prime2).round() << 8) +
            ((rect.top * prime3).round()) <<
        4);
  }

  int? _hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CollisionRectObject &&
          id == other.id &&
          rect == other.rect &&
          velocity == other.velocity;
}

class Vector2d {
  const Vector2d(this.x, this.y);

  Vector2d.zero()
      : x = 0,
        y = 0;

  final double x;
  final double y;

  /// Negate.
  Vector2d operator -() => Vector2d(-x, -y);

  /// Subtract two vectors.
  Vector2d operator -(Vector2d other) => Vector2d(x - other.x, y - other.y);

  /// Add two vectors.
  Vector2d operator +(Vector2d other) => Vector2d(x + other.x, y + other.y);

  /// Scale.
  Vector2d operator /(double scale) => Vector2d(x / scale, y / scale);

  /// Scale.
  Vector2d operator *(double scale) => Vector2d(x * scale, y * scale);

  /// Length.
  double get length => sqrt(length2);

  /// Length squared.
  double get length2 {
    double sum;
    sum = x * x;
    sum += y * y;
    return sum;
  }

  /// Normalize this.
  Vector2d normalized() {
    final l = length;
    if (l == 0.0) {
      return Vector2d.zero();
    }
    final d = 1.0 / l;
    return Vector2d(x * d, y * d);
  }

  /// Inner product.
  double dot(Vector2d other) {
    double sum;
    sum = x * other.x;
    sum += y * other.y;
    return sum;
  }

  Vector2d perpendicular() => Vector2d(-y, x);

  @override
  String toString() => 'Vector2d($x, $y)';
}

class CollisionUtil {
  // Object a inside object b
  static ({Vector2d normal, double depth})? intercectRects(
      CollisionRectObject a, CollisionRectObject b) {
    Vector2d normal = Vector2d.zero();
    double depth = double.maxFinite;

    List<Vector2d> verticesA = a.vertices.toList();
    List<Vector2d> verticesB = b.vertices.toList();

    var normalAndDepthA = CollisionUtil.getNormalAndDepth(
      verticesA,
      verticesB,
    );

    if (normalAndDepthA.depth < depth) {
      depth = normalAndDepthA.depth;
      normal = normalAndDepthA.normal;
    }
    var normalAndDepthB = CollisionUtil.getNormalAndDepth(
      verticesB,
      verticesA,
      insverted: true,
    );

    if (normalAndDepthB.depth < depth) {
      depth = normalAndDepthB.depth;
      normal = normalAndDepthB.normal;
    }

    Vector2d direction = a.absoluteCenter - b.absoluteCenter;

    if (direction.dot(normal) < 0) {
      normal = -normal;
    }

    return (normal: normal, depth: depth);
  }

  static ({Vector2d normal, double depth}) getNormalAndDepth(
    List<Vector2d> verticesA,
    List<Vector2d> verticesB, {
    bool insverted = false,
  }) {
    var normal = Vector2d.zero();
    double depth = double.maxFinite;
    for (int i = 0; i < verticesA.length; i++) {
      Vector2d va = verticesA[i];
      Vector2d vb = verticesA[(i + 1) % verticesA.length];

      Vector2d edge = vb - va;
      Vector2d axis = Vector2d(-edge.y, edge.x);
      axis = axis.normalized();

      final pA = projectVertices(insverted ? verticesB : verticesA, axis);
      final pB = projectVertices(insverted ? verticesA : verticesB, axis);

      double axisDepth = min(pB.max - pA.min, pA.max - pB.min);
      if (axisDepth < depth) {
        depth = axisDepth;
        normal = axis;
      }
    }
    return (normal: normal, depth: depth);
  }

  static ({double min, double max}) projectVertices(
    List<Vector2d> vertices,
    Vector2d axis,
  ) {
    double min = double.maxFinite;
    double max = -double.maxFinite;
    for (var v in vertices) {
      double proj = v.dot(axis);

      if (proj < min) {
        min = proj;
      }
      if (proj > max) {
        max = proj;
      }
    }
    return (min: min, max: max);
  }
}

class CollidingPair<T> {
  T _a;
  T _b;

  T get a => _a;
  T get b => _b;

  int get hash => _hash;
  int _hash;

  CollidingPair(this._a, this._b) : _hash = _a.hashCode ^ _b.hashCode;

  /// Sets the prospect to contain [a] and [b] instead of what it previously
  /// contained.
  void set(T a, T b) {
    _a = a;
    _b = b;
    _hash = a.hashCode ^ b.hashCode;
  }

  /// Sets the prospect to contain the content of [other].
  void setFrom(CollidingPair<T> other) {
    _a = other._a;
    _b = other._b;
    _hash = other._hash;
  }

  /// Creates a new prospect object with the same content.
  CollidingPair<T> clone() => CollidingPair(_a, _b);
}

mixin CollisionObjectsMixin on QuadTreeCameraMixin {
  final collisionObjects = <int, CollisionRectObject>{};
  final Paint _rectPaint = Paint()
    ..color = Colors.yellow.withAlpha(150)
    ..style = PaintingStyle.fill
    ..strokeWidth = 2;
  final Paint _collidingPaint = Paint()
    ..color = Colors.red.withAlpha(150)
    ..style = PaintingStyle.fill
    ..strokeWidth = 2;

  @override
  void mountQtCamera() {
    super.mountQtCamera();

    addSideBounds();
  }

  // Bounds that will restrict the area where objects can move.
  void addSideBounds() {
    // Adding bounds to the screen box:
    const double boundWidth = 64;
    const double rectDimensions = 1024;
    final boundLeft = Rect.fromLTWH(
      cameraBoundary.center.dx - rectDimensions / 2 - boundWidth,
      cameraBoundary.center.dy - rectDimensions,
      boundWidth,
      rectDimensions * 3,
    );
    final boundRight = Rect.fromLTWH(
      cameraBoundary.center.dx + rectDimensions / 2 - boundWidth,
      cameraBoundary.center.dy - rectDimensions - boundWidth,
      boundWidth,
      rectDimensions * 3,
    );
    final boundTop = Rect.fromLTWH(
      cameraBoundary.center.dx - rectDimensions - boundWidth,
      cameraBoundary.center.dy - rectDimensions / 2 - boundWidth,
      rectDimensions * 3,
      boundWidth,
    );
    final boundBottom = Rect.fromLTWH(
      cameraBoundary.center.dx - rectDimensions,
      cameraBoundary.center.dy + rectDimensions / 2 - boundWidth,
      rectDimensions * 3,
      boundWidth,
    );

    quadTree.insert(boundLeft);
    quadTree.insert(boundRight);
    quadTree.insert(boundTop);
    quadTree.insert(boundBottom);
  }

  /// Draw points on the canvas.
  void drawCollisionObjects(Size size, Canvas canvas) {
    canvas.save();
    canvas.translate(-cameraBoundary.left, -cameraBoundary.top);
    for (final e in collisionObjects.values.toList()) {
      if (_collidingObjectIds.contains(e.id)) {
        canvas.drawRect(e.rect, _collidingPaint);
      } else {
        canvas.drawRect(e.rect, _rectPaint);
      }
    }
    canvas.restore();
  }

  void updateCollisionObjects(double delta) {
    final dt = delta / 1000;
    // Checking collisions:
    _collidingPairHashes.clear();
    _collidingObjectIds.clear();
    quadTree.forEach((id, left, top, width, height) {
      final obj = collisionObjects[id];
      if (obj == null) {
        collisionObjects[id] = CollisionRectObject(
          id: id,
          rect: Rect.fromLTWH(left, top, width, height),
          velocity: Vector2d.zero(),
        );
      } else {
        obj.rect = Rect.fromLTWH(left, top, width, height);
      }
      _checkCollideWith(collisionObjects[id]!);
      return true;
    });

    // Manipulating colliding pairs:
    for (final pair in _collidingPairHashes.values) {
      final a = pair.a;
      final b = pair.b;
      if (!a.canBeMoved && !b.canBeMoved) {
        continue;
      }
      final colisionResult = CollisionUtil.intercectRects(a, b);
      if (colisionResult == null) {
        continue;
      }

      // Changing velocity depending on how deep objects intercet.
      final depth = max(1.0, colisionResult.depth);
      final velocityChange = colisionResult.normal * depth * dt * 64;
      if (a.canBeMoved) {
        a.velocity = a.velocity + velocityChange;
      }
      // both objects gain same velocity change, but in opposite directions.
      if (b.canBeMoved) {
        b.velocity = b.velocity + velocityChange * -1;
      }
    }

    // Moving objects depending on their velocities:
    for (final e in collisionObjects.values) {
      quadTree.move(e.id, e.rect.left + e.velocity.x * dt,
          e.rect.top + e.velocity.y * dt);
    }
    needsPaintQt = true;
  }

  final _collidingPairHashes = <int, CollidingPair<CollisionRectObject>>{};
  final _collidingObjectIds = <int>{};

  void _checkCollideWith(
    CollisionRectObject object,
  ) {
    for (final potential in quadTree.queryRectsIterable(object.rect)) {
      if (potential.id == object.id) continue;
      final other = collisionObjects[potential.id];
      if (other == null) continue;
      final pair = CollidingPair(object, other);
      if (_collidingPairHashes.containsKey(pair.hash)) {
        // just checking that hash function is correct.
        final existing = _collidingPairHashes[pair.hash]!;
        debugger(
            when: !((existing.a.id == pair.a.id &&
                    existing.b.id == pair.b.id) ||
                (existing.a.id == pair.b.id && existing.b.id == pair.a.id)));
        continue;
      }
      _collidingPairHashes[pair.hash] = pair;
      _collidingObjectIds.add(object.id);
      _collidingObjectIds.add(other.id);
    }
  }
}

class QuadTreeCollisionPainter extends RePainterBase
    with QuadTreeCameraMixin, CollisionObjectsMixin {
  final HardwareKeyboard _keyboardManager = HardwareKeyboard.instance;
  bool _spacebarPressed = false;

  @override
  bool get needsPaint => needsPaintQt;

  @override
  void mount(RePaintBox box, PipelineOwner owner) {
    size = box.size;
    mountQtCamera();

    _keyboardManager.addHandler(onKeyboardEvent);
    _spacebarPressed =
        HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.space);
    needsPaintQt = true;
  }

  @override
  void unmount() {
    _keyboardManager.removeHandler(onKeyboardEvent);
    unmountQtCamera();
    _spacebarPressed = false;
    needsPaintQt = false;
  }

  bool onKeyboardEvent(KeyEvent event) {
    bool? isKeyDown = switch (event) {
      KeyDownEvent _ => true,
      KeyRepeatEvent _ => true,
      KeyUpEvent _ => false,
      _ => null,
    };
    if (isKeyDown == null) return false; // Not a key press event.
    switch (event.logicalKey) {
      case LogicalKeyboardKey.keyW when isKeyDown:
      case LogicalKeyboardKey.arrowUp when isKeyDown:
        moveQtCamera(const Offset(0, -10));
      case LogicalKeyboardKey.keyS when isKeyDown:
      case LogicalKeyboardKey.arrowDown when isKeyDown:
        moveQtCamera(const Offset(0, 10));
      case LogicalKeyboardKey.keyA when isKeyDown:
      case LogicalKeyboardKey.arrowLeft when isKeyDown:
        moveQtCamera(const Offset(-10, 0));
      case LogicalKeyboardKey.keyD when isKeyDown:
      case LogicalKeyboardKey.arrowRight when isKeyDown:
        moveQtCamera(const Offset(10, 0));
      case LogicalKeyboardKey.space:
        _spacebarPressed = isKeyDown;
      default:
        return false; // Not a key we care about.
    }
    return true;
  }

  @override
  void onPointerEvent(PointerEvent event) {
    switch (event) {
      case PointerHoverEvent hover:
        if (!_spacebarPressed) return;
        moveQtCamera(-hover.localDelta);
      case PointerMoveEvent move:
        if (!move.down) return;
        _onClick(move.localPosition);
      case PointerPanZoomUpdateEvent pan:
        moveQtCamera(pan.panDelta);
      case PointerDownEvent click:
        _onClick(click.localPosition);
    }
  }

  bool _wasAdded = false;

  void _onClick(Offset point) {
    if (_wasAdded) {
      return;
    }
    _wasAdded = true;
    Future<void>.delayed(const Duration(milliseconds: 500), () {
      _wasAdded = false;
    });
    // Calculate the dot offset from the camera.
    final cameraCenter = cameraBoundary.center;
    const double dimension = 64;
    final dot = Rect.fromCenter(
      center: Offset(
        point.dx + cameraCenter.dx - size.width / 2,
        point.dy + cameraCenter.dy - size.height / 2,
      ),
      width: dimension,
      height: dimension,
    );
    quadTree.insert(dot);
    needsPaintQt = true;
  }

  @override
  void update(RePaintBox box, Duration elapsed, double delta) {
    // If the size of the box has changed, update the camera too.
    if (box.size != size) {
      updateCameraBoundary(box.size);
    }
    updateCollisionObjects(delta);

    if (!needsPaintQt) return; // No need to update the points and repaint.

    /*
    final boundary = cameraBoundary;
    final result = quadTree.query(boundary);
    if (result.isEmpty) {
      _points = Float32List(0);
    } else {
      _points = Float32List(result.length * 2);
      var counter = 0;
      result.forEach((
        int id,
        double left,
        double top,
        double width,
        double height,
      ) {
        _points
          ..[counter] = left + width / 2 - boundary.left
          ..[counter + 1] = top + height / 2 - boundary.top;
        counter += 2;
        return true;
      });
      //_sortByY(_points);
    }
    */
  }

  final TextPainter _textPainter = TextPainter(
    textAlign: TextAlign.left,
    textDirection: TextDirection.ltr,
  );
  final Paint _bgPaint = Paint()..color = Colors.lightBlue;

  int _spinnerIndex = 0;
  static const List<String> _spinnerSymbols = [
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏',
  ];

  /// Draw current status.
  void _drawStatus(Size size, Canvas canvas) {
    _spinnerIndex++;
    final nbsp = String.fromCharCode(160);
    final status = StringBuffer()
      ..write(_spinnerSymbols[_spinnerIndex =
          _spinnerIndex % _spinnerSymbols.length])
      ..write(' | ')
      ..write('World:')
      ..write(nbsp)
      ..write(quadTree.boundary.width.toStringAsFixed(0))
      ..write('x')
      ..write(quadTree.boundary.height.toStringAsFixed(0))
      ..write(' | ')
      ..write('Screen:')
      ..write(nbsp)
      ..write(size.width.toStringAsFixed(0))
      ..write('x')
      ..write(size.height.toStringAsFixed(0))
      ..write(' | ')
      ..write('Position:')
      ..write(nbsp)
      ..write(cameraBoundary.left.toStringAsFixed(0))
      ..write('x')
      ..write(cameraBoundary.top.toStringAsFixed(0))
      ..write(' | ')
      ..write('Points:')
      ..write(nbsp)
      ..write(collisionObjects.length)
      ..write('/')
      ..write(quadTree.length)
      ..write(' | ')
      ..write('Nodes:')
      ..write(nbsp)
      ..write(quadTree.nodes);
    _textPainter
      ..text = TextSpan(
        text: status.toString(),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontFamily: 'RobotoMono',
        ),
      )
      ..layout(maxWidth: size.width - 32);
    final textSize = _textPainter.size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          8,
          size.height - textSize.height - 16 - 8,
          size.width - 16,
          textSize.height + 16,
        ),
        const Radius.circular(8),
      ),
      Paint()..color = Colors.white54,
    );
    _textPainter.paint(
      canvas,
      Offset(16, size.height - textSize.height - 16),
    );
  }

  final Paint _nodePaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 0.1
    ..style = PaintingStyle.stroke;

  /// Draw the quadtree nodes on the canvas.
  void _drawQuadTree(Size size, Canvas canvas) {
    final cam = cameraBoundary;
    final queue = Queue<QuadTree$Node?>()..add(quadTree.root);
    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      if (node == null) continue;
      if (!node.boundary.overlaps(cam)) continue;
      if (node.subdivided) {
        // Parent node is subdivided, add children to the queue.
        queue
          ..add(node.northWest)
          ..add(node.northEast)
          ..add(node.southWest)
          ..add(node.southEast);
      } else {
        // Draw the leaf node.
        final nodeBounds = Rect.fromLTWH(
          node.boundary.left - cam.left,
          node.boundary.top - cam.top,
          node.boundary.width,
          node.boundary.height,
        );

        // Check if any vertices are visible.
        if (nodeBounds.right < 0 ||
            nodeBounds.left > size.width ||
            nodeBounds.bottom < 0 ||
            nodeBounds.top > size.height) {
          continue;
        }
        final k = 1.0 / (node.depth + 1);
        canvas.drawRect(
          nodeBounds,
          _nodePaint
            ..strokeWidth = k * 2
            ..color = Colors.white.withValues(alpha: 1 - k),
        );
      }
    }
  }

  @override
  void paint(RePaintBox box, PaintingContext context) {
    final size = box.size;
    final canvas = context.canvas;

    canvas.drawRect(Offset.zero & size, _bgPaint); // Draw background
    _drawQuadTree(size, canvas); // Draw quadtree nodes
    drawCollisionObjects(size, canvas); // Draw points
    _drawStatus(size, canvas); // Draw status
    needsPaintQt = false; // Reset the flag.
  }
}
