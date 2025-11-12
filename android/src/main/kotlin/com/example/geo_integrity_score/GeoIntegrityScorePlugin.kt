package com.example.geo_integrity_score

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class GeoIntegrityScorePlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {

    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private val mainHandler = Handler(Looper.getMainLooper())

    private var detector: AndroidGpsDetector? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(binding.binaryMessenger, METHOD_CHANNEL_NAME)
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL_NAME)
        eventChannel.setStreamHandler(this)

        detector = AndroidGpsDetector(binding.applicationContext, mainHandler)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        detector?.stopMonitoring()
        detector = null
        eventSink = null
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            METHOD_START_MONITORING -> handleStartMonitoring(call, result)
            METHOD_STOP_MONITORING -> handleStopMonitoring(result)
            METHOD_DETECT_ONCE -> handleDetectOnce(call, result)
            else -> result.notImplemented()
        }
    }

    private fun handleStartMonitoring(call: MethodCall, result: Result) {
        val policy = MonitoringPolicy.fromMap(call.arguments as? Map<*, *>)
        val detectorInstance = detector ?: run {
            result.error("NO_DETECTOR", "Detector is not initialized", null)
            return
        }
        detectorInstance.startMonitoring(policy) { detection ->
            dispatchDetection(detection)
        }
        result.success(null)
    }

    private fun handleStopMonitoring(result: Result) {
        detector?.stopMonitoring()
        result.success(null)
    }

    private fun handleDetectOnce(call: MethodCall, result: Result) {
        val policy = MonitoringPolicy.fromMap(call.arguments as? Map<*, *>)
        val detection = detector?.detectOnce(policy)
        if (detection == null) {
            result.error("NO_DETECTOR", "Detector is not initialized", null)
        } else {
            result.success(detection.toMap())
        }
    }

    private fun dispatchDetection(detection: DetectionResult) {
        mainHandler.post {
            eventSink?.success(detection.toMap())
        }
    }

    companion object {
        private const val METHOD_CHANNEL_NAME = "geo_integrity_score"
        private const val EVENT_CHANNEL_NAME = "geo_integrity_score/events"
        private const val METHOD_START_MONITORING = "startMonitoring"
        private const val METHOD_STOP_MONITORING = "stopMonitoring"
        private const val METHOD_DETECT_ONCE = "detectOnce"
    }
}
