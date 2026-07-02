# Astute Logger

[![pub package](https://img.shields.io/pub/v/astute_logger.svg)](https://pub.dev/packages/astute_logger)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A lightweight, production-ready logging package for Flutter applications that provides structured logging, persistent log storage, automatic sensitive data redaction, JSON formatting, execution time measurement, request context support, and colorful console output.

Designed to replace `print()` with a more powerful, secure, and maintainable logging solution.

---

## ✨ Features

* 🚀 Structured logging with multiple log levels
* 🕒 Automatic timestamps for every log
* 📁 Persistent log file storage
* 🔐 Automatic sensitive data redaction
* 🎨 ANSI colored console output
* 📦 Pretty JSON formatting
* 📋 Pretty list printing
* ⏱ Execution time measurement
* 🌐 Request/Zone context support
* ⚡ Release mode optimization
* 🌍 Unicode & Emoji support
* 🏗 Clean and developer-friendly API

---

## 📦 Installation

Add the package to your `pubspec.yaml`:

```yaml
dependencies:
  astute_logger: ^latest_version
```

Then run:

```bash
flutter pub get
```

Import the package:

```dart
import 'package:astute_logger/astute_logger.dart';
```

---

# 🚀 Quick Start

Create a logger instance.

```dart
final logger = Logger("AuthService");
```

Write logs.

```dart
logger.write(
  message: "User logged in successfully",
  level: LogLevel.info,
);
```

---

# 📊 Log Levels

### Debug

```dart
logger.write(
  message: "Fetching user profile",
  level: LogLevel.debug,
);
```

### Info

```dart
logger.write(
  message: "User authenticated",
  level: LogLevel.info,
);
```

### Warning

```dart
logger.write(
  message: "API response is taking longer than expected",
  level: LogLevel.warning,
);
```

### Error

```dart
logger.write(
  message: "Database connection failed",
  level: LogLevel.error,
);
```

---

# 🕒 Automatic Timestamp

Every log automatically includes a timestamp.

Example:

```
[01-07-2026 15:42:18]
```

---

# 🏷 Class-Based Logging

Create separate loggers for different classes.

```dart
final authLogger = Logger("AuthService");
final apiLogger = Logger("ApiService");
```

Output:

```
AuthService::login
ApiService::fetchUsers
```

This makes it easy to identify where logs originate.

---

# 📁 Persistent Log Files

Logs are automatically saved to persistent storage.

Retrieve the log file:

```dart
final file = await Logger.getLogFile();
```

Useful for:

* Production debugging
* User bug reports
* Offline log collection

---

# 🔐 Automatic Sensitive Data Redaction

Astute Logger automatically masks sensitive information before writing logs.

Protected data includes:

* Bearer Tokens
* JWT Tokens
* Email Addresses
* Credit Card Numbers

Example:

Before

```
Authorization: Bearer eyJhbGciOi...
```

After

```
Authorization: Bearer [REDACTED]
```

No additional configuration is required.

---

# 📦 Pretty JSON Logging

Instead of printing raw JSON:

```dart
logger.logJson(response);
```

Produces beautifully formatted output for easier debugging.

---

# 📋 Pretty Print Lists

Print collections in a readable format.

```dart
logger.logPrettyList(
  users,
  label: "Users",
);
```

---

# 📦 JSON List Logging

Pretty print JSON arrays.

```dart
logger.logJsonList(users);
```

---

# ⏱ Measure Execution Time

Measure the execution duration of any operation.

```dart
final result = logger.logExecutionTime(
  "Database Query",
  () {
    return fetchUsers();
  },
);
```

Example output:

```
Database Query completed in 128 ms
```

---

# 🌐 Request Context Logging

Automatically attach request metadata to logs.

```dart
await LoggerContext.runWithContext(
  requestId: "REQ-001",
  extra: {
    "userId": "123",
    "platform": "Android",
  },
  body: () {
    logger.write(
      message: "User authenticated",
      level: LogLevel.info,
    );
  },
);
```

Perfect for:

* API requests
* Authentication
* Distributed tracing
* Debugging asynchronous operations

---

# 🎨 Colored Console Output

Print custom colored logs.

```dart
logger.logWithColor(
  "Everything looks good!",
  color: LogColor.green.code,
);
```

Supported colors include:

* Green
* Blue
* Yellow
* Red



# 🌍 Unicode Support

Astute Logger fully supports Unicode characters and emojis.

```dart
logger.write(
  message: "Hello 👋 你好 مرحبا नमस्ते",
  level: LogLevel.info,
);
```

---

# 📖 API Overview

| Method                | Description                      |
| --------------------- | -------------------------------- |
| `write()`             | Write a log message              |
| `logJson()`           | Pretty print JSON                |
| `logJsonList()`       | Pretty print JSON arrays         |
| `logPrettyList()`     | Pretty print Dart lists          |
| `logExecutionTime()`  | Measure execution time           |
| `logWithColor()`      | Print colored logs               |
| `Logger.getLogFile()` | Retrieve the persistent log file |

---

# ✅ Why Astute Logger?

Unlike simple `print()` statements, Astute Logger provides:

| Feature                  | print() | Astute Logger |
| ------------------------ | ------- | ------------- |
| Log Levels               | ❌       | ✅             |
| File Logging             | ❌       | ✅             |
| Colored Output           | ❌       | ✅             |
| Timestamps               | ❌       | ✅             |
| JSON Formatting          | ❌       | ✅             |
| Pretty Lists             | ❌       | ✅             |
| Request Context          | ❌       | ✅             |
| Sensitive Data Redaction | ❌       | ✅             |
| Execution Time           | ❌       | ✅             |
| Release Optimization     | ❌       | ✅             |

---

# 💼 Ideal For

* Flutter Applications
* Enterprise Apps
* Banking Apps
* Healthcare Applications
* E-commerce Platforms
* REST API Clients
* Production Monitoring
* Debugging Complex Applications

---

# 🤝 Contributing

Contributions, feature requests, and bug reports are welcome!

If you find a bug or have a suggestion, please open an issue or submit a pull request.

---

# 📄 License

This project is licensed under the MIT License.