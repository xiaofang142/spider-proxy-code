import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import '../../main.dart';
import '../../core/proxy_service.dart';
import 'certificate_install_guide_page.dart';
import 'rewrite_rules_page.dart';
import '../../core/rewriter/request_rewriter.dart';

class SettingsPage extends StatefulWidget {
  final ProxyServiceManager proxyService;

  const SettingsPage({super.key, required this.proxyService});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  int _httpPort = 8888;
  bool _httpsEnabled = true;
  String _filterDomains = '';
  bool _useSystemProxy = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 代理设置
          _buildSection(
            title: '代理设置',
            children: [
              _buildPortSetting(),
              _buildHttpsSetting(),
              _buildSystemProxySetting(),
            ],
          ),
          const SizedBox(height: 20),

          // 过滤设置
          _buildSection(
            title: '过滤设置',
            children: [
              _buildDomainFilterSetting(),
            ],
          ),
          const SizedBox(height: 20),

          // 证书管理
          _buildSection(
            title: '证书管理',
            children: [
              _buildInstallCertificate(),
              _buildViewCertificate(),
              _buildUninstallCertificate(),
            ],
          ),
          const SizedBox(height: 20),

          // 数据存储
          _buildSection(
            title: '数据存储',
            children: [
              _buildStorageLocation(),
              _buildClearData(),
            ],
          ),
          const SizedBox(height: 20),

          // 高级功能
          _buildSection(
            title: '高级功能',
            children: [
              _buildRewriteRules(),
            ],
          ),
          const SizedBox(height: 20),

          // 关于
          _buildSection(
            title: '关于',
            children: [
              _buildVersionInfo(),
              _buildHelpFeedback(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildPortSetting() {
    return ListTile(
      leading: const Icon(Icons.settings_ethernet),
      title: const Text('HTTP 代理端口'),
      subtitle: Text('$_httpPort'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showPortDialog(),
    );
  }

  Widget _buildHttpsSetting() {
    return SwitchListTile(
      leading: const Icon(Icons.security),
      title: const Text('HTTPS 解密'),
      subtitle: const Text('解密 HTTPS 流量需要安装证书'),
      value: _httpsEnabled,
      onChanged: (value) => setState(() => _httpsEnabled = value),
    );
  }

  Widget _buildSystemProxySetting() {
    return SwitchListTile(
      leading: const Icon(Icons.dns),
      title: const Text('使用系统代理'),
      subtitle: const Text('需要设备支持'),
      value: _useSystemProxy,
      onChanged: (value) => setState(() => _useSystemProxy = value),
    );
  }

  Widget _buildDomainFilterSetting() {
    return ListTile(
      leading: const Icon(Icons.filter_list),
      title: const Text('域名过滤'),
      subtitle: Text(_filterDomains.isEmpty ? '未设置' : _filterDomains),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showDomainFilterDialog(),
    );
  }

  Widget _buildInstallCertificate() {
    return ListTile(
      leading: const Icon(Icons.download),
      title: const Text('安装 CA 证书'),
      subtitle: const Text('首次使用 HTTPS 解密需要安装'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _installCertificate(),
    );
  }

  Widget _buildViewCertificate() {
    return ListTile(
      leading: const Icon(Icons.visibility),
      title: const Text('查看证书信息'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _viewCertificate(),
    );
  }

  Widget _buildUninstallCertificate() {
    return ListTile(
      leading: const Icon(Icons.delete_forever, color: Colors.orange),
      title: const Text('卸载 CA 证书', style: TextStyle(color: Colors.orange)),
      subtitle: const Text('删除本地证书和 KeyStore 私钥'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _confirmUninstallCertificate(),
    );
  }

  Widget _buildStorageLocation() {
    return ListTile(
      leading: const Icon(Icons.folder),
      title: const Text('存储位置'),
      subtitle: const Text('应用文档目录'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('存储位置设置开发中...')),
        );
      },
    );
  }

  Widget _buildClearData() {
    return ListTile(
      leading: const Icon(Icons.delete_forever, color: Colors.red),
      title: const Text('清空所有数据', style: TextStyle(color: Colors.red)),
      subtitle: const Text('删除所有抓包记录和设置'),
      onTap: () => _confirmClearData(),
    );
  }

  Widget _buildRewriteRules() {
    return ListTile(
      leading: const Icon(Icons.edit, color: Colors.blue),
      title: const Text('请求重写'),
      subtitle: const Text('修改 Header、URL 重定向、请求重放'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RewriteRulesPage(
              rewriter: RequestRewriter(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildVersionInfo() {
    return ListTile(
      leading: const Icon(Icons.info_outline),
      title: const Text('版本'),
      subtitle: const Text('v1.0.0-alpha'),
    );
  }

  Widget _buildHelpFeedback() {
    return ListTile(
      leading: const Icon(Icons.help_outline),
      title: const Text('帮助与反馈'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('帮助与反馈功能开发中...')),
        );
      },
    );
  }

  void _showPortDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置代理端口'),
        content: TextField(
          keyboardType: TextInputType.number,
          controller: TextEditingController(text: '$_httpPort'),
          decoration: const InputDecoration(
            labelText: '端口',
            hintText: '1024-65535',
          ),
          onChanged: (value) {
            final port = int.tryParse(value);
            if (port != null && port >= 1024 && port <= 65535) {
              setState(() => _httpPort = port);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('端口设置已保存')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showDomainFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('域名过滤'),
        content: TextField(
          controller: TextEditingController(text: _filterDomains),
          decoration: const InputDecoration(
            labelText: '域名列表',
            hintText: '使用逗号分隔多个域名',
            helperText: '留空表示不过滤，示例：api.example.com,test.com',
          ),
          maxLines: 3,
          onChanged: (value) => setState(() => _filterDomains = value),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _filterDomains = '');
              Navigator.pop(context);
            },
            child: const Text('清空'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('域名过滤已保存')),
              );
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _installCertificate() async {
    // 跳转到证书安装引导页面
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CertificateInstallGuidePage(
          proxyService: widget.proxyService,
        ),
      ),
    );

    // 返回后重新检查证书状态
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _viewCertificate() async {
    try {
      final certInfo = await widget.proxyService.getCertificateInfo();
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('CA 证书信息'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('主题', certInfo['subject'] ?? 'N/A'),
                  _buildInfoRow('颁发者', certInfo['issuer'] ?? 'N/A'),
                  _buildInfoRow('有效期', certInfo['validity'] ?? 'N/A'),
                  _buildInfoRow('指纹', certInfo['fingerprint'] ?? 'N/A'),
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取证书信息失败：$e')),
        );
      }
    }
  }

  Future<void> _confirmUninstallCertificate() async {
    if (!mounted) return;

    // 先检查证书是否已安装
    final isInstalled = await widget.proxyService.isCACertificateTrusted();

    if (!isInstalled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('证书未安装，无需卸载')),
      );
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认卸载证书'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('此操作将删除：'),
            const SizedBox(height: 8),
            const Text('• KeyStore 中存储的 CA 私钥', style: TextStyle(fontSize: 14)),
            const Text('• 本地证书文件', style: TextStyle(fontSize: 14)),
            const Text('• 证书缓存', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            const Text('警告：卸载后需要重新安装才能使用 HTTPS 解密功能。',
                style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _uninstallCertificate();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('卸载'),
          ),
        ],
      ),
    );
  }

  Future<void> _uninstallCertificate() async {
    try {
      final result = await widget.proxyService.uninstallCACertificate();
      if (mounted) {
        if (result['success'] == true) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('证书已卸载'),
              content: const Text('CA 证书已从 KeyStore 和本地存储中删除。'),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('确定'),
                ),
              ],
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('证书卸载失败：${result['error'] ?? '未知错误'}')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('证书卸载失败：$e')),
        );
      }
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  void _confirmClearData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空数据'),
        content: const Text('此操作将删除所有抓包记录、设置和证书，且不可恢复。确定继续吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              StoreProvider.of<AppState>(context).dispatch(ClearCapturesAction());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('数据已清空')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('清空'),
          ),
        ],
      ),
    );
  }
}
