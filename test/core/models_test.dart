import 'package:flutter_test/flutter_test.dart';
import 'package:spider_proxy/core/models/models.dart';

void main() {
  group('TrafficRecord', () {
    test('should create TrafficRecord from JSON', () {
      final json = {
        'id': 'test-id',
        'timestamp': '2024-01-01T12:00:00.000Z',
        'method': 'GET',
        'url': 'https://example.com/api',
        'host': 'example.com',
        'path': '/api',
        'statusCode': 200,
        'requestSize': 100,
        'responseSize': 500,
        'durationMs': 150,
        'isHttps': true,
      };

      final record = TrafficRecord.fromJson(json);

      expect(record.id, 'test-id');
      expect(record.method, 'GET');
      expect(record.statusCode, 200);
      expect(record.isHttps, true);
    });

    test('should convert TrafficRecord to JSON', () {
      final record = TrafficRecord(
        id: 'test-id',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        method: 'POST',
        url: 'https://api.example.com/data',
        host: 'api.example.com',
        path: '/data',
        statusCode: 201,
        requestSize: 256,
        responseSize: 1024,
        durationMs: 200,
        isHttps: true,
      );

      final json = record.toJson();

      expect(json['id'], 'test-id');
      expect(json['method'], 'POST');
      expect(json['statusCode'], 201);
      expect(json['requestSize'], 256);
      expect(json['responseSize'], 1024);
    });

    test('should create copy with modifications', () {
      final original = TrafficRecord(
        id: 'original-id',
        timestamp: DateTime.now(),
        method: 'GET',
        url: 'https://example.com',
        host: 'example.com',
        path: '/',
        statusCode: 200,
      );

      final modified = original.copyWith(statusCode: 404, responseSize: 0);

      expect(original.statusCode, 200);
      expect(modified.statusCode, 404);
      expect(modified.responseSize, 0);
      expect(modified.id, original.id); // Unchanged
    });
  });

  group('RequestDetail', () {
    test('should create RequestDetail from JSON', () {
      final json = {
        'id': 'req-id',
        'trafficRecordId': 'record-id',
        'timestamp': '2024-01-01T12:00:00.000Z',
        'method': 'POST',
        'uri': 'https://api.example.com/users',
        'headers': {'Content-Type': 'application/json'},
        'cookies': ['session=abc123'],
        'contentLength': 512,
      };

      final detail = RequestDetail.fromJson(json);

      expect(detail.id, 'req-id');
      expect(detail.method, 'POST');
      expect(detail.contentLength, 512);
      expect(detail.headers['Content-Type'], 'application/json');
    });

    test('should get header value case-insensitively', () {
      final detail = RequestDetail(
        id: 'req-id',
        trafficRecordId: 'record-id',
        timestamp: DateTime.now(),
        method: 'GET',
        uri: Uri.parse('https://example.com'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer token123',
        },
      );

      expect(detail.getHeader('content-type'), 'application/json');
      expect(detail.getHeader('Authorization'), 'Bearer token123');
      expect(detail.hasHeader('HOST'), false);
    });
  });

  group('ResponseDetail', () {
    test('should create ResponseDetail from JSON', () {
      final json = {
        'id': 'resp-id',
        'trafficRecordId': 'record-id',
        'timestamp': '2024-01-01T12:00:00.000Z',
        'statusCode': 200,
        'statusMessage': 'OK',
        'headers': {'Content-Type': 'application/json'},
        'contentLength': 1024,
      };

      final detail = ResponseDetail.fromJson(json);

      expect(detail.statusCode, 200);
      expect(detail.statusMessage, 'OK');
      expect(detail.contentLength, 1024);
    });

    test('should identify response type correctly', () {
      final success = ResponseDetail(
        id: 'id1',
        trafficRecordId: 'record-id',
        timestamp: DateTime.now(),
        statusCode: 200,
      );
      final redirect = ResponseDetail(
        id: 'id2',
        trafficRecordId: 'record-id',
        timestamp: DateTime.now(),
        statusCode: 301,
      );
      final clientError = ResponseDetail(
        id: 'id3',
        trafficRecordId: 'record-id',
        timestamp: DateTime.now(),
        statusCode: 404,
      );
      final serverError = ResponseDetail(
        id: 'id4',
        trafficRecordId: 'record-id',
        timestamp: DateTime.now(),
        statusCode: 500,
      );

      expect(success.isSuccess, true);
      expect(redirect.isRedirect, true);
      expect(clientError.isClientError, true);
      expect(serverError.isServerError, true);
    });
  });
}
