import 'package:test/test.dart';

void main() => group('Util', () {
      group('Time', () {
        test('Seconds', () {
          const duration = Duration(seconds: 5);
          expect(
            duration.inSeconds * Duration.millisecondsPerSecond,
            equals(5 * 1000),
          );
          expect(
            duration.inSeconds *
                Duration.millisecondsPerSecond *
                Duration.microsecondsPerMillisecond,
            equals(5 * 1000 * 1000),
          );
          expect(
            duration.inSeconds * Duration.microsecondsPerSecond,
            equals(5 * 1000 * 1000),
          );
        });

        test('Delta', () {
          const elapsed = Duration(seconds: 15);
          const previous = Duration(seconds: 14);
          final delta = elapsed - previous;
          final ms = delta.inMicroseconds / Duration.microsecondsPerMillisecond;
          expect(ms, equals(1000));
        });

        test('Frame rate', () {
          const frameRate = 60;
          const deltaMs = 1000 / frameRate;
          expect(deltaMs, equals(1000 / 60));
        });
      });
    });
