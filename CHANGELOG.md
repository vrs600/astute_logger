#Changelog

## [2.5.1]
- updated `README.MD`

## [2.5.0]

### Added
- Multiple log levels (`debug`, `info`, `warning`, `error`, `critical`).
- Colored console logging.
- Persistent file logging.
- Configurable logger settings.
- Context-aware logging with request IDs.
- Sensitive data redaction.
- Pretty JSON logging.
- Execution time measurement.
- Automatic caller method detection.
- Error and stack trace logging.
- Cross-platform Flutter support.

### Technical Details
- Async logging queue with `StreamController` for non-blocking writes
- File output caching to avoid repeated directory lookups
- Stack trace parsing with intelligent frame skipping for cleaner caller names
- ANSI color code stripping before file writes to keep logs clean
- Graceful fallback for web platform where stack frames are JS-compiled
- Release mode safety (no logs in `kReleaseMode`)

## [2.2.0]

- Added colored console logging by log level (debug, info, warning, error)
- Added pretty JSON logging (`logJson`, `logJsonList`)
- Added pretty list/map logging (`logPrettyList`)
- Added execution time measurement (`logExecutionTime`, `logExecutionTimeAsync`)
- Added debug/profile/release mode detection
- Added caller method name detection from stack trace
- Added persistent file logging
- Added sensitive data redaction (tokens, emails, credit cards)
- Added Zone-based context propagation (`LoggerContext.runWithContext`)

## [0.0.1]

- Initial release of Astute Logger
- Added:
    - Basic logging with color support
    - Pretty JSON logging
    - Pretty list/map logging
    - Execution time measurement
    - Debug/profile/release mode detection
    - Method name detection