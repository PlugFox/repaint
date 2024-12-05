import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'repaint_inline.dart';
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

  /// Create a new [RePaint] widget with an inline controller.
  /// The [T] is the custom state type.
  /// The [frameRate] is used to limit the frame rate, (limitter and throttler).
  /// After the [frameRate] is set, the real frame rate will be lower.
  /// The [setUp] is called when the controller is attached to the render box.
  /// The [update] is called periodically by the loop.
  /// The [render] is called to render the scene after the update.
  /// The [tearDown] is called to unmount and dispose the controller.
  /// The [key] is used to identify the widget.
  ///
  /// {@macro repaint}
  static Widget inline<T>({
    required void Function(RePaintBox box, T state, Canvas canvas) render,
    T Function(RePaintBox box)? setUp,
    T? Function(RePaintBox box, T state, double delta)? update,
    void Function(T state)? tearDown,
    int? frameRate,
    Key? key,
  }) =>
      RePaintInline<T>(
        render: render,
        setUp: setUp,
        update: update,
        tearDown: tearDown,
        frameRate: frameRate,
        key: key,
      );

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
  Duration _lastFrameTime = Duration.zero;
  int _frameCount = 0;

  /// This method is periodically invoked by the [_ticker].
  void _onTick(Duration elapsed) {
    if (!attached) return;
    final delta = elapsed - _lastFrameTime;
    final deltaMs = delta.inMicroseconds / Duration.microsecondsPerMillisecond;
    switch (_painter.frameRate) {
      case null:
        // No frame rate limit.
        _lastFrameTime = elapsed;
        break;
      case <= 0:
        // Skip updating and rendering the game scene.
        _lastFrameTime = elapsed;
        return;
      case int fr when fr > 0:
        // Show the next frame if the time has come.
        // Вычисляем интервал между кадрами
        final frameDuration = Duration(milliseconds: (1000 / fr).round());
        if (_lastFrameTime == Duration.zero) {
          _lastFrameTime = elapsed;
          _frameCount = 1;
          break; // Show the first frame.
        }
        // Вычисляем текущую секунду
        final currentSecond = elapsed.inSeconds;
        final lastFrameSecond = _lastFrameTime.inSeconds;

        // Если мы перешли в новую секунду
        if (currentSecond > lastFrameSecond) {
          // Сбрасываем счетчик кадров
          _frameCount = 0;
        }

        // Проверяем, прошло ли достаточно времени с последнего кадра
        final timeSinceLastFrame = elapsed - _lastFrameTime;

        // Вычисляем теоретически допустимое количество кадров в текущей секунде
        final expectedFramesThisSecond = (currentSecond + 1) * fr;

        // Если текущее количество кадров меньше ожидаемого
        // И прошло достаточно времени с последнего кадра
        if (_frameCount < expectedFramesThisSecond / (currentSecond + 1) &&
            timeSinceLastFrame >= frameDuration) {
          _lastFrameTime = elapsed;
          _frameCount++;
          break; // Show the next frame.
        }

        // Limit frame rate
        return;
    }
    // Update game scene and prepare for rendering.
    _painter.update(this, elapsed, deltaMs);
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
