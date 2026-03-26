import 'package:flutter/material.dart';
import 'breakpoint_debugger.dart';
import '../dialogs/breakpoint_editor_dialog.dart';

/// 断点调试页面
class BreakpointDebuggerPage extends StatefulWidget {
  final BreakpointDebugger debugger;

  const BreakpointDebuggerPage({super.key, required this.debugger});

  @override
  State<BreakpointDebuggerPage> createState() => _BreakpointDebuggerPageState();
}

class _BreakpointDebuggerPageState extends State<BreakpointDebuggerPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('断点调试'),
        actions: [
          Switch(
            value: widget.debugger.enabled,
            onChanged: (value) {
              setState(() {
                if (value) {
                  widget.debugger.enable();
                } else {
                  widget.debugger.disable();
                }
              });
            },
            activeColor: Theme.of(context).colorScheme.primary,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddRuleDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // 当前暂停的请求/响应
          ValueListenableBuilder<BreakpointRequest?>(
            valueListenable: _pausedRequestNotifier,
            builder: (context, request, child) {
              if (request == null) return const SizedBox.shrink();
              return _buildPausedRequestCard(request);
            },
          ),
          ValueListenableBuilder<BreakpointResponse?>(
            valueListenable: _pausedResponseNotifier,
            builder: (context, response, child) {
              if (response == null) return const SizedBox.shrink();
              return _buildPausedResponseCard(response);
            },
          ),
          // 规则列表
          Expanded(
            child: ValueListenableBuilder<List<BreakpointRule>>(
              valueListenable: _rulesNotifier,
              builder: (context, rules, child) {
                if (rules.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.pause_circle_outline,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '暂无断点规则',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击右上角 + 添加规则',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rules.length,
                  itemBuilder: (context, index) {
                    final rule = rules[index];
                    return _buildRuleCard(rule);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  final ValueNotifier<List<BreakpointRule>> _rulesNotifier = ValueNotifier([]);
  final ValueNotifier<BreakpointRequest?> _pausedRequestNotifier = ValueNotifier(null);
  final ValueNotifier<BreakpointResponse?> _pausedResponseNotifier = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _updateRules();
    _startPollingPausedRequests();
  }

  void _updateRules() {
    _rulesNotifier.value = List.unmodifiable(widget.debugger.rules);
  }

  void _startPollingPausedRequests() {
    // 轮询检查是否有暂停的请求/响应
    Future.doWhile(() {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          setState(() {
            _pausedRequestNotifier.value = widget.debugger.pausedRequest;
            _pausedResponseNotifier.value = widget.debugger.pausedResponse;
          });
        }
        return true;
      });
      return true;
    });
  }

  Widget _buildRuleCard(BreakpointRule rule) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showEditRuleDialog(context, rule),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    rule.breakpointType == BreakpointType.request
                        ? Icons.arrow_outward
                        : Icons.arrow_downward,
                    size: 24,
                    color: rule.enabled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rule.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _getConditionDescription(rule.condition),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: rule.enabled,
                    onChanged: (value) {
                      widget.debugger.toggleRule(rule.id, value);
                      _updateRules();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 类型标签
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: rule.breakpointType == BreakpointType.request
                      ? Colors.blue.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      rule.breakpointType == BreakpointType.request
                          ? Icons.send
                          : Icons.reply,
                      size: 16,
                      color: rule.breakpointType == BreakpointType.request
                          ? Colors.blue
                          : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      rule.breakpointType == BreakpointType.request
                          ? '请求前断点'
                          : '响应前断点',
                      style: TextStyle(
                        fontSize: 13,
                        color: rule.breakpointType == BreakpointType.request
                            ? Colors.blue.shade700
                            : Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showEditRuleDialog(context, rule),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('编辑', style: TextStyle(fontSize: 13)),
                  ),
                  TextButton.icon(
                    onPressed: () => _deleteRule(context, rule),
                    icon: const Icon(Icons.delete, size: 16),
                    label: const Text(
                      '删除',
                      style: TextStyle(fontSize: 13, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPausedRequestCard(BreakpointRequest request) {
    return Card(
      color: Colors.amber.shade50,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pause_circle,
                  color: Colors.amber.shade700,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  '请求已暂停',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '已暂停 ${request.pausedDuration.inSeconds}秒',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${request.method} ${request.url}',
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _continueRequest(request),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('继续'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _modifyRequest(request),
                  icon: const Icon(Icons.edit),
                  label: const Text('修改'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _cancelRequest(request),
                  icon: const Icon(Icons.close),
                  label: const Text('取消'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPausedResponseCard(BreakpointResponse response) {
    return Card(
      color: Colors.orange.shade50,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.pause_circle,
                  color: Colors.orange.shade700,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  '响应已暂停',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  '已暂停 ${response.pausedDuration.inSeconds}秒',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${response.statusCode} ${response.url}',
              style: const TextStyle(fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _continueResponse(response),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('继续'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _modifyResponse(response),
                  icon: const Icon(Icons.edit),
                  label: const Text('修改'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _cancelResponse(response),
                  icon: const Icon(Icons.close),
                  label: const Text('取消'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getConditionDescription(MatchCondition condition) {
    final parts = <String>[];

    if (condition.hostEquals != null) {
      parts.add('域名=${condition.hostEquals}');
    } else if (condition.hostContains != null) {
      parts.add('域名包含"${condition.hostContains}"');
    }

    if (condition.urlContains != null) {
      parts.add('URL 包含"${condition.urlContains}"');
    }

    if (condition.method != null) {
      parts.add('方法=${condition.method}');
    }

    if (condition.statusCodeRange != null) {
      final range = condition.statusCodeRange!;
      if (range.$1 == range.$2) {
        parts.add('状态码=${range.$1}');
      } else {
        parts.add('状态码=${range.$1}-${range.$2}');
      }
    }

    return parts.isEmpty ? '所有请求' : parts.join(', ');
  }

  void _showAddRuleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _BreakpointRuleEditorDialog(
        debugger: widget.debugger,
        onSave: _updateRules,
      ),
    );
  }

  void _showEditRuleDialog(BuildContext context, BreakpointRule rule) {
    showDialog(
      context: context,
      builder: (context) => _BreakpointRuleEditorDialog(
        debugger: widget.debugger,
        rule: rule,
        onSave: _updateRules,
      ),
    );
  }

  void _deleteRule(BuildContext context, BreakpointRule rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除规则"${rule.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.debugger.removeRule(rule.id);
              _updateRules();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _continueRequest(BreakpointRequest request) {
    widget.debugger.resumeRequest();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请求已继续发送')),
    );
  }

  void _modifyRequest(BreakpointRequest request) {
    showDialog(
      context: context,
      builder: (context) => BreakpointEditorDialog(
        request: request,
        onSaveRequest: (url, method, headers, body) {
          // 修改后继续发送
          widget.debugger.resumeRequestWithModifications(
            url: url,
            method: method,
            headers: headers,
            body: body,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请求已修改并发送')),
          );
        },
      ),
    );
  }

  void _cancelRequest(BreakpointRequest request) {
    widget.debugger.cancelRequest();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('请求已取消')),
    );
  }

  void _continueResponse(BreakpointResponse response) {
    widget.debugger.resumeResponse();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('响应已继续返回')),
    );
  }

  void _modifyResponse(BreakpointResponse response) {
    showDialog(
      context: context,
      builder: (context) => BreakpointEditorDialog(
        response: response,
        onSaveResponse: (statusCode, headers, body) {
          // 修改后继续返回
          widget.debugger.resumeResponseWithModifications(
            statusCode: statusCode,
            headers: headers,
            body: body,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('响应已修改并返回')),
          );
        },
      ),
    );
  }

  void _cancelResponse(BreakpointResponse response) {
    widget.debugger.cancelResponse();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('响应已取消')),
    );
  }
}

/// 断点规则编辑器对话框
class _BreakpointRuleEditorDialog extends StatefulWidget {
  final BreakpointDebugger debugger;
  final BreakpointRule? rule;
  final VoidCallback onSave;

  const _BreakpointRuleEditorDialog({
    required this.debugger,
    this.rule,
    required this.onSave,
  });

  @override
  State<_BreakpointRuleEditorDialog> createState() =>
      _BreakpointRuleEditorDialogState();
}

class _BreakpointRuleEditorDialogState
    extends State<_BreakpointRuleEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostContainsController = TextEditingController();
  final _urlContainsController = TextEditingController();

  BreakpointType _breakpointType = BreakpointType.request;
  int? _statusCode;

  @override
  void initState() {
    super.initState();
    if (widget.rule != null) {
      _nameController.text = widget.rule!.name;
      _breakpointType = widget.rule!.breakpointType;
      if (widget.rule!.condition.hostContains != null) {
        _hostContainsController.text = widget.rule!.condition.hostContains!;
      }
      if (widget.rule!.condition.urlContains != null) {
        _urlContainsController.text = widget.rule!.condition.urlContains!;
      }
      if (widget.rule!.condition.statusCodeRange != null) {
        _statusCode = widget.rule!.condition.statusCodeRange!.$1;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostContainsController.dispose();
    _urlContainsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.rule == null ? '添加断点规则' : '编辑断点规则'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: '规则名称',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入规则名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<BreakpointType>(
                value: _breakpointType,
                decoration: const InputDecoration(
                  labelText: '断点类型',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: BreakpointType.request,
                    child: Text('请求前断点'),
                  ),
                  DropdownMenuItem(
                    value: BreakpointType.response,
                    child: Text('响应前断点'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _breakpointType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text('匹配条件', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _hostContainsController,
                decoration: const InputDecoration(
                  labelText: '域名包含',
                  hintText: '例如：api.example.com',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _urlContainsController,
                decoration: const InputDecoration(
                  labelText: 'URL 包含',
                  hintText: '例如：/api/v1/',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_breakpointType == BreakpointType.response) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _statusCode ?? 200,
                  decoration: const InputDecoration(
                    labelText: '状态码',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 200, child: Text('200 OK')),
                    DropdownMenuItem(value: 301, child: Text('301 Moved')),
                    DropdownMenuItem(value: 302, child: Text('302 Found')),
                    DropdownMenuItem(value: 400, child: Text('400 Bad Request')),
                    DropdownMenuItem(value: 401, child: Text('401 Unauthorized')),
                    DropdownMenuItem(value: 403, child: Text('403 Forbidden')),
                    DropdownMenuItem(value: 404, child: Text('404 Not Found')),
                    DropdownMenuItem(value: 500, child: Text('500 Server Error')),
                    DropdownMenuItem(value: 502, child: Text('502 Bad Gateway')),
                    DropdownMenuItem(value: 503, child: Text('503 Unavailable')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _statusCode = value;
                    });
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _saveRule,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _saveRule() {
    if (_formKey.currentState!.validate()) {
      final condition = MatchCondition(
        hostContains: _hostContainsController.text.isEmpty
            ? null
            : _hostContainsController.text,
        urlContains: _urlContainsController.text.isEmpty
            ? null
            : _urlContainsController.text,
        statusCodeRange: _breakpointType == BreakpointType.response &&
                _statusCode != null
            ? (_statusCode!, _statusCode!)
            : null,
      );

      final rule = BreakpointRule(
        id: widget.rule?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        breakpointType: _breakpointType,
        condition: condition,
        enabled: widget.rule?.enabled ?? true,
      );

      if (widget.rule == null) {
        widget.debugger.addRule(rule);
      } else {
        widget.debugger.removeRule(widget.rule!.id);
        widget.debugger.addRule(rule);
      }

      widget.onSave();
      Navigator.pop(context);
    }
  }
}
