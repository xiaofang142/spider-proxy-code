import 'dart:io';
import 'dart:async';
import 'dart:typed_data';

/// 数据包隧道配置
class TunnelConfig {
  final String name;
  final String address;
  final String netmask;
  final List<String> routes;
  final List<String> dnsServers;
  final int mtu;

  const TunnelConfig({
    this.name = 'spider-tun',
    this.address = '10.0.0.1',
    this.netmask = '255.255.255.0',
    this.routes = const ['0.0.0.0/0'],
    this.dnsServers = const ['8.8.8.8', '8.8.4.4'],
    this.mtu = 1500,
  });
}

/// 数据包隧道
/// 用于捕获和处理网络数据包
class PacketTunnel {
  final TunnelConfig _config;
  RawDatagramSocket? _socket;
  bool _isRunning = false;
  final StreamController<Uint8List> _packetController = 
      StreamController<Uint8List>.broadcast();
  final StreamController<String> _logController = 
      StreamController<String>.broadcast();

  /// 是否正在运行
  bool get isRunning => _isRunning;

  /// 数据包流
  Stream<Uint8List> get packetStream => _packetController.stream;

  /// 日志流
  Stream<String> get logStream => _logController.stream;

  /// 配置信息
  TunnelConfig get config => _config;

  PacketTunnel({TunnelConfig? config})
      : _config = config ?? const TunnelConfig();

  /// 启动隧道
  Future<void> start() async {
    if (_isRunning) {
      throw StateError('Packet tunnel is already running');
    }

    try {
      // 创建 TUN 设备
      // 注意：这需要平台特定的实现
      // 在 macOS 上需要使用 NetworkExtension
      // 在 Android 上需要使用 VpnService
      // 这里提供基础框架
      
      _log('Starting packet tunnel...');
      _log('Configuration:');
      _log('  Name: ${_config.name}');
      _log('  Address: ${_config.address}');
      _log('  Netmask: ${_config.netmask}');
      _log('  Routes: ${_config.routes.join(', ')}');
      _log('  DNS: ${_config.dnsServers.join(', ')}');
      _log('  MTU: ${_config.mtu}');

      // 模拟隧道启动
      // 实际需要调用原生代码创建 TUN 设备
      await _setupTunDevice();
      
      _isRunning = true;
      _log('Packet tunnel started');
      
      // 开始监听数据包
      _startPacketListener();
    } catch (e) {
      _log('Error starting packet tunnel: $e');
      rethrow;
    }
  }

  /// 设置 TUN 设备
  Future<void> _setupTunDevice() async {
    // TODO: 实现平台特定的 TUN 设备创建
    // macOS: 使用 NetworkExtension NEPacketTunnelProvider
    // Android: 使用 VpnService.Builder
    // Linux: 打开 /dev/net/tun
    
    // 临时实现：创建 UDP socket 模拟
    _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    _log('TUN device created (simulated)');
  }

  /// 开始监听数据包
  void _startPacketListener() {
    if (_socket == null) return;

    _socket!.listen(
      (event) {
        if (event.type == SocketEvent.read) {
          try {
            final datagram = _socket!.receive();
            if (datagram != null) {
              _handlePacket(datagram.data);
            }
          } catch (e) {
            _log('Error receiving packet: $e');
          }
        }
      },
      onError: (error) {
        _log('Socket error: $error');
      },
      onDone: () {
        _log('Socket closed');
      },
    );
  }

  /// 处理数据包
  void _handlePacket(Uint8List packet) {
    // 解析 IP 包
    if (packet.length < 20) {
      _log('Invalid packet: too short');
      return;
    }

    final version = (packet[0] >> 4) & 0x0F;
    final protocol = packet[9];
    
    _log('Packet: IPv$version, Protocol: $protocol, Length: ${packet.length}');

    // 发送数据包到流
    if (!_packetController.isClosed) {
      _packetController.add(packet);
    }
  }

  /// 发送数据包
  Future<void> sendPacket(Uint8List packet, InternetAddress address, int port) async {
    if (!_isRunning || _socket == null) {
      throw StateError('Packet tunnel is not running');
    }

    try {
      _socket!.send(packet, address, port);
      _log('Sent packet to $address:$port (${packet.length} bytes)');
    } catch (e) {
      _log('Error sending packet: $e');
      rethrow;
    }
  }

  /// 写入数据包到 TUN 设备
  Future<void> writePacket(Uint8List packet) async {
    if (!_isRunning) {
      throw StateError('Packet tunnel is not running');
    }

    // TODO: 实现实际的数据包写入
    _log('Writing packet to TUN: ${packet.length} bytes');
  }

  /// 读取数据包从 TUN 设备
  Future<Uint8List?> readPacket() async {
    if (!_isRunning) {
      throw StateError('Packet tunnel is not running');
    }

    // TODO: 实现实际的数据包读取
    return null;
  }

  /// 停止隧道
  Future<void> stop() async {
    if (!_isRunning) return;

    _isRunning = false;
    
    if (_socket != null) {
      _socket!.close();
      _socket = null;
    }

    await _packetController.close();
    await _logController.close();
    
    _log('Packet tunnel stopped');
  }

  /// 记录日志
  void _log(String message) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $message';
    print(logMessage);
    
    if (!_logController.isClosed) {
      _logController.add(logMessage);
    }
  }

  /// 获取统计信息
  TunnelStats getStats() {
    return TunnelStats(
      isRunning: _isRunning,
      configName: _config.name,
      packetCount: 0, // TODO: 实现计数
      byteCount: 0,
    );
  }
}

/// 隧道统计信息
class TunnelStats {
  final bool isRunning;
  final String configName;
  final int packetCount;
  final int byteCount;

  TunnelStats({
    required this.isRunning,
    required this.configName,
    required this.packetCount,
    required this.byteCount,
  });

  Map<String, dynamic> toJson() {
    return {
      'isRunning': isRunning,
      'configName': configName,
      'packetCount': packetCount,
      'byteCount': byteCount,
    };
  }
}
