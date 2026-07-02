## 0.0.1

- Initial release of Astute Logger
- Added:
    - Basic logging with color support
    - Pretty JSON logging
    - Pretty list/map logging
    - Execution time measurement
    - Debug/profile/release mode detection
    - Method name detection

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