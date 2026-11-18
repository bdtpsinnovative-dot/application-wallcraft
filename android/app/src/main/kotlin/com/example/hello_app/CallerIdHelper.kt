package com.example.hello_app

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.CallLog
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

data class CustomerCallerInfo(
    val contactId: String,
    val phoneNormalized: String,
    val displayName: String,
    val companyName: String,
    val customerType: String,
    val projectName: String,
    val assignedSalesName: String
)

object CallerIdHelper {
    private const val PREFS_NAME = "wallcraft_caller_id"
    private const val FLUTTER_PREFS_NAME = "FlutterSharedPreferences"
    private const val KEY_DIRECTORY_MAP = "directory_map_json"
    private const val KEY_DIRECTORY_COUNT = "directory_count"
    private const val KEY_API_BASE_URL = "api_base_url"
    private const val KEY_AUTH_TOKEN = "auth_token"
    private const val KEY_LAST_BG_SYNC_MS = "last_bg_call_sync_ms"
    private const val DEFAULT_API_BASE_URL = "https://www.wallcraftthailand.com/api/v1"
    private const val CHANNEL_ID = "wallcraft_caller_id_channel"
    private const val CHANNEL_NAME = "WallCraft Caller ID"
    private const val CHANNEL_DESC = "แสดงชื่อลูกค้าและโครงการเมื่อมีสายโทรเข้า-ออก"

    fun normalizeThaiPhone(raw: String?): String {
        if (raw.isNullOrBlank()) return ""
        val digits = raw.filter { it.isDigit() }
        if (digits.isEmpty()) return ""
        return when {
            digits.startsWith("0066") && digits.length in 12..13 -> "0" + digits.substring(4)
            digits.startsWith("066") && digits.length in 11..12 -> "0" + digits.substring(3)
            digits.startsWith("660") && digits.length >= 11 -> "0" + digits.substring(3)
            digits.startsWith("66") && digits.length in 10..11 -> "0" + digits.substring(2)
            else -> digits
        }
    }

    fun isValidThaiPhone(norm: String): Boolean {
        return norm.startsWith("0") && (norm.length == 9 || norm.length == 10)
    }

    fun saveApiConfig(context: Context, baseUrl: String?, authToken: String?) {
        val editor = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE).edit()
        if (!baseUrl.isNullOrBlank()) {
            editor.putString(KEY_API_BASE_URL, baseUrl.trim().trimEnd('/'))
        }
        if (!authToken.isNullOrBlank()) {
            editor.putString(KEY_AUTH_TOKEN, authToken.trim())
        }
        editor.apply()
    }

    fun getActiveApiBaseUrl(context: Context): String {
        val stored = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_API_BASE_URL, null)
        return if (!stored.isNullOrBlank()) stored else DEFAULT_API_BASE_URL
    }

    fun getActiveAuthToken(context: Context): String? {
        val flutterPrefs = context.getSharedPreferences(FLUTTER_PREFS_NAME, Context.MODE_PRIVATE)
        if (flutterPrefs.getBoolean("flutter.auth_explicitly_signed_out", false)) {
            return null
        }
        val flutterToken = flutterPrefs.getString("flutter.auth_token", null)
        if (!flutterToken.isNullOrBlank()) {
            return flutterToken.trim()
        }
        val nativeToken = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_AUTH_TOKEN, null)
        return nativeToken?.takeIf { it.isNotBlank() }?.trim()
    }

    fun getLastBgSyncMs(context: Context): Long {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getLong(KEY_LAST_BG_SYNC_MS, 0L)
    }

    fun setLastBgSyncMs(context: Context, valueMs: Long) {
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putLong(KEY_LAST_BG_SYNC_MS, valueMs)
            .apply()
    }

    fun formatThaiPhone(raw: String?): String {
        val norm = normalizeThaiPhone(raw)
        if (norm.length == 10 && norm.startsWith("0")) {
            return "${norm.substring(0, 3)}-${norm.substring(3, 6)}-${norm.substring(6)}"
        }
        if (norm.length == 9 && norm.startsWith("02")) {
            return "02-${norm.substring(2, 5)}-${norm.substring(5)}"
        }
        if (norm.length == 9 && norm.startsWith("0")) {
            return "${norm.substring(0, 3)}-${norm.substring(3, 6)}-${norm.substring(6)}"
        }
        return raw ?: norm
    }

    fun saveDirectory(context: Context, contactsJson: String): Int {
        val array = JSONArray(contactsJson)
        val mapObject = JSONObject()
        for (i in 0 until array.length()) {
            val item = array.optJSONObject(i) ?: continue
            val norm = normalizeThaiPhone(
                item.optString("phone_normalized").ifBlank { item.optString("phone_display") }
            )
            if (norm.isEmpty()) continue
            mapObject.put(norm, item)
        }
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_DIRECTORY_MAP, mapObject.toString())
            .putInt(KEY_DIRECTORY_COUNT, mapObject.length())
            .apply()
        return mapObject.length()
    }

    fun getDirectoryCount(context: Context): Int {
        return context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getInt(KEY_DIRECTORY_COUNT, 0)
    }

    private fun getDirectoryMap(context: Context): JSONObject? {
        val json = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            .getString(KEY_DIRECTORY_MAP, null) ?: return null
        return try {
            JSONObject(json)
        } catch (_: Exception) {
            null
        }
    }

    fun findContactByPhone(context: Context, rawPhone: String?): CustomerCallerInfo? {
        val norm = normalizeThaiPhone(rawPhone)
        if (norm.isEmpty()) return null
        val mapObject = getDirectoryMap(context) ?: return null
        val item = mapObject.optJSONObject(norm) ?: return null
        return CustomerCallerInfo(
            contactId = item.optString("id", ""),
            phoneNormalized = norm,
            displayName = item.optString("display_name", "").ifBlank { formatThaiPhone(norm) },
            companyName = item.optString("company_name", ""),
            customerType = item.optString("customer_type", ""),
            projectName = item.optString("project_name", ""),
            assignedSalesName = item.optString("assigned_sales_name", "")
        )
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val existing = manager.getNotificationChannel(CHANNEL_ID)
            if (existing == null) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = CHANNEL_DESC
                    enableVibration(true)
                }
                manager.createNotificationChannel(channel)
            }
        }
    }

    fun showCallerNotification(
        context: Context,
        rawPhone: String?,
        directionLabel: String,
        info: CustomerCallerInfo
    ) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) return
        }

        ensureChannel(context)

        val titleParts = mutableListOf(info.displayName)
        if (info.customerType.isNotBlank()) {
            titleParts.add("[${info.customerType}]")
        }
        val title = "$directionLabel: ${titleParts.joinToString(" ")}"

        val detailLines = mutableListOf<String>()
        detailLines.add("เบอร์: ${formatThaiPhone(rawPhone ?: info.phoneNormalized)}")
        if (info.companyName.isNotBlank() && info.companyName != info.displayName) {
            detailLines.add("บริษัท: ${info.companyName}")
        }
        if (info.projectName.isNotBlank()) {
            detailLines.add("โครงการ: ${info.projectName}")
        }
        if (info.assignedSalesName.isNotBlank()) {
            detailLines.add("เซลส์ดูแล: ${info.assignedSalesName}")
        }
        val shortSummary = detailLines.take(2).joinToString(" • ")
        val bigText = detailLines.joinToString("\n")

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("open_customer_directory", true)
            putExtra("phone_normalized", info.phoneNormalized)
        }
        val pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        val pendingIntent = PendingIntent.getActivity(
            context,
            info.phoneNormalized.hashCode(),
            launchIntent,
            pendingFlags
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle(title)
            .setContentText(shortSummary)
            .setStyle(NotificationCompat.BigTextStyle().bigText(bigText))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        val notifId = (info.phoneNormalized.hashCode() and 0x7FFFFFFF).coerceAtLeast(1000)
        NotificationManagerCompat.from(context).notify(notifId, notification)
    }

    fun readRecentCallLogs(
        context: Context,
        sinceEpochMs: Long,
        limit: Int
    ): List<Map<String, Any?>> {
        val granted = ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_CALL_LOG
        ) == PackageManager.PERMISSION_GRANTED
        if (!granted) return emptyList()

        val directoryMap = getDirectoryMap(context)

        val results = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            CallLog.Calls._ID,
            CallLog.Calls.NUMBER,
            CallLog.Calls.CACHED_NAME,
            CallLog.Calls.TYPE,
            CallLog.Calls.DATE,
            CallLog.Calls.DURATION
        )

        val selection = "${CallLog.Calls.DATE} >= ?"
        val selectionArgs = arrayOf(sinceEpochMs.toString())
        val sortOrder = "${CallLog.Calls.DATE} DESC"

        val isoFormatter = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = TimeZone.getTimeZone("UTC")
        }

        context.contentResolver.query(
            CallLog.Calls.CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            sortOrder
        )?.use { cursor ->
            val idIdx = cursor.getColumnIndex(CallLog.Calls._ID)
            val numIdx = cursor.getColumnIndex(CallLog.Calls.NUMBER)
            val nameIdx = cursor.getColumnIndex(CallLog.Calls.CACHED_NAME)
            val typeIdx = cursor.getColumnIndex(CallLog.Calls.TYPE)
            val dateIdx = cursor.getColumnIndex(CallLog.Calls.DATE)
            val durIdx = cursor.getColumnIndex(CallLog.Calls.DURATION)

            while (cursor.moveToNext() && results.size < limit) {
                val rawNumber = if (numIdx >= 0) cursor.getString(numIdx) else null
                val norm = normalizeThaiPhone(rawNumber)
                if (!isValidThaiPhone(norm)) continue

                val matched = directoryMap?.optJSONObject(norm)
                val cachedName = if (nameIdx >= 0) (cursor.getString(nameIdx) ?: "").trim() else ""

                val rowId = if (idIdx >= 0) cursor.getLong(idIdx) else 0L
                val callDateMs = if (dateIdx >= 0) cursor.getLong(dateIdx) else 0L
                val durationSec = if (durIdx >= 0) cursor.getInt(durIdx) else 0
                val callType = if (typeIdx >= 0) cursor.getInt(typeIdx) else CallLog.Calls.INCOMING_TYPE

                val direction = when (callType) {
                    CallLog.Calls.OUTGOING_TYPE -> "outgoing"
                    CallLog.Calls.MISSED_TYPE -> "missed"
                    5 -> "rejected" // CallLog.Calls.REJECTED_TYPE (API 24+)
                    6 -> "blocked" // CallLog.Calls.BLOCKED_TYPE (API 24+)
                    else -> "incoming"
                }

                val deviceCallKey = "${rowId}_${callDateMs}_${direction}_${norm}"

                results.add(
                    mapOf(
                        "device_call_key" to deviceCallKey,
                        "contact_id" to (matched?.optString("id", "") ?: ""),
                        "cached_name" to cachedName,
                        "phone_normalized" to norm,
                        "phone_display" to formatThaiPhone(norm),
                        "direction" to direction,
                        "duration_seconds" to durationSec,
                        "started_at" to isoFormatter.format(Date(callDateMs)),
                        "source" to "android_call_log"
                    )
                )
            }
        }
        return results
    }

    fun readMatchedRecentCallLogs(
        context: Context,
        sinceEpochMs: Long,
        limit: Int
    ): List<Map<String, Any?>> = readRecentCallLogs(context, sinceEpochMs, limit)
}
