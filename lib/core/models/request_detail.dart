import 'dart:convert';

/// 请求详情数据模型
class RequestDetail {
  final String id;
  final String trafficRecordId;
  final DateTime timestamp;
  final String method;
  final Uri uri;
  final Map<String, String> headers;
  final List<String> cookies;
  final String? body;
  final int contentLength;
  final String? contentType;
  final String? userAgent;
  final String? referer;
  final String? origin;
  final Map<String, String>? queryParams;
  final String? clientIp;
  final int? clientPort;

  RequestDetail({
    required this.id,
    required this.trafficRecordId,
    required this.timestamp,
    required this.method,
    required this.uri,
    this.headers = const {},
    this.cookies = const [],
    this.body,
    this.contentLength = 0,
    this.contentType,
    this.userAgent,
    this.referer,
    this.origin,
    this.queryParams,
    this.clientIp,
    this.clientPort,
  });

  /// 从 JSON 创建对象
  factory RequestDetail.fromJson(Map<String, dynamic> json) {
    return RequestDetail(
      id: json['id'] as String,
      trafficRecordId: json['trafficRecordId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      method: json['method'] as String,
      uri: Uri.parse(json['uri'] as String),
      headers: Map<String, String>.from(json['headers'] as Map? ?? {}),
      cookies: List<String>.from(json['cookies'] as List? ?? []),
      body: json['body'] as String?,
      contentLength: json['contentLength'] as int? ?? 0,
      contentType: json['contentType'] as String?,
      userAgent: json['userAgent'] as String?,
      referer: json['referer'] as String?,
      origin: json['origin'] as String?,
      queryParams: json['queryParams'] != null
          ? Map<String, String>.from(json['queryParams'] as Map)
          : null,
      clientIp: json['clientIp'] as String?,
      clientPort: json['clientPort'] as int?,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trafficRecordId': trafficRecordId,
      'timestamp': timestamp.toIso8601String(),
      'method': method,
      'uri': uri.toString(),
      'headers': headers,
      'cookies': cookies,
      'body': body,
      'contentLength': contentLength,
      'contentType': contentType,
      'userAgent': userAgent,
      'referer': referer,
      'origin': origin,
      'queryParams': queryParams,
      'clientIp': clientIp,
      'clientPort': clientPort,
    };
  }

  /// 转换为 JSON 字符串
  String toJsonString() => jsonEncode(toJson());

  /// 从 JSON 字符串创建对象
  static RequestDetail fromJsonString(String jsonString) {
    return RequestDetail.fromJson(jsonDecode(jsonString) as Map<String, dynamic>);
  }

  /// 获取请求头中的特定值
  String? getHeader(String name) {
    return headers[name] ?? headers[name.toLowerCase()];
  }

  /// 检查是否包含特定请求头
  bool hasHeader(String name) {
    return headers.containsKey(name) || headers.containsKey(name.toLowerCase());
  }

  /// 创建副本
  RequestDetail copyWith({
    String? id,
    String? trafficRecordId,
    DateTime? timestamp,
    String? method,
    Uri? uri,
    Map<String, String>? headers,
    List<String>? cookies,
    String? body,
    int? contentLength,
    String? contentType,
    String? userAgent,
    String? referer,
    String? origin,
    Map<String, String>? queryParams,
    String? clientIp,
    int? clientPort,
  }) {
    return RequestDetail(
      id: id ?? this.id,
      trafficRecordId: trafficRecordId ?? this.trafficRecordId,
      timestamp: timestamp ?? this.timestamp,
      method: method ?? this.method,
      uri: uri ?? this.uri,
      headers: headers ?? this.headers,
      cookies: cookies ?? this.cookies,
      body: body ?? this.body,
      contentLength: contentLength ?? this.contentLength,
      contentType: contentType ?? this.contentType,
      userAgent: userAgent ?? this.userAgent,
      referer: referer ?? this.referer,
      origin: origin ?? this.origin,
      queryParams: queryParams ?? this.queryParams,
      clientIp: clientIp ?? this.clientIp,
      clientPort: clientPort ?? this.clientPort,
    );
  }

  @override
  String toString() {
    return 'RequestDetail(id: $id, method: $method, uri: $uri)';
  }
}
