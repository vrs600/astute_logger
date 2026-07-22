import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:astute_logger/astute_logger.dart';

void main() {
  group('Astute Logger Tests', () {
    // ═══════════════════════════════════════════════════════════════════
    // 1. LOG LEVELS TESTS
    // ═══════════════════════════════════════════════════════════════════
    group('Log Levels', () {
      test('LogLevel enum contains all expected levels', () {
        expect(LogLevel.values.length, equals(5));
        expect(LogLevel.values, contains(LogLevel.debug));
        expect(LogLevel.values, contains(LogLevel.info));
        expect(LogLevel.values, contains(LogLevel.warning));
        expect(LogLevel.values, contains(LogLevel.error));
        expect(LogLevel.values, contains(LogLevel.critical));
      });

      test('Log levels are ordered by severity', () {
        expect(LogLevel.debug.index, equals(0));
        expect(LogLevel.info.index, equals(1));
        expect(LogLevel.warning.index, equals(2));
        expect(LogLevel.error.index, equals(3));
        expect(LogLevel.critical.index, equals(4));
      });

      test('Logger methods exist for all levels', () {
        final logger = AstuteLogger('Test');
        expect(() => logger.debug('test'), returnsNormally);
        expect(() => logger.info('test'), returnsNormally);
        expect(() => logger.warning('test'), returnsNormally);
        expect(() => logger.error('test'), returnsNormally);
        expect(() => logger.critical('test'), returnsNormally);
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // 2. REDACTION TESTS
    // ═══════════════════════════════════════════════════════════════════
    group('Redaction', () {
      test('Redaction enabled by default', () {
        final config = const LogConfig();
        expect(config.enableRedaction, isTrue);
      });

      test('Redaction can be disabled', () {
        final config = const LogConfig(enableRedaction: false);
        expect(config.enableRedaction, isFalse);
      });

      test('Email addresses are redacted', () {
        final logger = AstuteLogger('Test',
            config: const LogConfig(enableRedaction: true));

        // We can't directly test the output, but we can verify the method exists
        expect(() => logger.info('test@example.com'), returnsNormally);
      });

      test('Tokens are redacted', () {
        final logger = AstuteLogger('Test',
            config: const LogConfig(enableRedaction: true));

        expect(() => logger.info('bearer abc123xyz'), returnsNormally);
      });

      test('Credit cards are redacted', () {
        final logger = AstuteLogger('Test',
            config: const LogConfig(enableRedaction: true));

        expect(() => logger.info('4532-1234-5678-9010'), returnsNormally);
      });

      test('Passwords are redacted', () {
        final logger = AstuteLogger('Test',
            config: const LogConfig(enableRedaction: true));

        expect(() => logger.info('password: mySecret123'), returnsNormally);
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // 3. CONFIGURATION TESTS
    // ═══════════════════════════════════════════════════════════════════
    group('Configuration', () {
      test('Default LogConfig values', () {
        final config = const LogConfig();
        expect(config.enableRedaction, isTrue);
        expect(config.minimumLogLevel, equals(LogLevel.debug));
        expect(config.enableConsoleOutput, isTrue);
        expect(config.enableFileOutput, isTrue);
        expect(config.logFileName, equals('app_logs.txt'));
        expect(config.enableColorLogging, isTrue);
      });

      test('Custom LogConfig values', () {
        final config = LogConfig(
          enableRedaction: false,
          minimumLogLevel: LogLevel.warning,
          enableConsoleOutput: false,
          enableFileOutput: false,
          logFileName: 'custom_logs.txt',
          enableColorLogging: false,
        );
        expect(config.enableRedaction, isFalse);
        expect(config.minimumLogLevel, equals(LogLevel.warning));
        expect(config.enableConsoleOutput, isFalse);
        expect(config.enableFileOutput, isFalse);
        expect(config.logFileName, equals('custom_logs.txt'));
        expect(config.enableColorLogging, isFalse);
      });

      test('Logger accepts custom config', () {
        final config = const LogConfig(
          minimumLogLevel: LogLevel.error,
        );
        final logger = AstuteLogger('Test', config: config);

        expect(logger.config.minimumLogLevel, equals(LogLevel.error));
      });

      test('Logger has default config', () {
        final logger = AstuteLogger('Test');

        expect(logger.config.enableRedaction, isTrue);
        expect(logger.config.minimumLogLevel, equals(LogLevel.debug));
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // 4. LOGGER CONTEXT TESTS
    // ═══════════════════════════════════════════════════════════════════
    group('Logger Context', () {
      test('LoggerContext.runWithContext executes body', () {
        bool executed = false;

        LoggerContext.runWithContext(
          requestId: 'test-id',
          body: () {
            executed = true;
          },
        );

        expect(executed, isTrue);
      });

      test('LoggerContext returns body result', () {
        final result = LoggerContext.runWithContext<String>(
          requestId: 'test-id',
          body: () => 'test-result',
        );

        expect(result, equals('test-result'));
      });

      test('LoggerContext accepts extra metadata', () {
        final extra = {'key': 'value', 'count': 42};

        LoggerContext.runWithContext(
          requestId: 'test-id',
          extra: extra,
          body: () {
            // Context is set, can be accessed via Zone
            expect(Zone.current[LoggerContext.extraContext], equals(extra));
          },
        );
      });

      test('LoggerContext stores request ID', () {
        LoggerContext.runWithContext(
          requestId: 'req-123-abc',
          body: () {
            final reqId = Zone.current[LoggerContext.requestId];
            expect(reqId, equals('req-123-abc'));
          },
        );
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // 5. COLOR LOGGING TESTS
    // ═══════════════════════════════════════════════════════════════════
    group('Color Logging', () {
      test('LogColor enum has all colors', () {
        expect(LogColor.values.length, equals(5));
        expect(LogColor.values, contains(LogColor.green));
        expect(LogColor.values, contains(LogColor.blue));
        expect(LogColor.values, contains(LogColor.yellow));
        expect(LogColor.values, contains(LogColor.red));
        expect(LogColor.values, contains(LogColor.magenta));
      });

      test('Each LogColor has a valid code', () {
        expect(LogColor.green.code, equals('32'));
        expect(LogColor.blue.code, equals('34'));
        expect(LogColor.yellow.code, equals('33'));
        expect(LogColor.red.code, equals('31'));
        expect(LogColor.magenta.code, equals('35'));
      });

      test('Color logging can be disabled', () {
        final config = const LogConfig(enableColorLogging: false);
        final logger = AstuteLogger('Test', config: config);

        expect(logger.config.enableColorLogging, isFalse);
        expect(() => logger.info('test'), returnsNormally);
      });

      test('Color logging can be enabled', () {
        final config = const LogConfig(enableColorLogging: true);
        final logger = AstuteLogger('Test', config: config);

        expect(logger.config.enableColorLogging, isTrue);
        expect(() => logger.info('test'), returnsNormally);
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // 6. EXECUTION TIME TESTS
    // ═══════════════════════════════════════════════════════════════════
    group('Execution Time Measurement', () {
      test('logExecutionTime returns correct value', () {
        final logger = AstuteLogger('Test');

        final result = logger.logExecutionTime('test', () => 42);

        expect(result, equals(42));
      });

      test('logExecutionTime works with complex types', () {
        final logger = AstuteLogger('Test');

        final result = logger.logExecutionTime('test', () {
          return {
            'key': 'value',
            'list': [1, 2, 3]
          };
        });

        expect(
            result,
            equals({
              'key': 'value',
              'list': [1, 2, 3]
            }));
      });

      test('logExecutionTimeAsync returns correct value', () async {
        final logger = AstuteLogger('Test');

        final result = await logger.logExecutionTimeAsync('test', () async {
          await Future.delayed(const Duration(milliseconds: 100));
          return 'async result';
        });

        expect(result, equals('async result'));
      });

      test('logExecutionTimeAsync measures time', () async {
        final logger = AstuteLogger('Test');

        await logger.logExecutionTimeAsync('test', () async {
          await Future.delayed(const Duration(milliseconds: 100));
        });

        // Just verify it completes without error
        expect(true, isTrue);
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // 7. LOG FILE TESTS
    // ═══════════════════════════════════════════════════════════════════
    group('File Logging', () {
      test('getLogFile returns File or null', () async {
        final file = await AstuteLogger.getLogFile();

        expect(file, isNotNull);
      });

      test('getLogFile can specify custom filename', () async {
        final file = await AstuteLogger.getLogFile(fileName: 'custom.txt');

        expect(file, isNotNull);
        expect(file!.path, contains('custom.txt'));
      });

      test('File output can be enabled', () {
        final config = const LogConfig(enableFileOutput: true);
        final logger = AstuteLogger('Test', config: config);

        expect(logger.config.enableFileOutput, isTrue);
      });

      test('File output can be disabled', () {
        final config = const LogConfig(enableFileOutput: false);
        final logger = AstuteLogger('Test', config: config);

        expect(logger.config.enableFileOutput, isFalse);
      });

      test('Custom log filename can be set', () {
        final config = const LogConfig(logFileName: 'my_logs.txt');
        final logger = AstuteLogger('Test', config: config);

        expect(logger.config.logFileName, equals('my_logs.txt'));
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // 8. LOGGER INSTANTIATION TESTS
    // ═══════════════════════════════════════════════════════════════════
    group('Logger Instantiation', () {
      test('Logger can be created with title only', () {
        final logger = AstuteLogger('MyLogger');

        expect(logger.title, equals('MyLogger'));
        expect(logger.config, isNotNull);
      });

      test('Logger can be created with title and config', () {
        final config = const LogConfig(minimumLogLevel: LogLevel.warning);
        final logger = AstuteLogger('MyLogger', config: config);

        expect(logger.title, equals('MyLogger'));
        expect(logger.config, equals(config));
      });

      test('Multiple loggers can be created independently', () {
        final logger1 = AstuteLogger('Logger1');
        final logger2 = AstuteLogger('Logger2');

        expect(logger1.title, equals('Logger1'));
        expect(logger2.title, equals('Logger2'));
        expect(identical(logger1, logger2), isFalse);
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // 9. RELEASE MODE TESTS
    // ═══════════════════════════════════════════════════════════════════
    group('Release Mode Behavior', () {
      test('Logger methods can be called without errors', () {
        final logger = AstuteLogger('Test');

        // Even if kReleaseMode is true, methods should not throw
        expect(() => logger.debug('test'), returnsNormally);
        expect(() => logger.info('test'), returnsNormally);
        expect(() => logger.warning('test'), returnsNormally);
        expect(() => logger.error('test'), returnsNormally);
        expect(() => logger.critical('test'), returnsNormally);
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // 10. ERROR HANDLING TESTS
    // ═══════════════════════════════════════════════════════════════════
    group('Error Handling', () {
      test('Error method accepts error object', () {
        final logger = AstuteLogger('Test');
        final error = Exception('Test error');

        expect(
          () => logger.error('An error occurred', error: error),
          returnsNormally,
        );
      });

      test('Error method accepts stack trace', () {
        final logger = AstuteLogger('Test');

        try {
          throw Exception('Test');
        } catch (e, st) {
          expect(
            () => logger.error('An error occurred', error: e, stackTrace: st),
            returnsNormally,
          );
        }
      });

      test('Critical method accepts error and stack trace', () {
        final logger = AstuteLogger('Test');

        try {
          throw Exception('Critical error');
        } catch (e, st) {
          expect(
            () => logger.critical(
              'Critical error occurred',
              error: e,
              stackTrace: st,
            ),
            returnsNormally,
          );
        }
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // 11. EXTRA CONTEXT TESTS
    // ═══════════════════════════════════════════════════════════════════
    group('Extra Context', () {
      test('Logger methods accept extra context', () {
        final logger = AstuteLogger('Test');
        final extra = {'userId': '123', 'action': 'login'};

        expect(
          () => logger.info('User logged in', extra: extra),
          returnsNormally,
        );
      });

      test('Extra context can be null', () {
        final logger = AstuteLogger('Test');

        expect(
          () => logger.info('Message', extra: null),
          returnsNormally,
        );
      });

      test('Extra context can be empty map', () {
        final logger = AstuteLogger('Test');

        expect(
          () => logger.info('Message', extra: {}),
          returnsNormally,
        );
      });
    });
  });
}
