# Geo Integrity Score Plugin

## Overview

Geo Integrity Score is a Flutter plugin that validates the trustworthiness of live GPS coordinates by combining operating system APIs, motion sensors, and environment hardening checks on Android and iOS. The plugin exposes a real-time detection stream and configurable monitoring policies to balance accuracy, responsiveness, and power consumption.

## Key Features

- Multi-layer fraud scoring (OS mock location APIs, sensor consistency, environment hardening).
- Real-time detection stream via `EventChannel` with immediate fraud callbacks.
- Configurable monitoring modes to tune sampling intervals and sensor warm-up behavior.
- Unified fraud score schema across Android and iOS for consistent downstream handling.
- Extensible architecture that keeps detection logic isolated from Flutter channel wiring.

## Detection Pipeline

1. Acquire the most recent location fix through `LocationManager` (Android) or `CLLocationManager` (iOS).
2. Execute OS-level mock location checks (Android) before sensor warm-up to quickly flag obvious spoofing.
3. Register accelerometer and barometer listeners based on the active `MonitoringPolicy` warm-up interval.
4. Evaluate motion and altitude consistency once sufficient sensor samples are collected.
5. Run environment hardening heuristics (emulator, root, jailbreak) to surface tampered runtimes.
6. Aggregate triggered checks into a fraud score and emit the normalized payload over the Flutter channel.

## Platform Requirements

### Android

- Minimum API level: 21.
- Manifest permissions: `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`.
- Optional: `ACCESS_BACKGROUND_LOCATION` if background monitoring is required.
- Services used: `LocationManager`, `SensorManager`, `AppOpsManager`.

### iOS

- Minimum deployment target: iOS 13.
- `Info.plist` keys: `NSLocationWhenInUseUsageDescription` (and optionally `NSLocationAlwaysAndWhenInUseUsageDescription`).
- Frameworks: `CoreLocation`, `CoreMotion`, `CoreBluetooth` (optional for future enhancements).

## Flutter API Surface

```dart
class GeoIntegrityScore {
  /// Emits detection events with the latest fraud score and detail map.
  static Stream<DetectionResult> get detectionStream;

  /// Starts the native monitoring pipeline with the provided policy.
  static Future<void> startMonitoring({
    MonitoringPolicy policy = MonitoringPolicy.balanced(),
  });

  /// Stops the native monitoring pipeline and releases sensors.
  static Future<void> stopMonitoring();

  /// Performs a single burst detection and returns the result once complete.
  static Future<DetectionResult> detectOnce({
    MonitoringPolicy? policyOverride,
  });
}

class DetectionResult {
  final DateTime timestamp;
  final int fraudScore;
  final Map<String, int> details;
  final String platform; // "android" or "ios"
}
```

### MonitoringPolicy

```dart
class MonitoringPolicy {
  final MonitoringMode mode;
  final Duration evaluationInterval;
  final Duration sensorWarmup;
  final bool autoStopOnIdle;
  final double speedThresholdOverride;

  const MonitoringPolicy._({
    required this.mode,
    required this.evaluationInterval,
    required this.sensorWarmup,
    required this.autoStopOnIdle,
    required this.speedThresholdOverride,
  });

  factory MonitoringPolicy.aggressive() => MonitoringPolicy._(
        mode: MonitoringMode.aggressive,
        evaluationInterval: const Duration(seconds: 1),
        sensorWarmup: const Duration(milliseconds: 300),
        autoStopOnIdle: false,
        speedThresholdOverride: 120.0,
      );

  factory MonitoringPolicy.balanced() => MonitoringPolicy._(
        mode: MonitoringMode.balanced,
        evaluationInterval: const Duration(seconds: 3),
        sensorWarmup: const Duration(milliseconds: 500),
        autoStopOnIdle: true,
        speedThresholdOverride: 100.0,
      );

  factory MonitoringPolicy.lowPower() => MonitoringPolicy._(
        mode: MonitoringMode.lowPower,
        evaluationInterval: const Duration(seconds: 8),
        sensorWarmup: const Duration(milliseconds: 800),
        autoStopOnIdle: true,
        speedThresholdOverride: 90.0,
      );

  factory MonitoringPolicy.onDemand() => MonitoringPolicy._(
        mode: MonitoringMode.onDemand,
        evaluationInterval: const Duration(seconds: 2),
        sensorWarmup: const Duration(milliseconds: 400),
        autoStopOnIdle: true,
        speedThresholdOverride: 100.0,
      );
}

enum MonitoringMode { aggressive, balanced, lowPower, onDemand }
```

### Monitoring Policies & Evaluation Timing

- Each native detector evaluates fraud once the configured `evaluationInterval` (Dart) / `evaluationIntervalMillis` (native) elapses.
- A rolling buffer of up to six recent locations is maintained to compute displacement and speed deltas.
- `sensorWarmup` values drive accelerometer sampling frequency before sensor inconsistency rules execute.
- When `autoStopOnIdle` is `true` and no checks fire for a cycle, monitoring stops to conserve resources.

### Usage Example

```dart
final subscription = GeoIntegrityScore.detectionStream.listen((event) {
  if (event.fraudScore >= 50) {
    // Notify user, trigger remediation, or block high-risk flows.
  }
});

await GeoIntegrityScore.startMonitoring(
  policy: MonitoringPolicy.balanced(),
);

// Later, when monitoring is no longer required.
await GeoIntegrityScore.stopMonitoring();
await subscription.cancel();
```

## Layered Fraud Checks

### Android Detection Layers

| Detail Key | Layer | Score | Trigger Criteria |
| --- | --- | --- | --- |
| `MOCK_PROVIDER` | OS API | +50 | `Location.isFromMockProvider()` returns `true` on API 18+. |
| `APP_OPS` | OS API | +30 | `AppOpsManager.OPSTR_MOCK_LOCATION` allows mock locations for the current package (API 23+). |
| `ALLOW_MOCK_SETTING` | OS API | +20 | `Settings.Secure.ALLOW_MOCK_LOCATION` equals `"1"` on API < 23. |
| `GEO_IMPOSSIBILITY` | Sensor | +35 to +50 | Derived speed exceeds 100 m/s or back-to-back fixes imply >1 000 km/h; score scales up to +50. |
| `MOTION_MISMATCH` | Sensor | +25 | Displacement ≥10 m without a meaningful accelerometer spike during the policy warm-up window. |
| `PRESSURE_MISMATCH` | Sensor | +15 | Altitude delta ≥50 m while the barometer remains within idle noise thresholds. |
| `EMULATOR_CHECK` | Environment | +15 | Build fingerprints or device identifiers match known emulator signatures. |
| `ROOT_JAILBREAK` | Environment | +20 | Root indicators such as `/system/bin/su` presence or `ro.secure=0` flag observed. |

### iOS Detection Layers

| Detail Key | Layer | Score | Trigger Criteria |
| --- | --- | --- | --- |
| `GEO_IMPOSSIBILITY` | Sensor | +35 | Current `CLLocation.speed` >100 m/s or derived speed between consecutive fixes >1 000 km/h. |
| `MOTION_MISMATCH` | Sensor | +25 | ≥10 m location delta without correlated accelerometer activity sampled via `CMMotionManager`. |
| `PRESSURE_MISMATCH` | Sensor | +15 | Altitude increase/decrease ≥50 m while `CMAltimeter` reports only idle-level pressure noise. |
| `EMULATOR_CHECK` | Environment | +15 | Build targets resolve `TARGET_OS_SIMULATOR` or related simulator heuristics. |
| `ROOT_JAILBREAK` | Environment | +20 | Jailbreak traces such as `/Applications/Cydia.app` paths, escapable sandbox checks, or URL scheme probes succeed. |

The final `fraudScore` is the sum of all triggered detail scores. Application logic should define remediation thresholds.

## Detection Result Payload

- `fraudScore` (`int`): Aggregated sum of all triggered checks.
- `details` (`Map<String, int>` / `[String: Int]`): Individual check keys and their contribution.
- `platform` (`String`): Either `"android"` or `"ios"`, mirroring the native emitter.
- `location` (optional map): Latest latitude/longitude plus accuracy, altitude, and speed when available.

Both native detectors publish identical schemas so downstream consumers can apply shared policies.

## Native Architecture Summary

### Android (Kotlin)

- `AndroidGpsDetector` orchestrates location acquisition, sensor sampling, and scoring.
- Components:
  1. `LocationProvider`: Retrieves latest GPS fix, validates permissions.
  2. `MockApiInspector`: Evaluates mock location APIs (`isFromMockProvider`, `AppOpsManager`, legacy settings).
  3. `SensorInconsistencyAnalyzer`: Uses `SensorManager` for accelerometer/barometer sampling and computes deltas.
  4. `EnvironmentHardeningInspector`: Checks emulator fingerprints and root traces.
- Results are emitted through an `EventChannel` sink; coroutine scopes ensure non-blocking evaluations.

### iOS (Swift)

- `IosGpsDetector` coordinates `CLLocationManager`, `CMMotionManager`, and `CMAltimeter`.
- Components:
  1. `LocationService`: Maintains delegate callbacks and buffers at least three recent locations.
  2. `MotionSampler`: Streams accelerometer/gyroscope data with configurable warm-up.
  3. `SensorInconsistencyAnalyzer`: Calculates speed, motion correlation, and pressure alignment.
  4. `EnvironmentHardeningInspector`: Detects simulators and jailbreak indicators.
- Native results are serialized to dictionaries and pushed through the same `EventChannel` schema.

## Performance & Power Considerations

- **Adaptive Sampling:** Each `MonitoringPolicy` defines evaluation intervals and sensor warm-up windows to reduce continuous high-frequency sampling.
- **Idle Auto-stop:** When no significant movement is detected for a policy-defined grace period, the native layer pauses sensor listeners until motion resumes.
- **Burst Detection:** `detectOnce` triggers a focused evaluation without keeping sensors active, ideal for check-in flows.
- **Lifecycle Awareness:** Native modules release resources on app pause/background; Flutter side should restart monitoring when resumes if required.
- **Data Smoothing:** Rolling averages and hysteresis thresholds mitigate noise-induced false positives before raising the fraud score.

## Error Handling

- `NO_PERMISSION`: Location permission missing or revoked mid-session.
- `LOCATION_UNAVAILABLE`: GPS fix cannot be acquired within the policy timeout.
- `SENSOR_TIMEOUT`: Motion sensor data not delivered within the expected warm-up window.
- `STREAM_CLOSED`: Event channel subscription was cancelled while monitoring is active.

Callers should handle these errors by prompting for permissions, retrying with relaxed policies, or aborting sensitive operations.

## Testing Strategy

- **Dart:** Use `MethodChannel` and `EventChannel` mocks to validate serialization, streaming behavior, and error propagation. Focus on stream subscription lifecycle tests and mapping to `DetectionResult` models.
- **Android:** Unit-test scoring functions with synthetic location/sensor inputs. Instrumented tests can verify integration with `LocationManager` and `SensorManager` using dependency injection.
- **iOS:** Unit-test speed and motion calculations in isolation. UI tests are not required; integration tests focus on verifying native-to-Flutter serialization.

## Roadmap

1. Implement Dart API contracts and mock-based tests.
2. Deliver Android native module with dependency injection-friendly structure.
3. Deliver iOS native module mirroring Android scoring schema.
4. Add optional background monitoring support once compliance considerations are addressed.
