import 'dart:convert';

/// 响应详情数据模型
class ResponseDetail {
  final String id;
  final String trafficRecordId;
  final DateTime timestamp;
  final int statusCode;
  final String? statusMessage;
  final Map<String, String> headers;
  final List<String> cookies;
  final String? body;
  final int contentLength;
  final String? contentType;
  final String? server;
  final DateTime? date;
  final DateTime? lastModified;
  final String? etag;
  final String? cacheControl;
  final int? responseTime;
  final bool? isRedirect;
  final String? redirectLocation;

  ResponseDetail({
    required this.id,
    required this.trafficRecordId,
    required this.timestamp,
    required this.statusCode,
    this.statusMessage,
    this.headers = const {},
    this.cookies = const [],
    this.body,
    this.contentLength = 0,
    this.contentType,
    this.server,
    this.date,
    this.lastModified,
    this.etag,
    this.cacheControl,
    this.responseTime,
    this.isRedirect,
    this.redirectLocation,
  });

  /// 从 JSON 创建对象
  factory ResponseDetail.fromJson(Map<String, dynamic> json) {
    return ResponseDetail(
      id: json['id'] as String,
      trafficRecordId: json['trafficRecordId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      statusCode: json['statusCode'] as int,
      statusMessage: json['statusMessage'] as String?,
      headers: Map<String, String>.from(json['headers'] as Map? ?? {}),
      cookies: List<String>.from(json['cookies'] as List? ?? []),
      body: json['body'] as String?,
      contentLength: json['contentLength'] as int? ?? 0,
      contentType: json['contentType'] as String?,
      server: json['server'] as String?,
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : null,
      lastModified: json['lastModified'] != null
          ? DateTime.parse(json['lastModified'] as String)
          : null,
      etag: json['etag'] as String?,
      cacheControl: json['cacheControl'] as String?,
      responseTime: json['responseTime'] as int?,
      isRedirect: json['isRedirect'] as bool?,
      redirectLocation: json['redirectLocation'] as String?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trafficRecordId': trafficRecordId,
      'timestamp': timestamp.toIso8601String(),
      'statusCode': statusCode,
      'statusMessage': statusMessage,
      'headers': headers,
      'cookies': cookies,
      'body': body,
      'contentLength': contentLength,
      'contentType': contentType,
      'server': server,
      'date': date?.toIso8601String(),
      'lastModified': lastModified?.toIso8601String(),
      'etag': etag,
      'cacheControl': cacheControl,
      'responseTime': responseTime,
      'isRedirect': isRedirect,
      'redirectLocation': redirectLocation,
    };
  }

  /// 转换为 JSON 字符串
  String toJsonString() => jsonEncode(toJson());

  /// 从 JSON 字符串创建对象
  static ResponseDetail fromJsonString(String jsonString) {
    return ResponseDetail.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  /// 获取响应头中的特定值
  String? getHeader(String name) {
    return headers[name] ?? headers[name.toLowerCase()];
  }

  /// 检查是否包含特定响应头
  bool hasHeader(String name) {
    return headers.containsKey(name) || headers.containsKey(name.toLowerCase());
  }

  /// 检查是否是成功响应
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// 检查是否是重定向
  bool get isRedirect => isRedirect ?? (statusCode >= 300 && statusCode < 400);

  /// 检查是否是客户端错误
  bool get isClientError => statusCode >= 400 && statusCode < 500;

  /// 检查是否是服务器错误
  bool get isServerError => statusCode >= 500 && statusCode < 600;

  /// 创建副本
  ResponseDetail copyWith({
    String? id,
    String? trafficRecordId,
    DateTime? timestamp,
    int? statusCode,
    String? statusMessage,
    Map<String, String>? headers,
    List<String>? cookies,
    String? body,
    int? contentLength,
    String? contentType,
    String? server,
    DateTime? date,
    DateTime? lastModified,
    String? etag,
    String? cacheControl,
    int? responseTime,
    bool? isRedirect,
    String? redirectLocation,
  }) {
    return ResponseDetail(
      id: id ?? this.id,
      trafficRecordId: trafficRecordId ?? this.trafficRecordId,
      timestamp: timestamp ?? this.timestamp,
      statusCode: statusCode ?? this.statusCode,
      statusMessage: statusMessage ?? this.statusMessage,
      headers: headers ?? this.headers,
      cookies: cookies ?? this.cookies,
      body: body ?? this.body,
      contentLength: contentLength ?? this.contentLength,
      contentType: contentType ?? this.contentType,
      server: server ?? this.server,
      date: date ?? this.date,
      lastModified: lastModified ?? this.lastModified,
      etag: etag ?? this.etag,
      cacheControl: cacheControl ?? this.cacheControl,
      responseTime: responseTime ?? this.responseTime,
      isRedirect: isRedirect ?? this.isRedirect,
      redirectLocation: redirectLocation ?? this.redirectLocation,
    );
  }

  @override
  String toString() {
    return 'ResponseDetail(id: $id, status: $statusCode, contentLength: $contentLength)';
  }
}
