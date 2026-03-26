import 'dart:io';
import 'dart:async';
import '../models/traffic_record.dart';
import 'proxy_handler.dart';
import 'request_interceptor.dart';
import 'response_interceptor.dart';

/// HTTP 代理服务器配置
class ProxyConfig {
  final int port;
  final String host;
  final bool enableHttps;
  final Duration timeout;
  final int maxConnections;

  const ProxyConfig({
    this.port = 8888,
    this.host = '0.0.0.0',
    this.enableHttps = true,
    this.timeout = const Duration(seconds: 30),
    this.maxConnections = 100,
  });
}

/// HTTP 代理服务器
class HttpProxyServer {
  HttpServer? _server;
  final ProxyConfig _config;
  final ProxyHandler _handler;
  final StreamController<TrafficRecord> _trafficController = 
      StreamController<TrafficRecord>.broadcast();
  
  bool _isRunning = false;
  int _connectionCount = 0;
  DateTime? _startTime;

  /// 代理服务器是否正在运行
  bool get isRunning => _isRunning && _server != null;

  /// 服务器端口
  int get port => _config.port;

  /// 服务器主机
  String get host => _config.host;

  /// 连接数
  int get connectionCount => _connectionCount;

  /// 运行时长
  Duration get uptime {
    if (_startTime == null) return Duration.zero;
    return DateTime.now().difference(_startTime!);
  }

  /// 流量记录流
  Stream<TrafficRecord> get trafficStream => _trafficController.stream;

  HttpProxyServer({
    ProxyConfig? config,
    RequestInterceptor? requestInterceptor,
    ResponseInterceptor? responseInterceptor,
  })  : _config = config ?? const ProxyConfig(),
        _handler = ProxyHandler(
          requestInterceptor: requestInterceptor,
          responseInterceptor: responseInterceptor,
          _onTrafficRecorded: _onTrafficRecorded,
        );

  /// 启动代理服务器
  Future<void> start() async {
    if (isRunning) {
      throw StateError('Proxy server is already running');
    }

    try {
      _server = await HttpServer.bind(_config.host, _config.port);
      _isRunning = true;
      _startTime = DateTime.now();
      
      print('[HttpProxyServer] Started on ${_config.host}:${_config.port}');
      
      // 监听请求
      await for (HttpRequest request in _server!) {
        _handleConnection(request);
      }
    } catch (e) {
      print('[HttpProxyServer] Error starting server: $e');
      rethrow;
    }
  }

  /// 停止代理服务器
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      _isRunning = false;
      _startTime = null;
      print('[HttpProxyServer] Stopped');
    }
  }

  /// 处理连接
  void _handleConnection(HttpRequest request) async {
    _connectionCount++;
    
    try {
      await _handler.handleRequest(request);
    } catch (e) {
      print('[HttpProxyServer] Error handling connection: $e');
    } finally {
      _connectionCount--;
    }
  }

  /// 流量记录回调
  void _onTrafficRecorded(TrafficRecord record) {
    if (!_trafficController.isClosed) {
      _trafficController.add(record);
    }
  }

  /// 获取服务器统计信息
  ProxyStats getStats() {
    return ProxyStats(
      isRunning: isRunning,
      port: _config.port,
      host: _config.host,
      connectionCount: _connectionCount,
      uptime: uptime,
      startTime: _startTime,
    );
  }
}

/// 代理服务器统计信息
class ProxyStats {
  final bool isRunning;
  final int port;
  final String host;
  final int connectionCount;
  final Duration uptime;
  final DateTime? startTime;

  ProxyStats({
    required this.isRunning,
    required this.port,
    required this.host,
    required this.connectionCount,
    required this.uptime,
    required this.startTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'isRunning': isRunning,
      'port': port,
      'host': host,
      'connectionCount': connectionCount,
      'uptimeSeconds': uptime.inSeconds,
      'startTime': startTime?.toIso8601String(),
    };
  }
}
