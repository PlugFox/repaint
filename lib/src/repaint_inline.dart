import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';

import 'frame_rate.dart';
import 'repaint.dart';
import 'repainter_base.dart';

/// Internal widget RePaint for preserving inline state.
@internal
class RePaintInline<T extends Object?> extends StatefulWidget {
  /// Internal widget RePaint for preserving inline state.
  const RePaintInline({
    required this.render,
    this.setUp,
    this.update,
    this.tearDown,
    this.frameRate = const RePaintFrameRate.zero(),
    this.repaint,
    this.needsPaint = true,
    this.repaintBoundary = false,
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
  /// If `null` or less than 0, the frame rate is unlimited.
  /// 0 - Do not render the scene.
  /// 30 - limited to 30 frames per second.
  /// 60 - limited to 60 frames per second.
  /// 120 - limited to 120 frames per second.
  ///
  /// After the [frameRate] is set, the real frame rate will be lower.
  /// Before the frame rate, updates are limited by the flutter ticker,
  /// so the resulting frame rate will be noticeably lower.
  ///
  /// By default the frame rate is set to 0 and scene is updated only
  /// at [repaint] updates.
  final int? frameRate;

  /// The listenable to repaint the scene.
  /// Can be used to repaint the scene when the listenable changes.
  final Listenable? repaint;

  /// Whether the controller should create a new layer for the scene.
  /// If `true`, the controller will create a new layer for the scene.
  /// If `false`, the controller will not create a new layer for the scene.
  ///
  /// This is useful when the controller needs to be repainted frequently
  /// separately from the other widgets and the scene is complex
  /// and has many layers.
  final bool repaintBoundary;

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

  /// Mark the controller as needing to be repainted.
  void markNeedsPaint() => painter.markNeedsPaint();

  @override
  void initState() {
    super.initState();
    painter.widget = widget;
    widget.repaint?.addListener(markNeedsPaint);
  }

  @override
  void didUpdateWidget(covariant RePaintInline<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    painter.widget = widget;
    if (!identical(widget.repaint, oldWidget.repaint)) {
      oldWidget.repaint?.removeListener(markNeedsPaint);
      widget.repaint?.addListener(markNeedsPaint);
    }
  }

  @override
  void dispose() {
    super.dispose();
    widget.repaint?.removeListener(markNeedsPaint);
  }

  @override
  Widget build(BuildContext context) =>
      RePaint(painter: painter, repaintBoundary: widget.repaintBoundary);
}

/// Internal controller for inline state.
final class _InlinePainter<T> extends RePainterBase {
  /// Internal controller for inline state.
  _InlinePainter();

  RePaintInline<T>? widget;

  T? state;

  double _delta = 0;

  @override
  bool get needsPaint =>
      _needsPaint || _allowFrame && (widget?.needsPaint ?? true);
  bool _allowFrame = false;
  bool _needsPaint = true;

  /// Mark the controller as needing to be repainted.
  void markNeedsPaint() => _needsPaint = true;

  @override
  void mount(RePaintBox box, PipelineOwner owner) {
    state = widget?.setUp?.call(box);
    _delta = .0;
  }

  @override
  void update(RePaintBox box, Duration elapsed, double delta) {
    _delta += delta;
    switch (widget?.frameRate) {
      case 0:
        // Skip updating and rendering the game scene.
        _allowFrame = false;
        return;
      case null:
        // No frame rate limit.
        _allowFrame = true;
      case < 0:
        // No frame rate limit.
        _allowFrame = true;
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
  void unmount() {
    _needsPaint = _allowFrame = false;
    _delta = .0;
    widget?.tearDown?.call(state as T);
  }

  @override
  void paint(RePaintBox box, PaintingContext context) {
    _needsPaint = false;
    widget?.render(box, state as T, context.canvas);
  }
}
