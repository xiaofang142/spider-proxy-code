import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// 流量趋势图表组件
///
/// 显示实时上传/下载速率，支持时间范围选择
class TrafficChart extends StatefulWidget {
  /// 上传流量数据（字节）
  final List<TrafficDataPoint> uploadData;

  /// 下载流量数据（字节）
  final List<TrafficDataPoint> downloadData;

  /// 时间范围（分钟）
  final int timeRangeMinutes;

  /// 是否显示网格线
  final bool showGrid;

  /// 是否显示图例
  final bool showLegend;

  /// 是否显示峰值标注
  final bool showPeak;

  /// 图表高度
  final double height;

  const TrafficChart({
    super.key,
    required this.uploadData,
    required this.downloadData,
    this.timeRangeMinutes = 60,
    this.showGrid = true,
    this.showLegend = true,
    this.showPeak = true,
    this.height = 200,
  });

  @override
  State<TrafficChart> createState() => _TrafficChartState();
}

class _TrafficChartState extends State<TrafficChart> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height + (widget.showLegend ? 40 : 0),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // 图表
          Expanded(
            child: CustomPaint(
              painter: TrafficChartPainter(
                uploadData: widget.uploadData,
                downloadData: widget.downloadData,
                showGrid: widget.showGrid,
                showPeak: widget.showPeak,
                uploadColor: Colors.green,
                downloadColor: Colors.blue,
              ),
              size: Size.infinite,
            ),
          ),
          // 图例
          if (widget.showLegend) _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildLegendItem(Colors.green, '上传'),
          const SizedBox(width: 24),
          _buildLegendItem(Colors.blue, '下载'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

/// 流量数据点
class TrafficDataPoint {
  final DateTime timestamp;
  final int bytes;

  const TrafficDataPoint({
    required this.timestamp,
    required this.bytes,
  });

  /// 格式化为人类可读的流量单位
  String get formattedBytes {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// 计算速率（字节/秒）
  int get bytesPerSecond => bytes;
}

/// 流量图表绘制器
class TrafficChartPainter extends CustomPainter {
  final List<TrafficDataPoint> uploadData;
  final List<TrafficDataPoint> downloadData;
  final bool showGrid;
  final bool showPeak;
  final Color uploadColor;
  final Color downloadColor;

  TrafficChartPainter({
    required this.uploadData,
    required this.downloadData,
    this.showGrid = true,
    this.showPeak = true,
    this.uploadColor = Colors.green,
    this.downloadColor = Colors.blue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (uploadData.isEmpty && downloadData.isEmpty) {
      _drawEmptyState(canvas, size);
      return;
    }

    // 计算最大值用于 Y 轴缩放
    final allBytes = [
      ...uploadData.map((d) => d.bytes),
      ...downloadData.map((d) => d.bytes)
    ];
    final maxValue = allBytes.isEmpty ? 100 : allBytes.reduce((a, b) => a > b ? a : b);
    final peakValue = maxValue;

    // 绘制网格
    if (showGrid) {
      _drawGrid(canvas, size, maxValue);
    }

    // 绘制上传流量折线
    if (uploadData.isNotEmpty) {
      _drawLinePath(
        canvas,
        size,
        uploadData,
        maxValue,
        uploadColor,
        fillOpacity: 0.2,
      );
    }

    // 绘制下载流量折线
    if (downloadData.isNotEmpty) {
      _drawLinePath(
        canvas,
        size,
        downloadData,
        maxValue,
        downloadColor,
        fillOpacity: 0.2,
      );
    }

    // 绘制峰值标注
    if (showPeak && peakValue > 0) {
      _drawPeakLabel(canvas, size, peakValue, uploadData, downloadData);
    }

    // 绘制 Y 轴标签
    _drawYAxisLabels(canvas, size, maxValue);
  }

  void _drawEmptyState(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      text: const TextSpan(
        text: '暂无流量数据',
        style: TextStyle(color: Colors.grey, fontSize: 14),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size.width - textPainter.width) / 2, size.height / 2),
    );
  }

  void _drawGrid(Canvas canvas, Size size, double maxValue) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // 绘制 4 条水平网格线
    for (int i = 1; i <= 4; i++) {
      final y = size.height - (size.height * i / 5);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  void _drawLinePath(
    Canvas canvas,
    Size size,
    List<TrafficDataPoint> data,
    double maxValue,
    Color color, {
    double fillOpacity = 0.2,
  }) {
    if (data.isEmpty) return;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..color = color.withOpacity(fillOpacity)
      ..style = PaintingStyle.fill;

    // 创建路径
    final path = Path();
    final fillPath = Path();

    final xStep = size.width / (data.length - 1).clamp(1, data.length);

    // 起点
    final firstPoint = data.first;
    final normalizedFirstY = firstPoint.bytes / maxValue;
    final startX = 0.0;
    final startY = size.height - (normalizedFirstY * size.height);

    path.moveTo(startX, startY);
    fillPath.moveTo(startX, startY);

    // 绘制折线
    for (int i = 1; i < data.length; i++) {
      final point = data[i];
      final normalizedY = point.bytes / maxValue;
      final x = i * xStep;
      final y = size.height - (normalizedY * size.height);

      path.lineTo(x, y);
      fillPath.lineTo(x, y);
    }

    // 闭合填充路径
    if (data.length > 1) {
      final lastX = (data.length - 1) * xStep;
      fillPath.lineTo(lastX, size.height);
      fillPath.lineTo(0, size.height);
      fillPath.close();
    }

    // 绘制填充区域
    canvas.drawPath(fillPath, fillPaint);

    // 绘制折线
    canvas.drawPath(path, linePaint);

    // 绘制数据点
    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final point = data[i];
      final normalizedY = point.bytes / maxValue;
      final x = i * xStep;
      final y = size.height - (normalizedY * size.height);

      canvas.drawCircle(Offset(x, y), 3, pointPaint);
    }
  }

  void _drawPeakLabel(
    Canvas canvas,
    Size size,
    double peakValue,
    List<TrafficDataPoint> uploadData,
    List<TrafficDataPoint> downloadData,
  ) {
    // 找到峰值所在的数据点
    TrafficDataPoint? peakPoint;
    bool isUpload = true;

    final uploadPeak = uploadData.isNotEmpty
        ? uploadData.reduce((a, b) => a.bytes > b.bytes ? a : b)
        : null;
    final downloadPeak = downloadData.isNotEmpty
        ? downloadData.reduce((a, b) => a.bytes > b.bytes ? a : b)
        : null;

    if (uploadPeak != null &&
        (downloadPeak == null || uploadPeak.bytes > downloadPeak.bytes)) {
      peakPoint = uploadPeak;
      isUpload = true;
    } else if (downloadPeak != null) {
      peakPoint = downloadPeak;
      isUpload = false;
    }

    if (peakPoint == null) return;

    // 计算峰值位置
    final data = isUpload ? uploadData : downloadData;
    final peakIndex = data.indexOf(peakPoint);
    final xStep = size.width / (data.length - 1).clamp(1, data.length);
    final normalizedY = peakPoint.bytes / peakValue;
    final x = peakIndex * xStep;
    final y = size.height - (normalizedY * size.height);

    // 绘制峰值标签
    final peakText = peakPoint.formattedBytes;
    final textPainter = TextPainter(
      text: TextSpan(
        text: '峰值：$peakText',
        style: TextStyle(
          color: isUpload ? uploadColor : downloadColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // 背景
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    final bgWidth = textPainter.width + 8;
    final bgHeight = textPainter.height + 4;
    final bgRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x - bgWidth / 2, y - bgHeight - 8, bgWidth, bgHeight),
      const Radius.circular(4),
    );

    canvas.drawRRect(bgRect, bgPaint);
    textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - bgHeight - 6));
  }

  void _drawYAxisLabels(Canvas canvas, Size size, double maxValue) {
    final labelPaint = Paint()
      ..color = Colors.grey.shade600
      ..style = PaintingStyle.fill;

    final textStyles = TextStyle(
      color: Colors.grey.shade600,
      fontSize: 10,
    );

    // 绘制 5 个 Y 轴标签（0%, 25%, 50%, 75%, 100%）
    for (int i = 0; i <= 4; i++) {
      final value = maxValue * i / 4;
      final y = size.height - (size.height * i / 4);

      String labelText;
      if (value < 1024) {
        labelText = '${value.toStringAsFixed(0)}B';
      } else if (value < 1024 * 1024) {
        labelText = '${(value / 1024).toStringAsFixed(0)}KB';
      } else if (value < 1024 * 1024 * 1024) {
        labelText = '${(value / (1024 * 1024)).toStringAsFixed(1)}MB';
      } else {
        labelText = '${(value / (1024 * 1024 * 1024)).toStringAsFixed(2)}GB';
      }

      final textPainter = TextPainter(
        text: TextSpan(text: labelText, style: textStyles),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant TrafficChartPainter oldDelegate) {
    return oldDelegate.uploadData != uploadData ||
        oldDelegate.downloadData != downloadData ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.showPeak != showPeak;
  }
}
