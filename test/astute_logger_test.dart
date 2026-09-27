import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:astute_logger/astute_logger.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // ─────────────────────────────────────────────────────────────────
  // Test harness helpers
  // ─────────────────────────────────────────────────────────────────
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('astute_logger_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      throw MissingPluginException();
    });
  });

  tearDown(() async {
    await AstuteLogger.flush();
    AstuteLogger.resetFileCache();
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// Creates a logger writing to a unique file, console disabled.
  AstuteLogger makeLogger({
    String? fileName,
    LogConfig? config,
    String title = 'Test',
  }) {
    final name =
        fileName ?? 'test_${DateTime.now().microsecondsSinceEpoch}.txt';
    return AstuteLogger(
      title,
      config: config ??
          LogConfig(
            enableConsoleOutput: false,
            enableColorLogging: false,
            logFileName: name,
          ),
    );
  }

  Future<String> readLog(String fileName) async {
    await AstuteLogger.flush();
    final file = File('${tempDir.path}/$fileName');
    if (!await file.exists()) return '';
    return file.readAsString();
  }

  // ═══════════════════════════════════════════════════════════════════
  // 1. ENUMS & CONSTANTS
  // ═══════════════════════════════════════════════════════════════════
  group('Enums and constants', () {
    test('LogLevel has exactly 5 levels in severity order', () {
      expect(LogLevel.values, [
        LogLevel.debug,
        LogLevel.info,
        LogLevel.warning,
        LogLevel.error,
        LogLevel.critical,
      ]);
      expect(LogLevel.debug.index, 0);
      expect(LogLevel.critical.index, 4);
    });

    test('AppMode has debug/profile/release/unknown', () {
      expect(
          AppMode.values,
          containsAll(<AppMode>[
            AppMode.debug,
            AppMode.profile,
            AppMode.release,
            AppMode.unknown,
          ]));
    });

    test('LogColor codes match ANSI SGR values', () {
      expect(LogColor.green.code, '32');
      expect(LogColor.blue.code, '34');
      expect(LogColor.yellow.code, '33');
      expect(LogColor.red.code, '31');
      expect(LogColor.magenta.code, '35');
    });

    test('appMode getter returns a valid enum value', () {
      final logger = makeLogger();
      expect(AppMode.values, contains(logger.appMode));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 2. LOG CONFIG
  // ═══════════════════════════════════════════════════════════════════
  group('LogConfig', () {
    test('defaults are sensible', () {
      const c = LogConfig();
      expect(c.enableRedaction, isTrue);
      expect(c.minimumLogLevel, LogLevel.debug);
      expect(c.enableConsoleOutput, isTrue);
      expect(c.enableFileOutput, isTrue);
      expect(c.logFileName, 'app_logs.txt');
      expect(c.enableColorLogging, isTrue);
      expect(c.redactEmails, isTrue);
    });

    test('all fields are configurable', () {
      const c = LogConfig(
        enableRedaction: false,
        minimumLogLevel: LogLevel.error,
        enableConsoleOutput: false,
        enableFileOutput: false,
        logFileName: 'x.txt',
        enableColorLogging: false,
        redactEmails: false,
      );
      expect(c.enableRedaction, isFalse);
      expect(c.minimumLogLevel, LogLevel.error);
      expect(c.enableConsoleOutput, isFalse);
      expect(c.enableFileOutput, isFalse);
      expect(c.logFileName, 'x.txt');
      expect(c.enableColorLogging, isFalse);
      expect(c.redactEmails, isFalse);
    });

    test('LogConfig is const-constructible', () {
      // Compile-time check: assigning to const variable.
      const c = LogConfig(minimumLogLevel: LogLevel.warning);
      expect(c.minimumLogLevel, LogLevel.warning);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 3. LOGGER INSTANTIATION & ACCESSORS
  // ═══════════════════════════════════════════════════════════════════
  group('Logger instantiation', () {
    test('can be created with title only', () {
      final l = AstuteLogger('MyLogger');
      expect(l.title, 'MyLogger');
      expect(l.config, isA<LogConfig>());
    });

    test('can be created with title and config', () {
      const c = LogConfig(minimumLogLevel: LogLevel.warning);
      final l = AstuteLogger('MyLogger', config: c);
      expect(l.title, 'MyLogger');
      expect(l.config, same(c));
    });

    test('multiple loggers are independent', () {
      final a = AstuteLogger('A');
      final b = AstuteLogger('B');
      expect(identical(a, b), isFalse);
      expect(a.title, 'A');
      expect(b.title, 'B');
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 4. LOG LEVEL FILTERING
  // ═══════════════════════════════════════════════════════════════════
  group('Log level filtering', () {
    test('minimumLogLevel=debug writes all levels', () async {
      final fileName = 'lvl_debug.txt';
      final l = makeLogger(
        fileName: fileName,
        config: LogConfig(
          enableConsoleOutput: false,
          enableColorLogging: false,
          logFileName: fileName,
          minimumLogLevel: LogLevel.debug,
        ),
      );
      await l.debug('D');
      await l.info('I');
      await l.warning('W');
      await l.error('E');
      await l.critical('C');
      final out = await readLog(fileName);
      for (final tag in ['D', 'I', 'W', 'E', 'C']) {
        expect(out, contains(tag));
      }
    });

    test('minimumLogLevel=error drops debug/info/warning', () async {
      final fileName = 'lvl_error.txt';
      final l = makeLogger(
        fileName: fileName,
        config: LogConfig(
          enableConsoleOutput: false,
          enableColorLogging: false,
          logFileName: fileName,
          minimumLogLevel: LogLevel.error,
        ),
      );
      await l.debug('D');
      await l.info('I');
      await l.warning('W');
      await l.error('E');
      await l.critical('C');
      final out = await readLog(fileName);
      expect(out, isNot(contains('-> D')));
      expect(out, isNot(contains('-> I')));
      expect(out, isNot(contains('-> W')));
      expect(out, contains('-> E'));
      expect(out, contains('-> C'));
    });

    test('minimumLogLevel=critical writes only critical', () async {
      final fileName = 'lvl_critical.txt';
      final l = makeLogger(
        fileName: fileName,
        config: LogConfig(
          enableConsoleOutput: false,
          enableColorLogging: false,
          logFileName: fileName,
          minimumLogLevel: LogLevel.critical,
        ),
      );
      await l.debug('D');
      await l.info('I');
      await l.error('E');
      await l.critical('C');
      final out = await readLog(fileName);
      expect(out, isNot(contains('-> D')));
      expect(out, isNot(contains('-> I')));
      expect(out, isNot(contains('-> E')));
      expect(out, contains('-> C'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 5. QUEUE SERIALIZATION (regression for critical bug)
  // ═══════════════════════════════════════════════════════════════════
  group('Async log queue', () {
    test('writes preserve insertion order under concurrency', () async {
      final fileName = 'queue_order.txt';
      final l = makeLogger(fileName: fileName);
      final messages = List.generate(50, (i) => 'ordered-$i');

      await Future.wait(messages.map(l.info));

      final lines = await File('${tempDir.path}/$fileName').readAsLines();
      final actual = lines
          .map((line) => line.substring(line.lastIndexOf(' -> ') + 4))
          .toList();
      expect(actual, equals(messages));
    });

    test('concurrent writes across multiple loggers serialize per file',
        () async {
      final fileName = 'multi_logger.txt';
      final a = makeLogger(fileName: fileName, title: 'A');
      final b = makeLogger(fileName: fileName, title: 'B');

      await Future.wait([
        a.info('a-1'),
        b.info('b-1'),
        a.info('a-2'),
        b.info('b-2'),
      ]);

      await AstuteLogger.flush();
      final lines = await File('${tempDir.path}/$fileName').readAsLines();
      expect(lines.length, 4);
      // Ordering across loggers is nondeterministic, but each line must
      // be complete and parseable.
      for (final line in lines) {
        expect(line, startsWith('[log] '));
        expect(line, contains(' -> '));
      }
    });

    test('write() Future completes only after file is persisted', () async {
      final fileName = 'persisted.txt';
      final l = makeLogger(fileName: fileName);
      await l.info('persisted-message');
      final out = await readLog(fileName);
      expect(out, contains('persisted-message'));
    });

    test('disabling file output skips disk write but write() still resolves',
        () async {
      final fileName = 'no_file.txt';
      final l = makeLogger(
        fileName: fileName,
        config: LogConfig(
          enableConsoleOutput: false,
          enableColorLogging: false,
          enableFileOutput: false,
          logFileName: fileName,
        ),
      );
      await l.info('will-not-persist');
      final out = await readLog(fileName);
      expect(out, isEmpty);
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 6. PRETTY PRINT (regression for broken path)
  // ═══════════════════════════════════════════════════════════════════
  group('prettyPrint', () {
    test('pretty-prints a JSON string body but keeps log prefix', () async {
      final fileName = 'pretty.json.txt';
      final l = makeLogger(fileName: fileName);

      await l.write(
        message: '{"a":1,"b":[2,3]}',
        level: LogLevel.info,
        prettyPrint: true,
      );
      final out = await readLog(fileName);
      expect(
          out, contains(' -> {\n  "a": 1,\n  "b": [\n    2,\n    3\n  ]\n}'));
    });

    test('non-JSON message is logged verbatim when prettyPrint is true',
        () async {
      final fileName = 'pretty.nonjson.txt';
      final l = makeLogger(fileName: fileName);

      await l.write(
        message: 'plain text',
        level: LogLevel.info,
        prettyPrint: true,
      );
      final out = await readLog(fileName);
      expect(out, contains(' -> plain text'));
    });

    test('redaction is applied to pretty-printed JSON', () async {
      final fileName = 'pretty.redact.txt';
      final l = makeLogger(fileName: fileName);

      await l.write(
        message: '{"password":"hunter2","user":"alice"}',
        level: LogLevel.info,
        prettyPrint: true,
      );
      final out = await readLog(fileName);
      expect(out, isNot(contains('hunter2')));
      // The password value should be redacted; user preserved.
      expect(out, contains('alice'));
    });

    test('ANSI codes are stripped before file write', () async {
      final fileName = 'ansi_strip.txt';
      final l = makeLogger(
        fileName: fileName,
        config: LogConfig(
          enableConsoleOutput: false,
          enableColorLogging: true,
          logFileName: fileName,
        ),
      );
      await l.info('colored');
      final out = await readLog(fileName);
      expect(out, isNot(contains('\x1B[')));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 7. REDACTION — key-based (structured)
  // ═══════════════════════════════════════════════════════════════════
  group('Object redaction', () {
    test('redacts top-level sensitive keys', () {
      final l = makeLogger();
      final result = l.redactObject({
        'user': 'alice',
        'password': 'hunter2',
        'token': 'abc',
      }) as Map;
      expect(result['user'], 'alice');
      expect(result['password'], '[REDACTED]');
      expect(result['token'], '[REDACTED]');
    });

    test('redacts nested map keys recursively', () {
      final l = makeLogger();
      final result = l.redactObject({
        'outer': {
          'inner': {'password': 'hunter2', 'safe': 'ok'}
        }
      }) as Map;
      expect(result['outer']['inner']['password'], '[REDACTED]');
      expect(result['outer']['inner']['safe'], 'ok');
    });

    test('redacts sensitive keys inside lists', () {
      final l = makeLogger();
      final result = l.redactObject([
        {'password': 'a', 'name': 'x'},
        {'password': 'b', 'name': 'y'},
      ]) as List;
      expect(result[0]['password'], '[REDACTED]');
      expect(result[1]['password'], '[REDACTED]');
      expect(result[0]['name'], 'x');
    });

    test('case-insensitive key matching', () {
      final l = makeLogger();
      final result = l.redactObject({
        'PASSWORD': 'x',
        'Token': 'y',
        'ApiKey': 'z',
      }) as Map;
      expect(result['PASSWORD'], '[REDACTED]');
      expect(result['Token'], '[REDACTED]');
      expect(result['ApiKey'], '[REDACTED]');
    });

    test('non-map/list values pass through unchanged', () {
      final l = makeLogger();
      expect(l.redactObject('plain'), 'plain');
      expect(l.redactObject(42), 42);
      expect(l.redactObject(null), isNull);
    });

    test('custom sensitive keys can be registered/unregistered', () {
      AstuteLogger.registerSensitiveKey('ssn');
      final l = makeLogger();
      final result = l.redactObject({'ssn': '123-45-6789'}) as Map;
      expect(result['ssn'], '[REDACTED]');

      AstuteLogger.unregisterSensitiveKey('ssn');
      final result2 = l.redactObject({'ssn': '123-45-6789'}) as Map;
      expect(result2['ssn'], '123-45-6789');
    });

    test('getSensitiveKeys returns sorted list', () {
      final keys = AstuteLogger.getSensitiveKeys();
      expect(keys, equals(List<String>.from(keys)..sort()));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 8. REDACTION — free-text regex rules
  // ═══════════════════════════════════════════════════════════════════
  group('Free-text redaction', () {
    Future<String> logAndRead(String message) async {
      final fileName = 'ft_${DateTime.now().microsecondsSinceEpoch}.txt';
      final l = makeLogger(fileName: fileName);
      await l.info(message);
      return readLog(fileName);
    }

    test('redacts quoted password value', () async {
      final out = await logAndRead('{"password": "p@ss!"}');
      expect(out, isNot(contains('p@ss!')));
      expect(out, contains('[REDACTED]'));
    });

    test('redacts Bearer token', () async {
      final out = await logAndRead('Authorization: Bearer abc-123.xyz');
      expect(out, isNot(contains('abc-123.xyz')));
      expect(out, contains('[REDACTED]'));
    });

    test('redacts bare token:value', () async {
      final out = await logAndRead('token:abc123 count:5');
      expect(out, isNot(contains('abc123')));
      expect(out, contains('count:5'));
    });

    test('does not redact the word "token" when not followed by a value',
        () async {
      final out = await logAndRead('token count is 5');
      expect(out, contains('token count is 5'));
    });

    test('redacts email addresses by default', () async {
      final out = await logAndRead('contact alice@example.com');
      expect(out, isNot(contains('alice@example.com')));
    });

    test('redactEmails=false preserves emails but still redacts cards',
        () async {
      final fileName = 'emails_off.txt';
      final l = makeLogger(
        fileName: fileName,
        config: LogConfig(
          enableConsoleOutput: false,
          enableColorLogging: false,
          logFileName: fileName,
          redactEmails: false,
        ),
      );
      await l.info('mail a@b.com card 4111111111111111');
      final out = await readLog(fileName);
      expect(out, contains('a@b.com'));
      expect(out, isNot(contains('4111111111111111')));
    });

    test('redacts credit card numbers', () async {
      final out = await logAndRead('card 4111111111111111 on file');
      expect(out, isNot(contains('4111111111111111')));
    });

    test('enableRedaction=false disables all free-text redaction', () async {
      final fileName = 'no_redact.txt';
      final l = makeLogger(
        fileName: fileName,
        config: LogConfig(
          enableConsoleOutput: false,
          enableColorLogging: false,
          logFileName: fileName,
          enableRedaction: false,
        ),
      );
      await l.info('password: "hunter2" email a@b.com');
      final out = await readLog(fileName);
      expect(out, contains('hunter2'));
      expect(out, contains('a@b.com'));
    });

    test('empty message is a no-op', () async {
      final out = await logAndRead('');
      expect(out, contains(' -> '));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 9. JSON LOGGING
  // ═══════════════════════════════════════════════════════════════════
  group('JSON logging', () {
    test('json() writes pretty-printed output', () async {
      final fileName = 'json.txt';
      final l = makeLogger(fileName: fileName);
      await l.json({'a': 1, 'b': 'two'});
      final out = await readLog(fileName);
      expect(out, contains('"a": 1'));
      expect(out, contains('"b": "two"'));
    });

    test('json() redacts sensitive keys before writing', () async {
      final fileName = 'json_redact.txt';
      final l = makeLogger(fileName: fileName);
      await l.json({'user': 'alice', 'password': 'hunter2'});
      final out = await readLog(fileName);
      expect(out, isNot(contains('hunter2')));
      expect(out, contains('alice'));
    });

    test('json() handles null input', () async {
      final fileName = 'json_null.txt';
      final l = makeLogger(fileName: fileName);
      await l.json(null);
      expect(await readLog(fileName), contains('null'));
    });

    test('json() supports custom level and tag', () async {
      final fileName = 'json_tag.txt';
      final l = makeLogger(fileName: fileName);
      await l.json({'x': 1}, level: LogLevel.error, tag: 'API');
      final out = await readLog(fileName);
      expect(out, contains('[API]'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 10. TAGS
  // ═══════════════════════════════════════════════════════════════════
  group('Tags', () {
    test('tag is uppercased and bracketed', () async {
      final fileName = 'tag.txt';
      final l = makeLogger(fileName: fileName);
      await l.info('msg', tag: 'api');
      final out = await readLog(fileName);
      expect(out, contains('[API]'));
    });

    test('empty/whitespace tag produces no tag token', () async {
      final fileName = 'tag_empty.txt';
      final l = makeLogger(fileName: fileName);
      await l.info('msg', tag: '   ');
      final out = await readLog(fileName);
      expect(out, isNot(contains('[]')));
    });

    test('special characters in tag are preserved verbatim', () async {
      final fileName = 'tag_special.txt';
      final l = makeLogger(fileName: fileName);
      await l.info('msg', tag: 'a-b_c.1');
      final out = await readLog(fileName);
      expect(out, contains('[A-B_C.1]'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 11. EXTRA CONTEXT
  // ═══════════════════════════════════════════════════════════════════
  group('Extra context', () {
    test('extra map appears in the log line', () async {
      final fileName = 'extra.txt';
      final l = makeLogger(fileName: fileName);
      await l.info('msg', extra: {'userId': '42'});
      final out = await readLog(fileName);
      expect(out, contains('userId'));
      expect(out, contains('42'));
    });

    test('extra can be empty map without crashing', () async {
      final fileName = 'extra_empty.txt';
      final l = makeLogger(fileName: fileName);
      await l.info('msg', extra: {});
      expect(await readLog(fileName), contains('msg'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 12. ZONE CONTEXT (LoggerContext)
  // ═══════════════════════════════════════════════════════════════════
  group('LoggerContext zone propagation', () {
    test('requestId is injected into log line', () async {
      final fileName = 'zone.txt';
      final l = makeLogger(fileName: fileName);

      await LoggerContext.runWithContext(
        requestId: 'REQ-123',
        body: () async {
          await l.info('inside zone');
        },
      );

      final out = await readLog(fileName);
      expect(out, contains('[ReqID: REQ-123]'));
    });

    test('extra context is merged into log line', () async {
      final fileName = 'zone_extra.txt';
      final l = makeLogger(fileName: fileName);

      await LoggerContext.runWithContext(
        requestId: 'REQ-9',
        extra: {'tenant': 'acme'},
        body: () async {
          await l.info('inside');
        },
      );

      final out = await readLog(fileName);
      expect(out, contains('tenant'));
      expect(out, contains('acme'));
    });

    test('zone context does not leak outside runWithContext', () async {
      final fileName = 'zone_leak.txt';
      final l = makeLogger(fileName: fileName);

      await LoggerContext.runWithContext(
        requestId: 'ONLY-INSIDE',
        body: () async {
          await l.info('inside');
        },
      );
      await l.info('outside');

      final out = await readLog(fileName);
      final lines = out.split('\n').where((s) => s.isNotEmpty).toList();
      expect(lines.first, contains('ONLY-INSIDE'));
      expect(lines.last, isNot(contains('ONLY-INSIDE')));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 13. EXECUTION TIME
  // ═══════════════════════════════════════════════════════════════════
  group('Execution time', () {
    test('logExecutionTime returns function result', () {
      final l = makeLogger();
      expect(l.logExecutionTime('op', () => 42), 42);
    });

    test('logExecutionTime logs even when function throws', () async {
      final fileName = 'exec_sync.txt';
      final l = makeLogger(fileName: fileName);
      expect(
        () => l.logExecutionTime('boom', () => throw StateError('x')),
        throwsA(isA<StateError>()),
      );
      // Allow queued write to flush.
      await l.info('flush');
      final out = await readLog(fileName);
      expect(out, contains('boom executed in'));
    });

    test('logExecutionTimeAsync returns value', () async {
      final l = makeLogger();
      final v = await l.logExecutionTimeAsync('op', () async => 'ok');
      expect(v, 'ok');
    });

    test('logExecutionTimeAsync logs even when function throws', () async {
      final fileName = 'exec_async.txt';
      final l = makeLogger(fileName: fileName);
      await expectLater(
        l.logExecutionTimeAsync('boom', () async => throw StateError('x')),
        throwsA(isA<StateError>()),
      );
      await l.info('flush');
      final out = await readLog(fileName);
      expect(out, contains('boom executed in'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 14. FILE OUTPUT & getLogFile
  // ═══════════════════════════════════════════════════════════════════
  group('File output', () {
    test('getLogFile returns a File in the documents directory', () async {
      final file = await AstuteLogger.getLogFile(fileName: 'custom.txt');
      expect(file, isNotNull);
      expect(file!.path, contains('custom.txt'));
      expect(file.path, contains(tempDir.path));
    });

    test('getLogFile returns the same File instance on repeat calls', () async {
      final a = await AstuteLogger.getLogFile(fileName: 'cached.txt');
      final b = await AstuteLogger.getLogFile(fileName: 'cached.txt');
      // After the fix, the file is cached and identical.
      expect(identical(a, b), isTrue);
    });

    test('appends rather than truncates across writes', () async {
      final fileName = 'append.txt';
      final l = makeLogger(fileName: fileName);
      await l.info('first');
      await l.info('second');
      final out = await readLog(fileName);
      expect(out, contains('first'));
      expect(out, contains('second'));
    });

    test('custom logFileName routes output correctly', () async {
      final l = makeLogger(fileName: 'custom_route.txt');
      await l.info('routed');
      expect(await readLog('custom_route.txt'), contains('routed'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 15. getLogsByTag
  // ═══════════════════════════════════════════════════════════════════
  group('getLogsByTag', () {
    test('returns matching lines, strips ANSI, preserves order', () async {
      final fileName = 'getlogs.txt';
      final l = makeLogger(
        fileName: fileName,
        config: LogConfig(
          enableConsoleOutput: false,
          enableColorLogging: true,
          logFileName: fileName,
        ),
      );
      await l.info('one', tag: 'API');
      await l.info('two', tag: 'DB');
      await l.info('three', tag: 'api'); // case-insensitive match

      final results =
          await AstuteLogger.getLogsByTag('api', fileName: fileName);

      expect(results.length, 2);
      expect(results[0], contains('one'));
      expect(results[1], contains('three'));
      for (final line in results) {
        expect(line, isNot(contains('\x1B[')));
      }
    });

    test('returns empty list when file does not exist', () async {
      final results =
          await AstuteLogger.getLogsByTag('X', fileName: 'missing.txt');
      expect(results, isEmpty);
    });

    test('returns empty list for whitespace-only tag', () async {
      final results = await AstuteLogger.getLogsByTag('   ');
      expect(results, isEmpty);
    });

    test('is case-insensitive', () async {
      final fileName = 'case.txt';
      final l = makeLogger(fileName: fileName);
      await l.info('m', tag: 'MixedCase');
      final lower =
          await AstuteLogger.getLogsByTag('mixedcase', fileName: fileName);
      final upper =
          await AstuteLogger.getLogsByTag('MIXEDCASE', fileName: fileName);
      expect(lower, hasLength(1));
      expect(upper, hasLength(1));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 16. LOG FORMAT
  // ═══════════════════════════════════════════════════════════════════
  group('Log line format', () {
    test('includes [log], timestamp, mode, and arrow', () async {
      final fileName = 'format.txt';
      final l = makeLogger(fileName: fileName);
      await l.info('the-message');
      final line = (await readLog(fileName)).trim().split('\n').first;
      expect(line, startsWith('[log] ['));
      expect(line, contains('->'));
      expect(line, contains('the-message'));
    });

    test('mode token is one of DEBUG/PROFILE/RELEASE/UNKNOWN', () async {
      final fileName = 'mode.txt';
      final l = makeLogger(fileName: fileName);
      await l.info('x');
      final line = (await readLog(fileName)).trim();
      expect(
        line,
        anyOf(
          contains('[DEBUG]'),
          contains('[PROFILE]'),
          contains('[RELEASE]'),
          contains('[UNKNOWN]'),
        ),
      );
    });

    test('color enabled wraps line with ANSI codes before file write',
        () async {
      final fileName = 'color.txt';
      final l = makeLogger(
        fileName: fileName,
        config: LogConfig(
          enableConsoleOutput: false,
          enableColorLogging: true,
          logFileName: fileName,
        ),
      );
      await l.info('c');
      // File is always stripped, but write() must have added color.
      final out = await readLog(fileName);
      expect(out, isNot(contains('\x1B[')));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 17. ERROR & CRITICAL
  // ═══════════════════════════════════════════════════════════════════
  group('Error & critical', () {
    test('error() includes error object and stack trace', () async {
      final fileName = 'err.txt';
      final l = makeLogger(fileName: fileName);

      try {
        throw StateError('kaboom');
      } catch (e, st) {
        await l.error('op failed', error: e, stackTrace: st);
      }

      final out = await readLog(fileName);
      expect(out, contains('op failed'));
      expect(out, contains('kaboom'));
      expect(out, contains('StackTrace'));
    });

    test('critical() includes error and stack trace', () async {
      final fileName = 'crit.txt';
      final l = makeLogger(fileName: fileName);
      try {
        throw ArgumentError('bad');
      } catch (e, st) {
        await l.critical('severe', error: e, stackTrace: st);
      }
      final out = await readLog(fileName);
      expect(out, contains('severe'));
      expect(out, contains('bad'));
    });

    test('error() with no error/stacktrace just logs the message', () async {
      final fileName = 'err_plain.txt';
      final l = makeLogger(fileName: fileName);
      await l.error('simple error');
      final out = await readLog(fileName);
      expect(out, contains('simple error'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 18. EDGE CASES
  // ═══════════════════════════════════════════════════════════════════
  group('Edge cases', () {
    test('empty message is handled gracefully', () async {
      final fileName = 'empty.txt';
      final l = makeLogger(fileName: fileName);
      await l.info('');
      expect(await readLog(fileName), contains(' -> '));
    });

    test('message containing ANSI codes is stripped in file', () async {
      final fileName = 'ansi_msg.txt';
      final l = makeLogger(fileName: fileName);
      await l.info('has \x1B[31mred\x1B[0m inside');
      final out = await readLog(fileName);
      expect(out, isNot(contains('\x1B[')));
      expect(out, contains('has'));
      expect(out, contains('red'));
    });

    test('very long messages are persisted intact', () async {
      final fileName = 'long.txt';
      final l = makeLogger(fileName: fileName);
      final long = 'x' * 10000;
      await l.info(long);
      final out = await readLog(fileName);
      expect(out, contains(long));
    });

    test('unicode and emoji survive round-trip', () async {
      final fileName = 'unicode.txt';
      final l = makeLogger(fileName: fileName);
      await l.info('héllo 世界 🚀');
      final out = await readLog(fileName);
      expect(out, contains('héllo 世界 🚀'));
    });

    test('concurrent loggers with the same file name do not corrupt', () async {
      final fileName = 'shared.txt';
      final loggers = List.generate(
        5,
        (i) => makeLogger(fileName: fileName, title: 'L$i'),
      );
      await Future.wait([
        for (var i = 0; i < loggers.length; i++)
          for (var j = 0; j < 10; j++) loggers[i].info('L$i-$j'),
      ]);
      final lines = await File('${tempDir.path}/$fileName').readAsLines();
      expect(lines.length, 50);
      for (final line in lines) {
        expect(line, startsWith('[log] '));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 19. STACK-TRACE METHOD EXTRACTION
  // ═══════════════════════════════════════════════════════════════════
  group('Method name resolution', () {
    test('log line includes a non-empty method label', () async {
      final fileName = 'method.txt';
      final l = makeLogger(fileName: fileName);
      await l.info('x');
      final line = (await readLog(fileName)).trim();
      // Format: "... -> x", the segment before "->" contains "Class.method".
      final beforeArrow = line.split(' -> ').first;
      final parts = beforeArrow.split(' ');
      expect(parts, isNotEmpty);
    });

    test('method label does not include internal logger frames', () async {
      final fileName = 'method_internal.txt';
      final l = makeLogger(fileName: fileName);
      await l.info('x');
      final line = await readLog(fileName);
      expect(line, isNot(contains('_nativeMethodName')));
      expect(line, isNot(contains('_resolveMethodName')));
      expect(line, isNot(contains('AstuteLogger.write')));
    });
  });
}
