package com.example.hello_app

import android.Manifest
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL_NAME = "com.wallcraft.caller_id"
        private const val REQ_CALLER_ID_PERMS = 9101
        private const val REQ_CALL_SCREENING_ROLE = 9102
    }

    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveContactsDirectory" -> {
                        val json = call.argument<String>("json") ?: "[]"
                        val baseUrl = call.argument<String>("baseUrl")
                        val authToken = call.argument<String>("authToken")
                        try {
                            CallerIdHelper.saveApiConfig(this, baseUrl, authToken)
                            val count = CallerIdHelper.saveDirectory(this, json)
                            result.success(count)
                        } catch (e: Exception) {
                            result.error("SAVE_DIR_FAILED", e.message, null)
                        }
                    }

                    "saveApiConfig" -> {
                        val baseUrl = call.argument<String>("baseUrl")
                        val authToken = call.argument<String>("authToken")
                        CallerIdHelper.saveApiConfig(this, baseUrl, authToken)
                        result.success(true)
                    }

                    "getCallerIdStatus" -> {
                        result.success(buildStatusMap())
                    }

                    "requestCallerIdPermissions" -> {
                        handleRequestPermissions(result)
                    }

                    "getRecentCallLogs" -> {
                        val sinceMs = call.argument<Number>("sinceEpochMs")?.toLong()
                            ?: (System.currentTimeMillis() - 14L * 24 * 60 * 60 * 1000)
                        val limit = call.argument<Int>("limit") ?: 150
                        try {
                            val logs = CallerIdHelper.readRecentCallLogs(this, sinceMs, limit)
                            result.success(logs)
                        } catch (e: Exception) {
                            result.error("READ_CALL_LOG_FAILED", e.message, null)
                        }
                    }

                    "showTestNotification" -> {
                        val rawPhone = call.argument<String>("phone") ?: "0812345678"
                        val found = CallerIdHelper.findContactByPhone(this, rawPhone)
                        val info = found ?: CustomerCallerInfo(
                            contactId = "",
                            phoneNormalized = CallerIdHelper.normalizeThaiPhone(rawPhone),
                            displayName = call.argument<String>("displayName") ?: "ลูกค้าทดสอบ WallCraft",
                            companyName = call.argument<String>("companyName") ?: "บริษัท ตัวอย่าง ดีไซน์ จำกัด",
                            customerType = call.argument<String>("customerType") ?: "Architect",
                            projectName = call.argument<String>("projectName") ?: "โครงการตัวอย่าง",
                            assignedSalesName = call.argument<String>("assignedSalesName") ?: "ทีมขาย"
                        )
                        CallerIdHelper.showCallerNotification(
                            context = this,
                            rawPhone = rawPhone,
                            directionLabel = "ทดสอบสายโทรเข้า",
                            info = info
                        )
                        result.success(true)
                    }

                    "openAppSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.fromParts("package", packageName, null)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_SETTINGS_FAILED", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun hasPermission(permission: String): Boolean {
        return ContextCompat.checkSelfPermission(this, permission) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun hasCallScreeningRole(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val roleManager = getSystemService(Context.ROLE_SERVICE) as? RoleManager ?: return false
        return roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
    }

    private fun supportsCallScreeningRole(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val roleManager = getSystemService(Context.ROLE_SERVICE) as? RoleManager ?: return false
        return roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)
    }

    private fun buildStatusMap(): Map<String, Any> {
        val hasNotif = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            hasPermission(Manifest.permission.POST_NOTIFICATIONS)
        } else {
            true
        }
        return mapOf(
            "directoryCount" to CallerIdHelper.getDirectoryCount(this),
            "hasCallLogPermission" to hasPermission(Manifest.permission.READ_CALL_LOG),
            "hasPhoneStatePermission" to hasPermission(Manifest.permission.READ_PHONE_STATE),
            "hasNotificationPermission" to hasNotif,
            "hasCallScreeningRole" to hasCallScreeningRole(),
            "supportsCallScreeningRole" to supportsCallScreeningRole(),
            "androidSdk" to Build.VERSION.SDK_INT
        )
    }

    private fun handleRequestPermissions(result: MethodChannel.Result) {
        if (pendingPermissionResult != null) {
            pendingPermissionResult?.success(buildStatusMap())
            pendingPermissionResult = null
        }
        pendingPermissionResult = result

        val missing = mutableListOf<String>()
        if (!hasPermission(Manifest.permission.READ_CALL_LOG)) {
            missing.add(Manifest.permission.READ_CALL_LOG)
        }
        if (!hasPermission(Manifest.permission.READ_PHONE_STATE)) {
            missing.add(Manifest.permission.READ_PHONE_STATE)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            !hasPermission(Manifest.permission.POST_NOTIFICATIONS)
        ) {
            missing.add(Manifest.permission.POST_NOTIFICATIONS)
        }

        if (missing.isNotEmpty()) {
            ActivityCompat.requestPermissions(this, missing.toTypedArray(), REQ_CALLER_ID_PERMS)
        } else {
            maybeRequestCallScreeningRoleOrFinish()
        }
    }

    private fun maybeRequestCallScreeningRoleOrFinish() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roleManager = getSystemService(Context.ROLE_SERVICE) as? RoleManager
            if (roleManager != null &&
                roleManager.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING) &&
                !roleManager.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
            ) {
                val intent = roleManager.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING)
                @Suppress("DEPRECATION")
                startActivityForResult(intent, REQ_CALL_SCREENING_ROLE)
                return
            }
        }
        finishPendingPermissionResult()
    }

    private fun finishPendingPermissionResult() {
        if (hasPermission(Manifest.permission.READ_CALL_LOG)) {
            CallLogSyncWorker.enqueue(this, delaySeconds = 1L)
        }
        val pending = pendingPermissionResult ?: return
        pendingPermissionResult = null
        pending.success(buildStatusMap())
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_CALLER_ID_PERMS) {
            maybeRequestCallScreeningRoleOrFinish()
        }
    }

    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_CALL_SCREENING_ROLE) {
            finishPendingPermissionResult()
        }
    }
}
