import 'package:flutter_test/flutter_test.dart';
import 'package:spider_proxy/core/proxy/websocket_compression.dart';
import 'dart:convert';

void main() {
  group('WebSocketCompression', () {
    test('compress and decompress binary data', () {
      final original = utf8.encode('Hello, WebSocket!');
      final compressed = WebSocketCompression.compress(original);
      final decompressed = WebSocketCompression.decompress(compressed);
      expect(decompressed, original);
    });

    test('compress and decompress text', () {
      final originalText = 'Hello, WebSocket!';
      final compressed = WebSocketCompression.compressText(originalText);
      final decompressedText = WebSocketCompression.decompressToText(compressed);
      expect(decompressedText, originalText);
    });

    test('compressed data is smaller than original', () {
      // 创建足够大的数据以体现压缩效果
      final original = utf8.encode('A' * 1000);
      final compressed = WebSocketCompression.compress(original);
      expect(compressed.length, lessThan(original.length));
    });

    test('compress empty data', () {
      final original = <int>[];
      final compressed = WebSocketCompression.compress(original);
      final decompressed = WebSocketCompression.decompress(compressed);
      expect(decompressed, original);
    });

    test('compress and decompress chinese text', () {
      final originalText = '你好，WebSocket！这是一个压缩测试。';
      final compressed = WebSocketCompression.compressText(originalText);
      final decompressedText = WebSocketCompression.decompressToText(compressed);
      expect(decompressedText, originalText);
    });
  });
}
