import 'dart:typed_data';
import 'dart:ui' as ui show Rect;

/// {@template quadtree}
/// A Quadtree data structure that subdivides a 2D space into four quadrants
/// to speed up collision detection and spatial queries.
///
/// - insertion [insert]
/// - removal of a single object [remove]
/// - moving objects within the tree [move]
/// - node merging/optimization [optimize]
/// - querying objects within a rectangular region [query]
/// - retrieving all objects in the tree [entries]
/// - visiting all objects in the tree [visit]
/// {@endtemplate}
class QuadTree {
  /// Creates a new Quadtree with [boundary] and a [capacity].
  ///
  /// {@macro quadtree}
  QuadTree({
    required this.boundary,
    this.capacity = 10,
  })  :
        // Nodes
        _nodesCount = 0,
        _recycledNodesCount = 0,
        _nodes = List<QuadTree$Node?>.filled(64, null, growable: false),
        _recycledNodes = Uint32List(64),
        // Objects
        _objectsCount = 0,
        _recycledObjectsCount = 0,
        _objects = Float32List(64 * capacity * 5),
        _recycledObjects = Uint32List(64 * capacity),
        assert(boundary.isFinite, 'The boundary must be finite.'),
        assert(!boundary.isEmpty, 'The boundary must not be empty.'),
        assert(capacity > 0, 'The capacity must be greater than 0.');

  // --------------------------------------------------------------------------
  // PROPERTIES
  // --------------------------------------------------------------------------

  /// Boundary of the QuadTree.
  final ui.Rect boundary;

  /// The maximum number of objects that can be stored in a node before it
  /// subdivides.
  final int capacity;

  // --------------------------------------------------------------------------
  // NODES STORAGE
  // --------------------------------------------------------------------------

  /// Number of active objects in the QuadTree.
  int get nodesCount => _nodesCount - _recycledNodesCount;

  /// The next identifier for a node in the QuadTree
  int _nodesCount;

  /// List of nodes in the QuadTree.
  List<QuadTree$Node?> _nodes;

  /// Recycled objects in this manager.
  int _recycledNodesCount;

  /// Recycled nodes in this manager.
  Uint32List _recycledNodes;

  /// Create a new QuadTree node with [parent] and [boundary].
  QuadTree$Node _createNode({
    required QuadTree$Node? parent,
    required ui.Rect boundary,
  }) {
    // Get next id
    final int id;
    if (_recycledNodesCount > 0) {
      // Reuse recycled node id
      id = _recycledNodes[--_recycledNodesCount];
    } else {
      // Add new node
      if (_nodesCount == _nodes.length) {
        // Resize nodes array
        final newSize = _nodesCount << 1;
        _nodes = List<QuadTree$Node?>.filled(newSize, null, growable: false)
          ..setAll(0, _nodes);
      }
      id = _nodesCount++; // 0..n
    }

    return _nodes[id] = QuadTree$Node._(
      id: id,
      tree: this,
      parent: parent,
      boundary: boundary,
      capacity: capacity,
    );
  }

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
  /// [node, width, height, x, y]
  /// - node: The node the object is in, 0 if it is not existing in the tree.
  /// - width: The width of the object.
  /// - height: The height of the object.
  /// - x: The x-coordinate of the object.
  /// - y: The y-coordinate of the object.
  Float32List _objects;

  /// Recycled objects in this manager.
  int _recycledObjectsCount = 0;

  /// Recycled objects in this manager.
  Uint32List _recycledObjects;

  /// Get the offset of the entity in the objects list based on its id.
  @pragma('vm:prefer-inline')
  int _getEntityOffset(int id) => id * 5;

  /// Insert an object into the QuadTree
  /// with [width], [height], [left] and [top].
  /// Returns the identifier of the object in the QuadTree.
  /// Returns null if the object does not fit in the QuadTree.
  int? insert(ui.Rect rect) {
    assert(rect.isFinite, 'The rectangle must be finite.');

    /// Check if the object fits in the QuadTree.
    if (!_overlaps(boundary, rect)) return null;

    // Get next id
    final int id;
    if (_recycledObjectsCount > 0) {
      // Reuse recycled entity
      id = _recycledObjects[--_recycledObjectsCount];
    } else {
      // Add new entity
      if (_objectsCount * 5 == _objects.length) {
        // Resize entities array
        final newSize = _objectsCount << 1;
        _objects = _resizeFload32List(_objects, newSize * 5);
      }
      id = _objectsCount++; // 0..n
    }

    // Get the root node of the QuadTree
    // or create a new one if it does not exist.
    final root = _root ??= _createNode(
      parent: null,
      boundary: boundary,
    );

    // Find the node to insert the object

    // Fill the object data in the entities array
    final offset = _getEntityOffset(id);
    _objects
      //..[offset + 0] = ? // node
      ..[offset + 1] = rect.width // width
      ..[offset + 2] = rect.height // height
      ..[offset + 3] = rect.left // left (x)
      ..[offset + 4] = rect.top; // top (y)

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
    _objectsCount = 0;
    _recycledObjectsCount = 0;
    _objects = Float32List(64 * capacity * 5);
    _recycledObjects = Uint32List(64 * capacity);
  }
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
  });

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
