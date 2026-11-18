package com.example.hello_app

import android.os.Build
import android.telecom.Call
import android.telecom.CallScreeningService
import androidx.annotation.RequiresApi

@RequiresApi(Build.VERSION_CODES.N)
class WallCraftCallScreeningService : CallScreeningService() {

    override fun onScreenCall(callDetails: Call.Details) {
        try {
            val rawPhone = callDetails.handle?.schemeSpecificPart
            if (!rawPhone.isNullOrBlank()) {
                val info = CallerIdHelper.findContactByPhone(this, rawPhone)
                if (info != null) {
                    val directionLabel = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                        when (callDetails.callDirection) {
                            Call.Details.DIRECTION_OUTGOING -> "กำลังโทรออก"
                            else -> "สายโทรเข้า"
                        }
                    } else {
                        "สายโทรเข้า"
                    }
                    CallerIdHelper.showCallerNotification(
                        context = this,
                        rawPhone = rawPhone,
                        directionLabel = directionLabel,
                        info = info
                    )
                }
            }
        } catch (_: Exception) {
            // Never block or crash call screening
        } finally {
            respondToCall(callDetails, CallResponse.Builder().build())
        }
    }
}
