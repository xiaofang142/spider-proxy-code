/// 断点调试引擎
///
/// 支持请求前断点和响应前断点
/// 允许在断点处暂停并修改请求/响应内容
library breakpoint_debugger;

/// 断点调试器
class BreakpointDebugger {
  final List<BreakpointRule> _rules = [];
  bool _enabled = true;

  /// 是否启用断点调试
  bool get enabled => _enabled;

  /// 获取所有断点规则
  List<BreakpointRule> get rules => List.unmodifiable(_rules);

  /// 当前暂停的请求
  BreakpointRequest? _pausedRequest;

  /// 当前暂停的响应
  BreakpointResponse? _pausedResponse;

  /// 启用断点调试
  void enable() {
    _enabled = true;
  }

  /// 禁用断点调试
  void disable() {
    _enabled = false;
  }

  /// 添加断点规则
  void addRule(BreakpointRule rule) {
    _rules.add(rule);
  }

  /// 移除断点规则
  void removeRule(String ruleId) {
    _rules.removeWhere((rule) => rule.id == ruleId);
  }

  /// 更新规则状态
  void toggleRule(String ruleId, bool enabled) {
    for (final rule in _rules) {
      if (rule.id == ruleId) {
        final index = _rules.indexWhere((r) => r.id == ruleId);
        if (index >= 0) {
          _rules[index] = BreakpointRule(
            id: rule.id,
            name: rule.name,
            enabled: enabled,
            breakpointType: rule.breakpointType,
            condition: rule.condition,
          );
        }
        break;
      }
    }
  }

  /// 清除所有规则
  void clearRules() {
    _rules.clear();
  }

  /// 检查请求是否应该断点
  bool shouldBreakForRequest(String url, String method, Map<String, String> headers) {
    if (!_enabled) return false;

    for (final rule in _rules) {
      if (!rule.enabled) continue;
      if (rule.breakpointType != BreakpointType.request) continue;
      if (rule.matches(url, method, headers)) {
        return true;
      }
    }
    return false;
  }

  /// 检查响应是否应该断点
  bool shouldBreakForResponse(String url, int statusCode, Map<String, String> headers) {
    if (!_enabled) return false;

    for (final rule in _rules) {
      if (!rule.enabled) continue;
      if (rule.breakpointType != BreakpointType.response) continue;
      if (rule.matchesForResponse(url, statusCode, headers)) {
        return true;
      }
    }
    return false;
  }

  /// 暂停请求
  void pauseRequest(String id, String url, String method, Map<String, String> headers, String body) {
    _pausedRequest = BreakpointRequest(
      id: id,
      url: url,
      method: method,
      headers: Map.from(headers),
      body: body,
      pausedAt: DateTime.now(),
    );
  }

  /// 暂停响应
  void pauseResponse(String id, String url, int statusCode, Map<String, String> headers, String body) {
    _pausedResponse = BreakpointResponse(
      id: id,
      url: url,
      statusCode: statusCode,
      headers: Map.from(headers),
      body: body,
      pausedAt: DateTime.now(),
    );
  }

  /// 获取暂停的请求
  BreakpointRequest? get pausedRequest => _pausedRequest;

  /// 获取暂停的响应
  BreakpointResponse? get pausedResponse => _pausedResponse;

  /// 继续请求
  BreakpointRequest? resumeRequest() {
    final request = _pausedRequest;
    _pausedRequest = null;
    return request;
  }

  /// 继续响应
  BreakpointResponse? resumeResponse() {
    final response = _pausedResponse;
    _pausedResponse = null;
    return response;
  }

  /// 修改并继续请求
  void modifyAndResumeRequest(String url, String method, Map<String, String> headers, String body) {
    _pausedRequest = _pausedRequest?.copyWith(
      url: url,
      method: method,
      headers: headers,
      body: body,
    );
  }

  /// 修改并继续请求（带返回值）
  void resumeRequestWithModifications({
    required String url,
    required String method,
    required Map<String, String> headers,
    required String body,
  }) {
    _pausedRequest = _pausedRequest?.copyWith(
      url: url,
      method: method,
      headers: headers,
      body: body,
    );
  }

  /// 修改并继续响应（带返回值）
  void resumeResponseWithModifications({
    required int statusCode,
    required Map<String, String> headers,
    required String body,
  }) {
    _pausedResponse = _pausedResponse?.copyWith(
      statusCode: statusCode,
      headers: headers,
      body: body,
    );
  }

  /// 修改并继续响应
  void modifyAndResumeResponse(String url, int statusCode, Map<String, String> headers, String body) {
    _pausedResponse = _pausedResponse?.copyWith(
      url: url,
      statusCode: statusCode,
      headers: headers,
      body: body,
    );
  }

  /// 取消请求
  void cancelRequest() {
    _pausedRequest = null;
  }

  /// 取消响应
  void cancelResponse() {
    _pausedResponse = null;
  }

  /// 导入规则从 JSON
  void importRules(List<Map<String, dynamic>> jsonList) {
    for (final json in jsonList) {
      _rules.add(BreakpointRule.fromJson(json));
    }
  }

  /// 导出规则为 JSON
  List<Map<String, dynamic>> exportRules() {
    return _rules.map((rule) => rule.toJson()).toList();
  }
}

/// 断点规则
class BreakpointRule {
  final String id;
  final String name;
  final bool enabled;
  final BreakpointType breakpointType;
  final MatchCondition condition;

  BreakpointRule({
    required this.id,
    required this.name,
    this.enabled = true,
    required this.breakpointType,
    required this.condition,
  });

  /// 检查请求是否匹配规则
  bool matches(String url, String method, Map<String, String> headers) {
    if (!enabled) return false;
    return condition.matches(url, method, headers);
  }

  /// 检查响应是否匹配规则
  bool matchesForResponse(String url, int statusCode, Map<String, String> headers) {
    if (!enabled) return false;

    // 检查状态码
    if (condition.statusCodeRange != null) {
      final range = condition.statusCodeRange!;
      if (statusCode < range.$1 || statusCode > range.$2) {
        return false;
      }
    }

    return condition.matches(url, 'GET', headers);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'enabled': enabled,
      'breakpointType': breakpointType.name,
      'condition': condition.toJson(),
    };
  }

  factory BreakpointRule.fromJson(Map<String, dynamic> json) {
    return BreakpointRule(
      id: json['id'] as String,
      name: json['name'] as String,
      enabled: json['enabled'] as bool? ?? true,
      breakpointType: BreakpointType.values.firstWhere(
        (e) => e.name == json['breakpointType'],
        orElse: () => BreakpointType.request,
      ),
      condition: MatchCondition.fromJson(json['condition'] as Map<String, dynamic>),
    );
  }

  /// 创建 URL 匹配的请求断点
  factory BreakpointRule.requestUrl(String name, String urlPattern) {
    return BreakpointRule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      breakpointType: BreakpointType.request,
      condition: MatchCondition.urlContains(urlPattern),
    );
  }

  /// 创建域名匹配的请求断点
  factory BreakpointRule.requestHost(String name, String hostPattern) {
    return BreakpointRule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      breakpointType: BreakpointType.request,
      condition: MatchCondition.hostContains(hostPattern),
    );
  }

  /// 创建状态码匹配的响应断点
  factory BreakpointRule.responseStatus(String name, int statusCode) {
    return BreakpointRule(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      breakpointType: BreakpointType.response,
      condition: MatchCondition(statusCodeRange: (statusCode, statusCode)),
    );
  }
}

/// 断点类型
enum BreakpointType {
  /// 请求前断点
  request,

  /// 响应前断点
  response,
}

/// 断点请求
class BreakpointRequest {
  final String id;
  final String url;
  final String method;
  final Map<String, String> headers;
  final String body;
  final DateTime pausedAt;

  BreakpointRequest({
    required this.id,
    required this.url,
    required this.method,
    required this.headers,
    required this.body,
    required this.pausedAt,
  });

  /// 获取暂停时长
  Duration get pausedDuration => DateTime.now().difference(pausedAt);

  /// 创建副本
  BreakpointRequest copyWith({
    String? id,
    String? url,
    String? method,
    Map<String, String>? headers,
    String? body,
    DateTime? pausedAt,
  }) {
    return BreakpointRequest(
      id: id ?? this.id,
      url: url ?? this.url,
      method: method ?? this.method,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      pausedAt: pausedAt ?? this.pausedAt,
    );
  }
}

/// 断点响应
class BreakpointResponse {
  final String id;
  final String url;
  final int statusCode;
  final Map<String, String> headers;
  final String body;
  final DateTime pausedAt;

  BreakpointResponse({
    required this.id,
    required this.url,
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.pausedAt,
  });

  /// 获取暂停时长
  Duration get pausedDuration => DateTime.now().difference(pausedAt);

  /// 创建副本
  BreakpointResponse copyWith({
    String? id,
    String? url,
    int? statusCode,
    Map<String, String>? headers,
    String? body,
    DateTime? pausedAt,
  }) {
    return BreakpointResponse(
      id: id ?? this.id,
      url: url ?? this.url,
      statusCode: statusCode ?? this.statusCode,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      pausedAt: pausedAt ?? this.pausedAt,
    );
  }
}

/// 匹配条件（与 request_rewriter 共享）
class MatchCondition {
  final String? urlPattern;
  final String? urlContains;
  final String? urlRegex;
  final String? method;
  final Map<String, String>? headers;
  final String? hostContains;
  final String? hostEquals;
  final (int, int)? statusCodeRange;

  const MatchCondition({
    this.urlPattern,
    this.urlContains,
    this.urlRegex,
    this.method,
    this.headers,
    this.hostContains,
    this.hostEquals,
    this.statusCodeRange,
  });

  bool matches(String url, String method, Map<String, String> headers) {
    // 匹配 URL 模式
    if (urlPattern != null && !url.contains(urlPattern!)) {
      return false;
    }

    // 匹配 URL 包含
    if (urlContains != null && !url.toLowerCase().contains(urlContains!.toLowerCase())) {
      return false;
    }

    // 匹配 URL 正则
    if (urlRegex != null) {
      final regex = RegExp(urlRegex!);
      if (!regex.hasMatch(url)) {
        return false;
      }
    }

    // 匹配 HTTP 方法
    if (method != null && method.toLowerCase() != method.toLowerCase()) {
      return false;
    }

    // 匹配请求头
    if (headers != null) {
      for (final entry in headers!.entries) {
        final headerValue = headers[entry.key];
        if (headerValue == null || !headerValue.contains(entry.value)) {
          return false;
        }
      }
    }

    // 匹配域名
    final uri = Uri.tryParse(url);
    if (uri != null) {
      if (hostEquals != null && uri.host != hostEquals) {
        return false;
      }
      if (hostContains != null && !uri.host.contains(hostContains)) {
        return false;
      }
    }

    return true;
  }

  Map<String, dynamic> toJson() {
    return {
      if (urlPattern != null) 'urlPattern': urlPattern,
      if (urlContains != null) 'urlContains': urlContains,
      if (urlRegex != null) 'urlRegex': urlRegex,
      if (method != null) 'method': method,
      if (headers != null) 'headers': headers,
      if (hostContains != null) 'hostContains': hostContains,
      if (hostEquals != null) 'hostEquals': hostEquals,
      if (statusCodeRange != null) 'statusCodeRange': [statusCodeRange!.$1, statusCodeRange!.$2],
    };
  }

  factory MatchCondition.fromJson(Map<String, dynamic> json) {
    return MatchCondition(
      urlPattern: json['urlPattern'] as String?,
      urlContains: json['urlContains'] as String?,
      urlRegex: json['urlRegex'] as String?,
      method: json['method'] as String?,
      headers: json['headers'] as Map<String, String>?,
      hostContains: json['hostContains'] as String?,
      hostEquals: json['hostEquals'] as String?,
      statusCodeRange: json['statusCodeRange'] != null
          ? (json['statusCodeRange'][0] as int, json['statusCodeRange'][1] as int)
          : null,
    );
  }

  /// 创建 URL 包含匹配条件
  factory MatchCondition.urlContains(String value) {
    return MatchCondition(urlContains: value);
  }

  /// 创建域名匹配条件
  factory MatchCondition.hostContains(String value) {
    return MatchCondition(hostContains: value);
  }

  /// 创建方法匹配条件
  factory MatchCondition.method(String value) {
    return MatchCondition(method: value);
  }
}
