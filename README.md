# Spider Proxy 🕷️

一个基于 Flutter 的网络代理和抓包工具，支持 Android 原生 VPN 服务。

## 功能特性

- 🌐 **HTTP/HTTPS 代理** - 支持 HTTP 和 HTTPS 流量捕获
- 🔒 **SSL 解密** - 中间人攻击 (MITM) 解密 HTTPS 流量
- 📱 **Android VPN 服务** - 原生 VpnService 实现，自动捕获流量
- 🔄 **TCP/UDP 转发** - 完整的 TCP/UDP 数据包转发到 SOCKS5 代理
- 📡 **DNS 解析** - DNS 查询域名解析和缓存
- 🎯 **智能过滤** - 域名白名单/黑名单，URL 模式匹配
- 📊 **流量监控** - 实时显示上传/下载速度
- 💾 **数据持久化** - SQLite 本地存储
- 🔧 **Platform Channel** - Flutter 与 Android 原生通信

## 项目结构

```
code/
├── lib/                     # Flutter 代码
│   ├── main.dart           # 应用入口
│   ├── core/               # 核心模块
│   │   ├── proxy/         # 代理服务器
│   │   ├── ssl/           # SSL 拦截
│   │   ├── vpn/           # VPN 服务
│   │   └── models/        # 数据模型
│   ├── features/           # 功能模块
│   │   ├── traffic/       # 流量监控
│   │   └── filter/        # 请求过滤
│   └── ui/                 # 用户界面
│       └── pages/         # 页面
├── android/                # Android 原生代码
│   └── app/src/main/
│       └── kotlin/
│           └── com/spiderproxy/spider_proxy/
│               ├── MainActivity.kt
│               ├── VpnService.kt
│               ├── SslInterceptor.kt
│               ├── TcpForwarder.kt      # TCP 转发器
│               ├── UdpForwarder.kt      # UDP 转发器
│               ├── TunDeviceWriter.kt   # TUN 设备写回
│               ├── DnsResolver.kt       # DNS 解析器
│               └── ProxyForegroundService.kt
└── docs/                   # 文档
```

## 依赖说明

| 依赖 | 用途 |
|------|------|
| http_proxy | HTTP 代理服务器实现 |
| flutter_redux | 状态管理 |
| sqflite | 本地 SQLite 数据库 |
| permission_handler | 权限管理 |
| crypto | SSL/TLS 支持 |
| pointycastle | 加密算法 |
| org.bouncycastle:bcprov-jdk15on | Bouncy Castle 加密库 (Android) |
| org.bouncycastle:bcpkix-jdk15on | Bouncy Castle PKIX 库 (Android) |

## 开发环境要求

- Flutter SDK >= 3.24.0
- Dart SDK >= 3.5.0
- Android Studio
- Android minSdkVersion: 24

## 快速开始

### 1. 安装依赖

```bash
cd code
flutter pub get
```

### 2. 运行应用

```bash
# Android
flutter run
```

### 3. 构建发布版本

```bash
# Android APK
flutter build apk --release
```

## 使用指南

### VPN 模式（推荐）

1. 启动应用
2. 点击「启动代理」
3. 授予 VPN 权限
4. 应用自动捕获所有流量

### 手动代理模式

1. 启动应用
2. 点击「启动代理」
3. 在设备 WiFi 设置中配置代理：
   - 服务器：当前 WiFi IP
   - 端口：8888

### 安装 CA 证书

1. 进入设置页面
2. 点击「安装 CA 证书」
3. 按照提示在系统设置中安装
4. 信任证书用于 HTTPS 解密

## Android 配置

### 权限说明

已在 `android/app/src/main/AndroidManifest.xml` 中配置:

- `INTERNET` - 网络访问
- `BIND_VPN_SERVICE` - VPN 服务
- `ACCESS_NETWORK_STATE` - 网络状态
- `FOREGROUND_SERVICE` - 前台服务
- `POST_NOTIFICATIONS` - 通知权限

### VPN 服务

`VpnService.kt` 实现以下功能:
- 创建 TUN 设备捕获网络流量
- 转发流量到本地代理服务器
- 通过 Platform Channel 与 Flutter 通信
- SSL 证书生成和管理
- TCP/UDP 数据包解析和转发
- DNS 查询域名解析
- 连接状态跟踪

## 技术架构

```
┌─────────────────────────────────────────┐
│         Flutter UI Layer                │
│  (HomePage, CaptureList, Settings)      │
├─────────────────────────────────────────┤
│         flutter_redux 状态管理           │
├─────────────────────────────────────────┤
│     ProxyServiceManager                 │
│  (统一代理服务接口)                       │
├─────────────────────────────────────────┤
│  ┌─────────────┐  ┌──────────────────┐ │
│  │ HttpProxy   │  │  MitmProxy       │ │
│  │ Server      │  │  (HTTPS 解密)      │ │
│  └─────────────┘  └──────────────────┘ │
├─────────────────────────────────────────┤
│  ┌─────────────┐  ┌──────────────────┐ │
│  │ VpnService  │  │  SslInterceptor  │ │
│  │ (Android)   │  │  (Android)       │ │
│  │             │  │                  │ │
│  │ - TcpForwarder  │  TunDeviceWriter │ │
│  │ - UdpForwarder  │  ConnectionTracker││
│  │ - DnsResolver   │                  │ │
│  └─────────────┘  └──────────────────┘ │
├─────────────────────────────────────────┤
│     SQLite (Traffic Storage)            │
└─────────────────────────────────────────┘
```

## 核心组件

### Flutter 端

- `lib/core/proxy_service.dart` - 统一代理服务接口
- `lib/core/platform_channel.dart` - Platform Channel 通信
- `lib/core/proxy/http_proxy_server.dart` - HTTP 代理服务器
- `lib/core/ssl/mitm_proxy.dart` - MITM 代理服务器
- `lib/core/ssl/certificate_manager.dart` - CA 证书管理

### Android 端

- `VpnService.kt` - VPN 服务，TUN 设备创建和流量捕获
- `SslInterceptor.kt` - 原生 SSL 拦截器，证书生成（Bouncy Castle）
- `MainActivity.kt` - Flutter Activity，Platform Channel 桥接
- `TcpForwarder.kt` - TCP 数据包转发到 SOCKS5 代理
- `UdpForwarder.kt` - UDP 数据包转发，DNS 查询处理
- `TunDeviceWriter.kt` - TUN 设备写回，IP 包构建
- `DnsResolver.kt` - DNS 解析和缓存
- `ConnectionTracker.kt` - TCP 连接状态跟踪
- `ProxyForegroundService.kt` - 前台服务保活

## 已知限制

1. **TCP 状态机** - 使用简化实现，序列号/确认号未完全处理
2. **SOCKS5 UDP ASSOCIATE** - 使用直接转发模式，未完整实现 UDP 关联
3. **证书安装** - 需要用户手动在系统设置中安装 CA 证书
4. **性能优化** - 大流量下的内存管理和连接池有待优化

## 下一步计划

### P1 功能（优先级高）

- [ ] TCP 状态机 - 完善序列号/确认号处理
- [ ] SOCKS5 UDP ASSOCIATE - 完整实现 UDP 关联
- [ ] 证书自动安装（Android KeyChain API）
- [ ] 请求/响应详情页

### P2 功能（次要优先级）

- [ ] 流量统计 - 按连接统计上传/下载
- [ ] 连接池 - 复用代理连接减少延迟
- [ ] 性能优化 - 动态缓冲区、内存管理
- [ ] 流量分析图表
- [ ] 高级过滤（正则、多条件）
- [ ] 导出功能（HAR、PCAP）
- [ ] 脚本系统（请求重写）

## 注意事项

⚠️ **重要**: 本项目需要安装 Flutter SDK 才能编译运行。

如未安装 Flutter，请按照官方文档安装:
https://docs.flutter.dev/get-started/install

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request!

## 相关文档

- [P0 功能实现总结](docs/P0 功能实现总结.md)
- [Android Platform Channel 实现总结](docs/Android%20Platform%20Channel 实现总结.md)
- [Bouncy Castle 和 TCP 转发实现总结](docs/Bouncy%20Castle%20和%20TCP%20转发实现总结.md)
- [UDP 转发和 TUN 设备写回实现总结](docs/UDP%20转发和%20TUN%20设备写回实现总结.md)
- [响应数据写回集成实现总结](docs/响应数据写回集成实现总结.md)
- [快速开始指南](docs/快速开始指南.md)
