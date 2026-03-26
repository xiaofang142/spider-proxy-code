import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import '../../main.dart';
import '../widgets/domain_heatmap.dart';
import '../widgets/request_timeline.dart';
import '../widgets/traffic_chart.dart';
import '../../features/traffic/traffic_analyzer.dart';
import '../../core/models/traffic_record.dart';

/// 流量分析页面
///
/// 整合 A 模块所有功能：
/// - 域名/IP 热力图
/// - 请求时间线
/// - 流量趋势分析
/// - 异常检测
class AnalysisPage extends StatefulWidget {
  const AnalysisPage({super.key});

  @override
  State<AnalysisPage> createState() => _AnalysisPageState();
}

class _AnalysisPageState extends State<AnalysisPage> {
  final TrafficAnalyzer _analyzer = TrafficAnalyzer();
  TrafficAnalysisResult? _analysisResult;
  List<TrafficAnomaly> _anomalies = [];
  String _selectedDomain = '';
  TrafficRecord? _selectedRecord;

  @override
  void initState() {
    super.initState();
    _loadAnalysis();
  }

  Future<void> _loadAnalysis() async {
    final result = await _analyzer.analyze();
    setState(() {
      _analysisResult = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('流量分析'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalysis,
          ),
        ],
      ),
      body: StoreConnector<AppState, List<TrafficRecord>>(
        converter: (store) => store.state.captures,
        builder: (context, captures) {
          if (captures.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '暂无抓包数据',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '开始抓包后查看分析数据',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _loadAnalysis,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 概览卡片
                  _buildOverviewCard(captures),
                  const SizedBox(height: 16),
                  // 域名热力图
                  _buildDomainHeatmapSection(),
                  const SizedBox(height: 16),
                  // 流量趋势
                  _buildTrafficTrendSection(captures),
                  const SizedBox(height: 16),
                  // 异常检测
                  _buildAnomaliesSection(),
                  const SizedBox(height: 16),
                  // 请求时间线
                  if (_selectedRecord != null)
                    _buildTimelineSection(_selectedRecord!),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOverviewCard(List<TrafficRecord> captures) {
    if (_analysisResult == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final result = _analysisResult!;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.insights, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '流量概览',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _buildStatItem(
                  '总请求',
                  '${result.totalRequests}',
                  Icons.http,
                  Colors.blue,
                ),
                _buildStatItem(
                  '总流量',
                  _formatBytes(result.totalRequestSize + result.totalResponseSize),
                  Icons.data_usage,
                  Colors.green,
                ),
                _buildStatItem(
                  '平均耗时',
                  '${result.averageDurationMs}ms',
                  Icons.timer,
                  Colors.orange,
                ),
                _buildStatItem(
                  '域名数',
                  '${result.hostDistribution.length}',
                  Icons.dns,
                  Colors.purple,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDomainHeatmapSection() {
    if (_analysisResult == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DomainHeatmap(
          domainStats: _analysisResult!.hostDistribution,
          maxItems: 8,
          onDomainTap: (domain) {
            setState(() {
              _selectedDomain = domain;
            });
            // 可以在这里触发过滤
          },
        ),
      ],
    );
  }

  Widget _buildTrafficTrendSection(List<TrafficRecord> captures) {
    // 生成模拟的流量数据点（实际应该从存储中获取历史数据）
    final now = DateTime.now();
    final uploadData = <TrafficDataPoint>[];
    final downloadData = <TrafficDataPoint>[];

    // 按时间排序
    final sortedCaptures = List<TrafficRecord>.from(captures)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // 每分钟一个数据点
    final minuteBuckets = <int, int>{};
    final downloadBuckets = <int, int>{};

    for (final capture in sortedCaptures) {
      final minute = capture.timestamp.minute;
      minuteBuckets[minute] = (minuteBuckets[minute] ?? 0) + capture.requestSize;
      downloadBuckets[minute] =
          (downloadBuckets[minute] ?? 0) + capture.responseSize;
    }

    for (int i = 0; i < 60; i++) {
      uploadData.add(TrafficDataPoint(
        timestamp: now.subtract(Duration(minutes: 60 - i)),
        bytes: minuteBuckets[i] ?? 0,
      ));
      downloadData.add(TrafficDataPoint(
        timestamp: now.subtract(Duration(minutes: 60 - i)),
        bytes: downloadBuckets[i] ?? 0,
      ));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.trending_up, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '流量趋势',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                DropdownButton<String>(
                  value: '60',
                  items: const [
                    DropdownMenuItem(value: '10', child: Text('10 分钟')),
                    DropdownMenuItem(value: '30', child: Text('30 分钟')),
                    DropdownMenuItem(value: '60', child: Text('60 分钟')),
                  ],
                  onChanged: (value) {
                    // 时间范围切换
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            TrafficChart(
              uploadData: uploadData.where((d) => d.bytes > 0).toList(),
              downloadData: downloadData.where((d) => d.bytes > 0).toList(),
              height: 200,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnomaliesSection() {
    if (_analysisResult == null || _analysisResult!.patterns.isEmpty) {
      return const SizedBox.shrink();
    }

    final patterns = _analysisResult!.patterns;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.warning_amber, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '流量模式',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...patterns.map((pattern) => _buildPatternItem(pattern)),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternItem(TrafficPattern pattern) {
    Color borderColor;
    Color bgColor;

    switch (pattern.severity) {
      case PatternSeverity.critical:
        borderColor = Colors.red;
        bgColor = Colors.red.shade50;
        break;
      case PatternSeverity.high:
        borderColor = Colors.orange;
        bgColor = Colors.orange.shade50;
        break;
      case PatternSeverity.medium:
        borderColor = Colors.amber;
        bgColor = Colors.amber.shade50;
        break;
      case PatternSeverity.low:
        borderColor = Colors.blue;
        bgColor = Colors.blue.shade50;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(
            _getPatternIcon(pattern.type),
            color: borderColor,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              pattern.description,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Chip(
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            label: Text(
              _getSeverityText(pattern.severity),
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
            backgroundColor: borderColor,
          ),
        ],
      ),
    );
  }

  IconData _getPatternIcon(PatternType type) {
    switch (type) {
      case PatternType.highFrequency:
        return Icons.flash_on;
      case PatternType.highErrorRate:
        return Icons.error_outline;
      case PatternType.slowResponses:
        return Icons.slow_motion_video;
      case PatternType.largePayload:
        return Icons.folder_zip;
      case PatternType.suspiciousActivity:
        return Icons.security;
    }
  }

  String _getSeverityText(PatternSeverity severity) {
    switch (severity) {
      case PatternSeverity.critical:
        return '严重';
      case PatternSeverity.high:
        return '高';
      case PatternSeverity.medium:
        return '中';
      case PatternSeverity.low:
        return '低';
    }
  }

  Widget _buildTimelineSection(TrafficRecord record) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.waterfall_chart, size: 20),
                const SizedBox(width: 8),
                const Text(
                  '请求时间线',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    setState(() {
                      _selectedRecord = null;
                    });
                  },
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade300),
          RequestTimeline(
            record: record,
            timelineData: TimelineData.estimate(record),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
