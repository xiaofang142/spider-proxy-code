import 'dart:typed_data';

/// PCAP 格式导出器
///
/// PCAP 是网络抓包的标准二进制格式
/// 可用于 Wireshark 等工具分析
class PcapExporter {
  static const int _pcapMagic = 0xA1B2C3D4;
  static const int _pcapVersionMajor = 2;
  static const int _pcapVersionMinor = 4;
  static const int _pcapLinkTypeEthernet = 1; // DLT_EN10MB

  /// 导出抓包数据为 PCAP 格式
  static Uint8List export(List<CaptureItem> captures) {
    final buffer = BytesBuilder();

    // 写入 PCAP 全局头部（24 字节）
    buffer.add(_writePcapGlobalHeader());

    // 写入每个数据包
    for (final capture in captures) {
      final packet = _createPacket(capture);
      if (packet != null) {
        buffer.add(packet);
      }
    }

    return buffer.toBytes();
  }

  static Uint8List _writePcapGlobalHeader() {
    final buffer = Uint8List(24);
    final byteData = ByteData.view(buffer.buffer);

    // 魔数
    byteData.setUint32(0, _pcapMagic, Endian.host);
    // 主版本号
    byteData.setUint16(4, _pcapVersionMajor, Endian.host);
    // 次版本号
    byteData.setUint16(6, _pcapVersionMinor, Endian.host);
    // 时区（通常为 0）
    byteData.setUint32(8, 0, Endian.host);
    // 时间戳精度（0 = 秒）
    byteData.setUint32(12, 0, Endian.host);
    // 最大捕获长度
    byteData.setUint32(16, 65535, Endian.host);
    // 链路层类型（以太网）
    byteData.setUint32(20, _pcapLinkTypeEthernet, Endian.host);

    return buffer;
  }

  static Uint8List? _createPacket(CaptureItem capture) {
    // 简化实现：创建伪以太网帧
    // 实际应用中需要完整的 IP/TCP 头部

    // 计算数据包大小
    final headerSize = 14; // 以太网头部
    final ipHeaderSize = 20; // IPv4 头部
    final tcpHeaderSize = 20; // TCP 头部（无选项）

    final payloadSize = (capture.requestSize ?? 0) + (capture.responseSize ?? 0);
    if (payloadSize == 0) {
      // 没有有效载荷，使用最小数据包
      final totalSize = headerSize + ipHeaderSize + tcpHeaderSize;
      final buffer = Uint8List(totalSize);
      final byteData = ByteData.view(buffer.buffer);

      // 以太网头部（目标 MAC + 源 MAC + 类型）
      // 使用伪 MAC 地址
      for (int i = 0; i < 6; i++) {
        buffer[i] = 0x00; // 目标 MAC
        buffer[6 + i] = 0x00; // 源 MAC
      }
      buffer[12] = 0x08; // IPv4
      buffer[13] = 0x00;

      // IP 头部
      _writeIpHeader(byteData, headerSize, capture);

      // TCP 头部
      _writeTcpHeader(byteData, headerSize + ipHeaderSize, capture);

      return _writePcapPacketHeader(buffer.length, capture.timestamp)
          .followedBy(buffer)
          .toList() as Uint8List;
    }

    return null;
  }

  static void _writeIpHeader(ByteData byteData, int offset, CaptureItem capture) {
    // 版本 + IHL
    byteData.setUint8(offset, 0x45);
    // 服务类型
    byteData.setUint8(offset + 1, 0x00);
    // 总长度（简化）
    byteData.setUint16(offset + 2, 40, Endian.big);
    // 标识
    byteData.setUint16(offset + 4, 0x0001, Endian.big);
    // 标志 + 片偏移
    byteData.setUint16(offset + 6, 0x4000, Endian.big);
    // TTL
    byteData.setUint8(offset + 8, 64);
    // 协议（TCP）
    byteData.setUint8(offset + 9, 6);
    // 头部校验和（简化为 0）
    byteData.setUint16(offset + 10, 0x0000, Endian.big);
    // 源 IP（简化）
    byteData.setUint32(offset + 12, 0x7F000001); // 127.0.0.1
    // 目标 IP（简化）
    byteData.setUint32(offset + 16, 0x7F000001);
  }

  static void _writeTcpHeader(ByteData byteData, int offset, CaptureItem capture) {
    // 源端口（简化）
    byteData.setUint16(offset, 8080, Endian.big);
    // 目标端口（简化）
    byteData.setUint16(offset + 2, 80, Endian.big);
    // 序列号
    byteData.setUint32(offset + 4, 0x00000001, Endian.big);
    // 确认号
    byteData.setUint32(offset + 8, 0x00000000, Endian.big);
    // 数据偏移 + 标志
    byteData.setUint8(offset + 12, 0x50);
    byteData.setUint8(offset + 13, 0x02); // SYN
    // 窗口大小
    byteData.setUint16(offset + 14, 65535, Endian.big);
    // 校验和（简化为 0）
    byteData.setUint16(offset + 16, 0x0000, Endian.big);
    // 紧急指针
    byteData.setUint16(offset + 18, 0x0000, Endian.big);
  }

  static Uint8List _writePcapPacketHeader(int packetLength, DateTime timestamp) {
    final buffer = Uint8List(16);
    final byteData = ByteData.view(buffer.buffer);

    // 时间戳（秒）
    byteData.setUint32(0, timestamp.millisecondsSinceEpoch ~/ 1000, Endian.host);
    // 时间戳（微秒）
    byteData.setUint32(4, (timestamp.millisecondsSinceEpoch % 1000) * 1000, Endian.host);
    // 捕获长度
    byteData.setUint32(8, packetLength, Endian.host);
    // 原始长度
    byteData.setUint32(12, packetLength, Endian.host);

    return buffer;
  }
}

/// 抓包项目模型
class CaptureItem {
  final String id;
  final String method;
  final String url;
  final int statusCode;
  final int? requestSize;
  final int? responseSize;
  final DateTime timestamp;

  const CaptureItem({
    required this.id,
    required this.method,
    required this.url,
    required this.statusCode,
    this.requestSize,
    this.responseSize,
    required this.timestamp,
  });
}
