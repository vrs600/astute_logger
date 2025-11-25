# **Astute Logger**

A lightweight, smart, and colorful logging utility for Flutter and Dart applications.

Astute Logger helps you debug faster with:

* Color-coded logs
* Automatic method name detection
* Pretty JSON formatting
* Execution time tracking
* Debug/profile/release mode handling
* Clean and readable console output

---

## 📦 Installation

Add this to your `pubspec.yaml`:

```yaml
dependencies:
  astute_logger: ^0.0.1
```

Run:

```
flutter pub get
```

---

## 🚀 Usage

### Create a logger instance

```dart
final log = Logger("AuthService");
```

---

## 🟢 Basic Logging

```dart
log.write(
  message: "User signed in",
  level: LogLevel.info,
);
```

---

## 🟦 Pretty Print JSON

```dart
log.write(
  message: jsonEncode({"status": "success", "id": 42}),
  prettyPrint: true,
);
```

Or:

```dart
log.logJson({"name": "John", "age": 30});
```

---

## 🟨 Log List or Map

```dart
log.logPrettyList([1, 2, 3, 4], label: "Numbers");
```

```dart
log.logPrettyMap({"id": 1, "role": "admin"}, label: "User Info");
```

---

## 🟥 Measure Execution Time

```dart
final result = log.logExecutionTime("Calculate total", () {
  return items.reduce((a, b) => a + b);
});
```

---

## 🎨 Log with Custom Color

```dart
log.logWithColor("Operation successful!", color: LogColor.green.code);
```

---

## 🧠 Environment-Aware Logging

Astute Logger automatically detects:

* **kDebugMode**
* **kProfileMode**
* **kReleaseMode**

Logs are disabled automatically in **release mode**.

---

## 🔢 Log Levels

```dart
enum LogLevel { debug, info, warning, error }
```

---

## 🤝 Contributing

Pull requests and issues are welcome.

---

## 📄 License

MIT License.

---
