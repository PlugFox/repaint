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
        _moveCamera(hover.localDelta);
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
      width: 10,
      height: 10,
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
    ..strokeWidth = 10;

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
      ..write(_spinnerSymbols[_spinnerIndex % _spinnerSymbols.length])
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

  void _drawQuadTree(Size size, Canvas canvas) {}

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
