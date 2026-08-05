import 'package:dio/dio.dart';
import 'package:astute_logger/astute_logger.dart';

/// A Dio interceptor that logs HTTP requests and responses using AstuteLogger.
/// This interceptor provides comprehensive logging of HTTP traffic including:
/// - Request method and URL
/// - Response status code
/// - Request/response headers (with Authorization header redacted)
/// - Request/response body
/// - Response time
class LoggingInterceptor extends Interceptor {
  final AstuteLogger logger;
  final bool logRequestHeaders;
  final bool logRequestBody;
  final bool logResponseHeaders;
  final bool logResponseBody;

  /// Creates a new LoggingInterceptor.
  ///
  /// [logger] - The AstuteLogger instance to use for logging
  /// [logRequestHeaders] - Whether to log request headers (default: true)
  /// [logRequestBody] - Whether to log request body (default: true)
  /// [logResponseHeaders] - Whether to log response headers (default: true)
  /// [logResponseBody] - Whether to log response body (default: true)
  LoggingInterceptor({
    required this.logger,
    this.logRequestHeaders = true,
    this.logRequestBody = true,
    this.logResponseHeaders = true,
    this.logResponseBody = true,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Store the start time for response time calculation
    options.extra['_requestStartTime'] = DateTime.now();

    // Log request information
    final requestLog =
        StringBuffer('HTTP Request: ${options.method} ${options.uri}');

    if (logRequestHeaders) {
      final headers = _redactHeaders(options.headers);
      requestLog.write('\nHeaders: $headers');
    }

    if (logRequestBody && options.data != null) {
      requestLog.write('\nBody: ${options.data}');
    }

    logger.info(requestLog.toString(), tag: 'HTTP');

    super.onRequest(options, handler);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final requestStartTime =
        response.requestOptions.extra['_requestStartTime'] as DateTime?;
    final responseTime = requestStartTime != null
        ? DateTime.now().difference(requestStartTime).inMilliseconds
        : 0;

    final responseLog = StringBuffer(
        'HTTP Response: ${response.statusCode} ${response.statusMessage}');
    responseLog.write(' (${responseTime}ms)');

    if (logResponseHeaders) {
      final headers = _redactHeaders(response.headers.map);
      responseLog.write('\nHeaders: $headers');
    }

    if (logResponseBody && response.data != null) {
      responseLog.write('\nBody: ${response.data}');
    }

    logger.info(responseLog.toString(), tag: 'HTTP');

    super.onResponse(response, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final requestStartTime =
        err.requestOptions.extra['_requestStartTime'] as DateTime?;
    final responseTime = requestStartTime != null
        ? DateTime.now().difference(requestStartTime).inMilliseconds
        : 0;

    final errorLog =
        StringBuffer('HTTP Error: ${err.response?.statusCode ?? 'N/A'}');
    errorLog.write(' (${responseTime}ms)');

    errorLog
        .write('\nURL: ${err.requestOptions.method} ${err.requestOptions.uri}');

    if (logRequestHeaders) {
      final headers = _redactHeaders(err.requestOptions.headers);
      errorLog.write('\nRequest Headers: $headers');
    }

    if (logRequestBody && err.requestOptions.data != null) {
      errorLog.write('\nRequest Body: ${err.requestOptions.data}');
    }

    if (logResponseHeaders && err.response != null) {
      final headers = _redactHeaders(err.response!.headers.map);
      errorLog.write('\nResponse Headers: $headers');
    }

    if (err.response != null && logResponseBody && err.response!.data != null) {
      errorLog.write('\nResponse Body: ${err.response!.data}');
    }

    if (err.message != null) {
      errorLog.write('\nError: ${err.message}');
    }

    errorLog.write('\nType: ${err.type}');

    logger.error(errorLog.toString(), tag: 'HTTP');

    super.onError(err, handler);
  }

  /// Redacts sensitive headers like Authorization from the headers map.
  Map<String, dynamic> _redactHeaders(Map<String, dynamic> headers) {
    final redactedHeaders = Map<String, dynamic>.from(headers);

    // Redact Authorization header
    if (redactedHeaders.containsKey('authorization')) {
      redactedHeaders['authorization'] = '[REDACTED]';
    }

    // Redact other common sensitive headers
    const sensitiveHeaders = [
      'cookie',
      'set-cookie',
      'x-api-key',
      'x-access-token',
      'access-token',
      'bearer',
      'token',
    ];

    for (final header in sensitiveHeaders) {
      if (redactedHeaders.containsKey(header)) {
        redactedHeaders[header] = '[REDACTED]';
      }
    }

    return redactedHeaders;
  }
}
