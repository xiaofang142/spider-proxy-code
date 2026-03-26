package com.spiderproxy.spider_proxy

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.util.Log
import org.bouncycastle.asn1.ASN1ObjectIdentifier
import org.bouncycastle.asn1.x500.X500Name
import org.bouncycastle.asn1.x509.BasicConstraints
import org.bouncycastle.asn1.x509.ExtendedKeyUsage
import org.bouncycastle.asn1.x509.Extension
import org.bouncycastle.asn1.x509.GeneralName
import org.bouncycastle.asn1.x509.GeneralNames
import org.bouncycastle.asn1.x509.KeyPurposeId
import org.bouncycastle.asn1.x509.KeyUsage
import org.bouncycastle.cert.X509CertificateHolder
import org.bouncycastle.cert.X509v3CertificateBuilder
import org.bouncycastle.cert.jcajce.JcaX509CertificateConverter
import org.bouncycastle.cert.jcajce.JcaX509ExtensionUtils
import org.bouncycastle.cert.jcajce.JcaX509v3CertificateBuilder
import org.bouncycastle.jce.provider.BouncyCastleProvider
import org.bouncycastle.operator.ContentSigner
import org.bouncycastle.operator.OperatorCreationException
import org.bouncycastle.operator.jcajce.JcaContentSignerBuilder
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.math.BigInteger
import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.PublicKey
import java.security.Security
import java.security.cert.CertificateFactory
import java.security.cert.X509Certificate
import java.util.Date
import java.util.concurrent.ConcurrentHashMap
import javax.net.ssl.KeyManagerFactory
import javax.net.ssl.SSLContext
import javax.net.ssl.TrustManagerFactory

/**
 * Spider Proxy SSL 拦截器
 *
 * 使用 Bouncy Castle 生成完整的 X.509 证书
 * 使用 Android KeyStore 安全存储 CA 私钥
 *
 * 功能：
 * 1. 生成 CA 证书（私钥存储在 KeyStore）
 * 2. 为主机生成动态证书（24 小时过期）
 * 3. 创建 SSL 上下文用于 MITM 解密
 */
class SslInterceptor(private val certsDir: File, private val context: Context) {
    companion object {
        private const val TAG = "SpiderProxy.SslInterceptor"
        private const val CA_CERT_FILE_NAME = "spider_proxy_ca.crt"
        private const val KEYSTORE_ALIAS = "spider_proxy_ca"
        private const val ANDROID_KEYSTORE = "AndroidKeyStore"
        private const val CERT_VALIDITY_YEARS = 10L
        private const val HOST_CERT_VALIDITY_MS = 24 * 60 * 60 * 1000L // 24 小时

        init {
            // 注册 Bouncy Castle Provider
            Security.addProvider(BouncyCastleProvider())
        }
    }

    private var caCertificate: X509Certificate? = null
    private var caPrivateKey: PrivateKey? = null
    private var caPublicKey: PublicKey? = null
    private val certCache = ConcurrentHashMap<String, CachedCert>()
    private lateinit var caKeyPair: KeyPair
    private lateinit var keyStore: KeyStore

    /// 初始化 SSL 拦截器
    fun initialize() {
        Log.d(TAG, "Initializing SSL interceptor at ${certsDir.absolutePath}")

        // 初始化 KeyStore
        keyStore = KeyStore.getInstance(ANDROID_KEYSTORE)
        keyStore.load(null)

        // 创建证书目录
        if (!certsDir.exists()) {
            certsDir.mkdirs()
        }

        // 加载或生成 CA 证书
        loadOrGenerateCACertificate()
    }

    /// 从 KeyStore 获取 CA 私钥
    private fun getPrivateKeyFromKeyStore(): PrivateKey {
        val entry = keyStore.getEntry(KEYSTORE_ALIAS, null) as KeyStore.PrivateKeyEntry
        return entry.privateKey
    }

    /// 从 KeyStore 获取 CA 公钥
    private fun getPublicKeyFromKeyStore(): PublicKey {
        val entry = keyStore.getEntry(KEYSTORE_ALIAS, null) as KeyStore.PrivateKeyEntry
        return entry.certificate.publicKey
    }

    /// 加载或生成 CA 证书
    private fun loadOrGenerateCACertificate() {
        val certFile = File(certsDir, CA_CERT_FILE_NAME)

        if (certFile.exists() && keyStore.containsAlias(KEYSTORE_ALIAS)) {
            // 加载现有证书和私钥
            try {
                loadCACertificate(certFile)
                Log.d(TAG, "CA certificate loaded from disk")
            } catch (e: Exception) {
                Log.e(TAG, "Error loading CA certificate", e)
                generateCACertificate(certFile)
            }
        } else {
            // 生成新的 CA 证书
            generateCACertificate(certFile)
        }
    }

    /// 加载现有 CA 证书
    private fun loadCACertificate(certFile: File) {
        // 加载证书
        val cf = CertificateFactory.getInstance("X.509", "BC")
        FileInputStream(certFile).use { fis ->
            caCertificate = cf.generateCertificate(fis) as X509Certificate
        }

        // 从 KeyStore 加载私钥和公钥
        caPrivateKey = getPrivateKeyFromKeyStore()
        caPublicKey = getPublicKeyFromKeyStore()
        caKeyPair = KeyPair(caPublicKey!!, caPrivateKey!!)
    }

    /// 生成 CA 证书
    private fun generateCACertificate(certFile: File) {
        Log.d(TAG, "Generating new CA certificate")

        try {
            // 检查 KeyStore 中是否已存在密钥对
            if (keyStore.containsAlias(KEYSTORE_ALIAS)) {
                keyStore.deleteEntry(KEYSTORE_ALIAS)
            }

            // 使用 KeyStore 生成密钥对
            val keyPairGenerator = KeyPairGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_RSA,
                ANDROID_KEYSTORE
            )

            val keyGenSpec = KeyGenParameterSpec.Builder(
                KEYSTORE_ALIAS,
                KeyProperties.PURPOSE_SIGN
            )
                .setKeySize(2048)
                .setDigests(KeyProperties.DIGEST_SHA256)
                .setEncryptionPaddings("PKCS1v15")
                .setUserAuthenticationRequired(false)
                .setKeyValidityStart(Date())
                .build()

            keyPairGenerator.initialize(keyGenSpec)
            val keyPair = keyPairGenerator.generateKeyPair()

            // 从 KeyStore 获取私钥和公钥
            caPrivateKey = getPrivateKeyFromKeyStore()
            caPublicKey = getPublicKeyFromKeyStore()
            caKeyPair = keyPair

            // 生成 CA 证书
            val now = Date()
            val expiry = Date(now.time + CERT_VALIDITY_YEARS * 365L * 24 * 60 * 60 * 1000)
            val serialNumber = BigInteger.valueOf(System.currentTimeMillis())

            val subject = X500Name("CN=Spider Proxy CA,O=Spider Proxy,C=CN")
            val issuer = subject

            // 创建证书构建器
            val certBuilder: X509v3CertificateBuilder = JcaX509v3CertificateBuilder(
                issuer,
                serialNumber,
                now,
                expiry,
                subject,
                caPublicKey
            )

            // 添加扩展
            val extUtils = JcaX509ExtensionUtils()

            // 基本约束 - CA 证书
            certBuilder.addExtension(
                Extension.basicConstraints,
                true,
                BasicConstraints(true)
            )

            // 密钥用法
            certBuilder.addExtension(
                Extension.keyUsage,
                true,
                KeyUsage(KeyUsage.keyCertSign or KeyUsage.cRLSign)
            )

            // 主体密钥标识符
            certBuilder.addExtension(
                Extension.subjectKeyIdentifier,
                false,
                extUtils.createSubjectKeyIdentifier(caPublicKey)
            )

            // 颁发者密钥标识符
            certBuilder.addExtension(
                Extension.authorityKeyIdentifier,
                false,
                extUtils.createAuthorityKeyIdentifier(caPublicKey)
            )

            // 签名证书
            val signer: ContentSigner = JcaContentSignerBuilder("SHA256withRSA")
                .setProvider("BC")
                .build(caPrivateKey)

            val certHolder: X509CertificateHolder = certBuilder.build(signer)
            caCertificate = JcaX509CertificateConverter()
                .setProvider("BC")
                .getCertificate(certHolder)

            // 保存证书为 PEM 格式
            val certPem = buildString {
                appendLine("-----BEGIN CERTIFICATE-----")
                appendLine(Base64.encodeToString(caCertificate!!.encoded, Base64.NO_WRAP))
                appendLine("-----END CERTIFICATE-----")
            }
            FileOutputStream(certFile).use { fos ->
                fos.write(certPem.toByteArray())
            }

            Log.d(TAG, "CA certificate generated and stored in KeyStore")
        } catch (e: Exception) {
            Log.e(TAG, "Error generating CA certificate", e)
        }
    }

    /// 为主机生成证书并获取 SSL 上下文
    fun getSSLContextForHost(host: String): SSLContext? {
        // 检查缓存（24 小时过期）
        val cached = certCache[host]
        if (cached != null && !cached.isExpired) {
            Log.d(TAG, "Using cached SSL context for host: $host")
            return cached.sslContext
        }

        try {
            // 生成主机证书
            val hostCertData = generateHostCertificate(host)

            // 创建密钥库
            val keyStore = java.security.KeyStore.getInstance("PKCS12")
            keyStore.load(null, null)

            // 设置证书条目
            val certChain = arrayOf(hostCertData.certificate, caCertificate)
            keyStore.setKeyEntry(
                "host",
                hostCertData.privateKey,
                CharArray(0),
                certChain
            )

            // 初始化密钥管理器
            val keyManagerFactory = KeyManagerFactory.getInstance(KeyManagerFactory.getDefaultAlgorithm())
            keyManagerFactory.init(keyStore, CharArray(0))

            // 创建信任管理器
            val trustManagerFactory = TrustManagerFactory.getInstance(TrustManagerFactory.getDefaultAlgorithm())
            trustManagerFactory.init(keyStore)

            // 创建 SSL 上下文
            val sslContext = SSLContext.getInstance("TLS")
            sslContext.init(
                keyManagerFactory.keyManagers,
                trustManagerFactory.trustManagers,
                null
            )

            // 缓存 SSL 上下文（24 小时后过期）
            certCache[host] = CachedCert(
                sslContext = sslContext,
                expires = System.currentTimeMillis() + HOST_CERT_VALIDITY_MS
            )

            Log.d(TAG, "Generated SSL context for host: $host (expires in 24 hours)")
            return sslContext
        } catch (e: Exception) {
            Log.e(TAG, "Error generating SSL context for $host", e)
            return null
        }
    }

    /// 生成主机证书
    private fun generateHostCertificate(host: String): HostCertData {
        try {
            // 生成主机 RSA 密钥对
            val keyPairGenerator = KeyPairGenerator.getInstance("RSA", "BC")
            keyPairGenerator.initialize(2048)
            val keyPair = keyPairGenerator.generateKeyPair()

            // 生成证书（24 小时过期）
            val now = Date()
            val expiry = Date(now.time + HOST_CERT_VALIDITY_MS)
            val serialNumber = BigInteger.valueOf(System.currentTimeMillis() + host.hashCode())

            val subject = X500Name("CN=$host,O=Spider Proxy,C=CN")
            val issuer = X500Name("CN=Spider Proxy CA,O=Spider Proxy,C=CN")

            // 创建证书构建器
            val certBuilder: X509v3CertificateBuilder = JcaX509v3CertificateBuilder(
                issuer,
                serialNumber,
                now,
                expiry,
                subject,
                keyPair.public
            )

            // 添加扩展
            val extUtils = JcaX509ExtensionUtils()

            // 主体备用名称 (SAN) - 支持多域名
            val sanNames = mutableListOf<GeneralName>()
            sanNames.add(GeneralName(GeneralName.dNSName, host))

            // 添加通配符支持
            if (!host.startsWith("*.")) {
                sanNames.add(GeneralName(GeneralName.dNSName, "*.$host"))
            }

            certBuilder.addExtension(
                Extension.subjectAlternativeName,
                false,
                GeneralNames(sanNames.toTypedArray())
            )

            // 扩展密钥用法 - 服务器认证
            certBuilder.addExtension(
                Extension.extendedKeyUsage,
                false,
                ExtendedKeyUsage(KeyPurposeId.id_kp_serverAuth)
            )

            // 密钥用法
            certBuilder.addExtension(
                Extension.keyUsage,
                true,
                KeyUsage(KeyUsage.digitalSignature or KeyUsage.keyEncipherment)
            )

            // 主体密钥标识符
            certBuilder.addExtension(
                Extension.subjectKeyIdentifier,
                false,
                extUtils.createSubjectKeyIdentifier(keyPair.public)
            )

            // 颁发者密钥标识符
            certBuilder.addExtension(
                Extension.authorityKeyIdentifier,
                false,
                extUtils.createAuthorityKeyIdentifier(caPublicKey)
            )

            // 使用 CA 私钥签名
            val signer: ContentSigner = JcaContentSignerBuilder("SHA256withRSA")
                .setProvider("BC")
                .build(caPrivateKey)

            val certHolder: X509CertificateHolder = certBuilder.build(signer)
            val certificate = JcaX509CertificateConverter()
                .setProvider("BC")
                .getCertificate(certHolder)

            Log.d(TAG, "Host certificate generated for: $host (expires: ${expiry})")
            return HostCertData(keyPair.private, certificate)
        } catch (e: Exception) {
            Log.e(TAG, "Error generating host certificate for $host", e)
            // 返回占位数据
            return createDummyHostCertData(host)
        }
    }

    /// 卸载 CA 证书（从 KeyStore 和文件系统中删除）
    fun uninstallCertificate(): Boolean {
        try {
            // 从 KeyStore 删除私钥
            if (keyStore.containsAlias(KEYSTORE_ALIAS)) {
                keyStore.deleteEntry(KEYSTORE_ALIAS)
                Log.d(TAG, "CA private key removed from KeyStore")
            }

            // 删除证书文件
            val certFile = File(certsDir, CA_CERT_FILE_NAME)
            if (certFile.exists()) {
                certFile.delete()
                Log.d(TAG, "CA certificate file deleted")
            }

            // 清理缓存
            clearCertCache()

            // 重置证书引用
            caCertificate = null
            caPrivateKey = null
            caPublicKey = null

            Log.d(TAG, "CA certificate uninstalled successfully")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Error uninstalling CA certificate", e)
            return false
        }
    }

    /// 检查证书是否有效（未过期）
    fun isCertificateValid(): Boolean {
        val cert = caCertificate ?: return false
        val now = Date()
        return try {
            cert.checkValidity(now)
        } catch (e: Exception) {
            false
        }
    }

    /// 获取 CA 证书文件路径
    fun getCACertificatePath(): String {
        return File(certsDir, CA_CERT_FILE_NAME).absolutePath
    }

    /// 获取 CA 证书数据
    fun getCACertificateBytes(): ByteArray? {
        val certFile = File(certsDir, CA_CERT_FILE_NAME)
        return if (certFile.exists()) {
            FileInputStream(certFile).use { fis ->
                fis.readBytes()
            }
        } else {
            null
        }
    }

    /// 获取 CA 证书（X509 格式）
    fun getCACertificate(): X509Certificate? = caCertificate

    /// 获取 CA 证书有效期信息
    fun getCertificateValidityInfo(): Map<String, Any> {
        val cert = caCertificate
        return if (cert != null) {
            mapOf(
                "isValid" to isCertificateValid(),
                "notBefore" to cert.notBefore.time,
                "notAfter" to cert.notAfter.time,
                "subject" to cert.subjectDN.name,
                "issuer" to cert.issuerDN.name
            )
        } else {
            mapOf("isValid" to false)
        }
    }

    /// 检查证书是否已安装
    fun isCertificateInstalled(): Boolean {
        return keyStore.containsAlias(KEYSTORE_ALIAS) && caCertificate != null
    }

    /// 安装 CA 证书到系统
    fun installCACertificate(): Boolean {
        Log.d(TAG, "To install CA certificate manually:")
        Log.d(TAG, "1. Go to Settings > Security > Encryption & credentials")
        Log.d(TAG, "2. Select 'Install from storage'")
        Log.d(TAG, "3. Navigate to: ${getCACertificatePath()}")
        Log.d(TAG, "4. Enter a name for the certificate and confirm")
        return true
    }

    /// 清理证书缓存
    fun clearCertCache() {
        certCache.clear()
        Log.d(TAG, "Certificate cache cleared")
    }

    /// 停止 SSL 拦截器
    fun stop() {
        clearCertCache()
        caCertificate = null
        caPrivateKey = null
        caPublicKey = null
        Log.d(TAG, "SSL interceptor stopped")
    }

    /// 缓存的 SSL 上下文
    private data class CachedCert(
        val sslContext: SSLContext,
        val expires: Long
    ) {
        fun isExpired(): Boolean = System.currentTimeMillis() > expires
    }

    /// 主机证书数据
    data class HostCertData(
        val privateKey: PrivateKey,
        val certificate: X509Certificate?
    )
}
