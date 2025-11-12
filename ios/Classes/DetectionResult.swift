import Foundation
import CoreLocation

struct DetectionLocation {
  let latitude: Double
  let longitude: Double
  let accuracyMeters: Double?
  let altitudeMeters: Double?
  let speedMetersPerSecond: Double?

  init(location: CLLocation) {
    latitude = location.coordinate.latitude
    longitude = location.coordinate.longitude
    accuracyMeters = location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil
    altitudeMeters = location.verticalAccuracy >= 0 ? location.altitude : nil
    speedMetersPerSecond = location.speed >= 0 ? location.speed : nil
  }

  func toDictionary() -> [String: Any] {
    var payload: [String: Any] = [
      "latitude": latitude,
      "longitude": longitude,
    ]
    if let accuracy = accuracyMeters {
      payload["accuracyMeters"] = accuracy
    }
    if let altitude = altitudeMeters {
      payload["altitudeMeters"] = altitude
    }
    if let speed = speedMetersPerSecond {
      payload["speedMetersPerSecond"] = speed
    }
    return payload
  }
}

struct DetectionResult {
  let timestamp: Date
  let fraudScore: Int
  let details: [String: Int]
  let platform: String
  let location: DetectionLocation?

  init(
    timestamp: Date = Date(),
    fraudScore: Int,
    details: [String: Int],
    platform: String = "ios",
    location: DetectionLocation? = nil
  ) {
    self.timestamp = timestamp
    self.fraudScore = fraudScore
    self.details = details
    self.platform = platform
    self.location = location
  }

  func toDictionary() -> [String: Any] {
    var payload: [String: Any] = [
      "timestamp": Int(timestamp.timeIntervalSince1970 * 1000),
      "fraudScore": fraudScore,
      "details": details,
      "platform": platform,
    ]
    if let locationPayload = location?.toDictionary() {
      payload["location"] = locationPayload
    }
    return payload
  }
}
