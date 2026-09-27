# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [2.6.0]

### Added
- **`AppMode` enum** (`debug`, `profile`, `release`, `unknown`) exposed via the
  `AstuteLogger.appMode` getter, replacing the semantically confusing
  `getAppMode()` method that returned a `LogLevel`.
- **`LogConfig.redactEmails`** flag (default `true`). Disabling it preserves
  email addresses in logs for improved observability while still redacting
  credit cards and other sensitive patterns.
- **`AstuteLogger.redactObject(Object?)`** — public key-based redaction helper
  for nested maps and lists. Used internally by `json()` and exposed for
  callers (including the Dio interceptor).
- **`AstuteLogger.flush()`** (`@visibleForTesting`) — awaits full drain of the
  async write queue. Enables deterministic tests and shutdown-time flushing.
- **`AstuteLogger.resetFileCache()`** (`@visibleForTesting`) — clears the
  internal `File` cache, primarily for test isolation.
- **`AstuteLogger.getLogsByTag(tag, {fileName})`** now accepts a `fileName`
  parameter so callers can read from non-default log files.
- **`lib/service/logging_interceptor.dart`** — a new `LoggingInterceptor` for
  Dio that logs request/response/error traffic with structured redaction,
  truncation, and response-time measurement.
- **`LoggingInterceptor` options**: `logRequestHeaders`, `logRequestBody`,
  `logResponseHeaders`, `logResponseBody`, `maxBodyLength`,
  `maxHeaderValueLength` (all configurable via constructor with assertions).
- **`FormData` body logging** — only field names and file basenames are
  logged, never full paths or raw bytes.
- **Truncation** for both body strings and header values, with a
  `... [truncated, total N chars]` suffix.
- Comprehensive test suites:
  - `test/astute_logger_test.dart`
  - `test/logging_interceptor_test.dart`

### Changed
- **Async write pipeline** — replaced the `StreamController`-based queue with
  an explicit bounded queue (`Queue<_QueuedLogEvent>`) with a 1024-event
  capacity. Guarantees strict FIFO write ordering, back-pressure via slot
  waiters, and per-event `Future` completion only after the log line is
  persisted.
- **All public write methods now return `Future<void>`** — `write`, `json`,
  `debug`, `info`, `warning`, `error`, `critical`. Awaiting them provides a
  durability guarantee; ignoring them preserves the old fire-and-forget
  behavior.
- **File writes now open and close a fresh `IOSink` per call**
  (`openWrite` → `flush` → `close`) instead of `writeAsString(flush: true)`.
  This releases the OS file handle immediately, preventing Windows file
  locks and improving durability semantics.
- **`getLogFile()` now caches `File` instances correctly.** The previous
  implementation read from `_logFilesCache` but never populated it, defeating
  the cache. Fixed.
- **Pretty-print redaction** — pretty-printed JSON is now redacted via
  **key-based** rules (`_redactObject`) instead of the free-text regex, which
  failed on multi-line JSON (quoted keys broke the pattern match).
- **`json()` now reuses `_tryDecodeJson`** internally, avoiding duplicated
  `jsonDecode` logic.
- **Regex redaction rule #1** — clarified with inline examples in the source.
- **Stack-trace parsing regex** now allows `$` in identifiers (closures and
  generics) and includes a fallback pattern for frames without a trailing
  `(`, matching real VM output more reliably.
- **`logExecutionTime` and `logExecutionTimeAsync`** now log via `try/finally`
  so the timing line is always emitted, even when the measured function
  throws. The original exception propagates unchanged.
- **`_processLogQueue` write path** now uses the new `_appendToFile` helper.

### Fixed
- **Out-of-order writes under concurrency** — the async queue now serializes
  every event strictly in enqueue order, even across multiple logger
  instances writing to the same file.
- **Broken `prettyPrint` flag** — previously a no-op because `jsonDecode` was
  attempted on the fully-formatted log line. Now the raw message is decoded
  and pretty-printed correctly, with the log prefix and suffix preserved.
- **Redaction bypass for structured bodies** in the Dio interceptor — bodies
  are now routed through `redactObject()` before serialization.
- **`getLogFile` never caching** (see *Changed*).
- **Windows `PathAccessException` on file deletion** — resolved by the
  close-per-write change described above.

### Removed
- **`AstuteLogger.getAppMode()`** — replaced by the `appMode` getter.
  (Deprecated alias not retained; migration is a one-line rename.)

---

## [2.5.3]

### Changed
- Standardized log output with a consistent `[log]` prefix.
- Improved log readability by simplifying the title format.
- Preserved timestamps, context information, colorized logging, and scrubbed
  message output.

### Documentation
- Updated `README.md` with `getLogsByTag` feature documentation.

---

## [2.5.1]

### Documentation
- Updated `README.md`.

---

## [2.5.0]

### Added
- Multiple log levels (`debug`, `info`, `warning`, `error`, `critical`).
- Colored console logging.
- Persistent file logging.
- Configurable logger settings via `LogConfig`.
- Context-aware logging with request IDs (`LoggerContext.runWithContext`).
- Sensitive data redaction (tokens, passwords, emails, credit cards).
- Pretty JSON logging via `json()`.
- Execution time measurement (`logExecutionTime`, `logExecutionTimeAsync`).
- Automatic caller method detection from stack traces.
- Error and stack trace logging.
- Cross-platform Flutter support (Android, iOS, Web, Desktop).

### Technical Details
- Async logging queue for non-blocking writes.
- File output caching to avoid repeated directory lookups.
- Stack trace parsing with intelligent frame skipping for cleaner caller
  names.
- ANSI color code stripping before file writes to keep logs clean.
- Graceful fallback for web platform where stack frames are JS-compiled.
- Release-mode safety (no logs in `kReleaseMode`).

---

## [2.2.0]

### Added
- Colored console logging by log level (debug, info, warning, error).
- Pretty JSON logging (`logJson`, `logJsonList`).
- Pretty list/map logging (`logPrettyList`).
- Execution time measurement (`logExecutionTime`,
  `logExecutionTimeAsync`).
- Debug/profile/release mode detection.
- Caller method name detection from stack trace.
- Persistent file logging.
- Sensitive data redaction (tokens, emails, credit cards).
- Zone-based context propagation (`LoggerContext.runWithContext`).

---

## [0.0.1]

### Added
- Initial release of Astute Logger.
- Basic logging with color support.
- Pretty JSON logging.
- Pretty list/map logging.
- Execution time measurement.
- Debug/profile/release mode detection.
- Method name detection.

---

[2.6.0]: https://github.com/your-org/astute_logger/compare/v2.5.3...HEAD
[2.5.3]: https://github.com/your-org/astute_logger/compare/v2.5.1...v2.5.3
[2.5.1]: https://github.com/your-org/astute_logger/compare/v2.5.0...v2.5.1
[2.5.0]: https://github.com/your-org/astute_logger/compare/v2.2.0...v2.5.0
[2.2.0]: https://github.com/your-org/astute_logger/compare/v0.0.1...v2.2.0
[0.0.1]: https://github.com/your-org/astute_logger/releases/tag/v0.0.1