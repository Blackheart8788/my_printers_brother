package com.rouninlabs.another_brother

import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbManager
import android.os.Build
import androidx.annotation.WorkerThread
import com.brother.ptouch.sdk.Printer
import com.rouninlabs.another_brother.method.typeb.ITbPrinterAdapter
import com.rouninlabs.another_brother.receiver.UsbPermissionsReceiver
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit

/**
 * Tracker active printers to support the open/print/close approach.
 */
object BrotherManager {

    val mActivePrinters: MutableMap<String, Printer> = hashMapOf()
    val mActiveTypeBPrinters: MutableMap<String, ITbPrinterAdapter> = hashMapOf()

    /// Pending USB permission requests by device id. Guarded by synchronizing on the map.
    private val mUsbPermissionRequests: MutableMap<Int, UsbPermissionRequest> = hashMapOf()

    /// How long to wait for the user to answer the USB permission dialog before giving up.
    private const val USB_PERMISSION_TIMEOUT_SECONDS = 60L

    /**
     * A permission request that any number of threads can wait on.
     */
    private class UsbPermissionRequest {
        val answered = CountDownLatch(1)
        @Volatile var granted = false
    }

    fun getPrinter(printerId: String): Printer? {
        return mActivePrinters[printerId]
    }

    fun trackPrinter(printerId: String, printer: Printer) {
        mActivePrinters.put(printerId, printer)
    }

    fun untrackPrinter(printerId: String) {
        mActivePrinters.remove(printerId)
    }

    fun trackTypeBPrinter(printerId: String, printer: ITbPrinterAdapter) {
        mActiveTypeBPrinters.put(printerId, printer)
    }

    fun untrackTypeBPrinter(printerId: String) {
        mActiveTypeBPrinters.remove(printerId)
    }

    fun getTypeBPrinter(printerId: String): ITbPrinterAdapter? {
        return mActiveTypeBPrinters[printerId]
    }

    /**
     * Makes a permission request to get access to the usb device and blocks until the user
     * answers it. Concurrent requests for the same device share a single dialog.
     * Returns false if permission is denied or the user doesn't answer in time.
     */
    @WorkerThread
    fun requestUsbPermission(
        context: Context,
        usbManager: UsbManager,
        usbDevice: UsbDevice
    ): Boolean {
        if (usbManager.hasPermission(usbDevice)) {
            return true
        }

        val requestId = usbDevice.deviceId
        val request: UsbPermissionRequest
        val isNewRequest: Boolean
        synchronized(mUsbPermissionRequests) {
            val pending = mUsbPermissionRequests[requestId]
            isNewRequest = pending == null
            request = pending ?: UsbPermissionRequest().also { mUsbPermissionRequests[requestId] = it }
        }

        if (isNewRequest) {
            // The system adds EXTRA_DEVICE and EXTRA_PERMISSION_GRANTED to the intent when it
            // sends the result, so the PendingIntent must be mutable. The intent is explicit,
            // which keeps a mutable PendingIntent allowed on Android 14+.
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
            val intent = Intent(context, UsbPermissionsReceiver::class.java)
            usbManager.requestPermission(
                usbDevice,
                PendingIntent.getBroadcast(context, requestId, intent, flags)
            )
        }

        if (!request.answered.await(USB_PERMISSION_TIMEOUT_SECONDS, TimeUnit.SECONDS)) {
            synchronized(mUsbPermissionRequests) {
                if (mUsbPermissionRequests[requestId] === request) {
                    mUsbPermissionRequests.remove(requestId)
                }
            }
            return false
        }
        return request.granted
    }

    fun completePermissionRequest(usbDevice: UsbDevice, granted: Boolean) {
        val request = synchronized(mUsbPermissionRequests) {
            mUsbPermissionRequests.remove(usbDevice.deviceId)
        } ?: return

        request.granted = granted
        request.answered.countDown()
    }
}