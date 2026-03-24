# iOS NetworkExtension 配置说明

## 文件说明

- `PacketTunnelProvider.swift` - 包隧道提供者实现
- `PacketTunnelProvider.entitlements` - 扩展的权限配置
- `Runner.entitlements` - 主 App 的权限配置

## 配置步骤

### 1. 创建 Network Extension Target

在 Xcode 中:
1. File → New → Target
2. 选择 "Packet Tunnel Provider"
3. 命名为 "SpiderProxyNetworkExtension"
4. Bundle ID: `com.spiderproxy.spider-proxy.NetworkExtension`

### 2. 配置 Entitlements

确保主 App 和 Extension 都包含:
- `com.apple.security.application-groups`
- `keychain-access-groups`

### 3. 配置 Info.plist

在 Extension 的 Info.plist 中添加:
```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.networkextension.packet-tunnel</string>
    <key>NSExtensionPrincipalClass</key>
    <string>$(PRODUCT_MODULE_NAME).PacketTunnelProvider</string>
</dict>
```

### 4. 启用 Capabilities

在 Xcode 中为 App 和 Extension 启用:
- App Groups
- Keychain Sharing
- Network Extensions

## 注意事项

- 需要 Apple Developer 账号才能使用 NetworkExtension
- 真机测试需要配置 Provisioning Profile
- iOS 17+ 可能需要额外的隐私权限说明
