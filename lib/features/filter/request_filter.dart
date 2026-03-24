/// 请求过滤器 - 用于过滤和匹配网络请求
class RequestFilter {
  final List<String> _domainWhitelist = [];
  final List<String> _domainBlacklist = [];
  final List<RegExp> _urlPatterns = [];

  bool _isEnabled = false;

  bool get isEnabled => _isEnabled;

  /// 启用过滤器
  void enable() {
    _isEnabled = true;
  }

  /// 禁用过滤器
  void disable() {
    _isEnabled = false;
  }

  /// 添加域名白名单
  void addDomainWhitelist(String domain) {
    if (!_domainWhitelist.contains(domain)) {
      _domainWhitelist.add(domain);
    }
  }

  /// 添加域名黑名单
  void addDomainBlacklist(String domain) {
    if (!_domainBlacklist.contains(domain)) {
      _domainBlacklist.add(domain);
    }
  }

  /// 添加 URL 模式
  void addUrlPattern(String pattern) {
    _urlPatterns.add(RegExp(pattern));
  }

  /// 检查请求是否应该被捕获
  bool shouldCapture(String url, String domain) {
    if (!_isEnabled) return true;

    // 检查黑名单
    if (_domainBlacklist.contains(domain)) {
      return false;
    }

    // 如果有白名单，只捕获白名单中的域名
    if (_domainWhitelist.isNotEmpty) {
      return _domainWhitelist.contains(domain);
    }

    // 检查 URL 模式
    if (_urlPatterns.isNotEmpty) {
      return _urlPatterns.any((pattern) => pattern.hasMatch(url));
    }

    return true;
  }

  /// 清除所有规则
  void clear() {
    _domainWhitelist.clear();
    _domainBlacklist.clear();
    _urlPatterns.clear();
  }
}
