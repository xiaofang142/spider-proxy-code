import 'package:flutter_test/flutter_test.dart';
import 'package:spider_proxy/core/proxy/websocket_proxy.dart';

void main() {
  group('WebSocketFrame', () {
    test('parse text frame', () {
      final frame = WebSocketFrame(
        fin: true,
        rsv1: 0,
        rsv2: 0,
        rsv3: 0,
        opcode: 0x1,
        masked: false,
        payloadLength: 100,
      );

      expect(frame.fin, true);
      expect(frame.rsv1, 0);
      expect(frame.opcode, 0x1);
      expect(frame.opcodeText, 'Text');
      expect(frame.masked, false);
      expect(frame.payloadLength, 100);
      expect(frame.isCompressed, false);
    });

    test('parse compressed frame', () {
      final frame = WebSocketFrame(
        fin: true,
        rsv1: 1,
        rsv2: 0,
        rsv3: 0,
        opcode: 0x2,
        masked: true,
        payloadLength: 200,
      );

      expect(frame.isCompressed, true);
      expect(frame.opcodeText, 'Binary');
      expect(frame.masked, true);
    });

    test('parse close frame', () {
      final frame = WebSocketFrame(
        fin: true,
        opcode: 0x8,
        masked: false,
        payloadLength: 2,
      );

      expect(frame.opcodeText, 'Close');
    });

    test('parse ping frame', () {
      final frame = WebSocketFrame(
        fin: true,
        opcode: 0x9,
        masked: false,
        payloadLength: 0,
      );

      expect(frame.opcodeText, 'Ping');
    });

    test('parse pong frame', () {
      final frame = WebSocketFrame(
        fin: true,
        opcode: 0xA,
        masked: false,
        payloadLength: 0,
      );

      expect(frame.opcodeText, 'Pong');
    });

    test('parse continuation frame', () {
      final frame = WebSocketFrame(
        fin: false,
        opcode: 0x0,
        masked: false,
        payloadLength: 50,
      );

      expect(frame.opcodeText, 'Continuation');
      expect(frame.fin, false);
    });

    test('unknown opcode', () {
      final frame = WebSocketFrame(
        fin: true,
        opcode: 0xF,
        masked: false,
        payloadLength: 0,
      );

      expect(frame.opcodeText, 'Unknown (0xf)');
    });

    test('extended payload length (16-bit)', () {
      final frame = WebSocketFrame(
        fin: true,
        opcode: 0x1,
        masked: false,
        payloadLength: 126,
        extendedPayloadLength: 500,
      );

      expect(frame.actualPayloadLength, 500);
    });

    test('extended payload length (64-bit)', () {
      final frame = WebSocketFrame(
        fin: true,
        opcode: 0x1,
        masked: false,
        payloadLength: 127,
        extendedPayloadLength: 100000,
      );

      expect(frame.actualPayloadLength, 100000);
    });

    test('to json', () {
      final frame = WebSocketFrame(
        fin: true,
        rsv1: 1,
        rsv2: 0,
        rsv3: 0,
        opcode: 0x1,
        masked: false,
        payloadLength: 100,
      );

      final json = frame.toJson();
      expect(json['fin'], true);
      expect(json['rsv1'], 1);
      expect(json['opcode'], 0x1);
      expect(json['opcodeText'], 'Text');
      expect(json['isCompressed'], true);
    });
  });

  group('WebSocketMessage with frame', () {
    test('create message with frame', () {
      final frame = WebSocketFrame(
        fin: true,
        opcode: 0x1,
        masked: false,
        payloadLength: 10,
      );

      final message = WebSocketMessage(
        id: 'test-1',
        connectionId: 'conn-1',
        timestamp: DateTime.now(),
        direction: MessageDirection.clientToServer,
        type: MessageType.text,
        payload: 'Hello',
        frame: frame,
      );

      expect(message.frame, isNotNull);
      expect(message.frame!.opcodeText, 'Text');
    });

    test('message without frame', () {
      final message = WebSocketMessage(
        id: 'test-2',
        connectionId: 'conn-1',
        timestamp: DateTime.now(),
        direction: MessageDirection.serverToClient,
        type: MessageType.text,
        payload: 'World',
      );

      expect(message.frame, isNull);
    });

    test('message with frame to json', () {
      final frame = WebSocketFrame(
        fin: true,
        opcode: 0x1,
        masked: false,
        payloadLength: 5,
      );

      final message = WebSocketMessage(
        id: 'test-3',
        connectionId: 'conn-1',
        timestamp: DateTime.now(),
        direction: MessageDirection.clientToServer,
        type: MessageType.text,
        payload: 'Hello',
        frame: frame,
      );

      final json = message.toJson();
      expect(json['frame'], isNotNull);
      expect(json['frame']['opcode'], 0x1);
    });
  });

  group('WebSocketHandshake extensions', () {
    test('detect permessage-deflate extension', () {
      final handshake = WebSocketHandshake(
        id: 'hs-1',
        connectionId: 'conn-1',
        timestamp: DateTime.now(),
        url: 'ws://example.com/socket',
        secWebSocketExtensions: 'permessage-deflate; client_max_window_bits',
        secWebSocketExtensionsResponse: 'permessage-deflate',
      );

      expect(handshake.shouldEnableCompression(), true);
    });

    test('no extension in response', () {
      final handshake = WebSocketHandshake(
        id: 'hs-2',
        connectionId: 'conn-2',
        timestamp: DateTime.now(),
        url: 'ws://example.com/socket',
        secWebSocketExtensions: 'permessage-deflate',
        secWebSocketExtensionsResponse: null,
      );

      expect(handshake.shouldEnableCompression(), false);
    });

    test('different extension negotiated', () {
      final handshake = WebSocketHandshake(
        id: 'hs-3',
        connectionId: 'conn-3',
        timestamp: DateTime.now(),
        url: 'ws://example.com/socket',
        secWebSocketExtensionsResponse: 'some-other-extension',
      );

      expect(handshake.shouldEnableCompression(), false);
    });

    test('handshake to json with extensions', () {
      final handshake = WebSocketHandshake(
        id: 'hs-4',
        connectionId: 'conn-4',
        timestamp: DateTime.now(),
        url: 'ws://example.com/socket',
        secWebSocketExtensions: 'permessage-deflate',
        secWebSocketExtensionsResponse: 'permessage-deflate',
      );

      final json = handshake.toJson();
      expect(json['secWebSocketExtensions'], 'permessage-deflate');
      expect(json['secWebSocketExtensionsResponse'], 'permessage-deflate');
    });
  });

  group('WebSocketConnection compression', () {
    test('connection with compression enabled', () {
      final connection = WebSocketConnection(
        id: 'conn-with-compression',
        url: 'ws://example.com/socket',
        isCompressed: true,
      );

      expect(connection.isCompressed, true);
    });

    test('connection without compression', () {
      final connection = WebSocketConnection(
        id: 'conn-no-compression',
        url: 'ws://example.com/socket',
        isCompressed: false,
      );

      expect(connection.isCompressed, false);
    });

    test('connection to json with compression info', () {
      final connection = WebSocketConnection(
        id: 'conn-json',
        url: 'ws://example.com/socket',
        isCompressed: true,
        extensions: 'permessage-deflate',
      );

      final json = connection.toJson();
      expect(json['isCompressed'], isNotNull);
      expect(json['extensions'], 'permessage-deflate');
    });
  });
}
