import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:astute_logger/astute_logger.dart';
import 'package:astute_logger/service/logging_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> readLogAfterFlush(
  AstuteLogger logger,
  String fileName,
  Directory dir,
) async {
  await AstuteLogger.flush();
  final file = File('${dir.path}/$fileName');
  if (!await file.exists()) return '';
  return file.readAsString();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('astute_http_');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'getApplicationDocumentsDirectory') {
        return tempDir.path;
      }
      throw MissingPluginException();
    });
  });

  tearDown(() async {
    await AstuteLogger.flush();
    AstuteLogger.resetFileCache();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  ({AstuteLogger logger, String fileName}) makeLogger({
    int maxBodyLength = 2000,
    int maxHeaderValueLength = 500,
  }) {
    final fileName = 'http_${DateTime.now().microsecondsSinceEpoch}.txt';
    final logger = AstuteLogger(
      'InterceptorTest',
      config: LogConfig(
        enableConsoleOutput: false,
        enableColorLogging: false,
        logFileName: fileName,
      ),
    );
    return (logger: logger, fileName: fileName);
  }

  Dio makeDio(AstuteLogger logger,
      {HttpClientAdapter? adapter,
      int maxBodyLength = 2000,
      int maxHeaderValueLength = 500}) {
    final dio = Dio()
      ..httpClientAdapter = adapter ?? _StaticAdapter()
      ..interceptors.add(LoggingInterceptor(
        logger: logger,
        maxBodyLength: maxBodyLength,
        maxHeaderValueLength: maxHeaderValueLength,
      ));
    return dio;
  }

  // ═══════════════════════════════════════════════════════════════════
  // 1. CONSTRUCTION
  // ═══════════════════════════════════════════════════════════════════
  group('LoggingInterceptor construction', () {
    test('defaults are enabled with 2000/500 limits', () {
      final l = AstuteLogger('X');
      final i = LoggingInterceptor(logger: l);
      expect(i.logRequestHeaders, isTrue);
      expect(i.logRequestBody, isTrue);
      expect(i.logResponseHeaders, isTrue);
      expect(i.logResponseBody, isTrue);
      expect(i.maxBodyLength, 2000);
      expect(i.maxHeaderValueLength, 500);
    });

    test('asserts reject negative limits', () {
      final l = AstuteLogger('X');
      expect(
        () => LoggingInterceptor(logger: l, maxBodyLength: -1),
        throwsA(isA<AssertionError>()),
      );
      expect(
        () => LoggingInterceptor(logger: l, maxHeaderValueLength: -1),
        throwsA(isA<AssertionError>()),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 2. REQUEST LOGGING
  // ═══════════════════════════════════════════════════════════════════
  group('onRequest', () {
    test('logs method, URL, headers, and body', () async {
      final h = makeLogger();
      final dio = makeDio(h.logger);

      await dio.fetch(RequestOptions(
        path: 'https://api.test/users',
        method: 'POST',
        headers: {'x-trace': 'abc'},
        data: {'name': 'alice'},
      ));

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, contains('HTTP Request: POST https://api.test/users'));
      expect(out, contains('Headers:'));
      expect(out, contains('x-trace'));
      expect(out, contains('"name"'));
      expect(out, contains('alice'));
    });

    test('redacts Authorization header', () async {
      final h = makeLogger();
      final dio = makeDio(h.logger);

      await dio.fetch(RequestOptions(
        path: 'https://api.test',
        method: 'GET',
        headers: {'authorization': 'Bearer super-secret'},
      ));

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, contains('[REDACTED]'));
      expect(out, isNot(contains('super-secret')));
    });

    test('redacts common sensitive headers', () async {
      final h = makeLogger();
      final dio = makeDio(h.logger);

      await dio.fetch(RequestOptions(
        path: 'https://api.test',
        method: 'GET',
        headers: {
          'cookie': 'session=xyz',
          'x-api-key': 'k-123',
          'x-access-token': 't-456',
        },
      ));

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, isNot(contains('session=xyz')));
      expect(out, isNot(contains('k-123')));
      expect(out, isNot(contains('t-456')));
    });

    test('redacts structured JSON body via key redaction', () async {
      final h = makeLogger();
      final dio = makeDio(h.logger);

      await dio.fetch(RequestOptions(
        path: 'https://api.test',
        method: 'POST',
        data: {'user': 'alice', 'password': 'hunter2'},
      ));

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, contains('alice'));
      expect(out, isNot(contains('hunter2')));
      expect(out, contains('[REDACTED]'));
    });

    test('can disable request header logging', () async {
      final h = makeLogger();
      final dio = Dio()
        ..httpClientAdapter = _StaticAdapter()
        ..interceptors.add(LoggingInterceptor(
          logger: h.logger,
          logRequestHeaders: false,
        ));

      await dio.fetch(RequestOptions(
        path: 'https://api.test',
        method: 'GET',
        headers: {'x-trace': 'should-not-appear'},
      ));

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, isNot(contains('should-not-appear')));
    });

    test('can disable request body logging', () async {
      final h = makeLogger();
      final dio = Dio()
        ..httpClientAdapter = _StaticAdapter()
        ..interceptors.add(LoggingInterceptor(
          logger: h.logger,
          logRequestBody: false,
        ));

      await dio.fetch(RequestOptions(
        path: 'https://api.test',
        method: 'POST',
        data: {'name': 'alice'},
      ));

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, isNot(contains('alice')));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 3. RESPONSE LOGGING
  // ═══════════════════════════════════════════════════════════════════
  group('onResponse', () {
    test('logs status, message, headers, body, and time', () async {
      final h = makeLogger();
      final dio = makeDio(h.logger,
          adapter: _StaticAdapter(
            statusCode: 200,
            statusMessage: 'OK',
            body: '{"result":"ok"}',
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          ));

      await dio.fetch(RequestOptions(
        path: 'https://api.test',
        method: 'GET',
      ));

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, contains('HTTP Response: 200 OK'));
      expect(out, contains('ms'));
      expect(out, contains('Headers:'));
      expect(out, contains('"result"'));
      expect(out, contains('ok'));
    });

    test('redacts sensitive response headers', () async {
      final h = makeLogger();
      final dio = makeDio(h.logger,
          adapter: _StaticAdapter(
            statusCode: 200,
            body: '{}',
            headers: {
              'set-cookie': ['session=xyz'],
            },
          ));

      await dio.fetch(RequestOptions(
        path: 'https://api.test',
        method: 'GET',
      ));

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, isNot(contains('session=xyz')));
    });

    test('can disable response body logging', () async {
      final h = makeLogger();
      final dio = Dio()
        ..httpClientAdapter = _StaticAdapter(body: '{"secret":"value"}')
        ..interceptors.add(LoggingInterceptor(
          logger: h.logger,
          logResponseBody: false,
        ));

      await dio.fetch(RequestOptions(
        path: 'https://api.test',
        method: 'GET',
      ));

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, isNot(contains('secret')));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 4. ERROR LOGGING
  // ═══════════════════════════════════════════════════════════════════
  group('onError', () {
    test('logs error type, message, and URL', () async {
      final h = makeLogger();
      final dio = makeDio(h.logger,
          adapter: _ErrorAdapter(
            statusCode: 500,
            body: 'boom',
            type: DioExceptionType.badResponse,
            message: 'server exploded',
          ));

      await expectLater(
        dio.fetch(RequestOptions(
          path: 'https://api.test/fail',
          method: 'GET',
        )),
        throwsA(isA<DioException>()),
      );

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, contains('HTTP Error: 500'));
      expect(out, contains('server exploded'));
      expect(out, contains('https://api.test/fail'));
      expect(out, contains('DioExceptionType.badResponse'));
    });

    test('logs request body on error with redaction', () async {
      final h = makeLogger();
      final dio = makeDio(h.logger,
          adapter: _ErrorAdapter(
            statusCode: 400,
            type: DioExceptionType.badResponse,
          ));

      await expectLater(
        dio.fetch(RequestOptions(
          path: 'https://api.test',
          method: 'POST',
          data: {'user': 'alice', 'password': 'hunter2'},
        )),
        throwsA(isA<DioException>()),
      );

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, contains('Request Body'));
      expect(out, contains('alice'));
      expect(out, isNot(contains('hunter2')));
    });

    test('logs response body on error', () async {
      final h = makeLogger();
      final dio = makeDio(h.logger,
          adapter: _ErrorAdapter(
            statusCode: 500,
            body: '{"error":"internal"}',
            type: DioExceptionType.badResponse,
          ));

      await expectLater(
        dio.fetch(RequestOptions(
          path: 'https://api.test',
          method: 'GET',
        )),
        throwsA(isA<DioException>()),
      );

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, contains('Response Body'));
      expect(out, contains('internal'));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 5. TRUNCATION
  // ═══════════════════════════════════════════════════════════════════
  group('Truncation', () {
    test('truncates long bodies with total length', () async {
      final h = makeLogger();
      final dio = Dio()
        ..httpClientAdapter = _StaticAdapter()
        ..interceptors.add(LoggingInterceptor(
          logger: h.logger,
          maxBodyLength: 10,
        ));

      await dio.fetch(RequestOptions(
        path: 'https://api.test',
        method: 'POST',
        data: {'k': 'a-very-long-value'},
      ));

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, contains('[truncated, total'));
    });

    test('truncates long header values with total length', () async {
      final h = makeLogger();
      final dio = Dio()
        ..httpClientAdapter = _StaticAdapter()
        ..interceptors.add(LoggingInterceptor(
          logger: h.logger,
          maxHeaderValueLength: 5,
        ));

      await dio.fetch(RequestOptions(
        path: 'https://api.test',
        method: 'GET',
        headers: {'x-trace': '0123456789'},
      ));

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, contains('01234'));
      expect(out, contains('[truncated, total 10 chars]'));
    });

    test('short bodies are not truncated', () async {
      final h = makeLogger();
      final dio = makeDio(h.logger, maxBodyLength: 200);

      await dio.fetch(RequestOptions(
        path: 'https://api.test',
        method: 'POST',
        data: {'k': 'v'},
      ));

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, isNot(contains('[truncated')));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 6. BODY FORMATTING
  // ═══════════════════════════════════════════════════════════════════
  group('Body formatting', () {
    test('JSON string bodies are re-encoded and redacted', () async {
      final h = makeLogger();
      final dio = makeDio(h.logger);

      await dio.fetch(RequestOptions(
        path: 'https://api.test',
        method: 'POST',
        data: jsonEncode({'user': 'alice', 'token': 'abc'}),
      ));

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, contains('alice'));
      expect(out, isNot(contains('abc')));
    });

    test('non-JSON string bodies pass through unchanged', () async {
      final h = makeLogger();
      final dio = makeDio(h.logger);

      await dio.fetch(RequestOptions(
        path: 'https://api.test',
        method: 'POST',
        data: 'plain text payload',
      ));

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, contains('plain text payload'));
    });

    test('FormData bodies show field and file names only', () async {
      final h = makeLogger();
      final dio = makeDio(h.logger);

      final form = FormData();
      form.fields.add(MapEntry('username', 'alice'));
      form.files.add(MapEntry(
        'avatar',
        MultipartFile.fromBytes(
          [1, 2, 3],
          filename: '/tmp/secret/path/avatar.png',
        ),
      ));

      await dio.fetch(RequestOptions(
        path: 'https://api.test',
        method: 'POST',
        data: form,
      ));

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, contains('FormData'));
      expect(out, contains('username'));
      expect(out, contains('avatar.png'));
      expect(out, isNot(contains('/tmp/secret/path')));
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  // 7. RESPONSE TIME
  // ═══════════════════════════════════════════════════════════════════
  group('Response time', () {
    test('response line includes "(<ms>ms)"', () async {
      final h = makeLogger();
      final dio = makeDio(h.logger);

      await dio.fetch(RequestOptions(
        path: 'https://api.test',
        method: 'GET',
      ));

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, matches(RegExp(r'HTTP Response: \d+.*\(\d+ms\)')));
    });

    test('error line includes "(<ms>ms)"', () async {
      final h = makeLogger();
      final dio = makeDio(h.logger,
          adapter: _ErrorAdapter(
            statusCode: 500,
            type: DioExceptionType.badResponse,
          ));

      await expectLater(
        dio.fetch(RequestOptions(
          path: 'https://api.test',
          method: 'GET',
        )),
        throwsA(isA<DioException>()),
      );

      final out = await readLogAfterFlush(h.logger, h.fileName, tempDir);
      expect(out, matches(RegExp(r'HTTP Error: \d+.*\(\d+ms\)')));
    });
  });
}

// ─────────────────────────────────────────────────────────────────────
// Test adapters
// ─────────────────────────────────────────────────────────────────────
class _StaticAdapter implements HttpClientAdapter {
  final int statusCode;
  final String? statusMessage;
  final String body;
  final Map<String, List<String>> headers;

  _StaticAdapter({
    this.statusCode = 200,
    this.statusMessage,
    this.body = '{}',
    this.headers = const {
      Headers.contentTypeHeader: ['application/json'],
    },
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      body,
      statusCode,
      statusMessage: statusMessage,
      headers: headers,
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ErrorAdapter implements HttpClientAdapter {
  final int statusCode;
  final String? body;
  final DioExceptionType type;
  final String? message;
  final Map<String, List<String>> headers;

  _ErrorAdapter({
    required this.statusCode,
    this.body,
    this.type = DioExceptionType.badResponse,
    this.message,
    this.headers = const {
      Headers.contentTypeHeader: ['application/json'],
    },
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(
      requestOptions: options,
      response: ResponseBody.fromString(
                body ?? '',
                statusCode,
                headers: headers,
              ) ==
              null
          ? null
          : Response<dynamic>(
              requestOptions: options,
              statusCode: statusCode,
              data: body,
              headers: Headers.fromMap(headers),
            ),
      type: type,
      message: message,
    );
  }

  @override
  void close({bool force = false}) {}
}
