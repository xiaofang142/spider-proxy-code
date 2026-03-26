package com.spiderproxy.spider_proxy

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.net.VpnService
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.FileInputStream
import java.io.FileOutputStream
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import kotlinx.coroutines.*

/**
 * Spider Proxy VPN 服务
 *
 * 功能：
 * 1. 创建 TUN 设备捕获网络流量
 * 2. 转发流量到本地代理服务器
 * 3. 通过 Platform Channel 与 Flutter 通信
 */
class VpnService : Service() {
    companion object {
        private const val TAG = "SpiderProxy.VpnService"
        private const val NOTIFICATION_CHANNEL_ID = "spider_proxy_vpn_channel"
        private const val NOTIFICATION_ID = 1001

        // TUN 设备配置
        private const val VPN_ADDRESS = "10.0.0.1"
        private const val VPN_SUBNET_MASK = "255.255.255.0"
        private const val VPN_DNS = "8.8.8.8"
        private const val VPN_MTU = 1500

        // 代理服务器配置
        private const val PROXY_PORT = 8888
        private const val PROXY_ADDRESS = "127.0.0.1"

        // Method Channel 名称
        private const val CHANNEL_NAME = "com.spiderproxy/vpn"
    }

    private val binder = LocalBinder()
    private var methodChannel: MethodChannel? = null
    private var vpnInterface: ParcelFileDescriptor? = null
    private var vpnScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private lateinit var sslInterceptor: SslInterceptor
    private lateinit var tcpForwarder: TcpForwarder
    private lateinit var udpForwarder: UdpForwarder
    private lateinit var dnsResolver: DnsResolver
    private lateinit var tunDeviceWriter: TunDeviceWriter
    private lateinit var connectionTracker: ConnectionTracker
    private lateinit var dynamicBuffer: DynamicBuffer

    // 流量统计
    private var bytesSent = 0L
    private var bytesReceived = 0L

    // 服务状态
    var isRunning = false
        private set

    /// 获取 SSL 拦截器（供 MainActivity 使用）
    fun getSslInterceptor(): SslInterceptor = sslInterceptor

    inner class LocalBinder : Binder() {
        fun getService(): VpnService = this@VpnService
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "VpnService onCreate")
        createNotificationChannel()

        // 初始化 SSL 拦截器（传入 Context 用于 KeyStore）
        val certsDir = filesDir.resolve("certificates")
        sslInterceptor = SslInterceptor(certsDir, applicationContext)
        sslInterceptor.initialize()

        // 初始化 TCP 转发器
        tcpForwarder = TcpForwarder(PROXY_ADDRESS, PROXY_PORT, vpnScope, tunDeviceWriter)

        // 初始化 UDP 转发器
        udpForwarder = UdpForwarder(PROXY_ADDRESS, PROXY_PORT, vpnScope, tunDeviceWriter)

        // 初始化 DNS 解析器
        dnsResolver = DnsResolver(VPN_DNS)

        // 初始化 TUN 设备写入器
        tunDeviceWriter = TunDeviceWriter(vpnScope)

        // 初始化连接跟踪器
        connectionTracker = ConnectionTracker()

        // 初始化动态缓冲区
        dynamicBuffer = DynamicBuffer()
    }

    override fun onBind(intent: Intent?): IBinder {
        Log.d(TAG, "VpnService onBind")
        return binder
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "VpnService onStartCommand")
        startForeground(NOTIFICATION_ID, createNotification())
        return START_STICKY
    }

    override fun onDestroy() {
        Log.d(TAG, "VpnService onDestroy")

        // 记录动态缓冲区统计信息
        val bufferStats = dynamicBuffer.getStats()
        Log.d(TAG, "Dynamic buffer final stats: $bufferStats")

        // 记录连接池统计信息
        val tcpPoolStats = tcpForwarder.getPoolStats()
        Log.d(TAG, "TCP connection pool final stats: $tcpPoolStats")

        stopVpn()
        vpnScope.cancel()
        sslInterceptor.stop()
        tcpForwarder.close()
        udpForwarder.close()
        tunDeviceWriter.close()
        super.onDestroy()
    }

    /// 设置 MethodChannel（由 FlutterActivity 调用）
    fun setupMethodChannel(engine: FlutterEngine) {
        methodChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startVpn" -> startVpn(call.arguments as? Map<*, *>, result)
                "stopVpn" -> stopVpn(result)
                "getStatus" -> getStatus(result)
                "getTrafficStats" -> getTrafficStats(result)
                "installCertificate" -> installCertificate(result)
                "uninstallCertificate" -> uninstallCertificate(result)
                "isCertificateInstalled" -> isCertificateInstalled(result)
                "getCertificateInfo" -> getCertificateInfo(result)
                else -> result.notImplemented()
            }
        }
    }

    /// 安装证书（触发系统安装界面）
    private fun installCertificate(result: MethodChannel.Result) {
        vpnScope.launch {
            try {
                val certBytes = sslInterceptor.getCACertificateBytes()
                if (certBytes == null) {
                    result.error("CERT_NOT_FOUND", "CA certificate not found", null)
                    return@launch
                }

                // 创建证书文件用于系统安装
                val tempCertFile = File(cacheDir, "spider_proxy_ca.crt")
                FileOutputStream(tempCertFile).use { fos ->
                    fos.write(certBytes)
                }

                // 触发系统证书安装界面
                val intent = android.content.Intent(android.content.Intent.ACTION_VIEW)
                intent.setDataAndType(
                    android.net.Uri.fromFile(tempCertFile),
                    "application/x-x509-ca-cert"
                )
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                applicationContext.startActivity(intent)

                Log.d(TAG, "Certificate installation intent launched")
                result.success(true)
            } catch (e: Exception) {
                Log.e(TAG, "Error installing certificate", e)
                result.error("INSTALL_FAILED", e.message, null)
            }
        }
    }

    /// 卸载证书
    private fun uninstallCertificate(result: MethodChannel.Result) {
        vpnScope.launch {
            try {
                val success = sslInterceptor.uninstallCertificate()
                if (success) {
                    Log.d(TAG, "Certificate uninstalled successfully")
                    result.success(true)
                } else {
                    result.error("UNINSTALL_FAILED", "Failed to uninstall certificate", null)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error uninstalling certificate", e)
                result.error("UNINSTALL_FAILED", e.message, null)
            }
        }
    }

    /// 检查证书是否已安装
    private fun isCertificateInstalled(result: MethodChannel.Result) {
        try {
            val installed = sslInterceptor.isCertificateInstalled()
            result.success(installed)
        } catch (e: Exception) {
            Log.e(TAG, "Error checking certificate status", e)
            result.success(false)
        }
    }

    /// 获取证书信息
    private fun getCertificateInfo(result: MethodChannel.Result) {
        try {
            val info = sslInterceptor.getCertificateValidityInfo()
            result.success(info)
        } catch (e: Exception) {
            Log.e(TAG, "Error getting certificate info", e)
            result.error("GET_INFO_FAILED", e.message, null)
        }
    }

    /// 启动 VPN
    private fun startVpn(args: Map<*, *>?, result: MethodChannel.Result) {
        if (isRunning) {
            result.error("ALREADY_RUNNING", "VPN is already running", null)
            return
        }

        val port = (args?.get("port") as? Int) ?: PROXY_PORT
        val proxyAddress = (args?.get("proxyAddress") as? String) ?: PROXY_ADDRESS

        vpnScope.launch {
            try {
                // 1. 配置并建立 VPN 连接
                val vpnBuilder = VpnService.Builder()
                    .addAddress(VPN_ADDRESS, 24)
                    .addDnsServer(VPN_DNS)
                    .setMtu(VPN_MTU)
                    .setBlocking(false)
                    .setSession("Spider Proxy")

                // 添加路由（捕获所有流量）
                vpnBuilder.addRoute("0.0.0.0", 0)

                // 添加允许的应用包名（可选）
                // vpnBuilder.addAllowedApplication(packageName)

                // 2. 建立连接
                vpnInterface = vpnBuilder.establish()

                if (vpnInterface == null) {
                    result.error("VPN_ESTABLISH_FAILED", "Failed to establish VPN connection", null)
                    return@launch
                }

                Log.d(TAG, "VPN established: $VPN_ADDRESS/$VPN_SUBNET_MASK")

                // 3. 初始化 TUN 设备写入器
                tunDeviceWriter.initialize(vpnInterface!!)

                // 4. 启动流量转发线程
                launch { forwardTraffic() }

                isRunning = true
                sendStatusToFlutter("connected")
                result.success(true)

                Log.d(TAG, "VPN started successfully")
                Log.d(TAG, "Dynamic buffer initialized: initial=${DynamicBuffer.INITIAL_BUFFER_SIZE_KB}KB, max=${DynamicBuffer.MAX_BUFFER_SIZE_KB}KB")

            } catch (e: Exception) {
                Log.e(TAG, "Error starting VPN", e)
                sendStatusToFlutter("error")
                result.error("START_FAILED", e.message, null)
            }
        }
    }

    /// 停止 VPN
    private fun stopVpn(result: MethodChannel.Result? = null) {
        if (!isRunning) {
            result?.success(true)
            return
        }

        vpnScope.launch {
            try {
                Log.d(TAG, "Stopping VPN...")

                // 关闭 TUN 接口
                vpnInterface?.close()
                vpnInterface = null

                isRunning = false
                bytesSent = 0L
                bytesReceived = 0L

                sendStatusToFlutter("disconnected")
                Log.d(TAG, "VPN stopped")

                result?.success(true)

            } catch (e: Exception) {
                Log.e(TAG, "Error stopping VPN", e)
                result?.error("STOP_FAILED", e.message, null)
            }
        }
    }

    /// 转发流量
    private suspend fun forwardTraffic() {
        val vpnFd = vpnInterface ?: return

        val inputStream = FileInputStream(vpnFd.fileDescriptor)
        val outputStream = FileOutputStream(vpnFd.fileDescriptor)

        Log.d(TAG, "Starting traffic forwarding with dynamic buffer")

        try {
            while (isRunning) {
                try {
                    // 使用动态缓冲区
                    val buffer = dynamicBuffer.getBuffer()

                    // 读取数据包
                    val packetSize = inputStream.read(buffer.array())
                    if (packetSize <= 0) {
                        continue
                    }

                    // 检查缓冲区使用情况并调整
                    dynamicBuffer.adjust(packetSize, isOverflow = packetSize >= buffer.capacity())

                    buffer.limit(packetSize)
                    bytesSent += packetSize

                    // 解析 IP 包头部
                    val ipHeader = buffer.array().copyOfRange(0, packetSize)
                    val protocol = ipHeader[9].toInt() and 0xFF

                    // 处理 TCP/UDP 包
                    when (protocol) {
                        6 -> handleTcpPacket(buffer.array(), packetSize, outputStream)
                        17 -> handleUdpPacket(buffer.array(), packetSize)
                    }

                    buffer.clear()

                } catch (e: Exception) {
                    if (isRunning) {
                        Log.e(TAG, "Error forwarding packet", e)
                    }
                }
            }
        } finally {
            inputStream.close()
            outputStream.close()
        }
    }

    /// 处理 TCP 数据包
    private suspend fun handleTcpPacket(packet: ByteArray, size: Int, outputStream: FileOutputStream) {
        vpnScope.launch {
            try {
                // 提取 IP 头部信息
                val ipHeader = packet.copyOfRange(0, 20)
                val destAddress = packet.sliceArray(16..19).joinToString(".") {
                    (it.toInt() and 0xFF).toString()
                }
                val srcAddress = packet.sliceArray(12..15).joinToString(".") {
                    (it.toInt() and 0xFF).toString()
                }

                // TCP 头部从 IP 头部结束位置开始（IP 头部长度在第 1 个字节的低 4 位）
                val ipHeaderLength = (ipHeader[0].toInt() and 0x0F) * 4
                val tcpHeaderStart = ipHeaderLength

                if (packet.size <= tcpHeaderStart + 12) {
                    return@launch
                }

                // 提取 TCP 头部信息
                val destPort = ((packet[tcpHeaderStart + 2].toInt() and 0xFF) shl 8) or
                               (packet[tcpHeaderStart + 3].toInt() and 0xFF)
                val srcPort = ((packet[tcpHeaderStart].toInt() and 0xFF) shl 8) or
                              (packet[tcpHeaderStart + 1].toInt() and 0xFF)

                Log.d(TAG, "TCP packet: $srcAddress:$srcPort -> $destAddress:$destPort (${size} bytes)")
                bytesReceived += size

                // 使用 TcpForwarder 转发到代理服务器
                tcpForwarder.handleTcpPacket(
                    srcAddress = srcAddress,
                    srcPort = srcPort,
                    destAddress = destAddress,
                    destPort = destPort,
                    packet = packet,
                    packetSize = size
                )

            } catch (e: Exception) {
                Log.e(TAG, "Error handling TCP packet", e)
            }
        }
    }

    /// 处理 UDP 数据包
    private suspend fun handleUdpPacket(packet: ByteArray, size: Int) {
        vpnScope.launch {
            try {
                // 提取 IP 头部信息
                val ipHeader = packet.copyOfRange(0, 20)
                val destAddress = packet.sliceArray(16..19).joinToString(".") {
                    (it.toInt() and 0xFF).toString()
                }
                val srcAddress = packet.sliceArray(12..15).joinToString(".") {
                    (it.toInt() and 0xFF).toString()
                }

                // UDP 头部从 IP 头部结束位置开始
                val ipHeaderLength = (ipHeader[0].toInt() and 0x0F) * 4
                val udpHeaderStart = ipHeaderLength

                if (packet.size <= udpHeaderStart + 4) {
                    return@launch
                }

                // 提取 UDP 头部信息
                val destPort = ((packet[udpHeaderStart + 2].toInt() and 0xFF) shl 8) or
                               (packet[udpHeaderStart + 3].toInt() and 0xFF)
                val srcPort = ((packet[udpHeaderStart].toInt() and 0xFF) shl 8) or
                              (packet[udpHeaderStart + 1].toInt() and 0xFF)

                Log.d(TAG, "UDP packet: $srcAddress:$srcPort -> $destAddress:$destPort (${size} bytes)")
                bytesReceived += size

                // 特殊处理 DNS 查询 (UDP 53 端口)
                if (destPort == 53) {
                    // 解析 DNS 查询中的域名
                    val domain = parseDnsQuery(packet, ipHeaderLength + 8, size - ipHeaderLength - 8)
                    if (domain != null) {
                        Log.d(TAG, "DNS query for: $domain")
                    }
                }

                // 使用 UdpForwarder 转发
                udpForwarder.handleUdpPacket(
                    srcAddress = srcAddress,
                    srcPort = srcPort,
                    destAddress = destAddress,
                    destPort = destPort,
                    packet = packet,
                    packetSize = size
                )

            } catch (e: Exception) {
                Log.e(TAG, "Error handling UDP packet", e)
            }
        }
    }

    /// 解析 DNS 查询中的域名
    private fun parseDnsQuery(packet: ByteArray, offset: Int, length: Int): String? {
        if (length < 12) return null // DNS 头部最小长度

        try {
            val builder = StringBuilder()
            var pos = offset + 12 // 跳过 DNS 头部
            var labelLength = 0

            while (pos < packet.size) {
                labelLength = packet[pos].toInt() and 0xFF
                if (labelLength == 0) break

                pos++
                for (i in 0 until labelLength) {
                    if (pos >= packet.size) break
                    builder.append(packet[pos].toInt().toChar())
                    pos++
                }
                if (packet[pos].toInt() and 0xFF != 0) {
                    builder.append('.')
                }
            }

            return builder.toString()
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing DNS query", e)
            return null
        }
    }

    /// 获取 VPN 状态
    private fun getStatus(result: MethodChannel.Result) {
        val status = mapOf(
            "isRunning" to isRunning,
            "vpnAddress" to VPN_ADDRESS,
            "proxyAddress" to PROXY_ADDRESS,
            "proxyPort" to PROXY_PORT
        )
        result.success(status)
    }

    /// 获取流量统计
    private fun getTrafficStats(result: MethodChannel.Result) {
        val stats = mapOf(
            "bytesSent" to bytesSent,
            "bytesReceived" to bytesReceived
        )
        result.success(stats)
    }

    /// 发送状态到 Flutter
    private fun sendStatusToFlutter(status: String) {
        methodChannel?.invokeMethod("onVpnStatusChanged", mapOf(
            "status" to status,
            "isRunning" to isRunning,
            "bytesSent" to bytesSent,
            "bytesReceived" to bytesReceived
        ))
    }

    /// 创建通知渠道
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "VPN 服务",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Spider Proxy VPN 服务运行中"
                setShowBadge(false)
            }

            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    /// 创建前台服务通知
    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setContentTitle("Spider Proxy")
            .setContentText("VPN 服务运行中")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
