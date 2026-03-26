import 'package:flutter/material.dart';
import '../../core/models/traffic_record.dart';

/// 请求时间线 Waterfall 组件
///
/// 可视化展示请求的完整生命周期
/// DNS 解析 → TCP 连接 → SSL 握手 → 发送请求 → 等待响应 → 接收数据
class RequestTimeline extends StatelessWidget {
  /// 请求记录
  final TrafficRecord record;

  /// 时间线数据
  final TimelineData? timelineData;

  const RequestTimeline({
    super.key,
    required this.record,
    this.timelineData,
  });

  @override
  Widget build(BuildContext context) {
    // 如果没有详细时间数据，使用简化模式
    if (timelineData == null) {
      return _buildSimplifiedTimeline(context);
    }

    return _buildDetailedTimeline(context);
  }

  /// 简化时间线 - 基于已有数据估算
  Widget _buildSimplifiedTimeline(BuildContext context) {
    final totalDuration = record.durationMs.toDouble();
    if (totalDuration <= 0) {
      return const Center(child: Text('暂无时间数据'));
    }

    // 估算各阶段占比（典型值）
    final phases = [
      TimelinePhase(
        name: 'DNS',
        duration: totalDuration * 0.05,
        color: Colors.blue,
        icon: Icons.dns,
      ),
      TimelinePhase(
        name: 'TCP',
        duration: totalDuration * 0.1,
        color: Colors.orange,
        icon: Icons.link,
      ),
      TimelinePhase(
        name: 'SSL',
        duration: totalDuration * 0.15,
        color: Colors.purple,
        icon: Icons.lock,
      ),
      TimelinePhase(
        name: '请求',
        duration: totalDuration * 0.1,
        color: Colors.green,
        icon: Icons.upload,
      ),
      TimelinePhase(
        name: '等待',
        duration: totalDuration * 0.3,
        color: Colors.amber,
        icon: Icons.timer,
      ),
      TimelinePhase(
        name: '接收',
        duration: totalDuration * 0.3,
        color: Colors.teal,
        icon: Icons.download,
      ),
    ];

    return _buildTimeline(context, phases);
  }

  /// 详细时间线 - 使用真实数据
  Widget _buildDetailedTimeline(BuildContext context) {
    final phases = <TimelinePhase>[];

    if (timelineData!.dnsDuration > 0) {
      phases.add(TimelinePhase(
        name: 'DNS 解析',
        duration: timelineData!.dnsDuration.toDouble(),
        color: Colors.blue,
        icon: Icons.dns,
        details: timelineData!.dnsDetails,
      ));
    }

    if (timelineData!.connectDuration > 0) {
      phases.add(TimelinePhase(
        name: 'TCP 连接',
        duration: timelineData!.connectDuration.toDouble(),
        color: Colors.orange,
        icon: Icons.link,
        details: timelineData!.connectDetails,
      ));
    }

    if (timelineData!.sslDuration > 0) {
      phases.add(TimelinePhase(
        name: 'SSL 握手',
        duration: timelineData!.sslDuration.toDouble(),
        color: Colors.purple,
        icon: Icons.lock_security,
        details: timelineData!.sslDetails,
      ));
    }

    if (timelineData!.sendDuration > 0) {
      phases.add(TimelinePhase(
        name: '发送请求',
        duration: timelineData!.sendDuration.toDouble(),
        color: Colors.green,
        icon: Icons.upload_file,
        details: timelineData!.sendDetails,
      ));
    }

    if (timelineData!.waitDuration > 0) {
      phases.add(TimelinePhase(
        name: '等待响应',
        duration: timelineData!.waitDuration.toDouble(),
        color: Colors.amber,
        icon: Icons.hourglass_empty,
        details: timelineData!.waitDetails,
      ));
    }

    if (timelineData!.receiveDuration > 0) {
      phases.add(TimelinePhase(
        name: '接收数据',
        duration: timelineData!.receiveDuration.toDouble(),
        color: Colors.teal,
        icon: Icons.download_done,
        details: timelineData!.receiveDetails,
      ));
    }

    return _buildTimeline(context, phases);
  }

  Widget _buildTimeline(BuildContext context, List<TimelinePhase> phases) {
    final totalDuration = phases.fold<double>(
      0,
      (sum, phase) => sum + phase.duration,
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Row(
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
              Text(
                '总耗时：${_formatDuration(totalDuration.toInt())}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 瀑布流
          _buildWaterfallBars(phases, totalDuration),
          const SizedBox(height: 16),
          // 图例
          _buildLegend(context, phases),
        ],
      ),
    );
  }

  Widget _buildWaterfallBars(
    List<TimelinePhase> phases,
    double totalDuration,
  ) {
    return Column(
      children: phases.map((phase) {
        final percentage = phase.duration / totalDuration * 100;
        final isSignificant = percentage > 20; // 超过 20% 认为是显著的

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 阶段名称和时间
              Row(
                children: [
                  Icon(
                    phase.icon,
                    size: 16,
                    color: phase.color,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    phase.name,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const Spacer(),
                  Text(
                    _formatDuration(phase.duration.toInt()),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isSignificant
                          ? Colors.red.shade700
                          : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // 进度条
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  height: 24,
                  width: double.infinity,
                  color: phase.color.withOpacity(0.1),
                  child: Stack(
                    children: [
                      FractionallySizedBox(
                        widthFactor: phase.duration / totalDuration,
                        alignment: Alignment.centerLeft,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                phase.color,
                                phase.color.withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: percentage > 15
                              ? Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Text(
                                    '${percentage.toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),
                      // 慢警告标记
                      if (isSignificant && phase.duration > 500)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            color: Colors.red.shade200,
                            child: const Icon(
                              Icons.warning_amber,
                              size: 14,
                              color: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // 详细信息
              if (phase.details != null && phase.details!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 22),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: phase.details!.entries.map((e) {
                      return Chip(
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          '${e.key}: ${e.value}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLegend(BuildContext context, List<TimelinePhase> phases) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: phases.map((phase) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: phase.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              phase.name,
              style: const TextStyle(fontSize: 11),
            ),
          ],
        );
      }).toList(),
    );
  }

  String _formatDuration(int ms) {
    if (ms < 1000) {
      return '${ms}ms';
    } else if (ms < 60000) {
      return '${(ms / 1000).toStringAsFixed(1)}s';
    } else {
      final minutes = ms ~/ 60000;
      final seconds = (ms % 60000) / 1000;
      return '${minutes}m${seconds.toStringAsFixed(0)}s';
    }
  }
}

/// 时间线阶段数据
class TimelinePhase {
  final String name;
  final double duration;
  final Color color;
  final IconData icon;
  final Map<String, String>? details;

  TimelinePhase({
    required this.name,
    required this.duration,
    required this.color,
    required this.icon,
    this.details,
  });
}

/// 详细时间线数据
class TimelineData {
  // DNS 解析
  final int dnsDuration;
  final Map<String, String> dnsDetails;

  // TCP 连接
  final int connectDuration;
  final Map<String, String> connectDetails;

  // SSL 握手
  final int sslDuration;
  final Map<String, String> sslDetails;

  // 发送请求
  final int sendDuration;
  final Map<String, String> sendDetails;

  // 等待响应 (TTFB)
  final int waitDuration;
  final Map<String, String> waitDetails;

  // 接收数据
  final int receiveDuration;
  final Map<String, String> receiveDetails;

  TimelineData({
    this.dnsDuration = 0,
    this.dnsDetails = const {},
    this.connectDuration = 0,
    this.connectDetails = const {},
    this.sslDuration = 0,
    this.sslDetails = const {},
    this.sendDuration = 0,
    this.sendDetails = const {},
    this.waitDuration = 0,
    this.waitDetails = const {},
    this.receiveDuration = 0,
    this.receiveDetails = const {},
  });

  int get totalDuration =>
      dnsDuration +
      connectDuration +
      sslDuration +
      sendDuration +
      waitDuration +
      receiveDuration;

  /// 从 TrafficRecord 创建估算的 TimelineData
  factory TimelineData.estimate(TrafficRecord record) {
    final total = record.durationMs.toDouble();
    if (total <= 0) {
      return TimelineData();
    }

    return TimelineData(
      dnsDuration: (total * 0.05).toInt(),
      connectDuration: (total * 0.1).toInt(),
      sslDuration: (total * 0.15).toInt(),
      sendDuration: (total * 0.1).toInt(),
      waitDuration: (total * 0.3).toInt(),
      receiveDuration: (total * 0.3).toInt(),
    );
  }
}
