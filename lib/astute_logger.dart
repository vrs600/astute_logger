import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel { debug, info, warning, error }

enum LogColor {
  green('32'),
  blue('34'),
  yellow('33'),
  red('31');

  final String code;
  const LogColor(this.code);
}

class _LogEvent {
  final Logger logger;
  final String text;
  final bool prettyPrint;

  const _LogEvent({
    required this.logger,
    required this.text,
    required this.prettyPrint,
  });
}

abstract final class LoggerContext {
  static const Symbol requestId = Symbol('logger_request_id');
  static const Symbol extraContext = Symbol('logger_extra_context');

  /// Runs [body] inside a new asynchronous Zone injected with logging metadata.
  static R runWithContext<R>({
    required String requestId,
    Map<String, dynamic>? extra,
    required R Function() body,
  }) {
    return Zone.current.fork(
      zoneValues: {
        LoggerContext.requestId: requestId,
        if (extra != null) LoggerContext.extraContext: extra,
      },
    ).run(body);
  }
}

class Logger {
  final String title;
  Logger(this.title);

  // ------------------------------------------------------------------
  // 📥 Async Logging Queue Pipeline
  // ------------------------------------------------------------------
  static File? _logFile;
  static final StreamController<_LogEvent> _queueController =
      StreamController<_LogEvent>()..stream.listen(_processLogQueue);

  static Future<void> _processLogQueue(_LogEvent event) async {
    // 1. Standard console logging output
    if (event.prettyPrint) {
      event.logger.logJson(event.text);
    } else {
      log(event.text);
    }

    // 2. Persistent file recording output
    try {
      if (_logFile == null) {
        final directory = await getApplicationDocumentsDirectory();
        _logFile = File('${directory.path}/app_logs.txt');
      }

      // Strip ANSI color escape characters before writing text out to the file
      final cleanText = event.text.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');

      await _logFile!.writeAsString(
        '$cleanText\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      log('Failed to write log to persistent file storage: $e',
          name: 'LoggerError');
    }
  }

  /// Public access utility method to retrieve the raw file containing persisted logs
  static Future<File?> getLogFile() async {
    if (_logFile != null) return _logFile;
    try {
      final directory = await getApplicationDocumentsDirectory();
      return File('${directory.path}/app_logs.txt');
    } catch (_) {
      return null;
    }
  }

  void write({
    required String message,
    bool prettyPrint = false,
    required LogLevel level,
    Map<String, dynamic>? extra,
  }) {
    if (kReleaseMode) return;

    final scrubbedMessage = _redactSensitiveData(message);
    final methodLabel = _resolveMethodName();

    // 1. Gather explicit parameter extra metadata
    final Map<String, dynamic> combinedContext = {};
    if (extra != null) {
      combinedContext.addAll(extra);
    }

    // 2. Extract Zone-propagated metadata safely
    final zoneRequestId = Zone.current[LoggerContext.requestId] as String?;
    final zoneExtra =
        Zone.current[LoggerContext.extraContext] as Map<String, dynamic>?;

    if (zoneExtra != null) {
      combinedContext.addAll(zoneExtra);
    }

    // 3. Construct context metadata tag
    String contextTag = '';
    if (zoneRequestId != null) {
      contextTag += '[ReqID: $zoneRequestId]';
    }
    if (combinedContext.isNotEmpty) {
      contextTag += ' [Ctx: $combinedContext]';
    }
    if (contextTag.isNotEmpty) {
      contextTag = '$contextTag ';
    }
    final now = DateTime.now();
    final localTimestamp = "${now.day}-${_two(now.month)}-${_two(now.year)} "
        "${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}";

    String logText =
        "[$localTimestamp] [${getAppMode().name.toUpperCase()}] $contextTag$title::$methodLabel -> $scrubbedMessage";

    logText = _colorize(logText, _getColorForLevel(level));

    _queueController.add(_LogEvent(
      logger: this,
      text: logText,
      prettyPrint: prettyPrint,
    ));
  }

  // ------------------------------------------------------------------
  // 🟨 Stack Trace — platform-aware
  // ------------------------------------------------------------------

  /// Extracts a readable method name from the stack trace.
  /// Falls back gracefully on web where frames are JS-compiled.
  String _resolveMethodName() {
    if (kIsWeb) {
      // Web stack frames are JS-compiled and unreliable — skip extraction
      return 'web';
    }
    return _nativeMethodName(frameIndex: 3);
  }

  /// Parses a native (VM) stack frame to extract `ClassName.methodName`.
  ///
  /// Frame index 3 skips: [0] _nativeMethodName, [1] _resolveMethodName,
  /// [2] write, [3] = your actual caller.
  String _nativeMethodName({int frameIndex = 3}) {
    try {
      final frames = StackTrace.current.toString().split('\n');
      if (frames.length <= frameIndex) return 'unknown';

      final frame = frames[frameIndex].trim();

      // Native Dart VM format:
      // "#3      ClassName.methodName (package:app/file.dart:42:5)"
      final vmRegex = RegExp(r'#\d+\s+([\w.<>]+)\s+\(');
      final vmMatch = vmRegex.firstMatch(frame);
      if (vmMatch != null) {
        final full = vmMatch.group(1)!; // e.g. "AuthService.login"
        // Strip leading "new " for constructors, trim noise
        return full.replaceFirst(RegExp(r'^new\s+'), '');
      }

      return 'unknown';
    } catch (_) {
      return 'unknown';
    }
  }

  // ------------------------------------------------------------------
  // helpers, JSON, color, list methods unchanged below ...
  // ------------------------------------------------------------------

  String _two(int n) => n.toString().padLeft(2, '0');

  void logJson(dynamic jsonObject) {
    if (!kDebugMode) return;
    try {
      String prettyString;
      if (jsonObject is String) {
        final decoded = jsonDecode(jsonObject);
        prettyString = const JsonEncoder.withIndent('  ').convert(decoded);
      } else {
        prettyString = const JsonEncoder.withIndent('  ').convert(jsonObject);
      }
      log(prettyString, name: title);
    } catch (e) {
      log('Failed to pretty print JSON: $e', name: title);
    }
  }

  void logJsonList(List<dynamic> jsonList) {
    if (!kDebugMode) return;
    try {
      log(const JsonEncoder.withIndent('  ').convert(jsonList), name: title);
    } catch (e) {
      log('Failed to pretty print JSON list: $e', name: title);
    }
  }

  void logPrettyList<T>(List<T> list, {String? label}) {
    if (!kDebugMode) return;
    try {
      final prettyString = const JsonEncoder.withIndent('  ').convert(list);
      final header = label != null ? '[$label]\n' : '';
      log('$header$prettyString', name: title);
    } catch (e) {
      log('Failed to pretty print list: $e', name: title);
    }
  }

  T logExecutionTime<T>(String message, T Function() func) {
    final stopwatch = Stopwatch()..start();
    final result = func();
    stopwatch.stop();
    write(
      message: "$message executed in ${stopwatch.elapsedMilliseconds} ms",
      level: LogLevel.debug,
    );
    return result;
  }

  void logWithColor(String message, {String color = '32'}) {
    if (!kDebugMode) return;
    log(_colorize("$title : $message", color));
  }

  String _colorize(String message, String colorCode) =>
      "\x1B[${colorCode}m$message\x1B[0m";

  String _getColorForLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return LogColor.green.code;
      case LogLevel.info:
        return LogColor.blue.code;
      case LogLevel.warning:
        return LogColor.yellow.code;
      case LogLevel.error:
        return LogColor.red.code;
    }
  }

  LogLevel getAppMode() {
    if (kDebugMode) return LogLevel.debug;
    if (kProfileMode) return LogLevel.info;
    if (kReleaseMode) return LogLevel.error;
    return LogLevel.warning;
  }

  // ------------------------------------------------------------------
  // 🔒 Sensitive Data Redaction Engine
  // ------------------------------------------------------------------

  static final List<RegExp> _redactionRules = [
    // 1. Bearer / Authorization tokens
    RegExp(
        r'(?:bearer|auth|token|password|secret)["\s:][=\s"]*([a-zA-Z0-9_\-\.\~\+\/]+=*)',
        caseSensitive: false),
    // 2. Email Addresses
    RegExp(r'[a-zA-Z0-9.!#$%&'
        r'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*'),
    // 3. Credit Cards (Visa, Mastercard, Amex, Discover structural matches)
    RegExp(
        r'\b(?:4[0-9]{12}(?:[0-9]{3})?|[5S][1-5][0-9]{14}|6(?:011|5[0-9][0-9])[0-9]{12}|3[47][0-9]{13}|3(?:0[0-5]|[68][0-9])[0-9]{11}|(?:2131|1800|35\d{3})\d{11})\b'),
  ];

  String _redactSensitiveData(String source) {
    if (source.isEmpty) return source;
    String cleaned = source;

    for (final rule in _redactionRules) {
      cleaned = cleaned.replaceAllMapped(rule, (match) {
        final fullMatch = match.group(0)!;
        // If the match captures a specific secret group value (like group 1 in auth tokens), redact only that group
        if (match.groupCount >= 1 && match.group(1) != null) {
          final secret = match.group(1)!;
          if (secret.trim().isNotEmpty) {
            return fullMatch.replaceFirst(secret, '[REDACTED]');
          }
        }
        // Otherwise, replace the entire structured match value (like emails/cards)
        return '[REDACTED]';
      });
    }
    return cleaned;
  }

  Future<T> logExecutionTimeAsync<T>(
    String message,
    Future<T> Function() func,
  ) async {
    final stopwatch = Stopwatch()..start();
    final result = await func();
    stopwatch.stop();
    write(
      message: "$message executed in ${stopwatch.elapsedMilliseconds} ms",
      level: LogLevel.debug,
    );
    return result;
  }

  void logError(dynamic error, StackTrace stackTrace, {String? message}) {
    write(
      message: message ?? 'Exception: $error\n$stackTrace',
      level: LogLevel.error,
    );
  }

  void logIf(
    bool condition, {
    required String message,
    required LogLevel level,
  }) {
    if (condition) write(message: message, level: level);
  }
}
