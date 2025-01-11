// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui show Rect;

/// View over a [Float32List] that represents a query result.
extension type QuadTree$QueryResult._(Float32List _bytes) {
  /// Returns the number of bytes reserved for each object in the query result.
  static const int sizePerObject = 5; // id + 4 floats

  /// Whether this query result is empty and has no objects.
  bool get isEmpty => _bytes.isEmpty;

  /// Whether this query result is not empty and has objects.
  bool get isNotEmpty => _bytes.isNotEmpty;

  /// The number of objects in this query result.
  int get length => _bytes.length ~/ sizePerObject;

  /// Returns an iterable of object identifiers.
  Iterable<int> get ids {
    if (isEmpty) return const Iterable.empty();
    final ids = Uint32List.sublistView(_bytes);
    return Iterable<int>.generate(length, (i) => ids[i * sizePerObject]);
  }

  /// Returns an unordered map of object identifiers and their bounds.
  Map<int, ui.Rect> toMap() {
    if (isEmpty) return const {};
    final ids = Uint32List.sublistView(_bytes);
    final results = HashMap<int, ui.Rect>();
    for (var i = 0; i < _bytes.length; i += 5) {
      final id = ids[i + 0];
      results[id] = ui.Rect.fromLTWH(
        _bytes[i + 1],
        _bytes[i + 2],
        _bytes[i + 3],
        _bytes[i + 4],
      );
    }
    return results;
  }

  /// Visit all objects in this query result.
  /// The walk stops when it iterates over all objects or
  /// when the callback returns false.
  void forEach(
    bool Function(
      int id,
      double left,
      double top,
      double width,
      double height,
    ) cb,
  ) {
    if (isEmpty) return;
    final ids = Uint32List.sublistView(_bytes);
    final data = _bytes;
    for (var i = 0; i < _bytes.length; i += 5) {
      final id = ids[i + 0];
      final next = cb(
        id, // id
        data[i + 1], // left (x)
        data[i + 2], // top (y)
        data[i + 3], // width
        data[i + 4], // height
      );
      if (next) continue;
      return;
    }
  }
}

/// {@template quadtree}
/// A Quadtree data structure that subdivides a 2D space into four quadrants
/// to speed up collision detection and spatial queries.
///
/// All objects are stored in the leaf nodes of the QuadTree and represented
/// as rectangles with an identifier.
/// The QuadTree can store objects with a width, height, and position.
/// Positions are represented as a point (x, y) in the 2D space at the top-left
/// corner of the object.
/// {@endtemplate}
final class QT {
  /// Creates a new Quadtree with [boundary] and a [capacity].
  ///
  /// {@macro quadtree}
  factory QT({
    // Boundary of the QuadTree.
    required ui.Rect boundary,
    // Capacity of the each QuadTree node.
    int capacity = 18,
    // Maximum depth of the QuadTree.
    int depth = 8,
  }) {
    assert(boundary.isFinite, 'The boundary must be finite.');
    assert(!boundary.isEmpty, 'The boundary must not be empty.');
    assert(capacity >= 6, 'The capacity must be greater or equal than 6.');
    assert(depth >= 1, 'The maximum depth must be greater or equal than 1.');
    assert(depth <= 7000, 'The maximum depth must be less or equal than 7000.');
    final nodes = List<QT$N?>.filled(_reserved, null, growable: false);
    final recycledNodes = Uint32List(_reserved);
    final objects = Float32List(_reserved * _objectSize);
    final recycledIds = Uint32List(_reserved);
    final id2node = Uint32List(_reserved);
    return QT._internal(
      boundary: boundary,
      capacity: capacity.clamp(6, 10000),
      depth: depth.clamp(1, 7000),
      nodes: nodes,
      recycledNodes: recycledNodes,
      objects: objects,
      recycledIds: recycledIds,
      id2node: id2node,
    );
  }

  /// Internal constructor for the QuadTree.
  QT._internal({
    required this.boundary,
    required this.capacity,
    required this.depth,
    required List<QT$N?> nodes,
    required Uint32List recycledNodes,
    required Float32List objects,
    required Uint32List recycledIds,
    required Uint32List id2node,
  })  :
        // Nodes
        _nodes = nodes,
        _recycledNodes = recycledNodes,
        // Objects
        _objects = objects,
        _recycledIds = recycledIds,
        _id2node = id2node;

  // --------------------------------------------------------------------------
  // PROPERTIES
  // --------------------------------------------------------------------------

  /// Boundary of the QuadTree.
  final ui.Rect boundary;

  /// The maximum number of objects that can be stored in a node before it
  /// subdivides.
  final int capacity;

  /// The maximum depth of the QuadTree.
  final int depth;

  // --------------------------------------------------------------------------
  // STORAGE
  // --------------------------------------------------------------------------

  /// Size of the object, 4 floats.
  /// [0] - left position (x)
  /// [1] - top position (y)
  /// [2] - width
  /// [3] - height
  static const _objectSize = 4;

  /// Initial reserved size for the each array withing the QuadTree.
  static const int _reserved = 64;

  /// The root node of the QuadTree.
  QT$N? get root => _root;
  QT$N? _root;

  /// The next identifier for a node in the QuadTree
  int _nodesCount = 0;

  /// Recycled objects in this manager.
  int _recycledNodesCount = 0;

  /// Recycled nodes ids in this manager.
  Uint32List _recycledNodes;

  /// Number of active objects in the QuadTree.
  int get nodesCount => _nodesCount - _recycledNodesCount;

  /// List of nodes in the QuadTree.
  /// Each index in the list is the identifier of the node.
  List<QT$N?> _nodes;

  /// Number of active objects in the QuadTree.
  int get length => _length;
  int _length = 0;

  /// Whether this tree is empty and has no objects.
  bool get isEmpty => _length == 0;

  /// Whether this tree is not empty and has objects.
  bool get isNotEmpty => _length > 0;

  /// List of objects in the QuadTree.
  ///
  /// Each object is stored in a contiguous block of memory.
  /// The first object starts at index 0, the second object starts at index 4,
  /// the third object starts at index 8, and so on.
  ///
  /// Offest of the object in the list is calculated as: index * 4.
  ///
  /// The objects are stored as a Float32List with the following format:
  /// [left, top, width, height]
  /// - left: The x-coordinate of the object.
  /// - top: The y-coordinate of the object.
  /// - width: The width of the object.
  /// - height: The height of the object.
  Float32List _objects;

  /// The next identifier for an object in the QuadTree.
  int _nextObjectId = 0;

  /// Recycled ids in this manager count.
  int _recycledIdsCount = 0;

  /// Recycled ids in this manager array.
  Uint32List _recycledIds;

  /// References between ids and nodes.
  /// Index is the id and value is the node id.
  Uint32List _id2node;

  // --------------------------------------------------------------------------
  // PUBLIC METHODS
  // --------------------------------------------------------------------------

  /// Insert an rectangle into the QuadTree.
  /// Returns the identifier of the object in the QuadTree.
  int insert(ui.Rect rect) {
    assert(rect.isFinite, 'The rectangle must be finite.');

    // Get the root node of the QuadTree
    // or create a new one if it does not exist.
    final root = _root ??= _createNode(
      parent: null,
      boundary: boundary,
    );

    // Create a new object in the QuadTree.
    final objectId = _getNextObjectId();
    // Increase the number of active objects in the QuadTree.
    _length++;

    // Find the node to insert the object
    final nodeId = root._insert(objectId, rect);

    // Store the reference between the id and the current node.
    _id2node[objectId] = nodeId;

    return objectId;
  }

  /// Get rectangle bounds of the object with the given [objectId].
  ui.Rect get(int objectId) {
    final objects = _objects;
    if (objectId < 0 || objectId >= _nextObjectId || objectId >= objects.length)
      throw ArgumentError('Object with id $objectId not found.');
    final offset = objectId * _objectSize;
    return ui.Rect.fromLTWH(
      objects[offset + 0],
      objects[offset + 1],
      objects[offset + 2],
      objects[offset + 3],
    );
  }

  /// Removes [objectId] from the Quadtree if it exists.
  /// After removal, tries merging nodes upward if possible.
  bool remove(int objectId) {
    if (objectId < 0 ||
        objectId >= _nextObjectId ||
        objectId >= _id2node.length) return false; // Invalid id
    final node = _nodes[_id2node[objectId]];
    if (node == null) return false; // Node not found

    // Remove the object directly from the node and mark the node and its
    // parents as dirty.
    if (!node._remove(objectId)) return false; // Object not found in the node

    _length--; // Decrease the length of the QuadTree
    _id2node[objectId] = 0; // Remove the reference to the node

    // Mark the node and all its parents as dirty
    // and possibly needs optimization.
    // Also decrease the length of the node and all its parents.
    for (QT$N? n = node; n != null; n = n.parent) {
      n._dirty = true;
      n._length--;
    }

    // Resize recycled ids array if needed
    if (_recycledIdsCount == _recycledIds.length)
      _recycledIds = _resizeUint32List(
        _recycledIds,
        _recycledIds.length << 1,
      );
    _recycledIds[_recycledIdsCount++] = objectId;

    return true;
  }

  /// Visit all nodes in the QuadTree.
  /// The walk stops when it iterates over all nodes or
  /// when the callback returns false.
  void visit(bool Function(QT$N node) visitor) => root?.visit(visitor);

  /// Visit all objects in this QuadTree.
  /// The walk stops when it iterates over all objects or
  /// when the callback returns false.
  void forEach(
    bool Function(
      int id,
      double left,
      double top,
      double width,
      double height,
    ) cb,
  ) {
    final root = _root;
    if (root == null) return;
    var offset = 0;
    if (root._subdivided) {
      for (var i = 0; i < _nextObjectId; i++) {
        if (_id2node[i] == 0) continue;
        offset = i * _objectSize;
        final next = cb(
          i, // id of the object
          _objects[offset + 0], // left
          _objects[offset + 1], // top
          _objects[offset + 2], // width
          _objects[offset + 3], // height
        );
        if (next) continue;
        break;
      }
    } else {
      final rootIds = root._ids;
      for (final id in rootIds) {
        offset = id * _objectSize;
        final next = cb(
          id, // id of the object
          _objects[offset + 0], // left
          _objects[offset + 1], // top
          _objects[offset + 2], // width
          _objects[offset + 3], // height
        );
        if (next) continue;
        break;
      }
    }
  }

  /// Query the QuadTree for objects that intersect with the given [rect].
  /// Returns a list of object identifiers.
  List<int> queryIds(ui.Rect rect) {
    if (rect.isEmpty) return const [];

    final root = _root;
    if (root == null) return const [];

    // If the query rectangle fully contains the QuadTree boundary.
    // Return all objects in the QuadTree.
    if (rect.left <= boundary.left &&
        rect.top <= boundary.top &&
        rect.right >= boundary.right &&
        rect.bottom >= boundary.bottom) {
      if (root._subdivided) {
        final results = Uint32List(_length);
        for (var i = 0, j = 0; i < _nextObjectId; i++) {
          if (_id2node[i] != 0) results[j++] = i;
        }
        return results;
      } else {
        return root._ids.toList(growable: false);
      }
    }

    // Visit all suitable nodes in the QuadTree and collect objects.
    final objects = _objects;
    final results = Uint32List(_length);
    final queue = Queue<QT$N>()..add(root);
    var offset = 0;
    var count = 0;
    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      if (!_overlaps(node.boundary, rect)) continue;
      if (node.subdivided) {
        queue
          ..add(node._northWest!)
          ..add(node._northEast!)
          ..add(node._southWest!)
          ..add(node._southEast!);
      } else {
        for (final id in node._ids) {
          offset = id * _objectSize;
          final left = objects[offset + 0],
              top = objects[offset + 1],
              width = objects[offset + 2],
              height = objects[offset + 3];
          if (_overlapsLTWH(rect, left, top, width, height))
            results[count++] = id;
        }
      }
    }
    return results.sublist(0, count);
  }

  /// Query the QuadTree for objects that intersect with the given [rect].
  /// Returns a map of object identifiers and their bounds.
  Map<int, ui.Rect> queryMap(ui.Rect rect) {
    if (rect.isEmpty) return const {};

    final root = _root;
    if (root == null) return const {};

    var offset = 0;
    final objects = _objects;
    final results = HashMap<int, ui.Rect>();

    // If the query rectangle fully contains the QuadTree boundary.
    // Return all objects in the QuadTree.
    if (rect.left <= boundary.left &&
        rect.top <= boundary.top &&
        rect.right >= boundary.right &&
        rect.bottom >= boundary.bottom) {
      if (root._subdivided) {
        for (var i = 0; i < _nextObjectId; i++) {
          if (_id2node[i] == 0) continue;
          offset = i * _objectSize;
          results[i] = ui.Rect.fromLTWH(
            objects[offset + 0],
            objects[offset + 1],
            objects[offset + 2],
            objects[offset + 3],
          );
        }
      } else {
        final rootIds = root._ids;
        for (final id in rootIds) {
          offset = id * _objectSize;
          results[id] = ui.Rect.fromLTWH(
            objects[offset + 0],
            objects[offset + 1],
            objects[offset + 2],
            objects[offset + 3],
          );
        }
      }
      return results;
    }

    // Visit all suitable nodes in the QuadTree and collect objects.
    final queue = Queue<QT$N>()..add(root);
    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      if (!_overlaps(node.boundary, rect)) continue;
      if (node.subdivided) {
        queue
          ..add(node._northWest!)
          ..add(node._northEast!)
          ..add(node._southWest!)
          ..add(node._southEast!);
      } else {
        for (final id in node._ids) {
          offset = id * _objectSize;
          final left = objects[offset + 0],
              top = objects[offset + 1],
              width = objects[offset + 2],
              height = objects[offset + 3];
          if (_overlapsLTWH(rect, left, top, width, height))
            results[id] = ui.Rect.fromLTWH(left, top, width, height);
        }
      }
    }
    return results;
  }

  /// Query the QuadTree for objects that intersect with the given [rect].
  /// Returns a buffer of object data.
  QuadTree$QueryResult query(ui.Rect rect) {
    if (rect.isEmpty) return QuadTree$QueryResult._(Float32List(0));

    final root = _root;
    if (root == null || isEmpty) return QuadTree$QueryResult._(Float32List(0));

    const sizePerObject = QuadTree$QueryResult.sizePerObject; // id + 4 floats
    final objects = _objects;
    var offset = 0;

    // If the query rectangle fully contains the QuadTree boundary.
    // Return all objects in the QuadTree.
    if (rect.left <= boundary.left &&
        rect.top <= boundary.top &&
        rect.right >= boundary.right &&
        rect.bottom >= boundary.bottom) {
      final results = Float32List(_length * sizePerObject);
      final ids = Uint32List.sublistView(results);

      if (root._subdivided) {
        for (var i = 0, j = 0; i < _nextObjectId; i++) {
          if (_id2node[i] == 0) continue;
          offset = i * _objectSize;
          ids[j + 0] = i;
          results[j + 1] = objects[offset + 0];
          results[j + 2] = objects[offset + 1];
          results[j + 3] = objects[offset + 2];
          results[j + 4] = objects[offset + 3];
          j += sizePerObject;
        }
      } else {
        final rootIds = root._ids;
        var j = 0;
        for (final id in rootIds) {
          offset = id * _objectSize;
          ids[j + 0] = id;
          results[j + 1] = objects[offset + 0];
          results[j + 2] = objects[offset + 1];
          results[j + 3] = objects[offset + 2];
          results[j + 4] = objects[offset + 3];
          j += sizePerObject;
        }
      }
      return QuadTree$QueryResult._(results);
    }

    final subdivided = Queue<QT$N>()..add(root);
    final leafs = <QT$N>[];

    // Find all leaf nodes from the subdivided nodes
    while (subdivided.isNotEmpty) {
      final node = subdivided.removeFirst();
      if (node.isEmpty) continue;
      if (!_overlaps(node.boundary, rect)) continue;
      if (node.subdivided) {
        subdivided
          ..add(node._northWest!)
          ..add(node._northEast!)
          ..add(node._southWest!)
          ..add(node._southEast!);
      } else {
        leafs.add(node);
      }
    }

    // Find all objects in the leaf nodes
    // hat intersect with the query rectangle
    /* var j = 0;
    for (var i = 0; i < leafs.length; i++) {
      final node = leafs[i];
      if (!_overlaps(node.boundary, rect)) continue;
      if (i != j) leafs[j] = leafs[i];
      j++;
    }
    leafs.length = j; */

    // No leaf nodes found
    if (leafs.isEmpty) return QuadTree$QueryResult._(Float32List(0));

    // Calculate the maximum possible length of the results
    final length = leafs.fold<int>(0, (sum, node) => sum + node.length);

    // Fill the results with the objects from the leaf nodes
    final results = Float32List(length * sizePerObject);
    final ids = Uint32List.sublistView(results);
    var $length = 0;
    for (final node in leafs) {
      for (final id in node._ids) {
        offset = id * _objectSize;
        final left = objects[offset + 0],
            top = objects[offset + 1],
            width = objects[offset + 2],
            height = objects[offset + 3];
        if (!_overlapsLTWH(rect, left, top, width, height)) continue;
        ids[$length + 0] = id;
        results[$length + 1] = left;
        results[$length + 2] = top;
        results[$length + 3] = width;
        results[$length + 4] = height;
        $length += sizePerObject;
      }
    }

    // No objects found
    if ($length == 0) return QuadTree$QueryResult._(Float32List(0));

    // Resize the results to the actual length
    return QuadTree$QueryResult._(results.sublist(0, $length));
  }

  /// Call this on the root to try merging all possible child nodes.
  /// Recursively merges subtrees that have fewer than [capacity]
  /// objects in total.
  void optimize() {
    final root = _root;
    if (root == null || !root._dirty) return;

    // Visit all nodes in the QuadTree and try to merge them.

    final queue = Queue<QT$N>()..add(root);
    late final toMerge = Queue<QT$N>();

    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      // Skip if not dirty
      if (!node._dirty) continue;
      // Leaf node - nothing to merge, just mark as not dirty
      if (node.leaf) {
        node._dirty = false;
        continue;
      }

      // If too many objects in the node, skip merging and just check children
      if (node.length > capacity) {
        node._dirty = false;
        queue
          ..add(node._northWest!)
          ..add(node._northEast!)
          ..add(node._southWest!)
          ..add(node._southEast!);
        continue;
      }

      // Get all leaf nodes
      toMerge
        ..add(node._northWest!)
        ..add(node._northEast!)
        ..add(node._southWest!)
        ..add(node._southEast!);

      while (toMerge.isNotEmpty) {
        final child = toMerge.removeFirst();
        if (child._subdivided) {
          // Add children to the queue for further merging
          toMerge
            ..add(child._northWest!)
            ..add(child._northEast!)
            ..add(child._southWest!)
            ..add(child._southEast!);
        } else {
          // Merge the child node with the parent node
          node._ids.addAll(child._ids);
          // Link the object id to the parent node
          for (final objectId in child._ids) _id2node[objectId] = node.id;
          child._ids.clear();
        }

        child
          .._length = 0
          .._dirty = false
          .._subdivided = false
          .._northWest = null
          .._northEast = null
          .._southWest = null
          .._southEast = null;
        _nodes[child.id] = null;

        // Resize recycled nodes array if needed
        if (_recycledNodesCount == _recycledNodes.length)
          _recycledNodes = _resizeUint32List(
            _recycledNodes,
            _recycledNodes.length << 1,
          );
        _recycledNodes[_recycledNodesCount++] = child.id;
      }

      // Reset the node to a leaf node with the merged objects
      node
        .._dirty = false
        .._length = node._ids.length
        .._subdivided = false
        .._northWest = null
        .._northEast = null
        .._southWest = null
        .._southEast = null;
    }
  }

  /// Clears the QuadTree and resets all properties.
  void clear() {
    // Break the references between nodes and quadrants and clear the nodes
    final queue = Queue<QT$N?>()..add(_root);
    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      if (node == null) continue;
      if (node.subdivided) {
        queue
          ..add(node._northWest)
          ..add(node._northEast)
          ..add(node._southWest)
          ..add(node._southEast);
      }
      node
        .._dirty = false
        .._length = 0
        .._subdivided = false
        .._northWest = null
        .._northEast = null
        .._southWest = null
        .._southEast = null
        .._ids.clear();
    }
    _root = null;

    // Clear nodes
    _nodesCount = 0;
    _recycledNodesCount = 0;
    _nodes = List<QT$N?>.filled(_reserved, null, growable: false);
    _recycledNodes = Uint32List(_reserved);

    // Clear objects
    _length = 0;
    _nextObjectId = 0;
    _recycledIdsCount = 0;
    _objects = Float32List(_reserved * _objectSize);
    _recycledIds = Uint32List(_reserved);
    _id2node = Uint32List(_reserved);
  }

  // --------------------------------------------------------------------------
  // PRIVATE METHODS
  // --------------------------------------------------------------------------

  /// Create a new QuadTree node with [parent] and [boundary].
  QT$N _createNode({
    required QT$N? parent,
    required ui.Rect boundary,
  }) {
    // Get next id
    final int nodeId;
    if (_recycledNodesCount > 0) {
      // Reuse recycled node id
      nodeId = _recycledNodes[--_recycledNodesCount];
    } else {
      // Add new node
      if (_nodesCount == _nodes.length) {
        // Resize nodes array
        final newSize = _nodesCount << 1;
        _nodes = List<QT$N?>.filled(newSize, null, growable: false)
          ..setAll(0, _nodes);
      }
      nodeId = _nodesCount++; // 0..n
    }
    return _nodes[nodeId] = QT$N._(
      id: nodeId,
      tree: this,
      parent: parent,
      boundary: boundary,
      depth: parent == null ? 0 : parent.depth + 1,
      ids: HashSet<int>(),
    );
  }

  /// Get the next identifier for an object in the QuadTree.
  @pragma('vm:prefer-inline')
  int _getNextObjectId() {
    if (_recycledIdsCount > 0) {
      // Reuse recycled entity
      return _recycledIds[--_recycledIdsCount];
    } else {
      // Add new entity
      final id = _nextObjectId++; // 0..n
      if (id == _id2node.length) {
        // Resize objects array to match the new nodes capacity.
        _objects = _resizeFload32List(_objects, _objects.length << 1);
        // Resize id2node array to match the new nodes capacity.
        _id2node = _resizeUint32List(_id2node, _id2node.length << 1);
      }
      return id;
    }
  }

  // --------------------------------------------------------------------------
  // OVERRIDES
  // --------------------------------------------------------------------------

  @override
  String toString() => 'QuadTree{'
      'nodes: $nodesCount, '
      'objects: $length'
      '}';
}

/// {@template quadtree_node}
/// A node in the QuadTree that represents a region in the 2D space.
/// {@endtemplate}
final class QT$N {
  /// Creates a new QuadTree node with [width], [height], [x], and [y].
  ///
  /// {@macro quadtree_node}
  QT$N._({
    required this.id,
    required this.tree,
    required this.parent,
    required this.boundary,
    required this.depth,
    required Set<int> ids,
  }) : _ids = ids;

  // --------------------------------------------------------------------------
  // PROPERTIES
  // --------------------------------------------------------------------------

  /// The unique identifier of this node.
  final int id;

  /// The QuadTree this node belongs to.
  final QT tree;

  /// The parent node of this node.
  final QT$N? parent;

  /// Boundary of the QuadTree node.
  final ui.Rect boundary;

  /// The depth of this node in the QuadTree.
  /// The root node has a depth of 0.
  /// The depth increases by 1 for each level of the QuadTree.
  final int depth;

  /// Number of objects directly stored in this (for leaf node)
  /// or all nested nodes (for subdivided node).
  int get length => _length;
  int _length = 0;

  /// Whether this node is empty.
  /// Returns true if the node has no objects stored in it or its children.
  bool get isEmpty => _length == 0;

  /// Whether this node is not empty.
  /// Returns true if the node has objects stored in it or its children.
  bool get isNotEmpty => _length > 0;

  /// Unordered set of object identifiers stored in this node.
  Iterable<int> get ids => _ids;
  final Set<int> _ids;

  /// Whether this node has been subdivided.
  /// A subdivided node has four child nodes (quadrants)
  /// and can not directly store objects.
  bool get subdivided => _subdivided;
  bool _subdivided = false;

  /// Whether this node is a leaf node.
  /// A leaf node is a node that has not been subdivided and can store objects.
  bool get leaf => !_subdivided;

  /// Mark this node as dirty and possibly needs optimization to merge with
  /// other nodes.
  bool _dirty = false;

  /// The North-West child node (quadrant) of this node.
  QT$N? get northWest => _northWest;
  QT$N? _northWest;

  /// The North-East child node (quadrant) of this node.
  QT$N? get northEast => _northEast;
  QT$N? _northEast;

  /// The South-West child node (quadrant) of this node.
  QT$N? get southWest => _southWest;
  QT$N? _southWest;

  /// The South-East child node (quadrant) of this node.
  QT$N? get southEast => _southEast;
  QT$N? _southEast;

  /// Get all the child nodes of this node.
  /// Returns an empty list if this node has not been subdivided.
  /// Better to use directly: [northWest], [northEast], [southWest], [southEast]
  List<QT$N> get children => _subdivided
      ? <QT$N>[_northWest!, _northEast!, _southWest!, _southEast!]
      : const [];

  // --------------------------------------------------------------------------
  // PUBLIC METHODS
  // --------------------------------------------------------------------------

  /// Visit nodes in the QuadTree.
  /// The walk stops when it iterates over all nodes or
  /// when the callback returns false.
  @pragma('vm:prefer-inline')
  void visit(bool Function(QT$N node) visitor) {
    final queue = Queue<QT$N>()..add(this);
    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      if (!visitor(node)) return;
      if (node.leaf) continue;
      queue
        ..add(node._northWest!)
        ..add(node._northEast!)
        ..add(node._southWest!)
        ..add(node._southEast!);
    }
  }

  /// Visit all objects in this node and its children.
  /// The walk stops when it iterates over all objects or
  /// when the callback returns false.
  @pragma('vm:prefer-inline')
  void forEach(
    bool Function(
      int id,
      double left,
      double top,
      double width,
      double height,
    ) cb,
  ) {
    if (isEmpty) return;
    if (subdivided) {
      _northWest!.forEach(cb);
      _northEast!.forEach(cb);
      _southWest!.forEach(cb);
      _southEast!.forEach(cb);
    } else {
      final objects = tree._objects;
      int offset;
      for (final id in _ids) {
        offset = id * QT._objectSize;
        final next = cb(
          id, // id of the object
          objects[offset + 0], // left
          objects[offset + 1], // top
          objects[offset + 2], // width
          objects[offset + 3], // height
        );
        if (next) continue;
        return;
      }
    }
  }

  // --------------------------------------------------------------------------
  // PRIVATE METHODS
  // --------------------------------------------------------------------------

  /// Splits the current node into four sub-nodes:
  /// North-West, North-East, South-West, South-East.
  void _subdivide() {
    _dirty = false;
    _subdivided = true;
    final halfWidth = boundary.width / 2;
    final halfHeight = boundary.height / 2;
    final left = boundary.left;
    final top = boundary.top;
    final nw = _northWest = tree._createNode(
          parent: this,
          boundary: ui.Rect.fromLTWH(
            left,
            top,
            halfWidth,
            halfHeight,
          ),
        ),
        ne = _northEast = tree._createNode(
          parent: this,
          boundary: ui.Rect.fromLTWH(
            left + halfWidth,
            top,
            halfWidth,
            halfHeight,
          ),
        ),
        sw = _southWest = tree._createNode(
          parent: this,
          boundary: ui.Rect.fromLTWH(
            left,
            top + halfHeight,
            halfWidth,
            halfHeight,
          ),
        ),
        se = _southEast = tree._createNode(
          parent: this,
          boundary: ui.Rect.fromLTWH(
            left + halfWidth,
            top + halfHeight,
            halfWidth,
            halfHeight,
          ),
        );

    // Fill the new nodes with the objects from the parent node.
    final objects = tree._objects;
    final id2node = tree._id2node;
    for (final objectId in _ids) {
      final offset = objectId * QT._objectSize;

      final left = objects[offset + 0],
          top = objects[offset + 1],
          width = objects[offset + 2],
          height = objects[offset + 3];

      final rectCenterX = left + width / 2.0;
      final rectCenterY = top + height / 2.0;

      // Pick the most suitable leaf node for the object.
      final QT$N node;
      if (_southWest!.boundary.top > rectCenterY) {
        if (_northWest!.boundary.right > rectCenterX) {
          node = nw; // North-West
        } else {
          node = ne; // North-East
        }
      } else {
        if (_southWest!.boundary.right > rectCenterX) {
          node = sw; // South-West
        } else {
          node = se; // South-East
        }
      }

      // Migrate object's id to the new nested node:
      node._ids.add(objectId);

      // Increase the number of objects in the nested node.
      node._length++;

      // Store the reference between the id and the current leaf node.
      id2node[objectId] = node.id;
    }
    _ids.clear();
  }

  /// Insert an object with [objectId] into the QuadTree node or its children.
  /// Returns id of the node where the object was inserted.
  int _insert(int objectId, ui.Rect rect) {
    // Increase the number of objects in the node.
    _length++;

    // Should we insert the object directly into this node?
    // If the node is a leaf node
    // and has enough capacity or reached the max depth.
    if (leaf && (_length < tree.capacity || depth >= tree.depth)) {
      // Add object to the node
      _ids.add(objectId);
      return id;
    }

    // If not subdivided yet, subdivide.
    if (!_subdivided) _subdivide();

    // Pick the most suitable leaf node for the object.
    final rectCenterX = rect.left + rect.width / 2.0;
    final rectCenterY = rect.top + rect.height / 2.0;
    if (_southWest!.boundary.top > rectCenterY) {
      if (_northWest!.boundary.right > rectCenterX) {
        return _northWest!._insert(objectId, rect); // North-West
      } else {
        return _northEast!._insert(objectId, rect); // North-East
      }
    } else {
      if (_southWest!.boundary.right > rectCenterX) {
        return _southWest!._insert(objectId, rect); // South-West
      } else {
        return _southEast!._insert(objectId, rect); // South-East
      }
    }
  }

  /// Remove the object with the given [id] from this node.
  /// This method should be called only from the QuadTree.
  /// Because the only QuadTree can free and recycle object ids.
  ///
  /// Returns true if the object was removed successfully.
  /// Returns false if the object was not found in this node.
  bool _remove(int id) => _ids.remove(id);

  // --------------------------------------------------------------------------
  // OVERRIDES
  // --------------------------------------------------------------------------

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is QT$N && id == other.id;

  @override
  String toString() => r'QuadTree$Node{'
      'id: $id, '
      'objects: $length, '
      'subdivided: $_subdivided'
      '}';
}

// --------------------------------------------------------------------------
// UTILS
// --------------------------------------------------------------------------

/// Checks if rectangles [a] and [b] overlap by coordinate checks.
@pragma('vm:prefer-inline')
bool _overlaps(ui.Rect a, ui.Rect b) =>
    a.left <= b.right &&
    a.right >= b.left &&
    a.top <= b.bottom &&
    a.bottom >= b.top;

/// Checks if rectangle [rect] overlaps with the rectangle defined by
/// [left], [top], [width], and [height].
@pragma('vm:prefer-inline')
bool _overlapsLTWH(
  ui.Rect rect,
  double left,
  double top,
  double width,
  double height,
) =>
    rect.left <= left + width &&
    rect.right >= left &&
    rect.top <= top + height &&
    rect.bottom >= top;

/// Resizes a Uint32List to [newCapacity].
@pragma('vm:prefer-inline')
Uint32List _resizeUint32List(Uint32List array, int newCapacity) =>
    Uint32List(newCapacity)..setAll(0, array);

/// Resizes a Float32List to [newCapacity].
@pragma('vm:prefer-inline')
Float32List _resizeFload32List(Float32List array, int newCapacity) =>
    Float32List(newCapacity)..setAll(0, array);
