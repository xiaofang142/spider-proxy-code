/// WebSocket 压缩工具
///
/// 实现 RFC 7692 定义的 permessage-deflate 扩展
library websocket_compression;

import 'package:archive/archive.dart';

/// WebSocket 压缩工具类
class WebSocketCompression {
  /// 压缩数据
  ///
  /// 使用 deflate 算法压缩原始数据
  static List<int> compress(List<int> data) {
    final deflate = Deflate();
    return deflate.process(data);
  }

  /// 解压缩数据
  ///
  /// 使用 inflate 算法解压缩 deflate 压缩的数据
  static List<int> decompress(List<int> data) {
    final inflate = Inflate();
    return inflate.process(data);
  }

  /// 计算压缩率
  ///
  /// 返回压缩后的大小与原始大小的比率（0-1 之间）
  static double calculateCompressionRatio(List<int> original, List<int> compressed) {
    if (original.isEmpty) return 0.0;
    return 1.0 - (compressed.length / original.length);
  }
}
