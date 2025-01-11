// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui show Rect;

import 'package:meta/meta.dart';

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
///
/// The QuadTree is a tree data structure in which each internal node has
/// exactly four children: North-West, North-East, South-West, and South-East.
/// Each node represents a rectangular region of the space.
///
/// The QuadTree is a spatial partitioning algorithm that is used to subdivide
/// a two-dimensional space into smaller regions for efficient collision
/// detection and spatial queries.
///
/// [boundary] is the boundary of the QuadTree, usually the size of the game
/// world coordinates or the screen size.
///
/// [capacity] is the maximum number of objects that can be stored in a node
/// before it subdivides.
/// Suitable values for the capacity are usually between 18 and 24.
/// Should be always greater or equal than 6.
///
/// [depth] is the maximum depth of the QuadTree. If the depth is reached,
/// the QuadTree will not subdivide further and [capacity] will be ignored.
/// Suitable values for the depth are usually between 8 and 16.
/// Should be always greater or equal than 1.
///
/// This formula computes the maximum depth of a quad tree based on the overall
/// boundary size (`Boundary`) and
/// the desired minimal boundary size (`Size`) for each node:
///
///    maxDepth = ceil(log2(Boundary / Size))
///
/// Where:
/// - Boundary is the length of the entire boundary (e.g., the width or height
///   of the area, assuming a square).
/// - Size is the desired minimal boundary size for a node.
/// - log2(...) is the logarithm base 2.
/// - ceil(...) means rounding up to the next integer.
///
/// For example, if the boundary is 1024x1024 and the desired minimal size is
/// 64x64, the maximum depth of the quad tree will be:
///   maxDepth = ceil(log2(1024 / 64)) = ceil(log2(16)) = ceil(4) = 4
///
/// The quad tree subdivides its space by splitting each node
/// into four quadrants, effectively halving the boundary at every level.
/// Once the boundary size reaches the desired minimal size,
/// the maximum depth is reached.
///
/// {@endtemplate}
final class QuadTree {
  /// Creates a new Quadtree with [boundary] and a [capacity].
  ///
  /// {@macro quadtree}
  factory QuadTree({
    // Boundary of the QuadTree.
    required ui.Rect boundary,
    // Capacity of the each QuadTree node.
    int capacity = 24,
    // Maximum depth of the QuadTree.
    int depth = 12,
  }) {
    // Make copy of the boundary
    final rect = ui.Rect.fromLTRB(
      boundary.left,
      boundary.top,
      boundary.right,
      boundary.bottom,
    );
    // Validate the parameters
    assert(rect.isFinite, 'The boundary must be finite.');
    assert(!rect.isEmpty, 'The boundary must not be empty.');
    assert(capacity >= 6, 'The capacity must be greater or equal than 6.');
    assert(depth >= 1, 'The maximum depth must be greater or equal than 1.');
    assert(depth <= 7000, 'The maximum depth must be less or equal than 7000.');
    // Initialize the QuadTree
    final nodes = List<QuadTree$Node?>.filled(_reserved, null, growable: false);
    final recycledNodes = Uint32List(_reserved);
    final objects = Float32List(_reserved * _objectSize);
    final recycledIds = Uint32List(_reserved);
    final id2node = Uint32List(_reserved);
    // Create the QuadTree
    return QuadTree._internal(
      boundary: rect,
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
  QuadTree._internal({
    required this.boundary,
    required this.capacity,
    required this.depth,
    required List<QuadTree$Node?> nodes,
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
  static const int _objectSize = 4;

  /// Initial reserved size for the each array withing the QuadTree.
  static const int _reserved = 64;

  /// The root node of the QuadTree.
  QuadTree$Node? get root => _root;
  QuadTree$Node? _root;

  /// The next identifier for a node in the QuadTree
  int _nodesCount = 0;

  /// Recycled objects in this manager.
  int _recycledNodesCount = 0;

  /// Recycled nodes ids in this manager.
  Uint32List _recycledNodes;

  /// Number of active nodes in the QuadTree.
  int get nodes => _nodesCount - _recycledNodesCount;

  /// List of nodes in the QuadTree.
  /// Each index in the list is the identifier of the node.
  List<QuadTree$Node?> _nodes;

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

    final offset = objectId * _objectSize;
    // Store the object's coordinates in the objects array.
    _objects
      ..[offset + 0] = rect.left
      ..[offset + 1] = rect.top
      ..[offset + 2] = rect.width
      ..[offset + 3] = rect.height;

    // Find the node to insert the object
    final nodeId = root._insert(
      objectId,
      rect.left,
      rect.top,
      rect.width,
      rect.height,
    );

    // Store the reference between the id and the current node.
    _id2node[objectId] = nodeId;

    return objectId;
  }

  /// Get rectangle bounds of the object with the given [objectId].
  ui.Rect get(int objectId) {
    final objects = _objects;
    if (objectId < 0 || objectId >= objects.length)
      throw ArgumentError('Object with id $objectId not found.');
    final offset = objectId * _objectSize;
    return ui.Rect.fromLTWH(
      objects[offset + 0],
      objects[offset + 1],
      objects[offset + 2],
      objects[offset + 3],
    );
  }

  /// Move the object with the given [objectId] to the new position
  /// [left] (x), [top] (y).
  void move(int objectId, double left, double top) {
    final root = _root;
    if (root == null) return;
    if (objectId < 0 || objectId >= _id2node.length) return;
    final nodeId = _id2node[objectId];
    if (nodeId >= _nodes.length) return;
    final node = _nodes[nodeId];

    final objects = _objects;
    final offset = objectId * _objectSize;

    // Update the object's coordinates.
    objects[offset + 0] = left;
    objects[offset + 1] = top;

    // Get the object's width and height.
    final width = objects[offset + 2];
    final height = objects[offset + 3];

    // Check if the object still fits in the same node's boundary.
    if (node == null) {
      assert(false, 'Current node not found for object with id $objectId.');
      // Insert the object to the QuadTree at the new position.
      final nodeId = root._insert(objectId, left, top, width, height);
      _id2node[objectId] = nodeId;
    } else if (_overlapsLTWH(node.boundary, left, top, width, height)) {
      // The object still fits in the same node's boundary.
      // Coordinate already updated - nothing to do.
    } else {
      // The object moved outside the boundary of the QuadTree.
      // Remove the object from the QuadTree and insert it back.
      // Do not change the object's id.
      node._remove(objectId);

      // Mark the node and all its parents as dirty
      // and possibly needs optimization.
      // Also decrease the length of the node and all its parents.
      for (QuadTree$Node? n = node; n != null; n = n.parent) {
        n._dirty = true;
        n._length--;
      }

      // Insert the object back into the QuadTree at the new position
      // with the same id.
      final nodeId = root._insert(objectId, left, top, width, height);
      _id2node[objectId] = nodeId;
    }
  }

  /// Removes [objectId] from the Quadtree if it exists.
  /// After removal, tries merging nodes upward if possible.
  bool remove(int objectId) {
    if (objectId < 0 || objectId >= _id2node.length) return false; // Invalid id
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
    for (QuadTree$Node? n = node; n != null; n = n.parent) {
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
  void visit(bool Function(QuadTree$Node node) visitor) => root?.visit(visitor);

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
  ///
  /// This method is two times faster than [queryMap] and [query].
  /// And should be used when you need only object identifiers.
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
    final queue = Queue<QuadTree$Node>()..add(root);
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
    final queue = Queue<QuadTree$Node>()..add(root);
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

    final subdivided = Queue<QuadTree$Node>()..add(root);
    final leafs = <QuadTree$Node>[];

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

    final queue = Queue<QuadTree$Node>()..add(root);
    late final toMerge = Queue<QuadTree$Node>();

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
    final queue = Queue<QuadTree$Node?>()..add(_root);
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
    _nodes = List<QuadTree$Node?>.filled(_reserved, null, growable: false);
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
  QuadTree$Node _createNode({
    required QuadTree$Node? parent,
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
        _nodes = List<QuadTree$Node?>.filled(newSize, null, growable: false)
          ..setAll(0, _nodes);
      }
      nodeId = _nodesCount++; // 0..n
    }
    return _nodes[nodeId] = QuadTree$Node._(
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
  // TESTING, DEBUG AND HEALTHCHECKS
  // --------------------------------------------------------------------------

  /// Health check for the QuadTree node.
  /// Returns a list of problems found in the QuadTree.
  ///
  /// Main purpose is to check if the QuadTree is in a valid state.
  /// You should not rely on this method for production code as it is
  /// very-verry slow and expensive.
  /// Better to use this method for debugging and testing.
  ///
  /// Should be called only after [optimize] method.
  @visibleForTesting
  List<String> healthCheck() {
    final errors = <String>[];
    if (capacity < 6) errors.add('Capacity must be greater or equal than 6.');
    final nodeIds = <int>{};
    if (_root?._dirty ?? false)
      errors.add('Root node is dirty (call optimize).');
    //final objects = <int>{};
    visit((node) {
      if (nodeIds.contains(node.id))
        errors.add('Node #${node.id} is visited more than once or duplicated.');
      nodeIds.add(node.id);
      if (!identical(_nodes[node.id], node))
        errors.add('Node #${node.id} is not stored in the nodes array.');
      if (node._dirty) {
        errors.add('Node #${node.id} is dirty (call optimize).');
      }
      if (node.leaf) {
        if (node._subdivided)
          errors.add('Leaf node #${node.id} is subdivided.');
        if (node.length > capacity && node.depth < depth)
          errors.add('Leaf node #${node.id} has too many objects.');
        if (node._ids.length != node.length)
          errors.add('Leaf node #${node.id} has invalid objects count.');

        for (final objectId in node._ids) {
          if (objectId >= _nextObjectId)
            errors.add('Leaf node #${node.id} has invalid object id.');
          if (_id2node[objectId] != node.id)
            errors.add('Leaf node #${node.id} has invalid object reference.');
        }

        var child = node;
        var parent = node.parent;
        while (true) {
          if (parent == null) {
            if (!identical(child, _root))
              errors.add('Leaf node #${child.id} has no parent.');
            break; // Root node
          }

          if (child._length > parent.length)
            errors.add('Leaf node #${child.id} has more objects than parent.');
          if (!nodeIds.contains(parent.id))
            errors.add('Parent node #${parent.id} is not visited.');

          child = parent;
          parent = parent.parent;
        }
      } else if (node.subdivided) {
        if (!node._subdivided)
          errors.add('Subdivided node #${node.id} is not subdivided.');
        if (node._ids.isNotEmpty)
          errors.add('Subdivided node #${node.id} has objects.');
        if (node._length < 1)
          errors.add('Subdivided node #${node.id} is empty (call optimize).');
        if (node._length < capacity) {
          if (node._northWest!.subdivided)
            errors.add('Subdivided node #${node.id} is not optimized.');
          else if (node._northEast!.subdivided)
            errors.add('Subdivided node #${node.id} is not optimized.');
          else if (node._southWest!.subdivided)
            errors.add('Subdivided node #${node.id} is not optimized.');
          else if (node._southEast!.subdivided)
            errors.add('Subdivided node #${node.id} is not optimized.');
        }
        if (node._ids.isNotEmpty)
          errors.add('Subdivided node #${node.id} has non-empty objects set.');
      }
      return true; // Continue visiting
    });

    // Check if all nodes are visited
    if (nodes != nodeIds.length)
      errors.add('Invalid nodes count: $nodes != ${nodeIds.length}.');

    return errors;
  }

  // --------------------------------------------------------------------------
  // OVERRIDES
  // --------------------------------------------------------------------------

  @override
  String toString() => 'QuadTree{'
      'nodes: $nodes, '
      'objects: $length'
      '}';
}

/// {@template quadtree_node}
/// A node in the QuadTree that represents a region in the 2D space.
/// {@endtemplate}
final class QuadTree$Node {
  /// Creates a new QuadTree node with [width], [height], [x], and [y].
  ///
  /// {@macro quadtree_node}
  QuadTree$Node._({
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
  final QuadTree tree;

  /// The parent node of this node.
  final QuadTree$Node? parent;

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
  QuadTree$Node? get northWest => _northWest;
  QuadTree$Node? _northWest;

  /// The North-East child node (quadrant) of this node.
  QuadTree$Node? get northEast => _northEast;
  QuadTree$Node? _northEast;

  /// The South-West child node (quadrant) of this node.
  QuadTree$Node? get southWest => _southWest;
  QuadTree$Node? _southWest;

  /// The South-East child node (quadrant) of this node.
  QuadTree$Node? get southEast => _southEast;
  QuadTree$Node? _southEast;

  /// Get all the child nodes of this node.
  /// Returns an empty list if this node has not been subdivided.
  /// Better to use directly: [northWest], [northEast], [southWest], [southEast]
  List<QuadTree$Node> get children => _subdivided
      ? <QuadTree$Node>[_northWest!, _northEast!, _southWest!, _southEast!]
      : const [];

  // --------------------------------------------------------------------------
  // PUBLIC METHODS
  // --------------------------------------------------------------------------

  /// Visit nodes in the QuadTree.
  /// The walk stops when it iterates over all nodes or
  /// when the callback returns false.
  @pragma('vm:prefer-inline')
  void visit(bool Function(QuadTree$Node node) visitor) {
    final queue = Queue<QuadTree$Node>()..add(this);
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
        offset = id * QuadTree._objectSize;
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
      final offset = objectId * QuadTree._objectSize;

      final left = objects[offset + 0],
          top = objects[offset + 1],
          width = objects[offset + 2],
          height = objects[offset + 3];

      final rectCenterX = left + width / 2.0;
      final rectCenterY = top + height / 2.0;

      // Pick the most suitable leaf node for the object.
      final QuadTree$Node node;
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
  int _insert(
    int objectId,
    double left,
    double top,
    double width,
    double height,
  ) {
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
    final rectCenterX = left + width / 2.0;
    final rectCenterY = top + height / 2.0;
    if (_southWest!.boundary.top > rectCenterY) {
      if (_northWest!.boundary.right > rectCenterX) {
        // North-West
        return _northWest!._insert(objectId, left, top, width, height);
      } else {
        // North-East
        return _northEast!._insert(objectId, left, top, width, height);
      }
    } else {
      if (_southWest!.boundary.right > rectCenterX) {
        // South-West
        return _southWest!._insert(objectId, left, top, width, height);
      } else {
        // South-East
        return _southEast!._insert(objectId, left, top, width, height);
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
      identical(this, other) || other is QuadTree$Node && id == other.id;

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

// TODO(plugfox): Add collision detection and spatial queries.
// Использование битовых масок (BitWise) для определения того,
// какие объекты могут коллайдить между собой,
// – довольно распространённый и эффективный подход в игровых движках.
// Он хорошо масштабируется и упрощает логику фильтрации коллизий
// при большом количестве типов объектов. Ниже несколько соображений:
//
// Управление коллизиями
//
// С помощью битовых масок можно быстро проверить,
// нужно ли вообще рассматривать коллизию двух объектов,
// используя операцию & (логическое И).
// Добавляя новые типы объектов и фракций, вы легко расширяете систему,
// просто назначая каждому объекту свой бит в маске (или же набор битов).
// Гибкость настройки
//
// Обычно каждому объекту назначают categoryBits (какой он тип)
// и maskBits (с чем должен взаимодействовать).
// Пример: у снаряда есть categoryBits = 0x0002 (т. е. второй бит),
// а у противника – maskBits, где выставлен этот же второй бит.
// Если (categoryBits & maskBits) != 0,
// значит они должны обрабатываться как потенциальная коллизия.
// Mike Matiunin <plugfox@gmail.com>, 08 January 2025
