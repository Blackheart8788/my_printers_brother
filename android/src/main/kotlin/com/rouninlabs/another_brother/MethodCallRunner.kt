package com.rouninlabs.another_brother

import android.util.Log
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.util.concurrent.atomic.AtomicBoolean

private const val TAG = "another_brother"
const val NATIVE_ERROR_CODE = "NATIVE_ERROR"

/**
 * Runs the work of a method call on this scope. Any exception thrown by [block] is reported back
 * to Dart as a PlatformException instead of crashing the app.
 */
fun CoroutineScope.launchMethodCall(
    call: MethodCall,
    result: MethodChannel.Result,
    dispatcher: CoroutineDispatcher = Dispatchers.IO,
    block: suspend CoroutineScope.() -> Unit
): Job = launch(dispatcher) {
    try {
        block()
    } catch (e: CancellationException) {
        throw e
    } catch (e: Exception) {
        Log.e(TAG, "${call.method} failed", e)
        withContext(Dispatchers.Main) {
            result.error(NATIVE_ERROR_CODE, e.message ?: e.javaClass.simpleName, Log.getStackTraceString(e))
        }
    }
}

/**
 * Delivers only the first reply to [delegate]. Later replies are dropped, so an error reported
 * after a method call has already replied cannot throw "Reply already submitted".
 */
class SingleReplyResult(private val delegate: MethodChannel.Result) : MethodChannel.Result {
    private val replied = AtomicBoolean(false)

    override fun success(result: Any?) {
        if (claimReply()) delegate.success(result)
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        if (claimReply()) delegate.error(errorCode, errorMessage, errorDetails)
    }

    override fun notImplemented() {
        if (claimReply()) delegate.notImplemented()
    }

    private fun claimReply(): Boolean {
        val first = replied.compareAndSet(false, true)
        if (!first) {
            Log.w(TAG, "Dropping extra reply for a method call that already replied")
        }
        return first
    }
}
