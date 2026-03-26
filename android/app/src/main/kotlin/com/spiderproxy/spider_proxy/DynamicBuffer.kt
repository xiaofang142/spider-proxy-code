package com.spiderproxy.spider_proxy

import android.util.Log
import java.nio.ByteBuffer

/**
 * 动态缓冲区
 *
 * 根据流量大小自动调整缓冲区大小，优化大流量场景性能
 *
 * 特性：
 * 1. 初始缓冲区 16KB
 * 2. 当缓冲区即将溢出时自动扩容（2 倍增长）
 * 3. 最大缓冲区 1MB
 * 4. 统计溢出次数和扩容历史
 */
class DynamicBuffer {
    companion object {
        private const val TAG = "SpiderProxy.DynamicBuffer"
        private const val INITIAL_BUFFER_SIZE = 16 * 1024 // 16KB
        private const val MAX_BUFFER_SIZE = 1 * 1024 * 1024 // 1MB
        private const val BUFFER_EXPANSION_THRESHOLD = 0.8 // 80% 使用率时扩容

        // 公开常量供外部使用
        val INITIAL_BUFFER_SIZE_KB: Int get() = INITIAL_BUFFER_SIZE / 1024
        val MAX_BUFFER_SIZE_KB: Int get() = MAX_BUFFER_SIZE / 1024
    }

    private var bufferSize = INITIAL_BUFFER_SIZE
    private var buffer: ByteBuffer = ByteBuffer.allocate(bufferSize)

    // 统计信息
    var expansionCount = 0
        private set
    var totalOverflowBytes = 0L
        private set
    var peakUsage = 0
        private set

    /**
     * 获取当前缓冲区
     */
    fun getBuffer(): ByteBuffer {
        buffer.clear()
        return buffer
    }

    /**
     * 检查是否需要扩容
     * @param currentUsage 当前使用量
     * @return 是否需要扩容
     */
    fun shouldExpand(currentUsage: Int): Boolean {
        val usageRatio = currentUsage.toFloat() / bufferSize
        return usageRatio >= BUFFER_EXPANSION_THRESHOLD
    }

    /**
     * 根据使用量调整缓冲区大小
     * @param currentUsage 当前使用量
     * @param isOverflow 是否已溢出
     */
    fun adjust(currentUsage: Int, isOverflow: Boolean) {
        // 更新峰值使用量
        if (currentUsage > peakUsage) {
            peakUsage = currentUsage
        }

        // 如果溢出，记录溢出字节数
        if (isOverflow) {
            totalOverflowBytes += (currentUsage - bufferSize)
        }

        // 检查是否需要扩容
        if (shouldExpand(currentUsage) && bufferSize < MAX_BUFFER_SIZE) {
            expand()
        }
    }

    /**
     * 扩容缓冲区
     */
    private fun expand() {
        val newBufferSize = calculateNewBufferSize()
        if (newBufferSize <= bufferSize) {
            Log.d(TAG, "Buffer already at max size: $bufferSize")
            return
        }

        Log.d(TAG, "Expanding buffer from $bufferSize to $newBufferSize bytes (expansion #$expansionCount)")

        // 创建新缓冲区
        val newBuffer = ByteBuffer.allocate(newBufferSize)

        // 复制旧数据（如果有）
        buffer.flip()
        if (buffer.hasRemaining()) {
            newBuffer.put(buffer)
        }

        // 替换旧缓冲区
        buffer = newBuffer
        bufferSize = newBufferSize
        expansionCount++
    }

    /**
     * 计算新的缓冲区大小
     * @return 新的缓冲区大小
     */
    private fun calculateNewBufferSize(): Int {
        // 2 倍增长，但不超过最大值
        return minOf(bufferSize * 2, MAX_BUFFER_SIZE)
    }

    /**
     * 获取当前缓冲区大小
     */
    fun getSize(): Int = bufferSize

    /**
     * 获取当前使用率
     */
    fun getUsagePercent(): Float {
        val position = buffer.position()
        return position.toFloat() / bufferSize * 100
    }

    /**
     * 重置缓冲区
     */
    fun reset() {
        buffer.clear()
    }

    /**
     * 获取统计信息
     */
    fun getStats(): Map<String, Any> {
        return mapOf(
            "currentSize" to bufferSize,
            "expansionCount" to expansionCount,
            "totalOverflowBytes" to totalOverflowBytes,
            "peakUsage" to peakUsage,
            "currentUsagePercent" to getUsagePercent()
        )
    }
}
