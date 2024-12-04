import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'repaint.dart';

/// The interface for a custom scene painter.
abstract interface class IRePainter {
  /// Whether the controller should limit the frame rate.
  /// If `null`, the frame rate is not limited.
  /// 0 - Do not render the scene.
  /// 30 - 30 frames per second.
  /// 60 - 60 frames per second.
  /// 120 - 120 frames per second.
  int? get frameRate;

  /// Mount the controller.
  /// Called when the controller is attached to the render box.
  void mount(PipelineOwner owner, RePaintBox box);

  /// Lifecycle state change callback.
  /// Called when the app lifecycle state changes.
  void lifecycle(AppLifecycleState state);

  /// Loop tick update.
  /// Called periodically by the loop.
  void update(RePaintBox box, Duration elapsed, double delta);

  /// Render current scene.
  /// Render the updated objects after the [update] method.
  void render(RePaintBox box, Canvas canvas);

  /// Unmount and dispose the controller.
  /// Called when the controller is detached from the render box.
  void unmount();
}
