import CoreLocation
import Flutter
import UIKit

public final class GeoIntegrityScorePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private enum Method: String {
    case startMonitoring
    case stopMonitoring
    case detectOnce
  }

  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?
  private var detector: IosGpsDetector?
  private var eventSink: FlutterEventSink?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = GeoIntegrityScorePlugin()
    instance.configure(with: registrar)
  }

  private func configure(with registrar: FlutterPluginRegistrar) {
    let methodChannel = FlutterMethodChannel(name: "geo_integrity_score", binaryMessenger: registrar.messenger())
    let eventChannel = FlutterEventChannel(name: "geo_integrity_score/events", binaryMessenger: registrar.messenger())

    registrar.addMethodCallDelegate(self, channel: methodChannel)
    eventChannel.setStreamHandler(self)

    self.methodChannel = methodChannel
    self.eventChannel = eventChannel
    self.detector = IosGpsDetector()
  }

  public func detach(fromEngine registrar: FlutterPluginRegistrar) {
    methodChannel?.setMethodCallHandler(nil)
    eventChannel?.setStreamHandler(nil)
    detector?.stopMonitoring()
    detector = nil
    eventSink = nil
  }

  // MARK: - FlutterMethodCall handling

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let method = Method(rawValue: call.method) else {
      result(FlutterMethodNotImplemented)
      return
    }

    guard let detector = detector else {
      result(FlutterError(code: "NO_DETECTOR", message: "Detector is not initialized", details: nil))
      return
    }

    switch method {
    case .startMonitoring:
      let policy = MonitoringPolicy.from(call.arguments)
      detector.startMonitoring(policy: policy) { [weak self] detection in
        self?.emit(detection)
      }
      result(nil)

    case .stopMonitoring:
      detector.stopMonitoring()
      result(nil)

    case .detectOnce:
      let policy = MonitoringPolicy.from(call.arguments)
      let detection = detector.detectOnce(policy: policy)
      result(detection.toDictionary())
    }
  }

  // MARK: - FlutterStreamHandler

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  private func emit(_ detection: DetectionResult) {
    guard let sink = eventSink else { return }
    DispatchQueue.main.async {
      sink(detection.toDictionary())
    }
  }
}
