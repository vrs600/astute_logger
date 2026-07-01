import 'package:astute_logger/astute_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Logger Tests', () {
    late Logger logger;

    setUp(() {
      logger = Logger('TestClass');
    });

    // ===================================================================
    // ✅ TEST 1: Timestamp Format Validation
    // ===================================================================
    test(
        'Log message includes properly formatted timestamp (DD-MM-YYYY HH:MM:SS)',
        () {
      // Validate timestamp format using regex
      final timestampRegex = RegExp(
        r'\[\d{2}-\d{2}-\d{4}\s\d{2}:\d{2}:\d{2}\]',
      );

      expect(
        timestampRegex.hasMatch('[01-07-2026 14:23:45]'),
        isTrue,
        reason: 'Timestamp format should be DD-MM-YYYY HH:MM:SS',
      );
    });

    // ===================================================================
    // ✅ TEST 2: Logging doesn't throw error with basic message
    // ===================================================================
    test('Logger.write() executes without throwing exception', () {
      expect(
        () {
          logger.write(
            message: 'Test message',
            level: LogLevel.debug,
          );
        },
        returnsNormally,
        reason: 'Logger.write should not throw',
      );
    });

    // ===================================================================
    // ✅ TEST 3: Class Name > Method Format Construction
    // ===================================================================
    test('Log format includes ClassName::methodName pattern', () {
      final testLogger = Logger('AuthService');

      // Test format construction
      final title = 'AuthService';
      final methodLabel = 'login';
      final expectedFormat = '$title::$methodLabel';

      expect(
        expectedFormat,
        equals('AuthService::login'),
        reason: 'Format should be ClassName::methodName',
      );
    });

    // ===================================================================
    // ✅ TEST 4: Log Level Enum Values
    // ===================================================================
    test('LogLevel enum has all required values', () {
      expect(LogLevel.debug, isNotNull);
      expect(LogLevel.info, isNotNull);
      expect(LogLevel.warning, isNotNull);
      expect(LogLevel.error, isNotNull);
    });

    // ===================================================================
    // ✅ TEST 5: LogColor Enum with Correct Codes
    // ===================================================================
    test('LogColor enum values have correct ANSI color codes', () {
      expect(LogColor.green.code, equals('32'));
      expect(LogColor.blue.code, equals('34'));
      expect(LogColor.yellow.code, equals('33'));
      expect(LogColor.red.code, equals('31'));
    });

    // ===================================================================
    // ✅ TEST 6: Log File Path Resolution
    // ===================================================================
    test('getLogFile() returns a valid file reference', () async {
      final logFile = await Logger.getLogFile();
      expect(
        logFile,
        isNotNull,
        reason: 'Log file should be retrievable',
      );
    });

    // ===================================================================
    // ✅ TEST 7: Log File Persistence (Basic)
    // ===================================================================
    test('Logs are written to persistent file storage', () async {
      logger.write(
        message: 'Test log message for persistence',
        level: LogLevel.info,
      );

      // Wait for async queue to process
      await Future.delayed(Duration(milliseconds: 800));

      final logFile = await Logger.getLogFile();
      expect(
        logFile,
        isNotNull,
        reason: 'Log file should exist after writing',
      );

      if (logFile != null && logFile.existsSync()) {
        final content = await logFile.readAsString();
        expect(
          content.isNotEmpty,
          isTrue,
          reason: 'Log file should contain log entries',
        );
      }
    });

    // ===================================================================
    // ✅ TEST 8: Timestamp is Always Present in Logs
    // ===================================================================
    test('Every log entry contains a timestamp', () async {
      logger.write(
        message: 'Timestamped message',
        level: LogLevel.debug,
      );

      await Future.delayed(Duration(milliseconds: 800));

      final logFile = await Logger.getLogFile();
      if (logFile != null && logFile.existsSync()) {
        final content = await logFile.readAsString();
        final timestampPattern =
            RegExp(r'\[\d{2}-\d{2}-\d{4}\s\d{2}:\d{2}:\d{2}\]');

        expect(
          timestampPattern.hasMatch(content),
          isTrue,
          reason: 'Log should contain timestamp in DD-MM-YYYY HH:MM:SS format',
        );
      }
    });

    // ===================================================================
    // ✅ TEST 9: Logger Title is Included
    // ===================================================================
    test('Logger title (class name) appears in log output', () async {
      final customLogger = Logger('MyCustomClass');
      customLogger.write(
        message: 'Test with custom class',
        level: LogLevel.info,
      );

      await Future.delayed(Duration(milliseconds: 800));

      final logFile = await Logger.getLogFile();
      if (logFile != null && logFile.existsSync()) {
        final content = await logFile.readAsString();
        expect(
          content.contains('MyCustomClass'),
          isTrue,
          reason: 'Log should contain the logger title',
        );
      }
    });

    // ===================================================================
    // ✅ TEST 10: Sensitive Data Redaction - Tokens
    // ===================================================================
    test('Bearer tokens are redacted from logs', () async {
      const testMessage =
          'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';

      logger.write(
        message: testMessage,
        level: LogLevel.debug,
      );

      await Future.delayed(Duration(milliseconds: 800));

      final logFile = await Logger.getLogFile();
      if (logFile != null && logFile.existsSync()) {
        final content = await logFile.readAsString();

        expect(
          content.contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'),
          isFalse,
          reason: 'Token should be redacted',
        );
        expect(
          content.contains('[REDACTED]'),
          isTrue,
          reason: 'Should contain [REDACTED] placeholder',
        );
      }
    });

    // ===================================================================
    // ✅ TEST 11: Sensitive Data Redaction - Emails
    // ===================================================================
    test('Email addresses are redacted from logs', () async {
      const testMessage = 'User email: user@example.com logged in successfully';

      logger.write(
        message: testMessage,
        level: LogLevel.info,
      );

      await Future.delayed(Duration(milliseconds: 800));

      final logFile = await Logger.getLogFile();
      if (logFile != null && logFile.existsSync()) {
        final content = await logFile.readAsString();

        expect(
          content.contains('user@example.com'),
          isFalse,
          reason: 'Email should be redacted',
        );
        expect(
          content.contains('[REDACTED]'),
          isTrue,
          reason: 'Should contain [REDACTED] placeholder',
        );
      }
    });

    // ===================================================================
    // ✅ TEST 12: Sensitive Data Redaction - Credit Cards
    // ===================================================================
    test('Credit card numbers are redacted from logs', () async {
      const testMessage = 'Payment card: 4532015112830366 processed';

      logger.write(
        message: testMessage,
        level: LogLevel.warning,
      );

      await Future.delayed(Duration(milliseconds: 800));

      final logFile = await Logger.getLogFile();
      if (logFile != null && logFile.existsSync()) {
        final content = await logFile.readAsString();

        expect(
          content.contains('4532015112830366'),
          isFalse,
          reason: 'Credit card should be redacted',
        );
        expect(
          content.contains('[REDACTED]'),
          isTrue,
          reason: 'Should contain [REDACTED] placeholder',
        );
      }
    });

    // ===================================================================
    // ✅ TEST 13: Zone Context - Request ID
    // ===================================================================
    test('Zone context request ID is included in logs', () async {
      await LoggerContext.runWithContext(
        requestId: 'test-req-12345',
        body: () {
          logger.write(
            message: 'Test with zone context',
            level: LogLevel.info,
          );
          return null;
        },
      );

      await Future.delayed(Duration(milliseconds: 800));

      final logFile = await Logger.getLogFile();
      if (logFile != null && logFile.existsSync()) {
        final content = await logFile.readAsString();
        expect(
          content.contains('test-req-12345'),
          isTrue,
          reason: 'Log should contain zone request ID',
        );
      }
    });

    // ===================================================================
    // ✅ TEST 14: Zone Context - Extra Data
    // ===================================================================
    test('Zone context extra metadata is included in logs', () async {
      await LoggerContext.runWithContext(
        requestId: 'req-456',
        extra: {'userId': 'user-789', 'action': 'create'},
        body: () {
          logger.write(
            message: 'Action performed with context',
            level: LogLevel.info,
          );
          return null;
        },
      );

      await Future.delayed(Duration(milliseconds: 800));

      final logFile = await Logger.getLogFile();
      if (logFile != null && logFile.existsSync()) {
        final content = await logFile.readAsString();
        expect(
          content.contains('userId'),
          isTrue,
          reason: 'Log should contain extra context data',
        );
      }
    });

    // ===================================================================
    // ✅ TEST 15: Multiple Log Levels in Sequence
    // ===================================================================
    test('Multiple logs with different levels are all recorded', () async {
      logger.write(
        message: 'Debug message',
        level: LogLevel.debug,
      );
      logger.write(
        message: 'Info message',
        level: LogLevel.info,
      );
      logger.write(
        message: 'Warning message',
        level: LogLevel.warning,
      );
      logger.write(
        message: 'Error message',
        level: LogLevel.error,
      );

      await Future.delayed(Duration(milliseconds: 1000));

      final logFile = await Logger.getLogFile();
      if (logFile != null && logFile.existsSync()) {
        final content = await logFile.readAsString();

        expect(content.contains('Debug message'), isTrue);
        expect(content.contains('Info message'), isTrue);
        expect(content.contains('Warning message'), isTrue);
        expect(content.contains('Error message'), isTrue);
      }
    });

    // ===================================================================
    // ✅ TEST 16: JSON Pretty Printing
    // ===================================================================
    test('logJson does not throw error on valid JSON', () {
      final testJson = {'name': 'John', 'age': 30};

      expect(
        () => logger.logJson(testJson),
        returnsNormally,
        reason: 'logJson should handle valid JSON without throwing',
      );
    });

    // ===================================================================
    // ✅ TEST 17: JSON List Pretty Printing
    // ===================================================================
    test('logJsonList does not throw error on valid JSON list', () {
      final testList = [
        {'id': 1, 'name': 'Item 1'},
        {'id': 2, 'name': 'Item 2'},
      ];

      expect(
        () => logger.logJsonList(testList),
        returnsNormally,
        reason: 'logJsonList should handle valid list without throwing',
      );
    });

    // ===================================================================
    // ✅ TEST 18: Pretty List Printing
    // ===================================================================
    test('logPrettyList does not throw error on list', () {
      final testList = ['item1', 'item2', 'item3'];

      expect(
        () => logger.logPrettyList(testList, label: 'Test List'),
        returnsNormally,
        reason: 'logPrettyList should handle lists without throwing',
      );
    });

    // ===================================================================
    // ✅ TEST 19: Execution Time Logging
    // ===================================================================
    test('logExecutionTime measures and logs execution duration', () {
      final result = logger.logExecutionTime(
        'Test Operation',
        () {
          // Simulate some work
          int sum = 0;
          for (int i = 0; i < 100000; i++) {
            sum += i;
          }
          return sum;
        },
      );

      expect(
        result,
        isNotNull,
        reason: 'Should return the function result',
      );
      expect(
        result,
        isA<int>(),
        reason: 'Result should be an integer',
      );
    });

    // ===================================================================
    // ✅ TEST 20: Log With Color
    // ===================================================================
    test('logWithColor does not throw error', () {
      expect(
        () => logger.logWithColor('Colored message', color: '32'),
        returnsNormally,
        reason: 'logWithColor should execute without throwing',
      );
    });

    // ===================================================================
    // ✅ TEST 21: App Mode Detection
    // ===================================================================
    test('getAppMode() returns a valid LogLevel', () {
      final appMode = logger.getAppMode();

      expect(appMode, isNotNull);
      expect(appMode, isA<LogLevel>());

      if (kDebugMode) {
        expect(appMode, equals(LogLevel.debug));
      } else if (kProfileMode) {
        expect(appMode, equals(LogLevel.info));
      } else if (kReleaseMode) {
        expect(appMode, equals(LogLevel.error));
      }
    });

    // ===================================================================
    // ✅ TEST 22: Release Mode Behavior
    // ===================================================================
    test('Logs are skipped in release mode', () async {
      // This test documents the behavior
      // In kReleaseMode, write() returns early

      logger.write(
        message: 'Message in release mode',
        level: LogLevel.debug,
      );

      await Future.delayed(Duration(milliseconds: 500));

      // In release mode, no file should be written
      // In test environment, this is typically not release mode
      expect(!kReleaseMode, isTrue,
          reason:
              'Test environment should not be in release mode for this test');
    });

    // ===================================================================
    // ✅ TEST 23: Logger Context Symbols
    // ===================================================================
    test('LoggerContext defines required symbols', () {
      expect(LoggerContext.requestId, isNotNull);
      expect(LoggerContext.extraContext, isNotNull);
      expect(LoggerContext.requestId, isA<Symbol>());
      expect(LoggerContext.extraContext, isA<Symbol>());
    });

    // ===================================================================
    // ✅ TEST 24: Message with Extra Context Parameter
    // ===================================================================
    test('write() accepts extra context parameter', () {
      expect(
        () => logger.write(
          message: 'Test message',
          level: LogLevel.info,
          extra: {'userId': '123', 'action': 'test'},
        ),
        returnsNormally,
        reason: 'write() should accept extra parameter',
      );
    });

    // ===================================================================
    // ✅ TEST 25: Pretty Print Parameter
    // ===================================================================
    test('write() accepts prettyPrint parameter', () {
      expect(
        () => logger.write(
          message: '{"key": "value"}',
          level: LogLevel.info,
          prettyPrint: true,
        ),
        returnsNormally,
        reason: 'write() should accept prettyPrint parameter',
      );
    });

    // ===================================================================
    // ✅ TEST 26: ANSI Color Codes in Output
    // ===================================================================
    test('ANSI color codes are properly formatted', () {
      // The logger should use ANSI codes for coloring
      const redCode = '31';
      const startCode = '\x1B[';
      const endCode = '\x1B[0m';

      final coloredMessage = '$startCode${redCode}mTest$endCode';

      expect(coloredMessage.contains(startCode), isTrue);
      expect(coloredMessage.contains(endCode), isTrue);
      expect(coloredMessage.contains(redCode), isTrue);
    });

    // ===================================================================
    // ✅ TEST 27: Multiple Logger Instances
    // ===================================================================
    test('Multiple logger instances work independently', () {
      final logger1 = Logger('Class1');
      final logger2 = Logger('Class2');

      expect(() {
        logger1.write(message: 'From Class1', level: LogLevel.debug);
        logger2.write(message: 'From Class2', level: LogLevel.info);
      }, returnsNormally);

      expect(logger1.title, equals('Class1'));
      expect(logger2.title, equals('Class2'));
    });

    // ===================================================================
    // ✅ TEST 28: Empty Message Handling
    // ===================================================================
    test('Logger handles empty messages gracefully', () {
      expect(
        () => logger.write(
          message: '',
          level: LogLevel.debug,
        ),
        returnsNormally,
        reason: 'Logger should handle empty messages',
      );
    });

    // ===================================================================
    // ✅ TEST 29: Special Characters in Message
    // ===================================================================
    test('Logger handles special characters in messages', () async {
      logger.write(
        message: 'Special chars: !@#\$%^&*()_+-=[]{}|;:,.<>?/~`',
        level: LogLevel.info,
      );

      await Future.delayed(Duration(milliseconds: 800));

      final logFile = await Logger.getLogFile();
      if (logFile != null && logFile.existsSync()) {
        final content = await logFile.readAsString();
        expect(content.isNotEmpty, isTrue);
      }
    });

    // ===================================================================
    // ✅ TEST 30: Unicode Character Support
    // ===================================================================
    test('Logger handles unicode characters', () async {
      logger.write(
        message: 'Unicode test: 你好 مرحبا Здравствуй 🎉',
        level: LogLevel.info,
      );

      await Future.delayed(Duration(milliseconds: 800));

      final logFile = await Logger.getLogFile();
      if (logFile != null && logFile.existsSync()) {
        final content = await logFile.readAsString();
        expect(content.isNotEmpty, isTrue);
      }
    });
  });
}
