import Foundation

struct MonitoringPolicy {
  let mode: String
  let evaluationInterval: TimeInterval
  let sensorWarmup: TimeInterval
  let autoStopOnIdle: Bool
  let speedThreshold: Double

  static func from(_ arguments: Any?) -> MonitoringPolicy {
    guard let map = arguments as? [String: Any] else {
      return .balanced
    }

    let mode = (map["mode"] as? String) ?? "balanced"
    let evaluationMillis = (map["evaluationIntervalMillis"] as? NSNumber)?.doubleValue ?? 3_000
    let warmupMillis = (map["sensorWarmupMillis"] as? NSNumber)?.doubleValue ?? 500
    let autoStop = (map["autoStopOnIdle"] as? NSNumber)?.boolValue ?? (map["autoStopOnIdle"] as? Bool) ?? true
    let threshold = (map["speedThreshold"] as? NSNumber)?.doubleValue ?? 100

    return MonitoringPolicy(
      mode: mode,
      evaluationInterval: max(0.5, evaluationMillis / 1_000),
      sensorWarmup: max(0, warmupMillis / 1_000),
      autoStopOnIdle: autoStop,
      speedThreshold: threshold
    )
  }

  static var balanced: MonitoringPolicy {
    MonitoringPolicy(
      mode: "balanced",
      evaluationInterval: 3,
      sensorWarmup: 0.5,
      autoStopOnIdle: true,
      speedThreshold: 100
    )
  }
}
