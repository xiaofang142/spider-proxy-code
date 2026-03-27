import 'package:flutter_test/flutter_test.dart';
import 'package:spider_proxy/core/script/script_log.dart';

void main() {
  group('ScriptExecutionLog', () {
    test('create log with all fields', () {
      final log = ScriptExecutionLog(
        id: 'log-1',
        scriptId: 'script-1',
        scriptName: 'Test Script',
        timestamp: DateTime(2026, 3, 27, 10, 30, 45),
        level: ScriptLogLevel.info,
        message: 'Request processed',
        contextType: 'onRequest',
      );

      expect(log.id, 'log-1');
      expect(log.scriptId, 'script-1');
      expect(log.scriptName, 'Test Script');
      expect(log.level, ScriptLogLevel.info);
      expect(log.message, 'Request processed');
      expect(log.contextType, 'onRequest');
    });

    test('create error log with stack trace', () {
      final log = ScriptExecutionLog(
        id: 'log-2',
        scriptId: 'script-1',
        scriptName: 'Test Script',
        timestamp: DateTime.now(),
        level: ScriptLogLevel.error,
        message: 'TypeError: Cannot read property of undefined',
        stackTrace: 'at script.js:10\nat main.js:5',
        contextType: 'onRequest',
      );

      expect(log.level, ScriptLogLevel.error);
      expect(log.stackTrace, isNotNull);
      expect(log.stackTrace!.contains('script.js:10'), true);
    });

    test('to json', () {
      final log = ScriptExecutionLog(
        id: 'log-3',
        scriptId: 'script-1',
        scriptName: 'Test Script',
        timestamp: DateTime(2026, 3, 27, 10, 30, 45),
        level: ScriptLogLevel.info,
        message: 'Test message',
        contextType: 'onResponse',
      );

      final json = log.toJson();
      expect(json['id'], 'log-3');
      expect(json['scriptId'], 'script-1');
      expect(json['level'], 'info');
      expect(json['message'], 'Test message');
      expect(json['contextType'], 'onResponse');
    });

    test('from json', () {
      final json = <String, dynamic>{
        'id': 'log-4',
        'scriptId': 'script-2',
        'scriptName': 'Another Script',
        'timestamp': '2026-03-27T10:30:45.000Z',
        'level': 'error',
        'message': 'Error message',
        'stackTrace': 'at line 10',
        'contextType': 'onRequest',
      };

      final log = ScriptExecutionLog.fromJson(json);
      expect(log.id, 'log-4');
      expect(log.scriptId, 'script-2');
      expect(log.level, ScriptLogLevel.error);
      expect(log.message, 'Error message');
    });
  });

  group('ScriptLogManager', () {
    test('add and retrieve logs', () {
      final logManager = ScriptLogManager();

      logManager.addLog(ScriptExecutionLog(
        id: 'log-1',
        scriptId: 'script-1',
        scriptName: 'Script 1',
        timestamp: DateTime.now(),
        level: ScriptLogLevel.info,
        message: 'Message 1',
      ));

      logManager.addLog(ScriptExecutionLog(
        id: 'log-2',
        scriptId: 'script-1',
        scriptName: 'Script 1',
        timestamp: DateTime.now(),
        level: ScriptLogLevel.info,
        message: 'Message 2',
      ));

      expect(logManager.getAllLogs().length, 2);
      expect(logManager.getLogsForScript('script-1').length, 2);
    });

    test('get logs by script id', () {
      final logManager = ScriptLogManager();

      logManager.addLog(ScriptExecutionLog(
        id: 'log-1',
        scriptId: 'script-1',
        scriptName: 'Script 1',
        timestamp: DateTime.now(),
        level: ScriptLogLevel.info,
        message: 'Script 1 message',
      ));

      logManager.addLog(ScriptExecutionLog(
        id: 'log-2',
        scriptId: 'script-2',
        scriptName: 'Script 2',
        timestamp: DateTime.now(),
        level: ScriptLogLevel.info,
        message: 'Script 2 message',
      ));

      expect(logManager.getLogsForScript('script-1').length, 1);
      expect(logManager.getLogsForScript('script-2').length, 1);
      expect(logManager.getLogsForScript('script-3').length, 0);
    });

    test('clear logs for specific script', () {
      final logManager = ScriptLogManager();

      logManager.addLog(ScriptExecutionLog(
        id: 'log-1',
        scriptId: 'script-1',
        scriptName: 'Script 1',
        timestamp: DateTime.now(),
        level: ScriptLogLevel.info,
        message: 'Message 1',
      ));

      logManager.addLog(ScriptExecutionLog(
        id: 'log-2',
        scriptId: 'script-2',
        scriptName: 'Script 2',
        timestamp: DateTime.now(),
        level: ScriptLogLevel.info,
        message: 'Message 2',
      ));

      logManager.clearLogs('script-1');

      expect(logManager.getLogsForScript('script-1').length, 0);
      expect(logManager.getLogsForScript('script-2').length, 1);
    });

    test('clear all logs', () {
      final logManager = ScriptLogManager();

      logManager.addLog(ScriptExecutionLog(
        id: 'log-1',
        scriptId: 'script-1',
        scriptName: 'Script 1',
        timestamp: DateTime.now(),
        level: ScriptLogLevel.info,
        message: 'Message 1',
      ));

      logManager.clearLogs();
      expect(logManager.getAllLogs().length, 0);
    });

    test('error count', () {
      final logManager = ScriptLogManager();

      logManager.addLog(ScriptExecutionLog(
        id: 'log-1',
        scriptId: 'script-1',
        scriptName: 'Script 1',
        timestamp: DateTime.now(),
        level: ScriptLogLevel.info,
        message: 'Info message',
      ));

      logManager.addLog(ScriptExecutionLog(
        id: 'log-2',
        scriptId: 'script-1',
        scriptName: 'Script 1',
        timestamp: DateTime.now(),
        level: ScriptLogLevel.error,
        message: 'Error message',
      ));

      logManager.addLog(ScriptExecutionLog(
        id: 'log-3',
        scriptId: 'script-1',
        scriptName: 'Script 1',
        timestamp: DateTime.now(),
        level: ScriptLogLevel.error,
        message: 'Another error',
      ));

      expect(logManager.errorCount, 2);
    });

    test('max logs limit', () {
      final logManager = ScriptLogManager();

      // 添加超过 1000 条日志
      for (int i = 0; i < 1100; i++) {
        logManager.addLog(ScriptExecutionLog(
          id: 'log-$i',
          scriptId: 'script-1',
          scriptName: 'Script 1',
          timestamp: DateTime.now(),
          level: ScriptLogLevel.info,
          message: 'Message $i',
        ));
      }

      expect(logManager.getAllLogs().length, 1000);
      expect(logManager.getAllLogs().first.id, 'log-100');
    });

    test('get logs by level', () {
      final logManager = ScriptLogManager();

      logManager.addLog(ScriptExecutionLog(
        id: 'log-1',
        scriptId: 'script-1',
        scriptName: 'Script 1',
        timestamp: DateTime.now(),
        level: ScriptLogLevel.debug,
        message: 'Debug message',
      ));

      logManager.addLog(ScriptExecutionLog(
        id: 'log-2',
        scriptId: 'script-1',
        scriptName: 'Script 1',
        timestamp: DateTime.now(),
        level: ScriptLogLevel.info,
        message: 'Info message',
      ));

      logManager.addLog(ScriptExecutionLog(
        id: 'log-3',
        scriptId: 'script-1',
        scriptName: 'Script 1',
        timestamp: DateTime.now(),
        level: ScriptLogLevel.warn,
        message: 'Warn message',
      ));

      logManager.addLog(ScriptExecutionLog(
        id: 'log-4',
        scriptId: 'script-1',
        scriptName: 'Script 1',
        timestamp: DateTime.now(),
        level: ScriptLogLevel.error,
        message: 'Error message',
      ));

      expect(logManager.getLogsByLevel(ScriptLogLevel.debug).length, 1);
      expect(logManager.getLogsByLevel(ScriptLogLevel.info).length, 1);
      expect(logManager.getLogsByLevel(ScriptLogLevel.warn).length, 1);
      expect(logManager.getLogsByLevel(ScriptLogLevel.error).length, 1);
    });

    test('get recent logs', () {
      final logManager = ScriptLogManager();

      for (int i = 0; i < 150; i++) {
        logManager.addLog(ScriptExecutionLog(
          id: 'log-$i',
          scriptId: 'script-1',
          scriptName: 'Script 1',
          timestamp: DateTime.now(),
          level: ScriptLogLevel.info,
          message: 'Message $i',
        ));
      }

      final recentLogs = logManager.getRecentLogs(50);
      expect(recentLogs.length, 50);
      expect(recentLogs.first.id, 'log-100');
    });
  });
}
