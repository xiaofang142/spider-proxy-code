/// 脚本引擎
///
/// 支持 JavaScript 脚本执行
/// 用于请求/响应拦截和修改
library script_engine;

/// 脚本引擎
class ScriptEngine {
  final List<Script> _scripts = [];
  bool _enabled = true;

  /// 是否启用脚本引擎
  bool get enabled => _enabled;

  /// 获取所有脚本
  List<Script> get scripts => List.unmodifiable(_scripts);

  /// 启用脚本引擎
  void enable() {
    _enabled = true;
  }

  /// 禁用脚本引擎
  void disable() {
    _enabled = false;
  }

  /// 添加脚本
  void addScript(Script script) {
    _scripts.add(script);
  }

  /// 移除脚本
  void removeScript(String scriptId) {
    _scripts.removeWhere((script) => script.id == scriptId);
  }

  /// 更新脚本状态
  void toggleScript(String scriptId, bool enabled) {
    for (final script in _scripts) {
      if (script.id == scriptId) {
        final index = _scripts.indexWhere((s) => s.id == scriptId);
        if (index >= 0) {
          _scripts[index] = Script(
            id: script.id,
            name: script.name,
            enabled: enabled,
            code: script.code,
            type: script.type,
            description: script.description,
          );
        }
        break;
      }
    }
  }

  /// 清除所有脚本
  void clearScripts() {
    _scripts.clear();
  }

  /// 执行请求拦截脚本
  ScriptContext? executeOnRequest(String url, String method, Map<String, String> headers, String body) {
    if (!_enabled) return null;

    for (final script in _scripts) {
      if (!script.enabled) continue;

      try {
        final context = ScriptContext(
          url: url,
          method: method,
          headers: Map.from(headers),
          body: body,
        );

        // 简单实现：在实际应用中需要 JavaScript 引擎
        // 这里使用简化的脚本执行逻辑
        final result = _executeScript(script.code, context);

        if (result.modified) {
          return result;
        }
      } catch (e) {
        print('[ScriptEngine] Error executing script "${script.name}": $e');
      }
    }

    return null;
  }

  /// 执行响应拦截脚本
  ScriptContext? executeOnResponse(String url, int statusCode, Map<String, String> headers, String body) {
    if (!_enabled) return null;

    for (final script in _scripts) {
      if (!script.enabled) continue;

      try {
        final context = ScriptContext(
          url: url,
          statusCode: statusCode,
          headers: Map.from(headers),
          body: body,
        );

        final result = _executeScript(script.code, context);

        if (result.modified) {
          return result;
        }
      } catch (e) {
        print('[ScriptEngine] Error executing script "${script.name}": $e');
      }
    }

    return null;
  }

  /// 执行脚本（简化实现）
  ScriptContext _executeScript(String code, ScriptContext context) {
    // TODO: 集成 JavaScript 引擎 (如 dart_eval 或外部 JS 引擎)
    // 这里仅做简化实现

    // 在实际应用中，应该：
    // 1. 解析 JavaScript 代码
    // 2. 创建 sandbox 环境
    // 3. 执行脚本并获取结果

    // 简化实现：检查代码中是否有特殊标记
    if (code.contains('// @modify-header')) {
      // 模拟修改 Header
      final lines = code.split('\n');
      for (final line in lines) {
        if (line.startsWith('// @modify-header:')) {
          final parts = line.substring(18).split('=');
          if (parts.length == 2) {
            context.headers[parts[0].trim()] = parts[1].trim();
            context.modified = true;
          }
        }
      }
    }

    if (code.contains('// @modify-body')) {
      // 模拟修改 Body
      final lines = code.split('\n');
      for (final line in lines) {
        if (line.startsWith('// @modify-body:')) {
          context.body = line.substring(17).trim();
          context.modified = true;
        }
      }
    }

    if (code.contains('// @abort')) {
      context.aborted = true;
      context.modified = true;
    }

    return context;
  }

  /// 导入脚本从 JSON
  void importScripts(List<Map<String, dynamic>> jsonList) {
    for (final json in jsonList) {
      _scripts.add(Script.fromJson(json));
    }
  }

  /// 导出脚本为 JSON
  List<Map<String, dynamic>> exportScripts() {
    return _scripts.map((script) => script.toJson()).toList();
  }

  /// 加载内置模板
  void loadBuiltInTemplates() {
    _scripts.addAll(BuiltInScripts.getAll());
  }
}

/// 脚本类型
enum ScriptType {
  /// 请求拦截
  onRequest,

  /// 响应拦截
  onResponse,

  /// 通用脚本
  universal,
}

/// 脚本
class Script {
  final String id;
  final String name;
  final bool enabled;
  final String code;
  final ScriptType type;
  final String? description;

  Script({
    required this.id,
    required this.name,
    this.enabled = true,
    required this.code,
    this.type = ScriptType.universal,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'enabled': enabled,
      'code': code,
      'type': type.name,
      if (description != null) 'description': description,
    };
  }

  factory Script.fromJson(Map<String, dynamic> json) {
    return Script(
      id: json['id'] as String,
      name: json['name'] as String,
      enabled: json['enabled'] as bool? ?? true,
      code: json['code'] as String,
      type: ScriptType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ScriptType.universal,
      ),
      description: json['description'] as String?,
    );
  }
}

/// 脚本执行上下文
class ScriptContext {
  String url;
  String method;
  Map<String, String> headers;
  String body;
  int? statusCode;
  bool modified = false;
  bool aborted = false;

  ScriptContext({
    required this.url,
    required this.method,
    required this.headers,
    required this.body,
    this.statusCode,
  });

  /// 修改 URL
  void setUrl(String newUrl) {
    url = newUrl;
    modified = true;
  }

  /// 修改方法
  void setMethod(String newMethod) {
    method = newMethod;
    modified = true;
  }

  /// 设置 Header
  void setHeader(String name, String value) {
    headers[name] = value;
    modified = true;
  }

  /// 删除 Header
  void removeHeader(String name) {
    headers.remove(name);
    modified = true;
  }

  /// 修改 Body
  void setBody(String newBody) {
    body = newBody;
    modified = true;
  }

  /// 获取 Header
  String? getHeader(String name) {
    return headers[name];
  }

  /// 中止请求/响应
  void abort() {
    aborted = true;
    modified = true;
  }
}

/// 内置脚本模板
class BuiltInScripts {
  /// 获取所有内置脚本
  static List<Script> getAll() {
    return [
      addCustomHeader(),
      removeHeader(),
      logRequests(),
      mockResponse(),
      modifyUserAgent(),
      addTimestamp(),
      blockAds(),
      enableCors(),
    ];
  }

  /// 添加自定义 Header
  static Script addCustomHeader() {
    return Script(
      id: 'builtin_add_header',
      name: '添加自定义 Header',
      description: '为所有请求添加自定义请求头',
      type: ScriptType.onRequest,
      code: '''// 添加自定义 Header
// @modify-header: X-Custom-Header=SpiderProxy
// @modify-header: X-Request-Source=Mobile

function onRequest(context) {
  context.setHeader('X-Custom-Header', 'SpiderProxy');
  context.setHeader('X-Request-Source', 'Mobile');
  return context;
}''',
    );
  }

  /// 删除 Header
  static Script removeHeader() {
    return Script(
      id: 'builtin_remove_header',
      name: '删除敏感 Header',
      description: '删除请求中的敏感信息',
      type: ScriptType.onRequest,
      code: '''// 删除敏感 Header
// @modify-header: Cookie=
// @modify-header: Authorization=

function onRequest(context) {
  context.removeHeader('Cookie');
  context.removeHeader('Authorization');
  return context;
}''',
    );
  }

  /// 日志记录
  static Script logRequests() {
    return Script(
      id: 'builtin_log',
      name: '请求日志',
      description: '记录所有请求到控制台',
      type: ScriptType.universal,
      code: '''// 请求日志
function onRequest(context) {
  print('>>> \${context.method} \${context.url}');
  print('Headers: \${context.headers}');
  print('Body: \${context.body}');
  return context;
}

function onResponse(context) {
  print('<<< \${context.statusCode} \${context.url}');
  return context;
}''',
    );
  }

  /// Mock 响应
  static Script mockResponse() {
    return Script(
      id: 'builtin_mock',
      name: 'Mock 响应',
      description: '返回固定的 Mock 数据',
      type: ScriptType.onResponse,
      code: '''// Mock 响应
// @modify-body: {"success": true, "data": {"id": 1, "name": "Mock User"}}

function onResponse(context) {
  context.setHeader('Content-Type', 'application/json');
  context.setBody('{"success": true, "data": {"id": 1, "name": "Mock User"}}');
  context.statusCode = 200;
  return context;
}''',
    );
  }

  /// 修改 User-Agent
  static Script modifyUserAgent() {
    return Script(
      id: 'builtin_ua',
      name: '修改 User-Agent',
      description: '自定义 User-Agent 字符串',
      type: ScriptType.onRequest,
      code: '''// 修改 User-Agent
// @modify-header: User-Agent=SpiderProxy/1.0 (Mobile; Android)

function onRequest(context) {
  context.setHeader('User-Agent', 'SpiderProxy/1.0 (Mobile; Android)');
  return context;
}''',
    );
  }

  /// 添加时间戳
  static Script addTimestamp() {
    return Script(
      id: 'builtin_timestamp',
      name: '添加时间戳',
      description: '为请求添加时间戳 Header',
      type: ScriptType.onRequest,
      code: '''// 添加时间戳
// @modify-header: X-Request-Time=\${timestamp}

function onRequest(context) {
  final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  context.setHeader('X-Request-Time', timestamp);
  return context;
}''',
    );
  }

  /// 广告拦截
  static Script blockAds() {
    return Script(
      id: 'builtin_block_ads',
      name: '广告拦截',
      description: '拦截常见广告域名请求',
      type: ScriptType.onRequest,
      code: '''// 广告拦截
// @abort

function onRequest(context) {
  final adDomains = [
    'ads.example.com',
    'analytics.example.com',
    'tracking.example.com',
  ];

  final uri = Uri.parse(context.url);
  if (adDomains.contains(uri.host)) {
    print('Blocked ad request: \${context.url}');
    context.abort();
  }
  return context;
}''',
    );
  }

  /// 启用 CORS
  static Script enableCors() {
    return Script(
      id: 'builtin_cors',
      name: '启用 CORS',
      description: '为响应添加 CORS Header',
      type: ScriptType.onResponse,
      code: '''// 启用 CORS
// @modify-header: Access-Control-Allow-Origin=*
// @modify-header: Access-Control-Allow-Methods=GET, POST, PUT, DELETE, OPTIONS

function onResponse(context) {
  context.setHeader('Access-Control-Allow-Origin', '*');
  context.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  context.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  return context;
}''',
    );
  }
}
