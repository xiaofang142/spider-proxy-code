import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'main.dart';
import 'core/proxy_service.dart';

class HomePage extends StatefulWidget {
  final ProxyServiceManager proxyService;

  const HomePage({super.key, required this.proxyService});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spider Proxy'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: StoreConnector<AppState, AppState>(
        converter: (store) => store.state,
        builder: (context, state) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 代理状态卡片
                _buildStatusCard(context, state),
                const SizedBox(height: 20),
                // 实时流量统计
                if (state.isProxyRunning && state.trafficStats != null)
                  _buildTrafficStats(state.trafficStats!),
                const SizedBox(height: 20),
                // 统计信息
                _buildStatsCards(state),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 状态卡片
  Widget _buildStatusCard(BuildContext context, AppState state) {
    IconData icon;
    Color iconColor;
    String statusText;
    String subText;

    switch (state.proxyStatus) {
      case ProxyStatus.running:
        icon = Icons.security;
        iconColor = Colors.green;
        statusText = '代理运行中';
        subText = '正在捕获网络流量';
        break;
      case ProxyStatus.starting:
        icon = Icons.hourglass_empty;
        iconColor = Colors.orange;
        statusText = '启动中...';
        subText = '正在初始化代理服务';
        break;
      case ProxyStatus.stopping:
        icon = Icons.hourglass_empty;
        iconColor = Colors.orange;
        statusText = '停止中...';
        subText = '正在关闭代理服务';
        break;
      case ProxyStatus.error:
        icon = Icons.error_outline;
        iconColor = Colors.red;
        statusText = '代理错误';
        subText = '请检查日志了解详情';
        break;
      case ProxyStatus.stopped:
      default:
        icon = Icons.security_outlined;
        iconColor = Colors.grey;
        statusText = '代理已停止';
        subText = '点击启动代理';
    }

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Icon(
              icon,
              size: 64,
              color: iconColor,
            ),
            const SizedBox(height: 16),
            Text(
              statusText,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              subText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: state.proxyStatus == ProxyStatus.running ||
                      state.proxyStatus == ProxyStatus.stopping
                  ? () => _stopProxy(context)
                  : () => _startProxy(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: state.proxyStatus == ProxyStatus.running
                    ? Colors.red
                    : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
              ),
              child: state.proxyStatus == ProxyStatus.running
                  ? const Text('停止代理', style: TextStyle(fontSize: 18))
                  : const Text('启动代理', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startProxy(BuildContext context) async {
    try {
      StoreProvider.of<AppState>(context).dispatch(ToggleProxyAction());

      await widget.proxyService.start(
        httpPort: 8888,
        enableHttps: true,
      );

      StoreProvider.of<AppState>(context).dispatch(ProxyStartedAction());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('代理启动成功'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('[HomePage] Error starting proxy: $e');
      StoreProvider.of<AppState>(context).dispatch(ProxyErrorAction(e.toString()));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('代理启动失败：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopProxy(BuildContext context) async {
    try {
      StoreProvider.of<AppState>(context).dispatch(ToggleProxyAction());

      await widget.proxyService.stop();

      StoreProvider.of<AppState>(context).dispatch(ProxyStoppedAction());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('代理已停止'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      print('[HomePage] Error stopping proxy: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('停止代理失败：$e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// 实时流量统计
  Widget _buildTrafficStats(TrafficStats stats) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '实时流量',
              style: Theme.of(ThemeData()).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TrafficStatItem(
                    icon: Icons.arrow_upward,
                    label: '上传',
                    value: stats.totalSent,
                    speed: stats.currentUploadSpeed,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _TrafficStatItem(
                    icon: Icons.arrow_downward,
                    label: '下载',
                    value: stats.totalReceived,
                    speed: stats.currentDownloadSpeed,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 统计卡片
  Widget _buildStatsCards(AppState state) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.http,
            label: '捕获请求',
            value: '${state.capturedCount}',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.devices,
            label: '连接设备',
            value: '0',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            icon: Icons.timer,
            label: '运行时长',
            value: state.trafficStats != null
                ? _formatDuration(
                    DateTime.now().difference(state.trafficStats!.startTime))
                : '0:00',
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

class _TrafficStatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String speed;
  final Color color;

  const _TrafficStatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.speed,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Text(
            speed,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Colors.blue),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
