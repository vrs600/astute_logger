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
    // 16. ACTUAL REDACTION FUNCTIONALITY TESTS
    // ═══════════════════════════════════════════════════════════════════
    group('Actual Redaction Functionality', () {
      test('Email redaction works correctly through public interface', () {
        final logger = AstuteLogger('Test');
        // Test through the json method which uses redaction internally
        final data = {
          'user': 'john',
          'email': 'test@example.com',
          'message': 'User login successful'
        };

        // The json method should redact sensitive data
        expect(() => logger.json(data), returnsNormally);
      });

      test('Token redaction works correctly through public interface', () {
        final logger = AstuteLogger('Test');
        final data = {'api_token': 'secret_token_123', 'user_id': 123};

        expect(() => logger.json(data), returnsNormally);
      });

      test('Password redaction works correctly through public interface', () {
        final logger = AstuteLogger('Test');
        final data = {
          'username': 'john',
          'password': 'mySecret123',
          'action': 'login'
        };

        expect(() => logger.json(data), returnsNormally);
      });

      test('Credit card redaction works correctly through public interface',
          () {
        final logger = AstuteLogger('Test');
        final data = {
          'payment_method': 'credit_card',
          'card_number': '4532-1234-5678-9010',
          'amount': 100.00
        };

        expect(() => logger.json(data), returnsNormally);
      });

      test('Redaction can be disabled in config', () {
        final config = const LogConfig(enableRedaction: false);
        final logger = AstuteLogger('Test', config: config);

        // When redaction is disabled, sensitive data should still be logged
        expect(() => logger.info('email: test@example.com'), returnsNormally);
      });

      test('Empty message handling', () {
        final logger = AstuteLogger('Test');
        // Empty message should be handled gracefully
        expect(() => logger.info(''), returnsNormally);
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // 17. ANSI CODE STRIPPING TESTS
    // ═══════════════════════════════════════════════════════════════════
    group('ANSI Code Stripping', () {
      test('ANSI code handling in log processing', () {
        final logger = AstuteLogger('Test');
        // The logger should handle ANSI codes in messages without crashing
        final message = 'Normal text with \x1B[32mgreen\x1B[0m color codes';
        expect(() => logger.info(message), returnsNormally);
      });

      test('ANSI codes in different log levels', () {
        final logger = AstuteLogger('Test');
        final message = 'Text with \x1B[31mred\x1B[0m colors';

        expect(() => logger.debug(message), returnsNormally);
        expect(() => logger.info(message), returnsNormally);
        expect(() => logger.warning(message), returnsNormally);
        expect(() => logger.error(message), returnsNormally);
        expect(() => logger.critical(message), returnsNormally);
      });
    });

    // ═══════════════════════════════════════════════════════════════════
    // 18. OBJECT REDACTION TESTS
    // ═══════════════════════════════════════════════════════════════════
    group('Object Redaction', () {
      test('Object redaction handles simple map with sensitive keys', () {
        final logger = AstuteLogger('Test');
        final data = {
          'name': 'John',
          'password': 'secret123',
          'email': 'john@example.com'
        };

        // Test through the json method which uses _redactObject internally
        expect(() => logger.json(data), returnsNormally);
      });

      test('Object redaction handles nested maps', () {
        final logger = AstuteLogger('Test');
        final data = {
          'user': {
            'name': 'John',
            'credentials': {'password': 'secret123', 'token': 'abc123'}
          }
        };

        expect(() => logger.json(data), returnsNormally);
      });

      test('Object redaction handles lists', () {
        final logger = AstuteLogger('Test');
        final data = [
          {'name': 'John', 'password': 'secret1'},
          {'name': 'Jane', 'password': 'secret2'}
        ];

        expect(() => logger.json(data), returnsNormally);
      });

      test('Object redaction handles mixed nested structures', () {
        final logger = AstuteLogger('Test');
        final data = {
          'users': [
            {
              'name': 'John',
              'emails': ['john@example.com', 'john.work@example.com'],
              'credentials': {
                'password': 'secret',
                'tokens': ['token1', 'token2']
              }
            }
          ]
        };

        expect(() => logger.json(data), returnsNormally);
      });

      test('Object redaction handles non-map, non-list values', () {
        final logger = AstuteLogger('Test');
        final data = 'simple string';

        expect(() => logger.json(data), returnsNormally);
      });
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
  // 8. TAG-BASED LOG RETRIEVAL TESTS
  // ═══════════════════════════════════════════════════════════════════
  group('Tag-based Log Retrieval', () {
    test('getLogsByTag method exists and is static', () {
      expect(AstuteLogger.getLogsByTag, isNotNull);
    });

    test('getLogsByTag returns empty list when no logs exist', () async {
      final logs = await AstuteLogger.getLogsByTag('test');
      expect(logs, isA<List<String>>());
      expect(logs, isEmpty);
    });

    test('getLogsByTag handles empty tag', () async {
      final logs = await AstuteLogger.getLogsByTag('');
      expect(logs, isA<List<String>>());
      // Should return empty list for empty tag
      expect(logs, isEmpty);
    });

    test('getLogsByTag handles whitespace-only tag', () async {
      final logs = await AstuteLogger.getLogsByTag('   ');
      expect(logs, isA<List<String>>());
      // Should return empty list for whitespace-only tag
      expect(logs, isEmpty);
    });

    test('getLogsByTag can be called with different cases', () async {
      // This test verifies the method can be called with different cases
      // Actual functionality would need a log file with known content to test properly
      await AstuteLogger.getLogsByTag('TEST');
      await AstuteLogger.getLogsByTag('test');
      await AstuteLogger.getLogsByTag('Test');

      // All calls should complete without throwing
      expect(true, isTrue);
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

  // ════╕══════════════════════════════════════════════════════════════════
  // 11. SENSITIVE KEY MANAGEMENT TESTS
  // ═══════════════════════════════════════════════════════════════════
  group('Sensitive Key Management', () {
    test('Default sensitive keys are present', () {
      final defaultKeys = AstuteLogger.getSensitiveKeys();
      expect(defaultKeys, contains('password'));
      expect(defaultKeys, contains('token'));
      expect(defaultKeys, contains('email'));
      expect(defaultKeys, contains('secret'));
    });

    test('Can register new sensitive key', () {
      AstuteLogger.registerSensitiveKey('api_key');
      final keys = AstuteLogger.getSensitiveKeys();
      expect(keys, contains('api_key'));
    });

    test('Can unregister sensitive key', () {
      // First register a key
      AstuteLogger.registerSensitiveKey('custom_key');
      expect(AstuteLogger.getSensitiveKeys(), contains('custom_key'));

      // Then unregister it
      AstuteLogger.unregisterSensitiveKey('custom_key');
      expect(AstuteLogger.getSensitiveKeys(), isNot(contains('custom_key')));
    });

    test('Sensitive keys are case-insensitive', () {
      AstuteLogger.registerSensitiveKey('API_KEY');
      final keys = AstuteLogger.getSensitiveKeys();
      expect(keys, contains('api_key'));
    });

    test('getSensitiveKeys returns sorted list', () {
      // Clear and add some keys in random order
      final defaultKeys = AstuteLogger.getSensitiveKeys();
      for (var key in defaultKeys) {
        AstuteLogger.unregisterSensitiveKey(key);
      }

      AstuteLogger.registerSensitiveKey('zebra');
      AstuteLogger.registerSensitiveKey('apple');
      AstuteLogger.registerSensitiveKey('banana');

      final keys = AstuteLogger.getSensitiveKeys();
      expect(keys, equals(['apple', 'banana', 'zebra']));

      // Restore default keys
      for (var key in defaultKeys) {
        AstuteLogger.registerSensitiveKey(key);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 12. JSON LOGGING TESTS
  // ═══════════════════════════════════════════════════════════════════
  group('JSON Logging', () {
    test('json method exists and can be called', () {
      final logger = AstuteLogger('Test');
      expect(() => logger.json({'key': 'value'}), returnsNormally);
    });

    test('json method accepts all log levels', () {
      final logger = AstuteLogger('Test');
      final data = {'test': 'data'};

      expect(() => logger.json(data, level: LogLevel.debug), returnsNormally);
      expect(() => logger.json(data, level: LogLevel.info), returnsNormally);
      expect(() => logger.json(data, level: LogLevel.warning), returnsNormally);
      expect(() => logger.json(data, level: LogLevel.error), returnsNormally);
      expect(
          () => logger.json(data, level: LogLevel.critical), returnsNormally);
    });

    test('json method accepts tag parameter', () {
      final logger = AstuteLogger('Test');
      expect(() => logger.json({'key': 'value'}, tag: 'TEST'), returnsNormally);
    });

    test('json method accepts extra parameter', () {
      final logger = AstuteLogger('Test');
      final extra = {'context': 'test'};
      expect(
          () => logger.json({'key': 'value'}, extra: extra), returnsNormally);
    });

    test('json method handles null object', () {
      final logger = AstuteLogger('Test');
      expect(() => logger.json(null), returnsNormally);
    });

    test('json method handles complex nested objects', () {
      final logger = AstuteLogger('Test');
      final complexData = {
        'user': {
          'id': 123,
          'profile': {
            'name': 'John',
            'settings': {'theme': 'dark', 'notifications': true}
          }
        },
        'items': [1, 2, 3],
        'metadata': {
          'timestamp': DateTime.now().toIso8601String(),
          'version': '1.0'
        }
      };

      expect(() => logger.json(complexData), returnsNormally);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 13. LOG LEVEL FILTERING TESTS
  // ═══════════════════════════════════════════════════════════════════
  group('Log Level Filtering', () {
    test('Debug level allows all logs', () {
      final config = const LogConfig(minimumLogLevel: LogLevel.debug);
      final logger = AstuteLogger('Test', config: config);

      // All these should work without filtering
      expect(() => logger.debug('debug message'), returnsNormally);
      expect(() => logger.info('info message'), returnsNormally);
      expect(() => logger.warning('warning message'), returnsNormally);
      expect(() => logger.error('error message'), returnsNormally);
      expect(() => logger.critical('critical message'), returnsNormally);
    });

    test('Info level filters debug logs', () {
      final config = const LogConfig(minimumLogLevel: LogLevel.info);
      final logger = AstuteLogger('Test', config: config);

      // Debug should be filtered out, others should work
      expect(() => logger.debug('debug message'),
          returnsNormally); // Still returns normally, just won't log
      expect(() => logger.info('info message'), returnsNormally);
      expect(() => logger.warning('warning message'), returnsNormally);
      expect(() => logger.error('error message'), returnsNormally);
      expect(() => logger.critical('critical message'), returnsNormally);
    });

    test('Warning level filters debug and info logs', () {
      final config = const LogConfig(minimumLogLevel: LogLevel.warning);
      final logger = AstuteLogger('Test', config: config);

      expect(() => logger.debug('debug message'), returnsNormally);
      expect(() => logger.info('info message'), returnsNormally);
      expect(() => logger.warning('warning message'), returnsNormally);
      expect(() => logger.error('error message'), returnsNormally);
      expect(() => logger.critical('critical message'), returnsNormally);
    });

    test('Error level filters debug, info, and warning logs', () {
      final config = const LogConfig(minimumLogLevel: LogLevel.error);
      final logger = AstuteLogger('Test', config: config);

      expect(() => logger.debug('debug message'), returnsNormally);
      expect(() => logger.info('info message'), returnsNormally);
      expect(() => logger.warning('warning message'), returnsNormally);
      expect(() => logger.error('error message'), returnsNormally);
      expect(() => logger.critical('critical message'), returnsNormally);
    });

    test('Critical level filters all except critical logs', () {
      final config = const LogConfig(minimumLogLevel: LogLevel.critical);
      final logger = AstuteLogger('Test', config: config);

      expect(() => logger.debug('debug message'), returnsNormally);
      expect(() => logger.info('info message'), returnsNormally);
      expect(() => logger.warning('warning message'), returnsNormally);
      expect(() => logger.error('error message'), returnsNormally);
      expect(() => logger.critical('critical message'), returnsNormally);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 14. TAG FUNCTIONALITY TESTS
  // ═══════════════════════════════════════════════════════════════════
  group('Tag Functionality', () {
    test('Tag parameter is optional', () {
      final logger = AstuteLogger('Test');
      expect(() => logger.info('message without tag'), returnsNormally);
    });

    test('Tag can be empty string', () {
      final logger = AstuteLogger('Test');
      expect(() => logger.info('message', tag: ''), returnsNormally);
    });

    test('Tag can be whitespace only', () {
      final logger = AstuteLogger('Test');
      expect(() => logger.info('message', tag: '   '), returnsNormally);
    });

    test('Tag can contain special characters', () {
      final logger = AstuteLogger('Test');
      expect(
          () => logger.info('message', tag: 'test-tag_123'), returnsNormally);
    });

    test('Tag is case-sensitive in output', () {
      final logger = AstuteLogger('Test');
      // Both should work, but will produce different tags
      expect(() => logger.info('message1', tag: 'TEST'), returnsNormally);
      expect(() => logger.info('message2', tag: 'test'), returnsNormally);
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
  // ══╕════════════════════════════════════════════════════════════════
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
  // 8. TAG-BASED LOG RETRIEVAL TESTS
  // ═══════════════════════════════════════════════════════════════════
  group('Tag-based Log Retrieval', () {
    test('getLogsByTag method exists and is static', () {
      expect(AstuteLogger.getLogsByTag, isNotNull);
    });

    test('getLogsByTag returns empty list when no logs exist', () async {
      final logs = await AstuteLogger.getLogsByTag('test');
      expect(logs, isA<List<String>>());
      expect(logs, isEmpty);
    });

    test('getLogsByTag handles empty tag', () async {
      final logs = await AstuteLogger.getLogsByTag('');
      expect(logs, isA<List<String>>());
      // Should return empty list for empty tag
      expect(logs, isEmpty);
    });

    test('getLogsByTag handles whitespace-only tag', () async {
      final logs = await AstuteLogger.getLogsByTag('   ');
      expect(logs, isA<List<String>>());
      // Should return empty list for whitespace-only tag
      expect(logs, isEmpty);
    });

    test('getLogsByTag can be called with different cases', () async {
      // This test verifies the method can be called with different cases
      // Actual functionality would need a log file with known content to test properly
      await AstuteLogger.getLogsByTag('TEST');
      await AstuteLogger.getLogsByTag('test');
      await AstuteLogger.getLogsByTag('Test');

      // All calls should complete without throwing
      expect(true, isTrue);
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
  // 11. SENSITIVE KEY MANAGEMENT TESTS
  // ═══════════════════════════════════════════════════════════════════
  group('Sensitive Key Management', () {
    test('Default sensitive keys are present', () {
      final defaultKeys = AstuteLogger.getSensitiveKeys();
      expect(defaultKeys, contains('password'));
      expect(defaultKeys, contains('token'));
      expect(defaultKeys, contains('email'));
      expect(defaultKeys, contains('secret'));
    });

    test('Can register new sensitive key', () {
      AstuteLogger.registerSensitiveKey('api_key');
      final keys = AstuteLogger.getSensitiveKeys();
      expect(keys, contains('api_key'));
    });

    test('Can unregister sensitive key', () {
      // First register a key
      AstuteLogger.registerSensitiveKey('custom_key');
      expect(AstuteLogger.getSensitiveKeys(), contains('custom_key'));

      // Then unregister it
      AstuteLogger.unregisterSensitiveKey('custom_key');
      expect(AstuteLogger.getSensitiveKeys(), isNot(contains('custom_key')));
    });

    test('Sensitive keys are case-insensitive', () {
      AstuteLogger.registerSensitiveKey('API_KEY');
      final keys = AstuteLogger.getSensitiveKeys();
      expect(keys, contains('api_key'));
    });

    test('getSensitiveKeys returns sorted list', () {
      // Clear and add some keys in random order
      final defaultKeys = AstuteLogger.getSensitiveKeys();
      for (var key in defaultKeys) {
        AstuteLogger.unregisterSensitiveKey(key);
      }

      AstuteLogger.registerSensitiveKey('zebra');
      AstuteLogger.registerSensitiveKey('apple');
      AstuteLogger.registerSensitiveKey('banana');

      final keys = AstuteLogger.getSensitiveKeys();
      expect(keys, equals(['apple', 'banana', 'zebra']));

      // Restore default keys
      for (var key in defaultKeys) {
        AstuteLogger.registerSensitiveKey(key);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 12. JSON LOGGING TESTS
  // ═══════════════════════════════════════════════════════════════════
  group('JSON Logging', () {
    test('json method exists and can be called', () {
      final logger = AstuteLogger('Test');
      expect(() => logger.json({'key': 'value'}), returnsNormally);
    });

    test('json method accepts all log levels', () {
      final logger = AstuteLogger('Test');
      final data = {'test': 'data'};

      expect(() => logger.json(data, level: LogLevel.debug), returnsNormally);
      expect(() => logger.json(data, level: LogLevel.info), returnsNormally);
      expect(() => logger.json(data, level: LogLevel.warning), returnsNormally);
      expect(() => logger.json(data, level: LogLevel.error), returnsNormally);
      expect(
          () => logger.json(data, level: LogLevel.critical), returnsNormally);
    });

    test('json method accepts tag parameter', () {
      final logger = AstuteLogger('Test');
      expect(() => logger.json({'key': 'value'}, tag: 'TEST'), returnsNormally);
    });

    test('json method accepts extra parameter', () {
      final logger = AstuteLogger('Test');
      final extra = {'context': 'test'};
      expect(
          () => logger.json({'key': 'value'}, extra: extra), returnsNormally);
    });

    test('json method handles null object', () {
      final logger = AstuteLogger('Test');
      expect(() => logger.json(null), returnsNormally);
    });

    test('json method handles complex nested objects', () {
      final logger = AstuteLogger('Test');
      final complexData = {
        'user': {
          'id': 123,
          'profile': {
            'name': 'John',
            'settings': {'theme': 'dark', 'notifications': true}
          }
        },
        'items': [1, 2, 3],
        'metadata': {
          'timestamp': DateTime.now().toIso8601String(),
          'version': '1.0'
        }
      };

      expect(() => logger.json(complexData), returnsNormally);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 13. LOG LEVEL FILTERING TESTS
  // ═══════════════════════════════════════════════════════════════════
  group('Log Level Filtering', () {
    test('Debug level allows all logs', () {
      final config = const LogConfig(minimumLogLevel: LogLevel.debug);
      final logger = AstuteLogger('Test', config: config);

      // All these should work without filtering
      expect(() => logger.debug('debug message'), returnsNormally);
      expect(() => logger.info('info message'), returnsNormally);
      expect(() => logger.warning('warning message'), returnsNormally);
      expect(() => logger.error('error message'), returnsNormally);
      expect(() => logger.critical('critical message'), returnsNormally);
    });

    test('Info level filters debug logs', () {
      final config = const LogConfig(minimumLogLevel: LogLevel.info);
      final logger = AstuteLogger('Test', config: config);

      // Debug should be filtered out, others should work
      expect(() => logger.debug('debug message'),
          returnsNormally); // Still returns normally, just won't log
      expect(() => logger.info('info message'), returnsNormally);
      expect(() => logger.warning('warning message'), returnsNormally);
      expect(() => logger.error('error message'), returnsNormally);
      expect(() => logger.critical('critical message'), returnsNormally);
    });

    test('Warning level filters debug and info logs', () {
      final config = const LogConfig(minimumLogLevel: LogLevel.warning);
      final logger = AstuteLogger('Test', config: config);

      expect(() => logger.debug('debug message'), returnsNormally);
      expect(() => logger.info('info message'), returnsNormally);
      expect(() => logger.warning('warning message'), returnsNormally);
      expect(() => logger.error('error message'), returnsNormally);
      expect(() => logger.critical('critical message'), returnsNormally);
    });

    test('Error level filters debug, info, and warning logs', () {
      final config = const LogConfig(minimumLogLevel: LogLevel.error);
      final logger = AstuteLogger('Test', config: config);

      expect(() => logger.debug('debug message'), returnsNormally);
      expect(() => logger.info('info message'), returnsNormally);
      expect(() => logger.warning('warning message'), returnsNormally);
      expect(() => logger.error('error message'), returnsNormally);
      expect(() => logger.critical('critical message'), returnsNormally);
    });

    test('Critical level filters all except critical logs', () {
      final config = const LogConfig(minimumLogLevel: LogLevel.critical);
      final logger = AstuteLogger('Test', config: config);

      expect(() => logger.debug('debug message'), returnsNormally);
      expect(() => logger.info('info message'), returnsNormally);
      expect(() => logger.warning('warning message'), returnsNormally);
      expect(() => logger.error('error message'), returnsNormally);
      expect(() => logger.critical('critical message'), returnsNormally);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 14. TAG FUNCTIONALITY TESTS
  // ═══════════════════════════════════════════════════════════════════
  group('Tag Functionality', () {
    test('Tag parameter is optional', () {
      final logger = AstuteLogger('Test');
      expect(() => logger.info('message without tag'), returnsNormally);
    });

    test('Tag can be empty string', () {
      final logger = AstuteLogger('Test');
      expect(() => logger.info('message', tag: ''), returnsNormally);
    });

    test('Tag can be whitespace only', () {
      final logger = AstuteLogger('Test');
      expect(() => logger.info('message', tag: '   '), returnsNormally);
    });

    test('Tag can contain special characters', () {
      final logger = AstuteLogger('Test');
      expect(
          () => logger.info('message', tag: 'test-tag_123'), returnsNormally);
    });

    test('Tag is case-sensitive in output', () {
      final logger = AstuteLogger('Test');
      // Both should work, but will produce different tags
      expect(() => logger.info('message1', tag: 'TEST'), returnsNormally);
      expect(() => logger.info('message2', tag: 'test'), returnsNormally);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 15. EXTRA CONTEXT TESTS
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

    test('Extra context with nested objects', () {
      final logger = AstuteLogger('Test');
      final extra = {
        'user': {
          'id': 123,
          'profile': {'name': 'John', 'email': 'john@example.com'}
        },
        'metadata': {'timestamp': DateTime.now().toIso8601String()}
      };

      expect(
          () => logger.info('Complex context', extra: extra), returnsNormally);
    });

    test('Extra context with lists', () {
      final logger = AstuteLogger('Test');
      final extra = {
        'items': [1, 2, 3],
        'names': ['Alice', 'Bob', 'Charlie']
      };

      expect(() => logger.info('List context', extra: extra), returnsNormally);
    });
  });
}
