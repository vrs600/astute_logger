## [2.3.0] - 2026-07-22

### Added
- **Colored console logging** by log level with ANSI color codes (green for debug, blue for info, yellow for warning, red for error)
- **Pretty JSON logging** with proper indentation and formatting
- **Pretty list/map logging** for structured data visualization
- **Execution time measurement** for sync (`logExecutionTime`) and async (`logExecutionTimeAsync`) functions
- **App mode detection** (debug/profile/release) integrated into log messages
- **Caller method name detection** from stack traces with platform-aware handling (native VM vs web)
- **Persistent file logging** to application documents directory with async queue pipeline
- **Sensitive data redaction** engine:
  - Bearer/Authorization tokens
  - Email addresses
  - Credit card numbers (Visa, Mastercard, Amex, Discover)
- **Zone-based context propagation** via `LoggerContext.runWithContext()` for request IDs and metadata
- **Configurable logging** via `LogConfig`:
  - Redaction toggle
  - Minimum log level filtering
  - Console output toggle
  - File output toggle
  - Log file name customization
  - Color logging toggle
- **Log level enum** (debug, info, warning, error) with severity-based filtering
- **Static log file access** via `getLogFile()` for retrieving persisted logs
- **Convenience methods** (debug, info, warning, error) for shorter call syntax
- **Dynamic context injection** via `extra` parameter on all logging calls
- **Timestamp formatting** in day-month-year and 24-hour time format

### Technical Details
- Async logging queue with `StreamController` for non-blocking writes
- File output caching to avoid repeated directory lookups
- Stack trace parsing with intelligent frame skipping for cleaner caller names
- ANSI color code stripping before file writes to keep logs clean
- Graceful fallback for web platform where stack frames are JS-compiled
- Release mode safety (no logs in `kReleaseMode`)

## 2.2.0

- Added colored console logging by log level (debug, info, warning, error)
- Added pretty JSON logging (`logJson`, `logJsonList`)
- Added pretty list/map logging (`logPrettyList`)
- Added execution time measurement (`logExecutionTime`, `logExecutionTimeAsync`)
- Added debug/profile/release mode detection
- Added caller method name detection from stack trace
- Added persistent file logging
- Added sensitive data redaction (tokens, emails, credit cards)
- Added Zone-based context propagation (`LoggerContext.runWithContext`)

## 0.0.1

- Initial release of Astute Logger
- Added:
    - Basic logging with color support
    - Pretty JSON logging
    - Pretty list/map logging
    - Execution time measurement
    - Debug/profile/release mode detection
    - Method name detection