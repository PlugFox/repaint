import 'dart:ui';

import 'package:flutter/rendering.dart';

import 'repaint.dart';
import 'repainter_interface.dart';

/// {@template repainter_base}
/// The base class for a custom scene painter.
/// {@endtemplate}
abstract /* base */ class RePainterBase implements RePainter {
  /// {@macro repainter_base}
  const RePainterBase();

  @override
  bool get needsPaint => true;

  @override
  void lifecycle(AppLifecycleState state) {
    // implement lifecycle
  }

  @override
  void mount(RePaintBox box, PipelineOwner owner) {
    // implement mount
  }

  @override
  void update(RePaintBox box, Duration elapsed, double delta) {
    // implement update
  }

  @override
  void onPointerEvent(PointerEvent event) {
    // implement onPointerEvent
  }

  @override
  void unmount() {
    // implement unmount
  }
}
