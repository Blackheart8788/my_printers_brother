package com.rouninlabs.another_brother.method.typeb

import android.content.Context
import com.brother.ptouch.sdk.Printer
import com.brother.ptouch.sdk.PrinterInfo
import com.brother.ptouch.sdk.PrinterStatus
import com.rouninlabs.another_brother.BrotherManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import com.rouninlabs.another_brother.launchMethodCall

/**
 * Command for Sending file to the printer.
 */
class TbSendFileMethodCall(val flutterAssets: FlutterPlugin.FlutterAssets, val context: Context, val call: MethodCall, val result: MethodChannel.Result, val scope: CoroutineScope) {
    companion object {
        const val METHOD_NAME = "typeB-sendFile"
    }

    fun execute() {

        scope.launchMethodCall(call, result) {

            val dartPrintInfo: HashMap<String, Any> = call.argument<HashMap<String, Any>>("printInfo")!!
            val printerId: String = call.argument<String>("printerId")!!
            val filePath = call.argument<String>("filePath")!!
            val brotherFileName = call.argument<String>("brotherFileName")!!

            
            val tbPrinter:ITbPrinterAdapter? = BrotherManager.getTypeBPrinter(printerId = printerId)

            if (tbPrinter == null) {
                withContext(Dispatchers.Main) {
                    // Set result Printer status.
                    result.success(false)
                }
                return@launchMethodCall
            }

            val success = tbPrinter.sendFile(filePath = filePath, brotherFileName = brotherFileName)
            
            if (!success) {
                withContext(Dispatchers.Main) {
                    // Set result Printer status.
                    result.success(false)
                }
                return@launchMethodCall
            }

            // On Success track printer
            withContext(Dispatchers.Main) {
               // Set result Printer status.
               result.success(true)
           }
        }

    }
}