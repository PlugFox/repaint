# RePaint

[![Pub](https://img.shields.io/pub/v/repaint.svg)](https://pub.dev/packages/repaint)
[![Actions Status](https://github.com/PlugFox/repaint/actions/workflows/checkout.yml/badge.svg)](https://github.com/PlugFox/repaint/actions)
[![Coverage](https://codecov.io/gh/PlugFox/repaint/branch/master/graph/badge.svg)](https://codecov.io/gh/PlugFox/repaint)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg)](https://opensource.org/licenses/MIT)
[![Linter](https://img.shields.io/badge/style-linter-40c4ff.svg)](https://pub.dev/packages/linter)
[![GitHub stars](https://img.shields.io/github/stars/plugfox/repaint?style=social)](https://github.com/plugfox/repaint/)

Library for creating and managing a canvas similar to CustomPaint but with more features.

## How to

### Handle mouse events

```dart
@override
@mustCallSuper
void onPointerEvent(PointerEvent event) {
  case (event) {
    case PointerDownEvent e:
    case PointerUpEvent e:
    case PointerCancelEvent e:
    case PointerPanZoomStartEvent e:
    case PointerPanZoomUpdateEvent e:
    case PointerPanZoomEndEvent e:
    case PointerScrollEvent e:
    case PointerSignalEvent e:
    case PointerHoverEvent e:
      break;
    case PointerMoveEvent e:
      // Move the [_rect] by the [_offset] on mouse drag
      final rect = _rect.shift(_offset);
      if (!rect.contains(e.localPosition)) return;
      _offset += move.delta;
  }
}
```

### Handle keyboard events

To handle keyboard events you can use [HardwareKeyboard](https://api.flutter.dev/flutter/services/HardwareKeyboard-class.html) manager:

```dart
bool _onKeyEvent(KeyEvent event) {
  if (event.deviceType != KeyEventDeviceType.keyboard) return false;
  if (event is! KeyDownEvent) return false;
  // F1 - do something
  switch (event.logicalKey) {
    case LogicalKeyboardKey.f1:
      doSomething();
      return true;
    default:
      return false;
  }
}

@override
void mount(_, __) {
  HardwareKeyboard.instance.addHandler(_onKeyEvent);
}

@override
void unmount() {
  HardwareKeyboard.instance.removeHandler(_onKeyEvent);
}
```

or wrap RePaint with [Focus](https://api.flutter.dev/flutter/widgets/Focus-class.html) widget and use [onKeyEvent](https://api.flutter.dev/flutter/widgets/Focus/onKeyEvent.html) to handle keyboard events:

```dart
final painter = RePainterImpl();

Widget build(BuildContext context) {
  return Focus(
    onKeyEvent: painter.onKeyEvent,
    child: RePaint(
      painter: painter,
    ),
  );
}
```
