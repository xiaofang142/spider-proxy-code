package com.spiderproxy.spider_proxy

import android.util.Log
import kotlinx.coroutines.*
import java.net.DatagramPacket
import java.net.DatagramSocket
import java.net.InetSocketAddress
import java.util.concurrent.ConcurrentHashMap

/**
 * UDP 转发器
 *
 * 处理 UDP 数据包转发到 SOCKS5 代理服务器
 * 支持 DNS 查询等 UDP 流量
 *
 * 注意：SOCKS5 UDP 关联 (UDP ASSOCIATE) 实现较为复杂，
 * 这里使用简化的直接转发方式
 */
class UdpForwarder(
    private val proxyAddress: String,
    private val proxyPort: Int,
    private val vpnScope: CoroutineScope,
    private val tunDeviceWriter: TunDeviceWriter? = null
) {
    companion object {
        private const val TAG = "SpiderProxy.UdpForwarder"
        private const val BUFFER_SIZE = 65535 // UDP 最大包大小
        private const val CONNECTION_TIMEOUT = 10000L // 10 seconds
        private const val IDLE_TIMEOUT = 60000L // 60 seconds
    }

    // UDP 连接管理
    private val udpConnections = ConcurrentHashMap<Int, UdpConnection>()
    private var isRunning = true

    /// 处理 UDP 数据包
    suspend fun handleUdpPacket(
        srcAddress: String,
        srcPort: Int,
        destAddress: String,
        destPort: Int,
        packet: ByteArray,
        packetSize: Int
    ) {
        val connectionId = generateConnectionId(srcAddress, srcPort, destAddress, destPort)

        // 获取或创建 UDP 连接
        var connection = udpConnections[connectionId]
        if (connection == null) {
            connection = createUdpConnection(
                connectionId = connectionId,
                srcAddress = srcAddress,
                srcPort = srcPort,
                destAddress = destAddress,
                destPort = destPort
            )
            udpConnections[connectionId] = connection

            // 启动连接
            vpnScope.launch {
                try {
                    connection.start()
                    Log.d(TAG, "New UDP connection created: $connectionId")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start UDP connection: $connectionId", e)
                    removeConnection(connectionId)
                }
            }
        }

        // 发送数据
        connection?.sendData(packet, packetSize)
    }

    /// 创建 UDP 连接
    private fun createUdpConnection(
        connectionId: Int,
        srcAddress: String,
        srcPort: Int,
        destAddress: String,
        destPort: Int
    ): UdpConnection {
        return UdpConnection(
            connectionId = connectionId,
            srcAddress = srcAddress,
            srcPort = srcPort,
            destAddress = destAddress,
            destPort = destPort,
            proxyAddress = proxyAddress,
            proxyPort = proxyPort,
            vpnScope = vpnScope,
            onConnectionClosed = { removeConnection(connectionId) },
            tunDeviceWriter = tunDeviceWriter
        )
    }

    /// 移除连接
    private fun removeConnection(connectionId: Int) {
        udpConnections.remove(connectionId)?.close()
        Log.d(TAG, "UDP connection removed: $connectionId")
    }

    /// 生成连接 ID
    private fun generateConnectionId(srcAddress: String, srcPort: Int, destAddress: String, destPort: Int): Int {
        return (srcAddress.hashCode() + srcPort + destAddress.hashCode() + destPort).absoluteValue
    }

    /// 关闭所有连接
    fun close() {
        isRunning = false
        udpConnections.values.forEach { it.close() }
        udpConnections.clear()
        Log.d(TAG, "UdpForwarder closed, ${udpConnections.size} connections cleaned up")
    }

    /// 获取活跃连接数
    fun getActiveConnectionCount(): Int = udpConnections.size
}

/**
 * UDP 连接
 *
 * 管理单个 UDP 连接的双向数据转发
 */
class UdpConnection(
    private val connectionId: Int,
    private val srcAddress: String,
    private val srcPort: Int,
    private val destAddress: String,
    private val destPort: Int,
    private val proxyAddress: String,
    private val proxyPort: Int,
    private val vpnScope: CoroutineScope,
    private val onConnectionClosed: (Int) -> Unit,
    private val tunDeviceWriter: TunDeviceWriter? = null
) {
    companion object {
        private const val TAG = "SpiderProxy.UdpConnection"
    }

    private var socket: DatagramSocket? = null
    private val dynamicBuffer = DynamicBuffer()
    private var isConnected = false
    private var connectionScope: CoroutineScope? = null
    private var lastActivityTime = System.currentTimeMillis()

    // 连接状态
    enum class State {
        CONNECTING,
        CONNECTED,
        CLOSING,
        CLOSED
    }

    private var state = State.CONNECTING

    /// 启动连接
    suspend fun start() {
        try {
            withTimeout(UdpForwarder.CONNECTION_TIMEOUT) {
                // 1. 创建 UDP Socket
                socket = DatagramSocket()
                socket?.reuseAddress = true
                socket?.soTimeout = UdpForwarder.IDLE_TIMEOUT.toInt()

                // 2. 连接到代理服务器（简化实现：直接连接到目标）
                // 注意：完整的 SOCKS5 UDP ASSOCIATE 需要额外的握手步骤
                // 这里为了简化，直接连接到目标地址

                isConnected = true
                state = State.CONNECTED
                lastActivityTime = System.currentTimeMillis()

                Log.d(TAG, "UDP connection $connectionId established")

                // 3. 启动数据转发
                connectionScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
                connectionScope?.launch {
                    forwardData()
                }

                connectionScope?.launch {
                    monitorIdle()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to establish UDP connection $connectionId", e)
            state = State.CLOSED
            onConnectionClosed(connectionId)
        }
    }

    /// 发送数据到目标
    fun sendData(packet: ByteArray, size: Int) {
        if (!isConnected || state != State.CONNECTED) {
            Log.w(TAG, "Cannot send UDP data, connection not ready: $connectionId")
            return
        }

        try {
            vpnScope.launch {
                try {
                    val targetAddress = InetSocketAddress(destAddress, destPort)
                    val datagram = DatagramPacket(packet, size, targetAddress)
                    socket?.send(datagram)

                    lastActivityTime = System.currentTimeMillis()
                    Log.d(TAG, "UDP sent ${size} bytes to $destAddress:$destPort")
                } catch (e: Exception) {
                    Log.e(TAG, "Error sending UDP data for $connectionId", e)
                    close()
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error in sendData for $connectionId", e)
        }
    }

    /// 转发数据
    private suspend fun forwardData() {
        try {
            while (isConnected && state == State.CONNECTED) {
                try {
                    // 使用动态缓冲区
                    val buffer = dynamicBuffer.getBuffer()
                    val packet = DatagramPacket(buffer.array(), buffer.capacity())
                    socket?.receive(packet)

                    val bytesRead = packet.length
                    if (bytesRead > 0) {
                        lastActivityTime = System.currentTimeMillis()

                        // 调整缓冲区大小
                        dynamicBuffer.adjust(bytesRead, isOverflow = bytesRead >= buffer.capacity())

                        // 将响应写回 TUN 设备
                        val data = packet.data.copyOf(bytesRead)
                        tunDeviceWriter?.writeUdpResponse(
                            udpData = data,
                            srcAddress = destAddress,
                            srcPort = destPort,
                            destAddress = srcAddress,
                            destPort = srcPort
                        ) ?: run {
                            // 简化实现：仅记录
                            Log.d(TAG, "UDP received ${bytesRead} bytes from $destAddress:$destPort")
                        }
                    }
                } catch (e: java.net.SocketTimeoutException) {
                    // 超时，检查是否应该关闭
                    if (System.currentTimeMillis() - lastActivityTime > UdpForwarder.IDLE_TIMEOUT) {
                        Log.d(TAG, "UDP connection $connectionId idle timeout")
                        break
                    }
                } catch (e: Exception) {
                    if (state == State.CONNECTED) {
                        Log.e(TAG, "Error receiving UDP data for $connectionId", e)
                    }
                    break
                }
            }
        } catch (e: CancellationException) {
            Log.d(TAG, "UDP forward task cancelled for $connectionId")
        } finally {
            close()
        }
    }

    /// 监控空闲连接
    private suspend fun monitorIdle() {
        while (isConnected && state == State.CONNECTED) {
            delay(UdpForwarder.IDLE_TIMEOUT / 2)

            if (System.currentTimeMillis() - lastActivityTime > UdpForwarder.IDLE_TIMEOUT) {
                Log.d(TAG, "UDP connection $connectionId idle timeout, closing")
                break
            }
        }
        close()
    }

    /// 关闭连接
    fun close() {
        if (state == State.CLOSED || state == State.CLOSING) return

        state = State.CLOSING
        isConnected = false

        try {
            socket?.close()
            connectionScope?.cancel()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing UDP connection $connectionId", e)
        } finally {
            state = State.CLOSED
            onConnectionClosed(connectionId)
            Log.d(TAG, "UDP connection $connectionId closed")
        }
    }
}

/**
 * DNS 解析器
 *
 * 专门处理 DNS 查询和响应
 */
class DnsResolver(private val dnsServer: String = "8.8.8.8") {
    companion object {
        private const val TAG = "SpiderProxy.DnsResolver"
        private const val DNS_PORT = 53
    }

    private val dnsCache = ConcurrentHashMap<String, CachedDnsResponse>()

    /// 解析域名
    suspend fun resolve(domain: String): String? {
        // 检查缓存
        val cached = dnsCache[domain]
        if (cached != null && !cached.isExpired) {
            Log.d(TAG, "DNS cache hit for $domain")
            return cached.ipAddress
        }

        return try {
            withTimeout(5000) {
                // 使用 Java InetAddress 解析
                val addresses = java.net.InetAddress.getAllByName(domain)
                if (addresses.isNotEmpty()) {
                    val ip = addresses[0].hostAddress
                    // 缓存 DNS 响应
                    dnsCache[domain] = CachedDnsResponse(
                        ipAddress = ip!!,
                        expires = System.currentTimeMillis() + 300000 // 5 分钟
                    )
                    Log.d(TAG, "DNS resolved: $domain -> $ip")
                    ip
                } else {
                    null
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "DNS resolution failed for $domain", e)
            null
        }
    }

    /// 清除缓存
    fun clearCache() {
        dnsCache.clear()
        Log.d(TAG, "DNS cache cleared")
    }

    /// 缓存的 DNS 响应
    private data class CachedDnsResponse(
        val ipAddress: String,
        val expires: Long
    ) {
        fun isExpired(): Boolean = System.currentTimeMillis() > expires
    }
}
