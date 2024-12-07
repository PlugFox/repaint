import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'repaint.dart';

/// The interface for a custom scene painter.
abstract interface class RePainter {
  /// The [frameRate] is used to limit the frame rate, (limitter and throttler).
  ///
  /// If `null`, the frame rate is not limited.
  /// 0 - Do not render the scene.
  /// 30 - 30 frames per second.
  /// 60 - 60 frames per second.
  /// 120 - 120 frames per second.
  ///
  /// After the [frameRate] is set, the real frame rate will be lower.
  /// Before the frame rate, updates are limited by the flutter ticker,
  /// so the resulting frame rate will be noticeably lower.
  /// Because calling the [update] does not immediately cause a redraw,
  /// but only marks the render object as needing a redraw with
  /// [RenderObject.markNeedsPaint],
  /// thats why the frame rate is lower than expected.
  int? get frameRate;

  /// Mount the controller.
  /// Called when the controller is attached to the render box.
  @protected
  void mount(covariant RePaintBox box, PipelineOwner owner);

  /// Lifecycle state change callback.
  /// Called when the app lifecycle state changes.
  void lifecycle(AppLifecycleState state);

  /// Loop tick update.
  /// Called periodically by the loop.
  void update(covariant RePaintBox box, Duration elapsed, double delta);

  /// Paint the scene.
  ///
  /// Paint the updated objects after the [update] method.
  ///
  /// [box] - the current render box of the widget.
  /// [context] - the painting context during the paint phase.
  ///
  /// Hints:
  /// - Use the [box.size] to get the render box size.
  /// - Use the [box.context] to get the build context.
  /// - Use the [context.canvas] to draw the scene.
  @protected
  void paint(covariant RePaintBox box, PaintingContext context);

  /// Unmount and dispose the controller.
  /// Called when the controller is detached from the render box.
  @protected
  void unmount();
}
