# Spider Proxy Phase 2 核心引擎实现文档

## 📋 实现概览

本文档记录了 Spider Proxy Phase 2 核心引擎的完整实现，包括 HTTP 代理、HTTPS 解密、VPN 服务和流量监控功能。

## 📁 文件结构

```
lib/
├── core/
│   ├── models/
│   │   ├── models.dart              # 数据模型导出
│   │   ├── traffic_record.dart      # 流量记录模型
│   │   ├── request_detail.dart      # 请求详情模型
│   │   └── response_detail.dart     # 响应详情模型
│   ├── proxy/
│   │   ├── proxy.dart               # 代理模块导出
│   │   ├── http_proxy_server.dart   # HTTP 代理服务器
│   │   ├── proxy_handler.dart       # 请求处理器
│   │   ├── proxy_server.dart        # 基础代理服务器 (已有)
│   │   ├── request_interceptor.dart # 请求拦截器
│   │   └── response_interceptor.dart# 响应拦截器
│   ├── ssl/
│   │   ├── ssl.dart                 # SSL 模块导出
│   │   ├── certificate_manager.dart # CA 证书管理
│   │   ├── ssl_interceptor.dart     # SSL 拦截器
│   │   └── mitm_proxy.dart          # MITM 代理
│   ├── vpn/
│   │   ├── vpn.dart                 # VPN 模块导出
│   │   ├── vpn_service.dart         # VPN 服务
│   │   ├── packet_tunnel.dart       # 数据包隧道
│   │   └── route_config.dart        # 路由配置
│   └── proxy_service.dart           # 代理服务管理器
├── features/
│   └── traffic/
│       ├── traffic.dart             # 流量模块导出
│       ├── traffic_monitor.dart     # 流量监控 (已有)
│       ├── traffic_storage.dart     # SQLite 存储
│       └── traffic_analyzer.dart    # 流量分析
└── ui/
    └── pages/
        ├── home_page.dart           # 首页 UI (已更新)
        ├── capture_list_page.dart   # 抓包列表
        └── settings_page.dart       # 设置页面
```

## 🔧 核心功能

### 1. HTTP 代理服务器

**文件**: `lib/core/proxy/http_proxy_server.dart`

- 监听端口 8888（可配置）
- 处理 HTTP 请求转发
- 支持 CONNECT 方法（HTTPS 隧道）
- 请求/响应拦截器链
- 流量记录流

**使用示例**:
```dart
final proxy = HttpProxyServer(
  config: ProxyConfig(port: 8888),
  requestInterceptor: DefaultRequestInterceptor(),
  responseInterceptor: DefaultResponseInterceptor(),
);
await proxy.start();
```

### 2. HTTPS 证书管理

**文件**: `lib/core/ssl/certificate_manager.dart`

- CA 证书生成和管理
- 动态证书签发
- 证书缓存
- 证书安装指导

**注意**: 实际证书生成需要原生代码支持（OpenSSL 或 crypto 库）。

### 3. SSL 拦截器

**文件**: `lib/core/ssl/ssl_interceptor.dart`

- HTTPS 连接拦截
- 动态证书生成
- SSL 解密/加密（框架）

### 4. MITM 代理

**文件**: `lib/core/ssl/mitm_proxy.dart`

- HTTP/HTTPS 流量拦截
- 中间人代理实现
- 流量记录

### 5. VPN 服务

**文件**: `lib/core/vpn/vpn_service.dart`

- VPN 服务封装
- 数据包隧道
- 路由配置
- 状态管理

**注意**: 实际 VPN 功能需要平台特定实现：
- macOS: NetworkExtension
- Android: VpnService
- iOS: NetworkExtension

### 6. 流量监控

**文件**: `lib/features/traffic/`

- `traffic_monitor.dart`: 实时监控
- `traffic_storage.dart`: SQLite 存储
- `traffic_analyzer.dart`: 流量分析

### 7. 数据模型

**文件**: `lib/core/models/`

- `traffic_record.dart`: 流量记录
- `request_detail.dart`: 请求详情
- `response_detail.dart`: 响应详情

所有模型支持：
- JSON 序列化/反序列化
- copyWith 方法
- toString 方法

### 8. 首页 UI

**文件**: `lib/ui/pages/home_page.dart`

- 连接状态显示（已停止/运行中/启动中/停止中/错误）
- 开始/停止按钮
- 实时流量统计（上传/下载）
- 运行时长显示
- 请求计数

## 📊 状态管理

**文件**: `lib/main.dart`

新增状态：
- `ProxyStatus`: 代理状态枚举
- `TrafficStats`: 流量统计类
- `AppState`: 应用状态（包含 proxyStatus 和 trafficStats）

新增 Actions：
- `ProxyStartedAction`
- `ProxyStoppedAction`
- `ProxyErrorAction`
- `UpdateTrafficStatsAction`

## 🧪 测试

**文件**: `test/`

- `test/core/models_test.dart`: 数据模型测试
- `test/core/proxy_test.dart`: 代理服务测试
- `test/features/traffic_storage_test.dart`: 流量存储测试

**运行测试**:
```bash
cd /Users/xiaofang/documents/www/docker/spider-proxy/code
flutter test
```

## 📦 依赖

**文件**: `pubspec.yaml`

新增依赖：
- `uuid: ^4.2.1`: UUID 生成
- `path: ^1.8.3`: 路径处理

## 🚀 使用指南

### 启动代理服务

```dart
import 'package:spider_proxy/core/proxy_service.dart';

final proxyService = ProxyServiceManager();

// 启动代理
await proxyService.start(
  httpPort: 8888,
  httpsPort: 8889,
  enableHttps: true,
);

// 监听流量
proxyService.trafficStream.listen((record) {
  print('${record.method} ${record.url} - ${record.statusCode}');
});

// 停止代理
await proxyService.stop();
```

### 获取 CA 证书

```dart
final caCert = await proxyService.getCACertificate();
// 保存证书文件或显示给用户安装
```

### 流量分析

```dart
import 'package:spider_proxy/features/traffic/traffic_storage.dart';
import 'package:spider_proxy/features/traffic/traffic_analyzer.dart';

final storage = TrafficStorage();
await storage.initialize();

final analyzer = TrafficAnalyzer(storage: storage);
final result = await analyzer.analyze(
  startTime: DateTime.now().subtract(const Duration(hours: 1)),
  endTime: DateTime.now(),
);

print('总请求数：${result.totalRequests}');
print('平均响应时间：${result.averageDurationMs}ms');
```

## ⚠️ 注意事项

1. **证书生成**: 当前实现使用占位证书，实际使用需要集成 OpenSSL 或 crypto 库
2. **VPN 功能**: 需要平台特定的原生代码实现
3. **权限**: Android/iOS 需要相应权限才能运行代理和 VPN
4. **性能**: 生产环境需要优化证书缓存和连接池

## 📝 下一步

1. 实现实际的 CA 证书生成（使用 crypto 库或原生插件）
2. 实现平台特定的 VPN 集成
3. 添加完整的 SSL 解密逻辑
4. 优化性能和内存使用
5. 添加更多测试用例
6. 实现抓包列表页面和详情页面

## 📄 代码规范

- 遵循 Dart 代码规范
- 所有公共 API 都有文档注释
- 使用 const 构造函数
- 使用 final 声明不可变变量
- 错误处理使用 try-catch
- 异步操作使用 async/await
