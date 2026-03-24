import 'dart:io';

/// HTTP 代理服务器核心实现
class ProxyServer {
  HttpServer? _server;
  final int port;
  final String host;

  ProxyServer({this.port = 8888, this.host = '0.0.0.0'});

  bool get isRunning => _server != null;

  /// 启动代理服务器
  Future<void> start() async {
    if (isRunning) {
      throw StateError('Proxy server is already running');
    }

    _server = await HttpServer.bind(host, port);
    print('Proxy server started on $host:$port');

    await for (HttpRequest request in _server!) {
      _handleRequest(request);
    }
  }

  /// 停止代理服务器
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      print('Proxy server stopped');
    }
  }

  void _handleRequest(HttpRequest request) {
    // TODO: 实现请求处理逻辑
    // 1. 记录请求信息
    // 2. 转发请求到目标服务器
    // 3. 记录响应信息
    // 4. 返回响应给客户端
    request.response.statusCode = HttpStatus.notImplemented;
    request.response.write('Not Implemented');
    request.response.close();
  }
}
