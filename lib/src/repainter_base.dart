import 'dart:ui';

import 'package:flutter/rendering.dart';

import 'repaint.dart';
import 'repainter_interface.dart';

/// {@template repainter_base}
/// The base class for a custom scene painter.
/// {@endtemplate}
abstract base class RePainterBase implements RePainter {
  /// {@macro repainter_base}
  const RePainterBase();

  @override
  int? get frameRate => null;

  @override
  void lifecycle(AppLifecycleState state) {
    // implement lifecycle
  }

  @override
  void mount(PipelineOwner owner, RePaintBox box) {
    // implement mount
  }

  @override
  void render(RePaintBox box, Canvas canvas) {
    // implement render
  }

  @override
  void update(RePaintBox box, Duration elapsed, double delta) {
    // implement update
  }

  @override
  void unmount() {
    // implement unmount
  }
}
