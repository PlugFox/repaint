import 'dart:typed_data';
import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:repaint/repaint.dart';
import 'package:repaintexample/src/common/widget/app.dart';
import 'package:repaintexample/src/feature/performance_overlay/performance_overlay_screen.dart';

/// {@template square_figure_screen}
/// SquareFigureScreen widget.
/// {@endtemplate}
class SquareFigureScreen extends StatefulWidget {
  /// {@macro square_figure_screen}
  const SquareFigureScreen({
    super.key, // ignore: unused_element
  });

  @override
  State<SquareFigureScreen> createState() => _SquareFigureScreenState();
}

/// State for widget SquareFigureScreen.
class _SquareFigureScreenState extends State<SquareFigureScreen> {
  final _painter = _SquarePainter();
  final focusNode = FocusNode()..requestFocus();

  final ValueNotifier<int> _progress = ValueNotifier<int>(1);

  @override
  void initState() {
    super.initState();
    _progress.addListener(_updateAmount);
    _updateAmount();
  }

  void _updateAmount() => _painter.setCubesAmount(_progress.value);

  @override
  void dispose() {
    _progress
      ..removeListener(_updateAmount)
      ..dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Square'),
        leading: BackButton(
          onPressed: () => App.pop(context),
        ),
      ),
      body: KeyboardListener(
        focusNode: focusNode,
        autofocus: true,
        onKeyEvent: (key) {
          print('Key: ${key.logicalKey.keyId}');
          _painter.autoRotate = false;
          switch (key.logicalKey.keyId) {
            case 100: // right (d)
              _painter.yawAngle -= 1;
            case 97: // left (a)
              _painter.yawAngle += 1;
            case 119: // forward (w)
              _painter.pitchAngle -= 1;
            case 115: // backward (s)
              _painter.pitchAngle += 1;
            case 113: // left roll (q)
              _painter.rollAngle -= 1;
            case 101: // right roll (e)
              _painter.rollAngle += 1;
          }
        },
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1.5,
                      child: RePaint(
                        painter: _painter,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8.0),
                SizedBox(
                  height: 72,
                  child: FittedBox(
                    alignment: Alignment.center,
                    fit: BoxFit.scaleDown,
                    clipBehavior: Clip.none,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        SizedBox(
                          width: 300,
                          child: ValueListenableBuilder<int>(
                            valueListenable: _progress,
                            builder: (context, value, child) => Column(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: <Widget>[
                                Slider(
                                  min: 0,
                                  max: 100,
                                  value: value.toDouble(),
                                  onChanged: (val) => _progress.value = val.round().clamp(0, 100),
                                ),
                                Text(
                                  '$value% (${_painter.cubesToUse} cubes)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox.square(
                          dimension: 48,
                          child: IconButton(
                            icon: const Icon(Icons.bug_report),
                            onPressed: () => _painter.switchPerformanceOverlay(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SquarePainter extends PerformanceOverlayPainter {
  _SquarePainter()
      : _positions = Float32List(verticiesAmount * 6),
        _colors = Int32List(verticiesAmount * 3) {
    _initVertices();
  }

  static const verticiesAmount = 4;
  final Float32List _positions;

  final Int32List _colors;

  late Vertices _vertices;

  List<Offset> _points = [];

  double pitchAngle = 0; // plane nose goes up-down
  double yawAngle = 0; // plane nose goes left-right
  double rollAngle = 0; // plane rotation around its nose
  bool autoRotate = true;

  // Define 3D cube vertices
  static const List<List<int>> verticesCube = [
    [-1, -1, -1], [1, -1, -1], [1, 1, -1], [-1, 1, -1], // Bottom face
    [-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1] // Top face
  ];

  // Define cube edges (pairs of vertex indices)
  static const List<List<int>> edgesCube = [
    [0, 1], [1, 2], [2, 3], [3, 0], // Bottom face
    [4, 5], [5, 6], [6, 7], [7, 4], // Top face
    [0, 4], [1, 5], [2, 6], [3, 7] // Vertical edges
  ];

  void _initVertices() {
    _vertices = Vertices.raw(
      VertexMode.triangles,
      _positions,
      colors: _colors,
    );
  }

  // Function to rotate a point in 3D space
  List<double> rotate3D(List<double> coords3d, double angleX, double angleY, double angleZ) {
    // Convert angles to radians
    final radX = (math.pi / 180) * angleX;
    final radY = (math.pi / 180) * angleY;
    final radZ = (math.pi / 180) * angleZ;

    final x = coords3d[0];
    final y = coords3d[1];
    final z = coords3d[2];

    // Rotate around X-axis
    final y1 = y * math.cos(radX) - z * math.sin(radX);
    final z1 = y * math.sin(radX) + z * math.cos(radX);

    // Rotate around Y-axis
    final x2 = x * math.cos(radY) + z1 * math.sin(radY);
    final z2 = -x * math.sin(radY) + z1 * math.cos(radY);

    // Rotate around Z-axis
    final x3 = x2 * math.cos(radZ) - y1 * math.sin(radZ);
    final y3 = x2 * math.sin(radZ) + y1 * math.cos(radZ);

    return [x3, y3, z2];
  }

  // Project a 3D point to 2D (ignoring depth)
  List<double> projectSimple(List<double> coords3d, {double cameraDistance = 400}) {
    const depthModifier = 2;
    final scale = 300 / (coords3d[2] / depthModifier + cameraDistance); // Perspective divide (adjust depth)
    return [coords3d[0] * scale, coords3d[1] * scale];
  }

  static const double fov = 90; // Field of view in degrees
  final fovScale = 1 / (2 * math.tan((fov * 0.5 * math.pi) / 180));
  List<double> projectFov(List<double> coords3d, {double cameraDistance = 400}) {
    final scale = (fovScale * cameraDistance) / (coords3d[2] + cameraDistance * 4);
    return [coords3d[0] * scale, coords3d[1] * scale];
  }

  int calculateDimension(int cubesAmount) {
    int dimensionAmount = 1;
    for (int i = 0; i < cubesAmount; ++i) {
      dimensionAmount = dimensionAmount + 1;
      final testNumber = math.pow(dimensionAmount, 3).ceil();
      if (testNumber >= cubesAmount) {
        break;
      }
    }
    return dimensionAmount;
  }

  List<List<int>> verticesCubeForIndex(int idx, int maxIdx) {
    final dimensionAmount = calculateDimension(maxIdx);

    int rowIdx = 0;
    int colIdx = 0;
    int depthIdx = 0;
    for (int i = 0; i < idx; ++i) {
      colIdx++;
      if (colIdx >= dimensionAmount) {
        colIdx = 0;
        rowIdx++;
        if (rowIdx >= dimensionAmount) {
          rowIdx = 0;
          depthIdx++;
        }
      }
    }

    return verticesCube
        .map((v) => [v[0] - colIdx + dimensionAmount ~/ 2, v[1] - rowIdx + dimensionAmount ~/ 2, v[2] + depthIdx])
        .toList();
  }

  int cubesToUse = 1;
  void setCubesAmount(int amount) {
    cubesToUse = amount * amount * 1;
  }

  Duration elapsedLast = Duration.zero;
  String _lastKey = '';
  @override
  void internalUpdate(RePaintBox box, Duration elapsed, double delta) {
    final size = box.size;
    final dimension = size.shortestSide;
    final center = size.center(Offset.zero);
    
    final dt = (elapsedLast.inMilliseconds - elapsed.inMilliseconds) / 1024;

    if (autoRotate) {
      yawAngle += 4 * dt;
      pitchAngle += 6 * dt;
      rollAngle += 8 * dt;
    }

    String getKey() => '$yawAngle-$pitchAngle-$rollAngle-$cubesToUse';
    final key = getKey();
    if (key == _lastKey) {
      return;
    }
    _points = [];
    _lastKey = key;
    elapsedLast = elapsed;

    final dimensionAmount = calculateDimension(cubesToUse);

    for (int cubeIdx = 0; cubeIdx < cubesToUse; ++cubeIdx) {
      final movedVertices = verticesCubeForIndex(cubeIdx, cubesToUse);
      final rotatedVertices = movedVertices
          .map((v) => rotate3D(v.map((e) => e * dimension).toList(), pitchAngle, yawAngle, rollAngle))
          .toList();
      final projectedVertices =
          rotatedVertices.map((v) => projectSimple(v, cameraDistance: dimension * (2 + dimensionAmount / 4))).toList();

      for (var i = 0; i < edgesCube.length; ++i) {
        final edge = edgesCube[i];
        final start2d = projectedVertices[edge[0]];
        final end2d = projectedVertices[edge[1]];
        _points.add(Offset(center.dx + start2d[0], center.dy - start2d[1]));
        _points.add(Offset(center.dx + end2d[0], center.dy - end2d[1]));
      }
    }
    _vertices = Vertices.raw(
      VertexMode.triangles,
      _positions,
      colors: _colors,
    );
  }

  @override
  void internalPaint(RePaintBox box, PaintingContext context) {
    final canvas = context.canvas;
    var paint = Paint()
      ..style = PaintingStyle.fill
      ..strokeWidth = 4
      ..isAntiAlias = false
      ..blendMode = BlendMode.src
      ..filterQuality = FilterQuality.none;

    canvas.drawRect(
      Offset.zero & box.size,
      paint..color = Colors.white,
    );

    paint.color = Colors.black;
    for (var i = 0; i < (_points.length - 1); i += 2) {
      canvas.drawLine(_points[i], _points[i + 1], paint);
    }
  }
}
