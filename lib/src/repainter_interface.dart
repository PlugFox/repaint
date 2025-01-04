import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'repaint.dart';

/// The interface for a custom scene painter.
abstract interface class RePainter {
  /// The controller needs to be repainted after the update.
  ///
  /// If `true`, the controller will be repainted.
  /// That means the [paint] method will be called after the [update] method.
  ///
  /// If `false`, the controller will not be repainted.
  /// That means the [paint] method
  /// will not be called after the [update] method.
  ///
  /// This is useful when the controller does not need to be repainted
  /// after the update if the scene is static and does not changed over time.
  ///
  /// You can use this flag to optimize the rendering process.
  /// For example, implement a frame skipper or a frame limiter.
  ///
  /// If you want to skip the [update] method too,
  /// just check it in the [update] method and return immediately.
  bool get needsPaint;

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
