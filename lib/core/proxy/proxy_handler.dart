import 'dart:io';
import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/traffic_record.dart';
import '../models/request_detail.dart';
import '../models/response_detail.dart';
import 'request_interceptor.dart';
import 'response_interceptor.dart';

/// HTTP 代理请求处理器
class ProxyHandler {
  static final _uuid = const Uuid();
  
  final RequestInterceptor _requestInterceptor;
  final ResponseInterceptor _responseInterceptor;
  final Function(TrafficRecord)? _onTrafficRecorded;

  ProxyHandler({
    RequestInterceptor? requestInterceptor,
    ResponseInterceptor? responseInterceptor,
    this._onTrafficRecorded,
  })  : _requestInterceptor = requestInterceptor ?? DefaultRequestInterceptor(),
        _responseInterceptor = responseInterceptor ?? DefaultResponseInterceptor();

  /// 处理 HTTP 请求
  Future<void> handleRequest(HttpRequest request) async {
    final startTime = DateTime.now();
    final recordId = _uuid.v4();

    try {
      // 创建请求详情
      final requestDetail = await _createRequestDetail(request, recordId);

      // 拦截请求
      final shouldContinue = await _requestInterceptor.intercept(request, requestDetail);
      if (!shouldContinue) {
        return;
      }

      // 转发请求到目标服务器
      final responseDetail = await _forwardRequest(request, requestDetail);

      // 计算响应时间
      final durationMs = DateTime.now().difference(startTime).inMilliseconds;
      final finalResponseDetail = responseDetail.copyWith(
        responseTime: durationMs,
      );

      // 拦截响应
      await _responseInterceptor.intercept(request.response, finalResponseDetail);

      // 发送响应给客户端
      await _sendResponse(request.response, finalResponseDetail);

      // 创建流量记录
      final trafficRecord = _createTrafficRecord(
        recordId,
        requestDetail,
        finalResponseDetail,
        durationMs,
      );

      // 通知流量记录
      _onTrafficRecorded?.call(trafficRecord);

    } catch (e) {
      print('[ProxyHandler] Error handling request: $e');
      _sendErrorResponse(request.response, e);
    }
  }

  /// 创建请求详情
  Future<RequestDetail> _createRequestDetail(HttpRequest request, String recordId) async {
    final body = await _readRequestBody(request);
    
    return RequestDetail(
      id: _uuid.v4(),
      trafficRecordId: recordId,
      timestamp: DateTime.now(),
      method: request.method,
      uri: request.uri,
      headers: Map<String, String>.from(request.headers),
      cookies: request.headers[HttpHeaders.cookieHeader]?.split(';').map((c) => c.trim()).toList() ?? [],
      body: body,
      contentLength: request.headers.contentLength ?? 0,
      contentType: request.headers.contentType?.mimeType,
      userAgent: request.headers.value(HttpHeaders.userAgentHeader),
      referer: request.headers.value(HttpHeaders.refererHeader),
      origin: request.headers.value(HttpHeaders.originHeader),
      clientIp: request.connectionInfo?.remoteAddress.address,
      clientPort: request.connectionInfo?.remoteAddress.port,
    );
  }

  /// 读取请求体
  Future<String?> _readRequestBody(HttpRequest request) async {
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
      return String.fromCharCodes(bytes);
    } catch (e) {
      print('[ProxyHandler] Error reading request body: $e');
      return null;
    }
  }

  /// 转发请求到目标服务器
  Future<ResponseDetail> _forwardRequest(HttpRequest request, RequestDetail requestDetail) async {
    final responseDetailId = _uuid.v4();
    
    // 确定目标主机和端口
    String host = request.uri.host;
    int port = request.uri.port;

    // 如果是代理请求，从 Host 头或 URI 中获取目标
    if (request.uri.hasScheme) {
      host = request.uri.host;
      port = request.uri.port;
      if (port == 0) {
        port = request.uri.scheme == 'https' ? 443 : 80;
      }
    } else {
      final hostHeader = request.headers.value(HttpHeaders.hostHeader);
      if (hostHeader != null) {
        final parts = hostHeader.split(':');
        host = parts[0];
        if (parts.length > 1) {
          port = int.tryParse(parts[1]) ?? port;
        }
      }
    }

    // 创建目标 URI
    final targetUri = Uri(
      scheme: request.uri.scheme.isEmpty ? 'http' : request.uri.scheme,
      host: host,
      port: port,
      path: request.uri.path,
      query: request.uri.query,
    );

    // 创建 HTTP 客户端
    final client = HttpClient();
    
    try {
      // 创建请求
      HttpClientRequest targetRequest;
      if (request.method == 'CONNECT') {
        // CONNECT 方法用于 HTTPS 代理
        final socket = await _handleConnectMethod(request, host, port);
        return ResponseDetail(
          id: responseDetailId,
          trafficRecordId: requestDetail.trafficRecordId,
          timestamp: DateTime.now(),
          statusCode: 200,
          statusMessage: 'Connection Established',
        );
      } else {
        targetRequest = await client.openUrl(request.method, targetUri);
        
        // 复制请求头
        request.headers.forEach((name, values) {
          if (name.toLowerCase() != 'host' && 
              name.toLowerCase() != 'proxy-connection' &&
              name.toLowerCase() != 'connection') {
            targetRequest.headers.set(name, values.join(', '));
          }
        });

        // 复制请求体
        if (requestDetail.body != null) {
          targetRequest.write(requestDetail.body!);
        }

        // 发送请求并获取响应
        final targetResponse = await targetRequest.close();
        
        // 读取响应体
        final responseBody = await _readResponseBody(targetResponse);
        
        // 创建响应详情
        return ResponseDetail(
          id: responseDetailId,
          trafficRecordId: requestDetail.trafficRecordId,
          timestamp: DateTime.now(),
          statusCode: targetResponse.statusCode,
          statusMessage: targetResponse.reasonPhrase,
          headers: Map<String, String>.from(targetResponse.headers),
          cookies: targetResponse.headers[HttpHeaders.setCookieHeader]?.split(',').map((c) => c.trim()).toList() ?? [],
          body: responseBody,
          contentLength: targetResponse.headers.contentLength ?? responseBody?.length ?? 0,
          contentType: targetResponse.headers.contentType?.mimeType,
          server: targetResponse.headers.value(HttpHeaders.serverHeader),
        );
      }
    } finally {
      client.close();
    }
  }

  /// 处理 CONNECT 方法（用于 HTTPS 代理）
  Future<Socket> _handleConnectMethod(HttpRequest request, String host, int port) async {
    // 建立到目标服务器的 TCP 连接
    final socket = await Socket.connect(host, port);
    
    // 返回 200 响应，建立隧道
    request.response
      ..statusCode = HttpStatus.ok
      ..reasonPhrase = 'Connection Established'
      ..close();
    
    return socket;
  }

  /// 读取响应体
  Future<String?> _readResponseBody(HttpClientResponse response) async {
    try {
      final bytes = await response.fold<List<int>>(
        [],
        (list, data) => list..addAll(data),
      );
      return String.fromCharCodes(bytes);
    } catch (e) {
      return null;
    }
  }

  /// 发送响应给客户端
  Future<void> _sendResponse(HttpResponse response, ResponseDetail responseDetail) async {
    // 设置状态码
    response.statusCode = responseDetail.statusCode;
    if (responseDetail.statusMessage != null) {
      response.reasonPhrase = responseDetail.statusMessage;
    }

    // 设置响应头
    responseDetail.headers.forEach((name, value) {
      if (name.toLowerCase() != 'transfer-encoding' &&
          name.toLowerCase() != 'content-length') {
        response.headers.set(name, value);
      }
    });

    // 设置响应体
    if (responseDetail.body != null) {
      response.write(responseDetail.body!);
    }

    // 关闭响应
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
      port: requestDetail.clientPort,
    );
  }
}
