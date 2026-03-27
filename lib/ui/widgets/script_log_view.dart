import 'package:flutter/material.dart';
import 'script_log.dart';

/// 脚本日志视图组件
///
/// 显示脚本执行日志，支持级别过滤和清空
class ScriptLogView extends StatefulWidget {
  final ScriptLogManager logManager;
  final String scriptId;
  final String scriptName;

  const ScriptLogView({
    super.key,
    required this.logManager,
    required this.scriptId,
    required this.scriptName,
  });

  @override
  State<ScriptLogView> createState() => _ScriptLogViewState();
}

class _ScriptLogViewState extends State<ScriptLogView> {
  ScriptLogLevel? _filterLevel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '脚本日志',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 16,
              ),
            ),
            Text(
              widget.scriptName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          // 过滤按钮
          PopupMenuButton<ScriptLogLevel?>(
            icon: const Icon(Icons.filter_list),
            tooltip: '过滤日志级别',
            onSelected: (level) {
              setState(() => _filterLevel = level);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: null,
                child: Text('全部'),
              ),
              const PopupMenuItem(
                value: ScriptLogLevel.debug,
                child: Text('Debug'),
              ),
              const PopupMenuItem(
                value: ScriptLogLevel.info,
                child: Text('Info'),
              ),
              const PopupMenuItem(
                value: ScriptLogLevel.warn,
                child: Text('Warn'),
              ),
              const PopupMenuItem(
                value: ScriptLogLevel.error,
                child: Text('Error'),
              ),
            ],
          ),
          // 清空按钮
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: '清空日志',
            onPressed: _confirmClear,
          ),
        ],
      ),
      body: Column(
        children: [
          // 过滤提示条
          if (_filterLevel != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.filter_alt,
                    size: 16,
                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '已过滤：${_getLevelName(_filterLevel!)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => setState(() => _filterLevel = null),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '清除过滤',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // 日志列表
          Expanded(
            child: _buildLogList(),
          ),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    var logs = widget.logManager.getLogsForScript(widget.scriptId);

    // 应用过滤
    if (_filterLevel != null) {
      logs = logs.where((log) => log.level == _filterLevel).toList();
    }

    if (logs.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[logs.length - 1 - index]; // 倒序显示，最新的在前
        return _buildLogCard(log);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.article_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无日志',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '脚本执行时会在此显示日志',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(ScriptExecutionLog log) {
    final levelColor = _getLevelColor(log.level);
    final levelBgColor = levelColor.withOpacity(0.1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: levelColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 日志头部
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: levelBgColor,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: levelColor.withOpacity(0.3)),
                ),
                child: Text(
                  _getLevelName(log.level),
                  style: TextStyle(
                    fontSize: 11,
                    color: levelColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTime(log.timestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
              if (log.contextType != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    log.contextType!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // 日志消息
          Text(
            log.message,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade900,
            ),
          ),
          // 堆栈跟踪（如果有）
          if (log.stackTrace != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                log.stackTrace!,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red.shade800,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getLevelColor(ScriptLogLevel level) {
    switch (level) {
      case ScriptLogLevel.debug:
        return Colors.blue;
      case ScriptLogLevel.info:
        return Colors.green;
      case ScriptLogLevel.warn:
        return Colors.orange;
      case ScriptLogLevel.error:
        return Colors.red;
    }
  }

  String _getLevelName(ScriptLogLevel level) {
    switch (level) {
      case ScriptLogLevel.debug:
        return 'DEBUG';
      case ScriptLogLevel.info:
        return 'INFO';
      case ScriptLogLevel.warn:
        return 'WARN';
      case ScriptLogLevel.error:
        return 'ERROR';
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空此脚本的所有日志吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.logManager.clearLogs(widget.scriptId);
              Navigator.pop(context);
              if (mounted) {
                setState(() {});
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}

/// 打开日志视图
void openScriptLogView({
  required BuildContext context,
  required ScriptLogManager logManager,
  required String scriptId,
  required String scriptName,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ScriptLogView(
        logManager: logManager,
        scriptId: scriptId,
        scriptName: scriptName,
      ),
    ),
  );
}
