package com.spiderproxy.spider_proxy

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import android.util.Log
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Spider Proxy 主 Activity
 *
 * 负责：
 * 1. 初始化 Flutter 引擎
 * 2. 设置 Platform Channel
 * 3. 绑定 VPN 服务
 */
class MainActivity : FlutterActivity() {
    companion object {
        private const val TAG = "SpiderProxy.MainActivity"
        private const val CHANNEL_NAME = "com.spiderproxy/proxy"
    }

    private var vpnService: VpnService? = null
    private var vpnBound = false
    private var methodChannel: MethodChannel? = null

    // VPN 服务连接
    private val vpnServiceConnection = object : ServiceConnection {
        override fun onServiceConnected(className: ComponentName, service: IBinder) {
            val binder = service as VpnService.LocalBinder
            vpnService = binder.getService()
            vpnBound = true
            vpnService?.setupMethodChannel(engine!!)
        }

        override fun onServiceDisconnected(arg: ComponentName) {
            vpnService = null
            vpnBound = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 设置主 Method Channel
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
        setupMethodChannelHandlers()
    }

    override fun onResume() {
        super.onResume()
        // 绑定 VPN 服务
        Intent(this, VpnService::class.java).also { intent ->
            bindService(intent, vpnServiceConnection, Context.BIND_AUTO_CREATE)
        }
    }

    override fun onPause() {
        super.onPause()
        if (vpnBound) {
            unbindService(vpnServiceConnection)
            vpnBound = false
        }
    }

    /// 设置 Method Channel 处理器
    private fun setupMethodChannelHandlers() {
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startProxy" -> startProxy(call.arguments as? Map<*, *>, result)
                "stopProxy" -> stopProxy(result)
                "installCertificate" -> installCertificate(result)
                "getProxyStatus" -> getProxyStatus(result)
                else -> result.notImplemented()
            }
        }
    }

    /// 启动代理
    private fun startProxy(args: Map<*, *>?, result: MethodChannel.Result) {
        val port = (args?.get("port") as? Int) ?: 8888
        val enableHttps = (args?.get("enableHttps") as? Boolean) ?: true

        // 启动 VPN 服务
        val vpnIntent = Intent(this, VpnService::class.java)
        startService(vpnIntent)

        // 通知 Flutter
        result.success(mapOf(
            "success" to true,
            "port" to port,
            "enableHttps" to enableHttps
        ))
    }

    /// 停止代理
    private fun stopProxy(result: MethodChannel.Result) {
        val vpnIntent = Intent(this, VpnService::class.java)
        stopService(vpnIntent)
        result.success(true)
    }

    /// 安装证书
    private fun installCertificate(result: MethodChannel.Result) {
        try {
            // 获取 VpnService 中的 SSL 拦截器证书路径
            val vpnService = this.vpnService
            if (vpnService != null) {
                val sslInterceptor = vpnService.getSslInterceptor()
                val certPath = sslInterceptor.getCACertificatePath()
                sslInterceptor.installCACertificate()

                result.success(mapOf(
                    "success" to true,
                    "certPath" to certPath,
                    "message" to "请在系统设置中安装证书：$certPath"
                ))
            } else {
                // VPN 服务未绑定，直接返回证书路径
                val certsDir = filesDir.resolve("certificates")
                val certPath = File(certsDir, "spider_proxy_ca.crt").absolutePath

                result.success(mapOf(
                    "success" to true,
                    "certPath" to certPath,
                    "message" to "请在系统设置中安装证书：$certPath"
                ))
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error installing certificate", e)
            result.error("INSTALL_FAILED", e.message, null)
        }
    }

    /// 获取代理状态
    private fun getProxyStatus(result: MethodChannel.Result) {
        val status = mapOf(
            "isRunning" to (vpnService?.isRunning ?: false),
            "vpnBound" to vpnBound
        )
        result.success(status)
    }
}
