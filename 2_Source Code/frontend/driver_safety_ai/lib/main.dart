
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/splash/splash_screen.dart';
import 'services/camera_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const DriverSafetyAI());

  // Camera enumeration is supported on mobile and desktop platforms.
  // Web uses its own browser camera permissions and APIs.
  if (!kIsWeb) {
    await CameraService.initialize();

    if (CameraService.hasCamera) {
      debugPrint('Camera initialized successfully.');
    } else {
      debugPrint(
        'No camera available. The application will continue.',
      );
    }
  } else {
    debugPrint(
      'Web platform detected. Camera initialization is deferred.',
    );
  }
}

class DriverSafetyAI extends StatelessWidget {
  const DriverSafetyAI({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Driver Safety AI',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
