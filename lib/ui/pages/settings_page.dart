import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        children: [
          const _SettingsHeader(title: '代理设置'),
          ListTile(
            leading: const Icon(Icons.dns),
            title: const Text('代理端口'),
            subtitle: const Text('8888'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 修改端口
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.lock),
            title: const Text('HTTPS 解密'),
            subtitle: const Text('需要安装证书'),
            value: true,
            onChanged: (value) {
              // TODO: 切换 HTTPS 解密
            },
          ),
          const Divider(),
          const _SettingsHeader(title: '过滤规则'),
          ListTile(
            leading: const Icon(Icons.filter_alt),
            title: const Text('域名过滤'),
            subtitle: const Text('只捕获指定域名的流量'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 域名过滤设置
            },
          ),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('黑名单'),
            subtitle: const Text('忽略指定域名'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 黑名单设置
            },
          ),
          const Divider(),
          const _SettingsHeader(title: '存储'),
          ListTile(
            leading: const Icon(Icons.storage),
            title: const Text('抓包保存位置'),
            subtitle: const Text('/sdcard/spider_proxy/'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: 选择保存位置
            },
          ),
          ListTile(
            leading: const Icon(Icons.clear_all),
            title: const Text('清空历史数据'),
            onTap: () {
              _showClearConfirmDialog(context);
            },
          ),
          const Divider(),
          const _SettingsHeader(title: '关于'),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('版本'),
            subtitle: const Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('开源协议'),
            subtitle: const Text('MIT License'),
          ),
        ],
      ),
    );
  }

  void _showClearConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空所有历史抓包数据吗？此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // TODO: 清空数据
              Navigator.pop(context);
            },
            child: const Text('确认', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  final String title;

  const _SettingsHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
