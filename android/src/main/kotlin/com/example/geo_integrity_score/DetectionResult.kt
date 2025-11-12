package com.example.geo_integrity_score

data class DetectionLocation(
    val latitude: Double,
    val longitude: Double,
    val accuracyMeters: Float? = null,
    val altitudeMeters: Double? = null,
    val speedMetersPerSecond: Float? = null,
) {
    fun toMap(): Map<String, Any> {
        val payload = mutableMapOf<String, Any>(
            "latitude" to latitude,
            "longitude" to longitude,
        )
        accuracyMeters?.let { payload["accuracyMeters"] = it }
        altitudeMeters?.let { payload["altitudeMeters"] = it }
        speedMetersPerSecond?.let { payload["speedMetersPerSecond"] = it }
        return payload
    }

    companion object {
        fun fromMap(raw: Map<*, *>?): DetectionLocation? {
            if (raw == null) return null

            val latitude = (raw["latitude"] as? Number)?.toDouble() ?: return null
            val longitude = (raw["longitude"] as? Number)?.toDouble() ?: return null

            return DetectionLocation(
                latitude = latitude,
                longitude = longitude,
                accuracyMeters = (raw["accuracyMeters"] as? Number)?.toFloat(),
                altitudeMeters = (raw["altitudeMeters"] as? Number)?.toDouble(),
                speedMetersPerSecond = (raw["speedMetersPerSecond"] as? Number)?.toFloat(),
            )
        }
    }
}

data class DetectionResult(
    val timestampMillis: Long,
    val fraudScore: Int,
    val details: Map<String, Int>,
    val platform: String,
    val location: DetectionLocation? = null,
) {
    fun toMap(): Map<String, Any> {
        val payload = mutableMapOf<String, Any>(
            "timestamp" to timestampMillis,
            "fraudScore" to fraudScore,
            "details" to details,
            "platform" to platform,
        )
        location?.let { payload["location"] = it.toMap() }
        return payload
    }

    companion object {
        fun fromMap(raw: Map<*, *>?): DetectionResult? {
            if (raw == null) return null

            val timestamp = (raw["timestamp"] as? Number)?.toLong() ?: return null
            val score = (raw["fraudScore"] as? Number)?.toInt() ?: return null
            val detailEntries = (raw["details"] as? Map<*, *>)?.entries?.mapNotNull { entry ->
                val key = entry.key?.toString() ?: return@mapNotNull null
                val value = (entry.value as? Number)?.toInt() ?: return@mapNotNull null
                key to value
            } ?: emptyList()

            val platform = raw["platform"]?.toString() ?: "android"
            val location = DetectionLocation.fromMap(raw["location"] as? Map<*, *>)

            return DetectionResult(
                timestampMillis = timestamp,
                fraudScore = score,
                details = detailEntries.toMap(),
                platform = platform,
                location = location,
            )
        }
    }
}
