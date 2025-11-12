package com.example.geo_integrity_score

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Handler
import android.os.SystemClock
import java.util.concurrent.CopyOnWriteArrayList
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

class AndroidGpsDetector(
    private val context: Context,
    private val handler: Handler,
) : SensorEventListener, LocationListener {

    private val locationManager: LocationManager?
        get() = context.getSystemService(Context.LOCATION_SERVICE) as? LocationManager

    private val sensorManager: SensorManager?
        get() = context.getSystemService(Context.SENSOR_SERVICE) as? SensorManager

    private val accelerometerValues = FloatArray(3)
    private val pressureValues = FloatArray(3)
    private val recentLocations = CopyOnWriteArrayList<Location>()

    private var monitoringPolicy: MonitoringPolicy = MonitoringPolicy.balanced()
    private var monitoringActive = false
    private var monitoringCallback: ((DetectionResult) -> Unit)? = null
    private var lastEvaluationRealtime = 0L

    fun startMonitoring(policy: MonitoringPolicy, callback: (DetectionResult) -> Unit) {
        monitoringPolicy = policy
        monitoringCallback = callback
        monitoringActive = true
        lastEvaluationRealtime = 0L

        registerListeners()
    }

    fun stopMonitoring() {
        monitoringActive = false
        monitoringCallback = null
        recentLocations.clear()

        locationManager?.removeUpdates(this)
        sensorManager?.unregisterListener(this)
    }

    fun detectOnce(policy: MonitoringPolicy?): DetectionResult {
        val effectivePolicy = policy ?: MonitoringPolicy.balanced()
        val now = System.currentTimeMillis()
        val detectionLocation = lastKnownLocation()?.toDetectionLocation()

        val policyScore = when (effectivePolicy.mode) {
            "aggressive" -> 10
            "lowPower" -> 3
            else -> 5
        }

        return DetectionResult(
            timestampMillis = now,
            fraudScore = policyScore,
            details = mapOf("POLICY_MODE" to policyScore),
            platform = "android",
            location = detectionLocation,
        )
    }

    override fun onLocationChanged(location: Location) {
        if (!monitoringActive) return

        recentLocations.add(location)
        while (recentLocations.size > MAX_LOCATION_HISTORY) {
            recentLocations.removeAt(0)
        }

        val nowRealtime = SystemClock.elapsedRealtime()
        if (nowRealtime - lastEvaluationRealtime >= monitoringPolicy.evaluationIntervalMillis) {
            lastEvaluationRealtime = nowRealtime
            evaluateAndDispatch()
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (!monitoringActive) return

        when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> {
                for (i in 0..2) {
                    accelerometerValues[i] = event.values[i]
                }
            }
            Sensor.TYPE_PRESSURE -> {
                for (i in 0..2) {
                    pressureValues[i] = event.values[i]
                }
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onProviderEnabled(provider: String) = Unit

    override fun onProviderDisabled(provider: String) = Unit

    override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit

    private fun registerListeners() {
        val locationProvider = LocationManager.GPS_PROVIDER
        try {
            locationManager?.requestLocationUpdates(
                locationProvider,
                monitoringPolicy.evaluationIntervalMillis,
                0f,
                this,
                handler.looper,
            )
        } catch (securityException: SecurityException) {
            monitoringCallback?.invoke(
                DetectionResult(
                    timestampMillis = System.currentTimeMillis(),
                    fraudScore = ERROR_SCORE,
                    details = mapOf("NO_PERMISSION" to ERROR_SCORE),
                    platform = "android",
                ),
            )
            return
        }

        val sensorMgr = sensorManager ?: return
        sensorMgr.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.let {
            sensorMgr.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME, handler)
        }
        sensorMgr.getDefaultSensor(Sensor.TYPE_PRESSURE)?.let {
            sensorMgr.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL, handler)
        }
    }

    private fun evaluateAndDispatch() {
        val latest = recentLocations.lastOrNull() ?: return
        val scoreBuilder = mutableMapOf<String, Int>()
        var fraudScore = 0

        if (latest.isFromMockProvider) {
            fraudScore += MOCK_PROVIDER_SCORE
            scoreBuilder["MOCK_PROVIDER"] = MOCK_PROVIDER_SCORE
        }

        computeSpeedScore()?.let {
            fraudScore += it
            scoreBuilder["GEO_IMPOSSIBILITY"] = it
        }

        val locationPayload = latest.toDetectionLocation()

        monitoringCallback?.invoke(
            DetectionResult(
                timestampMillis = latest.time,
                fraudScore = fraudScore,
                details = scoreBuilder.toMap(),
                platform = "android",
                location = locationPayload,
            ),
        )

        if (monitoringPolicy.autoStopOnIdle && fraudScore == 0) {
            stopMonitoring()
        }
    }

    private fun computeSpeedScore(): Int? {
        if (recentLocations.size < 2) return null
        val latest = recentLocations.last()
        val previous = recentLocations[recentLocations.size - 2]

        val distance = latest.distanceTo(previous)
        val timeDelta = max(1.0, (latest.time - previous.time).toDouble() / 1000.0)
        val speed = distance / timeDelta

        return if (speed > monitoringPolicy.speedThreshold) {
            val capped = min(MAX_GEO_IMPOSSIBILITY_SCORE, ((speed / monitoringPolicy.speedThreshold) * 10).toInt())
            max(capped, GEO_IMPOSSIBILITY_BASE_SCORE)
        } else {
            null
        }
    }

    private fun Location.toDetectionLocation(): DetectionLocation {
        return DetectionLocation(
            latitude = latitude,
            longitude = longitude,
            accuracyMeters = if (hasAccuracy()) accuracy else null,
            altitudeMeters = if (hasAltitude()) altitude else null,
            speedMetersPerSecond = if (hasSpeed()) speed else null,
        )
    }

    private fun lastKnownLocation(): Location? {
        val manager = locationManager ?: return null
        val providers = listOf(
            LocationManager.GPS_PROVIDER,
            LocationManager.NETWORK_PROVIDER,
            LocationManager.PASSIVE_PROVIDER,
        )

        return providers.mapNotNull { provider ->
            try {
                manager.getLastKnownLocation(provider)
            } catch (securityException: SecurityException) {
                null
            }
        }.maxByOrNull { it.time }
    }

    companion object {
        private const val MAX_LOCATION_HISTORY = 6
        private const val ERROR_SCORE = 100
        private const val MOCK_PROVIDER_SCORE = 50
        private const val GEO_IMPOSSIBILITY_BASE_SCORE = 35
        private const val MAX_GEO_IMPOSSIBILITY_SCORE = 50
    }
}
