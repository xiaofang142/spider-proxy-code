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

    // 连接状态管理
    private val connections = ConcurrentHashMap<Int, TcpConnection>()
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
        var connection = connections[connectionId]
        if (connection == null) {
            // 创建新连接
            connection = createTcpConnection(
                connectionId = connectionId,
                srcAddress = srcAddress,
                srcPort = srcPort,
                destAddress = destAddress,
                destPort = destPort
            )
            connections[connectionId] = connection

            // 启动连接
            vpnScope.launch {
                try {
                    connection.start()
                    Log.d(TAG, "New TCP connection created: $connectionId")
                } catch (e: Exception) {
                    Log.e(TAG, "Failed to start connection: $connectionId", e)
                    removeConnection(connectionId)
                }
            }
        }

        // 发送数据
        connection?.sendData(packet, packetSize)
    }

    /// 创建 TCP 连接
    private fun createTcpConnection(
        connectionId: Int,
        srcAddress: String,
        srcPort: Int,
        destAddress: String,
        destPort: Int
    ): TcpConnection {
        return TcpConnection(
            connectionId = connectionId,
            srcAddress = srcAddress,
            srcPort = srcPort,
            destAddress = destAddress,
            destPort = destPort,
            proxyAddress = proxyAddress,
            proxyPort = proxyPort,
            selector = selector,
            onConnectionClosed = { removeConnection(connectionId) },
            tunDeviceWriter = tunDeviceWriter
        )
    }

    /// 移除连接
    private fun removeConnection(connectionId: Int) {
        connections.remove(connectionId)?.close()
        Log.d(TAG, "Connection removed: $connectionId")
    }

    /// 生成连接 ID
    private fun generateConnectionId(srcAddress: String, srcPort: Int, destAddress: String, destPort: Int): Int {
        // 使用简单的哈希生成唯一连接 ID
        return (srcAddress.hashCode() + srcPort + destAddress.hashCode() + destPort).absoluteValue
    }

    /// 关闭所有连接
    fun close() {
        try {
            connections.values.forEach { it.close() }
            connections.clear()
            selector.close()
            Log.d(TAG, "TcpForwarder closed, ${connections.size} connections cleaned up")
        } catch (e: Exception) {
            Log.e(TAG, "Error closing TcpForwarder", e)
        }
    }

    /// 获取活跃连接数
    fun getActiveConnectionCount(): Int = connections.size
}

/**
 * TCP 连接
 *
 * 管理单个 TCP 连接的双向数据转发
 */
class TcpConnection(
    private val connectionId: Int,
    private val srcAddress: String,
    private val srcPort: Int,
    private val destAddress: String,
    private val destPort: Int,
    private val proxyAddress: String,
    private val proxyPort: Int,
    private val selector: Selector,
    private val onConnectionClosed: (Int) -> Unit,
    private val tunDeviceWriter: TunDeviceWriter? = null
) {
    companion object {
        private const val TAG = "SpiderProxy.TcpConnection"
    }

    private var proxyChannel: SocketChannel? = null
    private val dynamicInputBuffer = DynamicBuffer()
    private val dynamicOutputBuffer = DynamicBuffer()
    private var isConnected = false
    private var connectionScope: CoroutineScope? = null

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
            // 1. 连接到代理服务器
            proxyChannel = SocketChannel.open()
            proxyChannel?.configureBlocking(false)
            proxyChannel?.connect(InetSocketAddress(proxyAddress, proxyPort))

            // 等待连接完成
            withTimeout(TcpForwarder.CONNECTION_TIMEOUT) {
                while (!proxyChannel?.finishConnect()!!) {
                    delay(10)
                }
            }

            // 2. 注册到 Selector
            proxyChannel?.register(selector, SelectionKey.OP_READ)

            isConnected = true
            state = State.CONNECTED

            Log.d(TAG, "Connection $connectionId established to proxy")

            // 3. 启动数据转发
            connectionScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
            connectionScope?.launch {
                forwardData()
            }

        } catch (e: Exception) {
            Log.e(TAG, "Failed to connect for $connectionId", e)
            state = State.CLOSED
            onConnectionClosed(connectionId)
        }
    }

    /// 发送数据到代理
    fun sendData(packet: ByteArray, size: Int) {
        if (!isConnected || state != State.CONNECTED) {
            Log.w(TAG, "Cannot send data, connection not ready: $connectionId")
            return
        }

        try {
            val buffer = dynamicOutputBuffer.getBuffer()
            buffer.put(packet, 0, size)
            buffer.flip()

            proxyChannel?.write(buffer)

            // 调整缓冲区大小
            dynamicOutputBuffer.adjust(size, isOverflow = size >= buffer.capacity())
        } catch (e: Exception) {
            Log.e(TAG, "Error sending data for $connectionId", e)
            close()
        }
    }

    /// 转发数据
    private suspend fun forwardData() {
        try {
            while (isConnected && state == State.CONNECTED) {
                // 使用 Selector 等待可读事件
                val readyChannels = selector.select(1000)

                if (readyChannels > 0) {
                    val selectedKeys = selector.selectedKeys().iterator()

                    while (selectedKeys.hasNext()) {
                        val key = selectedKeys.next()
                        selectedKeys.remove()

                        if (key.isReadable) {
                            readFromProxy()
                        }
                    }
                }
            }
        } catch (e: CancellationException) {
            Log.d(TAG, "Forward task cancelled for $connectionId")
        } catch (e: Exception) {
            if (state == State.CONNECTED) {
                Log.e(TAG, "Error forwarding data for $connectionId", e)
            }
        } finally {
            close()
        }
    }

    /// 从代理读取数据
    private fun readFromProxy() {
        try {
            val buffer = dynamicInputBuffer.getBuffer()
            val bytesRead = proxyChannel?.read(buffer) ?: -1

            if (bytesRead == -1) {
                // EOF - 连接关闭
                Log.d(TAG, "EOF received for connection $connectionId")
                close()
                return
            }

            if (bytesRead > 0) {
                // 调整缓冲区大小
                dynamicInputBuffer.adjust(bytesRead, isOverflow = bytesRead >= buffer.capacity())

                buffer.flip()
                val data = ByteArray(bytesRead)
                buffer.get(data)

                // 将数据写回 TUN 设备
                tunDeviceWriter?.writeTcpResponse(
                    tcpData = data,
                    srcAddress = destAddress,
                    srcPort = destPort,
                    destAddress = srcAddress,
                    destPort = srcPort
                ) ?: run {
                    // 简化实现：仅记录
                    Log.d(TAG, "Read ${bytesRead} bytes from proxy for $connectionId")
                }
            }
        } catch (e: IOException) {
            Log.e(TAG, "Error reading from proxy for $connectionId", e)
            close()
        }
    }

    /// 关闭连接
    fun close() {
        if (state == State.CLOSED || state == State.CLOSING) return

        state = State.CLOSING
        isConnected = false

        try {
            proxyChannel?.close()
            connectionScope?.cancel()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing connection $connectionId", e)
        } finally {
            state = State.CLOSED
            onConnectionClosed(connectionId)
            Log.d(TAG, "Connection $connectionId closed")
        }
    }
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
