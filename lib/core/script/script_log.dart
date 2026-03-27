/// 脚本执行日志
///
/// 记录脚本执行过程中的日志信息
library script_log;

/// 日志级别
enum ScriptLogLevel {
  debug,
  info,
  warn,
  error,
}

/// 脚本执行日志
class ScriptExecutionLog {
  final String id;
  final String scriptId;
  final String scriptName;
  final DateTime timestamp;
  final ScriptLogLevel level;
  final String message;
  final String? stackTrace;
  final String? contextType; // 'onRequest' | 'onResponse'

  ScriptExecutionLog({
    required this.id,
    required this.scriptId,
    required this.scriptName,
    required this.timestamp,
    required this.level,
    required this.message,
    this.stackTrace,
    this.contextType,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'scriptId': scriptId,
      'scriptName': scriptName,
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      if (stackTrace != null) 'stackTrace': stackTrace,
      if (contextType != null) 'contextType': contextType,
    };
  }

  factory ScriptExecutionLog.fromJson(Map<String, dynamic> json) {
    return ScriptExecutionLog(
      id: json['id'] as String,
      scriptId: json['scriptId'] as String,
      scriptName: json['scriptName'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      level: ScriptLogLevel.values.firstWhere(
        (e) => e.name == json['level'],
      ),
      message: json['message'] as String,
      stackTrace: json['stackTrace'] as String?,
      contextType: json['contextType'] as String?,
    );
  }
}

/// 脚本执行日志管理器
class ScriptLogManager {
  final List<ScriptExecutionLog> _logs = [];
  final int _maxLogs = 1000; // 最多保留 1000 条日志

  /// 添加日志
  void addLog(ScriptExecutionLog log) {
    _logs.add(log);
    // 超出限制时删除最旧的日志
    if (_logs.length > _maxLogs) {
      _logs.removeAt(0);
    }
  }

  /// 获取指定脚本的日志
  List<ScriptExecutionLog> getLogsForScript(String scriptId) {
    return _logs.where((log) => log.scriptId == scriptId).toList();
  }

  /// 获取所有日志
  List<ScriptExecutionLog> getAllLogs() {
    return List.unmodifiable(_logs);
  }

  /// 清空日志
  void clearLogs([String? scriptId]) {
    if (scriptId == null) {
      _logs.clear();
    } else {
      _logs.removeWhere((log) => log.scriptId == scriptId);
    }
  }

  /// 获取错误日志数量
  int get errorCount {
    return _logs.where((log) => log.level == ScriptLogLevel.error).length;
  }

  /// 获取指定级别的日志
  List<ScriptExecutionLog> getLogsByLevel(ScriptLogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  /// 获取最近的日志
  List<ScriptExecutionLog> getRecentLogs([int count = 100]) {
    if (_logs.length <= count) {
      return List.unmodifiable(_logs);
    }
    return _logs.sublist(_logs.length - count);
  }
}
