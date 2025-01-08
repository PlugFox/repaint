import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:l/l.dart';

/// Catch all application errors and logs.
void appZone(FutureOr<void> Function() fn) => l.capture<void>(
      () => runZonedGuarded<void>(
        () {
          final binding = WidgetsFlutterBinding.ensureInitialized()
            ..deferFirstFrame();
          fn();
          binding.allowFirstFrame();
        },
        l.e,
      ),
      const LogOptions(
        handlePrint: true,
        messageFormatting: _messageFormatting,
        outputInRelease: true,
        printColors: true,
      ),
    );

/// Formats the log message.
Object _messageFormatting(LogMessage log) =>
    '${_timeFormat(log.timestamp)} | ${log.message}';

/// Formats the time.
String _timeFormat(DateTime time) =>
    '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
