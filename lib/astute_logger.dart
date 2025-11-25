import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';

/// Enum representing different levels of log severity.
enum LogLevel { debug, info, warning, error }

/// Enum representing ANSI terminal colors for log output.
enum LogColor {
  green('32'),
  blue('34'),
  yellow('33'),
  red('31');

  final String code;
  const LogColor(this.code);
}

/// A simple yet powerful logger utility for Flutter apps.
///
/// Supports:
/// - Automatic timestamps and method names
/// - Color-coded log levels
/// - Pretty-printing of JSON and lists
/// - Execution time measurement
///
/// Usage:
/// ```dart
/// final log = Logger("AuthService");
/// log.write(message: "User signed in", level: LogLevel.info);
/// ```
class Logger {
  final String title;

  Logger(this.title);

  // ------------------------------------------------------------------
  // 🟩 Basic log message
  // ------------------------------------------------------------------

  /// Logs a message with optional pretty-printing and color coding.
  ///
  /// [message] - The message to log.
  /// [prettyPrint] - If true, tries to format the message as JSON.
  /// [level] - The [LogLevel] used to determine severity and color.
  void write({
    required String message,
    bool prettyPrint = false,
    required LogLevel level,
  }) {
    if (kReleaseMode) return;

    String method = currentMethodName(2);

    final now = DateTime.now();
    final localTimestamp = "${now.day}-${_two(now.month)}-${_two(now.year)} "
        "${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}";

    String logText =
        "[$localTimestamp] [${getAppMode()}] $title::$method -> $message";

    // 🎨 Apply color based on log level
    logText = _colorize(logText, _getColorForLevel(level));

    if (prettyPrint) {
      logJson(logText);
    } else {
      log(logText);
    }
  }

  /// Pads numbers less than 10 with a leading zero.
  String _two(int n) => n.toString().padLeft(2, '0');

  // ------------------------------------------------------------------
  // 🟦 JSON Pretty Printing
  // ------------------------------------------------------------------

  /// Pretty prints a JSON object or string to the console.
  ///
  /// Automatically detects if [jsonObject] is a string or map/list.
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

  // ------------------------------------------------------------------
  // 🟨 Stack Trace Utilities
  // ------------------------------------------------------------------

  /// Extracts the current method name from the stack trace.
  ///
  /// [frameIndex] specifies how many frames to go up in the stack.
  String currentMethodName([int frameIndex = 1]) {
    final stack = StackTrace.current.toString().split('\n');
    if (stack.length <= frameIndex) return 'unknown';
    final regex = RegExp(r'#\d+\s+([^(]+)');
    return regex.firstMatch(stack[frameIndex])?.group(1) ?? 'unknown';
  }

  // ------------------------------------------------------------------
  // 🟥 Performance Measurement
  // ------------------------------------------------------------------

  /// Measures and logs the execution time of a synchronous function.
  ///
  /// Example:
  /// ```dart
  /// log.logExecutionTime("Compute sum", () {
  ///   return list.reduce((a, b) => a + b);
  /// });
  /// ```
  T logExecutionTime<T>(String message, T Function() func) {
    final stopwatch = Stopwatch()..start();
    final result = func();
    stopwatch.stop();
    write(
        message: "$message executed in ${stopwatch.elapsedMilliseconds} ms",
        level: LogLevel.debug);
    return result;
  }

  // ------------------------------------------------------------------
  // 🧩 Color Handling
  // ------------------------------------------------------------------

  /// Wraps a message in ANSI color escape codes.
  String _colorize(String message, String colorCode) =>
      "\x1B[${colorCode}m$message\x1B[0m";

  /// Logs a message with a specific color.
  ///
  /// Example:
  /// ```dart
  /// log.logWithColor("Success", color: LogColor.green.code);
  /// ```
  void logWithColor(String message, {String color = '32'}) {
    if (!kDebugMode) return;
    log(_colorize("$title : $message", color));
  }

  /// Returns the ANSI color code corresponding to a [LogLevel].
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

  // ------------------------------------------------------------------
  // 🧾 List Logging
  // ------------------------------------------------------------------

  /// Pretty prints a list of JSON objects.
  void logJsonList(List<dynamic> jsonList) {
    if (!kDebugMode) return;

    try {
      String prettyString =
      const JsonEncoder.withIndent('  ').convert(jsonList);
      log(prettyString, name: title);
    } catch (e) {
      log('Failed to pretty print JSON list: $e', name: title);
    }
  }

  /// Pretty prints a generic list in formatted JSON style.
  ///
  /// [label] can be provided to display a title before the list.
  void logPrettyList<T>(List<T> list, {String? label}) {
    if (!kDebugMode) return;

    try {
      final prettyString = const JsonEncoder.withIndent('  ').convert(list);
      final header = label != null ? '[$label]' : '';
      log('$header\n$prettyString', name: title);
    } catch (e) {
      log('Failed to pretty print list: $e', name: title);
    }
  }

  // ------------------------------------------------------------------
  // 🧠 Environment Detection
  // ------------------------------------------------------------------

  /// Returns the current [LogLevel] based on Flutter build mode.
  ///
  /// - `debug` → Debug mode
  /// - `info` → Profile mode
  /// - `error` → Release mode
  LogLevel getAppMode() {
    if (kDebugMode) {
      return LogLevel.debug;
    } else if (kProfileMode) {
      return LogLevel.info;
    } else if (kReleaseMode) {
      return LogLevel.error;
    } else {
      return LogLevel.warning; // fallback
    }
  }
}
