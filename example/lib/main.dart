import 'dart:async';

import 'package:astute_logger/astute_logger.dart';

Future<void> main() async {
  final logger = AstuteLogger("ExampleService");

  print("\n================ Astute Logger Demo ================\n");

  // ==========================================================
  // 1. Basic Logging
  // ==========================================================

  logger.write(
    message: "Application started successfully",
    level: LogLevel.info,
  );

  logger.write(
    message: "Loading user profile...",
    level: LogLevel.debug,
  );

  logger.write(
    message: "Slow internet connection detected",
    level: LogLevel.warning,
  );

  logger.write(
    message: "Unable to fetch latest data",
    level: LogLevel.error,
  );

  // ==========================================================
  // 2. Colored Console Output
  // ==========================================================

  logger.logWithColor(
    "Green success message",
    color: LogColor.green.code,
  );

  logger.logWithColor(
    "Blue informational message",
    color: LogColor.blue.code,
  );

  logger.logWithColor(
    "Yellow warning message",
    color: LogColor.yellow.code,
  );

  logger.logWithColor(
    "Red error message",
    color: LogColor.red.code,
  );

  // ==========================================================
  // 3. Pretty JSON
  // ==========================================================

  logger.logJson({
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "roles": ["Admin", "Manager"],
    "active": true,
  });

  // ==========================================================
  // 4. Pretty JSON String
  // ==========================================================

  logger.write(
    message: '''
{
  "status":"success",
  "items":[1,2,3],
  "message":"Everything works!"
}
''',
    prettyPrint: true,
    level: LogLevel.info,
  );

  // ==========================================================
  // 5. Pretty JSON List
  // ==========================================================

  logger.logJsonList([
    {"id": 1, "name": "Alice"},
    {"id": 2, "name": "Bob"},
    {"id": 3, "name": "Charlie"},
  ]);

  // ==========================================================
  // 6. Pretty List
  // ==========================================================

  logger.logPrettyList(
    ["Apple", "Banana", "Orange", "Mango"],
    label: "Fruits",
  );

  // ==========================================================
  // 7. Extra Metadata
  // ==========================================================

  logger.write(
    message: "User logged in",
    level: LogLevel.info,
    extra: {
      "userId": "USR-1001",
      "device": "Android",
      "version": "1.0.0",
    },
  );

  // ==========================================================
  // 8. Request Context
  // ==========================================================

  await LoggerContext.runWithContext(
    requestId: "REQ-2026-001",
    extra: {
      "tenant": "Acme Corp",
      "environment": "Development",
    },
    body: () {
      logger.write(
        message: "Processing authenticated request",
        level: LogLevel.info,
      );

      logger.write(
        message: "Loading customer profile",
        level: LogLevel.debug,
      );
    },
  );

  // ==========================================================
  // 9. Sensitive Data Redaction
  // ==========================================================

  logger.write(
    message:
    "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9",
    level: LogLevel.debug,
  );

  logger.write(
    message: "Customer email: john.doe@example.com",
    level: LogLevel.info,
  );

  logger.write(
    message: "Payment card: 4532015112830366",
    level: LogLevel.warning,
  );

  logger.write(
    message: "Password = mySuperSecretPassword",
    level: LogLevel.error,
  );

  // ==========================================================
  // 10. Synchronous Execution Time
  // ==========================================================

  final sum = logger.logExecutionTime(
    "Calculate Sum",
        () {
      final numbers = List.generate(100000, (i) => i);
      return numbers.reduce((a, b) => a + b);
    },
  );

  logger.write(
    message: "Sum = $sum",
    level: LogLevel.info,
  );

  // ==========================================================
  // 11. Asynchronous Execution Time
  // ==========================================================

  await logger.logExecutionTimeAsync(
    "Fake API Request",
        () async {
      await Future.delayed(const Duration(milliseconds: 800));
      return true;
    },
  );

  // ==========================================================
  // 12. Conditional Logging
  // ==========================================================

  const isPremiumUser = true;

  logger.logIf(
    isPremiumUser,
    message: "Premium feature unlocked",
    level: LogLevel.info,
  );

  // ==========================================================
  // 13. Exception Logging
  // ==========================================================

  try {
    throw Exception("Something went wrong!");
  } catch (e, stackTrace) {
    logger.logError(
      e,
      stackTrace,
      message: "Unexpected exception occurred",
    );
  }

  // ==========================================================
  // 14. Persistent Log File
  // ==========================================================

  final file = await AstuteLogger.getLogFile();

  if (file != null) {
    logger.write(
      message: "Logs are stored at: ${file.path}",
      level: LogLevel.info,
    );
  }

  print("\n=============== Demo Completed ===============");
}