import 'dart:ui';

import 'package:repaint/repaint.dart';

mixin QuadTreeCameraMixin {
  final QuadTree quadTree = QuadTree(
    boundary: const Rect.fromLTWH(0, 0, 100000, 100000),
    capacity: 18,
  );

  final _camera = QuadTreeCamera(
    boundary: Rect.zero,
  );
  Rect get cameraBoundary => _camera.boundary;
  Size size = Size.zero;

  bool needsPaintQt = false;

  void mountQtCamera() {
    _camera.set(Rect.fromCenter(
      center: quadTree.boundary.center,
      width: size.width,
      height: size.height,
    ));
  }

  void updateCameraBoundary(Size newSize) {
    size = newSize;
    _camera.set(Rect.fromCenter(
      center: _camera.boundary.center,
      width: size.width,
      height: size.height,
    ));
    needsPaintQt = true;
  }

  void moveQtCamera(Offset offset) {
    if (offset == Offset.zero) return;
    needsPaintQt = true;
    _camera.move(offset);
    // Ensure the camera stays within the quadtree boundary.
    if (_camera.boundary.width > quadTree.boundary.width ||
        _camera.boundary.height > quadTree.boundary.height) {
      final canvasAspectRatio = size.width / size.height;
      final quadTreeAspectRatio =
          quadTree.boundary.width / quadTree.boundary.height;
      if (canvasAspectRatio > quadTreeAspectRatio) {
        _camera.set(Rect.fromCenter(
          center: _camera.boundary.center,
          width: quadTree.boundary.width,
          height: quadTree.boundary.width / canvasAspectRatio,
        ));
      } else {
        _camera.set(Rect.fromCenter(
          center: _camera.boundary.center,
          width: quadTree.boundary.height * canvasAspectRatio,
          height: quadTree.boundary.height,
        ));
      }
    }
    if (_camera.boundary.left < quadTree.boundary.left) {
      _camera.set(Rect.fromLTWH(
        0,
        _camera.boundary.top,
        _camera.boundary.width,
        _camera.boundary.height,
      ));
    } else if (_camera.boundary.right > quadTree.boundary.right) {
      _camera.set(Rect.fromLTWH(
        quadTree.boundary.right - _camera.boundary.width,
        _camera.boundary.top,
        _camera.boundary.width,
        _camera.boundary.height,
      ));
    }
    if (_camera.boundary.top < quadTree.boundary.top) {
      _camera.set(Rect.fromLTWH(
        _camera.boundary.left,
        0,
        _camera.boundary.width,
        _camera.boundary.height,
      ));
    } else if (_camera.boundary.bottom > quadTree.boundary.bottom) {
      _camera.set(Rect.fromLTWH(
        _camera.boundary.left,
        quadTree.boundary.bottom - _camera.boundary.height,
        _camera.boundary.width,
        _camera.boundary.height,
      ));
    }
  }

  void unmountQtCamera() {
    quadTree.clear();
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
