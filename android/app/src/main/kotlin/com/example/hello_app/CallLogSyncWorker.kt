package com.example.hello_app

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import androidx.work.BackoffPolicy
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.TimeUnit

class CallLogSyncWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : Worker(appContext, workerParams) {

    companion object {
        private const val UNIQUE_WORK_NAME = "wallcraft_call_log_sync"
        private const val PROD_CALL_LOGS_URL = "https://www.wallcraftthailand.com/api/v1/call-logs"

        fun enqueue(context: Context, delaySeconds: Long = 3L) {
            val granted = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.READ_CALL_LOG
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) return

            if (CallerIdHelper.getActiveAuthToken(context).isNullOrBlank()) return

            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()

            val request = OneTimeWorkRequestBuilder<CallLogSyncWorker>()
                .setInitialDelay(delaySeconds.coerceAtLeast(1L), TimeUnit.SECONDS)
                .setConstraints(constraints)
                .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
                .build()

            WorkManager.getInstance(context.applicationContext).enqueueUniqueWork(
                UNIQUE_WORK_NAME,
                ExistingWorkPolicy.REPLACE,
                request
            )
        }
    }

    override fun doWork(): Result {
        val ctx = applicationContext
        val granted = ContextCompat.checkSelfPermission(
            ctx,
            Manifest.permission.READ_CALL_LOG
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) return Result.success()

        val authToken = CallerIdHelper.getActiveAuthToken(ctx) ?: return Result.success()

        val nowMs = System.currentTimeMillis()
        val maxLookbackMs = nowMs - 14L * 24 * 60 * 60 * 1000
        val defaultLookbackMs = nowMs - 3L * 24 * 60 * 60 * 1000
        val storedLast = CallerIdHelper.getLastBgSyncMs(ctx)
        val sinceMs = if (storedLast > 0L) {
            (storedLast - 24L * 60 * 60 * 1000).coerceIn(maxLookbackMs, nowMs)
        } else {
            defaultLookbackMs
        }

        val logs = CallerIdHelper.readRecentCallLogs(ctx, sinceMs, limit = 60)
        if (logs.isEmpty()) {
            CallerIdHelper.setLastBgSyncMs(ctx, nowMs)
            return Result.success()
        }

        val jsonLogs = JSONArray()
        for (row in logs) {
            val phone = (row["phone_normalized"] as? String).orEmpty()
            if (phone.isEmpty()) continue

            val contactId = (row["contact_id"] as? String).orEmpty()
            // Strictly skip phone numbers outside our customer_contacts directory
            if (contactId.isEmpty()) continue

            val rawDir = (row["direction"] as? String).orEmpty()
            val callDirection = when (rawDir) {
                "outgoing" -> "outgoing"
                "incoming" -> "incoming"
                else -> "missed"
            }
            val durationSec = (row["duration_seconds"] as? Number)?.toInt() ?: 0
            val outcome = when {
                durationSec > 0 -> "connected"
                callDirection == "missed" -> "no_answer"
                else -> "unknown"
            }

            val info = CallerIdHelper.findContactByPhone(ctx, phone) ?: continue

            val item = JSONObject().apply {
                put("phone", phone)
                put("contact_id", contactId)
                put("contact_name", info.displayName)
                if (info.companyName.isNotBlank()) {
                    put("company_name", info.companyName)
                }
                put("call_direction", callDirection)
                put("call_source", "android_call_log")
                put("started_at", (row["started_at"] as? String).orEmpty())
                put("duration_sec", durationSec)
                put("outcome", outcome)
                put("device_call_key", (row["device_call_key"] as? String).orEmpty())
            }
            jsonLogs.put(item)
        }

        if (jsonLogs.length() == 0) {
            CallerIdHelper.setLastBgSyncMs(ctx, nowMs)
            return Result.success()
        }

        val payload = JSONObject().put("logs", jsonLogs).toString()
        val primaryUrl = CallerIdHelper.getActiveApiBaseUrl(ctx).trimEnd('/') + "/call-logs"

        val status = postPayloadWithFailover(primaryUrl, authToken, payload)
        return when {
            status in 200..299 -> {
                CallerIdHelper.setLastBgSyncMs(ctx, nowMs)
                Result.success()
            }
            status in 400..499 -> Result.failure()
            else -> Result.retry()
        }
    }

    private fun postPayloadWithFailover(
        primaryUrl: String,
        authToken: String,
        payload: String
    ): Int {
        return try {
            sendPost(primaryUrl, authToken, payload)
        } catch (_: IOException) {
            if (primaryUrl != PROD_CALL_LOGS_URL) {
                try {
                    sendPost(PROD_CALL_LOGS_URL, authToken, payload)
                } catch (_: IOException) {
                    503
                }
            } else {
                503
            }
        }
    }

    private fun sendPost(endpoint: String, authToken: String, payload: String): Int {
        val conn = (URL(endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 10_000
            readTimeout = 15_000
            doOutput = true
            setRequestProperty("Content-Type", "application/json; charset=utf-8")
            setRequestProperty("Accept", "application/json")
            setRequestProperty("Authorization", "Bearer $authToken")
        }
        return try {
            OutputStreamWriter(conn.outputStream, Charsets.UTF_8).use { writer ->
                writer.write(payload)
                writer.flush()
            }
            conn.responseCode
        } finally {
            conn.disconnect()
        }
    }
}
