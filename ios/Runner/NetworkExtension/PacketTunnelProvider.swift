import NetworkExtension

/// iOS NetworkExtension 包隧道提供者
class PacketTunnelProvider: NEPacketTunnelProvider {
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // 启动隧道
        print("Starting packet tunnel...")
        
        // TODO: 配置隧道设置
        // 1. 设置网络配置
        // 2. 启动代理服务器
        // 3. 开始捕获流量
        
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // 停止隧道
        print("Stopping packet tunnel...")
        
        // TODO: 清理资源
        // 1. 停止代理服务器
        // 2. 保存数据
        
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // 处理来自 App 的消息
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // 系统进入睡眠前调用
        completionHandler()
    }
    
    override func wake() {
        // 系统从睡眠中唤醒时调用
    }
}
