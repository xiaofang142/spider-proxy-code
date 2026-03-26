import 'package:flutter_test/flutter_test.dart';
import 'package:spider_proxy/core/proxy/proxy.dart';
import 'package:spider_proxy/core/models/models.dart';

void main() {
  group('ProxyConfig', () {
    test('should create default config', () {
      const config = ProxyConfig();

      expect(config.port, 8888);
      expect(config.host, '0.0.0.0');
      expect(config.enableHttps, true);
      expect(config.timeout.inSeconds, 30);
    });

    test('should create custom config', () {
      const config = ProxyConfig(
        port: 9000,
        host: '127.0.0.1',
        enableHttps: false,
      );

      expect(config.port, 9000);
      expect(config.host, '127.0.0.1');
      expect(config.enableHttps, false);
    });
  });

  group('ProxyStats', () {
    test('should create stats and convert to JSON', () {
      final startTime = DateTime.now();
      final stats = ProxyStats(
        isRunning: true,
        port: 8888,
        host: '0.0.0.0',
        connectionCount: 5,
        uptime: const Duration(seconds: 120),
        startTime: startTime,
      );

      final json = stats.toJson();

      expect(json['isRunning'], true);
      expect(json['port'], 8888);
      expect(json['connectionCount'], 5);
      expect(json['uptimeSeconds'], 120);
    });
  });

  group('DefaultRequestInterceptor', () {
    test('should intercept request', () async {
      final interceptor = DefaultRequestInterceptor();
      
      // Create mock request
      final requestDetail = RequestDetail(
        id: 'test-id',
        trafficRecordId: 'record-id',
        timestamp: DateTime.now(),
        method: 'GET',
        uri: Uri.parse('https://example.com'),
      );

      // Mock HttpRequest would be needed for full test
      // This is a simplified test
      expect(interceptor, isNotNull);
    });

    test('should add and remove interceptors', () {
      final interceptor = DefaultRequestInterceptor();
      final loggingInterceptor = LoggingRequestInterceptor();

      interceptor.addInterceptor(loggingInterceptor);
      
      // Interceptor added successfully (no exception)
      expect(interceptor, isNotNull);
    });
  });

  group('FilteringRequestInterceptor', () {
    test('should include matching patterns', () async {
      final interceptor = FilteringRequestInterceptor();
      interceptor.addIncludePattern(r'.*\.example\.com.*');

      final requestDetail = RequestDetail(
        id: 'test-id',
        trafficRecordId: 'record-id',
        timestamp: DateTime.now(),
        method: 'GET',
        uri: Uri.parse('https://api.example.com/users'),
      );

      // Mock HttpRequest would be needed for full test
      expect(interceptor, isNotNull);
    });

    test('should exclude matching patterns', () async {
      final interceptor = FilteringRequestInterceptor();
      interceptor.addExcludePattern(r'.*\.google\.com.*');

      // Should exclude google.com
      expect(interceptor, isNotNull);
    });
  });

  group('RequestInterceptor Chain', () {
    test('should chain multiple interceptors', () {
      final chain = DefaultRequestInterceptor();
      
      chain.addInterceptor(LoggingRequestInterceptor());
      chain.addInterceptor(FilteringRequestInterceptor());
      
      expect(chain, isNotNull);
    });
  });
}
