
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  static List<CameraDescription> cameras = <CameraDescription>[];

  static bool _isInitialized = false;

  static bool get isInitialized => _isInitialized;

  static bool get hasCamera => cameras.isNotEmpty;

  static Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    try {
      cameras = await availableCameras();
      _isInitialized = true;

      if (cameras.isEmpty) {
        debugPrint(
          'CameraService: No cameras are available on this device.',
        );
      } else {
        debugPrint(
          'CameraService: Initialized with ${cameras.length} camera(s).',
        );
      }
    } catch (error, stackTrace) {
      cameras = <CameraDescription>[];
      _isInitialized = false;

      debugPrint('CameraService: Camera initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      // Keep the application running if the camera is unavailable.
    }
  }
}
