import 'package:flutter/material.dart';
import 'websocket_proxy.dart';

/// WebSocket 抓包页面
class WebSocketPage extends StatefulWidget {
  final WebSocketProxy proxy;

  const WebSocketPage({super.key, required this.proxy});

  @override
  State<WebSocketPage> createState() => _WebSocketPageState();
}

class _WebSocketPageState extends State<WebSocketPage> {
  int? _selectedConnectionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WebSocket'),
        actions: [
          Switch(
            value: widget.proxy.enabled,
            onChanged: (value) {
              setState(() {
                if (value) {
                  widget.proxy.enable();
                } else {
                  widget.proxy.disable();
                }
              });
            },
            activeColor: Theme.of(context).colorScheme.primary,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () => _confirmClear(),
          ),
        ],
      ),
      body: Row(
        children: [
          // 连接列表
          SizedBox(
            width: 300,
            child: _buildConnectionList(),
          ),
          const VerticalDivider(width: 1),
          // 消息流
          Expanded(
            child: _selectedConnectionId != null
                ? _buildMessageStream()
                : _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.devices,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '连接列表',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ValueListenableBuilder<List<WebSocketConnection>>(
            valueListenable: widget.proxy.connections,
            builder: (context, connections, child) {
              if (connections.isEmpty) {
                return _buildEmptyConnectionList();
              }

              return ListView.builder(
                itemCount: connections.length,
                itemBuilder: (context, index) {
                  final conn = connections[index];
                  return _buildConnectionTile(conn);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyConnectionList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off_outlined,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无 WebSocket 连接',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '应用使用 WebSocket 时会在此显示',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionTile(WebSocketConnection conn) {
    final isSelected = _selectedConnectionId == conn.id;

    return ListTile(
      selected: isSelected,
      leading: ValueListenableBuilder<WebSocketState>(
        valueListenable: conn.state,
        builder: (context, state, child) {
          return Icon(
            _getStateIcon(state),
            color: _getStateColor(state),
          );
        },
      ),
      title: Text(
        _getHost(conn.url),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          ValueListenableBuilder<int>(
            valueListenable: conn.messageCount,
            builder: (context, count, child) {
              return Text(
                '$count 条消息',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              );
            },
          ),
          const SizedBox(height: 2),
          Text(
            conn.connectionDurationString,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.close, size: 18),
        onPressed: () => _closeConnection(conn),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
      onTap: () {
        setState(() {
          _selectedConnectionId = conn.id;
        });
      },
    );
  }

  Widget _buildMessageStream() {
    final conn = widget.proxy.connectionsSet.firstWhere(
      (c) => c.id == _selectedConnectionId,
      orElse: () => throw Exception('Connection not found'),
    );

    return Column(
      children: [
        // 连接信息栏
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ValueListenableBuilder<WebSocketState>(
                    valueListenable: conn.state,
                    builder: (context, state, child) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStateColor(state).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _getStateText(state),
                          style: TextStyle(
                            fontSize: 12,
                            color: _getStateColor(state),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      conn.url,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '时长：${conn.connectionDurationString}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '消息：${conn.messages.length}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // 消息列表
        Expanded(
          child: ValueListenableBuilder<List<WebSocketMessage>>(
            valueListenable: _messagesNotifier,
            builder: (context, messages, child) {
              if (messages.isEmpty) {
                return _buildEmptyMessageList();
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  return _buildMessageCard(message);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  ValueNotifier<List<WebSocketMessage>> get _messagesNotifier {
    final conn = widget.proxy.connectionsSet.firstWhere(
      (c) => c.id == _selectedConnectionId,
      orElse: () => throw Exception('Connection not found'),
    );
    return ValueNotifier(List.unmodifiable(conn.messages));
  }

  Widget _buildEmptyMessageList() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无消息',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'WebSocket 通信消息会实时显示在此',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageCard(WebSocketMessage message) {
    final isOutgoing = message.direction == MessageDirection.clientToServer;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isOutgoing ? Colors.blue.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  message.directionText,
                  style: TextStyle(
                    fontSize: 11,
                    color: isOutgoing ? Colors.blue : Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                message.typeText,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                message.sizeString,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.maxFinite,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isOutgoing
                  ? Theme.of(context).colorScheme.primaryContainer
                  : Theme.of(context).colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message.payloadString,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(message.timestamp),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.touch_app_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            '选择连接查看详情',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击左侧列表中的 WebSocket 连接',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getStateIcon(WebSocketState state) {
    switch (state) {
      case WebSocketState.connecting:
        return Icons.sync;
      case WebSocketState.open:
        return Icons.check_circle;
      case WebSocketState.closing:
        return Icons.pause_circle;
      case WebSocketState.closed:
        return Icons.cancel;
    }
  }

  Color _getStateColor(WebSocketState state) {
    switch (state) {
      case WebSocketState.connecting:
        return Colors.orange;
      case WebSocketState.open:
        return Colors.green;
      case WebSocketState.closing:
        return Colors.orange;
      case WebSocketState.closed:
        return Colors.grey;
    }
  }

  String _getStateText(WebSocketState state) {
    switch (state) {
      case WebSocketState.connecting:
        return '连接中';
      case WebSocketState.open:
        return '已连接';
      case WebSocketState.closing:
        return '关闭中';
      case WebSocketState.closed:
        return '已关闭';
    }
  }

  String _getHost(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host;
    } catch (e) {
      return url;
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
  }

  void _closeConnection(WebSocketConnection conn) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认关闭'),
        content: Text('确定要关闭 WebSocket 连接 "${_getHost(conn.url)}" 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.proxy.removeConnection(conn.id);
              Navigator.pop(context);
              if (mounted) {
                setState(() {
                  _selectedConnectionId = null;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  void _confirmClear() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有 WebSocket 连接和消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              widget.proxy.clearConnections();
              Navigator.pop(context);
              if (mounted) {
                setState(() {
                  _selectedConnectionId = null;
                });
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
