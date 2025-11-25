import 'package:astute_logger/astute_logger.dart';

void main() {
  final log = Logger("ExampleService");

  // 🔵 Basic message
  log.write(message: "App started", level: LogLevel.info);

  // 🟢 Debug message
  log.write(message: "Fetching user...", level: LogLevel.debug);

  // 🟡 Warning
  log.write(message: "Low internet connection", level: LogLevel.warning);

  // 🔴 Error
  log.write(message: "Failed to load data", level: LogLevel.error);

  // 🎨 Log with color
  log.logWithColor("Custom colored success log", color: LogColor.green.code);

  // 🧾 Pretty JSON
  log.logJson({
    "id": 1,
    "name": "John",
    "role": "admin",
  });

  // 🧾 Pretty JSON string
  log.write(
    message: '{"status": "ok", "items": [1,2,3]}',
    prettyPrint: true,
    level: LogLevel.info,
  );

  // 📋 Pretty List
  log.logPrettyList(["Apple", "Banana", "Orange"], label: "Fruits");

  // ⏱ Execution time measurement
  log.logExecutionTime("Compute sum", () {
    final list = List.generate(5000, (i) => i);
    return list.reduce((a, b) => a + b);
  });
}
