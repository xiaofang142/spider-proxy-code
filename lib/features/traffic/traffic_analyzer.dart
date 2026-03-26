import '../../core/models/traffic_record.dart';
import 'traffic_storage.dart';

/// 流量分析器
class TrafficAnalyzer {
  final TrafficStorage _storage;
  final Map<String, TrafficPattern> _patterns = {};

  TrafficAnalyzer({TrafficStorage? storage})
      : _storage = storage ?? TrafficStorage();

  /// 分析流量记录
  Future<TrafficAnalysisResult> analyze({
    DateTime? startTime,
    DateTime? endTime,
    String? host,
  }) async {
    final records = await _storage.getTrafficRecords(
      startTime: startTime,
      endTime: endTime,
      host: host,
    );

    return _analyzeRecords(records);
  }

  /// 分析记录列表
  TrafficAnalysisResult _analyzeRecords(List<TrafficRecord> records) {
    if (records.isEmpty) {
      return TrafficAnalysisResult.empty();
    }

    // 基础统计
    final totalRequests = records.length;
    final totalRequestSize = records.fold<int>(0, (sum, r) => sum + r.requestSize);
    final totalResponseSize = records.fold<int>(0, (sum, r) => sum + r.responseSize);
    final avgDuration = records.fold<int>(0, (sum, r) => sum + r.durationMs) ~/ totalRequests;

    // 状态码分布
    final statusDistribution = <String, int>{};
    for (final record in records) {
      final group = _getStatusCodeGroup(record.statusCode);
      statusDistribution[group] = (statusDistribution[group] ?? 0) + 1;
    }

    // 方法分布
    final methodDistribution = <String, int>{};
    for (final record in records) {
      methodDistribution[record.method] = (methodDistribution[record.method] ?? 0) + 1;
    }

    // 主机分布
    final hostDistribution = <String, int>{};
    for (final record in records) {
      hostDistribution[record.host] = (hostDistribution[record.host] ?? 0) + 1;
    }

    // 识别流量模式
    final patterns = _identifyPatterns(records);

    // 性能指标
    final performanceMetrics = _calculatePerformanceMetrics(records);

    return TrafficAnalysisResult(
      totalRequests: totalRequests,
      totalRequestSize: totalRequestSize,
      totalResponseSize: totalResponseSize,
      averageDurationMs: avgDuration,
      statusDistribution: statusDistribution,
      methodDistribution: methodDistribution,
      hostDistribution: Map<String, int>.fromEntries(
        hostDistribution.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)),
      ),
      patterns: patterns,
      performanceMetrics: performanceMetrics,
      timeRange: TimeRange(
        start: records.map((r) => r.timestamp).reduce((a, b) => a.isBefore(b) ? a : b),
        end: records.map((r) => r.timestamp).reduce((a, b) => a.isAfter(b) ? a : b),
      ),
    );
  }

  /// 获取状态码分组
  String _getStatusCodeGroup(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) return '2xx';
    if (statusCode >= 300 && statusCode < 400) return '3xx';
    if (statusCode >= 400 && statusCode < 500) return '4xx';
    if (statusCode >= 500) return '5xx';
    return 'other';
  }

  /// 识别流量模式
  List<TrafficPattern> _identifyPatterns(List<TrafficRecord> records) {
    final patterns = <TrafficPattern>[];

    // 检测高频请求
    final hostCounts = <String, int>{};
    for (final record in records) {
      hostCounts[record.host] = (hostCounts[record.host] ?? 0) + 1;
    }

    for (final entry in hostCounts.entries) {
      if (entry.value > records.length * 0.3) {
        patterns.add(TrafficPattern(
          type: PatternType.highFrequency,
          description: '高频访问：${entry.key} (${entry.value} 次)',
          severity: PatternSeverity.medium,
        ));
      }
    }

    // 检测错误率
    final errorCount = records.where((r) => r.statusCode >= 400).length;
    final errorRate = errorCount / records.length;
    if (errorRate > 0.1) {
      patterns.add(TrafficPattern(
        type: PatternType.highErrorRate,
        description: '高错误率：${(errorRate * 100).toStringAsFixed(1)}%',
        severity: errorRate > 0.3 ? PatternSeverity.high : PatternSeverity.medium,
      ));
    }

    // 检测慢请求
    final slowRequests = records.where((r) => r.durationMs > 2000).length;
    if (slowRequests > records.length * 0.1) {
      patterns.add(TrafficPattern(
        type: PatternType.slowResponses,
        description: '慢响应：$slowRequests 个请求超过 2 秒',
        severity: PatternSeverity.medium,
      ));
    }

    return patterns;
  }

  /// 计算性能指标
  PerformanceMetrics _calculatePerformanceMetrics(List<TrafficRecord> records) {
    final durations = records.map((r) => r.durationMs).toList()..sort();
    
    return PerformanceMetrics(
      minDurationMs: durations.first,
      maxDurationMs: durations.last,
      avgDurationMs: durations.reduce((a, b) => a + b) ~/ durations.length,
      p50DurationMs: durations[durations.length ~/ 2],
      p90DurationMs: durations[(durations.length * 0.9).toInt()],
      p99DurationMs: durations[(durations.length * 0.99).toInt()],
      requestsPerSecond: records.length / 
          (records.last.timestamp.difference(records.first.timestamp).inSeconds + 1),
    );
  }

  /// 获取 Top 主机
  Future<List<MapEntry<String, int>>> getTopHosts({int limit = 10}) async {
    final stats = await _storage.getStats();
    // 这里简化实现，实际应该从存储中查询
    return [];
  }

  /// 检测异常流量
  Future<List<TrafficAnomaly>> detectAnomalies({
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final records = await _storage.getTrafficRecords(
      startTime: startTime,
      endTime: endTime,
    );

    final anomalies = <TrafficAnomaly>[];

    if (records.isEmpty) return anomalies;

    // 1. 检测流量突增 (> 200% 基线)
    anomalies.addAll(_detectTrafficSpikes(records));

    // 2. 检测错误率异常 (> 10%)
    anomalies.addAll(_detectErrorSpikes(records));

    // 3. 检测响应时间异常 (> 3σ)
    anomalies.addAll(_detectSlowDowns(records));

    // 4. 检测可疑活动
    anomalies.addAll(_detectSuspiciousActivity(records));

    return anomalies;
  }

  /// 检测流量突增
  List<TrafficAnomaly> _detectTrafficSpikes(List<TrafficRecord> records) {
    final anomalies = <TrafficAnomaly>[];

    // 按小时分组统计请求数
    final hourlyCounts = <String, int>{};
    for (final record in records) {
      final hourKey = '${record.timestamp.year}-${record.timestamp.month}-${record.timestamp.day}-${record.timestamp.hour}';
      hourlyCounts[hourKey] = (hourlyCounts[hourKey] ?? 0) + 1;
    }

    if (hourlyCounts.length < 2) return anomalies;

    final counts = hourlyCounts.values.toList();
    final avgCount = counts.reduce((a, b) => a + b) / counts.length;
    final baseline = avgCount;

    for (final entry in hourlyCounts.entries) {
      if (entry.value > baseline * 3) {
        anomalies.add(TrafficAnomaly(
          type: AnomalyType.trafficSpike,
          description: '流量突增：${entry.key} 时段请求数 (${entry.value}) 超过基线 (${baseline.toStringAsFixed(0)}) 的 3 倍',
          detectedAt: DateTime.now(),
          context: {
            'hour': entry.key,
            'count': entry.value,
            'baseline': baseline,
            'ratio': entry.value / baseline,
          },
        ));
      }
    }

    return anomalies;
  }

  /// 检测错误率异常
  List<TrafficAnomaly> _detectErrorSpikes(List<TrafficRecord> records) {
    final anomalies = <TrafficAnomaly>[];

    final errorCount = records.where((r) => r.statusCode >= 400).length;
    final errorRate = errorCount / records.length;

    if (errorRate > 0.1) {
      anomalies.add(TrafficAnomaly(
        type: AnomalyType.errorSpike,
        description: '错误率异常：${(errorRate * 100).toStringAsFixed(1)}% 的请求返回错误 (${errorCount}/${records.length})',
        detectedAt: DateTime.now(),
        context: {
          'errorCount': errorCount,
          'totalCount': records.length,
          'errorRate': errorRate,
        },
      ));
    }

    return anomalies;
  }

  /// 检测响应时间异常
  List<TrafficAnomaly> _detectSlowDowns(List<TrafficRecord> records) {
    final anomalies = <TrafficAnomaly>[];

    final durations = records.map((r) => r.durationMs).toList();
    if (durations.length < 10) return anomalies;

    final avgDuration = durations.reduce((a, b) => a + b) / durations.length;
    final variance = durations.fold<double>(
      0,
      (sum, d) => sum + (d - avgDuration) * (d - avgDuration),
    );
    final stdDev = (variance / durations.length).sqrt();

    // 检测超过 3 个标准差的请求
    final threshold = avgDuration + 3 * stdDev;
    final slowRequests = records.where((r) => r.durationMs > threshold).toList();

    if (slowRequests.isNotEmpty && stdDev > 0) {
      anomalies.add(TrafficAnomaly(
        type: AnomalyType.slowDown,
        description: '响应时间异常：${slowRequests.length} 个请求超过阈值 (${threshold.toStringAsFixed(0)}ms)',
        detectedAt: DateTime.now(),
        context: {
          'avgDuration': avgDuration.toStringAsFixed(0),
          'stdDev': stdDev.toStringAsFixed(0),
          'threshold': threshold.toStringAsFixed(0),
          'slowCount': slowRequests.length,
        },
      ));
    }

    return anomalies;
  }

  /// 检测可疑活动
  List<TrafficAnomaly> _detectSuspiciousActivity(List<TrafficRecord> records) {
    final anomalies = <TrafficAnomaly>[];

    // 检测同一域名的高频请求（可能为爬虫或攻击）
    final hostCounts = <String, int>{};
    for (final record in records) {
      hostCounts[record.host] = (hostCounts[record.host] ?? 0) + 1;
    }

    for (final entry in hostCounts.entries) {
      // 单个域名超过总请求数的 50%
      if (entry.value > records.length * 0.5 && entry.value > 100) {
        anomalies.add(TrafficAnomaly(
          type: AnomalyType.securityThreat,
          description: '可疑活动：${entry.key} 请求过于集中 (${entry.value}/${records.length})',
          detectedAt: DateTime.now(),
          context: {
            'host': entry.key,
            'count': entry.value,
            'totalCount': records.length,
            'ratio': entry.value / records.length,
          },
        ));
      }
    }

    return anomalies;
  }

  /// 获取 IP 段分布
  Map<String, int> getIpDistribution(List<TrafficRecord> records) {
    final ipSegments = <String, int>{};

    for (final record in records) {
      // 从域名解析 IP 段（简化实现，实际应该从网络层获取）
      final ipSegment = _extractIpSegment(record.host);
      ipSegments[ipSegment] = (ipSegments[ipSegment] ?? 0) + 1;
    }

    return Map<String, int>.fromEntries(
      ipSegments.entries.toList()..sort((a, b) => b.value.compareTo(a.value)),
    );
  }

  /// 从域名提取 IP 段（简化实现）
  String _extractIpSegment(String host) {
    // 提取主域名作为 IP 段的代理
    // 例如：api.github.com -> github.com
    final parts = host.split('.');
    if (parts.length >= 2) {
      return parts.sublist(parts.length - 2).join('.');
    }
    return host;
  }
}

// 为 double 添加 sqrt 扩展
extension on num {
  double sqrt() {
    if (this <= 0) return 0;
    double guess = this / 2;
    for (int i = 0; i < 10; i++) {
      guess = (guess + this / guess) / 2;
    }
    return guess;
  }
}

/// 流量分析结果
class TrafficAnalysisResult {
  final int totalRequests;
  final int totalRequestSize;
  final int totalResponseSize;
  final int averageDurationMs;
  final Map<String, int> statusDistribution;
  final Map<String, int> methodDistribution;
  final Map<String, int> hostDistribution;
  final List<TrafficPattern> patterns;
  final PerformanceMetrics performanceMetrics;
  final TimeRange timeRange;

  TrafficAnalysisResult({
    required this.totalRequests,
    required this.totalRequestSize,
    required this.totalResponseSize,
    required this.averageDurationMs,
    required this.statusDistribution,
    required this.methodDistribution,
    required this.hostDistribution,
    required this.patterns,
    required this.performanceMetrics,
    required this.timeRange,
  });

  factory TrafficAnalysisResult.empty() {
    return TrafficAnalysisResult(
      totalRequests: 0,
      totalRequestSize: 0,
      totalResponseSize: 0,
      averageDurationMs: 0,
      statusDistribution: {},
      methodDistribution: {},
      hostDistribution: {},
      patterns: [],
      performanceMetrics: PerformanceMetrics.empty(),
      timeRange: TimeRange(start: DateTime.now(), end: DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalRequests': totalRequests,
      'totalRequestSize': totalRequestSize,
      'totalResponseSize': totalResponseSize,
      'averageDurationMs': averageDurationMs,
      'statusDistribution': statusDistribution,
      'methodDistribution': methodDistribution,
      'hostDistribution': hostDistribution,
      'patterns': patterns.map((p) => p.toJson()).toList(),
      'performanceMetrics': performanceMetrics.toJson(),
      'timeRange': timeRange.toJson(),
    };
  }
}

/// 流量模式
class TrafficPattern {
  final PatternType type;
  final String description;
  final PatternSeverity severity;

  TrafficPattern({
    required this.type,
    required this.description,
    required this.severity,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'description': description,
      'severity': severity.name,
    };
  }
}

enum PatternType {
  highFrequency,
  highErrorRate,
  slowResponses,
  largePayload,
  suspiciousActivity,
}

enum PatternSeverity {
  low,
  medium,
  high,
  critical,
}

/// 性能指标
class PerformanceMetrics {
  final int minDurationMs;
  final int maxDurationMs;
  final int avgDurationMs;
  final int p50DurationMs;
  final int p90DurationMs;
  final int p99DurationMs;
  final double requestsPerSecond;

  PerformanceMetrics({
    required this.minDurationMs,
    required this.maxDurationMs,
    required this.avgDurationMs,
    required this.p50DurationMs,
    required this.p90DurationMs,
    required this.p99DurationMs,
    required this.requestsPerSecond,
  });

  factory PerformanceMetrics.empty() {
    return PerformanceMetrics(
      minDurationMs: 0,
      maxDurationMs: 0,
      avgDurationMs: 0,
      p50DurationMs: 0,
      p90DurationMs: 0,
      p99DurationMs: 0,
      requestsPerSecond: 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'minDurationMs': minDurationMs,
      'maxDurationMs': maxDurationMs,
      'avgDurationMs': avgDurationMs,
      'p50DurationMs': p50DurationMs,
      'p90DurationMs': p90DurationMs,
      'p99DurationMs': p99DurationMs,
      'requestsPerSecond': requestsPerSecond,
    };
  }
}

/// 时间范围
class TimeRange {
  final DateTime start;
  final DateTime end;

  TimeRange({
    required this.start,
    required this.end,
  });

  Duration get duration => end.difference(start);

  Map<String, dynamic> toJson() {
    return {
      'start': start.toIso8601String(),
      'end': end.toIso8601String(),
      'durationSeconds': duration.inSeconds,
    };
  }
}

/// 流量异常
class TrafficAnomaly {
  final AnomalyType type;
  final String description;
  final DateTime detectedAt;
  final Map<String, dynamic> context;

  TrafficAnomaly({
    required this.type,
    required this.description,
    required this.detectedAt,
    required this.context,
  });
}

enum AnomalyType {
  trafficSpike,
  errorSpike,
  slowDown,
  unusualPattern,
  securityThreat,
}
