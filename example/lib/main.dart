import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:astute_logger/astute_logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final logger = AstuteLogger(
    'AstuteLoggerDemo',
    config: const LogConfig(
      enableConsoleOutput: true,
      enableFileOutput: true,
      enableColorLogging: true,
      enableRedaction: true,
      minimumLogLevel: LogLevel.debug,
    ),
  );

  logger.debug("Debug log");

  logger.info(
    "Application started",
    extra: {"version": "3.0.0", "platform": "Android"},
  );

  logger.warning("Battery level is low", extra: {"battery": "15%"});

  logger.error("Unable to fetch profile", error: Exception("HTTP 500"));

  logger.critical(
    "Database connection lost",
    error: Exception("SocketException"),
    stackTrace: StackTrace.current,
  );

  LoggerContext.runWithContext(
    requestId: "REQ-20260722-001",
    extra: {"userId": 123, "screen": "Home", "feature": "Login"},
    body: () {
      logger.info("This log uses LoggerContext");
    },
  );

  logger.info("""
Email : john.doe@gmail.com

Bearer abcdefghijklmnopqrstuvwxyz123456789

password=mySuperSecretPassword

Credit Card : 4111111111111111
""");

  logger.logExecutionTime("Sorting List", () {
    final list = List.generate(200000, (i) => 200000 - i);
    list.sort();
  });

  await logger.logExecutionTimeAsync("Fake API Call", () async {
    await Future.delayed(const Duration(seconds: 2));
  });

  final json = jsonEncode({
    "user": {
      "id": 1,
      "name": "John",
      "roles": ["Admin", "Manager"],
    },
    "permissions": ["read", "write", "delete"],
  });

  logger.write(message: json, prettyPrint: true, level: LogLevel.info);

  try {
    throw Exception("Something went terribly wrong.");
  } catch (e, stackTrace) {
    logger.error("Caught exception", error: e, stackTrace: stackTrace);
  }

  final logFile = await AstuteLogger.getLogFile();

  if (logFile != null && await logFile.exists()) {
    logger.info("Log file location: ${logFile.path}");

    final content = await logFile.readAsString();

    logger.info("Log file contains ${content.length} characters.");
  }

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(child: Text('Check your console and log file')),
      ),
    ),
  );
}
