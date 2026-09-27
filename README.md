# 🚀 Astute Logger

A lightweight, configurable logging package for Flutter with support for colored console output, persistent file logging, contextual logging, execution time measurement, structured and free-text sensitive data redaction, and a built-in Dio HTTP interceptor.

---

## ✨ Features

- 📝 Multiple log levels
  - 🟢 Debug
  - 🔵 Info
  - 🟡 Warning
  - 🔴 Error
  - 🟣 Critical
- 🎨 Colored console logs
- 📂 Persistent file logging with an async, serialized write queue
- ⚙️ Configurable logger settings
- 📍 Automatic caller method detection (VM + web fallback)
- 🌐 Context-aware logging using Zones
- 🆔 Request ID propagation
- 🏷️ Additional contextual metadata & tags
- 📄 Pretty JSON logging
- 🔒 Sensitive data redaction
  - 🔑 Authorization tokens & Bearer headers
  - 🔐 Passwords, secrets & API keys
  - 📧 Email addresses (opt-out via `redactEmails`)
  - 💳 Credit card numbers
  - 🧩 Key-based redaction for nested maps & lists via `redactObject`
- ⏱️ Execution time measurement (sync & async)
- 🚨 Error & stack trace logging
- 🌐 Built-in Dio `LoggingInterceptor` for HTTP request/response/error traffic
- 📱 Cross-platform Flutter support (Android, iOS, Web, Desktop)

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

// Optional: HTTP interceptor
import 'package:astute_logger/service/logging_interceptor.dart';
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
    redactEmails: true,
    minimumLogLevel: LogLevel.debug,
    logFileName: 'app_logs.txt',
  ),
);
```

---

# 📖 Examples

## 🟢 Debug

```dart
await logger.debug("Debug message");
```

## 🔵 Info

```dart
await logger.info("Application started");
```

## 🟡 Warning

```dart
await logger.warning("API response is slow");
```

## 🔴 Error

```dart
await logger.error(
  "Unable to load profile",
  error: Exception("HTTP 500"),
  stackTrace: StackTrace.current,
);
```

## 🟣 Critical

```dart
await logger.critical(
  "Database connection lost",
  error: Exception("SocketException"),
  stackTrace: StackTrace.current,
);
```

> ℹ️ **Async by default.** All write methods (`debug`, `info`, `warning`,
> `error`, `critical`, `json`, `write`) return `Future<void>`. The returned
> Future completes only after the log line has been persisted to disk (if
> file output is enabled). Await it whenever you need a durability guarantee.

---

## 🏷️ Logging with Metadata

```dart
await logger.info(
  "User logged in",
  tag: 'AUTH',
  extra: {
    "userId": 123,
    "role": "Admin",
  },
);
```

---

## 🌐 Context-Aware Logging

```dart
await LoggerContext.runWithContext(
  requestId: "REQ-1001",
  extra: {
    "screen": "Home",
    "feature": "Login",
  },
  body: () async {
    await logger.info("Inside contextual logging");
    // Every log within this Zone automatically carries:
    //   [ReqID: REQ-1001] [Ctx: {screen: Home, feature: Login}]
  },
);
```

---

## ⏱️ Measure Execution Time

### Synchronous

```dart
final sorted = logger.logExecutionTime(
  "Sorting List",
  () {
    final list = List.generate(100000, (i) => 100000 - i);
    list.sort();
    return list;
  },
);
```

> The timing log is emitted even if the callback throws — the original
> exception is rethrown unchanged.

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

Use `write(prettyPrint: true)` for raw JSON strings, or `json()` for objects.

### Pretty-print a JSON string

```dart
await logger.write(
  message: jsonEncode({
    "name": "John",
    "age": 25,
    "roles": ["Admin", "User"]
  }),
  prettyPrint: true,
  level: LogLevel.info,
);
```

### Log a structured object (auto pretty-printed + redacted)

```dart
await logger.json({
  "user": "john",
  "password": "hunter2",          // → [REDACTED]
  "profile": {
    "email": "john@example.com",  // → [REDACTED] (unless redactEmails=false)
  },
});
```

> 🔒 **Pretty-printed JSON is redacted using key-based rules**, not regex.
> This means `{"password": "p@ss!"}` is reliably redacted even when the value
> contains special characters or when the JSON is multi-line.

---

## 🔒 Automatic Sensitive Data Redaction

AstuteLogger offers **two complementary redaction engines**:

### 1. Key-based redaction (structured data)

Applied automatically by `json()` and by `write(prettyPrint: true)` when the
message decodes to a `Map` or `List`. It also powers the public
`redactObject()` helper used by the Dio interceptor.

```dart
logger.redactObject({
  'user': 'alice',
  'credentials': {
    'password': 'hunter2',
    'token': 'abc',
  },
});
// => {
//      'user': 'alice',
//      'credentials': {
//        'password': '[REDACTED]',
//        'token': '[REDACTED]',
//      },
//    }
```

Manage the sensitive key set at runtime:

```dart
AstuteLogger.registerSensitiveKey('ssn');
AstuteLogger.unregisterSensitiveKey('ssn');
AstuteLogger.getSensitiveKeys(); // sorted list
```

Default keys: `password`, `token`, `accesstoken`, `refreshtoken`,
`authorization`, `apikey`, `secret`, `email`.

### 2. Free-text redaction (regex)

Applied to every message when `enableRedaction: true`.

| Rule | Example input | Output |
|------|---------------|--------|
| Quoted key/value | `"password": "p@ss!"` | `"password": "[REDACTED]"` |
| Bearer token | `Authorization: Bearer abc-123` | `Authorization: Bearer [REDACTED]` |
| Bare key/value | `token:abc123 count:5` | `token:[REDACTED] count:5` |
| Email address | `contact alice@example.com` | `contact [REDACTED]` |
| Credit card | `card 4111111111111111` | `card [REDACTED]` |

### Disabling email redaction

If you need to log emails for debugging:

```dart
const LogConfig(redactEmails: false)
```

Emails are preserved, but credit-card numbers and other rules still apply.
To disable redaction entirely, set `enableRedaction: false`.

---

## 📂 Read Log File

```dart
final file = await AstuteLogger.getLogFile();

if (file != null && await file.exists()) {
  final logs = await file.readAsString();
  print(logs);
}
```

Custom file name:

```dart
final file = await AstuteLogger.getLogFile(fileName: 'api_logs.txt');
```

> `getLogFile()` caches `File` instances per path to avoid repeated platform
> channel calls and to keep a stable identity across lookups.

---

## 🏷️ Filter Logs by Tag

```dart
final authLogs = await AstuteLogger.getLogsByTag('AUTH');
authLogs.forEach(print);
```

Custom file name:

```dart
final apiLogs = await AstuteLogger.getLogsByTag(
  'HTTP',
  fileName: 'api_logs.txt',
);
```

> Matching is case-insensitive and ANSI color codes are stripped from the
> returned lines.

---

## 🌐 Dio HTTP Logging

Attach the built-in `LoggingInterceptor` to any Dio instance:

```dart
import 'package:dio/dio.dart';
import 'package:astute_logger/service/logging_interceptor.dart';

final dio = Dio()
  ..interceptors.add(LoggingInterceptor(
    logger: logger,
    logRequestHeaders: true,
    logRequestBody: true,
    logResponseHeaders: true,
    logResponseBody: true,
    maxBodyLength: 2000,       // truncate long bodies
    maxHeaderValueLength: 500, // truncate long header values
  ));
```

### What gets logged

- **Request:** method, URL, headers (sensitive ones redacted), body
- **Response:** status code + message, elapsed time, headers, body
- **Error:** status code, elapsed time, URL, request/response headers,
  request/response bodies, error message, `DioExceptionType`

### Redaction & safety

- `Authorization`, `Cookie`, `Set-Cookie`, `X-Api-Key`, `X-Access-Token`,
  `Access-Token`, `Bearer`, `Token` headers are replaced with `[REDACTED]`.
- JSON bodies are decoded and passed through `redactObject()` — so
  `{"password": "hunter2"}` becomes `{"password": "[REDACTED]"}`.
- `FormData` bodies log only field names and file **basenames** — never full
  paths or raw bytes.
- Long values are truncated with a `... [truncated, total N chars]` suffix.

---

## ⚙️ Configuration

```dart
const LogConfig(
  enableConsoleOutput: true,
  enableFileOutput: true,
  enableColorLogging: true,
  enableRedaction: true,
  redactEmails: true,
  minimumLogLevel: LogLevel.debug,
  logFileName: 'app_logs.txt',
)
```

| Field | Default | Description |
|-------|---------|-------------|
| `enableRedaction` | `true` | Master switch for all redaction |
| `redactEmails` | `true` | Redact email addresses in free text |
| `minimumLogLevel` | `LogLevel.debug` | Drop messages below this level |
| `enableConsoleOutput` | `true` | Write to `dart:developer` `log()` |
| `enableFileOutput` | `true` | Persist to the app documents directory |
| `logFileName` | `'app_logs.txt'` | Target log file name |
| `enableColorLogging` | `true` | ANSI colorize console output |

---

## 🧭 App Modes

Each log line includes the current Flutter build mode:

```dart
logger.appMode; // AppMode.debug | profile | release | unknown
```

---

## 🧪 Testing Hooks

The following static helpers are exposed for tests and diagnostics:

```dart
// Wait for the async write queue to fully drain.
await AstuteLogger.flush();

// Clear the internal File cache (useful between tests).
AstuteLogger.resetFileCache();
```

> These are marked `@visibleForTesting` — prefer not to call them from
> production code.

---

## 🧵 Threading & Durability

- All log events flow through a single static queue with a bounded capacity
  (1024 pending events). Producers block when the queue is full.
- Writes are **serialized**: events are persisted strictly in enqueue order,
  even across multiple logger instances writing to the same file.
- File handles are opened and closed per write (`openWrite` + `close()`), so
  log files are never held open by the process — safe on Windows and in
  tests.

---

## ❤️ License

MIT License.