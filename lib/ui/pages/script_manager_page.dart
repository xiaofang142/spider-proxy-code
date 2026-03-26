import 'package:flutter/material.dart';
import 'script_engine.dart';

/// 脚本管理页面
class ScriptManagerPage extends StatefulWidget {
  final ScriptEngine engine;

  const ScriptManagerPage({super.key, required this.engine});

  @override
  State<ScriptManagerPage> createState() => _ScriptManagerPageState();
}

class _ScriptManagerPageState extends State<ScriptManagerPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('脚本系统'),
        actions: [
          Switch(
            value: widget.engine.enabled,
            onChanged: (value) {
              setState(() {
                if (value) {
                  widget.engine.enable();
                } else {
                  widget.engine.disable();
                }
              });
            },
            activeColor: Theme.of(context).colorScheme.primary,
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateScriptDialog(context),
          ),
        ],
      ),
      body: ValueListenableBuilder<List<Script>>(
        valueListenable: _scriptsNotifier,
        builder: (context, scripts, child) {
          if (scripts.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.code_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '暂无脚本',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '点击右下角 + 创建脚本',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => _loadBuiltInScripts(),
                    icon: const Icon(Icons.download),
                    label: const Text('加载内置模板'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: scripts.length,
            itemBuilder: (context, index) {
              final script = scripts[index];
              return _buildScriptCard(script);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateScriptDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('新建脚本'),
      ),
    );
  }

  final ValueNotifier<List<Script>> _scriptsNotifier = ValueNotifier([]);

  @override
  void initState() {
    super.initState();
    _updateScripts();
  }

  void _updateScripts() {
    _scriptsNotifier.value = List.unmodifiable(widget.engine.scripts);
  }

  void _loadBuiltInScripts() {
    widget.engine.loadBuiltInTemplates();
    _updateScripts();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已加载内置脚本模板')),
    );
  }

  Widget _buildScriptCard(Script script) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showEditScriptDialog(context, script),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _getScriptTypeIcon(script.type),
                    size: 24,
                    color: script.enabled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          script.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (script.description != null && script.description!.isNotEmpty)
                          const SizedBox(height: 4),
                        if (script.description != null && script.description!.isNotEmpty)
                          Text(
                            script.description!,
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
                    value: script.enabled,
                    onChanged: (value) {
                      widget.engine.toggleScript(script.id, value);
                      _updateScripts();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 脚本类型标签
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getScriptTypeColor(script.type).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _getScriptTypeColor(script.type).withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _getScriptTypeText(script.type),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getScriptTypeColor(script.type),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 代码预览
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    _getCodePreview(script.code),
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: Colors.grey.shade800,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _runScript(context, script),
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('运行', style: TextStyle(fontSize: 13)),
                  ),
                  TextButton.icon(
                    onPressed: () => _showEditScriptDialog(context, script),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('编辑', style: TextStyle(fontSize: 13)),
                  ),
                  TextButton.icon(
                    onPressed: () => _exportScript(context, script),
                    icon: const Icon(Icons.share, size: 16),
                    label: const Text('导出', style: TextStyle(fontSize: 13)),
                  ),
                  TextButton.icon(
                    onPressed: () => _deleteScript(context, script),
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

  IconData _getScriptTypeIcon(ScriptType type) {
    switch (type) {
      case ScriptType.onRequest:
        return Icons.arrow_outward;
      case ScriptType.onResponse:
        return Icons.arrow_downward;
      case ScriptType.universal:
        return Icons.code;
    }
  }

  String _getScriptTypeText(ScriptType type) {
    switch (type) {
      case ScriptType.onRequest:
        return '请求拦截';
      case ScriptType.onResponse:
        return '响应拦截';
      case ScriptType.universal:
        return '通用脚本';
    }
    return '';
  }

  Color _getScriptTypeColor(ScriptType type) {
    switch (type) {
      case ScriptType.onRequest:
        return Colors.blue;
      case ScriptType.onResponse:
        return Colors.green;
      case ScriptType.universal:
        return Colors.purple;
    }
  }

  String _getCodePreview(String code) {
    final lines = code.split('\n');
    if (lines.length > 3) {
      return lines.take(3).join('\n') + '\n...';
    }
    return code;
  }

  void _showCreateScriptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _ScriptEditorDialog(
        engine: widget.engine,
        onSave: _updateScripts,
      ),
    );
  }

  void _showEditScriptDialog(BuildContext context, Script script) {
    showDialog(
      context: context,
      builder: (context) => _ScriptEditorDialog(
        engine: widget.engine,
        script: script,
        onSave: _updateScripts,
      ),
    );
  }

  void _deleteScript(BuildContext context, Script script) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除脚本"${script.name}"吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.engine.removeScript(script.id);
              _updateScripts();
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

  void _runScript(BuildContext context, Script script) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('脚本"${script.name}"已启用')),
    );
  }

  void _exportScript(BuildContext context, Script script) {
    // TODO: 实现导出功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('导出功能开发中...')),
    );
  }
}

/// 脚本编辑器对话框
class _ScriptEditorDialog extends StatefulWidget {
  final ScriptEngine engine;
  final Script? script;
  final VoidCallback onSave;

  const _ScriptEditorDialog({
    required this.engine,
    this.script,
    required this.onSave,
  });

  @override
  State<_ScriptEditorDialog> createState() => _ScriptEditorDialogState();
}

class _ScriptEditorDialogState extends State<_ScriptEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _codeController = TextEditingController();

  ScriptType _type = ScriptType.universal;

  @override
  void initState() {
    super.initState();
    if (widget.script != null) {
      _nameController.text = widget.script!.name;
      _descriptionController.text = widget.script!.description ?? '';
      _codeController.text = widget.script!.code;
      _type = widget.script!.type;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.script == null ? '创建脚本' : '编辑脚本'),
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
                  labelText: '脚本名称',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '请输入脚本名称';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '描述',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ScriptType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: '脚本类型',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ScriptType.universal,
                    child: Text('通用脚本'),
                  ),
                  DropdownMenuItem(
                    value: ScriptType.onRequest,
                    child: Text('请求拦截'),
                  ),
                  DropdownMenuItem(
                    value: ScriptType.onResponse,
                    child: Text('响应拦截'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _type = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text('脚本代码', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 300,
                child: TextFormField(
                  controller: _codeController,
                  decoration: const InputDecoration(
                    hintText: '// JavaScript 代码\nfunction onRequest(context) {\n  // ...\n}',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return '请输入脚本代码';
                    }
                    return null;
                  },
                ),
              ),
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
          onPressed: _saveScript,
          child: const Text('保存'),
        ),
      ],
    );
  }

  void _saveScript() {
    if (_formKey.currentState!.validate()) {
      final script = Script(
        id: widget.script?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        code: _codeController.text,
        type: _type,
        enabled: widget.script?.enabled ?? true,
      );

      if (widget.script == null) {
        widget.engine.addScript(script);
      } else {
        widget.engine.removeScript(widget.script!.id);
        widget.engine.addScript(script);
      }

      widget.onSave();
      Navigator.pop(context);
    }
  }
}
