import 'dart:collection';
import 'dart:typed_data';
import 'dart:ui' as ui show Rect;

import 'package:meta/meta.dart';

/// {@template quadtree}
/// A Quadtree data structure that subdivides a 2D space into four quadrants
/// to speed up collision detection and spatial queries.
/// {@endtemplate}
final class QuadTree {
  /// Creates a new Quadtree with [boundary] and a [capacity].
  ///
  /// {@macro quadtree}
  factory QuadTree({
    required ui.Rect boundary,
    int capacity = 10,
  }) {
    assert(boundary.isFinite, 'The boundary must be finite.');
    assert(!boundary.isEmpty, 'The boundary must not be empty.');
    assert(capacity >= 4, 'The capacity must be greater or equal than 4.');
    final nodeSize = capacity * 5;
    const reserved = 64;
    final nodes = List<QuadTree$Node?>.filled(reserved, null, growable: false);
    final recycledNodes = Uint32List(reserved);
    final objects = Float32List(reserved * nodeSize);
    final idsView = Uint32List.sublistView(objects);
    final recycledIds = Uint32List(reserved);
    return QuadTree._(
      boundary: boundary,
      capacity: capacity,
      nodeSize: nodeSize,
      nodes: nodes,
      recycledNodes: recycledNodes,
      objects: objects,
      ids: idsView,
      nextId: 1,
      recycledIdsCount: 0,
      recycledIds: recycledIds,
    );
  }

  /// Internal constructor for the QuadTree.
  QuadTree._({
    required this.boundary,
    required this.capacity,
    required int nodeSize,
    required List<QuadTree$Node?> nodes,
    required Uint32List recycledNodes,
    required Float32List objects,
    required Uint32List ids,
    required int nextId,
    required int recycledIdsCount,
    required Uint32List recycledIds,
  })  :
        // Nodes
        _nodeSize = nodeSize,
        _nodesCount = 0,
        _recycledNodesCount = 0,
        _nodes = nodes,
        _recycledNodes = recycledNodes,
        // Objects
        _id2node = Uint32List(64),
        _objects = objects,
        _idsView = ids,
        _nextId = nextId,
        _recycledIdsCount = recycledIdsCount,
        _recycledIds = recycledIds;

  // --------------------------------------------------------------------------
  // PROPERTIES
  // --------------------------------------------------------------------------

  /// Boundary of the QuadTree.
  final ui.Rect boundary;

  /// The maximum number of objects that can be stored in a node before it
  /// subdivides.
  final int capacity;

  // --------------------------------------------------------------------------
  // STORAGE
  // --------------------------------------------------------------------------

  /// The size of a node in the QuadTree in bytes.
  final int _nodeSize;

  /// The root node of the QuadTree.
  QuadTree$Node? _root;

  /// The next identifier for a node in the QuadTree
  int _nodesCount;

  /// Number of active objects in the QuadTree.
  int get nodesCount => _nodesCount - _recycledNodesCount;

  /// List of nodes in the QuadTree.
  /// Each index in the list is the identifier of the node:
  /// `list[id] == node.id`
  List<QuadTree$Node?> _nodes;

  /// Recycled objects in this manager.
  int _recycledNodesCount;

  /// Recycled nodes in this manager.
  Uint32List _recycledNodes;

  /// Number of active objects in the QuadTree.
  int get length => _length;
  int _length = 0;

  /// List of objects in the QuadTree.
  ///
  /// Each object is stored in a contiguous block of memory.
  /// The first object starts at index 0, the second object starts at index 5,
  /// the third object starts at index 10, and so on.
  ///
  /// The objects are stored as a Float32List with the following format:
  /// [id, width, height, x, y]
  /// - id: The identifier of the object in the QuadTree.
  /// - width: The width of the object.
  /// - height: The height of the object.
  /// - x: The x-coordinate of the object.
  /// - y: The y-coordinate of the object.
  Float32List _objects;

  /// Ids of the objects in the QuadTree.
  /// Each object is stored in a contiguous block of memory.
  ///
  /// The objects are stored as a Uint32List with the following format:
  /// [id, _, _, _, _]
  /// - id: The identifier of the object in the QuadTree.
  ///
  /// Other fields are from the object data.
  Uint32List _idsView;

  /// The next identifier for an object in the QuadTree.
  int _nextId = 1;

  /// Recycled ids in this manager count.
  int _recycledIdsCount = 0;

  /// References between ids and nodes.
  /// Index is the id and value is the node id.
  Uint32List _id2node;

  /// Recycled ids in this manager array.
  Uint32List _recycledIds;

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

        if (_nodeSize * newSize > _objects.length) {
          // Resize objects array to match the new nodes capacity.
          _objects = _resizeFload32List(_objects, _nodeSize * newSize);
        }
      }
      nodeId = _nodesCount++; // 0..n
    }

    // Create a new node and store it in the nodes array.
    final objectsView = Float32List.sublistView(
      _objects,
      nodeId * _nodeSize,
      nodeId * _nodeSize + _nodeSize,
    )..fillRange(0, _nodeSize, 0); // Fill with zeros
    final idsView = Uint32List.sublistView(
      _objects,
      nodeId * _nodeSize,
      nodeId * _nodeSize + _nodeSize,
    );
    return _nodes[nodeId] = QuadTree$Node._(
      id: nodeId,
      tree: this,
      parent: parent,
      boundary: boundary,
      capacity: capacity,
      objectsView: objectsView,
      idsView: idsView,
    );
  }

  /// Get the node with the given [id].
  //@pragma('vm:prefer-inline')
  //QuadTree$Node? _getNode(int id) => _nodes[id];

  /// Get the next identifier for an object in the QuadTree.
  @pragma('vm:prefer-inline')
  int _getNextId() {
    if (_recycledIdsCount > 0) {
      // Reuse recycled entity
      return _recycledIds[--_recycledIdsCount];
    } else {
      // Add new entity
      final id = _nextId++; // 1..n
      if (id == _id2node.length)
        _id2node = _resizeUint32List(_id2node, id << 1);
      return id;
    }
  }

  // --------------------------------------------------------------------------
  // INSERTION, REMOVAL, QUERY
  // --------------------------------------------------------------------------

  /// Insert an rectangle into the QuadTree.
  /// Returns the identifier of the object in the QuadTree.
  /// Returns null if the object does not fit in the QuadTree.
  int? insert(ui.Rect rect) {
    assert(rect.isFinite, 'The rectangle must be finite.');

    // Get the root node of the QuadTree
    // or create a new one if it does not exist.
    final root = _root ??= _createNode(
      parent: null,
      boundary: boundary,
    );

    // Find the node to insert the object
    final id = root._insert(rect);

    if (id != null) {
      // Object was inserted successfully
      _length++;
    }

    return id;
  }

  /// Get rectangle bounds of the object with the given [id].
  ui.Rect get(int id) {
    if (id < 1 || id >= _nextId || id >= _id2node.length)
      throw ArgumentError('Object with id $id not found.');
    final node = _nodes[_id2node[id]];
    if (node == null) throw ArgumentError('Object with id $id not found.');
    for (var i = 0; i < _nodeSize; i += 5) {
      if (node._idsView[i] != id) continue;
      return ui.Rect.fromLTWH(
        node._objectsView[i + 3], // left (x)
        node._objectsView[i + 4], // top (y)
        node._objectsView[i + 1], // width
        node._objectsView[i + 2], // height
      );
    }
    throw ArgumentError('Object with id $id not found.');
  }

  // TODO(plugfox):
  // Get many objects at once
  // Query
  // Optimize
  // Visitors
  // Mike Matiunin <plugfox@gmail.com>, 07 January 2025

  /// Removes [id] from the Quadtree if it exists.
  /// After removal, tries merging nodes upward if possible.
  void remove(int id, {bool optimize = true}) {
    if (id < 1 || id >= _nextId || id >= _id2node.length) return;
    final node = _nodes[_id2node[id]];
    _id2node[id] = 0; // Clear reference
    if (node == null) return;
    for (var i = 0; i < _nodeSize; i += 5) {
      if (node._idsView[i] != id) continue;
      node._idsView[i] = 0; // Clear id
      node._objectsView.fillRange(i, i + 5, 0); // Clear object
      node._objectsCount--;

      // Mark the node and all its parents as dirty
      // and possibly needs optimization.
      // Also decrease the length of the node and all its parents.
      for (QuadTree$Node? n = node; n != null; n = n.parent) {
        n._dirty = true;
        n._length--;
      }

      // Decrease the length of the QuadTree
      _length--;
      break;
    }
  }

  /// Clears the QuadTree and resets all properties.
  void clear() {
    // Clear nodes
    _nodesCount = 0;
    _recycledNodesCount = 0;
    _nodes = List<QuadTree$Node?>.filled(64, null, growable: false);
    _recycledNodes = Uint32List(64);
    _root = null;

    // Clear objects
    _length = 0;
    _objects = Float32List(64 * _nodeSize);
    _idsView = Uint32List.sublistView(_objects);

    // Clear ids
    _nextId = 1;
    _recycledIdsCount = 0;
    _id2node = Uint32List(64);
    _recycledIds = Uint32List(64);
  }

  // --------------------------------------------------------------------------
  // VISITORS AND ITTERATORS
  // --------------------------------------------------------------------------

  /// Visit all nodes in the QuadTree.
  void visit(void Function(QuadTree$Node node) visitor) {
    final root = _root;
    if (root == null) return;
    final queue = Queue<QuadTree$Node>()..add(root);
    while (queue.isNotEmpty) {
      final node = queue.removeFirst();
      visitor(node);
      if (node.leaf) continue;
      queue
        ..add(node._northWest!)
        ..add(node._northEast!)
        ..add(node._southWest!)
        ..add(node._southEast!);
    }
  }

  // --------------------------------------------------------------------------
  // OPTIMIZATION (MERGING)
  // --------------------------------------------------------------------------

  /// Call this on the root to try merging all possible child nodes.
  /// Recursively merges subtrees that have fewer than [capacity]
  /// objects in total.
  void optimize() {
    final root = _root;
    if (root == null || !root._dirty) return;

    final queue = Queue<QuadTree$Node>()..add(root);
    late final toMerge = Queue<QuadTree$Node>();

    while (queue.isNotEmpty) {
      final node = queue.removeFirst();

      // Skip if not dirty
      // Leaf node - nothing to merge, just mark as not dirty
      if (!node._dirty || node.leaf) {
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
      var count = 0;
      var offset = 0;
      final ids = node._idsView;
      final objects = node._objectsView;

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
          for (var i = 0; i < _nodeSize; i += 5) {
            final id = child._idsView[i];
            if (id == 0) continue; // Skip empty slots
            final dataToMerge = child._objectsView;

            // Fill the object data in the parent node
            ids[offset + 0] = id;
            objects
              ..[offset + 1] = dataToMerge[i + 1]
              ..[offset + 2] = dataToMerge[i + 2]
              ..[offset + 3] = dataToMerge[i + 3]
              ..[offset + 4] = dataToMerge[i + 4];
            offset += 5;
            count++;

            // Link the object id to the parent node
            _id2node[id] = node.id;
          }
        }

        // Remove this node from the QuadTree and add it to the recycled nodes
        child
          .._length = 0
          .._objectsCount = 0
          .._objectsView.fillRange(0, _nodeSize, 0)
          .._subdivided = false
          .._northWest = null
          .._northEast = null
          .._southWest = null
          .._southEast = null;
        _nodes[child.id] = null;
        _recycledNodes[_recycledNodesCount++] = child.id;
      }

      // Reset the node to a leaf node with the merged objects
      node
        .._dirty = false
        .._subdivided = false
        .._objectsCount = count
        .._northWest = null
        .._northEast = null
        .._southWest = null
        .._southEast = null;

      assert(count == node.length, 'Invalid count of objects after merging.');
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
    if (capacity < 4) errors.add('Capacity must be greater or equal than 4.');
    final nodeIds = <int>{};
    //final objects = <int>{};
    visit((node) {
      if (nodeIds.contains(node.id))
        errors.add('Node #${node.id} is visited more than once or duplicated.');
      nodeIds.add(node.id);
      if (!identical(_nodes[node.id], node))
        errors.add('Node #${node.id} is not stored in the nodes array.');
      if (node._dirty) {
        errors.add('Node #${node.id} is dirty (call optimize).');
      } else if (node.leaf) {
        if (node._subdivided)
          errors.add('Leaf node #${node.id} is subdivided.');
        if (node._objectsCount > capacity)
          errors.add('Leaf node #${node.id} has too many objects.');
        if (node._objectsCount != node.length)
          errors.add('Leaf node #${node.id} has invalid objects count.');

        var counter = 0;
        for (var i = 0; i < _nodeSize; i += 5) {
          final id = node._idsView[i];
          if (id == 0) continue; // Skip empty slots
          if (id >= _nextId)
            errors.add('Leaf node #${node.id} has invalid object id.');
          if (_id2node[id] != node.id)
            errors.add('Leaf node #${node.id} has invalid object reference.');
          final width = node._objectsView[i + 1];
          final height = node._objectsView[i + 2];
          final left = node._objectsView[i + 3];
          final top = node._objectsView[i + 4];
          if (left > boundary.right)
            errors.add('Object #$id outside the boundary.');
          if (top > boundary.bottom)
            errors.add('Object #$id outside the boundary.');
          if (left + width < boundary.left)
            errors.add('Object #$id outside the boundary.');
          if (top + height < boundary.top)
            errors.add('Object #$id outside the boundary.');
          counter++;
        }
        if (counter != node._objectsCount)
          errors.add('Leaf node #${node.id} has invalid objects count.');

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
      } else {
        if (!node._subdivided)
          errors.add('Subdivided node #${node.id} is not subdivided.');
        if (node._objectsCount != 0)
          errors.add('Subdivided node #${node.id} has objects.');
        if (node._length < 1)
          errors.add('Subdivided node #${node.id} is empty (call optimize).');

        final bytes = node._objectsView;
        if (bytes.any((byte) => byte != 0))
          errors.add('Subdivided node #${node.id} has non-empty data.');
      }
    });

    // Check if all nodes are visited
    if (nodesCount != nodeIds.length)
      errors.add('Invalid nodes count: $nodesCount != ${nodeIds.length}.');

    return errors;
  }

  @override
  String toString() => 'QuadTree{'
      'nodes: $nodesCount, '
      'objects: $length'
      '}';
}

/// {@template quadtree_node}
/// A node in the QuadTree that represents a region in the 2D space.
/// {@endtemplate}
class QuadTree$Node {
  /// Creates a new QuadTree node with [width], [height], [x], and [y].
  ///
  /// {@macro quadtree_node}
  QuadTree$Node._({
    required this.id,
    required this.tree,
    required this.parent,
    required this.boundary,
    required this.capacity,
    required Float32List objectsView,
    required Uint32List idsView,
  })  : offset = id * capacity * 4,
        _objectsView = objectsView,
        _idsView = idsView,
        _length = 0,
        _objectsCount = 0,
        _subdivided = false,
        _dirty = false;

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

  /// The maximum number of objects that can be stored in a node before it
  /// subdivides.
  final int capacity;

  /// The offset of the first object in the objects list.
  final int offset;

  /// The objects stored in this node.
  final Float32List _objectsView;

  /// The ids of the objects stored in this node.
  final Uint32List _idsView;

  /// Number of objects directly stored in this (for leaf node)
  /// or all nested nodes (for subdivided node).
  int get length => _length;
  int _length;

  /// Number of objects stored directly in this node.
  int _objectsCount;

  /// Whether this node has been subdivided.
  /// A subdivided node has four child nodes (quadrants)
  /// and can not directly store objects.
  bool get subdivided => _subdivided;
  bool _subdivided;

  /// Whether this node is a leaf node.
  /// A leaf node is a node that has not been subdivided and can store objects.
  bool get leaf => !_subdivided;

  /// Child nodes (quadrants).
  QuadTree$Node? _northWest;
  QuadTree$Node? _northEast;
  QuadTree$Node? _southWest;
  QuadTree$Node? _southEast;

  /// Mark this node as dirty and possibly needs optimization to merge with
  /// other nodes.
  bool _dirty;

  /// Try to insert an object into this node.
  int? _insert(ui.Rect rect) {
    // Check if the object fits in the QuadTree.
    if (!_overlaps(boundary, rect)) return null;

    // Should we insert the object directly into this node?
    if (_objectsCount < capacity && leaf) {
      // Get next id
      final id = tree._getNextId();

      // Insert to free slot
      final nodeSize = capacity * 5;
      for (var i = 0; i < nodeSize; i += 5) {
        final byte = _idsView[i]; // id
        if (byte != 0) continue; // Skip used slots

        // Fill the object data in the entities array
        _idsView[i + 0] = id;
        _objectsView[i + 1] = rect.width;
        _objectsView[i + 2] = rect.height;
        _objectsView[i + 3] = rect.left;
        _objectsView[i + 4] = rect.top;
        _objectsCount++;

        // Increase the length of the node and all its parents.
        for (QuadTree$Node? n = this; n != null; n = n.parent) n._length++;

        // Store the reference between the id and the current node.
        tree._id2node[id] = this.id;
        return id;
      }

      assert(false, 'Can not insert object into the node, all slots are full.');
      return null; // Should not happen, but just in case.
    }

    // If not subdivided yet, subdivide.
    if (!_subdivided) _subdivide();

    final rectCenterX = rect.left + rect.width / 2.0;
    final rectCenterY = rect.top + rect.height / 2.0;

    if (_southWest!.boundary.top > rectCenterY) {
      if (_northWest!.boundary.right > rectCenterX) {
        return _northWest!._insert(rect); // North-West
      } else {
        return _northEast!._insert(rect); // North-East
      }
    } else {
      if (_southWest!.boundary.right > rectCenterX) {
        return _southWest!._insert(rect); // South-West
      } else {
        return _southEast!._insert(rect); // South-East
      }
    }
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
    );
    final ne = _northEast = tree._createNode(
      parent: this,
      boundary: ui.Rect.fromLTWH(
        left + halfWidth,
        top,
        halfWidth,
        halfHeight,
      ),
    );
    final sw = _southWest = tree._createNode(
      parent: this,
      boundary: ui.Rect.fromLTWH(
        left,
        top + halfHeight,
        halfWidth,
        halfHeight,
      ),
    );
    final se = _southEast = tree._createNode(
      parent: this,
      boundary: ui.Rect.fromLTWH(
        left + halfWidth,
        top + halfHeight,
        halfWidth,
        halfHeight,
      ),
    );

    final nodeSize = capacity * 5;
    for (var i = 0; i < nodeSize; i += 5) {
      final id = _idsView[i]; // id
      if (id == 0) continue; // If slot is empty, skip it.

      // Get object's data from the current objects array.
      final width = _objectsView[i + 1];
      final height = _objectsView[i + 2];
      final left = _objectsView[i + 3];
      final top = _objectsView[i + 4];

      final rectCenterX = left + width / 2.0;
      final rectCenterY = top + height / 2.0;

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

      // Migrate object's data to the new nested node:
      node
        .._idsView[i + 0] = id
        .._objectsView[i + 1] = width
        .._objectsView[i + 2] = height
        .._objectsView[i + 3] = left
        .._objectsView[i + 4] = top;

      // Increase the objects count of the leaf node.
      node._objectsCount++;

      // Increase the length of the node
      // Parent length is still the same,
      // because we are just moving objects to children.
      node._length++;

      // Store the reference between the id and the current leaf node.
      tree._id2node[id] = node.id;
    }
    _idsView.fillRange(0, nodeSize, 0); // Clear ids
    _objectsView.fillRange(0, nodeSize, 0); // Clear objects
    _objectsCount = 0; // Reset objects count, but `length` is still the same.
  }

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

/// Resizes a Uint32List to [newCapacity].
@pragma('vm:prefer-inline')
Uint32List _resizeUint32List(Uint32List array, int newCapacity) =>
    Uint32List(newCapacity)..setAll(0, array);

/// Resizes a Float32List to [newCapacity].
@pragma('vm:prefer-inline')
Float32List _resizeFload32List(Float32List array, int newCapacity) =>
    Float32List(newCapacity)..setAll(0, array);
