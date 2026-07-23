import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Represents the severity level of a log message.
enum LogLevel { debug, info, warning, error, critical }

/// Defines ANSI color codes for terminal logging.
enum LogColor {
  green('32'),
  blue('34'),
  yellow('33'),
  red('31'),
  magenta('35');

  final String code;
  const LogColor(this.code);
}

/// Internal class representing a log event to be processed.
class _LogEvent {
  final AstuteLogger logger;
  final String text;
  final bool prettyPrint;

  const _LogEvent({
    required this.logger,
    required this.text,
    required this.prettyPrint,
  });
}

/// Provides utilities for managing logging context across asynchronous operations.
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

/// Configuration for the logger, including output settings and redaction rules.
class LogConfig {
  final bool enableRedaction;
  final LogLevel minimumLogLevel;
  final bool enableConsoleOutput;
  final bool enableFileOutput;
  final String logFileName;
  final bool enableColorLogging;

  const LogConfig({
    this.enableRedaction = true,
    this.minimumLogLevel = LogLevel.debug,
    this.enableConsoleOutput = true,
    this.enableFileOutput = true,
    this.logFileName = 'app_logs.txt',
    this.enableColorLogging = true,
  });
}

/// A powerful and flexible logging utility for Flutter applications.
/// Supports console and file logging, redaction of sensitive data, and contextual metadata.
class AstuteLogger {
  final String title;
  final LogConfig config;

  AstuteLogger(
    this.title, {
    this.config = const LogConfig(),
  });
  // ------------------------------------------------------------------
  // 📥 Async Logging Queue Pipeline
  // ------------------------------------------------------------------
  static final StreamController<_LogEvent> _queueController =
      StreamController<_LogEvent>()..stream.listen(_processLogQueue);

  static final Map<String, File> _logFilesCache = {};

  /// Dynamic access utility method to retrieve the raw file containing persisted logs by name
  static Future<File?> getLogFile({String fileName = 'app_logs.txt'}) async {
    try {
      if (_logFilesCache.containsKey(fileName)) return _logFilesCache[fileName];
      final directory = await getApplicationDocumentsDirectory();
      return File('${directory.path}/$fileName');
    } catch (_) {
      return null;
    }
  }

  /// Writes a log message with the specified level and optional metadata.
  void write({
    required String message,
    bool prettyPrint = false,
    required LogLevel level,
    Map<String, dynamic>? extra,
  }) {
    if (kReleaseMode) return;
    if (level.index < config.minimumLogLevel.index) return;

    final scrubbedMessage =
        config.enableRedaction ? _redactSensitiveData(message) : message;

    final methodLabel = _resolveMethodName();

    final Map<String, dynamic> combinedContext = {};
    if (extra != null) {
      combinedContext.addAll(extra);
    }

    final zoneRequestId = Zone.current[LoggerContext.requestId] as String?;
    final zoneExtra =
        Zone.current[LoggerContext.extraContext] as Map<String, dynamic>?;
    if (zoneExtra != null) {
      combinedContext.addAll(zoneExtra);
    }

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
    final localTimestamp = "${now.day}-${_two(now.month)}-${now.year} "
        "${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}";

    String logText =
        "[log] [$localTimestamp] [${getAppMode().name.toUpperCase()}] $contextTag$methodLabel -> $scrubbedMessage";

    if (config.enableColorLogging) {
      logText = _colorize(logText, _getColorForLevel(level));
    }

    _queueController.add(_LogEvent(
      logger: this,
      text: logText,
      prettyPrint: prettyPrint,
    ));
  }

  /// Processes log events asynchronously, handling console and file output.
  static Future<void> _processLogQueue(_LogEvent event) async {
    final config = event.logger.config;

    // Format JSON separately if prettyPrint
    String outputText = event.text;
    if (event.prettyPrint) {
      try {
        final decoded = jsonDecode(event.text);
        outputText = const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {
        // If decoding fails, use original text
      }
    }

    if (config.enableConsoleOutput) {
      log(outputText, name: event.logger.title);
    }

    if (!config.enableFileOutput) return;
    try {
      final fileName = config.logFileName;
      if (!_logFilesCache.containsKey(fileName)) {
        final directory = await getApplicationDocumentsDirectory();
        _logFilesCache[fileName] = File('${directory.path}/$fileName');
      }
      final file = _logFilesCache[fileName]!;
      final cleanText = outputText.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
      await file.writeAsString(
        '$cleanText\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      log('Failed to write log to persistent file storage: $e',
          name: 'LoggerError');
    }
  }

  // ------------------------------------------------------------------
  // 🟨 Stack Trace — platform-aware
  // ------------------------------------------------------------------

  /// Extracts a readable method name from the stack trace.
  /// Falls back gracefully on web where frames are JS-compiled.
  String _resolveMethodName() {
    if (kIsWeb) return 'web';

    // Look deeper into the stack trace to find the framework frame bypass
    return _nativeMethodName();
  }

  /// Parses a native (VM) stack frame to extract `ClassName.methodName`.
  ///
  /// Frame index 3 skips: [0] _nativeMethodName, [1] _resolveMethodName,
  /// [2] write, [3] = your actual caller.
  String _nativeMethodName() {
    try {
      final frames = StackTrace.current.toString().split('\n');

      // Iterate past framework internals to discover true business logic caller
      for (final frame in frames) {
        if (frame.isEmpty) continue;

        final vmRegex = RegExp(r'#\d+\s+([\w.<>]+)\s+\(');
        final vmMatch = vmRegex.firstMatch(frame);

        if (vmMatch != null) {
          final full = vmMatch.group(1)!;

          // Skip internal logger framework wrappers dynamically
          if (full.contains('AstuteLogger.') ||
              full.contains('_resolveMethodName') ||
              full.contains('_nativeMethodName')) {
            continue;
          }

          return full.replaceFirst(RegExp(r'^new\s+'), '');
        }
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

  /// Measures and logs the execution time of a synchronous function.
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

  /// Applies ANSI color codes to the log message for terminal output.
  String _colorize(String message, String colorCode) =>
      "\x1B[${colorCode}m$message\x1B[0m";

  /// Returns the appropriate color code for the given log level.
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
      case LogLevel.critical:
        return LogColor.magenta.code;
    }
  }

  /// Determines the current application mode (debug, profile, release).
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

  /// Redacts sensitive data from log messages using predefined rules.
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

  /// Measures and logs the execution time of an asynchronous function.
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

  /// Logs a debug-level message.
  void debug(String message, {Map<String, dynamic>? extra}) {
    write(message: message, level: LogLevel.debug, extra: extra);
  }

  /// Logs an info-level message.
  void info(String message, {Map<String, dynamic>? extra}) {
    write(message: message, level: LogLevel.info, extra: extra);
  }

  /// Logs a warning-level message.
  void warning(String message, {Map<String, dynamic>? extra}) {
    write(message: message, level: LogLevel.warning, extra: extra);
  }

  /// Logs an error-level message, optionally including an error and stack trace.
  void error(String message,
      {Map<String, dynamic>? extra, Object? error, StackTrace? stackTrace}) {
    final combinedMessage = StringBuffer(message);
    if (error != null) {
      combinedMessage.write('\nError: $error');
    }
    if (stackTrace != null) {
      combinedMessage.write('\nStackTrace:\n$stackTrace');
    }
    write(
        message: combinedMessage.toString(),
        level: LogLevel.error,
        extra: extra);
  }

  /// Logs a critical-level message, optionally including an error and stack trace.
  void critical(String message,
      {Map<String, dynamic>? extra, Object? error, StackTrace? stackTrace}) {
    final combinedMessage = StringBuffer(message);
    if (error != null) {
      combinedMessage.write('\nError: $error');
    }
    if (stackTrace != null) {
      combinedMessage.write('\nStackTrace:\n$stackTrace');
    }
    write(
        message: combinedMessage.toString(),
        level: LogLevel.critical,
        extra: extra);
  }
}
