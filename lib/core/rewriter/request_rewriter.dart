/// 请求重写引擎
///
/// 支持请求头修改、响应头修改、URL 重定向等功能
library request_rewriter;

/// 请求重写规则
class RequestRewriteRule {
  final String id;
  final String name;
  final bool enabled;
  final RewriteRuleType type;
  final MatchCondition condition;
  final RewriteAction action;

  RequestRewriteRule({
    required this.id,
    required this.name,
    this.enabled = true,
    required this.type,
    required this.condition,
    required this.action,
  });

  /// 检查请求是否匹配规则
  bool matches(String url, String method, Map<String, String> headers) {
    if (!enabled) return false;
    return condition.matches(url, method, headers);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'enabled': enabled,
      'type': type.name,
      'condition': condition.toJson(),
      'action': action.toJson(),
    };
  }

  factory RequestRewriteRule.fromJson(Map<String, dynamic> json) {
    return RequestRewriteRule(
      id: json['id'] as String,
      name: json['name'] as String,
      enabled: json['enabled'] as bool? ?? true,
      type: RewriteRuleType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => RewriteRuleType.modifyHeader,
      ),
      condition: MatchCondition.fromJson(json['condition'] as Map<String, dynamic>),
      action: RewriteAction.fromJson(json['action'] as Map<String, dynamic>),
    );
  }
}

/// 重写规则类型
enum RewriteRuleType {
  /// 修改请求头
  modifyHeader,

  /// 修改响应头
  modifyResponseHeader,

  /// URL 重定向
  redirectUrl,

  /// 修改请求体
  modifyBody,

  /// 修改响应体
  modifyResponseBody,
}

/// 匹配条件
class MatchCondition {
  final String? urlPattern;
  final String? urlContains;
  final String? urlRegex;
  final String? method;
  final Map<String, String>? headers;
  final String? hostContains;
  final String? hostEquals;

  const MatchCondition({
    this.urlPattern,
    this.urlContains,
    this.urlRegex,
    this.method,
    this.headers,
    this.hostContains,
    this.hostEquals,
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
    if (method != null && !method.equalsIgnorecase(method)) {
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

extension on String {
  equalsIgnorecase(String other) {
    return toLowerCase() == other.toLowerCase();
  }
}

/// 重写动作
class RewriteAction {
  final ActionType type;
  final String? headerName;
  final String? headerValue;
  final String? redirectUrl;
  final String? newValue;
  final bool remove;

  const RewriteAction({
    required this.type,
    this.headerName,
    this.headerValue,
    this.redirectUrl,
    this.newValue,
    this.remove = false,
  });

  /// 添加/修改请求头
  factory RewriteAction.setHeader(String name, String value) {
    return RewriteAction(
      type: ActionType.setHeader,
      headerName: name,
      headerValue: value,
    );
  }

  /// 删除请求头
  factory RewriteAction.removeHeader(String name) {
    return RewriteAction(
      type: ActionType.removeHeader,
      headerName: name,
      remove: true,
    );
  }

  /// URL 重定向
  factory RewriteAction.redirect(String url) {
    return RewriteAction(
      type: ActionType.redirect,
      redirectUrl: url,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      if (headerName != null) 'headerName': headerName,
      if (headerValue != null) 'headerValue': headerValue,
      if (redirectUrl != null) 'redirectUrl': redirectUrl,
      if (newValue != null) 'newValue': newValue,
      if (remove) 'remove': remove,
    };
  }

  factory RewriteAction.fromJson(Map<String, dynamic> json) {
    return RewriteAction(
      type: ActionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ActionType.setHeader,
      ),
      headerName: json['headerName'] as String?,
      headerValue: json['headerValue'] as String?,
      redirectUrl: json['redirectUrl'] as String?,
      newValue: json['newValue'] as String?,
      remove: json['remove'] as bool? ?? false,
    );
  }
}

/// 动作类型
enum ActionType {
  /// 设置请求头
  setHeader,

  /// 删除请求头
  removeHeader,

  /// URL 重定向
  redirect,

  /// 替换内容
  replace,
}

/// 重写引擎
class RequestRewriter {
  final List<RequestRewriteRule> _rules = [];

  /// 添加重写规则
  void addRule(RequestRewriteRule rule) {
    _rules.add(rule);
  }

  /// 移除重写规则
  void removeRule(String ruleId) {
    _rules.removeWhere((rule) => rule.id == ruleId);
  }

  /// 更新规则状态
  void toggleRule(String ruleId, bool enabled) {
    for (final rule in _rules) {
      if (rule.id == ruleId) {
        // 更新规则状态（需要创建一个新对象）
        final index = _rules.indexWhere((r) => r.id == ruleId);
        if (index >= 0) {
          _rules[index] = RequestRewriteRule(
            id: rule.id,
            name: rule.name,
            enabled: enabled,
            type: rule.type,
            condition: rule.condition,
            action: rule.action,
          );
        }
        break;
      }
    }
  }

  /// 获取所有规则
  List<RequestRewriteRule> get rules => List.unmodifiable(_rules);

  /// 清除所有规则
  void clearRules() {
    _rules.clear();
  }

  /// 重写请求头
  Map<String, String> rewriteRequestHeaders(
    String url,
    String method,
    Map<String, String> headers,
  ) {
    final modifiedHeaders = Map<String, String>.from(headers);

    for (final rule in _rules) {
      if (!rule.enabled) continue;
      if (rule.type != RewriteRuleType.modifyHeader) continue;
      if (!rule.matches(url, method, headers)) continue;

      final action = rule.action;
      if (action.type == ActionType.setHeader &&
          action.headerName != null &&
          action.headerValue != null) {
        modifiedHeaders[action.headerName!] = action.headerValue!;
      } else if (action.type == ActionType.removeHeader &&
          action.headerName != null) {
        modifiedHeaders.remove(action.headerName!);
      }
    }

    return modifiedHeaders;
  }

  /// 重写响应头
  Map<String, String> rewriteResponseHeaders(
    String url,
    int statusCode,
    Map<String, String> headers,
  ) {
    final modifiedHeaders = Map<String, String>.from(headers);

    for (final rule in _rules) {
      if (!rule.enabled) continue;
      if (rule.type != RewriteRuleType.modifyResponseHeader) continue;
      if (!rule.matches(url, 'GET', headers)) continue;

      final action = rule.action;
      if (action.type == ActionType.setHeader &&
          action.headerName != null &&
          action.headerValue != null) {
        modifiedHeaders[action.headerName!] = action.headerValue!;
      } else if (action.type == ActionType.removeHeader &&
          action.headerName != null) {
        modifiedHeaders.remove(action.headerName!);
      }
    }

    return modifiedHeaders;
  }

  /// 重写 URL
  String? rewriteUrl(String url, String method, Map<String, String> headers) {
    for (final rule in _rules) {
      if (!rule.enabled) continue;
      if (rule.type != RewriteRuleType.redirectUrl) continue;
      if (!rule.matches(url, method, headers)) continue;

      return rule.action.redirectUrl;
    }

    return null;
  }

  /// 导入规则从 JSON
  void importRules(List<Map<String, dynamic>> jsonList) {
    for (final json in jsonList) {
      _rules.add(RequestRewriteRule.fromJson(json));
    }
  }

  /// 导出规则为 JSON
  List<Map<String, dynamic>> exportRules() {
    return _rules.map((rule) => rule.toJson()).toList();
  }
}
