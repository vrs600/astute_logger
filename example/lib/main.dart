import 'dart:async';
import 'dart:convert';

import 'package:astute_logger/astute_logger.dart';
import 'package:astute_logger/service/logging_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AstuteLoggerDemoApp());
}

/// Entry-point widget. The demo runs once on first frame so that
/// the log file can be persisted before we render the results.
class AstuteLoggerDemoApp extends StatelessWidget {
  const AstuteLoggerDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const DemoHomePage(),
    );
  }
}

class DemoHomePage extends StatefulWidget {
  const DemoHomePage({super.key});

  @override
  State<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends State<DemoHomePage> {
  // ───────────────────────────────────────────────────────────────────
  // Logger configuration — every LogConfig field is exercised here.
  // ───────────────────────────────────────────────────────────────────
  final AstuteLogger _logger = AstuteLogger(
    'AstuteLoggerDemo',
    config: const LogConfig(
      enableConsoleOutput: true,
      enableFileOutput: true,
      enableColorLogging: true,
      enableRedaction: true,
      redactEmails: true,
      minimumLogLevel: LogLevel.debug,
      logFileName: 'astute_demo_logs.txt',
    ),
  );

  final List<String> _report = <String>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runDemo());
  }

  // ═══════════════════════════════════════════════════════════════════
  // DEMO DRIVER — calls each feature in turn and records the output.
  // ═══════════════════════════════════════════════════════════════════
  Future<void> _runDemo() async {
    await _demoBasicLevels();
    await _demoExtraContext();
    await _demoZoneContext();
    await _demoTags();
    await _demoRedactionFreeText();
    await _demoStructuredJson();
    await _demoObjectRedaction();
    await _demoCustomSensitiveKey();
    await _demoPrettyPrint();
    await _demoExecutionTime();
    await _demoErrorAndCritical();
    await _demoLogLevelFiltering();
    await _demoColorToggle();
    await _demoMultipleLoggers();
    await _demoReadLogFile();
    await _demoGetLogsByTag();
    await _demoDioInterceptor();

    // Ensure every queued write is persisted before reading back.
    await AstuteLogger.flush();
    await _demoDisplayTailOfLogFile();

    if (mounted) setState(() {});
  }

  // ───────────────────────────────────────────────────────────────────
  // 1. Log levels
  // ───────────────────────────────────────────────────────────────────
  Future<void> _demoBasicLevels() async {
    _section('1. Log Levels');

    await _logger.debug('Debug log — very verbose diagnostics');
    await _logger.info('Info log — normal application flow');
    await _logger.warning('Warning log — something looks suspicious');
    await _logger.error('Error log — an operation failed');
    await _logger.critical('Critical log — the app is in trouble');
  }

  // ───────────────────────────────────────────────────────────────────
  // 2. Extra context
  // ───────────────────────────────────────────────────────────────────
  Future<void> _demoExtraContext() async {
    _section('2. Extra Context (per-call metadata)');

    await _logger.info(
      'Application started',
      extra: {'version': '3.0.0', 'platform': 'Android'},
    );

    await _logger.warning('Battery level is low', extra: {'battery': '15%'});
  }

  // ───────────────────────────────────────────────────────────────────
  // 3. Zone-based context (LoggerContext)
  // ───────────────────────────────────────────────────────────────────
  Future<void> _demoZoneContext() async {
    _section('3. Zone Context (LoggerContext.runWithContext)');

    await LoggerContext.runWithContext(
      requestId: 'REQ-20260722-001',
      extra: {'userId': 123, 'screen': 'Home', 'feature': 'Login'},
      body: () async {
        await _logger.info(
          'This log is automatically enriched with ReqID and Ctx',
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // 4. Tags
  // ───────────────────────────────────────────────────────────────────
  Future<void> _demoTags() async {
    _section('4. Tags');

    await _logger.info('User logged in', tag: 'AUTH');
    await _logger.info('Fetching /users', tag: 'NETWORK');
    await _logger.info('Query executed in 42ms', tag: 'DATABASE');
    await _logger.debug('Cache hit', tag: 'CACHE');
  }

  // ───────────────────────────────────────────────────────────────────
  // 5. Free-text redaction
  // ───────────────────────────────────────────────────────────────────
  Future<void> _demoRedactionFreeText() async {
    _section('5. Free-Text Redaction');

    await _logger.info('''
Raw payload:
  Email       : john.doe@gmail.com
  Authorization: Bearer abcdefghijklmnopqrstuvwxyz123456789
  password=mySuperSecretPassword
  Card        : 4111111111111111
''');
  }

  // ───────────────────────────────────────────────────────────────────
  // 6. Structured JSON logging + pretty print + redaction
  // ───────────────────────────────────────────────────────────────────
  Future<void> _demoStructuredJson() async {
    _section('6. Structured JSON Logging (json())');

    await _logger.json(
      {
        'user': {
          'id': 1,
          'name': 'John',
          'roles': ['Admin', 'Manager'],
        },
        'permissions': ['read', 'write', 'delete'],
        'password': 'hunter2', // → [REDACTED] by key redaction
        'email': 'john@example.com', // → [REDACTED] by key redaction
      },
      tag: 'PROFILE',
      level: LogLevel.info,
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // 7. Public redactObject() helper
  // ───────────────────────────────────────────────────────────────────
  Future<void> _demoObjectRedaction() async {
    _section('7. redactObject() — programmatic key-based redaction');

    final redacted = _logger.redactObject({
      'user': 'alice',
      'credentials': {'password': 'hunter2', 'refreshToken': 'abc.def.ghi'},
    });

    await _logger.info('Redacted object: $redacted', tag: 'REDACT');
  }

  // ───────────────────────────────────────────────────────────────────
  // 8. Custom sensitive keys
  // ───────────────────────────────────────────────────────────────────
  Future<void> _demoCustomSensitiveKey() async {
    _section('8. Custom Sensitive Keys');

    AstuteLogger.registerSensitiveKey('ssn');
    await _logger.json({'ssn': '123-45-6789', 'name': 'Alice'});
    AstuteLogger.unregisterSensitiveKey('ssn');

    await _logger.info('Registered keys: ${AstuteLogger.getSensitiveKeys()}');
  }

  // ───────────────────────────────────────────────────────────────────
  // 9. prettyPrint on raw JSON strings
  // ───────────────────────────────────────────────────────────────────
  Future<void> _demoPrettyPrint() async {
    _section('9. Pretty-Print Raw JSON String');

    final rawJson = jsonEncode({
      'order': {
        'id': 'ORD-1',
        'items': [
          {'sku': 'A1', 'qty': 2},
          {'sku': 'B7', 'qty': 1},
        ],
        'token': 'secret-abc', // → [REDACTED]
      },
    });

    await _logger.write(
      message: rawJson,
      prettyPrint: true,
      level: LogLevel.info,
      tag: 'ORDER',
    );

    await _logger.write(
      message: 'this is not json, so it logs verbatim',
      prettyPrint: true,
      level: LogLevel.info,
      tag: 'ORDER',
    );
  }

  // ───────────────────────────────────────────────────────────────────
  // 10. Execution time measurement
  // ───────────────────────────────────────────────────────────────────
  Future<void> _demoExecutionTime() async {
    _section('10. Execution Time');

    final sorted = _logger.logExecutionTime('Sorting List', () {
      final list = List.generate(200000, (i) => 200000 - i);
      list.sort();
      return list;
    });
    await _logger.info('Sorted ${sorted.length} elements', tag: 'PERF');

    await _logger.logExecutionTimeAsync('Fake API Call', () async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    });

    // Timing is logged even when the measured function throws.
    try {
      _logger.logExecutionTime('Throwing operation', () {
        throw StateError('intentional');
      });
    } catch (_) {
      // Swallowed for demo — the timing line was already emitted.
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // 11. Error & critical with stack trace
  // ───────────────────────────────────────────────────────────────────
  Future<void> _demoErrorAndCritical() async {
    _section('11. Error & Critical with Stack Trace');

    try {
      throw Exception('Something went terribly wrong.');
    } catch (e, st) {
      await _logger.error('Caught exception', error: e, stackTrace: st);
      await _logger.critical(
        'Database connection lost',
        error: e,
        stackTrace: st,
        tag: 'DB',
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // 12. minimumLogLevel filtering
  // ───────────────────────────────────────────────────────────────────
  Future<void> _demoLogLevelFiltering() async {
    _section('12. minimumLogLevel Filtering');

    final errorOnly = AstuteLogger(
      'ErrorOnly',
      config: const LogConfig(
        enableConsoleOutput: false,
        enableColorLogging: false,
        minimumLogLevel: LogLevel.error,
        logFileName: 'astute_demo_logs.txt',
      ),
    );

    await errorOnly.debug('DROPPED — below threshold');
    await errorOnly.info('DROPPED — below threshold');
    await errorOnly.warning('DROPPED — below threshold');
    await errorOnly.error('KEPT — at threshold');
    await errorOnly.critical('KEPT — above threshold');
  }

  // ───────────────────────────────────────────────────────────────────
  // 13. Color toggle
  // ───────────────────────────────────────────────────────────────────
  Future<void> _demoColorToggle() async {
    _section('13. Colored Console Output');

    final colorful = AstuteLogger(
      'Colorful',
      config: const LogConfig(
        enableConsoleOutput: true,
        enableColorLogging: true,
        enableFileOutput: false,
      ),
    );

    await colorful.debug('green');
    await colorful.info('blue');
    await colorful.warning('yellow');
    await colorful.error('red');
    await colorful.critical('magenta');
  }

  // ───────────────────────────────────────────────────────────────────
  // 14. Multiple independent loggers sharing a file
  // ───────────────────────────────────────────────────────────────────
  Future<void> _demoMultipleLoggers() async {
    _section('14. Multiple Loggers Writing to the Same File');

    final a = AstuteLogger(
      'LoggerA',
      config: const LogConfig(
        enableConsoleOutput: false,
        logFileName: 'astute_demo_logs.txt',
      ),
    );
    final b = AstuteLogger(
      'LoggerB',
      config: const LogConfig(
        enableConsoleOutput: false,
        logFileName: 'astute_demo_logs.txt',
      ),
    );

    // Fire concurrently — the queue guarantees serialized writes.
    await Future.wait([
      a.info('A-1'),
      b.info('B-1'),
      a.info('A-2'),
      b.info('B-2'),
    ]);
  }

  // ───────────────────────────────────────────────────────────────────
  // 15. Read log file
  // ───────────────────────────────────────────────────────────────────
  Future<void> _demoReadLogFile() async {
    _section('15. Read Log File');

    final file = await AstuteLogger.getLogFile(
      fileName: 'astute_demo_logs.txt',
    );

    if (file != null && await file.exists()) {
      final size = await file.length();
      await _logger.info(
        'Log file at ${file.path} (${size} bytes)',
        tag: 'FILE',
      );
    } else {
      await _logger.warning('Log file not found', tag: 'FILE');
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // 16. Filter logs by tag
  // ───────────────────────────────────────────────────────────────────
  Future<void> _demoGetLogsByTag() async {
    _section('16. getLogsByTag');

    await AstuteLogger.flush();

    final authLogs = await AstuteLogger.getLogsByTag(
      'AUTH',
      fileName: 'astute_demo_logs.txt',
    );
    final networkLogs = await AstuteLogger.getLogsByTag(
      'NETWORK',
      fileName: 'astute_demo_logs.txt',
    );
    final none = await AstuteLogger.getLogsByTag(
      'NOPE',
      fileName: 'astute_demo_logs.txt',
    );

    _add('AUTH logs found: ${authLogs.length}');
    _add('NETWORK logs found: ${networkLogs.length}');
    _add('NOPE logs found: ${none.length}');
  }

  // ───────────────────────────────────────────────────────────────────
  // 17. Dio interceptor
  // ───────────────────────────────────────────────────────────────────
  Future<void> _demoDioInterceptor() async {
    _section('17. Dio LoggingInterceptor');

    final dio = Dio()
      ..interceptors.add(
        LoggingInterceptor(
          logger: _logger,
          logRequestHeaders: true,
          logRequestBody: true,
          logResponseHeaders: true,
          logResponseBody: true,
          maxBodyLength: 2000,
          maxHeaderValueLength: 500,
        ),
      );

    try {
      await _logger.info('Making test HTTP request...', tag: 'HTTP');
      await dio.get<dynamic>(
        'https://jsonplaceholder.typicode.com/posts/1',
        options: Options(headers: {'x-demo-trace': 'abc-123'}),
      );
      await _logger.info('HTTP request completed', tag: 'HTTP');
    } catch (e) {
      await _logger.error('HTTP request failed', error: e, tag: 'HTTP');
    } finally {
      dio.close(force: true);
    }
  }

  // ───────────────────────────────────────────────────────────────────
  // 18. Show the last N lines of the log file on screen
  // ───────────────────────────────────────────────────────────────────
  Future<void> _demoDisplayTailOfLogFile() async {
    _section('18. Tail of Log File');

    final file = await AstuteLogger.getLogFile(
      fileName: 'astute_demo_logs.txt',
    );
    if (file == null || !await file.exists()) return;

    final content = await file.readAsString();
    final lines = content.split('\n').where((l) => l.isNotEmpty).toList();
    final tail = lines.length <= 15 ? lines : lines.sublist(lines.length - 15);

    for (final line in tail) {
      _add(line);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // UI helpers
  // ═══════════════════════════════════════════════════════════════════
  void _section(String title) {
    _report
      ..add('')
      ..add('═══════════════════════════════════════')
      ..add(title)
      ..add('═══════════════════════════════════════');
  }

  void _add(String line) => _report.add(line);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Astute Logger Demo'),
        actions: [
          IconButton(
            tooltip: 'Clear log file',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final file = await AstuteLogger.getLogFile(
                fileName: 'astute_demo_logs.txt',
              );
              if (file != null && await file.exists()) {
                await file.delete();
              }
              setState(() => _report.clear());
            },
          ),
        ],
      ),
      body: _report.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _report.length,
              itemBuilder: (context, i) {
                final line = _report[i];
                final isHeader =
                    line.startsWith('══') ||
                    line.startsWith('1.') ||
                    line.startsWith('2.') ||
                    line.startsWith('3.') ||
                    line.startsWith('4.') ||
                    line.startsWith('5.') ||
                    line.startsWith('6.') ||
                    line.startsWith('7.') ||
                    line.startsWith('8.') ||
                    line.startsWith('9.') ||
                    line.startsWith('1') ||
                    line.startsWith('0');
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    line,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      fontWeight: isHeader
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
