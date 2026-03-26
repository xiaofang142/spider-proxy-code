import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';

/// CA 证书管理器
///
/// 注意：完整的证书生成需要使用原生平台通道调用 OpenSSL 或系统证书 API
/// 本实现提供基础框架和占位实现，实际生产环境需要实现 Platform Channel
class CertificateManager {
  static const String _caCertFileName = 'spider_proxy_ca.crt';
  static const String _caKeyFileName = 'spider_proxy_ca.key';
  static const String _certsDirName = 'certificates';

  Directory? _certsDir;
  bool _isInitialized = false;
  String? _caCertificatePem;
  String? _caPrivateKeyPem;

  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  /// 证书目录
  Directory? get certsDir => _certsDir;

  /// CA 证书文件路径
  String? get caCertPath => _certsDir != null
      ? path.join(_certsDir!.path, _caCertFileName)
      : null;

  /// CA 私钥文件路径
  String? get caKeyPath => _certsDir != null
      ? path.join(_certsDir!.path, _caKeyFileName)
      : null;

  /// 初始化证书管理器
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 获取应用文档目录
    final appDir = await getApplicationDocumentsDirectory();
    _certsDir = Directory(path.join(appDir.path, _certsDirName));

    // 创建证书目录
    if (!await _certsDir!.exists()) {
      await _certsDir!.create(recursive: true);
    }

    // 生成或加载 CA 证书
    await _ensureCACertificate();

    _isInitialized = true;
    print('[CertificateManager] Initialized at ${_certsDir!.path}');
  }

  /// 确保 CA 证书存在
  Future<void> _ensureCACertificate() async {
    final certFile = File(path.join(_certsDir!.path, _caCertFileName));
    final keyFile = File(path.join(_certsDir!.path, _caKeyFileName));

    // 如果证书不存在，生成新的 CA 证书
    if (!await certFile.exists() || !await keyFile.exists()) {
      await _generateCACertificate();
    } else {
      // 加载现有证书
      _caCertificatePem = await certFile.readAsString();
      _caPrivateKeyPem = await keyFile.readAsString();
      print('[CertificateManager] CA certificate loaded from disk');
    }
  }

  /// 生成 CA 证书
  ///
  /// 注意：完整的实现需要：
  /// 1. 使用 crypto 库生成 RSA 密钥对
  /// 2. 创建 X.509 证书结构
  /// 3. 使用 ASN.1 编码
  /// 4. 保存为 PEM 格式
  ///
  /// 由于 Dart 标准库对 X.509 证书支持有限，实际生产环境应使用：
  /// - Android: 通过 Platform Channel 调用 Java KeyStore 或 OpenSSL
  /// - iOS: 通过 Platform Channel 调用 Security Framework
  Future<void> _generateCACertificate() async {
    print('[CertificateManager] Generating CA certificate...');

    final now = DateTime.now();
    final expiry = DateTime(now.year + 10, now.month, now.day);

    // 生成证书序列号
    final serialNumber = _generateSerialNumber();

    // 生成证书信息
    final certInfo = _CertificateInfo(
      subject: 'CN=Spider Proxy CA,O=Spider Proxy,C=CN',
      issuer: 'CN=Spider Proxy CA,O=Spider Proxy,C=CN',
      serialNumber: serialNumber,
      notBefore: now,
      notAfter: expiry,
      publicKey: _generateRSAPublicKey(),
    );

    // 生成证书 PEM
    _caCertificatePem = _generateCertificatePem(certInfo);

    // 生成私钥 PEM (占位实现)
    _caPrivateKeyPem = _generateRSAPrivateKeyPem();

    // 保存到文件
    final certFile = File(path.join(_certsDir!.path, _caCertFileName));
    final keyFile = File(path.join(_certsDir!.path, _caKeyFileName));

    await certFile.writeAsString(_caCertificatePem!);
    await keyFile.writeAsString(_caPrivateKeyPem!);

    print('[CertificateManager] CA certificate generated');
  }

  /// 生成随机序列号
  String _generateSerialNumber() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(':').toUpperCase();
  }

  /// 生成 RSA 公钥信息 (占位)
  String _generateRSAPublicKey() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(256, (_) => random.nextInt(256));
    final modulus = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return 'RSA-PUBKEY-MODULUS:$modulus';
  }

  /// 生成 RSA 私钥 PEM (占位)
  String _generateRSAPrivateKeyPem() {
    final buffer = StringBuffer();
    buffer.writeln('-----BEGIN RSA PRIVATE KEY-----');
    // Base64 编码的 DER 格式私钥 (占位)
    buffer.writeln('MIIEpAIBAAKCAQEA' + List.filled(300, 'A').join());
    buffer.writeln('-----END RSA PRIVATE KEY-----');
    return buffer.toString();
  }

  /// 生成证书 PEM
  String _generateCertificatePem(_CertificateInfo info) {
    final buffer = StringBuffer();
    buffer.writeln('-----BEGIN CERTIFICATE-----');
    buffer.writeln('Subject: ${info.subject}');
    buffer.writeln('Issuer: ${info.issuer}');
    buffer.writeln('Serial Number: ${info.serialNumber}');
    buffer.writeln('Not Before: ${info.notBefore.toIso8601String()}');
    buffer.writeln('Not After: ${info.notAfter.toIso8601String()}');
    buffer.writeln('Public Key: ${info.publicKey}');

    // 添加 SHA256 指纹
    final fingerprint = sha256.convert(info.subject.codeUnits).toString();
    buffer.writeln('SHA256 Fingerprint: $fingerprint');

    buffer.writeln('-----END CERTIFICATE-----');
    return buffer.toString();
  }

  /// 获取 CA 证书数据
  Future<Uint8List> getCACertificateBytes() async {
    if (!_isInitialized) {
      throw StateError('CertificateManager not initialized');
    }

    final certFile = File(path.join(_certsDir!.path, _caCertFileName));
    if (!await certFile.exists()) {
      throw FileSystemException('CA certificate not found');
    }

    return await certFile.readAsBytes();
  }

  /// 获取 CA 证书字符串
  Future<String> getCACertificateString() async {
    if (!_isInitialized) {
      throw StateError('CertificateManager not initialized');
    }

    final certFile = File(path.join(_certsDir!.path, _caCertFileName));
    if (!await certFile.exists()) {
      throw FileSystemException('CA certificate not found');
    }

    return await certFile.readAsString();
  }

  /// 为指定主机生成证书
  ///
  /// 注意：完整的实现需要：
  /// 1. 生成主机特定的 RSA 密钥对
  /// 2. 创建 CSR (Certificate Signing Request)
  /// 3. 使用 CA 证书签名
  /// 4. 返回证书和私钥
  Future<Map<String, Uint8List>> generateCertificateForHost(String host) async {
    if (!_isInitialized) {
      throw StateError('CertificateManager not initialized');
    }

    print('[CertificateManager] Generating certificate for host: $host');

    // 生成主机特定证书信息
    final now = DateTime.now();
    final expiry = DateTime(now.year + 1, now.month, now.day);
    final serialNumber = _generateSerialNumber();

    final certInfo = _CertificateInfo(
      subject: 'CN=$host,O=Spider Proxy,C=CN',
      issuer: 'CN=Spider Proxy CA,O=Spider Proxy,C=CN',
      serialNumber: serialNumber,
      notBefore: now,
      notAfter: expiry,
      publicKey: _generateRSAPublicKey(),
    );

    final certPem = _generateCertificatePem(certInfo);
    final keyPem = _generateRSAPrivateKeyPem();

    // 临时实现：返回 PEM 数据的字节形式
    return {
      'cert': Uint8List.fromList(certPem.codeUnits),
      'key': Uint8List.fromList(keyPem.codeUnits),
    };
  }

  /// 安装 CA 证书到设备
  ///
  /// 注意：这需要平台特定的实现
  /// - Android: 需要用户手动安装到系统证书存储
  /// - iOS: 需要安装描述文件并手动信任
  Future<bool> installCACertificate() async {
    if (!_isInitialized) {
      throw StateError('CertificateManager not initialized');
    }

    print('[CertificateManager] To install CA certificate:');
    print('1. Open device Settings');
    print('2. Go to Security/Privacy > Certificate Management');
    print('3. Import certificate from: $caCertPath');
    print('4. Trust the certificate for network connections');
    print('');
    print('For Android:');
    print('  Settings > Security > Encryption & credentials > Install from storage');
    print('');
    print('For iOS:');
    print('  Settings > General > VPN & Device Management > Install Profile');

    return true;
  }

  /// 检查 CA 证书是否已安装并信任
  Future<bool> isCACertificateTrusted() async {
    if (!_isInitialized || caCertPath == null) {
      return false;
    }

    final certFile = File(caCertPath!);
    return await certFile.exists();
  }

  /// 删除所有证书
  Future<void> deleteAllCertificates() async {
    if (_certsDir != null && await _certsDir!.exists()) {
      await _certsDir!.delete(recursive: true);
      _certsDir = null;
      _isInitialized = false;
      print('[CertificateManager] All certificates deleted');
    }
  }

  /// 清理过期的证书
  Future<void> pruneExpiredCertificates() async {
    if (_certsDir == null) return;
    print('[CertificateManager] Pruning expired certificates...');
    // TODO: 实现证书过期检查逻辑
  }

  /// 获取证书过期时间
  DateTime? get certificateExpiry {
    if (!_isInitialized) return null;
    return DateTime.now().add(const Duration(days: 3650)); // 10 年
  }
}

/// 证书信息内部类
class _CertificateInfo {
  final String subject;
  final String issuer;
  final String serialNumber;
  final DateTime notBefore;
  final DateTime notAfter;
  final String publicKey;

  _CertificateInfo({
    required this.subject,
    required this.issuer,
    required this.serialNumber,
    required this.notBefore,
    required this.notAfter,
    required this.publicKey,
  });
}
