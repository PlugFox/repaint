import 'dart:ui' as ui;

import 'hitbox.dart';

/// Quadtree is a data structure that subdivides a 2D space into four quadrants,
/// improving the efficiency of collision detection and retrieval of objects
/// in certain regions.
///
class Quadtree<T extends HitBox> {
  /// Creates a new Quadtree with [boundary] and a [capacity].
  Quadtree({
    required this.boundary,
    this.capacity = 4,
  }) : objects = [];

  /// Boundary of the current Quadtree node.
  final ui.Rect boundary;

  /// Maximum number of objects in this node before subdividing.
  final int capacity;

  /// All objects that are stored in this node.
  final List<T> objects;

  /// Indicates whether this node has been subdivided into four child nodes.
  bool _subdivided = false;

  /// Child nodes (quadrants).
  Quadtree<T>? _northWest;
  Quadtree<T>? _northEast;
  Quadtree<T>? _southWest;
  Quadtree<T>? _southEast;

  /// Attempts to insert [object] into the Quadtree.
  /// Returns true if insertion is successful, otherwise false.
  bool insert(T object) {
    // 1. Check if object overlaps this node's boundary.
    if (!_overlapsBoundary(object, boundary)) {
      return false;
    }

    // 2. If there's space and no subdivision yet, simply add the object.
    if (objects.length < capacity && !_subdivided) {
      objects.add(object);
      return true;
    }

    // 3. If not subdivided yet, subdivide.
    if (!_subdivided) {
      _subdivide();
    }

    // 4. Try inserting into each child node.
    if (_northWest!.insert(object)) return true;
    if (_northEast!.insert(object)) return true;
    if (_southWest!.insert(object)) return true;
    if (_southEast!.insert(object)) return true;

    // If the object spans multiple boundaries and doesn't fit neatly
    // into one child, keep it in this node.
    objects.add(object);
    return true;
  }

  /// Retrieves a list of objects that might overlap the rectangular
  /// query region specified by [queryRect].
  List<T> query(ui.Rect queryRect) {
    final found = <T>[];

    // If there's no overlap at all, return empty.
    if (!boundary.overlaps(queryRect)) {
      return found;
    }

    // Check objects in the current node.
    for (final object in objects) {
      // Use the object's overlapsRect method to avoid creating Rect objects.
      if (object.overlapsRect(
        left: queryRect.left,
        top: queryRect.top,
        right: queryRect.right,
        bottom: queryRect.bottom,
      )) {
        found.add(object);
      }
    }

    // If subdivided, recurse into children.
    if (_subdivided) {
      found.addAll(_northWest!.query(queryRect));
      found.addAll(_northEast!.query(queryRect));
      found.addAll(_southWest!.query(queryRect));
      found.addAll(_southEast!.query(queryRect));
    }

    return found;
  }

  /// Draws the current node's boundary and all objects onto [canvas] for debugging.
  /// Optionally pass a custom [paint] style.
  ///
  /// This uses [canvas.drawRect] and path operations, so it creates some new objects
  /// (like Path) internally. You can refactor if you need to minimize allocations.
  void draw(ui.Canvas canvas, {ui.Paint? paint}) {
    paint ??= ui.Paint()
      ..color = const ui.Color(0xFF000000).withOpacity(0.5)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw boundary for the current node.
    final boundaryPath = ui.Path()..addRect(boundary);
    canvas.drawPath(boundaryPath, paint);

    // Draw objects in this node.
    // We create minimal overhead by building paths instead of new Rect objects.
    for (final object in objects) {
      final objectPath = ui.Path()
        ..moveTo(object.x, object.y)
        ..lineTo(object.x + object.width, object.y)
        ..lineTo(object.x + object.width, object.y + object.height)
        ..lineTo(object.x, object.y + object.height)
        ..close();

      final objectPaint = ui.Paint()
        ..color = const ui.Color(0xFF00FF00).withOpacity(0.5)
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 1.0;

      canvas.drawPath(objectPath, objectPaint);
    }

    // Recursively draw child nodes.
    if (_subdivided) {
      _northWest!.draw(canvas, paint: paint);
      _northEast!.draw(canvas, paint: paint);
      _southWest!.draw(canvas, paint: paint);
      _southEast!.draw(canvas, paint: paint);
    }
  }

  /// Removes all objects and resets the node (including children).
  void clear() {
    objects.clear();
    _subdivided = false;
    _northWest = null;
    _northEast = null;
    _southWest = null;
    _southEast = null;
  }

  /// Splits the current node into four sub-nodes:
  /// North-West, North-East, South-West, South-East.
  void _subdivide() {
    _subdivided = true;
    final halfWidth = boundary.width / 2;
    final halfHeight = boundary.height / 2;
    final x = boundary.left;
    final y = boundary.top;

    _northWest = Quadtree<T>(
      boundary: ui.Rect.fromLTWH(x, y, halfWidth, halfHeight),
      capacity: capacity,
    );
    _northEast = Quadtree<T>(
      boundary: ui.Rect.fromLTWH(x + halfWidth, y, halfWidth, halfHeight),
      capacity: capacity,
    );
    _southWest = Quadtree<T>(
      boundary: ui.Rect.fromLTWH(x, y + halfHeight, halfWidth, halfHeight),
      capacity: capacity,
    );
    _southEast = Quadtree<T>(
      boundary: ui.Rect.fromLTWH(
          x + halfWidth, y + halfHeight, halfWidth, halfHeight),
      capacity: capacity,
    );
  }

  /// Checks if [object] overlaps [rectBoundary] without creating a new Rect object.
  bool _overlapsBoundary(T object, ui.Rect rectBoundary) {
    final objectRight = object.x + object.width;
    final objectBottom = object.y + object.height;
    final boundaryRight = rectBoundary.left + rectBoundary.width;
    final boundaryBottom = rectBoundary.top + rectBoundary.height;

    return object.x < boundaryRight &&
        objectRight > rectBoundary.left &&
        object.y < boundaryBottom &&
        objectBottom > rectBoundary.top;
  }
}
