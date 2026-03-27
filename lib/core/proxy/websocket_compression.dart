/// WebSocket 压缩工具
///
/// 实现 RFC 7692 定义的 permessage-deflate 扩展
library websocket_compression;

import 'package:archive/archive.dart';
import 'dart:convert';

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

  /// 压缩文本
  ///
  /// 将字符串编码为 UTF-8 后压缩
  static List<int> compressText(String text) {
    return compress(utf8.encode(text));
  }

  /// 解压为文本
  ///
  /// 解压缩后解码为 UTF-8 字符串
  static String decompressToText(List<int> data) {
    return utf8.decode(decompress(data));
  }

  /// 计算压缩率
  ///
  /// 返回压缩后的大小与原始大小的比率（0-1 之间）
  static double calculateCompressionRatio(List<int> original, List<int> compressed) {
    if (original.isEmpty) return 0.0;
    return 1.0 - (compressed.length / original.length);
  }
}
