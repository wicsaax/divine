package com.divine.divine

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder

/**
 * 前台服务, 在 LLM 流式调用期间保持 app 进程不被 OEM 杀.
 *
 * 通知栏会显示一条 "divine 正在解读…", 点击回到 app.
 * 流式结束后 (成功 / 失败 / 取消) 由 Flutter 侧通过 MethodChannel 停止本服务.
 */
class LlmStreamService : Service() {

    companion object {
        private const val CHANNEL_ID = "divine_llm_stream"
        private const val CHANNEL_NAME = "占卜解读"
        private const val NOTIFICATION_ID = 4081
    }

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIFICATION_ID, buildNotification())
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "AI 解读运行期间保持网络连接的常驻通知"
                setShowBadge(false)
            }
            val nm = getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(ch)
        }
    }

    private fun buildNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pi: PendingIntent? = intent?.let {
            PendingIntent.getActivity(
                this, 0, it,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
        }

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        builder
            .setContentTitle("divine 正在解读…")
            .setContentText("切走也不会断, 回来就能看完整解读.")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
        if (pi != null) builder.setContentIntent(pi)
        return builder.build()
    }
}
