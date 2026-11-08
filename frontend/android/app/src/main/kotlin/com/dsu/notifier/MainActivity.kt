package com.dsu.notifier

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import java.util.UUID
import java.security.SecureRandom
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "dsu_notifier/native"
    private val notificationChannel = "new_notices"
    private val permissionRequest = 1001

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createNotificationChannel()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "deviceIdentity" -> {
                    val preferences = getSharedPreferences("device_identity", MODE_PRIVATE)
                    val id = preferences.getString("id", null) ?: UUID.randomUUID().toString()
                    val secret = preferences.getString("secret", null) ?: ByteArray(32).also { SecureRandom().nextBytes(it) }.let { Base64.encodeToString(it, Base64.NO_WRAP or Base64.URL_SAFE) }
                    preferences.edit().putString("id", id).putString("secret", secret).commit()
                    result.success(mapOf("id" to id, "secret" to secret))
                }
                "openNotificationSettings" -> {
                    startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                    result.success(null)
                }
                "requestNotifications" -> result.success(requestNotifications())
                "showTestNotification" -> { showTestNotification(); result.success(null) }
                "showNotification" -> {
                    showNotification(
                        call.argument<String>("title") ?: "새 공지 알림",
                        call.argument<String>("body") ?: "새 공지사항이 등록되었습니다.",
                        call.argument<String>("url"),
                    )
                    result.success(null)
                }
                "openUrl" -> {
                    val uri = safeNoticeUri(call.argument<String>("url"))
                    if (uri == null) result.error("INVALID_URL", "Invalid notice URL", null)
                    else try {
                        startActivity(Intent(Intent.ACTION_VIEW, uri))
                        result.success(null)
                    } catch (_: android.content.ActivityNotFoundException) {
                        result.error("NO_BROWSER", "No browser available", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun safeNoticeUri(url: String?): Uri? {
        val uri = url?.let { Uri.parse(it) } ?: return null
        return uri.takeIf { it.scheme == "https" && it.host == "www.dongseo.ac.kr" && it.userInfo == null && (it.port == -1 || it.port == 443) }
    }

    private fun requestNotifications(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), permissionRequest)
            return false
        }
        return true
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            val channel = NotificationChannel(notificationChannel, "새 공지", NotificationManager.IMPORTANCE_DEFAULT)
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    private fun showTestNotification() {
        showNotification("새 공지 알림", "테스트 공지사항이 등록되었습니다.", null)
    }

    private fun showNotification(title: String, body: String, url: String?) {
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
        val safeUri = safeNoticeUri(url)
        val intent = if (safeUri != null) {
            Intent(Intent.ACTION_VIEW, safeUri)
        } else {
            Intent(this, MainActivity::class.java)
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            title.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = android.app.Notification.Builder(this, notificationChannel)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(android.app.Notification.PRIORITY_DEFAULT)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()
        getSystemService(NotificationManager::class.java).notify(title.hashCode(), notification)
    }
}
