import 'dart:convert';

/// 流量记录数据模型
class TrafficRecord {
  final String id;
  final DateTime timestamp;
  final String method;
  final String url;
  final String host;
  final String path;
  final int statusCode;
  final int requestSize;
  final int responseSize;
  final int durationMs;
  final String? requestType;
  final String? responseType;
  final bool isHttps;
  final String? clientIp;
  final int? port;

  TrafficRecord({
    required this.id,
    required this.timestamp,
    required this.method,
    required this.url,
    required this.host,
    required this.path,
    this.statusCode = 0,
    this.requestSize = 0,
    this.responseSize = 0,
    this.durationMs = 0,
    this.requestType,
    this.responseType,
    this.isHttps = false,
    this.clientIp,
    this.port,
  });

  /// 从 JSON 创建对象
  factory TrafficRecord.fromJson(Map<String, dynamic> json) {
    return TrafficRecord(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      method: json['method'] as String,
      url: json['url'] as String,
      host: json['host'] as String,
      path: json['path'] as String,
      statusCode: json['statusCode'] as int? ?? 0,
      requestSize: json['requestSize'] as int? ?? 0,
      responseSize: json['responseSize'] as int? ?? 0,
      durationMs: json['durationMs'] as int? ?? 0,
      requestType: json['requestType'] as String?,
      responseType: json['responseType'] as String?,
      isHttps: json['isHttps'] as bool? ?? false,
      clientIp: json['clientIp'] as String?,
      port: json['port'] as int?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'method': method,
      'url': url,
      'host': host,
      'path': path,
      'statusCode': statusCode,
      'requestSize': requestSize,
      'responseSize': responseSize,
      'durationMs': durationMs,
      'requestType': requestType,
      'responseType': responseType,
      'isHttps': isHttps,
      'clientIp': clientIp,
      'port': port,
    };
  }

  /// 转换为 JSON 字符串
  String toJsonString() => jsonEncode(toJson());

  /// 从 JSON 字符串创建对象
  static TrafficRecord fromJsonString(String jsonString) {
    return TrafficRecord.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  /// 创建副本
  TrafficRecord copyWith({
    String? id,
    DateTime? timestamp,
    String? method,
    String? url,
    String? host,
    String? path,
    int? statusCode,
    int? requestSize,
    int? responseSize,
    int? durationMs,
    String? requestType,
    String? responseType,
    bool? isHttps,
    String? clientIp,
    int? port,
  }) {
    return TrafficRecord(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      method: method ?? this.method,
      url: url ?? this.url,
      host: host ?? this.host,
      path: path ?? this.path,
      statusCode: statusCode ?? this.statusCode,
      requestSize: requestSize ?? this.requestSize,
      responseSize: responseSize ?? this.responseSize,
      durationMs: durationMs ?? this.durationMs,
      requestType: requestType ?? this.requestType,
      responseType: responseType ?? this.responseType,
      isHttps: isHttps ?? this.isHttps,
      clientIp: clientIp ?? this.clientIp,
      port: port ?? this.port,
    );
  }

  @override
  String toString() {
    return 'TrafficRecord(id: $id, method: $method, url: $url, status: $statusCode)';
  }
}
