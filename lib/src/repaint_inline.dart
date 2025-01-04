import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import '../repaint.dart';

/// Internal widget RePaint for preserving inline state.
@internal
class RePaintInline<T extends Object?> extends StatefulWidget {
  /// Internal widget RePaint for preserving inline state.
  const RePaintInline({
    required this.render,
    this.setUp,
    this.update,
    this.tearDown,
    this.frameRate,
    this.needsPaint = true,
    super.key,
  });

  /// Called when the controller is attached to the render box.
  /// Can be used to set up the initial custom state.
  final T Function(RePaintBox box)? setUp;

  /// Loop tick update.
  /// Called periodically by the loop.
  /// Can be used to update the custom state.
  final T? Function(RePaintBox box, T state, double delta)? update;

  /// Render current scene.
  final void Function(RePaintBox box, T state, Canvas canvas) render;

  /// Unmount and dispose the controller.
  final void Function(T state)? tearDown;

  /// Whether the controller should limit the frame rate.
  /// If `null`, the frame rate is not limited.
  /// 0 - Do not render the scene.
  /// 30 - 30 frames per second.
  /// 60 - 60 frames per second.
  /// 120 - 120 frames per second.
  final int? frameRate;

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
  final bool needsPaint;

  @override
  State<RePaintInline<T>> createState() => _RePaintInlineState<T>();
}

class _RePaintInlineState<T> extends State<RePaintInline<T>> {
  final _InlinePainter<T> painter = _InlinePainter<T>();

  @override
  void initState() {
    super.initState();
    painter.widget = widget;
  }

  @override
  void didUpdateWidget(covariant RePaintInline<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    painter.widget = widget;
  }

  @override
  Widget build(BuildContext context) => RePaint(painter: painter);
}

/// Internal controller for inline state.
final class _InlinePainter<T> extends RePainterBase {
  /// Internal controller for inline state.
  _InlinePainter();

  RePaintInline<T>? widget;

  T? state;

  double _delta = 0;

  @override
  bool get needsPaint => _allowFrame && (widget?.needsPaint ?? true);
  bool _allowFrame = false;

  @override
  void mount(RePaintBox box, PipelineOwner owner) {
    state = widget?.setUp?.call(box);
    _delta = .0;
  }

  @override
  void update(RePaintBox box, Duration elapsed, double delta) {
    _delta += delta;
    switch (widget?.frameRate) {
      case null:
        // No frame rate limit.
        _allowFrame = true;
      case <= 0:
        // Skip updating and rendering the game scene.
        _allowFrame = false;
        return;
      case int fr when fr > 0:
        final targetFrameTime = 1000 / fr;
        if (_delta < targetFrameTime) {
          _allowFrame = false;
          return; // Limit frame rate
        }
        _allowFrame = true;
    }
    final dt = _delta;
    _delta = .0; // Reset delta
    state = widget?.update?.call(box, state as T, dt) ?? state;
  }

  @override
  void paint(RePaintBox box, PaintingContext context) {
    widget?.render(box, state as T, context.canvas);
  }

  @override
  void unmount() {
    _delta = .0;
    widget?.tearDown?.call(state as T);
  }
}
