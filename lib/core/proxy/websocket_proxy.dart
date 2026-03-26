/// WebSocket 代理引擎
///
/// 支持 WebSocket 连接捕获、消息拦截和实时查看
library websocket_proxy;

import 'dart:async';
import 'dart:convert';

/// WebSocket 代理
class WebSocketProxy {
  final _connections = <WebSocketConnection>{};
  final ValueNotifier<List<WebSocketConnection>> connections =
      ValueNotifier([]);

  bool _enabled = true;

  /// 是否启用
  bool get enabled => _enabled;

  /// 获取所有连接
  Set<WebSocketConnection> get connectionsSet =>
      Set.unmodifiable(_connections);

  /// 启用 WebSocket 代理
  void enable() {
    _enabled = true;
  }

  /// 禁用 WebSocket 代理
  void disable() {
    _enabled = false;
    // 关闭所有连接
    for (final conn in _connections.toList()) {
      conn.close();
    }
  }

  /// 创建 WebSocket 连接
  Future<WebSocketConnection> createConnection(
    String url, {
    Map<String, String>? headers,
    List<String>? protocols,
  }) async {
    final connection = WebSocketConnection(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      url: url,
      headers: headers ?? {},
      protocols: protocols,
    );

    _connections.add(connection);
    _updateConnections();

    // 连接事件监听
    connection.state.addListener((_) {
      if (connection.state.value == WebSocketState.closed) {
        _connections.remove(connection);
        _updateConnections();
      }
    });

    return connection;
  }

  /// 移除连接
  void removeConnection(String connectionId) {
    final conn = _connections.firstWhere(
      (c) => c.id == connectionId,
      orElse: () => throw Exception('Connection not found'),
    );
    conn.close();
    _connections.remove(conn);
    _updateConnections();
  }

  /// 清除所有连接
  void clearConnections() {
    for (final conn in _connections.toList()) {
      conn.close();
    }
    _connections.clear();
    _updateConnections();
  }

  void _updateConnections() {
    connections.value = List.unmodifiable(_connections.toList());
  }

  /// 导入连接从 JSON
  void importConnections(List<Map<String, dynamic>> jsonList) {
    for (final json in jsonList) {
      // TODO: 实现导入逻辑
    }
  }

  /// 导出连接为 JSON
  List<Map<String, dynamic>> exportConnections() {
    return _connections.map((conn) => conn.toJson()).toList();
  }
}

/// WebSocket 连接状态
enum WebSocketState {
  /// 连接中
  connecting,

  /// 已连接
  open,

  /// 关闭中
  closing,

  /// 已关闭
  closed,
}

/// 消息方向
enum MessageDirection {
  /// 客户端到服务器
  clientToServer,

  /// 服务器到客户端
  serverToClient,
}

/// 消息类型
enum MessageType {
  /// 文本消息
  text,

  /// 二进制消息
  binary,
}

/// WebSocket 连接
class WebSocketConnection {
  final String id;
  final String url;
  final Map<String, String> headers;
  final List<String>? protocols;

  final ValueNotifier<WebSocketState> state =
      ValueNotifier(WebSocketState.connecting);

  final DateTime connectedAt;
  final List<WebSocketMessage> messages = [];
  final ValueNotifier<int> messageCount = ValueNotifier(0);

  // 元数据
  String? selectedProtocol;
  String? extensions;
  int? closeCode;
  String? closeReason;

  WebSocketConnection({
    required this.id,
    required this.url,
    this.headers = const {},
    this.protocols,
  }) : connectedAt = DateTime.now();

  /// 获取连接时长
  Duration get connectionDuration => DateTime.now().difference(connectedAt);

  /// 获取连接时长字符串
  String get connectionDurationString {
    final duration = connectionDuration;
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 添加消息
  void addMessage(WebSocketMessage message) {
    messages.add(message);
    messageCount.value = messages.length;
  }

  /// 发送消息
  Future<void> send(dynamic data) async {
    if (state.value != WebSocketState.open) {
      throw Exception('Connection is not open');
    }

    final message = WebSocketMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      connectionId: id,
      timestamp: DateTime.now(),
      direction: MessageDirection.clientToServer,
      type: data is String ? MessageType.text : MessageType.binary,
      payload: data,
    );

    addMessage(message);
    // TODO: 实际发送逻辑
  }

  /// 关闭连接
  void close({int? code, String? reason}) {
    state.value = WebSocketState.closing;
    closeCode = code;
    closeReason = reason;
    state.value = WebSocketState.closed;
  }

  /// 标记为已连接
  void markAsConnected({String? protocol, String? extensions}) {
    selectedProtocol = protocol;
    this.extensions = extensions;
    state.value = WebSocketState.open;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'state': state.value.name,
      'connectedAt': connectedAt.toIso8601String(),
      'messageCount': messages.length,
      if (selectedProtocol != null) 'selectedProtocol': selectedProtocol,
      if (extensions != null) 'extensions': extensions,
      if (closeCode != null) 'closeCode': closeCode,
      if (closeReason != null) 'closeReason': closeReason,
    };
  }

  factory WebSocketConnection.fromJson(Map<String, dynamic> json) {
    final conn = WebSocketConnection(
      id: json['id'] as String,
      url: json['url'] as String,
    );
    // TODO: 恢复其他字段
    return conn;
  }
}

/// WebSocket 消息
class WebSocketMessage {
  final String id;
  final String connectionId;
  final DateTime timestamp;
  final MessageDirection direction;
  final MessageType type;
  final dynamic payload;

  WebSocketMessage({
    required this.id,
    required this.connectionId,
    required this.timestamp,
    required this.direction,
    required this.type,
    required this.payload,
  });

  /// 获取消息大小
  int get size {
    if (payload is String) {
      return (payload as String).length;
    } else if (payload is List<int>) {
      return (payload as List<int>).length;
    }
    return 0;
  }

  /// 获取消息大小字符串
  String get sizeString {
    final size = this.size;
    if (size < 1024) {
      return '$size B';
    } else if (size < 1024 * 1024) {
      return '${(size / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  /// 获取 payload 字符串表示
  String get payloadString {
    if (payload is String) {
      return payload as String;
    } else if (payload is List<int>) {
      return 'Binary data (${sizeString})';
    }
    return payload.toString();
  }

  /// 尝试解析 JSON
  dynamic get parsedJson {
    if (payload is String) {
      try {
        return jsonDecode(payload as String);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// 获取方向文本
  String get directionText {
    switch (direction) {
      case MessageDirection.clientToServer:
        return '发送';
      case MessageDirection.serverToClient:
        return '接收';
    }
  }

  /// 获取类型文本
  String get typeText {
    switch (type) {
      case MessageType.text:
        return '文本';
      case MessageType.binary:
        return '二进制';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'connectionId': connectionId,
      'timestamp': timestamp.toIso8601String(),
      'direction': direction.name,
      'type': type.name,
      'size': size,
      if (payload is String) 'payload': payload,
    };
  }

  factory WebSocketMessage.fromJson(Map<String, dynamic> json) {
    return WebSocketMessage(
      id: json['id'] as String,
      connectionId: json['connectionId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      direction: MessageDirection.values.firstWhere(
        (e) => e.name == json['direction'],
      ),
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
      ),
      payload: json['payload'] ?? '',
    );
  }
}

/// WebSocket 握手信息
class WebSocketHandshake {
  final String id;
  final String connectionId;
  final DateTime timestamp;
  final String url;
  final Map<String, String> requestHeaders;
  final Map<String, String>? responseHeaders;
  final int? statusCode;

  WebSocketHandshake({
    required this.id,
    required this.connectionId,
    required this.timestamp,
    required this.url,
    this.requestHeaders = const {},
    this.responseHeaders,
    this.statusCode,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'connectionId': connectionId,
      'timestamp': timestamp.toIso8601String(),
      'url': url,
      'requestHeaders': requestHeaders,
      if (responseHeaders != null) 'responseHeaders': responseHeaders,
      if (statusCode != null) 'statusCode': statusCode,
    };
  }
}
