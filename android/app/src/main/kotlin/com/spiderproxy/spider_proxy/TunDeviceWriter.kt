package com.spiderproxy.spider_proxy

import android.os.ParcelFileDescriptor
import android.util.Log
import kotlinx.coroutines.*
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.util.concurrent.ConcurrentHashMap

/**
 * TUN 设备写入器
 *
 * 负责将代理响应数据写回 TUN 设备
 * 完成完整的双向流量处理
 */
class TunDeviceWriter(
    private val vpnScope: CoroutineScope
) {
    companion object {
        private const val TAG = "SpiderProxy.TunDeviceWriter"
        private const val BUFFER_SIZE = 16384 // 16KB
        private const val WRITE_TIMEOUT = 5000L // 5 seconds
    }

    private var tunOutputStream: FileOutputStream? = null
    private val writeBuffer = ByteBuffer.allocate(BUFFER_SIZE)
    private val pendingWrites = mutableListOf<PendingWrite>()

    /// 待写入的数据
    data class PendingWrite(
        val data: ByteArray,
        val offset: Int,
        val length: Int,
        val destAddress: String,
        val destPort: Int,
        val protocol: Int, // TCP=6, UDP=17
        val timestamp: Long = System.currentTimeMillis()
    )

    /// 初始化 TUN 设备写入
    fun initialize(tunFileDescriptor: ParcelFileDescriptor) {
        try {
            tunOutputStream = FileOutputStream(tunFileDescriptor.fileDescriptor)
            Log.d(TAG, "TUN device writer initialized")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize TUN writer", e)
        }
    }

    /// 写入数据到 TUN 设备
    fun write(
        data: ByteArray,
        offset: Int,
        length: Int,
        destAddress: String,
        destPort: Int,
        protocol: Int
    ) {
        vpnScope.launch {
            try {
                withTimeout(WRITE_TIMEOUT) {
                    // 构建 IP 包头部
                    val ipPacket = buildIpPacket(
                        data = data,
                        offset = offset,
                        length = length,
                        destAddress = destAddress,
                        protocol = protocol
                    )

                    // 写入 TUN 设备
                    tunOutputStream?.write(ipPacket)
                    tunOutputStream?.flush()

                    Log.d(TAG, "Wrote ${ipPacket.size} bytes to TUN device")
                }
            } catch (e: TimeoutCancellationException) {
                Log.e(TAG, "Timeout writing to TUN device")
            } catch (e: Exception) {
                Log.e(TAG, "Error writing to TUN device", e)
            }
        }
    }

    /// 构建 IP 数据包
    private fun buildIpPacket(
        data: ByteArray,
        offset: Int,
        length: Int,
        destAddress: String,
        protocol: Int
    ): ByteArray {
        // 解析源地址和目标地址
        val srcIp = parseIpAddress(destAddress)
        val destIp = intArrayOf(10, 0, 0, 1) // VPN 地址

        // IP 头部长度 (20 字节 for IPv4 without options)
        val ipHeaderLength = 20

        // TCP/UDP 头部长度
        val transportHeaderLength = when (protocol) {
            6 -> 20 // TCP
            17 -> 8 // UDP
            else -> 0
        }

        // 总长度
        val totalLength = ipHeaderLength + transportHeaderLength + length

        // 创建 IP 包
        val packet = ByteArray(totalLength)
        var pos = 0

        // IP 头部
        // 版本和头部长度 (4 位版本 +4 位头部长度)
        packet[pos++] = 0x45.toByte() // IPv4, 5 * 4 = 20 bytes header

        // 服务类型 (DSCP + ECN)
        packet[pos++] = 0x00

        // 总长度 (16 位)
        packet[pos++] = ((totalLength shr 8) and 0xFF).toByte()
        packet[pos++] = (totalLength and 0xFF).toByte()

        // 标识 (16 位)
        val identification = System.currentTimeMillis().toInt() and 0xFFFF
        packet[pos++] = ((identification shr 8) and 0xFF).toByte()
        packet[pos++] = (identification and 0xFF).toByte()

        // 标志和分片偏移 (16 位)
        // 0x4000 = Don't Fragment
        packet[pos++] = 0x40
        packet[pos++] = 0x00

        // TTL
        packet[pos++] = 64

        // 协议
        packet[pos++] = protocol.toByte()

        // 头部校验和 (需要计算)
        packet[pos++] = 0x00
        packet[pos++] = 0x00

        // 源地址 (目标服务器地址)
        packet[pos++] = srcIp[0].toByte()
        packet[pos++] = srcIp[1].toByte()
        packet[pos++] = srcIp[2].toByte()
        packet[pos++] = srcIp[3].toByte()

        // 目标地址 (VPN 地址)
        packet[pos++] = destIp[0].toByte()
        packet[pos++] = destIp[1].toByte()
        packet[pos++] = destIp[2].toByte()
        packet[pos++] = destIp[3].toByte()

        // 计算 IP 头部校验和
        val checksum = calculateChecksum(packet, 0, ipHeaderLength)
        packet[10] = ((checksum shr 8) and 0xFF).toByte()
        packet[11] = (checksum and 0xFF).toByte()

        // 复制传输层数据 (TCP/UDP)
        System.arraycopy(data, offset, packet, ipHeaderLength, length)

        return packet
    }

    /// 解析 IP 地址字符串为整数数组
    private fun parseIpAddress(ip: String): IntArray {
        val parts = ip.split(".")
        return intArrayOf(
            parts[0].toInt(),
            parts[1].toInt(),
            parts[2].toInt(),
            parts[3].toInt()
        )
    }

    /// 计算校验和
    private fun calculateChecksum(data: ByteArray, offset: Int, length: Int): Int {
        var sum = 0
        for (i in offset until offset + length step 2) {
            if (i + 1 < length) {
                sum += ((data[i].toInt() and 0xFF) shl 8) or (data[i + 1].toInt() and 0xFF)
            } else {
                sum += (data[i].toInt() and 0xFF) shl 8
            }
        }

        // 折叠 32 位和到 16 位
        while (sum shr 16 != 0) {
            sum = (sum and 0xFFFF) + (sum shr 16)
        }

        // 取反
        return sum.inv() and 0xFFFF
    }

    /// 写入 TCP 响应
    fun writeTcpResponse(
        tcpData: ByteArray,
        srcAddress: String,
        srcPort: Int,
        destAddress: String,
        destPort: Int
    ) {
        write(
            data = tcpData,
            offset = 0,
            length = tcpData.size,
            destAddress = destAddress,
            destPort = destPort,
            protocol = 6 // TCP
        )
    }

    /// 写入 UDP 响应
    fun writeUdpResponse(
        udpData: ByteArray,
        srcAddress: String,
        srcPort: Int,
        destAddress: String,
        destPort: Int
    ) {
        write(
            data = udpData,
            offset = 0,
            length = udpData.size,
            destAddress = destAddress,
            destPort = destPort,
            protocol = 17 // UDP
        )
    }

    /// 关闭写入器
    fun close() {
        try {
            tunOutputStream?.close()
            pendingWrites.clear()
            Log.d(TAG, "TUN device writer closed")
        } catch (e: Exception) {
            Log.e(TAG, "Error closing TUN writer", e)
        }
    }

    /// 获取待处理写入数量
    fun getPendingWriteCount(): Int = pendingWrites.size
}

/**
 * 连接状态跟踪器
 *
 * 跟踪 TCP 连接状态，用于正确的数据转发
 */
class ConnectionTracker {
    companion object {
        private const val TAG = "SpiderProxy.ConnectionTracker"
    }

    private val connections = ConcurrentHashMap<Int, ConnectionInfo>()

    data class ConnectionInfo(
        val srcAddress: String,
        val srcPort: Int,
        val destAddress: String,
        val destPort: Int,
        val state: TcpState,
        val createdAt: Long = System.currentTimeMillis(),
        var lastActivityAt: Long = System.currentTimeMillis(),
        var bytesSent: Long = 0,
        var bytesReceived: Long = 0
    )

    enum class TcpState {
        SYN_SENT,
        SYN_RECEIVED,
        ESTABLISHED,
        FIN_WAIT,
        CLOSED
    }

    /// 获取或创建连接
    fun getOrCreateConnection(
        srcAddress: String,
        srcPort: Int,
        destAddress: String,
        destPort: Int
    ): ConnectionInfo {
        val connectionId = generateConnectionId(srcAddress, srcPort, destAddress, destPort)

        return connections.getOrPut(connectionId) {
            ConnectionInfo(
                srcAddress = srcAddress,
                srcPort = srcPort,
                destAddress = destAddress,
                destPort = destPort,
                state = TcpState.SYN_SENT
            )
        }
    }

    /// 更新连接状态
    fun updateState(
        srcAddress: String,
        srcPort: Int,
        destAddress: String,
        destPort: Int,
        state: TcpState
    ) {
        val connectionId = generateConnectionId(srcAddress, srcPort, destAddress, destPort)
        connections[connectionId]?.state = state
        connections[connectionId]?.lastActivityAt = System.currentTimeMillis()
    }

    /// 更新流量统计
    fun updateTraffic(
        srcAddress: String,
        srcPort: Int,
        destAddress: String,
        destPort: Int,
        bytesSent: Int,
        bytesReceived: Int
    ) {
        val connectionId = generateConnectionId(srcAddress, srcPort, destAddress, destPort)
        connections[connectionId]?.let {
            it.bytesSent += bytesSent
            it.bytesReceived += bytesReceived
            it.lastActivityAt = System.currentTimeMillis()
        }
    }

    /// 移除连接
    fun removeConnection(
        srcAddress: String,
        srcPort: Int,
        destAddress: String,
        destPort: Int
    ) {
        val connectionId = generateConnectionId(srcAddress, srcPort, destAddress, destPort)
        connections.remove(connectionId)
        Log.d(TAG, "Connection removed: $connectionId")
    }

    /// 获取活跃连接数
    fun getActiveConnectionCount(): Int = connections.size

    /// 清理空闲连接
    fun cleanupIdleConnections(timeoutMs: Long = 300000) { // 5 minutes
        val now = System.currentTimeMillis()
        val toRemove = connections.filterValues {
            now - it.lastActivityAt > timeoutMs
        }.keys

        toRemove.forEach { connections.remove(it) }
        Log.d(TAG, "Cleaned up ${toRemove.size} idle connections")
    }

    private fun generateConnectionId(
        srcAddress: String,
        srcPort: Int,
        destAddress: String,
        destPort: Int
    ): Int {
        return (srcAddress.hashCode() + srcPort + destAddress.hashCode() + destPort).absoluteValue
    }
}
