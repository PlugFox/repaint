import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'repainter_interface.dart';

/// {@template repaint}
/// A widget that repaints the scene using a custom controller.
/// {@endtemplate}
class RePaint extends LeafRenderObjectWidget {
  /// {@macro repaint}
  const RePaint({
    required this.painter,
    super.key,
  });

  /// The painter controller.
  final IRePainter painter;

  @override
  RePaintElement createElement() => RePaintElement(this);

  @override
  RenderObject createRenderObject(BuildContext context) => RePaintBox(
        painter: painter,
        context: context,
      );

  @override
  void updateRenderObject(BuildContext context, RePaintBox renderObject) {
    renderObject._context = context;
    if (identical(painter, renderObject.painter)) return;
    if (renderObject.attached) painter.unmount();
    renderObject._painter = painter
      ..mount(renderObject.owner!, renderObject)
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
    required IRePainter painter,
    required BuildContext context,
  })  : _painter = painter,
        _context = context;

  /// Current controller.
  IRePainter get painter => _painter;
  IRePainter _painter;

  /// Current build context.
  BuildContext get context => _context;
  BuildContext _context;

  /// Game loop ticker.
  Ticker? _ticker;

  /// Current size of the render box.
  @override
  Size get size => _size;
  Size _size = Size.zero;

  @override
  bool get isRepaintBoundary => true;

  @override
  bool get alwaysNeedsCompositing => false;

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _painter
      ..mount(owner, this)
      ..lifecycle(
          WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed);
    WidgetsBinding.instance.addObserver(this);
    _ticker = Ticker(_onTick)..start();
  }

  @override
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
  void debugResetSize() {
    super.debugResetSize();
    if (!super.hasSize) return;
    _size = super.size;
  }

  /// Total amount of time passed since the game loop was started.
  Duration _previous = Duration.zero;

  /// This method is periodically invoked by the [_ticker].
  void _onTick(Duration elapsed) {
    if (!attached) return;
    final durationDelta = elapsed - _previous;
    final delta = durationDelta.inMicroseconds / Duration.microsecondsPerSecond;
    switch (_painter.frameRate) {
      case null:
        // No frame rate limit.
        break;
      case <= 0:
        // Skip updating and rendering the game scene.
        _previous = elapsed;
        return;
      case int fr when fr > 0 && fr > delta * 1000:
        // Limit frame rate
        return;
    }
    _previous = elapsed;
    // Update game scene and prepare for rendering.
    _painter.update(this, elapsed, delta);
    markNeedsPaint(); // Mark this game scene as dirty and schedule a repaint.
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.save();
    context.canvas.translate(offset.dx, offset.dy);
    _painter.render(this, context.canvas); // Render the scene.
    context.canvas.restore();
  }
}
