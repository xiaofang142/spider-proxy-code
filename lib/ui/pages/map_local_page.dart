import 'package:flutter/material.dart';
import 'body_mapper.dart';

/// Map Local/Remote 管理页面
class MapLocalPage extends StatefulWidget {
  final BodyMapper mapper;

  const MapLocalPage({super.key, required this.mapper});

  @override
  State<MapLocalPage> createState() => _MapLocalPageState();
}

class _MapLocalPageState extends State<MapLocalPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('请求体替换'),
        actions: [
          Switch(
            value: widget.mapper.enabled,
            onChanged: (value) {
              setState(() {
                if (value) {
                  widget.mapper.enable();
                } else {
                  widget.mapper.disable();
                }
              });
            },
            activeColor: Theme.of(context).colorScheme.primary,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateRuleDialog(context),
          ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateRuleDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('新建规则'),
      ),
    );
  }

  Widget _buildBody() {
    final rules = widget.mapper.rules;

    if (rules.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.swap_horiz_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              '暂无规则',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '点击右下角 + 创建规则',
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
  }

  Widget _buildRuleCard(BodyMapperRule rule) {
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
                    rule.type == BodyMapType.local
                        ? Icons.folder
                        : Icons.cloud,
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
                        if (rule.description != null &&
                            rule.description!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            rule.description!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  Switch(
                    value: rule.enabled,
                    onChanged: (value) {
                      widget.mapper.toggleRule(rule.id, value);
                      setState(() {});
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 规则类型标签
              Row(
                children: [
                  _buildTypeChip(rule),
                  const SizedBox(width: 8),
                  _buildTargetChip(rule),
                ],
              ),
              const SizedBox(height: 12),
              // 匹配条件预览
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getConditionPreview(rule.condition),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _exportRule(context, rule),
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text(
                      '导出',
                      style: TextStyle(fontSize: 13),
                    ),
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

  Widget _buildTypeChip(BodyMapperRule rule) {
    final color = rule.type == BodyMapType.local ? Colors.blue : Colors.purple;
    final label = rule.type == BodyMapType.local ? 'Map Local' : 'Map Remote';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTargetChip(BodyMapperRule rule) {
    final color = rule.mapTarget == MapTarget.request ? Colors.orange : Colors.green;
    final label = rule.mapTarget == MapTarget.request ? '替换请求体' : '替换响应体';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _getConditionPreview(MatchCondition condition) {
    final parts = <String>[];
    if (condition.urlPattern != null) {
      parts.add('URL 包含 "${condition.urlPattern}"');
    }
    if (condition.urlContains != null) {
      parts.add('URL 包含 "${condition.urlContains}"');
    }
    if (condition.urlRegex != null) {
      parts.add('URL 匹配 "${condition.urlRegex}"');
    }
    if (condition.method != null) {
      parts.add('方法=${condition.method}');
    }
    if (condition.hostEquals != null) {
      parts.add('域名="${condition.hostEquals}"');
    }
    if (condition.hostContains != null) {
      parts.add('域名包含 "${condition.hostContains}"');
    }
    return parts.isEmpty ? '无条件（匹配所有）' : parts.join(', ');
  }

  void _showCreateRuleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _RuleEditorDialog(
        mapper: widget.mapper,
        onSave: () {
          setState(() {});
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showEditRuleDialog(BuildContext context, BodyMapperRule rule) {
    showDialog(
      context: context,
      builder: (context) => _RuleEditorDialog(
        mapper: widget.mapper,
        rule: rule,
        onSave: () {
          setState(() {});
          Navigator.pop(context);
        },
      ),
    );
  }

  void _deleteRule(BuildContext context, BodyMapperRule rule) {
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
              widget.mapper.removeRule(rule.id);
              setState(() {});
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

  void _exportRule(BuildContext context, BodyMapperRule rule) {
    // TODO: 实现导出功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导出功能开发中...')),
    );
  }
}

/// 规则编辑器对话框
class _RuleEditorDialog extends StatefulWidget {
  final BodyMapper mapper;
  final BodyMapperRule? rule;
  final VoidCallback onSave;

  const _RuleEditorDialog({
    required this.mapper,
    this.rule,
    required this.onSave,
  });

  @override
  State<_RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<_RuleEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _urlPatternController = TextEditingController();
  final _urlContainsController = TextEditingController();
  final _localPathController = TextEditingController();
  final _remoteUrlController = TextEditingController();

  BodyMapType _type = BodyMapType.local;
  MapTarget _mapTarget = MapTarget.response;
  String? _selectedMethod;

  @override
  void initState() {
    super.initState();
    if (widget.rule != null) {
      _nameController.text = widget.rule!.name;
      _descriptionController.text = widget.rule!.description ?? '';
      _urlPatternController.text = widget.rule!.condition.urlPattern ?? '';
      _urlContainsController.text = widget.rule!.condition.urlContains ?? '';
      _localPathController.text = widget.rule!.localPath ?? '';
      _remoteUrlController.text = widget.rule!.remoteUrl ?? '';
      _type = widget.rule!.type;
      _mapTarget = widget.rule!.mapTarget;
      _selectedMethod = widget.rule!.condition.method;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _urlPatternController.dispose();
    _urlContainsController.dispose();
    _localPathController.dispose();
    _remoteUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.rule == null ? '创建规则' : '编辑规则'),
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
              // 描述
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '描述',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              // 类型选择
              DropdownButtonFormField<BodyMapType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: '规则类型',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: BodyMapType.local,
                    child: Text('Map Local - 使用本地文件替换'),
                  ),
                  DropdownMenuItem(
                    value: BodyMapType.remote,
                    child: Text('Map Remote - 使用远程响应替换'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _type = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              // 替换目标
              DropdownButtonFormField<MapTarget>(
                value: _mapTarget,
                decoration: const InputDecoration(
                  labelText: '替换目标',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: MapTarget.request,
                    child: Text('替换请求体'),
                  ),
                  DropdownMenuItem(
                    value: MapTarget.response,
                    child: Text('替换响应体'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _mapTarget = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              // 匹配条件
              const Text('匹配条件', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              // URL 模式
              TextFormField(
                controller: _urlPatternController,
                decoration: const InputDecoration(
                  labelText: 'URL 包含',
                  hintText: '例如：/api/users',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // 请求方法
              DropdownButtonFormField<String?>(
                value: _selectedMethod,
                decoration: const InputDecoration(
                  labelText: '请求方法',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('不限'),
                  ),
                  const DropdownMenuItem(value: 'GET', child: Text('GET')),
                  const DropdownMenuItem(value: 'POST', child: Text('POST')),
                  const DropdownMenuItem(value: 'PUT', child: Text('PUT')),
                  const DropdownMenuItem(value: 'DELETE', child: Text('DELETE')),
                  const DropdownMenuItem(value: 'PATCH', child: Text('PATCH')),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedMethod = value;
                  });
                },
              ),
              const SizedBox(height: 16),
              // 本地文件路径/远程 URL
              if (_type == BodyMapType.local) ...[
                const Text('本地文件路径', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _localPathController,
                        decoration: const InputDecoration(
                          hintText: '/path/to/file.json',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (_type == BodyMapType.local &&
                              (value == null || value.isEmpty)) {
                            return '请输入本地文件路径';
                          }
                          return null;
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.folder_open),
                      onPressed: () => _selectFile(),
                    ),
                  ],
                ),
              ] else ...[
                const Text('远程 URL', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _remoteUrlController,
                  decoration: const InputDecoration(
                    hintText: 'https://example.com/response.json',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (_type == BodyMapType.remote &&
                        (value == null || value.isEmpty)) {
                      return '请输入远程 URL';
                    }
                    return null;
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

  Future<void> _selectFile() async {
    // TODO: 实现文件选择器
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('文件选择器开发中...')),
    );
  }

  void _saveRule() {
    if (_formKey.currentState!.validate()) {
      final rule = BodyMapperRule(
        id: widget.rule?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        description: _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        type: _type,
        mapTarget: _mapTarget,
        condition: MatchCondition(
          urlPattern: _urlPatternController.text.isEmpty
              ? null
              : _urlPatternController.text,
          urlContains: _urlContainsController.text.isEmpty
              ? null
              : _urlContainsController.text,
          method: _selectedMethod,
        ),
        localPath: _type == BodyMapType.local
            ? _localPathController.text
            : null,
        remoteUrl: _type == BodyMapType.remote
            ? _remoteUrlController.text
            : null,
      );

      if (widget.rule == null) {
        widget.mapper.addRule(rule);
      } else {
        widget.mapper.removeRule(widget.rule!.id);
        widget.mapper.addRule(rule);
      }

      widget.onSave();
    }
  }
}
