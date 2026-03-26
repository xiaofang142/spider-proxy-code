package com.spiderproxy.spider_proxy

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

/**
 * Spider Proxy 前台服务
 *
 * 用于保持代理服务和 VPN 服务在后台运行
 */
class ProxyForegroundService : Service() {
    companion object {
        private const val TAG = "SpiderProxy.ForegroundService"
        private const val NOTIFICATION_CHANNEL_ID = "spider_proxy_foreground_channel"
        private const val NOTIFICATION_ID = 1002
    }

    private val binder = LocalBinder()

    inner class LocalBinder : Binder() {
        fun getService(): ProxyForegroundService = this@ProxyForegroundService
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "ProxyForegroundService onCreate")
        createNotificationChannel()
    }

    override fun onBind(intent: Intent?): IBinder {
        Log.d(TAG, "ProxyForegroundService onBind")
        return binder
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d(TAG, "ProxyForegroundService onStartCommand")
        startForeground(NOTIFICATION_ID, createNotification())
        return START_STICKY
    }

    override fun onDestroy() {
        Log.d(TAG, "ProxyForegroundService onDestroy")
        super.onDestroy()
    }

    /// 创建通知渠道
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                NOTIFICATION_CHANNEL_ID,
                "代理服务",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Spider Proxy 代理服务运行中"
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
            .setContentText("代理服务运行中")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }
}
