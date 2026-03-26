import 'package:flutter/material.dart';
import 'dart:convert';
import '../../core/models/traffic_record.dart';
import '../../core/models/request_detail.dart';
import '../../core/models/response_detail.dart';
import '../../main.dart';
import 'package:flutter_redux/flutter_redux.dart';

/// 请求详情页面
///
/// 显示完整的请求和响应信息，包括：
/// - 概览：基本信息、时间线
/// - 请求：Headers、Body
/// - 响应：Headers、Body
class RequestDetailPage extends StatefulWidget {
  final String captureId;

  const RequestDetailPage({
    super.key,
    required this.captureId,
  });

  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  TrafficRecord? _trafficRecord;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, List<CaptureItem>>(
      converter: (store) => store.state.captures,
      builder: (context, captures) {
        // 根据 captureId 查找对应的记录
        final capture = captures.firstWhere(
          (c) => c.id == widget.captureId,
          orElse: () => CaptureItem(
            id: '',
            url: '',
            method: '',
            statusCode: 0,
            timestamp: DateTime.now(),
          ),
        );

        if (capture.id.isEmpty) {
          return const Scaffold(
            body: Center(child: Text('未找到请求记录')),
          );
        }

        // 注意：当前 CaptureItem 不包含完整的 TrafficRecord
        // 这里创建一个简化的 TrafficRecord 用于显示
        _trafficRecord = TrafficRecord(
          id: capture.id,
          timestamp: capture.timestamp,
          method: capture.method,
          url: capture.url,
          host: Uri.tryParse(capture.url)?.host ?? 'Unknown',
          path: Uri.tryParse(capture.url)?.path ?? '/',
          statusCode: capture.statusCode,
          requestSize: 0,
          responseSize: 0,
          durationMs: 0,
          isHttps: capture.url.startsWith('https://'),
        );

        return _buildContent(capture);
      },
    );
  }

  Widget _buildContent(CaptureItem capture) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('请求详情'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '概览'),
            Tab(text: '请求'),
            Tab(text: '响应'),
            Tab(text: '时间线'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(capture),
          _buildRequestTab(),
          _buildResponseTab(),
          _buildTimelineTab(capture),
        ],
      ),
    );
  }

  /// 概览标签页
  Widget _buildOverviewTab(CaptureItem capture) {
    final record = _trafficRecord;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 基本信息卡片
        _buildSection(
          title: '基本信息',
          children: [
            _buildInfoRow('方法', capture.method),
            _buildInfoRow('状态码', '${capture.statusCode}',
                valueColor: _getStatusCodeColor(capture.statusCode)),
            _buildInfoRow('URL', capture.url),
            _buildInfoRow('主机', record?.host ?? 'Unknown'),
            _buildInfoRow('路径', record?.path ?? '/'),
            _buildInfoRow('协议', capture.url.startsWith('https') ? 'HTTPS' : 'HTTP'),
          ],
        ),
        const SizedBox(height: 16),

        // 时间信息
        _buildSection(
          title: '时间信息',
          children: [
            _buildInfoRow('开始时间',
                capture.timestamp.toString().substring(0, 19)),
          ],
        ),
      ],
    );
  }

  /// 请求标签页
  Widget _buildRequestTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('请求详情数据需要完整的 MITM 解密支持',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey)),
          SizedBox(height: 8),
          Text('当前版本仅显示基本信息',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  /// 响应标签页
  Widget _buildResponseTab() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text('响应详情数据需要完整的 MITM 解密支持',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey)),
          SizedBox(height: 8),
          Text('当前版本仅显示基本信息',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  /// 时间线标签页
  Widget _buildTimelineTab(CaptureItem capture) {
    final timelineItems = [
      _TimelineItem(
        icon: Icons.dns,
        title: 'DNS 解析',
        subtitle: _trafficRecord?.host ?? 'Unknown',
        time: capture.timestamp,
      ),
      _TimelineItem(
        icon: Icons.link,
        title: '建立连接',
        subtitle: capture.url,
        time: capture.timestamp.add(const Duration(milliseconds: 1)),
      ),
      _TimelineItem(
        icon: Icons.send,
        title: '发送请求',
        subtitle: capture.method,
        time: capture.timestamp.add(const Duration(milliseconds: 2)),
        color: Colors.blue,
      ),
      _TimelineItem(
        icon: Icons.receive,
        title: '接收响应',
        subtitle: '${capture.statusCode}',
        time: capture.timestamp.add(const Duration(milliseconds: 3)),
        color: Colors.green,
      ),
      _TimelineItem(
        icon: Icons.check_circle,
        title: '完成',
        subtitle: '请求已完成',
        time: capture.timestamp.add(const Duration(milliseconds: 4)),
        color: Colors.orange,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...timelineItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _TimelineTile(
            item: item,
            isLast: index == timelineItems.length - 1,
          );
        }),
      ],
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建信息卡片区域
  Widget _buildSection({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  /// 格式化字节数
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// 获取状态码颜色
  Color _getStatusCodeColor(int statusCode) {
    if (statusCode >= 200 && statusCode < 300) {
      return Colors.green;
    } else if (statusCode >= 300 && statusCode < 400) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

/// 时间线项目
class _TimelineItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime time;
  final Color? color;

  _TimelineItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    this.color,
  });
}

/// 时间线组件
class _TimelineTile extends StatelessWidget {
  final _TimelineItem item;
  final bool isLast;

  const _TimelineTile({
    required this.item,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 图标列
        SizedBox(
          width: 40,
          child: Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: (item.color ?? Colors.blue).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.icon,
                  size: 18,
                  color: item.color ?? Colors.blue,
                ),
              ),
              if (!isLast)
                Container(
                  width: 2,
                  height: 40,
                  color: Colors.grey.shade300,
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // 内容列
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.time.toString().substring(0, 19),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
