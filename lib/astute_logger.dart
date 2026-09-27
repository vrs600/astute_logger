import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Represents the severity level of a log message.
enum LogLevel { debug, info, warning, error, critical }

/// Represents the current Flutter application mode.
enum AppMode { debug, profile, release, unknown }

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
  final Object? rawMessage;
  final String messageBody;
  final bool prettyPrint;

  const _LogEvent({
    required this.logger,
    required this.text,
    required this.rawMessage,
    required this.messageBody,
    required this.prettyPrint,
  });
}

class _QueuedLogEvent {
  final _LogEvent event;
  final Completer<void> completion = Completer<void>();

  _QueuedLogEvent(this.event);
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

  /// Whether email addresses are redacted. Disabling this can improve
  /// observability during debugging, but may expose personally identifiable
  /// information in logs.
  final bool redactEmails;

  const LogConfig({
    this.enableRedaction = true,
    this.minimumLogLevel = LogLevel.debug,
    this.enableConsoleOutput = true,
    this.enableFileOutput = true,
    this.logFileName = 'app_logs.txt',
    this.enableColorLogging = true,
    this.redactEmails = true,
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
  static const int _maxPendingLogEvents = 1024;
  static final Queue<_QueuedLogEvent> _logQueue = Queue<_QueuedLogEvent>();
  static final Queue<Completer<void>> _queueSlotWaiters =
      Queue<Completer<void>>();
  static int _availableQueueSlots = _maxPendingLogEvents;
  static bool _isProcessingLogQueue = false;

  static final Map<String, File> _logFilesCache = {};

  /// Dynamic access utility method to retrieve the raw file containing persisted logs by name
  /// The cache avoids repeated platform-channel calls and keeps a stable File identity per path.
  static Future<File?> getLogFile({String fileName = 'app_logs.txt'}) async {
    try {
      final cached = _logFilesCache[fileName];
      if (cached != null) return cached;
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      _logFilesCache[fileName] = file;
      return file;
    } catch (_) {
      return null;
    }
  }

  /// Retrieves log lines that contain the specified tag from an existing file.
  ///
  /// Reads the log file, filters lines containing [tag] in the format [TAG],
  /// strips ANSI color codes, and returns the matching log lines.
  /// This is a static utility and is not tied to any logger instance's config.
  ///
  /// Parameters:
  ///   - tag: The tag to filter logs by (case-insensitive)
  ///   - fileName: The existing log file to read
  ///
  /// Returns a Future containing a list of matching log lines with ANSI codes removed.
  static Future<List<String>> getLogsByTag(
    String tag, {
    String fileName = 'app_logs.txt',
  }) async {
    try {
      final logFile = await getLogFile(fileName: fileName);
      if (logFile == null || !(await logFile.exists())) {
        return [];
      }

      // Read the log file content
      final content = await logFile.readAsString();
      if (content.isEmpty) {
        return [];
      }

      // Normalize the tag for case-insensitive matching
      final tagPattern = RegExp(r'\[' + tag.trim().toUpperCase() + r'\]');

      // Split into lines and filter matching lines
      final matchingLines = content
          .split('\n')
          .where((line) => tagPattern.hasMatch(line))
          .map((line) => _stripAnsiCodes(line))
          .where((line) => line.trim().isNotEmpty)
          .toList();

      return matchingLines;
    } catch (e) {
      log('Failed to read logs by tag: $e', name: 'LoggerError');
      return [];
    }
  }

  /// Strips ANSI color codes from a string.
  ///
  /// Removes all ANSI escape sequences that are used for terminal coloring.
  static String _stripAnsiCodes(String text) {
    return text.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '');
  }

  /// Writes a log message with the specified level and optional metadata.
  Future<void> write({
    required String message,
    bool prettyPrint = false,
    required LogLevel level,
    Map<String, dynamic>? extra,
    String? tag,
  }) {
    if (kReleaseMode) return Future<void>.value();

    final tagText =
        tag != null && tag.trim().isNotEmpty ? '[${tag.toUpperCase()}] ' : '';

    if (level.index < config.minimumLogLevel.index) {
      return Future<void>.value();
    }

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
        "[log] [$localTimestamp] [${appMode.name.toUpperCase()}] $tagText$contextTag$methodLabel -> $scrubbedMessage";

    if (config.enableColorLogging) {
      logText = _colorize(logText, _getColorForLevel(level));
    }

    return _enqueueLogEvent(_LogEvent(
      logger: this,
      text: logText,
      rawMessage: message,
      messageBody: scrubbedMessage,
      prettyPrint: prettyPrint,
    ));
  }

  static Future<void> _enqueueLogEvent(_LogEvent event) async {
    if (_availableQueueSlots == 0) {
      final slotAvailable = Completer<void>();
      _queueSlotWaiters.add(slotAvailable);
      await slotAvailable.future;
    } else {
      _availableQueueSlots--;
    }

    final queuedEvent = _QueuedLogEvent(event);
    _logQueue.add(queuedEvent);
    _startLogQueueWorker();
    await queuedEvent.completion.future;
  }

  static void _startLogQueueWorker() {
    if (_isProcessingLogQueue) return;
    _isProcessingLogQueue = true;
    unawaited(_drainLogQueue());
  }

  static Future<void> _drainLogQueue() async {
    while (_logQueue.isNotEmpty) {
      final queuedEvent = _logQueue.first;
      try {
        await _processLogQueue(queuedEvent.event);
        queuedEvent.completion.complete();
      } catch (error, stackTrace) {
        queuedEvent.completion.completeError(error, stackTrace);
      } finally {
        _logQueue.removeFirst();
        if (_queueSlotWaiters.isNotEmpty) {
          _queueSlotWaiters.removeFirst().complete();
        } else {
          _availableQueueSlots++;
        }
      }
    }
    _isProcessingLogQueue = false;
  }

  @visibleForTesting
  static Future<void> flush() async {
    while (_isProcessingLogQueue || _logQueue.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  }

  @visibleForTesting
  static void resetFileCache() {
    _logFilesCache.clear();
  }

  /// Processes log events asynchronously, handling console and file output.
  static Future<void> _processLogQueue(_LogEvent event) async {
    final config = event.logger.config;

    String outputText = event.text;
    if (event.prettyPrint) {
      final decoded = _tryDecodeJson(event.rawMessage);
      if (decoded != null) {
        final redacted = config.enableRedaction
            ? event.logger._redactObject(decoded)
            : decoded;
        final prettyMessage =
            const JsonEncoder.withIndent('  ').convert(redacted);
        const colorReset = '\x1B[0m';
        final hasColorReset = outputText.endsWith(colorReset);
        final messageEnd = hasColorReset
            ? outputText.length - colorReset.length
            : outputText.length;
        final messageStart = messageEnd - event.messageBody.length;
        if (messageStart >= 0 &&
            outputText.substring(messageStart, messageEnd) ==
                event.messageBody) {
          outputText = outputText.substring(0, messageStart) +
              prettyMessage +
              outputText.substring(messageEnd);
        }
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
      await _appendToFile(file, '$cleanText\n');
    } catch (e) {
      log('Failed to write log to persistent file storage: $e',
          name: 'LoggerError');
    }
  }

  static Future<void> _appendToFile(File file, String text) async {
    final sink = file.openWrite(mode: FileMode.append);
    try {
      sink.write(text);
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  static Object? _tryDecodeJson(Object? value) {
    if (value == null) return null;
    if (value is Map || value is List) return value;
    if (value is String) {
      try {
        return jsonDecode(value);
      } catch (_) {
        return null;
      }
    }
    return null;
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
  /// Examples: `#0 Foo.bar (package:app/foo.dart:10:5)` -> `Foo.bar`;
  /// `#1 Foo.bar$closure` -> `Foo.bar$closure`.
  String _nativeMethodName() {
    try {
      final frames = StackTrace.current.toString().split('\n');

      // Find the first frame outside the logger implementation.
      for (final frame in frames) {
        if (frame.isEmpty) continue;

        final vmRegex = RegExp(r'#\d+\s+([\w.<>$]+)\s+\(');
        final fallbackRegex = RegExp(r'#\d+\s+([\w.<>$]+)');
        final vmMatch =
            vmRegex.firstMatch(frame) ?? fallbackRegex.firstMatch(frame);

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
    late final T result;
    try {
      result = func();
    } finally {
      // Stop and log even when the measured function throws.
      stopwatch.stop();
      write(
        message: "$message executed in ${stopwatch.elapsedMilliseconds} ms",
        level: LogLevel.debug,
      );
    }
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

  /// Determines the current application mode.
  AppMode get appMode {
    if (kDebugMode) return AppMode.debug;
    if (kProfileMode) return AppMode.profile;
    if (kReleaseMode) return AppMode.release;
    return AppMode.unknown;
  }

  // ------------------------------------------------------------------
  // 🔒 Sensitive Data Redaction Engine
  // ------------------------------------------------------------------

  static final Set<String> _sensitiveKeys = {
    "password",
    "token",
    "accesstoken",
    "refreshtoken",
    "authorization",
    "apikey",
    "secret",
    "email",
  };

  static void registerSensitiveKey(String key) {
    _sensitiveKeys.add(key.toLowerCase());
  }

  static void unregisterSensitiveKey(String key) {
    _sensitiveKeys.remove(key.toLowerCase());
  }

  static List<String> getSensitiveKeys() {
    return _sensitiveKeys.toList()..sort();
  }

  /// Redacts sensitive values in nested maps and lists.
  Object? redactObject(Object? value) => _redactObject(value);

  dynamic _redactObject(dynamic value) {
    if (value is Map) {
      return value.map((key, val) {
        final lowerKey = key.toString().toLowerCase();

        if (_sensitiveKeys.contains(lowerKey)) {
          return MapEntry(key, "[REDACTED]");
        }

        return MapEntry(key, _redactObject(val));
      });
    }

    if (value is List) {
      return value.map(_redactObject).toList();
    }

    return value;
  }

  Future<void> json(
    Object? object, {
    LogLevel level = LogLevel.debug,
    String? tag,
    Map<String, dynamic>? extra,
  }) {
    final cleaned = _redactObject(object);
    final decoded = _tryDecodeJson(jsonEncode(cleaned));
    final prettyMessage = const JsonEncoder.withIndent('  ').convert(decoded);

    return write(
      message: prettyMessage,
      level: level,
      prettyPrint: false,
      extra: extra,
      tag: tag,
    );
  }

  static final RegExp _emailRule = RegExp(
    r'[a-zA-Z0-9.!#$%&'
    r'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*',
  );

  static final RegExp _creditCardRule = RegExp(
      r'\b(?:4[0-9]{12}(?:[0-9]{3})?|[5S][1-5][0-9]{14}|6(?:011|5[0-9][0-9])[0-9]{12}|3[47][0-9]{13}|3(?:0[0-5]|[68][0-9])[0-9]{11}|(?:2131|1800|35\d{3})\d{11})\b');

  static final List<RegExp> _defaultRules = [
    // Input: '"password": "p@ss!"' -> '"password": "[REDACTED]"'
    RegExp(
      r"""(?:bearer|auth|token|password|secret|api[_-]?key)\s*[:=]\s*["']([^"']+)["']""",
      caseSensitive: false,
    ),
    // Input: 'Authorization: Bearer abc-123' -> 'Authorization: Bearer [REDACTED]'
    RegExp(
      r'Bearer\s+([A-Za-z0-9\-._~+/]+=*)',
      caseSensitive: false,
    ),
    // Input: 'token:abc-123, count: 5' -> 'token:[REDACTED], count: 5'
    RegExp(
      r'(?:token|password|secret)\s*[:=]\s*([^\s,;]+)',
      caseSensitive: false,
    ),
  ];

  /// Redacts sensitive data from log messages using predefined rules.
  String _redactSensitiveData(String source) {
    if (source.isEmpty) return source;
    String cleaned = source;

    if (config.redactEmails) {
      cleaned = cleaned.replaceAll(_emailRule, '[REDACTED]');
    }

    for (final rule in _defaultRules) {
      cleaned = cleaned.replaceAllMapped(rule, (match) {
        final fullMatch = match.group(0)!;
        // If the match captures a specific secret group value (like group 1 in auth tokens), redact only that group
        if (match.groupCount >= 1 && match.group(1) != null) {
          final secret = match.group(1)!;
          if (secret.trim().isNotEmpty) {
            final groupStart = fullMatch.lastIndexOf(secret);
            return fullMatch.replaceRange(
              groupStart,
              groupStart + secret.length,
              '[REDACTED]',
            );
          }
        }
        // Otherwise, replace the entire structured match value (like emails/cards)
        return '[REDACTED]';
      });
    }

    cleaned = cleaned.replaceAllMapped(_creditCardRule, (match) {
      if (!config.redactEmails &&
          _emailRule.allMatches(cleaned).any((emailMatch) =>
              emailMatch.start <= match.start && emailMatch.end >= match.end)) {
        return match.group(0)!;
      }
      return '[REDACTED]';
    });

    return cleaned;
  }

  /// Measures and logs the execution time of an asynchronous function.
  Future<T> logExecutionTimeAsync<T>(
    String message,
    Future<T> Function() func,
  ) async {
    final stopwatch = Stopwatch()..start();
    late final T result;
    try {
      result = await func();
    } finally {
      // Stop and log even when the measured function throws.
      stopwatch.stop();
      write(
        message: "$message executed in ${stopwatch.elapsedMilliseconds} ms",
        level: LogLevel.debug,
      );
    }
    return result;
  }

  /// Logs a debug-level message.
  Future<void> debug(
    String message, {
    Map<String, dynamic>? extra,
    String? tag,
  }) {
    return write(
      message: message,
      level: LogLevel.debug,
      extra: extra,
      tag: tag,
    );
  }

  /// Logs an info-level message.
  Future<void> info(
    String message, {
    Map<String, dynamic>? extra,
    String? tag,
  }) {
    return write(
      message: message,
      level: LogLevel.info,
      extra: extra,
      tag: tag,
    );
  }

  /// Logs a warning-level message.
  Future<void> warning(
    String message, {
    Map<String, dynamic>? extra,
    String? tag,
  }) {
    return write(
      message: message,
      level: LogLevel.warning,
      extra: extra,
      tag: tag,
    );
  }

  /// Logs an error-level message, optionally including an error and stack trace.
  Future<void> error(
    String message, {
    Map<String, dynamic>? extra,
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    final combinedMessage = StringBuffer(message);
    if (error != null) {
      combinedMessage.write('\nError: $error');
    }
    if (stackTrace != null) {
      combinedMessage.write('\nStackTrace:\n$stackTrace');
    }
    return write(
      message: combinedMessage.toString(),
      level: LogLevel.error,
      extra: extra,
      tag: tag,
    );
  }

  /// Logs a critical-level message, optionally including an error and stack trace.
  Future<void> critical(
    String message, {
    Map<String, dynamic>? extra,
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    final combinedMessage = StringBuffer(message);
    if (error != null) {
      combinedMessage.write('\nError: $error');
    }
    if (stackTrace != null) {
      combinedMessage.write('\nStackTrace:\n$stackTrace');
    }
    return write(
      message: combinedMessage.toString(),
      level: LogLevel.critical,
      extra: extra,
      tag: tag,
    );
  }
}
