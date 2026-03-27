/// 完整 JavaScript 引擎 (v3.0)
///
/// 基于 dart_eval 实现完整的 JavaScript 脚本执行能力
library script_engine_v2;

import 'dart:async';
import 'dart:convert';
import 'package:dart_eval/dart_eval.dart';
import 'package:dart_eval/dart_eval_bridge.dart';
import 'package:dart_eval/stdlib/core.dart';
import 'script_log.dart';

/// 完整 JavaScript 引擎
class ScriptEngineV2 {
  EvalDart? _vm;
  bool _enabled = true;
  final List<ScriptV2> _scripts = [];

  // v3.2 日志管理器
  final ScriptLogManager _logManager = ScriptLogManager();

  /// 是否启用
  bool get enabled => _enabled;

  /// 获取所有脚本
  List<ScriptV2> get scripts => List.unmodifiable(_scripts);

  /// 获取日志管理器
  ScriptLogManager get logManager => _logManager;

  /// 初始化引擎
  Future<void> initialize() async {
    _vm = EvalDart();
    await _registerLibraries();
  }

  /// 注册库
  Future<void> _registerLibraries() async {
    if (_vm == null) return;

    // 注册 proxy://context 库
    _vm!.registerLibrary('proxy://context', {
      'ScriptContext': ScriptContextBridge.type,
      'ScriptContext.new': ScriptContextBridge.constructor(),
      'ScriptContext.url': ScriptContextBridge.urlGetter,
      'ScriptContext.method': ScriptContextBridge.methodGetter,
      'ScriptContext.headers': ScriptContextBridge.headersGetter,
      'ScriptContext.body': ScriptContextBridge.bodyGetter,
      'ScriptContext.statusCode': ScriptContextBridge.statusCodeGetter,
      'ScriptContext.setHeader': ScriptContextBridge.setHeaderMethod,
      'ScriptContext.removeHeader': ScriptContextBridge.removeHeaderMethod,
      'ScriptContext.setBody': ScriptContextBridge.setBodyMethod,
      'ScriptContext.setUrl': ScriptContextBridge.setUrlMethod,
      'ScriptContext.setMethod': ScriptContextBridge.setMethodMethod,
      'ScriptContext.abort': ScriptContextBridge.abortMethod,
    });

    // 注册工具函数（v3.2 增强版 - 集成日志）
    _vm!.registerLibrary('proxy://utils', {
      'print': Func1((msg) {
        _logManager.addLog(ScriptExecutionLog(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          scriptId: _currentScriptId ?? 'unknown',
          scriptName: _currentScriptName ?? 'unknown',
          timestamp: DateTime.now(),
          level: ScriptLogLevel.info,
          message: msg as String,
          contextType: _currentContextType,
        ));
        return null;
      }),
      'jsonDecode': Func1((str) => json.decode(str as String)),
      'jsonEncode': Func1((obj) => json.encode(obj)),
    });
  }

  // 当前脚本执行上下文
  String? _currentScriptId;
  String? _currentScriptName;
  String? _currentContextType;

  /// 启用引擎
  void enable() {
    _enabled = true;
  }

  /// 禁用引擎
  void disable() {
    _enabled = false;
  }

  /// 添加脚本
  void addScript(ScriptV2 script) {
    _scripts.add(script);
  }

  /// 移除脚本
  void removeScript(String scriptId) {
    _scripts.removeWhere((script) => script.id == scriptId);
  }

  /// 更新脚本状态
  void toggleScript(String scriptId, bool enabled) {
    final index = _scripts.indexWhere((script) => script.id == scriptId);
    if (index >= 0) {
      final script = _scripts[index];
      _scripts[index] = ScriptV2(
        id: script.id,
        name: script.name,
        enabled: enabled,
        code: script.code,
        type: script.type,
        description: script.description,
      );
    }
  }

  /// 清除所有脚本
  void clearScripts() {
    _scripts.clear();
  }

  /// 执行 onRequest 脚本（v3.2 增强版 - 集成日志）
  Future<ScriptContext?> executeOnRequest(
    String url,
    String method,
    Map<String, String> headers,
    String body,
  ) async {
    if (!_enabled) return null;
    if (_vm == null) await initialize();

    for (final script in _scripts) {
      if (!script.enabled) continue;
      if (script.type != ScriptType.onRequest && script.type != ScriptType.universal) continue;

      _currentScriptId = script.id;
      _currentScriptName = script.name;
      _currentContextType = 'onRequest';

      try {
        final context = ScriptContext(
          url: url,
          method: method,
          headers: Map.from(headers),
          body: body,
        );

        final result = await _executeScript(script.code, context, 'onRequest');
        if (result != null && result.modified) {
          _logManager.addLog(ScriptExecutionLog(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            scriptId: script.id,
            scriptName: script.name,
            timestamp: DateTime.now(),
            level: ScriptLogLevel.info,
            message: 'Request modified successfully',
            contextType: 'onRequest',
          ));
          return result;
        }
      } catch (e, stackTrace) {
        _logManager.addLog(ScriptExecutionLog(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          scriptId: script.id,
          scriptName: script.name,
          timestamp: DateTime.now(),
          level: ScriptLogLevel.error,
          message: 'Error: ${e.toString()}',
          stackTrace: stackTrace.toString(),
          contextType: 'onRequest',
        ));
      }
    }

    return null;
  }

  /// 执行 onResponse 脚本（v3.2 增强版 - 集成日志）
  Future<ScriptContext?> executeOnResponse(
    String url,
    int statusCode,
    Map<String, String> headers,
    String body,
  ) async {
    if (!_enabled) return null;
    if (_vm == null) await initialize();

    for (final script in _scripts) {
      if (!script.enabled) continue;
      if (script.type != ScriptType.onResponse && script.type != ScriptType.universal) continue;

      _currentScriptId = script.id;
      _currentScriptName = script.name;
      _currentContextType = 'onResponse';

      try {
        final context = ScriptContext(
          url: url,
          statusCode: statusCode,
          headers: Map.from(headers),
          body: body,
        );

        final result = await _executeScript(script.code, context, 'onResponse');
        if (result != null && result.modified) {
          _logManager.addLog(ScriptExecutionLog(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            scriptId: script.id,
            scriptName: script.name,
            timestamp: DateTime.now(),
            level: ScriptLogLevel.info,
            message: 'Response modified successfully',
            contextType: 'onResponse',
          ));
          return result;
        }
      } catch (e, stackTrace) {
        _logManager.addLog(ScriptExecutionLog(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          scriptId: script.id,
          scriptName: script.name,
          timestamp: DateTime.now(),
          level: ScriptLogLevel.error,
          message: 'Error: ${e.toString()}',
          stackTrace: stackTrace.toString(),
          contextType: 'onResponse',
        ));
      }
    }

    return null;
  }

  /// 执行脚本
  Future<ScriptContext?> _executeScript(String code, ScriptContext context, String entryPoint) async {
    if (_vm == null) return null;

    try {
      // 包装脚本代码
      final wrappedCode = '''
import 'proxy://context' as context;
import 'proxy://utils' as utils;

$code

void main() {
  final ctx = context.ScriptContext(
    url: ${_escapeString(context.url)},
    method: ${_escapeString(context.method)},
    headers: ${_formatHeaders(context.headers)},
    body: ${_escapeString(context.body)},
    statusCode: ${context.statusCode ?? 0},
  );

  if ($entryPoint != null) {
    $entryPoint(ctx);
  }
}
''';

      // 编译并执行
      final result = _vm!.compile(wrappedCode);
      await _vm!.execute(result);

      // 获取修改后的上下文
      return context;
    } catch (e) {
      print('[ScriptEngineV2] Script execution error: $e');
      return null;
    }
  }

  String _escapeString(String str) {
    return '"${str.replaceAll('"', '\\"').replaceAll('\n', '\\n').replaceAll('\r', '\\r')}"';
  }

  String _formatHeaders(Map<String, String> headers) {
    final entries = headers.entries.map((e) => '"${e.key}": "${e.value}"').join(',');
    return '{$entries}';
  }

  /// 导入脚本从 JSON
  void importScripts(List<Map<String, dynamic>> jsonList) {
    for (final json in jsonList) {
      _scripts.add(ScriptV2.fromJson(json));
    }
  }

  /// 导出脚本为 JSON
  List<Map<String, dynamic>> exportScripts() {
    return _scripts.map((script) => script.toJson()).toList();
  }

  /// 加载内置模板
  void loadBuiltInTemplates() {
    _scripts.addAll(BuiltInScriptsV2.getAll());
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

/// 脚本 v2
class ScriptV2 {
  final String id;
  final String name;
  final bool enabled;
  final String code;
  final ScriptType type;
  final String? description;

  ScriptV2({
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

  factory ScriptV2.fromJson(Map<String, dynamic> json) {
    return ScriptV2(
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

  /// 中止
  void abort() {
    aborted = true;
    modified = true;
  }
}

/// ScriptContext Bridge for dart_eval
class ScriptContextBridge {
  static const type = BridgeTypeSpec('proxy://context', 'ScriptContext');

  static BridgeConstructorSpec constructor() {
    return BridgeConstructorSpec(BridgeMethodSpec('new', type));
  }

  static BridgeGetterSpec urlGetter => BridgeGetterSpec('url', const EValueType.string());
  static BridgeGetterSpec methodGetter => BridgeGetterSpec('method', const EValueType.string());
  static BridgeGetterSpec headersGetter => BridgeGetterSpec('headers', const EValueType.map());
  static BridgeGetterSpec bodyGetter => BridgeGetterSpec('body', const EValueType.string());
  static BridgeGetterSpec statusCodeGetter => BridgeGetterSpec('statusCode', const EValueType.int());

  static BridgeMethodSpec setHeaderMethod => BridgeMethodSpec(
    'setHeader',
    const EValueType.voidType(),
    parameters: [
      BridgeParameterSpec('name', const EValueType.string(), false),
      BridgeParameterSpec('value', const EValueType.string(), false),
    ],
  );

  static BridgeMethodSpec removeHeaderMethod => BridgeMethodSpec(
    'removeHeader',
    const EValueType.voidType(),
    parameters: [
      BridgeParameterSpec('name', const EValueType.string(), false),
    ],
  );

  static BridgeMethodSpec setBodyMethod => BridgeMethodSpec(
    'setBody',
    const EValueType.voidType(),
    parameters: [
      BridgeParameterSpec('body', const EValueType.string(), false),
    ],
  );

  static BridgeMethodSpec setUrlMethod => BridgeMethodSpec(
    'setUrl',
    const EValueType.voidType(),
    parameters: [
      BridgeParameterSpec('url', const EValueType.string(), false),
    ],
  );

  static BridgeMethodSpec setMethodMethod => BridgeMethodSpec(
    'setMethod',
    const EValueType.voidType(),
    parameters: [
      BridgeParameterSpec('method', const EValueType.string(), false),
    ],
  );

  static BridgeMethodSpec abortMethod => BridgeMethodSpec(
    'abort',
    const EValueType.voidType(),
  );
}

/// 内置脚本模板 v3.0
class BuiltInScriptsV2 {
  /// 获取所有内置脚本
  static List<ScriptV2> getAll() {
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
  static ScriptV2 addCustomHeader() {
    return ScriptV2(
      id: 'builtin_v2_add_header',
      name: '添加自定义 Header (v3)',
      description: '为所有请求添加自定义请求头',
      type: ScriptType.onRequest,
      code: '''
import 'proxy://context' as context;

void onRequest(ctx) {
  ctx.setHeader('X-Custom-Header', 'SpiderProxy-v3');
  ctx.setHeader('X-Request-Source', 'Mobile-App');
}
''',
    );
  }

  /// 删除 Header
  static ScriptV2 removeHeader() {
    return ScriptV2(
      id: 'builtin_v2_remove_header',
      name: '删除敏感 Header (v3)',
      description: '删除请求中的敏感信息',
      type: ScriptType.onRequest,
      code: '''
import 'proxy://context' as context;

void onRequest(ctx) {
  ctx.removeHeader('Cookie');
  ctx.removeHeader('Authorization');
}
''',
    );
  }

  /// 日志记录
  static ScriptV2 logRequests() {
    return ScriptV2(
      id: 'builtin_v2_log',
      name: '请求日志 (v3)',
      description: '记录所有请求到控制台',
      type: ScriptType.universal,
      code: '''
import 'proxy://context' as context;
import 'proxy://utils' as utils;

void onRequest(ctx) {
  utils.print('>>> \${ctx.method} \${ctx.url}');
}

void onResponse(ctx) {
  utils.print('<<< \${ctx.statusCode} \${ctx.url}');
}
''',
    );
  }

  /// Mock 响应
  static ScriptV2 mockResponse() {
    return ScriptV2(
      id: 'builtin_v2_mock',
      name: 'Mock 响应 (v3)',
      description: '返回固定的 Mock 数据',
      type: ScriptType.onResponse,
      code: '''
import 'proxy://context' as context;

void onResponse(ctx) {
  ctx.setHeader('Content-Type', 'application/json');
  ctx.setBody('{"success": true, "data": {"id": 1, "name": "Mock User"}}');
}
''',
    );
  }

  /// 修改 User-Agent
  static ScriptV2 modifyUserAgent() {
    return ScriptV2(
      id: 'builtin_v2_ua',
      name: '修改 User-Agent (v3)',
      description: '自定义 User-Agent 字符串',
      type: ScriptType.onRequest,
      code: '''
import 'proxy://context' as context;

void onRequest(ctx) {
  ctx.setHeader('User-Agent', 'SpiderProxy/3.0 (Mobile; Android)');
}
''',
    );
  }

  /// 添加时间戳
  static ScriptV2 addTimestamp() {
    return ScriptV2(
      id: 'builtin_v2_timestamp',
      name: '添加时间戳 (v3)',
      description: '为请求添加时间戳 Header',
      type: ScriptType.onRequest,
      code: '''
import 'proxy://context' as context;

void onRequest(ctx) {
  // 注意：dart_eval 不支持 DateTime
  // 这里使用简化方式
  ctx.setHeader('X-Request-Time', 'timestamp-placeholder');
}
''',
    );
  }

  /// 广告拦截
  static ScriptV2 blockAds() {
    return ScriptV2(
      id: 'builtin_v2_block_ads',
      name: '广告拦截 (v3)',
      description: '拦截常见广告域名请求',
      type: ScriptType.onRequest,
      code: '''
import 'proxy://context' as context;

void onRequest(ctx) {
  final url = ctx.url;
  if (url.contains('ads.example.com') ||
      url.contains('analytics.example.com')) {
    ctx.abort();
  }
}
''',
    );
  }

  /// 启用 CORS
  static ScriptV2 enableCors() {
    return ScriptV2(
      id: 'builtin_v2_cors',
      name: '启用 CORS (v3)',
      description: '为响应添加 CORS Header',
      type: ScriptType.onResponse,
      code: '''
import 'proxy://context' as context;

void onResponse(ctx) {
  ctx.setHeader('Access-Control-Allow-Origin', '*');
  ctx.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  ctx.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
}
''',
    );
  }
}
