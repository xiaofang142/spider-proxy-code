import 'package:flutter/material.dart';
import '../../core/debugger/breakpoint_debugger.dart';

/// 断点编辑器对话框
/// 支持手动修改请求/响应内容
class BreakpointEditorDialog extends StatefulWidget {
  final BreakpointRequest? request;
  final BreakpointResponse? response;
  final Function(String url, String method, Map<String, String> headers, String body)? onSaveRequest;
  final Function(int statusCode, Map<String, String> headers, String body)? onSaveResponse;

  const BreakpointEditorDialog({
    super.key,
    this.request,
    this.response,
    this.onSaveRequest,
    this.onSaveResponse,
  });

  @override
  State<BreakpointEditorDialog> createState() => _BreakpointEditorDialogState();
}

class _BreakpointEditorDialogState extends State<BreakpointEditorDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 请求编辑器
  final _urlController = TextEditingController();
  final _methodController = TextEditingController();
  final _requestHeadersController = TextEditingController();
  final _requestBodyController = TextEditingController();

  // 响应编辑器
  final _statusCodeController = TextEditingController();
  final _responseHeadersController = TextEditingController();
  final _responseBodyController = TextEditingController();

  bool _isRequestModified = false;
  bool _isResponseModified = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    if (widget.request != null) {
      _urlController.text = widget.request!.url;
      _methodController.text = widget.request!.method;
      _requestHeadersController.text = _formatHeaders(widget.request!.headers);
      _requestBodyController.text = widget.request!.body;
    }

    if (widget.response != null) {
      _statusCodeController.text = widget.response!.statusCode.toString();
      _responseHeadersController.text = _formatHeaders(widget.response!.headers);
      _responseBodyController.text = widget.response!.body;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _urlController.dispose();
    _methodController.dispose();
    _requestHeadersController.dispose();
    _requestBodyController.dispose();
    _statusCodeController.dispose();
    _responseHeadersController.dispose();
    _responseBodyController.dispose();
    super.dispose();
  }

  String _formatHeaders(Map<String, String> headers) {
    return headers.entries.map((e) => '${e.key}: ${e.value}').join('\n');
  }

  Map<String, String> _parseHeaders(String text) {
    final headers = <String, String>{};
    for (final line in text.split('\n')) {
      final index = line.indexOf(':');
      if (index > 0) {
        final key = line.substring(0, index).trim();
        final value = line.substring(index + 1).trim();
        if (key.isNotEmpty && value.isNotEmpty) {
          headers[key] = value;
        }
      }
    }
    return headers;
  }

  @override
  Widget build(BuildContext context) {
    final isRequest = widget.request != null;

    return Dialog(
      child: Container(
        width: 800,
        height: 600,
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isRequest ? Colors.blue.shade50 : Colors.green.shade50,
                border: Border(
                  bottom: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isRequest ? Icons.send : Icons.reply,
                    color: isRequest ? Colors.blue : Colors.green,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isRequest ? '编辑请求' : '编辑响应',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const Spacer(),
                  if (isRequest && _isRequestModified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '已修改',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  if (!isRequest && _isResponseModified)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '已修改',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // 标签页
            TabBar(
              controller: _tabController,
              tabs: isRequest
                  ? const [
                      Tab(text: 'URL'),
                      Tab(text: 'Header'),
                      Tab(text: 'Body'),
                    ]
                  : const [
                      Tab(text: '状态码'),
                      Tab(text: 'Header'),
                      Tab(text: 'Body'),
                    ],
            ),
            // 内容区
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // 第一页：URL 或 状态码
                  if (isRequest)
                    _buildUrlTab()
                  else
                    _buildStatusCodeTab(),
                  // 第二页：Header
                  _buildHeadersTab(isRequest),
                  // 第三页：Body
                  _buildBodyTab(isRequest),
                ],
              ),
            ),
            // 底部按钮栏
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _handleContinue,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('继续 (不修改)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _handleModifyContinue,
                    icon: const Icon(Icons.edit),
                    label: Text(isRequest ? '修改后发送' : '修改后返回'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrlTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: _methodController,
            decoration: const InputDecoration(
              labelText: '方法',
              border: OutlineInputBorder(),
              prefixText: 'Method: ',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _urlController,
            decoration: const InputDecoration(
              labelText: 'URL',
              border: OutlineInputBorder(),
              prefixText: 'URL: ',
            ),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCodeTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _statusCodeController,
        decoration: const InputDecoration(
          labelText: '状态码',
          border: OutlineInputBorder(),
          prefixText: 'Status: ',
        ),
        keyboardType: TextInputType.number,
      ),
    );
  }

  Widget _buildHeadersTab(bool isRequest) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            '每行一个 Header，格式：Key: Value',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: isRequest
                  ? _requestHeadersController
                  : _responseHeadersController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Content-Type: application/json\nAuthorization: Bearer xxx',
              ),
              maxLines: null,
              expands: true,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyTab(bool isRequest) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _formatJson(isRequest),
                icon: const Icon(Icons.format_indent_increase),
                label: const Text('格式化 JSON'),
              ),
              const Spacer(),
              Text(
                '${(isRequest ? _requestBodyController.text : _responseBodyController.text).length} 字符',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TextField(
              controller: isRequest ? _requestBodyController : _responseBodyController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '{\n  "key": "value"\n}',
              ),
              maxLines: null,
              expands: true,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _formatJson(bool isRequest) {
    try {
      final text = isRequest
          ? _requestBodyController.text
          : _responseBodyController.text;
      // 简单的 JSON 格式化
      // 在实际应用中应该使用 dart:convert 的 JsonEncoder
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('JSON 格式化功能开发中...')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JSON 格式错误：$e')),
      );
    }
  }

  void _handleContinue() {
    // 不修改，直接继续
    if (widget.request != null && widget.onSaveRequest != null) {
      widget.onSaveRequest!(
        widget.request!.url,
        widget.request!.method,
        widget.request!.headers,
        widget.request!.body,
      );
    } else if (widget.response != null && widget.onSaveResponse != null) {
      widget.onSaveResponse!(
        widget.response!.statusCode,
        widget.response!.headers,
        widget.response!.body,
      );
    }
    Navigator.pop(context);
  }

  void _handleModifyContinue() {
    final isRequest = widget.request != null;

    if (isRequest && widget.onSaveRequest != null) {
      final newUrl = _urlController.text;
      final newMethod = _methodController.text;
      final newHeaders = _parseHeaders(_requestHeadersController.text);
      final newBody = _requestBodyController.text;

      widget.onSaveRequest!(newUrl, newMethod, newHeaders, newBody);
    } else if (!isRequest && widget.onSaveResponse != null) {
      final newStatusCode = int.tryParse(_statusCodeController.text) ?? 200;
      final newHeaders = _parseHeaders(_responseHeadersController.text);
      final newBody = _responseBodyController.text;

      widget.onSaveResponse!(newStatusCode, newHeaders, newBody);
    }

    Navigator.pop(context);
  }
}
