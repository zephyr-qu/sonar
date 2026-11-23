package com.zephyr.sonar

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Tells the user about a file request that arrived while the app was not on screen.
 *
 * The request only pushes a dialog, which nobody sees from the background, so a plain notification
 * is the only way to surface it. It deliberately is *not* a foreground service notification:
 * Android 12+ forbids starting a foreground service from the background, which is exactly the
 * situation a request arrives in.
 *
 * Tapping it only brings [MainActivity] back to the front - the request dialog is already on the
 * navigation stack, so no request details need to travel through the notification.
 */
object RequestNotification {
    private const val CHANNEL_ID = "sonar_incoming_request"

    // Transfer progress notifications of the foreground service use id 1.
    private const val NOTIFICATION_ID = 2

    fun show(
        context: Context,
        title: String,
        text: String,
        channelName: String,
    ) {
        // Android 13+ silently drops the notification of an app without the permission, so skip the
        // work. The permission is requested at app start, not here: the app is in the background
        // when this runs and Android shows no permission dialog then.
        if (!hasPermission(context)) {
            return
        }

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(manager, channelName)

        val notification =
            NotificationCompat
                .Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_stat_request)
                .setContentTitle(title)
                .setContentText(text)
                .setStyle(NotificationCompat.BigTextStyle().bigText(text))
                .setCategory(NotificationCompat.CATEGORY_MESSAGE)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setOnlyAlertOnce(true)
                .setContentIntent(contentIntent(context))
                .build()

        manager.notify(NOTIFICATION_ID, notification)
    }

    // Removes the notification once the request was answered, declined or cancelled.
    // Cancelling a notification that is not shown is a no-op.
    fun cancel(context: Context) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(NOTIFICATION_ID)
    }

    private fun hasPermission(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }
        return ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }

    // The channel name is user-visible (app notification settings), so it comes translated from
    // Dart. Like every notification channel, it is only read when the channel is first created.
    private fun ensureChannel(
        manager: NotificationManager,
        channelName: String,
    ) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        if (manager.getNotificationChannel(CHANNEL_ID) != null) {
            return
        }
        val channel = NotificationChannel(CHANNEL_ID, channelName, NotificationManager.IMPORTANCE_HIGH)
        manager.createNotificationChannel(channel)
    }

    private fun contentIntent(context: Context): PendingIntent {
        val intent =
            Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_MAIN
                addCategory(Intent.CATEGORY_LAUNCHER)
                // MainActivity is singleTask: bring the running task forward instead of starting a
                // second instance (which would show a second request dialog).
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            }
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
