import 'dart:async';
import 'dart:io';
import 'proxy/proxy.dart';
import 'ssl/ssl.dart';
import 'models/models.dart';
import 'platform_channel.dart';

/// 代理服务管理器
/// 统一管理 HTTP 代理、HTTPS 解密和流量监控
class ProxyServiceManager {
  HttpProxyServer? _httpProxy;
  MitmProxy? _mitmProxy;
  CertificateManager? _certManager;
  VpnPlatformChannel? _vpnChannel;

  bool _isRunning = false;
  bool _isVpnMode = false;
  final StreamController<TrafficRecord> _trafficController =
      StreamController<TrafficRecord>.broadcast();
  final StreamController<String> _logController =
      StreamController<String>.broadcast();

  int _requestCount = 0;
  int _bytesTransferred = 0;
  DateTime? _startTime;

  /// 是否正在运行
  bool get isRunning => _isRunning;

  /// 请求计数
  int get requestCount => _requestCount;

  /// 传输字节数
  int get bytesTransferred => _bytesTransferred;

  /// 运行时长
  Duration get uptime {
    if (_startTime == null) return Duration.zero;
    return DateTime.now().difference(_startTime!);
  }

  /// 流量记录流
  Stream<TrafficRecord> get trafficStream => _trafficController.stream;

  /// 日志流
  Stream<String> get logStream => _logController.stream;

  /// 启动代理服务
  Future<void> start({
    int httpPort = 8888,
    int httpsPort = 8889,
    bool enableHttps = true,
    bool useVpnMode = false,
  }) async {
    if (_isRunning) {
      throw StateError('Proxy service is already running');
    }

    try {
      _log('Starting proxy service...');

      // 初始化证书管理器
      _certManager = CertificateManager();
      await _certManager!.initialize();

      // 如果使用 VPN 模式，启动 Android VPN 服务
      if (useVpnMode && Platform.isAndroid) {
        await _startVpnMode(port: httpPort);
      }

      // 创建请求/响应拦截器
      final requestInterceptor = DefaultRequestInterceptor();
      final responseInterceptor = DefaultResponseInterceptor();

      // 添加日志拦截器
      requestInterceptor.addInterceptor(LoggingRequestInterceptor());
      responseInterceptor.addInterceptor(LoggingResponseInterceptor());

      // 启动 HTTP 代理
      _httpProxy = HttpProxyServer(
        config: ProxyConfig(
          port: httpPort,
          enableHttps: enableHttps,
        ),
        requestInterceptor: requestInterceptor,
        responseInterceptor: responseInterceptor,
      );

      // 监听流量记录
      _httpProxy!.trafficStream.listen(_onTrafficRecorded);

      // 启动 HTTP 代理服务器（不阻塞）
      _httpProxy!.start().catchError((e) {
        _log('HTTP proxy error: $e');
      });

      // 启动 MITM 代理（如果需要 HTTPS）
      if (enableHttps) {
        _mitmProxy = MitmProxy(
          config: MitmConfig(port: httpsPort),
          certManager: _certManager,
        );
        _mitmProxy!.trafficStream.listen(_onTrafficRecorded);

        _mitmProxy!.start().catchError((e) {
          _log('MITM proxy error: $e');
        });
      }

      _isRunning = true;
      _isVpnMode = useVpnMode;
      _startTime = DateTime.now();
      _requestCount = 0;
      _bytesTransferred = 0;

      _log('Proxy service started');
      _log('HTTP proxy: port $httpPort');
      if (enableHttps) {
        _log('HTTPS proxy: port $httpsPort');
      }
      if (useVpnMode) {
        _log('VPN mode: enabled');
      }
    } catch (e) {
      _log('Error starting proxy service: $e');
      await stop();
      rethrow;
    }
  }

  /// 停止代理服务
  Future<void> stop() async {
    if (!_isRunning) return;

    try {
      _log('Stopping proxy service...');

      // 停止 VPN 模式
      if (_isVpnMode) {
        await _stopVpnMode();
      }

      if (_httpProxy != null) {
        await _httpProxy!.stop();
        _httpProxy = null;
      }

      if (_mitmProxy != null) {
        await _mitmProxy!.stop();
        _mitmProxy = null;
      }

      _isRunning = false;
      _isVpnMode = false;
      _startTime = null;
      _log('Proxy service stopped');
    } catch (e) {
      _log('Error stopping proxy service: $e');
      rethrow;
    }
  }

  /// 启动 VPN 模式
  Future<void> _startVpnMode({required int port}) async {
    try {
      _log('Starting VPN mode...');

      _vpnChannel = VpnPlatformChannel();
      await _vpnChannel!.initialize();

      final success = await _vpnChannel!.startVpn(
        port: port,
        proxyAddress: '127.0.0.1',
      );

      if (success) {
        _log('VPN mode started successfully');

        // 监听 VPN 状态
        _vpnChannel!.statusStream.listen((status) {
          _log('VPN status: ${status.name}');
        });

        // 监听流量统计
        _vpnChannel!.statsStream.listen((stats) {
          _bytesTransferred = stats.bytesSent + stats.bytesReceived;
        });
      } else {
        _log('Failed to start VPN mode');
      }
    } catch (e) {
      _log('Error starting VPN mode: $e');
    }
  }

  /// 停止 VPN 模式
  Future<void> _stopVpnMode() async {
    try {
      _log('Stopping VPN mode...');

      if (_vpnChannel != null) {
        await _vpnChannel!.stopVpn();
        await _vpnChannel!.dispose();
        _vpnChannel = null;
      }

      _log('VPN mode stopped');
    } catch (e) {
      _log('Error stopping VPN mode: $e');
    }
  }

  /// 获取 VPN 状态
  Future<VpnStatus?> getVpnStatus() async {
    if (_vpnChannel == null) return null;
    return _vpnChannel!.currentStatus;
  }

  /// 获取 VPN 统计
  Future<VpnStats?> getVpnStats() async {
    if (_vpnChannel == null) return null;
    return _vpnChannel!.currentStats;
  }

  /// 处理流量记录
  void _onTrafficRecorded(TrafficRecord record) {
    _requestCount++;
    _bytesTransferred += record.requestSize + record.responseSize;

    if (!_trafficController.isClosed) {
      _trafficController.add(record);
    }

    _log('[Traffic] ${record.method} ${record.url} - ${record.statusCode}');
  }

  /// 记录日志
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] [ProxyService] $message';
    print(logMessage);

    if (!_logController.isClosed) {
      _logController.add(logMessage);
    }
  }

  /// 获取 CA 证书
  Future<Uint8List> getCACertificate() async {
    if (_certManager == null) {
      throw StateError('Certificate manager not initialized');
    }
    return await _certManager!.getCACertificateBytes();
  }

  /// 安装 CA 证书
  Future<bool> installCACertificate() async {
    if (_certManager == null) {
      throw StateError('Certificate manager not initialized');
    }
    return await _certManager!.installCACertificate();
  }

  /// 卸载 CA 证书
  Future<Map<String, dynamic>> uninstallCACertificate() async {
    try {
      final result = await ProxyPlatformChannel().uninstallCertificate();
      return result;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 检查 CA 证书是否已安装并受信任
  Future<bool> isCACertificateTrusted() async {
    try {
      return await ProxyPlatformChannel().isCertificateInstalled();
    } catch (e) {
      return false;
    }
  }

  /// 获取服务状态
  ProxyServiceStatus getStatus() {
    return ProxyServiceStatus(
      isRunning: _isRunning,
      requestCount: _requestCount,
      bytesTransferred: _bytesTransferred,
      uptime: uptime,
      startTime: _startTime,
      httpProxyStats: _httpProxy?.getStats(),
    );
  }

  /// 初始化服务（预加载证书等）
  Future<void> initialize() async {
    _certManager = CertificateManager();
    await _certManager!.initialize();
    _log('Proxy service initialized');
  }

  /// 获取证书信息
  Future<Map<String, String>> getCertificateInfo() async {
    if (_certManager == null) {
      await initialize();
    }

    final certString = await _certManager!.getCACertificateString();

    // 解析证书信息（简化版本）
    final subject = _extractCertField(certString, 'Subject:');
    final issuer = _extractCertField(certString, 'Issuer:');
    final notBefore = _extractCertField(certString, 'Not Before:');
    final notAfter = _extractCertField(certString, 'Not After:');
    final fingerprint = _extractCertField(certString, 'SHA256 Fingerprint:');

    return {
      'subject': subject ?? 'Unknown',
      'issuer': issuer ?? 'Unknown',
      'validity': notBefore != null && notAfter != null
          ? '$notBefore ~ $notAfter'
          : 'Unknown',
      'fingerprint': fingerprint ?? 'Unknown',
    };
  }

  String? _extractCertField(String certContent, String fieldName) {
    final lines = certContent.split('\n');
    for (final line in lines) {
      if (line.contains(fieldName)) {
        return line.substring(line.indexOf(':') + 1).trim();
      }
    }
    return null;
  }

  /// 关闭服务
  Future<void> dispose() async {
    await stop();
    await _trafficController.close();
    await _logController.close();
  }
}

/// 代理服务状态
class ProxyServiceStatus {
  final bool isRunning;
  final int requestCount;
  final int bytesTransferred;
  final Duration uptime;
  final DateTime? startTime;
  final ProxyStats? httpProxyStats;

  ProxyServiceStatus({
    required this.isRunning,
    required this.requestCount,
    required this.bytesTransferred,
    required this.uptime,
    required this.startTime,
    this.httpProxyStats,
  });

  Map<String, dynamic> toJson() {
    return {
      'isRunning': isRunning,
      'requestCount': requestCount,
      'bytesTransferred': bytesTransferred,
      'uptimeSeconds': uptime.inSeconds,
      'startTime': startTime?.toIso8601String(),
      'httpProxyStats': httpProxyStats?.toJson(),
    };
  }
}
