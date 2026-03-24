# Spider Proxy 🕷️

一个基于 Flutter 的网络代理和抓包工具。

## 功能特性

- 🌐 **HTTP/HTTPS 代理** - 支持 HTTP 和 HTTPS 流量捕获
- 🔒 **SSL 解密** - 中间人攻击 (MITM) 解密 HTTPS 流量
- 📱 **跨平台支持** - Android 和 iOS
- 🎯 **智能过滤** - 域名白名单/黑名单，URL 模式匹配
- 📊 **流量监控** - 实时显示上传/下载速度
- 🤖 **AI 分析** - 智能识别请求类型和风险等级
- 💰 **内购支持** - 集成 RevenueCat 订阅系统

## 项目结构

```
lib/
├── main.dart                 # 应用入口
├── core/                     # 核心模块
│   ├── proxy/               # 代理服务器
│   ├── vpn/                 # VPN 服务
│   └── ssl/                 # SSL 拦截
├── features/                 # 功能模块
│   ├── traffic/            # 流量监控
│   ├── filter/             # 请求过滤
│   └── ai/                 # AI 分析
└── ui/                       # 用户界面
    ├── pages/              # 页面
    └── widgets/            # 组件
```

## 依赖说明

| 依赖 | 用途 |
|------|------|
| http_proxy | HTTP 代理服务器实现 |
| flutter_redux | 状态管理 |
| sqflite | 本地 SQLite 数据库 |
| permission_handler | 权限管理 |
| flutter_network_profiler | 网络监控 |
| purchases_flutter | RevenueCat 内购 |

## 开发环境要求

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio / Xcode
- Android minSdkVersion: 21
- iOS: 13.0+

## 快速开始

### 1. 安装依赖

```bash
flutter pub get
```

### 2. 运行应用

```bash
# Android
flutter run

# iOS
flutter run -d <device_id>
```

### 3. 构建发布版本

```bash
# Android APK
flutter build apk --release

# iOS
flutter build ios --release
```

## Android 配置

### 权限说明

已在 `android/app/src/main/AndroidManifest.xml` 中配置:

- `INTERNET` - 网络访问
- `BIND_VPN_SERVICE` - VPN 服务
- `ACCESS_NETWORK_STATE` - 网络状态
- `FOREGROUND_SERVICE` - 前台服务

## iOS 配置

### NetworkExtension

1. 在 Xcode 中添加 Network Extension Target
2. 配置 Packet Tunnel Provider
3. 启用 App Groups 和 Keychain Sharing
4. 配置 Entitlements

详见 `ios/Runner/NetworkExtension/README.md`

## 注意事项

⚠️ **重要**: 本项目需要安装 Flutter SDK 才能编译运行。

如未安装 Flutter，请按照官方文档安装:
https://docs.flutter.dev/get-started/install

## 许可证

MIT License

## 贡献

欢迎提交 Issue 和 Pull Request!
