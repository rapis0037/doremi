package com.cheesetabby.doremi

import android.os.Handler
import android.os.Looper
import com.cheesetabby.handtracking.HandTracker
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * 손 추적 모듈과 Flutter를 잇는 채널 등록만 한다.
 * 추론은 별도 스레드에서 돌린다 — 플랫폼 메인 스레드를 막으면 미리보기가 끊긴다.
 */
class MainActivity : FlutterActivity() {

    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    @Volatile private var tracker: HandTracker? = null
    @Volatile private var busy = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> initialize(result)
                    "detect" -> detect(call.arguments(), result)
                    "dispose" -> {
                        closeTracker()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun initialize(result: MethodChannel.Result) {
        worker.execute {
            try {
                closeTracker()
                tracker = HandTracker(applicationContext)
                main.post { result.success(true) }
            } catch (e: Throwable) {
                main.post { result.error("init_failed", e.message, null) }
            }
        }
    }

    private fun detect(args: Map<String, Any>?, result: MethodChannel.Result) {
        val tracker = this.tracker
        if (args == null || tracker == null) {
            result.success(null)
            return
        }
        // 앞 프레임이 아직 도는 중이면 버린다. 밀리면 지연만 쌓인다.
        if (busy) {
            result.success(null)
            return
        }
        busy = true

        val bytes = args["bytes"] as? ByteArray
        val width = args["width"] as? Int
        val height = args["height"] as? Int
        val rotation = args["rotation"] as? Int ?: 0
        val mirror = args["mirror"] as? Boolean ?: false
        val timestampMs = (args["timestampMs"] as? Number)?.toLong() ?: 0L

        if (bytes == null || width == null || height == null) {
            busy = false
            result.success(null)
            return
        }

        worker.execute {
            val payload = try {
                val found = tracker.detect(bytes, width, height, rotation, mirror, timestampMs)
                if (found == null) null else mapOf(
                    "landmarks" to found.landmarks,
                    "span" to found.span,
                    "confidence" to found.confidence,
                )
            } catch (e: Throwable) {
                null
            }
            busy = false
            main.post { result.success(payload) }
        }
    }

    private fun closeTracker() {
        tracker?.let {
            tracker = null
            try {
                it.close()
            } catch (_: Throwable) {
            }
        }
    }

    override fun onDestroy() {
        closeTracker()
        worker.shutdown()
        super.onDestroy()
    }

    companion object {
        private const val CHANNEL = "doremi/hand_tracking"
    }
}
