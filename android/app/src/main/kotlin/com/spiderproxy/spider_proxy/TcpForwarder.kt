package com.spiderproxy.spider_proxy

import android.util.Log
import kotlinx.coroutines.*
import java.io.IOException
import java.net.InetSocketAddress
import java.nio.ByteBuffer
import java.nio.channels.SelectionKey
import java.nio.channels.Selector
import java.nio.channels.SocketChannel
import java.util.concurrent.ConcurrentHashMap

/**
 * TCP 转发器
 *
 * 实现完整的 TCP 数据包转发到 SOCKS5 代理服务器
 * 支持连接状态管理和双向数据流
 */
class TcpForwarder(
    private val proxyAddress: String,
    private val proxyPort: Int,
    private val vpnScope: CoroutineScope,
    private val tunDeviceWriter: TunDeviceWriter? = null
) {
    companion object {
        private const val TAG = "SpiderProxy.TcpForwarder"
        private const val BUFFER_SIZE = 16384 // 16KB
        private const val CONNECTION_TIMEOUT = 10000L // 10 seconds
    }

    // 连接池管理
    private val connectionPool = ConnectionPool(
        proxyAddress = proxyAddress,
        proxyPort = proxyPort,
        minIdle = 2,
        maxIdle = 10,
        maxTotal = 50,
        idleTimeoutMs = 60000L,
        connectionTimeoutMs = CONNECTION_TIMEOUT
    )

    // 活跃连接跟踪
    private val activeConnections = ConcurrentHashMap<Int, PooledConnection>()
    private val selector = Selector.open()

    /// 处理 TCP 数据包
    suspend fun handleTcpPacket(
        srcAddress: String,
        srcPort: Int,
        destAddress: String,
        destPort: Int,
        packet: ByteArray,
        packetSize: Int
    ) {
        val connectionId = generateConnectionId(srcAddress, srcPort, destAddress, destPort)

        // 获取或创建连接
        var connection = activeConnections[connectionId]
        if (connection == null) {
            // 从连接池获取连接
            vpnScope.launch {
                try {
                    connection = connectionPool.acquire(destAddress, destPort)
                    if (connection != null) {
                        activeConnections[connectionId] = connection
                        Log.d(TAG, "New TCP connection from pool: $connectionId -> $destAddress:$destPort")
                    } else {
                        Log.e(TAG, "Failed to acquire connection from pool: $connectionId")
                        removeConnection(connectionId)
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error acquiring connection: $connectionId", e)
                    removeConnection(connectionId)
                }
            }
        }

        // 发送数据
        connection?.let { conn ->
            vpnScope.launch {
                try {
                    val channel = conn.getChannel()
                    val buffer = ByteBuffer.wrap(packet, 0, packetSize)
                    channel.write(buffer)
                    Log.d(TAG, "Sent ${packetSize} bytes to $destAddress:$destPort")
                } catch (e: Exception) {
                    Log.e(TAG, "Error sending data for $connectionId", e)
                    removeConnection(connectionId)
                }
            }
        }
    }

    /// 移除连接
    private fun removeConnection(connectionId: Int) {
        val connection = activeConnections.remove(connectionId)
        connection?.release() // 释放回连接池
        Log.d(TAG, "Connection released to pool: $connectionId")
    }

    /// 生成连接 ID
    private fun generateConnectionId(srcAddress: String, srcPort: Int, destAddress: String, destPort: Int): Int {
        // 使用简单的哈希生成唯一连接 ID
        return (srcAddress.hashCode() + srcPort + destAddress.hashCode() + destPort).absoluteValue
    }

    /// 关闭所有连接
    fun close() {
        try {
            // 关闭所有活跃连接
            activeConnections.values.forEach { it.close() }
            activeConnections.clear()

            // 关闭连接池
            connectionPool.close()

            // 关闭 Selector
            selector.close()

            // 记录统计信息
            val stats = connectionPool.getStats()
            Log.d(TAG, "TcpForwarder closed. Connection pool stats: $stats")
        } catch (e: Exception) {
            Log.e(TAG, "Error closing TcpForwarder", e)
        }
    }

    /// 获取活跃连接数
    fun getActiveConnectionCount(): Int = activeConnections.size

    /// 获取连接池统计
    fun getPoolStats(): Map<String, Any> = connectionPool.getStats()
}

/**
 * SOCKS5 代理客户端
 *
 * 实现 SOCKS5 协议握手和认证
 */
class Socks5Client {
    companion object {
        private const val TAG = "SpiderProxy.Socks5Client"

        // SOCKS5 常量
        private const val SOCKS_VERSION = 0x05
        private const val AUTH_NONE = 0x00
        private const val AUTH_PASSWORD = 0x02

        private const val CMD_CONNECT = 0x01
        private const val CMD_BIND = 0x02
        private const val CMD_UDP_ASSOCIATE = 0x03

        private const val ATYP_IPV4 = 0x01
        private const val ATYP_DOMAIN = 0x03
        private const val ATYP_IPV6 = 0x04

        private const val REPLY_SUCCESS = 0x00
    }

    /**
     * 执行 SOCKS5 握手
     */
    suspend fun handshake(channel: SocketChannel, username: String? = null, password: String? = null): Boolean {
        return withTimeout(5000) {
            try {
                // 1. 发送握手请求
                val handshakeRequest = if (username != null && password != null) {
                    byteArrayOf(
                        SOCK_VERSION.toByte(),
                        0x02.toByte(), // 认证方法数量
                        AUTH_NONE.toByte(),
                        AUTH_PASSWORD.toByte()
                    )
                } else {
                    byteArrayOf(
                        SOCK_VERSION.toByte(),
                        0x01.toByte(),
                        AUTH_NONE.toByte()
                    )
                }

                channel.write(ByteBuffer.wrap(handshakeRequest))

                // 2. 读取服务器响应
                val response = ByteBuffer.allocate(2)
                channel.read(response)
                response.flip()

                val version = response.get()
                val method = response.get()

                if (version != SOCK_VERSION.toByte()) {
                    Log.e(TAG, "Invalid SOCKS version: $version")
                    return@withTimeout false
                }

                if (method == 0xFF.toByte()) {
                    Log.e(TAG, "No acceptable authentication method")
                    return@withTimeout false
                }

                // 3. 如果需要密码认证
                if (method == AUTH_PASSWORD.toByte() && username != null && password != null) {
                    if (!authenticate(channel, username, password)) {
                        return@withTimeout false
                    }
                }

                Log.d(TAG, "SOCKS5 handshake completed")
                true
            } catch (e: Exception) {
                Log.e(TAG, "SOCKS5 handshake failed", e)
                false
            }
        }
    }

    /**
     * SOCKS5 密码认证
     */
    private suspend fun authenticate(channel: SocketChannel, username: String, password: String): Boolean {
        return withTimeout(5000) {
            try {
                // 构建认证请求
                val userBytes = username.toByteArray()
                val passBytes = password.toByteArray()
                val authRequest = ByteArray(3 + userBytes.size + passBytes.size).apply {
                    this[0] = 0x01 // 版本
                    this[1] = userBytes.size.toByte()
                    System.arraycopy(userBytes, 0, this, 2, userBytes.size)
                    this[2 + userBytes.size] = passBytes.size.toByte()
                    System.arraycopy(passBytes, 0, this, 3 + userBytes.size, passBytes.size)
                }

                channel.write(ByteBuffer.wrap(authRequest))

                // 读取响应
                val response = ByteBuffer.allocate(2)
                channel.read(response)
                response.flip()

                val status = response.get(1)
                if (status != 0x00.toByte()) {
                    Log.e(TAG, "Authentication failed: $status")
                    return@withTimeout false
                }

                Log.d(TAG, "SOCKS5 authentication successful")
                true
            } catch (e: Exception) {
                Log.e(TAG, "Authentication failed", e)
                false
            }
        }
    }

    /**
     * 建立 SOCKS5 连接
     */
    suspend fun connect(
        channel: SocketChannel,
        destAddress: String,
        destPort: Int
    ): Boolean {
        return withTimeout(5000) {
            try {
                // 构建连接请求
                val addressBytes = destAddress.toByteArray()
                val isDomain = destAddress.any { !it.isDigit() && it != '.' }

                val connectRequest = if (isDomain) {
                    // 域名地址
                    ByteBuffer.allocate(7 + addressBytes.size).apply {
                        put(SOCK_VERSION.toByte())
                        put(CMD_CONNECT.toByte())
                        put(0x00.toByte()) // RSV
                        put(ATYP_DOMAIN.toByte())
                        put(addressBytes.size.toByte())
                        put(addressBytes)
                        putShort(destPort.toShort())
                    }.array()
                } else {
                    // IPv4 地址
                    val ipParts = destAddress.split(".").map { it.toInt() }
                    ByteBuffer.allocate(10).apply {
                        put(SOCK_VERSION.toByte())
                        put(CMD_CONNECT.toByte())
                        put(0x00.toByte()) // RSV
                        put(ATYP_IPV4.toByte())
                        ipParts.forEach { put(it.toByte()) }
                        putShort(destPort.toShort())
                    }.array()
                }

                channel.write(ByteBuffer.wrap(connectRequest))

                // 读取响应
                val response = ByteBuffer.allocate(10)
                channel.read(response)
                response.flip()

                val reply = response.get(1)
                if (reply != REPLY_SUCCESS.toByte()) {
                    Log.e(TAG, "Connection failed with reply: $reply")
                    return@withTimeout false
                }

                Log.d(TAG, "SOCKS5 connection established to $destAddress:$destPort")
                true
            } catch (e: Exception) {
                Log.e(TAG, "SOCKS5 connection failed", e)
                false
            }
        }
    }
}
