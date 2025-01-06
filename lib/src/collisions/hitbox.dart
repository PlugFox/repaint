// ignore_for_file: avoid_equals_and_hash_code_on_mutable_classes

import 'package:meta/meta.dart';

/// {@template hitbox}
/// The hitbox will be a rectangle with the top-left corner at the specified
/// coordinates and the specified dimensions.
///
/// The [x] and [y] coordinates represent the top-left corner of the hitbox.
///
/// The [width] and [height] represent the dimensions of the hitbox.
/// {@endtemplate}
abstract interface class HitBox {
  /// Creates a hitbox with the specified coordinates and dimensions.
  /// A hitbox with a rectangular shape and the top-left corner at the specified
  /// coordinates.
  ///
  /// {@macro hitbox}
  factory HitBox.rect({
    required double width,
    required double height,
    double x,
    double y,
  }) = _HitBox$Rect;

  factory HitBox.square({
    required double size,
    double x,
    double y,
  }) = _HitBox$Rect.square;

  /// The width of the hitbox.
  abstract final double width;

  /// The height of the hitbox.
  abstract final double height;

  /// The x-coordinate of the hitbox.
  double get x;

  /// The y-coordinate of the hitbox.
  double get y;

  /// The x-coordinate of the left edge of the hitbox.
  double get left;

  /// The y-coordinate of the top edge of the hitbox.
  double get top;

  /// The x-coordinate of the right edge of the hitbox.
  double get right;

  /// The y-coordinate of the bottom edge of the hitbox.
  double get bottom;

  /// Moves the hitbox to the specified coordinates.
  void move(double x, double y);

  /// Returns true if this hitbox overlaps another [HitBox].
  bool overlaps(HitBox other);

  /// Returns true if this hitbox overlaps the rectangular area
  /// defined by [left],[top],[right],[bottom].
  bool overlapsRect({
    required double left,
    required double top,
    required double right,
    required double bottom,
  });
}

/// A hitbox with a rectangular shape.
class _HitBox$Rect implements HitBox {
  /// Rectangular hitbox with the specified dimensions.
  _HitBox$Rect({
    required this.width,
    required this.height,
    this.x = .0,
    this.y = .0,
  });

  /// Square hitbox with the specified size.
  _HitBox$Rect.square({
    required double size,
    this.x = .0,
    this.y = .0,
  })  : width = size,
        height = size;

  @override
  final double height;

  @override
  final double width;

  @override
  double x;

  @override
  double y;

  @override
  double get left => x;

  @override
  double get top => y;

  @override
  double get right => x + width;

  @override
  double get bottom => y + height;

  @override
  @mustCallSuper
  void move(double x, double y) {
    this.x = x;
    this.y = y;
  }

  /// Basic rectangle-overlap check without creating Rect objects.
  @override
  bool overlaps(HitBox other) =>
      x < other.x + other.width && // this.x < other.right
      x + width > other.x && // this.right > other.x
      y < other.y + other.height && // this.y < other.bottom
      y + height > other.y; // this.bottom > other.y

  /// Check overlap with a rectangular region.
  @override
  bool overlapsRect({
    required double left,
    required double top,
    required double right,
    required double bottom,
  }) =>
      x < right && // this.x < other.right
      x + width > left && // this.right > other.x
      y < bottom && // this.y < other.bottom
      y + height > top;

  @override
  int get hashCode => Object.hash(width, height, x, y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _HitBox$Rect &&
          width == other.width &&
          height == other.height &&
          x == other.x &&
          y == other.y;

  @override
  String toString() => width == height
      ? 'HitBox.square{size: $width, x: $x, y: $y}'
      : 'HitBox.rect{width: $width, height: $height, x: $x, y: $y}';
}
