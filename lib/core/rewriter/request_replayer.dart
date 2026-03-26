import 'dart:convert';
import 'dart:io';

/// 请求重放器
///
/// 支持重新发送已捕获的 HTTP 请求
class RequestReplayer {
  /// 重放请求
  ///
  /// [url] 请求 URL
  /// [method] HTTP 方法
  /// [headers] 请求头
  /// [body] 请求体
  /// [timeout] 超时时间（毫秒）
  static Future<ReplayResult> replay({
    required String url,
    required String method,
    Map<String, String>? headers,
    String? body,
    int timeout = 30000,
  }) async {
    try {
      final uri = Uri.parse(url);
      final request = HttpClientRequest(
        method,
        uri,
        Timeout(Duration(milliseconds: timeout)),
      );

      // 设置请求头
      if (headers != null) {
        for (final entry in headers.entries) {
          request.headers.set(entry.key, entry.value);
        }
      }

      // 设置请求体
      if (body != null && body.isNotEmpty) {
        request.write(body);
      }

      // 记录开始时间
      final startTime = DateTime.now();

      // 发送请求并获取响应
      final response = await request.close() as HttpClientResponse;

      // 读取响应体
      final responseBody = await response.transform(utf8.decoder).join();

      // 计算耗时
      final duration = DateTime.now().difference(startTime).inMilliseconds;

      return ReplayResult(
        success: true,
        statusCode: response.statusCode,
        headers: response.headers.map((k, v) => MapEntry(k, v.join(', '))),
        body: responseBody,
        durationMs: duration,
      );
    } catch (e) {
      return ReplayResult(
        success: false,
        error: e.toString(),
        durationMs: 0,
      );
    }
  }

  /// 生成 cURL 命令
  static String generateCurl({
    required String url,
    required String method,
    Map<String, String>? headers,
    String? body,
  }) {
    final buffer = StringBuffer('curl');

    // 方法
    buffer.write(' -X $method');

    // URL
    buffer.write(" '$url'");

    // 请求头
    if (headers != null) {
      for (final entry in headers.entries) {
        buffer.write(" -H '${entry.key}: ${entry.value}'");
      }
    }

    // 请求体
    if (body != null && body.isNotEmpty) {
      // 转义单引号
      final escapedBody = body.replaceAll("'", "'\\''");
      buffer.write(" --data '$escapedBody'");
    }

    return buffer.toString();
  }

  /// 生成 HTTPie 命令
  static String generateHttpie({
    required String url,
    required String method,
    Map<String, String>? headers,
    String? body,
  }) {
    final buffer = StringBuffer('http');

    // 方法和 URL
    buffer.write(' $method $url');

    // 请求头
    if (headers != null) {
      for (final entry in headers.entries) {
        buffer.write(' ${entry.key}:${entry.value}');
      }
    }

    // 请求体
    if (body != null && body.isNotEmpty) {
      buffer.write(' $body');
    }

    return buffer.toString();
  }

  /// 生成 PowerShell Invoke-WebRequest 命令
  static String generatePowerShell({
    required String url,
    required String method,
    Map<String, String>? headers,
    String? body,
  }) {
    final buffer = StringBuffer('Invoke-WebRequest');

    // URL
    buffer.write(" -Uri '$url'");

    // 方法
    buffer.write(" -Method '$method'");

    // 请求头
    if (headers != null) {
      buffer.write(' -Headers @{');
      final headerPairs = headers.entries
          .map((e) => "'${e.key}'='${e.value}'")
          .join('; ');
      buffer.write(headerPairs);
      buffer.write('}');
    }

    // 请求体
    if (body != null && body.isNotEmpty) {
      buffer.write(" -Body '$body'");
    }

    return buffer.toString();
  }
}

/// 重放结果
class ReplayResult {
  final bool success;
  final int? statusCode;
  final Map<String, String>? headers;
  final String? body;
  final int durationMs;
  final String? error;

  ReplayResult({
    required this.success,
    this.statusCode,
    this.headers,
    this.body,
    required this.durationMs,
    this.error,
  });

  /// 获取状态文本
  String get statusText {
    if (!success) return '请求失败';

    if (statusCode == null) return '未知状态';

    if (statusCode! >= 200 && statusCode! < 300) {
      return '成功 (${statusCode!})';
    } else if (statusCode! >= 300 && statusCode! < 400) {
      return '重定向 (${statusCode!})';
    } else if (statusCode! >= 400 && statusCode! < 500) {
      return '客户端错误 (${statusCode!})';
    } else if (statusCode! >= 500) {
      return '服务器错误 (${statusCode!})';
    }

    return '$statusCode!';
  }

  /// 获取格式化的响应体
  String get formattedBody {
    if (body == null) return '';

    try {
      // 尝试格式化为 JSON
      final jsonObj = jsonDecode(body!);
      return const JsonEncoder.withIndent('  ').convert(jsonObj);
    } catch (e) {
      // 非 JSON 格式，直接返回
      return body!;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'statusCode': statusCode,
      'headers': headers,
      'body': body,
      'durationMs': durationMs,
      'error': error,
    };
  }
}
