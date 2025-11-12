package com.example.geo_integrity_score

import kotlin.math.max

data class MonitoringPolicy(
    val mode: String,
    val evaluationIntervalMillis: Long,
    val sensorWarmupMillis: Long,
    val autoStopOnIdle: Boolean,
    val speedThreshold: Double,
) {
    companion object {
        private const val DEFAULT_MODE = "balanced"
        private const val MIN_EVALUATION_INTERVAL_MS = 500L
        private const val DEFAULT_EVALUATION_INTERVAL_MS = 3_000L
        private const val DEFAULT_SENSOR_WARMUP_MS = 500L
        private const val DEFAULT_AUTO_STOP_ON_IDLE = true
        private const val DEFAULT_SPEED_THRESHOLD = 100.0

        fun fromMap(raw: Map<*, *>?): MonitoringPolicy {
            if (raw == null) {
                return balanced()
            }

            val mode = raw["mode"]?.toString() ?: DEFAULT_MODE
            val evaluationInterval = (raw["evaluationIntervalMillis"] as? Number)?.toLong()
                ?: DEFAULT_EVALUATION_INTERVAL_MS
            val warmup = (raw["sensorWarmupMillis"] as? Number)?.toLong()
                ?: DEFAULT_SENSOR_WARMUP_MS
            val autoStop = raw["autoStopOnIdle"] as? Boolean ?: DEFAULT_AUTO_STOP_ON_IDLE
            val speedThreshold = (raw["speedThreshold"] as? Number)?.toDouble()
                ?: DEFAULT_SPEED_THRESHOLD

            return MonitoringPolicy(
                mode = mode,
                evaluationIntervalMillis = max(MIN_EVALUATION_INTERVAL_MS, evaluationInterval),
                sensorWarmupMillis = max(0L, warmup),
                autoStopOnIdle = autoStop,
                speedThreshold = speedThreshold,
            )
        }

        fun aggressive(): MonitoringPolicy = MonitoringPolicy(
            mode = "aggressive",
            evaluationIntervalMillis = 1_000L,
            sensorWarmupMillis = 300L,
            autoStopOnIdle = false,
            speedThreshold = 120.0,
        )

        fun balanced(): MonitoringPolicy = MonitoringPolicy(
            mode = DEFAULT_MODE,
            evaluationIntervalMillis = DEFAULT_EVALUATION_INTERVAL_MS,
            sensorWarmupMillis = DEFAULT_SENSOR_WARMUP_MS,
            autoStopOnIdle = DEFAULT_AUTO_STOP_ON_IDLE,
            speedThreshold = DEFAULT_SPEED_THRESHOLD,
        )
    }
}
