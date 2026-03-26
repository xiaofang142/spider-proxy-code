/// 请求体/响应体替换引擎
///
/// 支持 Map Local (本地文件替换) 和 Map Remote (远程响应替换)
library body_mapper;

import 'dart:convert';
import 'dart:io';

/// 请求体/响应体替换引擎
class BodyMapper {
  final List<BodyMapperRule> _rules = [];
  final BodyCache _cache = BodyCache();

  /// 是否启用
  bool _enabled = true;

  /// 获取启用状态
  bool get enabled => _enabled;

  /// 获取所有规则
  List<BodyMapperRule> get rules => List.unmodifiable(_rules);

  /// 启用替换引擎
  void enable() {
    _enabled = true;
  }

  /// 禁用替换引擎
  void disable() {
    _enabled = false;
  }

  /// 添加规则
  void addRule(BodyMapperRule rule) {
    _rules.add(rule);
  }

  /// 移除规则
  void removeRule(String ruleId) {
    _rules.removeWhere((rule) => rule.id == ruleId);
  }

  /// 更新规则状态
  void toggleRule(String ruleId, bool enabled) {
    final index = _rules.indexWhere((rule) => rule.id == ruleId);
    if (index >= 0) {
      final rule = _rules[index];
      _rules[index] = BodyMapperRule(
        id: rule.id,
        name: rule.name,
        enabled: enabled,
        type: rule.type,
        condition: rule.condition,
        localPath: rule.localPath,
        remoteUrl: rule.remoteUrl,
        mapTarget: rule.mapTarget,
      );
    }
  }

  /// 清除所有规则
  void clearRules() {
    _rules.clear();
  }

  /// 处理请求体
  Future<String?> mapRequestBody(
    String url,
    String method,
    String body,
  ) async {
    if (!_enabled) return null;

    for (final rule in _rules) {
      if (!rule.enabled) continue;
      if (rule.mapTarget != MapTarget.request) continue;

      if (rule.matches(url, method)) {
        return await rule.apply(body);
      }
    }

    return null;
  }

  /// 处理响应体
  Future<String?> mapResponseBody(
    String url,
    int statusCode,
    String body,
  ) async {
    if (!_enabled) return null;

    for (final rule in _rules) {
      if (!rule.enabled) continue;
      if (rule.mapTarget != MapTarget.response) continue;

      if (rule.matches(url, 'GET')) {
        return await rule.apply(body);
      }
    }

    return null;
  }

  /// 导入规则从 JSON
  void importRules(List<Map<String, dynamic>> jsonList) {
    for (final json in jsonList) {
      _rules.add(BodyMapperRule.fromJson(json));
    }
  }

  /// 导出规则为 JSON
  List<Map<String, dynamic>> exportRules() {
    return _rules.map((rule) => rule.toJson()).toList();
  }
}

/// 替换规则类型
enum BodyMapType {
  /// Map Local: 使用本地文件替换
  local,

  /// Map Remote: 使用远程响应替换
  remote,
}

/// 映射目标
enum MapTarget {
  /// 替换请求体
  request,

  /// 替换响应体
  response,
}

/// 匹配条件
class MatchCondition {
  final String? urlPattern;
  final String? urlContains;
  final String? urlRegex;
  final String? method;
  final String? hostEquals;
  final String? hostContains;

  const MatchCondition({
    this.urlPattern,
    this.urlContains,
    this.urlRegex,
    this.method,
    this.hostEquals,
    this.hostContains,
  });

  bool matches(String url, String method) {
    // 匹配方法
    if (method != null && this.method != null) {
      if (method.toUpperCase() != this.method!.toUpperCase()) {
        return false;
      }
    }

    // 匹配 URL 模式
    if (urlPattern != null && !url.contains(urlPattern!)) {
      return false;
    }

    // 匹配 URL 包含
    if (urlContains != null && !url.contains(urlContains!)) {
      return false;
    }

    // 匹配 URL 正则
    if (urlRegex != null) {
      final regex = RegExp(urlRegex!);
      if (!regex.hasMatch(url)) {
        return false;
      }
    }

    // 匹配域名
    if (hostEquals != null || hostContains != null) {
      try {
        final uri = Uri.parse(url);
        final host = uri.host.toLowerCase();

        if (hostEquals != null && host != hostEquals!.toLowerCase()) {
          return false;
        }

        if (hostContains != null && !host.contains(hostContains!.toLowerCase())) {
          return false;
        }
      } catch (e) {
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
      if (hostEquals != null) 'hostEquals': hostEquals,
      if (hostContains != null) 'hostContains': hostContains,
    };
  }

  factory MatchCondition.fromJson(Map<String, dynamic> json) {
    return MatchCondition(
      urlPattern: json['urlPattern'] as String?,
      urlContains: json['urlContains'] as String?,
      urlRegex: json['urlRegex'] as String?,
      method: json['method'] as String?,
      hostEquals: json['hostEquals'] as String?,
      hostContains: json['hostContains'] as String?,
    );
  }
}

/// 替换规则
class BodyMapperRule {
  final String id;
  final String name;
  final bool enabled;
  final BodyMapType type;
  final MatchCondition condition;
  final String? localPath;
  final String? remoteUrl;
  final MapTarget mapTarget;
  final String? description;

  BodyMapperRule({
    required this.id,
    required this.name,
    this.enabled = true,
    required this.type,
    required this.condition,
    this.localPath,
    this.remoteUrl,
    required this.mapTarget,
    this.description,
  });

  /// 检查是否匹配
  bool matches(String url, String method) {
    return enabled && condition.matches(url, method);
  }

  /// 应用替换
  Future<String?> apply(String originalBody) async {
    switch (type) {
      case BodyMapType.local:
        if (localPath == null) return null;
        return await _applyLocal(localPath!);
      case BodyMapType.remote:
        if (remoteUrl == null) return null;
        return await _applyRemote(remoteUrl!);
    }
  }

  /// 应用本地文件替换
  Future<String?> _applyLocal(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        print('[BodyMapper] File not found: $path');
        return null;
      }
      return await file.readAsString();
    } catch (e) {
      print('[BodyMapper] Error reading file: $e');
      return null;
    }
  }

  /// 应用远程响应替换
  Future<String?> _applyRemote(String url) async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close();
      return body;
    } catch (e) {
      print('[BodyMapper] Error fetching remote: $e');
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'enabled': enabled,
      'type': type.name,
      'condition': condition.toJson(),
      if (localPath != null) 'localPath': localPath,
      if (remoteUrl != null) 'remoteUrl': remoteUrl,
      'mapTarget': mapTarget.name,
      if (description != null) 'description': description,
    };
  }

  factory BodyMapperRule.fromJson(Map<String, dynamic> json) {
    return BodyMapperRule(
      id: json['id'] as String,
      name: json['name'] as String,
      enabled: json['enabled'] as bool? ?? true,
      type: BodyMapType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => BodyMapType.local,
      ),
      condition: MatchCondition.fromJson(json['condition'] as Map<String, dynamic>),
      localPath: json['localPath'] as String?,
      remoteUrl: json['remoteUrl'] as String?,
      mapTarget: MapTarget.values.firstWhere(
        (e) => e.name == json['mapTarget'],
        orElse: () => MapTarget.response,
      ),
      description: json['description'] as String?,
    );
  }
}

/// 缓存管理器
class BodyCache {
  final Map<String, _CacheEntry> _cache = {};
  final Map<String, File> _watchedFiles = {};

  /// 获取文件内容（带缓存）
  Future<String> getFileContent(String path) async {
    final now = DateTime.now();

    // 检查缓存
    if (_cache.containsKey(path)) {
      final entry = _cache[path]!;
      // 缓存 5 秒有效期
      if (now.difference(entry.cachedAt).inSeconds < 5) {
        return entry.content;
      }
    }

    // 读取文件
    final file = File(path);
    final content = await file.readAsString();

    // 更新缓存
    _cache[path] = _CacheEntry(content, now);

    // 设置文件监听
    if (!_watchedFiles.containsKey(path)) {
      _watchedFiles[path] = file;
    }

    return content;
  }

  /// 清除缓存
  void invalidate(String path) {
    _cache.remove(path);
  }

  /// 清除所有缓存
  void clear() {
    _cache.clear();
  }

  /// 获取缓存统计
  int get cacheSize => _cache.length;
}

class _CacheEntry {
  final String content;
  final DateTime cachedAt;

  _CacheEntry(this.content, this.cachedAt);
}
