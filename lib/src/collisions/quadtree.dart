import 'dart:collection';

import 'hitbox.dart';

/// {@template quadtree}
/// A Quadtree data structure that subdivides a 2D space into four quadrants
/// to speed up collision detection and spatial queries.
///
/// Now supports:
/// - insertion [insert]
/// - removal of a single object [remove]
/// - moving objects within the tree [move]
/// - node merging/optimization [optimize]
/// {@endtemplate}
class QuadTree<T extends HitBox> {
  /// Creates a new Quadtree with [boundary] and a [capacity].
  /// If [parent] is null, this node is the root.
  /// [objectNodeMap] is passed only internally when creating child nodes.
  ///
  /// {@macro quadtree}
  QuadTree({
    required this.boundary,
    this.capacity = 4,
    this.parent,
    Map<T, QuadTree<T>>? objectNodeMap,
  })  : _objectNodeMap = objectNodeMap ?? HashMap<T, QuadTree<T>>(),
        objects = <T>[];

  /// Boundary of the current Quadtree node.
  final HitBox boundary;

  /// Maximum number of objects in this node before subdividing.
  final int capacity;

  /// Parent node. Null if this is the root.
  final QuadTree<T>? parent;

  /// All objects stored in this node.
  final List<T> objects;

  /// Indicates whether this node has been subdivided into four child nodes.
  bool _subdivided = false;

  /// Child nodes (quadrants).
  QuadTree<T>? _northWest;
  QuadTree<T>? _northEast;
  QuadTree<T>? _southWest;
  QuadTree<T>? _southEast;

  /// A shared map of object -> node references, used to quickly find
  /// which node an object belongs to. This is stored in the root
  /// and shared across all children.
  final Map<T, QuadTree<T>> _objectNodeMap;

  /// A quick way to retrieve the root node, traversing up via [parent].
  QuadTree<T> get root => parent == null ? this : parent!.root;

  // --------------------------------------------------------------------------
  // CORE METHODS
  // --------------------------------------------------------------------------

  /// Inserts [object] into the Quadtree.
  /// Returns true if insertion is successful, otherwise false.
  bool insert(T object) {
    if (!_overlapsBoundary(object, boundary)) return false;

    // If there's space and no subdivision yet, simply add the object.
    if (objects.length < capacity && !_subdivided) {
      objects.add(object);
      // Remember that [object] resides in this node.
      _objectNodeMap[object] = this;
      return true;
    }

    // If not subdivided yet, subdivide.
    if (!_subdivided) _subdivide();

    // Try inserting into each child node.
    if (_northWest!.insert(object)) return true;
    if (_northEast!.insert(object)) return true;
    if (_southWest!.insert(object)) return true;
    if (_southEast!.insert(object)) return true;

    // If the object doesn't fit in a child (spans multiple quadrants),
    // keep it here.
    objects.add(object);
    _objectNodeMap[object] = this;
    return true;
  }

  /// Removes [object] from the Quadtree if it exists.
  /// After removal, tries merging nodes upward if possible.
  void remove(T object, {bool optimize = true}) {
    final node = _objectNodeMap[object];
    if (node == null) return; // Object not found in any node
    if (!node.objects.remove(object)) return; // Not actually in that node
    _objectNodeMap.remove(object);
    if (optimize) node._tryMergeUp();
  }

  /// Moves [object] to new [x], [y] coordinates.
  ///
  /// 1. Finds the node containing [object].
  /// 2. If the object is still in the same boundary, just update position.
  /// 3. Otherwise, removes from old node and re-inserts into the root,
  ///    since it might belong to a new location in the tree.
  void move(T object, double x, double y, {bool optimize = true}) {
    final node = _objectNodeMap[object];
    if (node == null) return; // no such object

    object.move(x, y); // Update position

    // Check if the object still fits in the same node's boundary.
    if (_overlapsBoundary(object, node.boundary))
      return; // If it still fits, do nothing; we've just updated coordinates.

    // Remove from old node
    node.objects.remove(object);
    _objectNodeMap.remove(object);

    // Insert from the root
    root.insert(object);

    // After removal, old node might be empty, try merging it.
    if (optimize) node._tryMergeUp();
  }

  /// Retrieves a list of objects that might overlap the rectangular
  /// query region specified by [hit].
  List<T> query(HitBox hit) {
    if (!boundary.overlaps(hit)) return const [];

    // TODO(plugfox): Add sorting by distance to the hitbox or y coordinate.
    // Mike Matiunin <plugfox@gmail.com>, 07 January 2025

    // TODO(plugfox): Replace List with a Iterable to avoid creating a new list.
    // Mike Matiunin <plugfox@gmail.com>, 07 January 2025

    return <T>[
      // Check objects in the current node.
      for (final object in objects)
        if (object.overlaps(hit)) object,

      // If subdivided, recurse into children nodes and collect objects.
      ...?_northWest?.query(hit),
      ...?_northEast?.query(hit),
      ...?_southWest?.query(hit),
      ...?_southEast?.query(hit),
    ];
  }

  /*
  /// Draws the current node's boundary and all objects onto [canvas]
  /// for debugging.
  /// Optionally pass a custom [paint] style.
  void draw(ui.Canvas canvas, {ui.Paint? paint}) {
    // TODO(plugfox): Use drawPoints and for better performance.
    // Mike Matiunin <plugfox@gmail.com>, 06 January 2025

    paint ??= ui.Paint()
      ..color = const ui.Color(0xFF000000).withValues(alpha: 0.5)
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw boundary for the current node.
    final boundaryPath = ui.Path()..addRect(boundary);
    canvas.drawPath(boundaryPath, paint);

    // Draw objects in this node.
    for (final object in objects) {
      final objectPath = ui.Path()
        ..moveTo(object.x, object.y)
        ..lineTo(object.x + object.width, object.y)
        ..lineTo(object.x + object.width, object.y + object.height)
        ..lineTo(object.x, object.y + object.height)
        ..close();

      final objectPaint = ui.Paint()
        ..color = const ui.Color(0xFF00FF00).withValues(alpha: 0.5)
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
  } */

  /// Removes all objects and resets the node (including children).
  /// This also clears the shared map for the root and all children.
  void clear() {
    if (parent == null) {
      // Root node -> clear the shared map
      _objectNodeMap.clear();
    }
    objects.clear();
    _subdivided = false;
    _northWest = null;
    _northEast = null;
    _southWest = null;
    _southEast = null;
  }

  // --------------------------------------------------------------------------
  // OPTIMIZATION (MERGING)
  // --------------------------------------------------------------------------

  /// Call this on the root to try merging all possible child nodes.
  /// Recursively merges subtrees that have fewer than [capacity]
  /// objects in total.
  void optimize() {
    root._tryMergeDownAll();
  }

  /// Recursively calls [_tryMergeUp] on all children, ensuring every
  /// subtree is merged if possible.
  void _tryMergeDownAll() {
    // We need to check every child node, even if they're subdivided yet
    // because we can still merge them and exclude other nodes.
    if (_subdivided) {
      assert(
        _northWest != null &&
            _northEast != null &&
            _southWest != null &&
            _southEast != null,
        'Subdivided but children are null',
      );
      // We can still get there null because of the recursive call,
      // so null check.
      _northWest?._tryMergeDownAll();
      _northEast?._tryMergeDownAll();
      _southWest?._tryMergeDownAll();
      _southEast?._tryMergeDownAll();
    }
    _tryMergeUp();
  }

  /// Merge child nodes if total objects in [this + children] <= [capacity].
  /// If merged, calls _tryMergeUp on the parent as well,
  /// allowing merges to bubble up.
  void _tryMergeUp() {
    if (!_subdivided) {
      // We can still bubble up if the parent can merge.
      parent?._tryMergeUp();
      return;
    }

    final totalObjects = objects.length +
        _northWest!.objects.length +
        _northEast!.objects.length +
        _southWest!.objects.length +
        _southEast!.objects.length;

    // If the sum of objects in children plus current node
    // doesn't exceed capacity, we can merge them.
    if (totalObjects <= capacity) {
      // Move all children objects up to this node.
      for (final childObj in _northWest!.objects)
        _objectNodeMap[childObj] = this;
      for (final childObj in _northEast!.objects)
        _objectNodeMap[childObj] = this;
      for (final childObj in _southWest!.objects)
        _objectNodeMap[childObj] = this;
      for (final childObj in _southEast!.objects)
        _objectNodeMap[childObj] = this;

      objects
        ..addAll(_northWest!.objects)
        ..addAll(_northEast!.objects)
        ..addAll(_southWest!.objects)
        ..addAll(_southEast!.objects);

      // Remove children
      _northWest!.clear();
      _northEast!.clear();
      _southWest!.clear();
      _southEast!.clear();
      _northWest = null;
      _northEast = null;
      _southWest = null;
      _southEast = null;
      _subdivided = false;
    }

    // In either case, bubble up further if there's a parent.
    parent?._tryMergeUp();
  }

  // --------------------------------------------------------------------------
  // SUBDIVISION
  // --------------------------------------------------------------------------

  /// Splits the current node into four sub-nodes:
  /// North-West, North-East, South-West, South-East.
  void _subdivide() {
    _subdivided = true;
    final halfWidth = boundary.width / 2;
    final halfHeight = boundary.height / 2;
    final x = boundary.left;
    final y = boundary.top;

    _northWest = QuadTree<T>(
      boundary: HitBox.rect(
        width: halfWidth,
        height: halfHeight,
        x: x,
        y: y,
      ),
      capacity: capacity,
      parent: this,
      objectNodeMap: _objectNodeMap,
    );
    _northEast = QuadTree<T>(
      boundary: HitBox.rect(
        width: halfWidth,
        height: halfHeight,
        x: x + halfWidth,
        y: y,
      ),
      capacity: capacity,
      parent: this,
      objectNodeMap: _objectNodeMap,
    );
    _southWest = QuadTree<T>(
      boundary: HitBox.rect(
        width: halfWidth,
        height: halfHeight,
        x: x,
        y: y + halfHeight,
      ),
      capacity: capacity,
      parent: this,
      objectNodeMap: _objectNodeMap,
    );
    _southEast = QuadTree<T>(
      boundary: HitBox.rect(
        width: halfWidth,
        height: halfHeight,
        x: x + halfWidth,
        y: y + halfHeight,
      ),
      capacity: capacity,
      parent: this,
      objectNodeMap: _objectNodeMap,
    );
  }

  // --------------------------------------------------------------------------
  // UTILS
  // --------------------------------------------------------------------------

  /// Checks if [object] overlaps [boundary] by coordinate checks
  /// (no new Rect).
  bool _overlapsBoundary(T object, HitBox boundary) =>
      object.overlaps(boundary);
}
