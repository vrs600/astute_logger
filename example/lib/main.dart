import 'package:astute_logger/astute_logger.dart';

Future<void> main() async {
  final AstuteLogger log = AstuteLogger("ExampleService");

  // ============================================================
  // Basic Logging
  // ============================================================

  log.write(message: "Application started", level: LogLevel.info);

  log.write(message: "Fetching user profile...", level: LogLevel.debug);

  log.write(message: "Network connection is slow", level: LogLevel.warning);

  log.write(message: "Failed to fetch user details", level: LogLevel.error);

  // ============================================================
  // Colored Console Output
  // ============================================================

  log.logWithColor(
    "Operation completed successfully",
    color: LogColor.green.code,
  );

  // ============================================================
  // Pretty JSON
  // ============================================================

  log.logJson({
    "id": 1,
    "name": "John Doe",
    "role": "Administrator",
    "active": true,
  });

  // ============================================================
  // Pretty JSON List
  // ============================================================

  log.logJsonList([
    {"id": 1, "name": "Alice"},
    {"id": 2, "name": "Bob"},
  ]);

  // ============================================================
  // Pretty Dart List
  // ============================================================

  log.logPrettyList(["Apple", "Banana", "Orange"], label: "Fruits");

  // ============================================================
  // Pretty Print JSON String
  // ============================================================

  log.write(
    message: '{"status":"success","items":[1,2,3]}',
    level: LogLevel.info,
    prettyPrint: true,
  );

  // ============================================================
  // Extra Metadata
  // ============================================================

  log.write(
    message: "User login successful",
    level: LogLevel.info,
    extra: {"userId": "USR-1001", "device": "Android", "version": "1.0.0"},
  );

  // ============================================================
  // Automatic Sensitive Data Redaction
  // ============================================================

  log.write(
    message: "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9",
    level: LogLevel.debug,
  );

  log.write(message: "User email: john.doe@example.com", level: LogLevel.info);

  log.write(message: "Credit Card: 4532015112830366", level: LogLevel.warning);

  // ============================================================
  // Request Context
  // ============================================================

  await LoggerContext.runWithContext(
    requestId: "REQ-2026-0001",
    extra: {"userId": "USR-1001", "platform": "Android"},
    body: () {
      log.write(
        message: "Authenticated request received",
        level: LogLevel.info,
      );
    },
  );

  // ============================================================
  // Execution Time
  // ============================================================

  final result = log.logExecutionTime("Compute Sum", () {
    final list = List.generate(100000, (i) => i);
    return list.reduce((a, b) => a + b);
  });

  log.write(message: "Result = $result", level: LogLevel.info);

  // ============================================================
  // Persistent Log File
  // ============================================================

  final logFile = await AstuteLogger.getLogFile();

  if (logFile != null) {
    log.write(message: "Logs saved to: ${logFile.path}", level: LogLevel.info);
  }
}
