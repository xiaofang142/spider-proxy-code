import 'dart:io';
import 'dart:async';
import 'packet_tunnel.dart';
import 'route_config.dart';

/// VPN 服务状态
enum VpnStatus {
  disconnected,
  connecting,
  connected,
  disconnecting,
  error,
}

/// VPN 服务配置
class VpnServiceConfig {
  final String name;
  final TunnelConfig tunnelConfig;
  final RouteConfig routeConfig;
  final bool enableLogging;
  final bool autoReconnect;

  const VpnServiceConfig({
    this.name = 'Spider Proxy VPN',
    this.tunnelConfig = const TunnelConfig(),
    this.routeConfig = const RouteConfig(),
    this.enableLogging = true,
    this.autoReconnect = false,
  });
}

/// VPN 服务
/// 封装系统 VPN 功能，提供数据包捕获和转发
class VpnService {
  final VpnServiceConfig _config;
  PacketTunnel? _tunnel;
  VpnStatus _status = VpnStatus.disconnected;
  final StreamController<VpnStatus> _statusController = 
      StreamController<VpnStatus>.broadcast();
  final StreamController<String> _logController = 
      StreamController<String>.broadcast();
  
  DateTime? _connectedAt;
  int _bytesTransferred = 0;

  /// 当前状态
  VpnStatus get status => _status;

  /// 是否已连接
  bool get isConnected => _status == VpnStatus.connected;

  /// 状态流
  Stream<VpnStatus> get statusStream => _statusController.stream;

  /// 日志流
  Stream<String> get logStream => _logController.stream;

  /// 连接时长
  Duration get connectionDuration {
    if (_connectedAt == null) return Duration.zero;
    return DateTime.now().difference(_connectedAt!);
  }

  /// 传输字节数
  int get bytesTransferred => _bytesTransferred;

  VpnService({VpnServiceConfig? config})
      : _config = config ?? const VpnServiceConfig();

  /// 启动 VPN 服务
  Future<void> start() async {
    if (isConnected) {
      throw StateError('VPN service is already connected');
    }

    try {
      _updateStatus(VpnStatus.connecting);
      _log('Starting VPN service...');

      // 检查平台支持
      await _checkPlatformSupport();

      // 创建隧道
      _tunnel = PacketTunnel(config: _config.tunnelConfig);
      await _tunnel!.start();

      // 配置路由
      await _configureRoutes();

      // 更新状态
      _connectedAt = DateTime.now();
      _updateStatus(VpnStatus.connected);
      _log('VPN service started successfully');

      // 监听数据包
      _listenToPackets();
    } catch (e) {
      _log('Error starting VPN service: $e');
      _updateStatus(VpnStatus.error);
      rethrow;
    }
  }

  /// 停止 VPN 服务
  Future<void> stop() async {
    if (_status == VpnStatus.disconnected) return;

    try {
      _updateStatus(VpnStatus.disconnecting);
      _log('Stopping VPN service...');

      if (_tunnel != null) {
        await _tunnel!.stop();
        _tunnel = null;
      }

      _connectedAt = null;
      _updateStatus(VpnStatus.disconnected);
      _log('VPN service stopped');
    } catch (e) {
      _log('Error stopping VPN service: $e');
      _updateStatus(VpnStatus.error);
      rethrow;
    }
  }

  /// 检查平台支持
  Future<void> _checkPlatformSupport() async {
    final platform = Platform.operatingSystem;
    _log('Checking platform support: $platform');

    // 不同平台需要不同的 VPN 实现
    // macOS: NetworkExtension
    // Android: VpnService
    // iOS: NetworkExtension
    // Windows: WFP (Windows Filtering Platform)
    // Linux: TUN/TAP

    // 临时实现：仅记录
    _log('Platform: $platform (using simulated VPN)');
  }

  /// 配置路由
  Future<void> _configureRoutes() async {
    _log('Configuring routes...');
    
    final routes = _config.routeConfig.getRoutes();
    _log('Routes to configure: ${routes.length}');
    
    // TODO: 实现实际的路由配置
    // 这需要平台特定的实现和权限
  }

  /// 监听数据包
  void _listenToPackets() {
    if (_tunnel == null) return;

    _tunnel!.packetStream.listen(
      (packet) {
        _bytesTransferred += packet.length;
        _handlePacket(packet);
      },
      onError: (error) {
        _log('Packet error: $error');
      },
    );

    _tunnel!.logStream.listen((log) {
      _log('[Tunnel] $log');
    });
  }

  /// 处理数据包
  void _handlePacket(Uint8List packet) {
    // 解析并处理数据包
    // 可以在此处实现流量分析、过滤等功能
  }

  /// 更新状态
  void _updateStatus(VpnStatus status) {
    _status = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  /// 记录日志
  void _log(String message) {
    if (!_config.enableLogging) return;

    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] [VpnService] $message';
    print(logMessage);

    if (!_logController.isClosed) {
      _logController.add(logMessage);
    }
  }

  /// 获取统计信息
  VpnStats getStats() {
    return VpnStats(
      status: _status,
      isConnected: isConnected,
      connectionDuration: connectionDuration,
      bytesTransferred: _bytesTransferred,
      tunnelStats: _tunnel?.getStats(),
    );
  }

  /// 检查是否需要代理
  bool shouldProxy(String host) {
    return _config.routeConfig.shouldProxy(host);
  }
}

/// VPN 统计信息
class VpnStats {
  final VpnStatus status;
  final bool isConnected;
  final Duration connectionDuration;
  final int bytesTransferred;
  final TunnelStats? tunnelStats;

  VpnStats({
    required this.status,
    required this.isConnected,
    required this.connectionDuration,
    required this.bytesTransferred,
    this.tunnelStats,
  });

  Map<String, dynamic> toJson() {
    return {
      'status': status.name,
      'isConnected': isConnected,
      'connectionDurationSeconds': connectionDuration.inSeconds,
      'bytesTransferred': bytesTransferred,
      'tunnelStats': tunnelStats?.toJson(),
    };
  }
}
