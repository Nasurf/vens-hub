import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:vens_hub/core/config/app_config.dart';
import 'package:vens_hub/core/error/exceptions.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_performance/firebase_performance.dart';
import 'package:vens_hub/core/di/injection_container.dart';
import 'package:vens_hub/core/services/performance/performance_service.dart';
import 'package:vens_hub/core/services/analytics/analytics_service.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class R2StorageService {
  FirebasePerformance? get _performance =>
      sl.isRegistered<FirebasePerformance>() ? sl<FirebasePerformance>() : null;
  PerformanceService? get _perfService =>
      sl.isRegistered<PerformanceService>() ? sl<PerformanceService>() : null;
  final _analytics = sl<AnalyticsService>();

  Dio _createDioWithInterceptors() {
    final dio = Dio();

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (!kIsWeb && _perfService != null) {
            final url = options.uri.toString();
            final method = options.method.toUpperCase();
            final httpMethod = _mapMethod(method);
            final metric = _perfService!.newHttpMetric(url, httpMethod);
            options.extra['httpMetric'] = metric;
            options.extra['startTime'] = DateTime.now();
            await metric.start();
            if (options.data is String) {
              metric.requestPayloadSize = (options.data as String).length;
            } else if (options.data is List<int>) {
              metric.requestPayloadSize = (options.data as List<int>).length;
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          final startTime =
              response.requestOptions.extra['startTime'] as DateTime?;
          final metric = response.requestOptions.extra['httpMetric'];
          if (metric is HttpMetric) {
            metric.httpResponseCode = response.statusCode ?? 0;
            if (response.data is String) {
              metric.responsePayloadSize = (response.data as String).length;
            } else if (response.data is List<int>) {
              metric.responsePayloadSize = (response.data as List<int>).length;
            }
            await metric.stop();
          }
          if (startTime != null) {
            final duration = DateTime.now().difference(startTime);
            _analytics.logPerformanceMetric(
              metricName: 'r2_http_call',
              value: duration.inMilliseconds,
              unit: 'ms',
              tags: {
                'method': response.requestOptions.method,
                'status': response.statusCode ?? 0,
                'url_path': response.requestOptions.uri.path,
              },
            );
          }
          handler.next(response);
        },
        onError: (e, handler) async {
          final startTime = e.requestOptions.extra['startTime'] as DateTime?;
          final metric = e.requestOptions.extra['httpMetric'];
          if (metric is HttpMetric) {
            metric.httpResponseCode = e.response?.statusCode ?? 0;
            await metric.stop();
          }
          if (startTime != null) {
            final duration = DateTime.now().difference(startTime);
            _analytics.logPerformanceMetric(
              metricName: 'r2_http_call_error',
              value: duration.inMilliseconds,
              unit: 'ms',
              tags: {
                'method': e.requestOptions.method,
                'status': e.response?.statusCode ?? 0,
                'url_path': e.requestOptions.uri.path,
                'error_type': e.runtimeType.toString(),
              },
            );
          }
          handler.next(e);
        },
      ),
    );

    return dio;
  }

  HttpMethod _mapMethod(String method) {
    switch (method) {
      case 'GET':
        return HttpMethod.Get;
      case 'POST':
        return HttpMethod.Post;
      case 'PUT':
        return HttpMethod.Put;
      case 'DELETE':
        return HttpMethod.Delete;
      case 'PATCH':
        return HttpMethod.Patch;
      default:
        return HttpMethod.Get;
    }
  }

  /// Deletes all documents for a specific user from R2
  Future<void> deleteAllUserDocuments(String userId) async {
    final trace =
        kIsWeb ? null : _performance?.newTrace('r2_deleteAllUserDocuments');
    trace?.putAttribute('user_id', userId);
    await trace?.start();

    try {
      final objects = await _listUserObjects(userId);
      trace?.setMetric('objects_found', objects.length);

      if (objects.isNotEmpty) {
        await _deleteMultipleObjects(objects);
        trace?.setMetric('objects_deleted', objects.length);
      }
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      if (e is StorageException) {
        rethrow;
      }
      throw StorageException(message: "Failed to delete user documents: $e");
    } finally {
      await trace?.stop();
    }
  }

  /// Lists all objects for a specific user
  Future<List<String>> _listUserObjects(String userId) async {
    final host = "${AppConfig.r2AccountId}.r2.cloudflarestorage.com";
    final canonicalUri = "/${AppConfig.r2BucketName}/";
    final url = "https://$host$canonicalUri";

    final queryParams = {'list-type': '2', 'prefix': 'users/$userId/'};

    final queryString = queryParams.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    final canonicalQueryString = queryString;

    final baseHeaders = <String, String>{"Host": host};

    final signed = _buildSigV4Headers(
      method: "GET",
      path: canonicalUri,
      region: "auto",
      service: "s3",
      body: Uint8List(0),
      baseHeaders: baseHeaders,
      accessKey: AppConfig.r2AccessKey,
      secretKey: AppConfig.r2SecretKey,
      canonicalQueryString: canonicalQueryString,
    );

    final dio = _createDioWithInterceptors();
    final resp = await dio.get(
      "$url?$canonicalQueryString",
      options: Options(
        headers: signed,
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    if (resp.statusCode != 200) {
      throw StorageException(
        message: "R2 list failed: ${resp.statusCode} ${resp.statusMessage}",
      );
    }

    final xmlData = resp.data as String;
    return _parseListObjectsResponse(xmlData);
  }

  /// Deletes multiple objects in a single request
  Future<void> _deleteMultipleObjects(List<String> objectKeys) async {
    final host = "${AppConfig.r2AccountId}.r2.cloudflarestorage.com";
    final canonicalUri = "/${AppConfig.r2BucketName}/";
    final url = "https://$host$canonicalUri";

    final queryParams = {'delete': ''};
    final queryString = queryParams.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');

    final canonicalQueryString = queryString;

    final xmlPayload = _buildDeleteObjectsXml(objectKeys);
    final bodyBytes = utf8.encode(xmlPayload);

    // S3 multi-delete recommends Content-MD5 for payload integrity
    final contentMd5 = base64Encode(md5.convert(bodyBytes).bytes);
    final baseHeaders = <String, String>{
      "Host": host,
      "Content-Type": "application/xml",
      "Content-Length": bodyBytes.length.toString(),
      "Content-MD5": contentMd5,
    };

    final signed = _buildSigV4Headers(
      method: "POST",
      path: canonicalUri,
      region: "auto",
      service: "s3",
      body: Uint8List.fromList(bodyBytes),
      baseHeaders: baseHeaders,
      accessKey: AppConfig.r2AccessKey,
      secretKey: AppConfig.r2SecretKey,
      canonicalQueryString: canonicalQueryString,
    );

    final dio = _createDioWithInterceptors();
    final resp = await dio.post(
      "$url?$canonicalQueryString",
      data: xmlPayload,
      options: Options(
        headers: signed,
        contentType: "application/xml",
        validateStatus: (s) => s != null && s < 500,
      ),
    );

    if (resp.statusCode != 200) {
      throw StorageException(
        message:
            "R2 bulk delete failed: ${resp.statusCode} ${resp.statusMessage}",
      );
    }
  }

  /// Builds XML payload for multiple object deletion
  String _buildDeleteObjectsXml(List<String> objectKeys) {
    final buffer = StringBuffer();
    buffer.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buffer.writeln('<Delete>');
    buffer.writeln('  <Quiet>true</Quiet>');

    for (final key in objectKeys) {
      buffer.writeln('  <Object>');
      buffer.writeln('    <Key>${_escapeXml(key)}</Key>');
      buffer.writeln('  </Object>');
    }

    buffer.writeln('</Delete>');
    return buffer.toString();
  }

  /// Parses the ListObjects response XML to extract object keys
  List<String> _parseListObjectsResponse(String xmlData) {
    final objects = <String>[];
    final keyPattern = RegExp(r'<Key>(.*?)</Key>');
    final matches = keyPattern.allMatches(xmlData);

    for (final match in matches) {
      final key = match.group(1);
      if (key != null && key.isNotEmpty) {
        objects.add(key);
      }
    }

    return objects;
  }

  /// Escapes XML special characters
  String _escapeXml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  /// Builds AWS Signature V4 headers (supports canonical query string)
  Map<String, String> _buildSigV4Headers({
    required String method,
    required String path, // canonical URI path, no query
    required String region,
    required String service,
    required Uint8List body,
    required Map<String, String> baseHeaders,
    required String accessKey,
    required String secretKey,
    String canonicalQueryString =
        '', // e.g., "list-type=2&prefix=users%2F<uid>%2F" or "delete="
  }) {
    final now = DateTime.now().toUtc();
    String two(int x) => x.toString().padLeft(2, '0');
    final date = "${now.year}${two(now.month)}${two(now.day)}"; // YYYYMMDD
    final amzDate =
        "${date}T${two(now.hour)}${two(now.minute)}${two(now.second)}Z"; // YYYYMMDD'T'HHMMSS'Z'

    final payloadHash = sha256.convert(body).toString();

    // Start with provided headers; add amz headers in lowercase (canonicalization will lowercase anyway)
    final headers = Map<String, String>.from(baseHeaders);
    headers['x-amz-date'] = amzDate;
    headers['x-amz-content-sha256'] = payloadHash;

    // Normalize header keys to lowercase for canonicalization
    String normVal(String v) => v.trim().replaceAll(RegExp('\\s+'), ' ');
    final lowerKvs = <String, String>{};
    headers.forEach((k, v) => lowerKvs[k.toLowerCase()] = normVal(v));

    final signedHeaderNames = lowerKvs.keys.toList()..sort();
    final canonicalHeaders = StringBuffer();
    for (final name in signedHeaderNames) {
      canonicalHeaders.write("$name:${lowerKvs[name]}\n");
    }
    final signedHeaders = signedHeaderNames.join(';');

    final canonicalRequest = [
      method,
      path,
      canonicalQueryString,
      canonicalHeaders.toString(),
      signedHeaders,
      payloadHash,
    ].join('\n');

    // Derive signing key and signature
    List<int> hmac(List<int> key, String data) =>
        Hmac(sha256, key).convert(utf8.encode(data)).bytes;
    final scope = "$date/$region/$service/aws4_request";
    final stringToSign = [
      'AWS4-HMAC-SHA256',
      amzDate,
      scope,
      sha256.convert(utf8.encode(canonicalRequest)).toString(),
    ].join('\n');
    final kDate = hmac(utf8.encode('AWS4$secretKey'), date);
    final kRegion = hmac(kDate, region);
    final kService = hmac(kRegion, service);
    final kSigning = hmac(kService, 'aws4_request');
    final signature =
        Hmac(sha256, kSigning).convert(utf8.encode(stringToSign)).toString();

    final authorization =
        'AWS4-HMAC-SHA256 Credential=$accessKey/$scope, SignedHeaders=$signedHeaders, Signature=$signature';

    final out = Map<String, String>.from(headers);
    out['Authorization'] = authorization;
    return out;
  }

  Future<String?> getCachedPdfPath(String url) async {
    final trace = kIsWeb ? null : _performance?.newTrace('r2_getCachedPdfPath');
    trace?.putAttribute('url', url);
    await trace?.start();

    try {
      // Use getFileFromCache instead of getSingleFile to avoid blocking on download
      final file = await DefaultCacheManager().getFileFromCache(url);
      final exists = file != null && file.file.existsSync();
      trace?.putAttribute('cache_hit', exists ? 'true' : 'false');
      return exists ? file.file.path : null;
    } catch (e) {
      trace?.putAttribute('error', e.runtimeType.toString());
      _analytics.logEvent(
        name: 'r2_cache_error',
        parameters: {'error': e.toString(), 'url': url},
      );
      return null; // Fallback to network load if caching fails
    } finally {
      await trace?.stop();
    }
  }

  /// Triggers a background download into the cache without blocking the UI.
  void downloadToCache(String url) {
    if (kIsWeb) return;
    // We don't await this as we want it to run in the background
    DefaultCacheManager()
        .downloadFile(url)
        .then((fileInfo) {
          _analytics.logEvent(
            name: 'r2_background_cache_success',
            parameters: {'url': url},
          );
        })
        .catchError((e) {
          _analytics.logEvent(
            name: 'r2_background_cache_error',
            parameters: {'error': e.toString(), 'url': url},
          );
        });
  }
}
