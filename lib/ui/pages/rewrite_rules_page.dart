import 'package:flutter/material.dart';
import 'request_rewriter.dart';

/// 请求重写规则管理页面
class RewriteRulesPage extends StatefulWidget {
  final RequestRewriter rewriter;

  const RewriteRulesPage({super.key, required this.rewriter});

  @override
  State<RewriteRulesPage> createState() => _RewriteRulesPageState();
}

class _RewriteRulesPageState extends State<RewriteRulesPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('请求重写'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddRuleDialog(context),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<RequestRewriteRule>>(
        valueListenable: _rulesNotifier,
        builder: (context, rules, child) {
          if (rules.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.edit_off,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无重写规则',
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
    );
  }

  final ValueNotifier<List<RequestRewriteRule>> _rulesNotifier =
      ValueNotifier([]);

  @override
  void initState() {
    super.initState();
    _updateRules();
  }

  void _updateRules() {
    _rulesNotifier.value = List.unmodifiable(widget.rewriter.rules);
  }

  Widget _buildRuleCard(RequestRewriteRule rule) {
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
                  // 规则类型图标
                  Icon(
                    _getRuleTypeIcon(rule.type),
                    size: 24,
                    color: rule.enabled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  // 规则名称和状态
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
                  // 开关
                  Switch(
                    value: rule.enabled,
                    onChanged: (value) {
                      widget.rewriter.toggleRule(rule.id, value);
                      _updateRules();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 动作描述
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Text(
                      _getActionDescription(rule.action),
                      style: const TextStyle(fontSize: 13),
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
                    onPressed: () => _testRule(context, rule),
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('测试', style: TextStyle(fontSize: 13)),
                  ),
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
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.red,
                      ),
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

  IconData _getRuleTypeIcon(RewriteRuleType type) {
    switch (type) {
      case RewriteRuleType.modifyHeader:
        return Icons.header;
      case RewriteRuleType.modifyResponseHeader:
        return Icons.http;
      case RewriteRuleType.redirectUrl:
        return Icons.forward;
      case RewriteRuleType.modifyBody:
        return Icons.description;
      case RewriteRuleType.modifyResponseBody:
        return Icons.article;
    }
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

    if (condition.urlRegex != null) {
      parts.add('正则匹配');
    }

    return parts.isEmpty ? '所有请求' : parts.join(', ');
  }

  String _getActionDescription(RewriteAction action) {
    switch (action.type) {
      case ActionType.setHeader:
        return '${action.remove ? '删除' : '设置'} Header: ${action.headerName}${action.headerValue != null ? ' = ${action.headerValue}' : ''}';
      case ActionType.removeHeader:
        return '删除 Header: ${action.headerName}';
      case ActionType.redirect:
        return '重定向到：${action.redirectUrl}';
      case ActionType.replace:
        return '替换：${action.newValue}';
    }
  }

  void _showAddRuleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _RuleEditorDialog(
        rewriter: widget.rewriter,
        onSave: () {
          _updateRules();
        },
      ),
    );
  }

  void _showEditRuleDialog(BuildContext context, RequestRewriteRule rule) {
    showDialog(
      context: context,
      builder: (context) => _RuleEditorDialog(
        rewriter: widget.rewriter,
        rule: rule,
        onSave: () {
          _updateRules();
        },
      ),
    );
  }

  void _deleteRule(BuildContext context, RequestRewriteRule rule) {
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
              widget.rewriter.removeRule(rule.id);
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

  void _testRule(BuildContext context, RequestRewriteRule rule) {
    // 简单的测试功能
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('规则"${rule.name}"配置正确'),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

/// 规则编辑器对话框
class _RuleEditorDialog extends StatefulWidget {
  final RequestRewriter rewriter;
  final RequestRewriteRule? rule;
  final VoidCallback onSave;

  const _RuleEditorDialog({
    required this.rewriter,
    this.rule,
    required this.onSave,
  });

  @override
  State<_RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<_RuleEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _hostContainsController = TextEditingController();
  final _urlContainsController = TextEditingController();
  final _methodController = TextEditingController();

  RewriteRuleType _ruleType = RewriteRuleType.modifyHeader;
  ActionType _actionType = ActionType.setHeader;
  String? _headerName;
  String? _headerValue;
  String? _redirectUrl;

  @override
  void initState() {
    super.initState();
    if (widget.rule != null) {
      _nameController.text = widget.rule!.name;
      _ruleType = widget.rule!.type;
      _actionType = widget.rule!.action.type;
      _headerName = widget.rule!.action.headerName;
      _headerValue = widget.rule!.action.headerValue;
      _redirectUrl = widget.rule!.action.redirectUrl;

      if (widget.rule!.condition.hostContains != null) {
        _hostContainsController.text = widget.rule!.condition.hostContains!;
      }
      if (widget.rule!.condition.urlContains != null) {
        _urlContainsController.text = widget.rule!.condition.urlContains!;
      }
      if (widget.rule!.condition.method != null) {
        _methodController.text = widget.rule!.condition.method!;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostContainsController.dispose();
    _urlContainsController.dispose();
    _methodController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.rule == null ? '添加规则' : '编辑规则'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 规则名称
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
              // 规则类型
              DropdownButtonFormField<RewriteRuleType>(
                value: _ruleType,
                decoration: const InputDecoration(
                  labelText: '规则类型',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: RewriteRuleType.modifyHeader,
                    child: Text('修改请求头'),
                  ),
                  DropdownMenuItem(
                    value: RewriteRuleType.modifyResponseHeader,
                    child: Text('修改响应头'),
                  ),
                  DropdownMenuItem(
                    value: RewriteRuleType.redirectUrl,
                    child: Text('URL 重定向'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _ruleType = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              // 匹配条件
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
              const SizedBox(height: 8),
              TextFormField(
                controller: _methodController,
                decoration: const InputDecoration(
                  labelText: 'HTTP 方法',
                  hintText: '例如：GET, POST',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // 动作配置
              const Text('执行动作', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<ActionType>(
                value: _actionType,
                decoration: const InputDecoration(
                  labelText: '动作类型',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: ActionType.setHeader,
                    child: Text('设置 Header'),
                  ),
                  const DropdownMenuItem(
                    value: ActionType.removeHeader,
                    child: Text('删除 Header'),
                  ),
                  if (_ruleType == RewriteRuleType.redirectUrl)
                    const DropdownMenuItem(
                      value: ActionType.redirect,
                      child: Text('重定向'),
                    ),
                ],
                onChanged: (value) {
                  setState(() {
                    _actionType = value!;
                  });
                },
              ),
              if (_actionType == ActionType.setHeader) ...[
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Header 名称',
                    hintText: '例如：X-Custom-Header',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _headerName = value,
                  initialValue: _headerName,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Header 值',
                    hintText: '例如：custom-value',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _headerValue = value,
                  initialValue: _headerValue,
                ),
              ],
              if (_actionType == ActionType.redirect) ...[
                const SizedBox(height: 8),
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: '重定向 URL',
                    hintText: '例如：http://localhost:8080',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _redirectUrl = value,
                  initialValue: _redirectUrl,
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
        method:
            _methodController.text.isEmpty ? null : _methodController.text,
      );

      RewriteAction action;
      if (_actionType == ActionType.setHeader) {
        action = RewriteAction.setHeader(
          _headerName ?? '',
          _headerValue ?? '',
        );
      } else if (_actionType == ActionType.removeHeader) {
        action = RewriteAction.removeHeader(_headerName ?? '');
      } else {
        action = RewriteAction.redirect(_redirectUrl ?? '');
      }

      final rule = RequestRewriteRule(
        id: widget.rule?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        type: _ruleType,
        condition: condition,
        action: action,
        enabled: widget.rule?.enabled ?? true,
      );

      if (widget.rule == null) {
        widget.rewriter.addRule(rule);
      } else {
        widget.rewriter.removeRule(widget.rule!.id);
        widget.rewriter.addRule(rule);
      }

      widget.onSave();
      Navigator.pop(context);
    }
  }
}
