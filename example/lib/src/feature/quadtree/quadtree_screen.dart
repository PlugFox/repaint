import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:repaint/repaint.dart';
import 'package:repaintexample/src/common/widget/app.dart';
import 'package:repaintexample/src/feature/quadtree/quadtree_camera.dart';

/// {@template quadtree_screen}
/// QuadTreeScreen widget.
/// {@endtemplate}
class QuadTreeScreen extends StatefulWidget {
  /// {@macro quadtree_screen}
  const QuadTreeScreen({
    super.key, // ignore: unused_element
  });

  @override
  State<QuadTreeScreen> createState() => _QuadTreeScreenState();
}

/// State for widget QuadTreeScreen.
class _QuadTreeScreenState extends State<QuadTreeScreen> {
  final QuadTreePainter painter = QuadTreePainter();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('QuadTree'),
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

class QuadTreePainter extends RePainterBase with QuadTreeCameraMixin {
  final HardwareKeyboard _keyboardManager = HardwareKeyboard.instance;
  bool _spacebarPressed = false;

  Float32List _points = Float32List(0);

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

  void _onClick(Offset point) {
    // Calculate the dot offset from the camera.
    final cameraCenter = cameraBoundary.center;
    final dot = Rect.fromCenter(
      center: Offset(
        point.dx + cameraCenter.dx - size.width / 2,
        point.dy + cameraCenter.dy - size.height / 2,
      ),
      width: 2,
      height: 2,
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

    if (!needsPaintQt) return; // No need to update the points and repaint.

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
  }

  final TextPainter _textPainter = TextPainter(
    textAlign: TextAlign.left,
    textDirection: TextDirection.ltr,
  );
  final Paint _bgPaint = Paint()..color = Colors.lightBlue;
  final Paint _pointPaint = Paint()
    ..color = Colors.black
    ..style = PaintingStyle.fill
    ..strokeWidth = 2;

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
      ..write(_points.length ~/ 2)
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

  /// Draw points on the canvas.
  void _drawPoints(Size size, Canvas canvas) {
    if (_points.isEmpty) return;
    canvas.drawRawPoints(
      PointMode.points,
      _points,
      _pointPaint,
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
    _drawPoints(size, canvas); // Draw points
    _drawStatus(size, canvas); // Draw status
    needsPaintQt = false; // Reset the flag.
  }
}

/// Sort the list of points by the y-coordinate.
// ignore: unused_element
void _sortByY(Float32List list) {
  void swap(Float32List list, int i, int j) {
    if (i == j) return;
    // Меняем x
    final tempX = list[i * 2];
    list[i * 2] = list[j * 2];
    list[j * 2] = tempX;

    // Меняем y
    final tempY = list[i * 2 + 1];
    list[i * 2 + 1] = list[j * 2 + 1];
    list[j * 2 + 1] = tempY;
  }

  int partition(Float32List list, int low, int high) {
    // Используем значение y на последней позиции в качестве опорного
    final pivotY = list[high * 2 + 1];
    int i = low - 1;

    for (int j = low; j < high; j++) {
      if (list[j * 2 + 1] <= pivotY) {
        i++;
        // Обмениваем пары [x, y]
        swap(list, i, j);
      }
    }

    // Перемещаем опорный элемент на правильную позицию
    swap(list, i + 1, high);
    return i + 1;
  }

  void quickSort(int low, int high) {
    if (low < high) {
      final pivotIndex = partition(list, low, high);
      quickSort(low, pivotIndex - 1);
      quickSort(pivotIndex + 1, high);
    }
  }

  quickSort(0, list.length ~/ 2 - 1);
}
