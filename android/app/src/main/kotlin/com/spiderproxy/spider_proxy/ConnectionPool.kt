package com.spiderproxy.spider_proxy

import android.util.Log
import kotlinx.coroutines.*
import java.io.IOException
import java.net.InetSocketAddress
import java.nio.channels.SocketChannel
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Semaphore
import java.util.concurrent.atomic.AtomicLong

/**
 * TCP 连接池
 *
 * 管理 SOCKS5 代理连接的复用，减少连接建立开销
 *
 * 特性：
 * 1. 连接复用：相同目标地址的连接可复用
 * 2. 空闲检测：自动回收空闲连接
 * 3. 连接限制：控制最大连接数防止资源耗尽
 * 4. 健康检查：连接使用前验证可用性
 */
class ConnectionPool(
    private val proxyAddress: String,
    private val proxyPort: Int,
    private val minIdle: Int = 2,
    private val maxIdle: Int = 10,
    private val maxTotal: Int = 50,
    private val idleTimeoutMs: Long = 60000L,
    private val connectionTimeoutMs: Long = 10000L
) {
    companion object {
        private const val TAG = "SpiderProxy.ConnectionPool"
    }

    // 连接池存储：key 为目标地址哈希，value 为连接队列
    private val pool = ConcurrentHashMap<String, ConcurrentLinkedQueue<PooledConnection>>()

    // 活跃连接计数
    private val activeCount = AtomicLong(0)
    private val totalCreated = AtomicLong(0)
    private val totalDestroyed = AtomicLong(0)

    // 信号量控制最大连接数
    private val maxTotalSemaphore = Semaphore(maxTotal)

    // 连接池是否关闭
    private var isClosed = false

    // 空闲连接清理协程
    private var idleCheckScope: CoroutineScope? = null
    private var idleCheckJob: Job? = null

    /**
     * 初始化连接池
     */
    fun initialize() {
        Log.d(TAG, "Initializing connection pool: minIdle=$minIdle, maxIdle=$maxIdle, maxTotal=$maxTotal")

        idleCheckScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
        idleCheckJob = idleCheckScope?.launch {
            while (!isClosed) {
                delay(idleTimeoutMs / 2)
                checkIdleConnections()
            }
        }

        Log.d(TAG, "Connection pool initialized")
    }

    /**
     * 获取连接
     * @param destAddress 目标地址
     * @param destPort 目标端口
     * @return PooledConnection 或 null
     */
    suspend fun acquire(destAddress: String, destPort: Int): PooledConnection? {
        if (isClosed) {
            Log.w(TAG, "Connection pool is closed")
            return null
        }

        val poolKey = "$destAddress:$destPort"

        // 尝试从池中获取空闲连接
        val pooledConn = pool[poolKey]?.pollFirst()
        if (pooledConn != null) {
            if (pooledConn.isValid()) {
                activeCount.incrementAndGet()
                Log.d(TAG, "Acquired pooled connection: $poolKey (active=$activeCount)")
                return pooledConn
            } else {
                // 连接已失效，销毁并继续创建新连接
                destroyConnection(pooledConn)
                Log.d(TAG, "Pooled connection invalid, creating new one: $poolKey")
            }
        }

        // 创建新连接（受信号量控制）
        if (!maxTotalSemaphore.tryAcquire()) {
            Log.w(TAG, "Connection pool exhausted, waiting...")
            maxTotalSemaphore.acquire()
        }

        return try {
            val newConn = createConnection(destAddress, destPort, poolKey)
            activeCount.incrementAndGet()
            totalCreated.incrementAndGet()
            Log.d(TAG, "Created new connection: $poolKey (total=$totalCreated, active=$activeCount)")
            newConn
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create connection: $poolKey", e)
            maxTotalSemaphore.release()
            null
        }
    }

    /**
     * 释放连接回池
     */
    fun release(connection: PooledConnection) {
        if (isClosed) {
            destroyConnection(connection)
            return
        }

        activeCount.decrementAndGet()
        connection.lastUsedTime = System.currentTimeMillis()

        val poolKey = connection.poolKey

        // 检查连接是否有效
        if (!connection.isValid()) {
            destroyConnection(connection)
            Log.d(TAG, "Released connection invalid, destroyed: $poolKey")
            return
        }

        // 检查池大小
        val queue = pool.getOrPut(poolKey) { java.util.concurrent.ConcurrentLinkedQueue() }
        if (queue.size >= maxIdle) {
            destroyConnection(connection)
            Log.d(TAG, "Pool full, destroyed connection: $poolKey")
        } else {
            queue.offer(connection)
            Log.d(TAG, "Released connection to pool: $poolKey (idle=${queue.size})")
        }
    }

    /**
     * 销毁连接
     */
    private fun destroyConnection(connection: PooledConnection) {
        try {
            connection.close()
            totalDestroyed.incrementAndGet()
            maxTotalSemaphore.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error destroying connection", e)
        }
    }

    /**
     * 创建新连接
     */
    private suspend fun createConnection(
        destAddress: String,
        destPort: Int,
        poolKey: String
    ): PooledConnection {
        val channel = SocketChannel.open()
        channel.configureBlocking(false)

        // 连接代理服务器
        withTimeout(connectionTimeoutMs) {
            channel.connect(InetSocketAddress(proxyAddress, proxyPort))
            while (!channel.finishConnect()) {
                delay(10)
            }
        }

        // 执行 SOCKS5 握手
        val socksClient = Socks5Client()
        if (!socksClient.handshake(channel)) {
            channel.close()
            throw IOException("SOCKS5 handshake failed")
        }

        // 连接到目标地址
        if (!socksClient.connect(channel, destAddress, destPort)) {
            channel.close()
            throw IOException("SOCKS5 connect failed")
        }

        val pooledConn = PooledConnection(
            channel = channel,
            destAddress = destAddress,
            destPort = destPort,
            poolKey = poolKey,
            onRelease = { release(it) }
        )

        return pooledConn
    }

    /**
     * 检查并清理空闲连接
     */
    private fun checkIdleConnections() {
        val now = System.currentTimeMillis()
        var cleanedCount = 0

        for ((poolKey, queue) in pool.entries) {
            val toRemove = mutableListOf<PooledConnection>()

            for (conn in queue) {
                if (now - conn.lastUsedTime > idleTimeoutMs) {
                    toRemove.add(conn)
                }
            }

            for (conn in toRemove) {
                queue.remove(conn)
                destroyConnection(conn)
                cleanedCount++
                Log.d(TAG, "Cleaned idle connection: $poolKey")
            }
        }

        if (cleanedCount > 0) {
            Log.d(TAG, "Connection pool cleanup: removed $cleanedCount idle connections")
        }
    }

    /**
     * 关闭连接池
     */
    fun close() {
        Log.d(TAG, "Closing connection pool...")
        isClosed = true

        idleCheckJob?.cancel()
        idleCheckScope?.cancel()

        // 关闭所有连接
        for ((_, queue) in pool) {
            for (conn in queue) {
                destroyConnection(conn)
            }
            queue.clear()
        }
        pool.clear()

        Log.d(TAG, "Connection pool closed. Stats: created=$totalCreated, destroyed=$totalDestroyed")
    }

    /**
     * 获取连接池统计
     */
    fun getStats(): Map<String, Any> {
        val idleCount = pool.values.sumOf { it.size }
        return mapOf(
            "activeCount" to activeCount.get(),
            "idleCount" to idleCount,
            "totalCreated" to totalCreated.get(),
            "totalDestroyed" to totalDestroyed.get(),
            "maxTotal" to maxTotal,
            "maxIdle" to maxIdle
        )
    }
}

/**
 * 池化连接包装器
 */
class PooledConnection(
    private val channel: SocketChannel,
    val destAddress: String,
    val destPort: Int,
    val poolKey: String,
    private val onRelease: (PooledConnection) -> Unit
) {
    var lastUsedTime = System.currentTimeMillis()
    private var isClosed = false

    /**
     * 检查连接是否有效
     */
    fun isValid(): Boolean {
        if (isClosed) return false
        return channel.isConnected && channel.isOpen
    }

    /**
     * 获取底层通道
     */
    fun getChannel(): SocketChannel = channel

    /**
     * 释放连接回池
     */
    fun release() {
        onRelease(this)
    }

    /**
     * 关闭连接
     */
    fun close() {
        if (isClosed) return
        isClosed = true
        try {
            channel.close()
        } catch (e: Exception) {
            // Ignore
        }
    }
}

/**
 * 简单的并发队列实现
 */
class ConcurrentLinkedQueue<T> {
    private val backingList = java.util.concurrent.ConcurrentLinkedQueue<T>()

    fun offer(element: T): Boolean = backingList.offer(element)
    fun pollFirst(): T? = backingList.poll()
    fun size(): Int = backingList.size
    fun isEmpty(): Boolean = backingList.isEmpty()
    fun iterator(): Iterator<T> = backingList.iterator()
    fun remove(element: T): Boolean = backingList.remove(element)
    fun clear() = backingList.clear()
}
