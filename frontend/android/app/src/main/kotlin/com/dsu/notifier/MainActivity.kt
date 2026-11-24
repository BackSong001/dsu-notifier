package com.dsu.notifier

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
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
                    val settingsIntent = if (Build.VERSION.SDK_INT >= 26) {
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    } else {
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    }
                    try {
                        startActivity(settingsIntent)
                        result.success(null)
                    } catch (_: android.content.ActivityNotFoundException) {
                        result.error("SETTINGS_UNAVAILABLE", "Notification settings are unavailable", null)
                    }
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
                    val uri = safeExternalUri(call.argument<String>("url"))
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

    private fun safeExternalUri(url: String?): Uri? {
        val uri = url?.let { Uri.parse(it) } ?: return null
        val validHost = uri.host == "www.dongseo.ac.kr" ||
            (uri.host == "www.lunchmenu.co.kr" && uri.path == "/menu/latest")
        return uri.takeIf {
            it.scheme == "https" && validHost && it.userInfo == null &&
                (it.port == -1 || it.port == 443)
        }
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
            // URL이 있으면 앱으로 열어서 딥링크 처리
            Intent(this, MainActivity::class.java).apply {
                putExtra("notice_url", safeUri.toString())
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
        } else {
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
        }
        // 알림마다 다른 ID를 사용해 여러 공지를 동시에 표시한다.
        val notificationId = System.nanoTime().toInt()
        val pendingIntent = PendingIntent.getActivity(
            this,
            notificationId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            android.app.Notification.Builder(this, notificationChannel)
        } else {
            android.app.Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(android.app.Notification.PRIORITY_DEFAULT)
            .setContentIntent(pendingIntent)
            .setAutoCancel(true)
            .build()
        getSystemService(NotificationManager::class.java).notify(notificationId, notification)
    }
}
