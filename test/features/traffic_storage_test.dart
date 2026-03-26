import 'package:flutter_test/flutter_test.dart';
import 'package:spider_proxy/core/models/models.dart';
import 'package:spider_proxy/features/traffic/traffic_storage.dart';

void main() {
  group('TrafficStats', () {
    test('should create stats and convert to JSON', () {
      final stats = TrafficStats(
        totalRecords: 100,
        todayRecords: 25,
        statusCodes: {'2xx': 80, '4xx': 15, '5xx': 5},
        methods: {'GET': 70, 'POST': 25, 'PUT': 5},
      );

      final json = stats.toJson();

      expect(json['totalRecords'], 100);
      expect(json['todayRecords'], 25);
      expect(json['statusCodes']['2xx'], 80);
      expect(json['methods']['GET'], 70);
    });
  });

  group('RouteConfig', () {
    test('should create default config', () {
      const config = RouteConfig();

      expect(config.defaultMode, RouteMode.blacklist);
      expect(config.dnsServers, ['8.8.8.8', '8.8.4.4']);
    });

    test('should check if host should be proxied', () {
      const config = RouteConfig(
        defaultMode: RouteMode.blacklist,
        bypassDomains: ['google.com', 'apple.com'],
      );

      expect(config.shouldProxy('example.com'), true);
      expect(config.shouldProxy('google.com'), false);
    });

    test('should support wildcard domain matching', () {
      const config = RouteConfig(
        bypassDomains: ['*.google.com'],
      );

      expect(config.shouldProxy('www.google.com'), false);
      expect(config.shouldProxy('api.google.com'), false);
      expect(config.shouldProxy('google.com'), true); // Exact match not required
    });

    test('should add rules dynamically', () {
      const config = RouteConfig();
      
      final newConfig = config.withRule(
        const RouteRule(
          pattern: '.*\\.api\\..*',
          mode: RouteMode.whitelist,
          isRegex: true,
        ),
      );

      expect(newConfig.rules.length, 1);
      expect(newConfig.rules.first.isRegex, true);
    });

    test('should serialize to JSON', () {
      const config = RouteConfig(
        defaultMode: RouteMode.whitelist,
        proxyDomains: ['example.com', 'api.example.com'],
        dnsServers: ['1.1.1.1', '8.8.8.8'],
      );

      final json = config.toJson();

      expect(json['defaultMode'], 'whitelist');
      expect(json['proxyDomains'].length, 2);
      expect(json['dnsServers'].length, 2);
    });

    test('should deserialize from JSON', () {
      final json = {
        'defaultMode': 'blacklist',
        'bypassDomains': ['google.com', 'facebook.com'],
        'proxyDomains': ['example.com'],
        'dnsServers': ['8.8.8.8'],
      };

      final config = RouteConfig.fromJson(json);

      expect(config.defaultMode, RouteMode.blacklist);
      expect(config.bypassDomains.length, 2);
      expect(config.proxyDomains.length, 1);
    });
  });

  group('TunnelConfig', () {
    test('should create default tunnel config', () {
      const config = TunnelConfig();

      expect(config.name, 'spider-tun');
      expect(config.address, '10.0.0.1');
      expect(config.netmask, '255.255.255.0');
      expect(config.mtu, 1500);
    });
  });

  group('TrafficRecord JSON Serialization', () {
    test('should serialize and deserialize correctly', () {
      final original = TrafficRecord(
        id: 'test-id',
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        method: 'POST',
        url: 'https://api.example.com/data',
        host: 'api.example.com',
        path: '/data',
        statusCode: 201,
        requestSize: 256,
        responseSize: 1024,
        durationMs: 150,
        isHttps: true,
      );

      final jsonString = original.toJsonString();
      final restored = TrafficRecord.fromJsonString(jsonString);

      expect(restored.id, original.id);
      expect(restored.method, original.method);
      expect(restored.statusCode, original.statusCode);
      expect(restored.isHttps, original.isHttps);
    });
  });
}
