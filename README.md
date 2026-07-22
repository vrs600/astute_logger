# 🚀 Astute Logger

A lightweight, configurable logging package for Flutter with support for colored console output, persistent file logging, contextual logging, execution time measurement, and automatic sensitive data redaction.

## ✨ Features

- 📝 Multiple log levels
  - 🟢 Debug
  - 🔵 Info
  - 🟡 Warning
  - 🔴 Error
  - 🟣 Critical
- 🎨 Colored console logs
- 📂 Persistent file logging
- ⚙️ Configurable logger settings
- 📍 Automatic caller method detection
- 🌐 Context-aware logging using Zones
- 🆔 Request ID propagation
- 🏷️ Additional contextual metadata
- 📄 Pretty JSON logging
- 🔒 Sensitive data redaction
  - 🔑 Authorization tokens
  - 🔐 Passwords & secrets
  - 📧 Email addresses
  - 💳 Credit card numbers
- ⏱️ Execution time measurement
- 🚨 Error & stack trace logging
- 📱 Cross-platform Flutter support

---

## 📦 Installation

Add the package to your `pubspec.yaml`.

```yaml
dependencies:
  astute_logger: ^0.1.0
```

Install it:

```bash
flutter pub get
```

---

## 📥 Import

```dart
import 'package:astute_logger/astute_logger.dart';
```

---

## 🏗️ Create a Logger

```dart
final logger = AstuteLogger(
  'AppLogger',
  config: const LogConfig(
    enableConsoleOutput: true,
    enableFileOutput: true,
    enableColorLogging: true,
    enableRedaction: true,
    minimumLogLevel: LogLevel.debug,
  ),
);
```

---

# 📖 Examples

## 🟢 Debug

```dart
logger.debug("Debug message");
```

## 🔵 Info

```dart
logger.info("Application started");
```

## 🟡 Warning

```dart
logger.warning("API response is slow");
```

## 🔴 Error

```dart
logger.error(
  "Unable to load profile",
  error: Exception("HTTP 500"),
);
```

## 🟣 Critical

```dart
logger.critical(
  "Database connection lost",
  error: Exception("SocketException"),
  stackTrace: StackTrace.current,
);
```

---

## 🏷️ Logging with Metadata

```dart
logger.info(
  "User logged in",
  extra: {
    "userId": 123,
    "role": "Admin",
  },
);
```

---

## 🌐 Context-Aware Logging

```dart
LoggerContext.runWithContext(
  requestId: "REQ-1001",
  extra: {
    "screen": "Home",
    "feature": "Login",
  },
  body: () {
    logger.info("Inside contextual logging");
  },
);
```

---

## ⏱️ Measure Execution Time

### Synchronous

```dart
logger.logExecutionTime(
  "Sorting List",
  () {
    final list = List.generate(100000, (i) => 100000 - i);
    list.sort();
  },
);
```

### Asynchronous

```dart
await logger.logExecutionTimeAsync(
  "API Request",
  () async {
    await Future.delayed(const Duration(seconds: 2));
  },
);
```

---

## 📄 Pretty JSON Logging

```dart
logger.write(
  message: jsonEncode({
    "name": "John",
    "age": 25,
    "roles": ["Admin", "User"]
  }),
  prettyPrint: true,
  level: LogLevel.info,
);
```

---

## 🔒 Automatic Sensitive Data Redaction

Input:

```text
Email: john.doe@gmail.com
Bearer abcdefghijklmnopqrstuvwxyz
password=mySecretPassword
Card: 4111111111111111
```

Output:

```text
Email: [REDACTED]
Bearer [REDACTED]
password=[REDACTED]
Card: [REDACTED]
```

---

## 📂 Read Log File

```dart
final file = await AstuteLogger.getLogFile();

if (file != null && await file.exists()) {
  final logs = await file.readAsString();
  print(logs);
}
```

---

## ⚙️ Configuration

```dart
const LogConfig(
  enableConsoleOutput: true,
  enableFileOutput: true,
  enableColorLogging: true,
  enableRedaction: true,
  minimumLogLevel: LogLevel.debug,
  logFileName: 'app_logs.txt',
)
```

---

## ❤️ License

MIT License.