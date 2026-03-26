/// 路由配置模式
enum RouteMode {
  /// 代理所有流量
  all,
  
  /// 仅代理指定域名/IP
  whitelist,
  
  /// 代理除指定域名/IP 外的所有流量
  blacklist,
  
  /// 不使用代理
  direct,
}

/// 路由规则
class RouteRule {
  final String pattern;
  final RouteMode mode;
  final bool isDomain;
  final bool isRegex;
  final String? description;

  const RouteRule({
    required this.pattern,
    this.mode = RouteMode.whitelist,
    this.isDomain = false,
    this.isRegex = false,
    this.description,
  });

  /// 检查是否匹配
  bool matches(String host) {
    if (isRegex) {
      final regex = RegExp(pattern, caseSensitive: false);
      return regex.hasMatch(host);
    } else if (isDomain) {
      // 域名匹配：支持 *.example.com 格式
      if (pattern.startsWith('*.')) {
        final suffix = pattern.substring(1);
        return host.endsWith(suffix);
      }
      return host == pattern;
    } else {
      // IP 地址匹配
      return host == pattern;
    }
  }

  @override
  String toString() {
    return 'RouteRule(pattern: $pattern, mode: $mode, isDomain: $isDomain)';
  }
}

/// 路由配置
class RouteConfig {
  final RouteMode defaultMode;
  final List<RouteRule> rules;
  final List<String> bypassDomains;
  final List<String> proxyDomains;
  final List<String> bypassIPs;
  final List<String> proxyIPs;
  final List<String> dnsServers;

  const RouteConfig({
    this.defaultMode = RouteMode.blacklist,
    this.rules = const [],
    this.bypassDomains = const [],
    this.proxyDomains = const [],
    this.bypassIPs = const [],
    this.proxyIPs = const [],
    this.dnsServers = const ['8.8.8.8', '8.8.4.4'],
  });

  /// 检查是否应该代理指定主机
  bool shouldProxy(String host) {
    // 首先检查规则
    for (final rule in rules) {
      if (rule.matches(host)) {
        return _modeToBool(rule.mode);
      }
    }

    // 检查域名列表
    if (proxyDomains.any((d) => _domainMatches(host, d))) {
      return true;
    }
    if (bypassDomains.any((d) => _domainMatches(host, d))) {
      return false;
    }

    // 检查 IP 列表
    if (proxyIPs.contains(host)) {
      return true;
    }
    if (bypassIPs.contains(host)) {
      return false;
    }

    // 返回默认模式
    return _modeToBool(defaultMode);
  }

  /// 域名匹配辅助函数
  bool _domainMatches(String host, String pattern) {
    if (pattern.startsWith('*.')) {
      final suffix = pattern.substring(1);
      return host.endsWith(suffix);
    }
    return host == pattern;
  }

  /// 模式转布尔值
  bool _modeToBool(RouteMode mode) {
    switch (mode) {
      case RouteMode.all:
      case RouteMode.whitelist:
        return true;
      case RouteMode.blacklist:
        return true;
      case RouteMode.direct:
        return false;
    }
  }

  /// 添加规则
  RouteConfig withRule(RouteRule rule) {
    return RouteConfig(
      defaultMode: defaultMode,
      rules: [...rules, rule],
      bypassDomains: bypassDomains,
      proxyDomains: proxyDomains,
      bypassIPs: bypassIPs,
      proxyIPs: proxyIPs,
      dnsServers: dnsServers,
    );
  }

  /// 添加代理域名
  RouteConfig withProxyDomain(String domain) {
    return RouteConfig(
      defaultMode: defaultMode,
      rules: rules,
      bypassDomains: bypassDomains,
      proxyDomains: [...proxyDomains, domain],
      bypassIPs: bypassIPs,
      proxyIPs: proxyIPs,
      dnsServers: dnsServers,
    );
  }

  /// 添加绕过域名
  RouteConfig withBypassDomain(String domain) {
    return RouteConfig(
      defaultMode: defaultMode,
      rules: rules,
      bypassDomains: [...bypassDomains, domain],
      proxyDomains: proxyDomains,
      bypassIPs: bypassIPs,
      proxyIPs: proxyIPs,
      dnsServers: dnsServers,
    );
  }

  /// 获取所有路由
  List<String> getRoutes() {
    final routes = <String>{};
    
    // 添加规则中的模式
    for (final rule in rules) {
      routes.add(rule.pattern);
    }
    
    // 添加域名列表
    routes.addAll(proxyDomains);
    routes.addAll(bypassDomains);
    
    return routes.toList();
  }

  /// 从 JSON 创建配置
  factory RouteConfig.fromJson(Map<String, dynamic> json) {
    return RouteConfig(
      defaultMode: RouteMode.values.firstWhere(
        (m) => m.name == json['defaultMode'],
        orElse: () => RouteMode.blacklist,
      ),
      rules: (json['rules'] as List?)
              ?.map((r) => RouteRule(
                    pattern: r['pattern'] as String,
                    mode: RouteMode.values.firstWhere(
                      (m) => m.name == r['mode'],
                      orElse: () => RouteMode.whitelist,
                    ),
                    isDomain: r['isDomain'] as bool? ?? false,
                    isRegex: r['isRegex'] as bool? ?? false,
                  ))
              .toList() ??
          [],
      bypassDomains: List<String>.from(json['bypassDomains'] ?? []),
      proxyDomains: List<String>.from(json['proxyDomains'] ?? []),
      bypassIPs: List<String>.from(json['bypassIPs'] ?? []),
      proxyIPs: List<String>.from(json['proxyIPs'] ?? []),
      dnsServers: List<String>.from(json['dnsServers'] ?? ['8.8.8.8', '8.8.4.4']),
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'defaultMode': defaultMode.name,
      'rules': rules.map((r) => {
            'pattern': r.pattern,
            'mode': r.mode.name,
            'isDomain': r.isDomain,
            'isRegex': r.isRegex,
          }).toList(),
      'bypassDomains': bypassDomains,
      'proxyDomains': proxyDomains,
      'bypassIPs': bypassIPs,
      'proxyIPs': proxyIPs,
      'dnsServers': dnsServers,
    };
  }

  /// 预定义配置：代理所有
  static const all = RouteConfig(
    defaultMode: RouteMode.all,
  );

  /// 预定义配置：仅代理指定
  static const whitelist = RouteConfig(
    defaultMode: RouteMode.direct,
  );

  /// 预定义配置：绕过指定
  static const blacklist = RouteConfig(
    defaultMode: RouteMode.all,
  );
}
