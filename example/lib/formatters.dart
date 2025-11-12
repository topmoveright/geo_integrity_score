String formatLocalTimestamp(DateTime timestamp) {
  return timestamp.toLocal().toIso8601String();
}

String formatCoordinate(double value) => value.toStringAsFixed(5);

String formatDistance(double meters) => '${meters.toStringAsFixed(1)} m';

String formatAltitude(double meters) => '${meters.toStringAsFixed(1)} m';

String formatSpeed(double metersPerSecond) {
  final double kmh = metersPerSecond * 3.6;
  return '${metersPerSecond.toStringAsFixed(2)} m/s (${kmh.toStringAsFixed(1)} km/h)';
}
