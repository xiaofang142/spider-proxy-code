import 'dart:io';
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'certificate_manager.dart';

/// SSL/TLS 拦截器 - 用于 HTTPS 解密
///
/// 注意：完整的 MITM SSL 拦截需要：
/// 1. 拦截 TCP 连接
/// 2. 动态生成主机证书
/// 3. 建立双向 SSL 连接（客户端<->代理<->目标服务器）
/// 4. 解密/重新加密数据流
///
/// 由于 Dart 标准库对底层 SSL 拦截支持有限，实际生产环境应使用：
/// - Android: 通过 Platform Channel 调用 VpnService + PacketInputStream
/// - iOS: 通过 Network Extension 框架实现 Packet Tunnel Provider
class SslInterceptor {
  static final _uuid = const Uuid();

  SecurityContext? _context;
  bool _isInitialized = false;
  final CertificateManager _certManager;
  final Map<String, _CachedCert> _certCache = {};

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 证书缓存数量
  int get cachedCertCount => _certCache.length;

  SslInterceptor({CertificateManager? certManager})
      : _certManager = certManager ?? CertificateManager();

  /// 初始化 SSL 上下文
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 初始化证书管理器
    await _certManager.initialize();

    // 创建安全上下文
    _context = SecurityContext(withTrustedRoots: true);

    // 加载 CA 证书
    try {
      final caCertBytes = await _certManager.getCACertificateBytes();
      _context!.setTrustedCertificatesBytes(caCertBytes);
      print('[SslInterceptor] CA certificate loaded');
    } catch (e) {
      print('[SslInterceptor] Warning: Could not load CA certificate: $e');
    }

    _isInitialized = true;
  }

  /// 拦截 HTTPS 连接
  ///
  /// 注意：这是简化实现，实际 MITM 拦截需要：
  /// 1. 拦截客户端的 SSL ClientHello
  /// 2. 与目标服务器建立 SSL 连接
  /// 3. 动态生成主机证书
  /// 4. 与客户端建立 SSL 连接（使用生成的证书）
  /// 5. 双向解密/转发数据
  Future<Socket> interceptConnection(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (!_isInitialized) {
      throw StateError('SSL interceptor not initialized');
    }

    try {
      // 建立到目标服务器的连接
      final socket = await Socket.connect(host, port, timeout: timeout);

      // 注意：完整的 MITM 实现需要在这里：
      // 1. 获取客户端的 ClientHello
      // 2. 提取 SNI (Server Name Indication)
      // 3. 动态生成证书
      // 4. 建立两个 SSL 连接

      return socket;
    } catch (e) {
      print('[SslInterceptor] Error intercepting connection: $e');
      rethrow;
    }
  }

  /// 为指定主机获取或生成证书
  Future<SecurityContext> getSecurityContextForHost(String host) async {
    if (!_isInitialized) {
      throw StateError('SSL interceptor not initialized');
    }

    // 检查缓存
    final cached = _certCache[host];
    if (cached != null && !cached.isExpired) {
      return cached.context;
    }

    // 生成新证书
    final context = SecurityContext(withTrustedRoots: true);

    try {
      final certData = await _certManager.generateCertificateForHost(host);

      // 设置证书和私钥
      context.useCertificateChainBytes(certData['cert']!);
      context.usePrivateKeyBytes(certData['key']!);

      // 缓存证书
      _certCache[host] = _CachedCert(
        context: context,
        expires: DateTime.now().add(const Duration(hours: 1)),
      );

      print('[SslInterceptor] Generated certificate for host: $host');
    } catch (e) {
      print('[SslInterceptor] Error generating certificate for $host: $e');
    }

    return context;
  }

  /// 处理 HTTPS CONNECT 请求
  ///
  /// HTTPS 代理使用 CONNECT 方法建立隧道：
  /// 1. 客户端发送：CONNECT example.com:443 HTTP/1.1
  /// 2. 代理建立 TCP 连接到目标服务器
  /// 3. 代理返回：HTTP/1.1 200 Connection Established
  /// 4. 客户端开始 SSL 握手
  Future<Socket> handleConnectRequest(
    String host,
    int port,
    HttpRequest request,
  ) async {
    print('[SslInterceptor] HTTPS CONNECT to $host:$port');

    // 建立到目标服务器的 TCP 连接
    final socket = await Socket.connect(host, port);

    // 返回 200 响应，建立隧道
    request.response
      ..statusCode = HttpStatus.ok
      ..reasonPhrase = 'Connection Established'
      ..close();

    return socket;
  }

  /// 解密 HTTPS 流量 (占位实现)
  ///
  /// 注意：完整的 SSL 解密需要：
  /// 1. 使用 OpenSSL 或类似库进行实际的 SSL 解密
  /// 2. 或通过 Platform Channel 调用原生 SSL 库
  ///
  /// Dart 标准库不提供直接的 SSL 解密 API
  Future<Uint8List> decryptData(Uint8List encryptedData, String host) async {
    if (!_isInitialized) {
      throw StateError('SSL interceptor not initialized');
    }

    // 占位实现：返回原始数据
    // 实际生产环境需要调用 OpenSSL 或平台原生 API
    print('[SslInterceptor] Decrypting data for host: $host (${encryptedData.length} bytes)');
    return encryptedData;
  }

  /// 加密数据 (占位实现)
  Future<Uint8List> encryptData(Uint8List plainData, String host) async {
    if (!_isInitialized) {
      throw StateError('SSL interceptor not initialized');
    }

    // 占位实现：返回原始数据
    print('[SslInterceptor] Encrypting data for host: $host (${plainData.length} bytes)');
    return plainData;
  }

  /// 获取 CA 证书 (用于安装到设备)
  Future<Uint8List> getCACertificate() async {
    if (!_isInitialized) {
      throw StateError('SSL interceptor not initialized');
    }

    return await _certManager.getCACertificateBytes();
  }

  /// 安装 CA 证书到设备
  Future<bool> installCACertificate() async {
    if (!_isInitialized) {
      throw StateError('SSL interceptor not initialized');
    }

    return await _certManager.installCACertificate();
  }

  /// 清理证书缓存
  void clearCertCache() {
    _certCache.clear();
    print('[SslInterceptor] Certificate cache cleared');
  }

  /// 清理过期证书
  void pruneExpiredCerts() {
    final now = DateTime.now();
    _certCache.removeWhere((host, cert) => now.isAfter(cert.expires));
    print('[SslInterceptor] Pruned expired certificates');
  }

  /// 停止拦截器
  Future<void> stop() async {
    _certCache.clear();
    _isInitialized = false;
    print('[SslInterceptor] Stopped');
  }
}

/// 缓存的证书
class _CachedCert {
  final SecurityContext context;
  final DateTime expires;

  _CachedCert({
    required this.context,
    required this.expires,
  });

  bool get isExpired => DateTime.now().isAfter(expires);
}
