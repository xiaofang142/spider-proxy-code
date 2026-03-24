import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import '../../main.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

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
                Card(
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        Icon(
                          state.isProxyRunning
                              ? Icons.security
                              : Icons.security_outlined,
                          size: 64,
                          color: state.isProxyRunning
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.isProxyRunning ? '代理运行中' : '代理已停止',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          state.isProxyRunning
                              ? '正在捕获网络流量'
                              : '点击启动代理',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: () {
                            StoreProvider.of<AppState>(context)
                                .dispatch(ToggleProxyAction());
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: state.isProxyRunning
                                ? Colors.red
                                : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 15,
                            ),
                          ),
                          child: Text(
                            state.isProxyRunning ? '停止代理' : '启动代理',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // 统计信息
                Row(
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
                  ],
                ),
              ],
            ),
          );
        },
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
