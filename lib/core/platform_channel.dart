import 'dart:async';
import 'package:flutter/services.dart';

/// VPN 服务状态
enum VpnStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

/// VPN 服务统计信息
class VpnStats {
  final bool isRunning;
  final int bytesSent;
  final int bytesReceived;
  final String? vpnAddress;
  final String? proxyAddress;
  final int? proxyPort;

  VpnStats({
    required this.isRunning,
    required this.bytesSent,
    required this.bytesReceived,
    this.vpnAddress,
    this.proxyAddress,
    this.proxyPort,
  });

  factory VpnStats.fromMap(Map<dynamic, dynamic> map) {
    return VpnStats(
      isRunning: map['isRunning'] as bool? ?? false,
      bytesSent: map['bytesSent'] as int? ?? 0,
      bytesReceived: map['bytesReceived'] as int? ?? 0,
      vpnAddress: map['vpnAddress'] as String?,
      proxyAddress: map['proxyAddress'] as String?,
      proxyPort: map['proxyPort'] as int?,
    );
  }

  String get totalSent => _formatBytes(bytesSent);
  String get totalReceived => _formatBytes(bytesReceived);

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// Platform Channel - VPN 服务接口
///
/// 用于 Flutter 与 Android 原生代码通信
class VpnPlatformChannel {
  static const MethodChannel _channel = MethodChannel('com.spiderproxy/vpn');

  final StreamController<VpnStatus> _statusController = StreamController<VpnStatus>.broadcast();
  final StreamController<VpnStats> _statsController = StreamController<VpnStats>.broadcast();

  VpnStatus _currentStatus = VpnStatus.disconnected;
  VpnStats? _currentStats;

  /// 是否已初始化
  bool _isInitialized = false;

  /// VPN 状态流
  Stream<VpnStatus> get statusStream => _statusController.stream;

  /// VPN 统计流
  Stream<VpnStats> get statsStream => _statsController.stream;

  /// 当前状态
  VpnStatus get currentStatus => _currentStatus;

  /// 当前统计
  VpnStats? get currentStats => _currentStats;

  /// 初始化 Platform Channel
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 设置方法调用处理器
    _channel.setMethodCallHandler(_handleMethodCall);

    _isInitialized = true;
  }

  /// 处理来自原生代码的方法调用
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onVpnStatusChanged':
        _onStatusChanged(call.arguments as Map<dynamic, dynamic>);
        break;
      case 'onTrafficStatsUpdated':
        _onTrafficStatsUpdated(call.arguments as Map<dynamic, dynamic>);
        break;
    }
  }

  /// 处理 VPN 状态变化
  void _onStatusChanged(Map<dynamic, dynamic> args) {
    final statusStr = args['status'] as String;
    final isRunning = args['isRunning'] as bool;
    final bytesSent = args['bytesSent'] as int? ?? 0;
    final bytesReceived = args['bytesReceived'] as int? ?? 0;

    VpnStatus newStatus;
    switch (statusStr) {
      case 'connected':
        newStatus = VpnStatus.connected;
        break;
      case 'connecting':
        newStatus = VpnStatus.connecting;
        break;
      case 'disconnecting':
        newStatus = VpnStatus.disconnecting;
        break;
      case 'error':
        newStatus = VpnStatus.error;
        break;
      case 'disconnected':
      default:
        newStatus = VpnStatus.disconnected;
    }

    _currentStatus = newStatus;
    _currentStats = VpnStats(
      isRunning: isRunning,
      bytesSent: bytesSent,
      bytesReceived: bytesReceived,
    );

    _statusController.add(newStatus);
    _statsController.add(_currentStats!);
  }

  /// 处理流量统计更新
  void _onTrafficStatsUpdated(Map<dynamic, dynamic> args) {
    _currentStats = VpnStats.fromMap(args);
    _statsController.add(_currentStats!);
  }

  /// 启动 VPN
  Future<bool> startVpn({
    int port = 8888,
    String proxyAddress = '127.0.0.1',
  }) async {
    try {
      final result = await _channel.invokeMethod('startVpn', {
        'port': port,
        'proxyAddress': proxyAddress,
      });
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      print('[VpnPlatformChannel] Failed to start VPN: ${e.message}');
      return false;
    }
  }

  /// 停止 VPN
  Future<bool> stopVpn() async {
    try {
      final result = await _channel.invokeMethod('stopVpn');
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      print('[VpnPlatformChannel] Failed to stop VPN: ${e.message}');
      return false;
    }
  }

  /// 获取 VPN 状态
  Future<VpnStats> getStatus() async {
    try {
      final result = await _channel.invokeMethod('getStatus');
      return VpnStats.fromMap(result as Map<dynamic, dynamic>);
    } on PlatformException catch (e) {
      print('[VpnPlatformChannel] Failed to get status: ${e.message}');
      return VpnStats(
        isRunning: false,
        bytesSent: 0,
        bytesReceived: 0,
      );
    }
  }

  /// 获取流量统计
  Future<VpnStats> getTrafficStats() async {
    try {
      final result = await _channel.invokeMethod('getTrafficStats');
      return VpnStats.fromMap(result as Map<dynamic, dynamic>);
    } on PlatformException catch (e) {
      print('[VpnPlatformChannel] Failed to get traffic stats: ${e.message}');
      return VpnStats(
        isRunning: false,
        bytesSent: 0,
        bytesReceived: 0,
      );
    }
  }

  /// 请求 VPN 权限（Android）
  Future<bool> requestVpnPermission() async {
    // 这需要在原生代码中处理
    // Flutter 端调用后会启动系统权限对话框
    return true;
  }

  /// 清理资源
  Future<void> dispose() async {
    await _statusController.close();
    await _statsController.close();
  }
}

/// Platform Channel - 代理服务接口
class ProxyPlatformChannel {
  static const MethodChannel _channel = MethodChannel('com.spiderproxy/proxy');

  /// 启动代理服务
  Future<Map<dynamic, dynamic>> startProxy({
    int port = 8888,
    bool enableHttps = true,
  }) async {
    try {
      final result = await _channel.invokeMethod('startProxy', {
        'port': port,
        'enableHttps': enableHttps,
      });
      return result as Map<dynamic, dynamic>;
    } on PlatformException catch (e) {
      print('[ProxyPlatformChannel] Failed to start proxy: ${e.message}');
      return {'success': false, 'error': e.message};
    }
  }

  /// 停止代理服务
  Future<bool> stopProxy() async {
    try {
      final result = await _channel.invokeMethod('stopProxy');
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      print('[ProxyPlatformChannel] Failed to stop proxy: ${e.message}');
      return false;
    }
  }

  /// 安装 CA 证书
  Future<Map<dynamic, dynamic>> installCertificate() async {
    try {
      final result = await _channel.invokeMethod('installCertificate');
      return result as Map<dynamic, dynamic>;
    } on PlatformException catch (e) {
      print('[ProxyPlatformChannel] Failed to install certificate: ${e.message}');
      return {'success': false, 'error': e.message};
    }
  }

  /// 卸载 CA 证书
  Future<Map<dynamic, dynamic>> uninstallCertificate() async {
    try {
      final result = await _channel.invokeMethod('uninstallCertificate');
      return result as Map<dynamic, dynamic>;
    } on PlatformException catch (e) {
      print('[ProxyPlatformChannel] Failed to uninstall certificate: ${e.message}');
      return {'success': false, 'error': e.message};
    }
  }

  /// 检查证书是否已安装
  Future<bool> isCertificateInstalled() async {
    try {
      final result = await _channel.invokeMethod('isCertificateInstalled');
      return result as bool? ?? false;
    } on PlatformException catch (e) {
      print('[ProxyPlatformChannel] Failed to check certificate: ${e.message}');
      return false;
    }
  }

  /// 获取证书信息
  Future<Map<dynamic, dynamic>> getCertificateInfo() async {
    try {
      final result = await _channel.invokeMethod('getCertificateInfo');
      return result as Map<dynamic, dynamic>;
    } on PlatformException catch (e) {
      print('[ProxyPlatformChannel] Failed to get certificate info: ${e.message}');
      return {'isValid': false};
    }
  }

  /// 获取代理状态
  Future<Map<dynamic, dynamic>> getProxyStatus() async {
    try {
      final result = await _channel.invokeMethod('getProxyStatus');
      return result as Map<dynamic, dynamic>;
    } on PlatformException catch (e) {
      print('[ProxyPlatformChannel] Failed to get status: ${e.message}');
      return {'isRunning': false, 'vpnBound': false};
    }
  }
}
