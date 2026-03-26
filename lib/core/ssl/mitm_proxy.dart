import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import '../models/traffic_record.dart';
import '../models/request_detail.dart';
import '../models/response_detail.dart';
import 'certificate_manager.dart';
import 'ssl_interceptor.dart';

/// 中间人 (MITM) 代理配置
class MitmConfig {
  final int port;
  final String host;
  final Duration timeout;
  final bool enableCaching;
  final Duration cacheTtl;

  const MitmConfig({
    this.port = 8889,
    this.host = '0.0.0.0',
    this.timeout = const Duration(seconds: 30),
    this.enableCaching = true,
    this.cacheTtl = const Duration(minutes: 5),
  });
}

/// 中间人 (MITM) 代理服务器
///
/// 支持 HTTP 和 HTTPS 流量拦截和解密
///
/// 工作原理：
/// 1. HTTP 请求：直接拦截并转发
/// 2. HTTPS 请求：
///    - 客户端发送 CONNECT 请求
///    - 代理建立 TCP 隧道
///    - 动态生成主机证书
///    - 与客户端建立 SSL 连接
///    - 解密流量并记录
///
/// 注意：完整的 MITM 实现需要 Platform Channel 调用原生能力
class MitmProxy {
  static final _uuid = const Uuid();

  HttpServer? _server;
  final MitmConfig _config;
  final CertificateManager _certManager;
  final SslInterceptor _sslInterceptor;
  final StreamController<TrafficRecord> _trafficController =
      StreamController<TrafficRecord>.broadcast();

  bool _isRunning = false;
  DateTime? _startTime;
  int _requestCount = 0;

  /// 是否正在运行
  bool get isRunning => _isRunning && _server != null;

  /// 请求计数
  int get requestCount => _requestCount;

  /// 流量记录流
  Stream<TrafficRecord> get trafficStream => _trafficController.stream;

  MitmProxy({
    MitmConfig? config,
    CertificateManager? certManager,
    SslInterceptor? sslInterceptor,
  })  : _config = config ?? const MitmConfig(),
        _certManager = certManager ?? CertificateManager(),
        _sslInterceptor = sslInterceptor ?? SslInterceptor();

  /// 启动 MITM 代理
  Future<void> start() async {
    if (isRunning) {
      throw StateError('MITM proxy is already running');
    }

    // 初始化 SSL 拦截器
    await _sslInterceptor.initialize();

    try {
      _server = await HttpServer.bind(_config.host, _config.port);
      _isRunning = true;
      _startTime = DateTime.now();

      print('[MitmProxy] Started on ${_config.host}:${_config.port}');

      // 监听请求
      await for (HttpRequest request in _server!) {
        _handleRequest(request);
      }
    } catch (e) {
      print('[MitmProxy] Error starting server: $e');
      rethrow;
    }
  }

  /// 停止 MITM 代理
  Future<void> stop() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      _isRunning = false;
      _startTime = null;
      await _sslInterceptor.stop();
      print('[MitmProxy] Stopped');
    }
  }

  /// 处理 HTTP/HTTPS 请求
  void _handleRequest(HttpRequest request) async {
    _requestCount++;
    final startTime = DateTime.now();
    final recordId = _uuid.v4();

    try {
      // 检查是否是 CONNECT 请求 (HTTPS)
      if (request.method == 'CONNECT') {
        await _handleHttpsConnect(request, recordId, startTime);
      } else {
        // HTTP 请求
        await _handleHttpRequest(request, recordId, startTime);
      }
    } catch (e) {
      print('[MitmProxy] Error handling request: $e');
      _sendErrorResponse(request.response, e);
    }
  }

  /// 处理 HTTPS CONNECT 请求
  ///
  /// CONNECT 方法用于建立 SSL 隧道：
  /// 1. 客户端：CONNECT example.com:443 HTTP/1.1
  /// 2. 代理：建立 TCP 连接到 example.com:443
  /// 3. 代理：HTTP/1.1 200 Connection Established
  /// 4. 客户端：开始 SSL 握手
  /// 5. 代理：拦截并解密 SSL 流量
  Future<void> _handleHttpsConnect(
    HttpRequest request,
    String recordId,
    DateTime startTime,
  ) async {
    final host = request.uri.host;
    final port = request.uri.port;

    print('[MitmProxy] HTTPS CONNECT to $host:$port');

    // 建立到目标服务器的 TCP 连接
    final targetSocket = await Socket.connect(host, port);

    // 发送 200 响应给客户端
    await request.response
        ..statusCode = HttpStatus.ok
        ..reasonPhrase = 'Connection Established'
        ..close();

    // 创建双向数据流
    final clientSocket = request.connectionInfo!.socket;

    // 注意：完整的 MITM 实现需要在这里：
    // 1. 拦截客户端的 SSL ClientHello
    // 2. 动态生成主机证书
    // 3. 与客户端建立 SSL 连接（作为服务器）
    // 4. 与目标服务器建立 SSL 连接（作为客户端）
    // 5. 双向解密/记录/转发数据

    // 临时实现：直接桥接数据（不解密）
    await _bridgeSockets(clientSocket, targetSocket, recordId, startTime, host);
  }

  /// 桥接两个 Socket 的数据流
  Future<void> _bridgeSockets(
    Socket clientSocket,
    Socket targetSocket,
    String recordId,
    DateTime startTime,
    String host,
  ) async {
    final clientToTarget = StreamController<List<int>>();
    final targetToClient = StreamController<List<int>>();

    try {
      // 客户端 -> 目标服务器
      clientSocket.listen(
        (data) {
          if (!targetSocket.destroyed) {
            targetSocket.add(data);
          }
        },
        onDone: () {
          targetSocket.close();
        },
        onError: (e) {
          print('[MitmProxy] Client to target error: $e');
        },
      );

      // 目标服务器 -> 客户端
      targetSocket.listen(
        (data) {
          if (!clientSocket.destroyed) {
            clientSocket.add(data);
          }
        },
        onDone: () {
          clientSocket.close();
        },
        onError: (e) {
          print('[MitmProxy] Target to client error: $e');
        },
      );

      // 记录流量（简化版本）
      int bytesTransferred = 0;
      final durationMs = DateTime.now().difference(startTime).inMilliseconds;

      // 注意：完整的流量记录需要解密后分析
      // 这里仅记录连接的元数据
      final trafficRecord = TrafficRecord(
        id: recordId,
        timestamp: startTime,
        method: 'CONNECT',
        url: 'https://$host',
        host: host,
        path: '/',
        statusCode: 200,
        requestSize: 0,
        responseSize: 0,
        durationMs: durationMs,
        isHttps: true,
      );

      if (!_trafficController.isClosed) {
        _trafficController.add(trafficRecord);
      }

    } catch (e) {
      print('[MitmProxy] Bridge error: $e');
    }
  }

  /// 处理 HTTP 请求
  Future<void> _handleHttpRequest(
    HttpRequest request,
    String recordId,
    DateTime startTime,
  ) async {
    // 创建请求详情
    final requestDetail = await _readRequest(request, recordId);

    // 转发请求
    final responseDetail = await _forwardHttpRequest(request, requestDetail);

    // 计算耗时
    final durationMs = DateTime.now().difference(startTime).inMilliseconds;

    // 发送响应
    await _sendResponse(request.response, responseDetail);

    // 创建流量记录
    final trafficRecord = _createTrafficRecord(
      recordId,
      requestDetail,
      responseDetail,
      durationMs,
    );

    // 通知流量记录
    if (!_trafficController.isClosed) {
      _trafficController.add(trafficRecord);
    }
  }

  /// 读取请求详情
  Future<RequestDetail> _readRequest(HttpRequest request, String recordId) async {
    final body = await _readBody(request);

    return RequestDetail(
      id: _uuid.v4(),
      trafficRecordId: recordId,
      timestamp: DateTime.now(),
      method: request.method,
      uri: request.uri,
      headers: _headersToMap(request.headers),
      cookies: request.headers[HttpHeaders.cookieHeader]
              ?.split(';')
              .map((c) => c.trim())
              .toList() ??
          [],
      body: body,
      contentLength: request.headers.contentLength ?? 0,
      contentType: request.headers.contentType?.mimeType,
      userAgent: request.headers.value(HttpHeaders.userAgentHeader),
      clientIp: request.connectionInfo?.remoteAddress.address,
      clientPort: request.connectionInfo?.remoteAddress.port,
    );
  }

  /// 读取请求/响应体
  Future<String?> _readBody(HttpRequest request) async {
    if (request.method == 'GET' || request.method == 'HEAD') {
      return null;
    }

    try {
      final contentLength = request.headers.contentLength ?? 0;
      if (contentLength == 0) {
        return null;
      }

      final bytes = await request.fold<List<int>>(
        [],
        (list, data) => list..addAll(data),
      );

      // 尝试解码为字符串
      try {
        return String.fromCharCodes(bytes);
      } catch (e) {
        return null;
      }
    } catch (e) {
      print('[MitmProxy] Error reading body: $e');
      return null;
    }
  }

  /// 转发 HTTP 请求
  Future<ResponseDetail> _forwardHttpRequest(
    HttpRequest request,
    RequestDetail requestDetail,
  ) async {
    final client = HttpClient();

    try {
      // 创建目标请求
      final targetRequest = await client.openUrl(request.method, requestDetail.uri);

      // 复制请求头（排除代理相关头）
      request.headers.forEach((name, values) {
        if (name.toLowerCase() != 'host' &&
            name.toLowerCase() != 'proxy-connection' &&
            name.toLowerCase() != 'connection') {
          targetRequest.headers.set(name, values.join(', '));
        }
      });

      // 复制请求体
      if (requestDetail.body != null && requestDetail.body!.isNotEmpty) {
        targetRequest.write(requestDetail.body!);
      }

      // 发送并获取响应
      final targetResponse = await targetRequest.close();
      final responseBody = await _readResponse(targetResponse);

      return ResponseDetail(
        id: _uuid.v4(),
        trafficRecordId: requestDetail.trafficRecordId,
        timestamp: DateTime.now(),
        statusCode: targetResponse.statusCode,
        statusMessage: targetResponse.reasonPhrase,
        headers: _headersToMap(targetResponse.headers),
        body: responseBody,
        contentLength: targetResponse.headers.contentLength ??
            responseBody?.length ??
            0,
        contentType: targetResponse.headers.contentType?.mimeType,
      );
    } finally {
      client.close();
    }
  }

  /// 读取响应体
  Future<String?> _readResponse(HttpClientResponse response) async {
    try {
      final bytes = await response.fold<List<int>>(
        [],
        (list, data) => list..addAll(data),
      );

      // 尝试解码为字符串
      try {
        return String.fromCharCodes(bytes);
      } catch (e) {
        return null;
      }
    } catch (e) {
      print('[MitmProxy] Error reading response: $e');
      return null;
    }
  }

  /// 发送响应
  Future<void> _sendResponse(HttpResponse response, ResponseDetail responseDetail) async {
    response.statusCode = responseDetail.statusCode;
    if (responseDetail.statusMessage != null) {
      response.reasonPhrase = responseDetail.statusMessage;
    }

    responseDetail.headers.forEach((name, value) {
      if (name.toLowerCase() != 'transfer-encoding' &&
          name.toLowerCase() != 'content-length') {
        response.headers.set(name, value);
      }
    });

    if (responseDetail.body != null && responseDetail.body!.isNotEmpty) {
      response.write(responseDetail.body!);
    }

    await response.close();
  }

  /// 发送错误响应
  void _sendErrorResponse(HttpResponse response, dynamic error) {
    response
      ..statusCode = HttpStatus.badGateway
      ..reasonPhrase = 'Proxy Error'
      ..headers.set(HttpHeaders.contentTypeHeader, 'text/plain')
      ..write('Proxy Error: $error')
      ..close();
  }

  /// 创建流量记录
  TrafficRecord _createTrafficRecord(
    String recordId,
    RequestDetail requestDetail,
    ResponseDetail responseDetail,
    int durationMs,
  ) {
    return TrafficRecord(
      id: recordId,
      timestamp: requestDetail.timestamp,
      method: requestDetail.method,
      url: requestDetail.uri.toString(),
      host: requestDetail.uri.host,
      path: requestDetail.uri.path,
      statusCode: responseDetail.statusCode,
      requestSize: requestDetail.contentLength,
      responseSize: responseDetail.contentLength,
      durationMs: durationMs,
      requestType: requestDetail.contentType,
      responseType: responseDetail.contentType,
      isHttps: requestDetail.uri.scheme == 'https',
      clientIp: requestDetail.clientIp,
    );
  }

  /// 转换 HttpHeaders 为 Map
  Map<String, String> _headersToMap(HttpHeaders headers) {
    final result = <String, String>{};
    headers.forEach((name, values) {
      result[name] = values.join(', ');
    });
    return result;
  }

  /// 获取 CA 证书
  Future<Uint8List> getCACertificate() async {
    return await _sslInterceptor.getCACertificate();
  }

  /// 安装 CA 证书
  Future<bool> installCACertificate() async {
    return await _sslInterceptor.installCACertificate();
  }
}
