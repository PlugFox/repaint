import 'package:flutter/gestures.dart';
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
  void paint(covariant RePaintBox box, PaintingContext context);

  /// Pointer event callback.
  /// Called when a pointer event occurs.
  /// For example, when the user taps the screen.
  /// Events are not propagated to the parent widgets.
  ///
  /// Possible events:
  /// - [PointerDownEvent] - The pointer has made contact with the device.
  /// - [PointerMoveEvent] - The pointer has moved with respect to the device
  ///   while the pointer is in contact with the device.
  /// - [PointerUpEvent] - The pointer has stopped making contact
  ///   with the device.
  /// - [PointerCancelEvent] - The input from the pointer is no longer directed
  ///   towards this receiver.
  /// - [PointerPanZoomStartEvent] - A pan/zoom has begun on this pointer.
  /// - [PointerPanZoomUpdateEvent] - The active pan/zoom on this pointer has updated.
  /// - [PointerPanZoomEndEvent] - The pan/zoom on this pointer has ended.
  /// - [PointerScrollEvent] - The pointer issued a scroll event.
  /// - [PointerSignalEvent] - An event that corresponds to a discrete
  ///   pointer signal.
  /// - [PointerHoverEvent] - The pointer has moved with respect to the device
  ///   while the pointer is not in contact with the device.
  void onPointerEvent(PointerEvent event);

  /// Unmount and dispose the controller.
  /// Called when the controller is detached from the render box.
  void unmount();
}
