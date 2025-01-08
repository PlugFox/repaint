import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:repaint/repaint.dart';
import 'package:repaintexample/src/common/widget/app.dart';

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
  /* #region Lifecycle */
  @override
  void initState() {
    super.initState();
    // Initial state initialization
  }

  @override
  void didUpdateWidget(covariant QuadTreeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Widget configuration changed
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The configuration of InheritedWidgets has changed
    // Also called after initState but before build
  }

  @override
  void dispose() {
    // Permanent removal of a tree stent
    super.dispose();
  }
  /* #endregion */

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

class QuadTreePainter extends RePainterBase {
  final QuadTree _quadTree = QuadTree(
    boundary: const Rect.fromLTWH(0, 0, 100000, 100000),
    capacity: 18,
  );

  final _camera = QuadTreeCamera(
    boundary: Rect.zero,
  );

  final HardwareKeyboard _keyboardManager = HardwareKeyboard.instance;
  bool _spacebarPressed = false;

  Float32List _points = Float32List(0);
  Size _size = Size.zero;

  @override
  bool get needsPaint => _needsPaint;
  bool _needsPaint = false;

  @override
  void mount(RePaintBox box, PipelineOwner owner) {
    _size = box.size;
    _camera.set(Rect.fromCenter(
      center: _quadTree.boundary.center,
      width: _size.width,
      height: _size.height,
    ));
    _keyboardManager.addHandler(onKeyboardEvent);
    _spacebarPressed =
        HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.space);
    _needsPaint = true;
  }

  @override
  void unmount() {
    _keyboardManager.removeHandler(onKeyboardEvent);
    _quadTree.clear();
    _spacebarPressed = false;
    _needsPaint = false;
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
        _moveCamera(const Offset(0, -10));
      case LogicalKeyboardKey.keyS when isKeyDown:
      case LogicalKeyboardKey.arrowDown when isKeyDown:
        _moveCamera(const Offset(0, 10));
      case LogicalKeyboardKey.keyA when isKeyDown:
      case LogicalKeyboardKey.arrowLeft when isKeyDown:
        _moveCamera(const Offset(-10, 0));
      case LogicalKeyboardKey.keyD when isKeyDown:
      case LogicalKeyboardKey.arrowRight when isKeyDown:
        _moveCamera(const Offset(10, 0));
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
        _moveCamera(-hover.localDelta);
      case PointerMoveEvent move:
        if (!move.down) return;
        _onClick(move.localPosition);
      case PointerPanZoomUpdateEvent pan:
        _moveCamera(pan.panDelta);
      case PointerDownEvent click:
        _onClick(click.localPosition);
    }
  }

  void _moveCamera(Offset offset) {
    if (offset == Offset.zero) return;
    _needsPaint = true;
    _camera.move(offset);
    // Ensure the camera stays within the quadtree boundary.
    if (_camera.boundary.width > _quadTree.boundary.width ||
        _camera.boundary.height > _quadTree.boundary.height) {
      final canvasAspectRatio = _size.width / _size.height;
      final quadTreeAspectRatio =
          _quadTree.boundary.width / _quadTree.boundary.height;
      if (canvasAspectRatio > quadTreeAspectRatio) {
        _camera.set(Rect.fromCenter(
          center: _camera.boundary.center,
          width: _quadTree.boundary.width,
          height: _quadTree.boundary.width / canvasAspectRatio,
        ));
      } else {
        _camera.set(Rect.fromCenter(
          center: _camera.boundary.center,
          width: _quadTree.boundary.height * canvasAspectRatio,
          height: _quadTree.boundary.height,
        ));
      }
    }
    if (_camera.boundary.left < _quadTree.boundary.left) {
      _camera.set(Rect.fromLTWH(
        0,
        _camera.boundary.top,
        _camera.boundary.width,
        _camera.boundary.height,
      ));
    } else if (_camera.boundary.right > _quadTree.boundary.right) {
      _camera.set(Rect.fromLTWH(
        _quadTree.boundary.right - _camera.boundary.width,
        _camera.boundary.top,
        _camera.boundary.width,
        _camera.boundary.height,
      ));
    }
    if (_camera.boundary.top < _quadTree.boundary.top) {
      _camera.set(Rect.fromLTWH(
        _camera.boundary.left,
        0,
        _camera.boundary.width,
        _camera.boundary.height,
      ));
    } else if (_camera.boundary.bottom > _quadTree.boundary.bottom) {
      _camera.set(Rect.fromLTWH(
        _camera.boundary.left,
        _quadTree.boundary.bottom - _camera.boundary.height,
        _camera.boundary.width,
        _camera.boundary.height,
      ));
    }
  }

  void _onClick(Offset point) {
    // Calculate the dot offset from the camera.
    final cameraCenter = _camera.boundary.center;
    final dot = Rect.fromCenter(
      center: Offset(
        point.dx + cameraCenter.dx - _size.width / 2,
        point.dy + cameraCenter.dy - _size.height / 2,
      ),
      width: 2,
      height: 2,
    );
    final id = _quadTree.insert(dot);
    if (id == null) return;
    _needsPaint = true;
  }

  @override
  void update(RePaintBox box, Duration elapsed, double delta) {
    // If the size of the box has changed, update the camera too.
    if (box.size != _size) {
      _size = box.size;
      _camera.set(Rect.fromCenter(
        center: _camera.boundary.center,
        width: _size.width,
        height: _size.height,
      ));
      _needsPaint = true;
    }

    if (!_needsPaint) return; // No need to update the points and repaint.

    final boundary = _camera.boundary;
    final result = _quadTree.query(boundary);
    if (result.isEmpty) {
      _points = Float32List(0);
    } else {
      _points = Float32List(result.length * 2);
      var counter = 0;
      result.forEach((
        int id,
        double width,
        double height,
        double left,
        double top,
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
      ..write(_quadTree.boundary.width.toStringAsFixed(0))
      ..write('x')
      ..write(_quadTree.boundary.height.toStringAsFixed(0))
      ..write(' | ')
      ..write('Screen:')
      ..write(nbsp)
      ..write(size.width.toStringAsFixed(0))
      ..write('x')
      ..write(size.height.toStringAsFixed(0))
      ..write(' | ')
      ..write('Position:')
      ..write(nbsp)
      ..write(_camera.boundary.left.toStringAsFixed(0))
      ..write('x')
      ..write(_camera.boundary.top.toStringAsFixed(0))
      ..write(' | ')
      ..write('Points:')
      ..write(nbsp)
      ..write(_points.length ~/ 2)
      ..write('/')
      ..write(_quadTree.length)
      ..write(' | ')
      ..write('Nodes:')
      ..write(nbsp)
      ..write(_quadTree.nodesCount);
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
    final cam = _camera.boundary;
    final queue = Queue<QuadTree$Node?>()..add(_quadTree.root);
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
    _needsPaint = false; // Reset the flag.
  }
}

class QuadTreeCamera {
  QuadTreeCamera({
    required Rect boundary,
  }) : _boundary = boundary;

  /// The boundary of the camera.
  Rect get boundary => _boundary;
  Rect _boundary;

  /// Move the camera by the given offset.
  void move(Offset offset) => _boundary = _boundary.shift(offset);

  /// Set the camera to the given boundary.
  void set(Rect boundary) => _boundary = boundary;
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
