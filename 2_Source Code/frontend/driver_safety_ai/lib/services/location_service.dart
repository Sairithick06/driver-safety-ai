import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  /// Maximum acceptable GPS accuracy for route tracking.
  static const double maximumAccuracyMeters = 100.0;

  /// Minimum movement required before accepting another route point.
  static const int minimumDistanceMeters = 10;

  /// Last accepted GPS position for route tracking.
  Position? _lastAcceptedRoutePosition;

  // ---------------------------------------------------------------------------
  // LOCATION SERVICE STATUS
  // ---------------------------------------------------------------------------

  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  // ---------------------------------------------------------------------------
  // PERMISSION
  // ---------------------------------------------------------------------------

  Future<LocationPermission> checkPermission() async {
    return Geolocator.checkPermission();
  }

  Future<LocationPermission> requestPermission() async {
    return Geolocator.requestPermission();
  }

  Future<bool> hasLocationPermission() async {
    final permission = await Geolocator.checkPermission();

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  // ---------------------------------------------------------------------------
  // LOCATION VALIDATION
  // ---------------------------------------------------------------------------

  bool validatePosition(Position position) {
    final latitude = position.latitude;
    final longitude = position.longitude;
    final accuracy = position.accuracy;

    final isValidLatitude =
        latitude.isFinite && latitude >= -90.0 && latitude <= 90.0;

    final isValidLongitude =
        longitude.isFinite && longitude >= -180.0 && longitude <= 180.0;

    final isValidAccuracy = accuracy.isFinite && accuracy >= 0.0;

    final isValid =
        isValidLatitude && isValidLongitude && isValidAccuracy;

    if (isValid) {
      debugPrint(
        'LOCATION VALIDATION PASSED | '
        'Lat: $latitude | '
        'Lng: $longitude | '
        'Accuracy: ${accuracy.toStringAsFixed(2)}m',
      );
    } else {
      debugPrint(
        'LOCATION VALIDATION FAILED | '
        'Lat: $latitude | '
        'Lng: $longitude | '
        'Accuracy: $accuracy',
      );
    }

    return isValid;
  }

  // ---------------------------------------------------------------------------
  // ACCURACY FILTER
  // ---------------------------------------------------------------------------

  Position? filterPosition(Position position) {
    if (!validatePosition(position)) {
      debugPrint(
        'LOCATION FILTERING: Position rejected by validation.',
      );

      return null;
    }

    if (position.accuracy > maximumAccuracyMeters) {
      debugPrint(
        'LOCATION FILTERING: Position rejected | '
        'Accuracy: ${position.accuracy.toStringAsFixed(2)}m | '
        'Maximum allowed: '
        '${maximumAccuracyMeters.toStringAsFixed(2)}m',
      );

      return null;
    }

    debugPrint(
      'LOCATION FILTERING: Accuracy accepted | '
      'Accuracy: ${position.accuracy.toStringAsFixed(2)}m',
    );

    return position;
  }

  // ---------------------------------------------------------------------------
  // ROUTE POINT PROCESSING
  // ---------------------------------------------------------------------------

  /// Processes a GPS position for route tracking.
  ///
  /// A position is accepted when:
  ///
  /// 1. Latitude and longitude are valid.
  /// 2. GPS accuracy is within the allowed limit.
  /// 3. The vehicle has moved at least the minimum distance
  ///    from the previously accepted route point.
  ///
  /// The first valid route point is always accepted.
  Position? processRoutePosition(Position position) {
    final filteredPosition = filterPosition(position);

    if (filteredPosition == null) {
      debugPrint(
        'ROUTE POINT: Rejected because GPS accuracy/validation failed.',
      );

      return null;
    }

    // Accept the first valid route point.
    if (_lastAcceptedRoutePosition == null) {
      _lastAcceptedRoutePosition = filteredPosition;

      debugPrint(
        'ROUTE POINT: First route point accepted | '
        'Lat: ${filteredPosition.latitude} | '
        'Lng: ${filteredPosition.longitude}',
      );

      return filteredPosition;
    }

    // Calculate movement from the previous accepted route point.
    final distance = Geolocator.distanceBetween(
      _lastAcceptedRoutePosition!.latitude,
      _lastAcceptedRoutePosition!.longitude,
      filteredPosition.latitude,
      filteredPosition.longitude,
    );

    // Ignore insignificant movement.
    if (distance < minimumDistanceMeters) {
      debugPrint(
        'ROUTE POINT: Rejected because movement is too small | '
        'Distance: ${distance.toStringAsFixed(2)}m | '
        'Minimum required: ${minimumDistanceMeters}m',
      );

      return null;
    }

    // Accept the new route point.
    _lastAcceptedRoutePosition = filteredPosition;

    debugPrint(
      'ROUTE POINT: Accepted | '
      'Distance from previous point: ${distance.toStringAsFixed(2)}m | '
      'Lat: ${filteredPosition.latitude} | '
      'Lng: ${filteredPosition.longitude}',
    );

    return filteredPosition;
  }

  // ---------------------------------------------------------------------------
  // RESET ROUTE TRACKING
  // ---------------------------------------------------------------------------

  /// Clears the previous route point.
  ///
  /// This should be called when a new trip starts.
  void resetRouteTracking() {
    _lastAcceptedRoutePosition = null;

    debugPrint(
      'ROUTE POINT: Route tracking reset.',
    );
  }

  // ---------------------------------------------------------------------------
  // CURRENT GPS POSITION
  // ---------------------------------------------------------------------------

  /// Gets the current GPS position after basic validation.
  ///
  /// This method does NOT apply the route accuracy filter
  /// or the route distance filter.
  Future<Position?> getCurrentPosition() async {
    try {
      final serviceEnabled = await isLocationServiceEnabled();

      if (!serviceEnabled) {
        debugPrint(
          'LOCATION: Location service is disabled.',
        );

        return null;
      }

      var permission = await checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await requestPermission();
      }

      if (permission == LocationPermission.denied) {
        debugPrint(
          'LOCATION: Permission denied.',
        );

        return null;
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint(
          'LOCATION: Permission permanently denied.',
        );

        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!validatePosition(position)) {
        debugPrint(
          'LOCATION: Current position failed validation.',
        );

        return null;
      }

      debugPrint(
        'LOCATION: Current position received | '
        'Lat: ${position.latitude} | '
        'Lng: ${position.longitude} | '
        'Accuracy: ${position.accuracy.toStringAsFixed(2)}m',
      );

      return position;
    } catch (e) {
      debugPrint(
        'LOCATION: Failed to get current position: $e',
      );

      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // FILTERED CURRENT POSITION FOR ROUTE USE
  // ---------------------------------------------------------------------------

  /// Gets the current GPS position and processes it as a route point.
  Future<Position?> getFilteredCurrentPosition() async {
    final position = await getCurrentPosition();

    if (position == null) {
      return null;
    }

    return processRoutePosition(position);
  }

  // ---------------------------------------------------------------------------
  // GPS POSITION STREAM
  // ---------------------------------------------------------------------------

  /// Returns GPS positions suitable for route tracking.
  ///
  /// Each incoming GPS position passes through:
  ///
  /// GPS position
  ///      ↓
  /// validation
  ///      ↓
  /// accuracy filtering
  ///      ↓
  /// distance filtering
  ///      ↓
  /// accepted route point
  Stream<Position> getPositionStream() async* {
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: minimumDistanceMeters,
    );

    await for (final position in Geolocator.getPositionStream(
      locationSettings: locationSettings,
    )) {
      final processedPosition = processRoutePosition(position);

      if (processedPosition != null) {
        yield processedPosition;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // LOCATION SETTINGS
  // ---------------------------------------------------------------------------

  Future<bool> openLocationSettings() async {
    return Geolocator.openLocationSettings();
  }

  Future<bool> openAppSettings() async {
    return Geolocator.openAppSettings();
  }
}