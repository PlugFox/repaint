import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'frame_rate.dart';
import 'repaint_inline.dart';
import 'repainter_interface.dart';

/// {@template repaint}
/// A widget that repaints the scene using a custom controller.
/// {@endtemplate}
class RePaint extends LeafRenderObjectWidget {
  /// {@macro repaint}
  const RePaint({
    required this.painter,
    this.repaintBoundary = true,
    super.key,
  });

  /// Create a new [RePaint] widget with an inline controller.
  /// The [T] is the custom state type.
  /// The [frameRate] is used to limit the frame rate, (limitter and throttler).
  /// The [repaint] is used to repaint the scene when the listenable changes.
  /// The [setUp] is called when the controller is attached to the render box.
  /// The [update] is called periodically by the loop.
  /// The [render] is called to render the scene after the update.
  /// The [tearDown] is called to unmount and dispose the controller.
  /// The [repaintBoundary] is used to create a new layer for the scene.
  /// The [key] is used to identify the widget.
  ///
  /// After the [frameRate] is set, the real frame rate will be lower.
  /// Before the frame rate, updates are limited by the flutter ticker,
  /// so the resulting frame rate will be noticeably lower.
  ///
  /// By default the frame rate is set to 0 and scene is updated only
  /// at [repaint] updates.
  ///
  /// By default, the [repaintBoundary] is set to false for [inline] widgets.
  /// {@macro repaint}
  static Widget inline<T>({
    required void Function(RePaintBox box, T state, Canvas canvas) render,
    T Function(RePaintBox box)? setUp,
    T? Function(RePaintBox box, T state, double delta)? update,
    void Function(T state)? tearDown,
    int? frameRate = const RePaintFrameRate.zero(),
    Listenable? repaint,
    bool repaintBoundary = false,
    Key? key,
  }) =>
      RePaintInline<T>(
        render: render,
        setUp: setUp,
        update: update,
        tearDown: tearDown,
        frameRate: frameRate,
        repaint: repaint,
        repaintBoundary: repaintBoundary,
        key: key,
      );

  /// The painter controller, used to update and paint the scene.
  /// For example, a game controller or a custom painter.
  final RePainter painter;

  /// Whether the controller should create a new layer for the scene.
  /// If `true`, the controller will create a new layer for the scene.
  /// If `false`, the controller will not create a new layer for the scene.
  ///
  /// This is useful when the controller needs to be repainted frequently
  /// separately from the other widgets and the scene is complex
  /// and has many layers.
  final bool repaintBoundary;

  @override
  RePaintElement createElement() => RePaintElement(this);

  @override
  RenderObject createRenderObject(BuildContext context) => RePaintBox(
        painter: painter,
        context: context,
        isRepaintBoundary: repaintBoundary,
      );

  @override
  void updateRenderObject(BuildContext context, RePaintBox renderObject) {
    renderObject
      .._context = context
      ..isRepaintBoundary = repaintBoundary;
    if (identical(painter, renderObject.painter)) return;
    if (renderObject.attached) painter.unmount();
    assert(renderObject.owner != null, 'RenderObject is not attached.');
    renderObject._painter = painter
      ..mount(renderObject, renderObject.owner!)
      ..lifecycle(
          WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed);
  }
}

/// {@template repaint_element}
/// Element for [RePaint].
/// {@endtemplate}
class RePaintElement extends LeafRenderObjectElement {
  /// {@macro repaint_element}
  RePaintElement(RePaint super.widget);

  /* @override
  RePaintRenderBox get renderObject => super.renderObject as RePaintRenderBox;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot); // Creates the renderObject.
  }

  @override
  void update(covariant RePaint newWidget) {
    super.update(newWidget);
  }

  @override
  void performRebuild() {
    super.performRebuild();
  }

  @override
  void unmount() {
    super.unmount();
  } */
}

/// {@template repaint_render_box}
/// A render object that repaints the scene using a custom controller.
/// {@endtemplate}
class RePaintBox extends RenderBox with WidgetsBindingObserver {
  /// {@macro repaint_render_box}
  RePaintBox({
    required RePainter painter,
    required BuildContext context,
    required bool isRepaintBoundary,
  })  : _painter = painter,
        _context = context,
        _$isRepaintBoundary = isRepaintBoundary;

  /// Current controller.
  RePainter get painter => _painter;
  RePainter _painter;

  /// Current build context.
  BuildContext get context => _context;
  BuildContext _context;

  /// Game loop ticker.
  Ticker? _ticker;

  /// Current size of the render box.
  @override
  Size get size => _size;
  Size _size = Size.zero;

  bool _$isRepaintBoundary;

  // Change the repaint boundary flag.
  set isRepaintBoundary(bool value) {
    if (_$isRepaintBoundary == value) return;
    _$isRepaintBoundary = value;
    markNeedsCompositingBitsUpdate();
  }

  @override
  bool get isRepaintBoundary => _$isRepaintBoundary;

  @override
  bool get alwaysNeedsCompositing => false;

  @override
  bool get sizedByParent => true;

  @override
  @protected
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  @protected
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _painter
      ..mount(this, owner)
      ..lifecycle(
          WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed);
    WidgetsBinding.instance.addObserver(this);
    _ticker = Ticker(_onTick, debugLabel: 'RePaintBox')..start();
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  bool hitTestChildren(
    BoxHitTestResult result, {
    required Offset position,
  }) =>
      false;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    var hitTarget = false;
    if (size.contains(position)) {
      hitTarget = hitTestSelf(position);
      result.add(BoxHitTestEntry(this, position));
    }
    return hitTarget;
  }

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    painter.onPointerEvent(event);
  }

  @override
  @protected
  void detach() {
    super.detach();
    _ticker?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _painter.unmount();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _painter.lifecycle(state);
  }

  @override
  set size(Size value) {
    final prev = super.hasSize ? super.size : null;
    super.size = value;
    if (prev == value) return;
    _size = value;
  }

  @override
  @protected
  void debugResetSize() {
    super.debugResetSize();
    if (!super.hasSize) return;
    _size = super.size;
  }

  /// Total amount of time passed since the game loop was started.
  Duration _lastFrameTime = Duration.zero;

  /// This method is periodically invoked by the [_ticker].
  void _onTick(Duration elapsed) {
    if (!attached) return;
    final delta = elapsed - _lastFrameTime;
    final deltaMs = delta.inMicroseconds / Duration.microsecondsPerMillisecond;
    _lastFrameTime = elapsed;
    // Update game scene and prepare for rendering.
    _painter.update(this, elapsed, deltaMs);
    // Mark this game scene as dirty and schedule a repaint.
    if (_painter.needsPaint) markNeedsPaint();
  }

  @override
  @protected
  void paint(PaintingContext context, Offset offset) {
    context.canvas
      ..save()
      ..translate(offset.dx, offset.dy);
    _painter.paint(this, context); // Paint scene using the custom controller.
    context.canvas.restore();
  }
}
