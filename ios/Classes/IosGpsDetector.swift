import CoreLocation
import CoreMotion

final class IosGpsDetector: NSObject {
  private let locationManager = CLLocationManager()
  private let motionManager = CMMotionManager()
  private let altimeter = CMAltimeter()

  private var policy: MonitoringPolicy = .balanced
  private var callback: ((DetectionResult) -> Void)?

  private var locations: [CLLocation] = []
  private var latestLocation: CLLocation?

  private var monitoringActive = false
  private var lastEvaluation: Date = .distantPast

  override init() {
    super.init()
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
  }

  func startMonitoring(policy: MonitoringPolicy, callback: @escaping (DetectionResult) -> Void) {
    self.policy = policy
    self.callback = callback
    monitoringActive = true
    locations.removeAll()
    latestLocation = nil

    requestPermissionsIfNeeded()

    locationManager.startUpdatingLocation()
    startMotionUpdates()
  }

  func stopMonitoring() {
    monitoringActive = false
    callback = nil
    locationManager.stopUpdatingLocation()
    stopMotionUpdates()
    locations.removeAll()
    latestLocation = nil
  }

  func detectOnce(policy: MonitoringPolicy?) -> DetectionResult {
    let effectivePolicy = policy ?? .balanced
    let scoreDetails = ["POLICY_MODE": scoreForMode(effectivePolicy.mode)]
    let locationCandidate = locationManager.location ?? latestLocation
    let detectionLocation = locationCandidate.map(DetectionLocation.init)
    let timestamp = locationCandidate?.timestamp ?? Date()
    return DetectionResult(
      timestamp: timestamp,
      fraudScore: scoreDetails.values.reduce(0, +),
      details: scoreDetails,
      location: detectionLocation
    )
  }

  private func requestPermissionsIfNeeded() {
    switch CLLocationManager.authorizationStatus() {
    case .notDetermined:
      locationManager.requestWhenInUseAuthorization()
    default:
      break
    }
  }

  private func startMotionUpdates() {
    if motionManager.isAccelerometerAvailable {
      motionManager.accelerometerUpdateInterval = policy.sensorWarmup
      motionManager.startAccelerometerUpdates()
    }
    if CMAltimeter.isRelativeAltitudeAvailable() {
      altimeter.startRelativeAltitudeUpdates(to: .main) { _, _ in }
    }
  }

  private func stopMotionUpdates() {
    if motionManager.isAccelerometerActive {
      motionManager.stopAccelerometerUpdates()
    }
    if CMAltimeter.isRelativeAltitudeAvailable() {
      altimeter.stopRelativeAltitudeUpdates()
    }
  }

  private func evaluateIfNeeded() {
    guard monitoringActive else { return }
    guard let latest = locations.last else { return }

    let now = Date()
    guard now.timeIntervalSince(lastEvaluation) >= policy.evaluationInterval else { return }
    lastEvaluation = now

    var fraudScore = 0
    var details: [String: Int] = [:]

    if latest.speed > policy.speedThreshold { // meters per second
      fraudScore += 35
      details["GEO_IMPOSSIBILITY"] = 35
    }

    let detection = DetectionResult(
      timestamp: latest.timestamp,
      fraudScore: fraudScore,
      details: details,
      location: DetectionLocation(location: latest)
    )
    callback?(detection)

    if policy.autoStopOnIdle && fraudScore == 0 {
      stopMonitoring()
    }
  }

  private func scoreForMode(_ mode: String) -> Int {
    switch mode {
    case "aggressive":
      return 10
    case "lowPower":
      return 3
    default:
      return 5
    }
  }
}

extension IosGpsDetector: CLLocationManagerDelegate {
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    let detection = DetectionResult(
      fraudScore: 100,
      details: ["LOCATION_ERROR": 100]
    )
    callback?(detection)
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations newLocations: [CLLocation]) {
    locations.append(contentsOf: newLocations)
    if let lastLocation = newLocations.last {
      latestLocation = lastLocation
    }
    while locations.count > 6 {
      locations.removeFirst()
    }
    evaluateIfNeeded()
  }
}
