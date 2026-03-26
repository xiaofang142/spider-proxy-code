import 'package:flutter/material.dart';
import '../../core/proxy_service.dart';

/// 证书安装引导页面
///
/// 提供分步指导，帮助用户正确安装 CA 证书到设备
class CertificateInstallGuidePage extends StatefulWidget {
  final ProxyServiceManager proxyService;

  const CertificateInstallGuidePage({
    super.key,
    required this.proxyService,
  });

  @override
  State<CertificateInstallGuidePage> createState() =>
      _CertificateInstallGuidePageState();
}

class _CertificateInstallGuidePageState
    extends State<CertificateInstallGuidePage> {
  int _currentStep = 0;
  bool _isInstalling = false;
  bool _installSuccess = false;
  bool _certificateInstalled = false;

  final List<_GuideStep> _steps = const [
    _GuideStep(
      icon: Icons.download,
      title: '下载证书',
      description: '首先，我们需要下载 CA 证书文件到您的设备',
      actionText: '下载证书',
    ),
    _GuideStep(
      icon: Icons.settings,
      title: '打开设置',
      description: '打开设备的「设置」应用',
      actionText: '我已打开设置',
    ),
    _GuideStep(
      icon: Icons.security,
      title: '安全设置',
      description: '进入「安全」或「隐私」设置页面',
      actionText: '我已找到安全设置',
    ),
    _GuideStep(
      icon: Icons.lock_outline,
      title: '证书管理',
      description: '找到「证书管理」或「加密和凭据」选项',
      actionText: '我已找到证书管理',
    ),
    _GuideStep(
      icon: Icons.folder_open,
      title: '从存储安装',
      description: '选择「从存储安装 CA 证书」或类似选项',
      actionText: '我已打开安装界面',
    ),
    _GuideStep(
      icon: Icons.description,
      title: '选择证书',
      description: '在下载管理器中找到并选择 Spider Proxy 证书文件',
      actionText: '我已选择证书',
    ),
    _GuideStep(
      icon: Icons.password,
      title: '设置密码',
      description: '如需设置锁屏密码，请设置一个您能记住的密码',
      actionText: '我已设置密码',
    ),
    _GuideStep(
      icon: Icons.check_circle,
      title: '命名并确认',
      description: '为证书命名（如"Spider Proxy"）并确认安装',
      actionText: '完成安装',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _checkCertificateStatus();
  }

  /// 检查证书安装状态
  Future<void> _checkCertificateStatus() async {
    try {
      final installed = await widget.proxyService.isCACertificateTrusted();
      setState(() {
        _certificateInstalled = installed;
      });
    } catch (e) {
      print('检查证书状态失败：$e');
    }
  }

  /// 下载证书
  Future<void> _downloadCertificate() async {
    setState(() {
      _isInstalling = true;
    });

    try {
      final success = await widget.proxyService.installCACertificate();
      if (success && mounted) {
        setState(() {
          _installSuccess = true;
        });
        // 自动进入下一步
        if (_currentStep < _steps.length - 1) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              setState(() {
                _currentStep++;
                _isInstalling = false;
              });
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInstalling = false;
        });
        _showErrorDialog('证书下载失败：$e');
      }
    }
  }

  /// 显示错误对话框
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('安装失败'),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  /// 验证安装
  Future<void> _verifyInstallation() async {
    await _checkCertificateStatus();
    if (_certificateInstalled && mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('🎉 安装成功'),
          content: const Text('CA 证书已成功安装到您的设备！\n\n现在您可以使用 Spider Proxy 进行 HTTPS 流量分析了。'),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('完成'),
            ),
          ],
        ),
      );
    } else {
      _showErrorDialog('未检测到证书，请重试安装步骤');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('证书安装引导'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // 进度指示器
          _buildProgressIndicator(),
          const Divider(height: 1),
          // 步骤内容
          Expanded(
            child: _buildStepContent(),
          ),
          // 底部按钮
          _buildBottomBar(),
        ],
      ),
    );
  }

  /// 构建进度指示器
  Widget _buildProgressIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            '步骤 ${_currentStep + 1} / ${_steps.length}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (_currentStep + 1) / _steps.length,
          ),
        ],
      ),
    );
  }

  /// 构建步骤内容
  Widget _buildStepContent() {
    final step = _steps[_currentStep];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 图标
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              step.icon,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 32),
          // 标题
          Text(
            step.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          // 描述
          Text(
            step.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 32),
          // 第一步显示下载状态
          if (_currentStep == 0) _buildDownloadStatus(),
          // 最后一步显示验证按钮
          if (_currentStep == _steps.length - 1) _buildVerifyButton(),
        ],
      ),
    );
  }

  /// 构建下载状态显示
  Widget _buildDownloadStatus() {
    if (_isInstalling) {
      return const Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('正在下载证书...'),
        ],
      );
    }

    if (_installSuccess) {
      return const Column(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 48),
          SizedBox(height: 16),
          Text('证书已下载', style: TextStyle(color: Colors.green)),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  /// 构建验证按钮
  Widget _buildVerifyButton() {
    return ElevatedButton.icon(
      onPressed: _certificateInstalled ? null : _verifyInstallation,
      icon: _certificateInstalled
          ? const Icon(Icons.check_circle)
          : const Icon(Icons.refresh),
      label: Text(_certificateInstalled ? '已验证' : '验证安装'),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            _certificateInstalled ? Colors.green : Theme.of(context).colorScheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      ),
    );
  }

  /// 构建底部按钮栏
  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 上一步按钮
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentStep--;
                  });
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('上一步'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 16),
          // 下一步按钮
          Expanded(
            flex: _currentStep > 0 ? 1 : 2,
            child: _currentStep == 0
                ? ElevatedButton.icon(
                    onPressed: _isInstalling ? null : _downloadCertificate,
                    icon: _isInstalling
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download),
                    label: Text(_steps[_currentStep].actionText),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  )
                : ElevatedButton.icon(
                    onPressed: _currentStep == _steps.length - 1
                        ? () => Navigator.pop(context)
                        : () {
                            setState(() {
                              _currentStep++;
                            });
                          },
                    icon: Icon(
                        _currentStep == _steps.length - 1
                            ? Icons.close
                            : Icons.arrow_forward),
                    label: Text(_steps[_currentStep].actionText),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// 引导步骤数据模型
class _GuideStep {
  final IconData icon;
  final String title;
  final String description;
  final String actionText;

  const _GuideStep({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionText,
  });
}
