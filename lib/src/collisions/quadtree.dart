import 'dart:typed_data';
import 'dart:ui' as ui show Rect;

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
    assert(capacity > 0, 'The capacity must be greater than 0.');
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
  List<QuadTree$Node?> _nodes;

  /// Recycled objects in this manager.
  int _recycledNodesCount;

  /// Recycled nodes in this manager.
  Uint32List _recycledNodes;

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

    // TODO(plugfox): Increase the number of objects in the tree
    // Mike Matiunin <plugfox@gmail.com>, 07 January 2025

    return id;
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
    _objects = Float32List(64 * _nodeSize);
    _idsView = Uint32List.sublistView(_objects);

    // Clear ids
    _nextId = 1;
    _recycledIdsCount = 0;
    _id2node = Uint32List(64);
    _recycledIds = Uint32List(64);
  }

  /*
  // --------------------------------------------------------------------------
  // OBJECTS STORAGE
  // --------------------------------------------------------------------------

  /// The root node of the QuadTree.
  QuadTree$Node? _root;

  /// Number of active objects in the QuadTree.
  int get objectsCount => _objectsCount - _recycledObjectsCount;

  /// The next identifier for an object in the QuadTree
  /// and total number of entities in this manager.
  int _objectsCount;

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
  ///
  /// Also this array is splitted by chunks for each node with
  /// [capacity] objects per node.
  /// For example with capacity 10
  /// the second object in the third node will be at index:
  /// (3 - 1) * capacity * 5 + (2 - 1) * 5 = 84
  Float32List _objects;

  /// Recycled objects in this manager.
  int _recycledObjectsCount = 0;

  /// Recycled objects in this manager.
  Uint32List _recycledObjects;

  /// Get the offset of the entity in the objects list based on its id.
  @pragma('vm:prefer-inline')
  int _getEntityOffset(int node, int object) =>
      node * capacity * 4 + object * 4;

  /// Insert an object into the QuadTree
  /// with [width], [height], [left] and [top].
  /// Returns the identifier of the object in the QuadTree.
  /// Returns null if the object does not fit in the QuadTree.
  int? insert(ui.Rect rect) {
    assert(rect.isFinite, 'The rectangle must be finite.');

    /// Check if the object fits in the QuadTree.
    if (!_overlaps(boundary, rect)) return null;

    // Get the root node of the QuadTree
    // or create a new one if it does not exist.
    final root = _root ??= _createNode(
      parent: null,
      boundary: boundary,
    );

    // Find the node to insert the object

    // Get next id

    // TODO(plugfox): Replace it
    // Mike Matiunin <plugfox@gmail.com>, 07 January 2025
    final int id;
    if (_recycledObjectsCount > 0) {
      // Reuse recycled entity
      id = _recycledObjects[--_recycledObjectsCount];
    } else {
      // Add new entity
      if (_objectsCount * 4 == _objects.length) {
        // Resize entities array
        final newSize = _objectsCount << 1;
        _objects = _resizeFload32List(_objects, newSize * 4);
      }
      id = _objectsCount++; // 0..n
    }

    // Fill the object data in the entities array
    /* final offset = _getEntityOffset(id);
    _objects
      //..[offset + 0] = ? // node
      ..[offset + 1] = rect.width // width
      ..[offset + 2] = rect.height // height
      ..[offset + 3] = rect.left // left (x)
      ..[offset + 4] = rect.top; // top (y) */

    return id;
  }
 */
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
        _objectsCount = 0,
        _subdivided = false;

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

  /// Number of objects directly stored in this node.
  int _objectsCount;

  /// Whether this node has been subdivided.
  bool get subdivided => _subdivided;
  bool _subdivided;

  /// Child nodes (quadrants).
  QuadTree$Node? _northWest;
  QuadTree$Node? _northEast;
  QuadTree$Node? _southWest;
  QuadTree$Node? _southEast;

  /// Try to insert an object into this node.
  int? _insert(ui.Rect rect) {
    // Check if the object fits in the QuadTree.
    if (!_overlaps(boundary, rect)) return null;

    // Should we insert the object directly into this node?
    if (_objectsCount < capacity && !_subdivided) {
      // Get next id
      final id = tree._getNextId();

      // Insert to free slot
      final length = _idsView.length;
      for (var i = 0; i < length; i += 5) {
        final byte = _idsView[i]; // id
        if (byte != 0) continue; // Skip used slots

        // Fill the object data in the entities array
        _idsView[i + 0] = id;
        _objectsView[i + 1] = rect.width;
        _objectsView[i + 2] = rect.height;
        _objectsView[i + 3] = rect.left;
        _objectsView[i + 4] = rect.top;
        _objectsCount++;

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
      if (_northWest!.boundary.left < rectCenterX) {
        return _northWest!._insert(rect); // North-West
      } else {
        return _northEast!._insert(rect); // North-East
      }
    } else {
      if (_southWest!.boundary.left < rectCenterX) {
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
    _northWest = tree._createNode(
      parent: this,
      boundary: ui.Rect.fromLTWH(
        left,
        top,
        halfWidth,
        halfHeight,
      ),
    );
    _northEast = tree._createNode(
      parent: this,
      boundary: ui.Rect.fromLTWH(
        left + halfWidth,
        top,
        halfWidth,
        halfHeight,
      ),
    );
    _southWest = tree._createNode(
      parent: this,
      boundary: ui.Rect.fromLTWH(
        left,
        top + halfHeight,
        halfWidth,
        halfHeight,
      ),
    );
    _southEast = tree._createNode(
      parent: this,
      boundary: ui.Rect.fromLTWH(
        left + halfWidth,
        top + halfHeight,
        halfWidth,
        halfHeight,
      ),
    );

    // TODO(plugfox): Fill nodes with parent objects
    // Clear current node
    // Mike Matiunin <plugfox@gmail.com>, 07 January 2025
  }
}

// --------------------------------------------------------------------------
// UTILS
// --------------------------------------------------------------------------

/* @pragma('vm:prefer-inline')
bool _overlapsBoundary({
  required ui.Rect boundary,
  required double width,
  required double height,
  required double left,
  required double top,
}) =>
    left < boundary.right &&
    left + width > boundary.left &&
    top < boundary.bottom &&
    top + height > boundary.top; */

/// Checks if rectangles [a] and [b] overlap by coordinate checks.
@pragma('vm:prefer-inline')
bool _overlaps(ui.Rect a, ui.Rect b) =>
    a.left < b.right && // this.x < other.right
    a.right > b.left && // this.right > other.x
    a.top < b.bottom && // this.y < other.bottom
    a.bottom > b.top; // this.bottom > other.y

/// Resizes a Uint32List to [newCapacity].
@pragma('vm:prefer-inline')
Uint32List _resizeUint32List(Uint32List array, int newCapacity) =>
    Uint32List(newCapacity)..setAll(0, array);

/// Resizes a Float32List to [newCapacity].
@pragma('vm:prefer-inline')
Float32List _resizeFload32List(Float32List array, int newCapacity) =>
    Float32List(newCapacity)..setAll(0, array);
