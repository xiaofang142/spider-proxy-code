import 'dart:convert';

/// HAR (HTTP Archive) 格式导出器
///
/// HAR 是一种基于 JSON 的 HTTP 事务存档格式
/// 规范：http://www.softwareishard.com/blog/har-12-spec/
class HarExporter {
  /// 导出抓包数据为 HAR 格式
  static String export(List<CaptureItem> captures) {
    final har = {
      'log': {
        'version': '1.2',
        'creator': {
          'name': 'Spider Proxy',
          'version': '1.0.0',
        },
        'browser': {
          'name': 'Spider Proxy',
          'version': '1.0.0',
        },
        'entries': captures.map(_convertEntry).toList(),
      },
    };

    return JsonEncoder.withIndent('  ').convert(har);
  }

  static Map<String, dynamic> _convertEntry(CaptureItem capture) {
    final startTime = capture.timestamp.toIso8601String();

    return {
      'startedDateTime': startTime,
      'time': capture.duration ?? 0,
      'request': {
        'method': capture.method,
        'url': capture.url,
        'httpVersion': 'HTTP/1.1',
        'headers': _convertHeaders(capture.requestHeaders ?? {}),
        'queryString': [],
        'cookies': [],
        'headersSize': -1,
        'bodySize': capture.requestSize ?? 0,
        'totalSize': capture.requestSize ?? 0,
      },
      'response': {
        'status': capture.statusCode,
        'statusText': _getStatusText(capture.statusCode),
        'httpVersion': 'HTTP/1.1',
        'headers': _convertHeaders(capture.responseHeaders ?? {}),
        'cookies': [],
        'content': {
          'size': capture.responseSize ?? 0,
          'mimeType': capture.mimeType ?? 'application/octet-stream',
        },
        'headersSize': -1,
        'bodySize': capture.responseSize ?? 0,
        'totalSize': capture.responseSize ?? 0,
      },
      'cache': {},
      'timings': {
        'send': 0,
        'receive': capture.duration ?? 0,
        'wait': capture.duration ?? 0,
      },
      'time': capture.duration ?? 0,
    };
  }

  static List<Map<String, dynamic>> _convertHeaders(Map<String, String> headers) {
    return headers.entries.map((e) {
      return {'name': e.key, 'value': e.value};
    }).toList();
  }

  static String _getStatusText(int statusCode) {
    switch (statusCode) {
      case 200:
        return 'OK';
      case 201:
        return 'Created';
      case 204:
        return 'No Content';
      case 301:
        return 'Moved Permanently';
      case 302:
        return 'Found';
      case 304:
        return 'Not Modified';
      case 400:
        return 'Bad Request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not Found';
      case 500:
        return 'Internal Server Error';
      case 502:
        return 'Bad Gateway';
      case 503:
        return 'Service Unavailable';
      default:
        return 'Unknown';
    }
  }
}

/// 抓包项目模型
class CaptureItem {
  final String id;
  final String method;
  final String url;
  final int statusCode;
  final int? requestSize;
  final int? responseSize;
  final Map<String, String>? requestHeaders;
  final Map<String, String>? responseHeaders;
  final String? mimeType;
  final DateTime timestamp;
  final int? duration;

  const CaptureItem({
    required this.id,
    required this.method,
    required this.url,
    required this.statusCode,
    this.requestSize,
    this.responseSize,
    this.requestHeaders,
    this.responseHeaders,
    this.mimeType,
    required this.timestamp,
    this.duration,
  });
}
