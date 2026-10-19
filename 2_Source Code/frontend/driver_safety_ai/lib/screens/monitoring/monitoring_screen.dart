import 'dart:async';



import 'package:camera/camera.dart';

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';



import '../../services/api_service.dart';

import '../../services/camera_service.dart';

import '../../services/monitoring_session_service.dart';

import '../../alert_system/alert_engine.dart';

import '../../alert_system/notification_service.dart';

import '../../alert_system/alert_rules.dart';



class MonitoringScreen extends StatefulWidget {

  final String accountId;



  const MonitoringScreen({

    super.key,

    this.accountId = '',

  });



  @override

  State<MonitoringScreen> createState() => _MonitoringScreenState();

}



class _MonitoringScreenState extends State<MonitoringScreen> {

  // ============================================================

  // COLORS

  // ============================================================



  static const Color backgroundColor = Color(0xff08111F);

  static const Color panelColor = Color(0xff111827);

  static const Color cardColor = Color(0xff151D2D);

  static const Color borderColor = Color(0xff23324A);



  static const Color greenColor = Color(0xff4ADE80);

  static const Color redColor = Color(0xffEF4444);

  static const Color orangeColor = Color(0xffF59E0B);

  static const Color blueColor = Color(0xff3B82F6);

  static const Color cyanColor = Color(0xff06B6D4);

  static const Color purpleColor = Color(0xffA855F7);



  // ============================================================

  // CAMERA

  // ============================================================



  CameraController? _controller;



  bool _isReady = false;

  bool _isProcessing = false;

  bool _isStopping = false;
  bool _isSwitchingCamera = false;



  // ============================================================

  // SESSION

  // ============================================================



  DateTime? _sessionStartTime;



  // ============================================================

  // MONITORING TIMER

  // ============================================================



  Timer? _monitorTimer;



  static const Duration captureInterval =

      Duration(milliseconds: 250);



  // ============================================================

  // LIVE VALUES

  // ============================================================



  String eyes = "Waiting";

  String yawning = "Waiting";

  String fatigue = "Waiting";

  String alert = "Waiting for driver";



  String blinkCount = "0";

  String blinkRate = "0";



  String faceStatus = "No Face Detected";

  String headPosition = "Waiting";

  String closedDuration = "0.00";



  String message = "";



  String lastAnalysis = "Waiting";



  // ============================================================

  // ALERT STATE

  // ============================================================



  AlertLevel _alertLevel = AlertLevel.safe;



  // ============================================================

  // ALERT ENGINE + NOTIFICATIONS

  // ============================================================



  final AlertEngine _alertEngine = AlertEngine();

  final NotificationService _notificationService =

      NotificationService.instance;



  // ============================================================

  // INIT

  // ============================================================



  @override

  void initState() {

    super.initState();



    _initializeCamera();

  }



  // ============================================================

  // CAMERA INITIALIZATION

  // ============================================================



  Future<void> _initializeCamera() async {
    if (_isStopping) return;

    try {
      // On web, main.dart intentionally defers camera initialization.
      // Initialize here when the Monitoring screen is opened, so the
      // browser can enumerate cameras in the context of this screen.
      if (CameraService.cameras.isEmpty) {
        debugPrint('MONITORING: No cached cameras; initializing camera service.');
        await CameraService.initialize();
      }

      if (!mounted || _isStopping) return;

      final List<CameraDescription> available = CameraService.cameras;
      debugPrint('MONITORING: Camera discovery returned ${available.length} camera(s).');

      if (available.isEmpty) {
        debugPrint(
          'MONITORING: No camera was discovered. Check browser permission and camera availability.',
        );
        if (mounted) {
          setState(() {
            _isReady = false;
            faceStatus = 'Camera Not Available';
            alert = 'Camera unavailable';
            lastAnalysis = 'Camera initialization failed';
          });
        }
        return;
      }

      // Driver monitoring should prefer the front-facing / built-in webcam.
      // If the platform does not label a camera as front-facing, use the first.
      final CameraDescription selectedCamera = available.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => available.first,
      );

      debugPrint(
        'MONITORING: Initializing camera "${selectedCamera.name}" '
        '(direction: ${selectedCamera.lensDirection}).',
      );

      final CameraController controller = CameraController(
        selectedCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );
      _controller = controller;

      await controller.initialize();

      if (!mounted || _isStopping) {
        await controller.dispose();
        if (identical(_controller, controller)) _controller = null;
        return;
      }

      setState(() {
        _isReady = true;
        _sessionStartTime = DateTime.now();
        faceStatus = 'Waiting for face';
        alert = 'Waiting for driver';
        lastAnalysis = 'Camera ready; waiting for analysis';
      });

      MonitoringSessionService.instance.startSession();
      _alertEngine.startNewRide();

      if (widget.accountId.trim().isNotEmpty) {
        _notificationService.setAccountId(widget.accountId.trim());
      } else {
        debugPrint(
          'MONITORING: No account ID supplied; email alerts cannot be addressed to a driver.',
        );
      }

      debugPrint('MONITORING: Camera initialized; monitoring session started.');
      _startMonitoring();
    } catch (error, stackTrace) {
      debugPrint('MONITORING: Camera initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      final failedController = _controller;
      _controller = null;
      try {
        await failedController?.dispose();
      } catch (disposeError) {
        debugPrint('MONITORING: Camera cleanup failed: $disposeError');
      }

      if (mounted && !_isStopping) {
        setState(() {
          _isReady = false;
          faceStatus = 'Camera Not Available';
          alert = 'Camera unavailable';
          lastAnalysis = 'Camera initialization failed';
        });
      }
    }
  }


  // ============================================================

  // SWITCH FRONT / REAR CAMERA

  // ============================================================

  Future<void> _switchCamera() async {
    if (_isStopping || _isSwitchingCamera || CameraService.cameras.length < 2) {
      if (mounted && CameraService.cameras.length < 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("This device has only one available camera."),
          ),
        );
      }
      return;
    }

    final CameraController? previousController = _controller;
    if (previousController == null || !previousController.value.isInitialized) {
      return;
    }

    final CameraLensDirection currentDirection =
        previousController.description.lensDirection;
    final CameraLensDirection targetDirection =
        currentDirection == CameraLensDirection.front
            ? CameraLensDirection.back
            : CameraLensDirection.front;

    CameraDescription? targetCamera;
    for (final camera in CameraService.cameras) {
      if (camera.lensDirection == targetDirection) {
        targetCamera = camera;
        break;
      }
    }

    if (targetCamera == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              targetDirection == CameraLensDirection.front
                  ? "Front camera is not available on this device."
                  : "Rear camera is not available on this device.",
            ),
          ),
        );
      }
      return;
    }

    _monitorTimer?.cancel();
    _monitorTimer = null;
    _isSwitchingCamera = true;

    if (mounted) {
      setState(() {
        _isReady = false;
      });
    }

    // Allow any in-flight photo capture / API detection to finish before
    // releasing the camera currently in use.
    int waitCount = 0;
    while (_isProcessing && waitCount < 100 && !_isStopping) {
      await Future.delayed(const Duration(milliseconds: 100));
      waitCount++;
    }

    if (_isStopping || !mounted) {
      _isSwitchingCamera = false;
      return;
    }

    if (_isProcessing) {
      _isSwitchingCamera = false;
      setState(() {
        _isReady = true;
      });
      _startMonitoring();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Camera is busy. Please try switching again."),
        ),
      );
      return;
    }

    CameraController? nextController;
    try {
      await previousController.dispose();
      _controller = null;

      nextController = CameraController(
        targetCamera,
        ResolutionPreset.low,
        enableAudio: false,
      );
      _controller = nextController;
      await nextController.initialize();

      if (!mounted || _isStopping) {
        await nextController.dispose();
        return;
      }

      setState(() {
        _isReady = true;
      });

      _isSwitchingCamera = false;
      _startMonitoring();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            targetDirection == CameraLensDirection.front
                ? "Front camera enabled."
                : "Rear camera enabled.",
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      debugPrint("Camera switch error: $e");
      try {
        await nextController?.dispose();
      } catch (_) {}

      // Attempt to restore the camera that was active before the switch.
      try {
        final restoredController = CameraController(
          previousController.description,
          ResolutionPreset.low,
          enableAudio: false,
        );
        _controller = restoredController;
        await restoredController.initialize();

        if (mounted && !_isStopping) {
          setState(() {
            _isReady = true;
          });
          _startMonitoring();
        }
      } catch (restoreError) {
        debugPrint("Camera restore error: $restoreError");
        _controller = null;
        if (mounted && !_isStopping) {
          setState(() {
            _isReady = false;
          });
        }
      }

      if (mounted && !_isStopping) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Could not switch camera. Please try again."),
          ),
        );
      }
    } finally {
      _isSwitchingCamera = false;
    }
  }


  // ============================================================

  // START MONITORING

  // ============================================================



  void _startMonitoring() {

    _monitorTimer?.cancel();



    // Run immediately.

    _captureAndDetect();



    // Continue monitoring.

    _monitorTimer = Timer.periodic(

      captureInterval,

      (_) {

        if (!_isStopping) {

          _captureAndDetect();

        }

      },

    );

  }



  // ============================================================

  // CAPTURE + DETECT

  // ============================================================



  Future<void> _captureAndDetect() async {

    if (_isStopping) {

      return;

    }



    if (!_isReady) {

      return;

    }



    final CameraController? controller = _controller;



    if (controller == null) {

      return;

    }



    if (!controller.value.isInitialized) {

      return;

    }



    // Prevent overlapping API requests.

    if (_isProcessing) {

      return;

    }



    _isProcessing = true;



    try {

      // ========================================================

      // CAPTURE IMAGE

      // ========================================================



      final XFile image = await controller.takePicture();



      if (_isStopping) {

        return;

      }



      dynamic imageData;



      // ========================================================

      // WEB

      // ========================================================



      if (kIsWeb) {

        imageData = await image.readAsBytes();

      } else {

        imageData = image;

      }



      if (_isStopping) {

        return;

      }



      // ========================================================

      // SEND TO FASTAPI

      // ========================================================



      final result = await ApiService.detect(imageData);



      if (!mounted || _isStopping) {

        return;

      }



      debugPrint("API RESPONSE: $result");



      // ========================================================

      // ALERT ENGINE

      // ========================================================

      // The detector result is passed directly to the alert engine.

      // The engine is responsible for confirmation, incident state,

      // notification frequency, and critical escalation timing.

      // ========================================================



      final generatedAlerts = _alertEngine.processDetection(

        Map<String, dynamic>.from(result),

      );



      for (final driverAlert in generatedAlerts) {

        debugPrint(

          "ALERT ENGINE: "

          "${driverAlert.severity.name.toUpperCase()} | "

          "${driverAlert.ruleName} | "

          "${driverAlert.message}",

        );

      }



      // Dispatch only alerts actually generated by the engine.

      // The engine prevents repeated notifications for the same

      // active incident.

      if (generatedAlerts.isNotEmpty) {

        await _notificationService.dispatchAlerts(

          generatedAlerts,

        );



        // Show the actual in-app notification only when the

        // Safety Notifications setting is enabled.

        final bool notificationsEnabled =

            await _notificationService.areNotificationsEnabled();



        if (notificationsEnabled) {

          for (final driverAlert in generatedAlerts) {

            if (driverAlert.actions.contains(

              AlertAction.appNotification,

            )) {

              _showInAppNotification(driverAlert);

            }

          }

        }

      }



      // ========================================================

      // FACE

      // ========================================================



      final bool faceDetected =

          result["face_detected"] == true;



      // ========================================================

      // API VALUES

      // ========================================================



      final String newEyes =

          (result["eyes"] ?? "Waiting").toString();



      final String newYawning =

          (result["yawning"] ?? "Waiting").toString();



      final String newFatigue =

          (result["fatigue"] ?? "Low").toString();



      final String newAlert =

          (result["alert"] ?? "Waiting for driver").toString();



      final String newBlinkCount =

          (result["blink_count"] ?? 0).toString();



      final String newBlinkRate =

          (result["blink_rate"] ?? 0).toString();



      final String newHeadPosition =

          (result["head_position"] ?? "Waiting").toString();



      final String newClosedDuration =

          _formatNumber(

        result["closed_duration"] ?? 0,

      );



      final String newMessage =

          (result["message"] ?? "").toString();



      // ========================================================

      // DETERMINE ALERT LEVEL

      // ========================================================



      final AlertLevel newAlertLevel =

          _getAlertLevel(

        faceDetected: faceDetected,

        alertValue: newAlert,

        fatigueValue: newFatigue,

        eyesValue: newEyes,

        yawningValue: newYawning,

        headPositionValue: newHeadPosition,

      );



      // ========================================================

      // SAVE ANALYSIS

      // ========================================================



      _saveAnalysisToSession(

        faceDetected: faceDetected,

        eyesValue: faceDetected

            ? newEyes

            : "No Face",

        yawningValue: faceDetected

            ? newYawning

            : "No Face",

        fatigueValue: faceDetected

            ? newFatigue

            : "High",

        alertValue: faceDetected

            ? newAlert

            : "Danger",

        blinkCountValue: newBlinkCount,

        blinkRateValue: newBlinkRate,

        headPositionValue: faceDetected

            ? newHeadPosition

            : "No Face",

        closedDurationValue: newClosedDuration,

        messageValue: newMessage,

      );



      // ========================================================

      // UPDATE UI

      // ========================================================



      if (!mounted || _isStopping) {

        return;

      }



      setState(() {

        // ------------------------------------------------------

        // FACE

        // ------------------------------------------------------



        faceStatus = faceDetected

            ? "Face Detected"

            : "No Face Detected";



        // ------------------------------------------------------

        // EYES

        // ------------------------------------------------------



        eyes = faceDetected

            ? newEyes

            : "No Face";



        // ------------------------------------------------------

        // YAWNING

        // ------------------------------------------------------



        yawning = faceDetected

            ? newYawning

            : "No Face";



        // ------------------------------------------------------

        // FATIGUE

        // ------------------------------------------------------



        fatigue = faceDetected

            ? newFatigue

            : "High";



        // ------------------------------------------------------

        // ALERT

        // ------------------------------------------------------



        alert = faceDetected

            ? newAlert

            : "Danger";



        // ------------------------------------------------------

        // BLINK COUNT

        // ------------------------------------------------------



        blinkCount = newBlinkCount;



        // ------------------------------------------------------

        // BLINK RATE

        // ------------------------------------------------------



        blinkRate = newBlinkRate;



        // ------------------------------------------------------

        // HEAD POSITION

        // ------------------------------------------------------



        headPosition = faceDetected

            ? newHeadPosition

            : "No Face";



        // ------------------------------------------------------

        // CLOSED DURATION

        // ------------------------------------------------------



        closedDuration = newClosedDuration;



        // ------------------------------------------------------

        // MESSAGE

        // ------------------------------------------------------



        message = newMessage;



        // ------------------------------------------------------

        // LAST ANALYSIS

        // ------------------------------------------------------



        lastAnalysis = _currentTime();



        // ------------------------------------------------------

        // ALERT LEVEL

        // ------------------------------------------------------



        _alertLevel = newAlertLevel;

      });

    } catch (e) {

      if (!_isStopping) {

        debugPrint("Detection Error: $e");

      }

    } finally {

      _isProcessing = false;

    }

  }



  // ============================================================

  // IN-APP NOTIFICATION

  // ============================================================



  void _showInAppNotification(DriverAlert driverAlert) {

    if (!mounted || _isStopping) {

      return;

    }



    final Color notificationColor =

        driverAlert.severity == AlertSeverity.critical

            ? redColor

            : driverAlert.severity == AlertSeverity.high

                ? orangeColor

                : blueColor;



    final String severityText =

        driverAlert.severity.name.toUpperCase();



    ScaffoldMessenger.of(context)

      ..hideCurrentSnackBar()

      ..showSnackBar(

        SnackBar(

          duration: const Duration(seconds: 5),

          backgroundColor: notificationColor,

          behavior: SnackBarBehavior.floating,

          margin: const EdgeInsets.fromLTRB(

            20,

            0,

            20,

            20,

          ),

          content: Row(

            children: [

              Icon(

                driverAlert.severity == AlertSeverity.critical

                    ? Icons.error_outline

                    : driverAlert.severity == AlertSeverity.high

                        ? Icons.warning_amber_rounded

                        : Icons.notifications_active_outlined,

                color: Colors.white,

              ),

              const SizedBox(width: 12),

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    Text(

                      '$severityText: ${driverAlert.ruleName}',

                      style: const TextStyle(

                        color: Colors.white,

                        fontWeight: FontWeight.bold,

                      ),

                    ),

                    const SizedBox(height: 3),

                    Text(

                      driverAlert.message,

                      style: const TextStyle(

                        color: Colors.white,

                      ),

                    ),

                  ],

                ),

              ),

            ],

          ),

        ),

      );

  }



  // ============================================================

  // ALERT LEVEL

  // ============================================================



  AlertLevel _getAlertLevel({

    required bool faceDetected,

    required String alertValue,

    required String fatigueValue,

    required String eyesValue,

    required String yawningValue,

    required String headPositionValue,

  }) {

    // No face means monitoring cannot reliably evaluate the driver.

    // Keep this as WARNING at the UI level; the AlertEngine separately

    // confirms continuous face loss before sending an alert.

    if (!faceDetected) {

      return AlertLevel.warning;

    }



    final String alertText =

        alertValue.trim().toLowerCase();



    final String fatigueText =

        fatigueValue.trim().toLowerCase();



    final String eyesText =

        eyesValue.trim().toLowerCase();



    final String yawningText =

        yawningValue.trim().toLowerCase();



    final String headText =

        headPositionValue.trim().toLowerCase();



    // ============================================================

    // COMBINED HIGH-RISK CONDITION

    // ============================================================

    // Evaluate the CURRENT detector result, not the previous UI

    // values. Both eyes closed together with active yawning is a

    // stronger fatigue signal and must immediately raise the UI

    // to the critical safety level.

    final bool bothEyesClosed =

        eyesText == "closed" ||

        (eyesText.contains("closed") &&

            !eyesText.contains("one eye"));



    final bool activeYawn =

        yawningText == "yes" ||

        yawningText.contains("yes");



    if (bothEyesClosed && activeYawn) {

      return AlertLevel.critical;

    }



    // Critical UI state from the CURRENT detector response.

    if (alertText.contains("danger") ||

        alertText.contains("critical") ||

        fatigueText.contains("high")) {

      return AlertLevel.critical;

    }



    // Warning UI state from the CURRENT detector response.

    if (alertText.contains("warning") ||

        fatigueText.contains("moderate") ||

        fatigueText.contains("medium") ||

        eyesText.contains("closed") ||

        activeYawn ||

        headText.contains("down") ||

        headText.contains("left") ||

        headText.contains("right")) {

      return AlertLevel.warning;

    }



    return AlertLevel.safe;

  }



  // ============================================================

  // SAVE ANALYSIS

  // ============================================================



  void _saveAnalysisToSession({

    required bool faceDetected,

    required String eyesValue,

    required String yawningValue,

    required String fatigueValue,

    required String alertValue,

    required String blinkCountValue,

    required String blinkRateValue,

    required String headPositionValue,

    required String closedDurationValue,

    required String messageValue,

  }) {

    try {

      MonitoringSessionService.instance.addAnalysis(

        faceDetected: faceDetected,

        eyes: eyesValue,

        yawning: yawningValue,

        fatigue: fatigueValue,

        alert: alertValue,

        blinkCount: blinkCountValue,

        blinkRate: blinkRateValue,

        headPosition: headPositionValue,

        closedDuration: closedDurationValue,

        message: messageValue,

      );

    } catch (e) {

      debugPrint(

        "Session analysis save error: $e",

      );

    }

  }



  // ============================================================

  // FORMAT NUMBER

  // ============================================================



  String _formatNumber(dynamic value) {

    try {

      final double number =

          double.parse(value.toString());



      return number.toStringAsFixed(2);

    } catch (_) {

      return "0.00";

    }

  }



  // ============================================================

  // CURRENT TIME

  // ============================================================



  String _currentTime() {

    final DateTime now = DateTime.now();



    int hour = now.hour;



    final String minute =

        now.minute.toString().padLeft(2, '0');



    final String period =

        hour >= 12 ? "PM" : "AM";



    hour = hour % 12;



    if (hour == 0) {

      hour = 12;

    }



    return "$hour:$minute $period";

  }



  // ============================================================

  // SESSION DURATION

  // ============================================================



  String _sessionDuration() {

    if (_sessionStartTime == null) {

      return "0s";

    }



    final Duration duration =

        DateTime.now().difference(

      _sessionStartTime!,

    );



    if (duration.inSeconds < 60) {

      return "${duration.inSeconds}s";

    }



    final int minutes =

        duration.inMinutes;



    final int seconds =

        duration.inSeconds % 60;



    return "${minutes}m ${seconds}s";

  }



  // ============================================================

  // STOP MONITORING

  // ============================================================



  Future<void> _stopMonitoring() async {

    if (_isStopping) {

      return;

    }



    _isStopping = true;



    debugPrint("Stopping monitoring...");



    // ----------------------------------------------------------

    // STOP TIMER

    // ----------------------------------------------------------



    _monitorTimer?.cancel();

    _monitorTimer = null;



    // ----------------------------------------------------------

    // WAIT FOR CURRENT DETECTION

    // ----------------------------------------------------------



    int waitCount = 0;



    while (_isProcessing && waitCount < 40) {

      await Future.delayed(

        const Duration(milliseconds: 50),

      );



      waitCount++;

    }



    // ----------------------------------------------------------

    // END SESSION

    // ----------------------------------------------------------



    try {

      final session =

          MonitoringSessionService.instance.endSession(

        endTime: DateTime.now(),

      );



      if (session != null) {

        debugPrint(

          "Monitoring session saved.",

        );



        debugPrint(

          "Session duration: "

          "${session.duration.inSeconds}s",

        );



        debugPrint(

          "Analyses: "

          "${session.totalAnalyses}",

        );



        debugPrint(

          "Warnings: "

          "${session.warningCount}",

        );



        debugPrint(

          "Critical: "

          "${session.criticalCount}",

        );

      }

    } catch (e) {

      debugPrint(

        "Session end/save error: $e",

      );

    }



    // ----------------------------------------------------------

    // DISPOSE CAMERA

    // ----------------------------------------------------------



    final CameraController? controller =

        _controller;



    _controller = null;



    if (controller != null) {

      try {

        if (controller.value.isInitialized) {

          await controller.dispose();

        }

      } catch (e) {

        debugPrint(

          "Camera dispose error: $e",

        );

      }

    }



    _isReady = false;



    // ----------------------------------------------------------

    // RETURN

    // ----------------------------------------------------------



    if (!mounted) {

      return;

    }



    Navigator.pop(context);

  }



  // ============================================================

  // DISPOSE

  // ============================================================



  @override

  void dispose() {

    _isStopping = true;



    _monitorTimer?.cancel();

    _monitorTimer = null;



    final CameraController? controller =

        _controller;



    _controller = null;



    if (controller != null) {

      controller.dispose();

    }



    super.dispose();

  }



  // ============================================================

  // BUILD

  // ============================================================



  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: backgroundColor,



      // ========================================================

      // APP BAR

      // ========================================================



      appBar: AppBar(

        backgroundColor:

            const Color(0xff102033),



        elevation: 0,



        leading: IconButton(

          icon: const Icon(

            Icons.arrow_back,

            color: Colors.white,

          ),

          onPressed:

              _isStopping

                  ? null

                  : _stopMonitoring,

        ),



        title: const Text(

          "AI Monitoring",

          style: TextStyle(

            color: Colors.white,

            fontSize: 28,

            fontWeight: FontWeight.bold,

          ),

        ),



        actions: [

          Padding(

            padding:

                const EdgeInsets.only(

              right: 18,

            ),

            child:

                _buildTopLiveIndicator(),

          ),

        ],

      ),



      // ========================================================

      // BODY

      // ========================================================



      body: SafeArea(

        child: LayoutBuilder(

          builder: (

            context,

            constraints,

          ) {

            return Column(

              children: [



                // ==================================================

                // ALERT BANNER

                // ==================================================



                Padding(

                  padding:

                      const EdgeInsets.fromLTRB(

                    20,

                    16,

                    20,

                    0,

                  ),

                  child:

                      _buildSafetyAlert(),

                ),



                // ==================================================

                // MAIN CONTENT

                // ==================================================



                Expanded(

                  child: Padding(

                    padding:

                        const EdgeInsets.all(

                      20,

                    ),

                    child:

                        _buildMainLayout(

                      constraints.maxWidth,

                      constraints.maxHeight,

                    ),

                  ),

                ),



                // ==================================================

                // STOP BUTTON

                // ==================================================



                Padding(

                  padding:

                      const EdgeInsets.fromLTRB(

                    20,

                    0,

                    20,

                    20,

                  ),

                  child:

                      _buildStopButton(),

                ),

              ],

            );

          },

        ),

      ),

    );

  }



  // ============================================================

  // TOP LIVE INDICATOR

  // ============================================================



  Widget _buildTopLiveIndicator() {

    return Container(

      padding:

          const EdgeInsets.symmetric(

        horizontal: 14,

        vertical: 8,

      ),



      decoration: BoxDecoration(

        color:

            redColor.withOpacity(0.10),



        borderRadius:

            BorderRadius.circular(22),



        border: Border.all(

          color:

              redColor.withOpacity(0.45),

        ),

      ),



      child: Row(

        mainAxisSize:

            MainAxisSize.min,



        children: [

          Container(

            width: 8,

            height: 8,



            decoration:

                const BoxDecoration(

              color: redColor,

              shape: BoxShape.circle,

            ),

          ),



          const SizedBox(width: 8),



          const Text(

            "LIVE",

            style: TextStyle(

              color: redColor,

              fontSize: 13,

              fontWeight: FontWeight.bold,

            ),

          ),

        ],

      ),

    );

  }



  // ============================================================

  // SAFETY ALERT

  // ============================================================



  Widget _buildSafetyAlert() {

    final Color color =

        _alertLevel.color;



    final IconData icon =

        _alertLevel.icon;



    final String title =

        _alertLevel.title;



    final String subtitle =

        _alertLevel.subtitle(

      fatigue: fatigue,

      eyes: eyes,

      headPosition: headPosition,

    );



    return AnimatedContainer(

      duration:

          const Duration(milliseconds: 250),



      width: double.infinity,



      padding:

          const EdgeInsets.symmetric(

        horizontal: 18,

        vertical: 13,

      ),



      decoration: BoxDecoration(

        color:

            color.withOpacity(0.10),



        borderRadius:

            BorderRadius.circular(16),



        border: Border.all(

          color:

              color.withOpacity(0.55),

        ),

      ),



      child: Row(

        children: [

          Container(

            width: 42,

            height: 42,



            decoration:

                BoxDecoration(

              color:

                  color.withOpacity(0.16),



              shape:

                  BoxShape.circle,

            ),



            child: Icon(

              icon,

              color: color,

              size: 23,

            ),

          ),



          const SizedBox(width: 14),



          Expanded(

            child: Column(

              crossAxisAlignment:

                  CrossAxisAlignment.start,



              children: [

                Text(

                  title,

                  style: TextStyle(

                    color: color,

                    fontSize: 14,

                    fontWeight:

                        FontWeight.bold,

                    letterSpacing: 0.4,

                  ),

                ),



                const SizedBox(height: 3),



                Text(

                  subtitle,

                  maxLines: 1,

                  overflow:

                      TextOverflow.ellipsis,



                  style: const TextStyle(

                    color: Colors.white70,

                    fontSize: 12,

                  ),

                ),

              ],

            ),

          ),



          // STATUS DOT



          Container(

            width: 9,

            height: 9,



            decoration:

                BoxDecoration(

              color: color,

              shape:

                  BoxShape.circle,

            ),

          ),

        ],

      ),

    );

  }



  // ============================================================

  // MAIN RESPONSIVE LAYOUT

  // ============================================================



  Widget _buildMainLayout(double width, double height) {
    // Breakpoints use the width available to this screen, not the device model.
    // Phones use a vertical, scrollable layout; wider screens use two panels.
    final double availableWidth = width;
    final bool useWideLayout = availableWidth >= 900;
    final double horizontalGap = availableWidth >= 1200 ? 24 : 16;

    if (useWideLayout) {
      final double analysisWidth = (availableWidth * 0.38).clamp(340.0, 440.0);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildCameraPanel(),
          ),
          SizedBox(width: horizontalGap),
          SizedBox(
            width: analysisWidth,
            child: _buildAnalysisPanel(scrollable: true),
          ),
        ],
      );
    }

    final double cameraHeight = (availableWidth * 0.68).clamp(220.0, 380.0);
    return SingleChildScrollView(
      primary: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: cameraHeight,
            child: _buildCameraPanel(),
          ),
          const SizedBox(height: 16),
          _buildAnalysisPanel(scrollable: false),
        ],
      ),
    );
  }

    Widget _buildCameraPanel() {

    return Container(

      decoration:

          BoxDecoration(

        color: panelColor,



        borderRadius:

            BorderRadius.circular(22),



        border: Border.all(

          color: borderColor,

        ),

      ),



      child: ClipRRect(

        borderRadius:

            BorderRadius.circular(22),



        child: Stack(

          fit: StackFit.expand,



          children: [

            // ====================================================

            // CAMERA

            // ====================================================



            if (_isReady &&

                _controller != null)

              _buildCameraPreview()

            else

              const Center(

                child:

                    CircularProgressIndicator(),

              ),



            // ====================================================

            // LIVE BADGE

            // ====================================================



            Positioned(

              top: 18,

              left: 18,

              child:

                  _buildCameraLiveBadge(),

            ),

            Positioned(
              top: 14,
              right: 14,
              child: Material(
                color: Colors.black.withOpacity(0.72),
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: (_isStopping || _isSwitchingCamera)
                      ? null
                      : _switchCamera,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 76),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.75),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSwitchingCamera)
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Icon(
                            Icons.cameraswitch_outlined,
                            color: Colors.white,
                            size: 23,
                          ),
                        const SizedBox(height: 4),
                        Text(
                          _isSwitchingCamera
                              ? "Switching"
                              : "Switch\nCamera",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),



            // ====================================================

            // CAMERA CORNERS

            // ====================================================



            Positioned(

              top: 42,

              left: 42,

              child: _corner(

                top: true,

                left: true,

              ),

            ),



            Positioned(

              top: 42,

              right: 42,

              child: _corner(

                top: true,

                left: false,

              ),

            ),



            Positioned(

              bottom: 42,

              left: 42,

              child: _corner(

                top: false,

                left: true,

              ),

            ),



            Positioned(

              bottom: 42,

              right: 42,

              child: _corner(

                top: false,

                left: false,

              ),

            ),



            // ====================================================

            // CAMERA SAFETY STATUS

            // ====================================================



            Positioned(

              left: 18,

              right: 18,

              bottom: 18,

              child:

                  _buildCameraSafetyStrip(),

            ),

          ],

        ),

      ),

    );

  }



  // ============================================================

  // CAMERA PREVIEW

  // ============================================================



  Widget _buildCameraPreview() {
    final CameraController? controller = _controller;

    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    // CameraPreview is constrained to the panel's available area. Cover keeps
    // the preview legible without forcing the sensor image into a wrong ratio.
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.previewSize?.height ?? 640,
          height: controller.value.previewSize?.width ?? 480,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

    Widget _buildCameraLiveBadge() {

    return Container(

      padding:

          const EdgeInsets.symmetric(

        horizontal: 14,

        vertical: 8,

      ),



      decoration:

          BoxDecoration(

        color:

            Colors.black.withOpacity(0.65),



        borderRadius:

            BorderRadius.circular(22),

      ),



      child: Row(

        mainAxisSize:

            MainAxisSize.min,



        children: [

          Container(

            width: 9,

            height: 9,



            decoration:

                const BoxDecoration(

              color: redColor,

              shape:

                  BoxShape.circle,

            ),

          ),



          const SizedBox(width: 7),



          const Text(

            "LIVE",

            style: TextStyle(

              color: Colors.white,

              fontSize: 13,

              fontWeight:

                  FontWeight.bold,

            ),

          ),

        ],

      ),

    );

  }



  // ============================================================

  // CAMERA SAFETY STRIP

  // ============================================================



  Widget _buildCameraSafetyStrip() {

    final Color color =

        _alertLevel.color;



    return Container(

      padding:

          const EdgeInsets.symmetric(

        horizontal: 14,

        vertical: 10,

      ),



      decoration: BoxDecoration(

        color:

            Colors.black.withOpacity(0.72),



        borderRadius:

            BorderRadius.circular(12),



        border: Border.all(

          color:

              color.withOpacity(0.65),

        ),

      ),



      child: Row(

        children: [

          Icon(

            _alertLevel.icon,

            color: color,

            size: 19,

          ),



          const SizedBox(width: 9),



          Expanded(

            child: Text(

              "Driver Safety: "

              "${_alertLevel.shortTitle}",

              style: TextStyle(

                color: color,

                fontSize: 13,

                fontWeight:

                    FontWeight.bold,

              ),

            ),

          ),



          Text(

            _sessionDuration(),

            style:

                const TextStyle(

              color: Colors.white54,

              fontSize: 12,

            ),

          ),

        ],

      ),

    );

  }



  // ============================================================

  // CAMERA CORNER

  // ============================================================



  Widget _corner({

    required bool top,

    required bool left,

  }) {

    return SizedBox(

      width: 48,

      height: 48,



      child: CustomPaint(

        painter:

            _CornerPainter(

          top: top,

          left: left,

        ),

      ),

    );

  }



  // ============================================================

  // ANALYSIS PANEL

  // ============================================================



  Widget _buildAnalysisPanel({bool scrollable = true}) {
    final Widget analysisContent = Padding(
      padding: const EdgeInsets.all(18),
      child: Column(

            children: [

              // ==================================================

              // SYSTEM STATUS

              // ==================================================



              _buildStatusHeader(),



              const SizedBox(

                height: 18,

              ),



              // ==================================================

              // LIVE ANALYSIS TITLE

              // ==================================================



              Row(

                children: [

                  Container(

                    width: 4,

                    height: 22,



                    decoration:

                        BoxDecoration(

                      color: cyanColor,



                      borderRadius:

                          BorderRadius.circular(

                        4,

                      ),

                    ),

                  ),



                  const SizedBox(width: 9),



                  const Text(

                    "Live Analysis",

                    style: TextStyle(

                      color: Colors.white,

                      fontSize: 21,

                      fontWeight:

                          FontWeight.bold,

                    ),

                  ),

                ],

              ),



              const SizedBox(

                height: 16,

              ),



              // ==================================================

              // ANALYSIS GRID

              // ==================================================



              _buildAnalysisGrid(),



              // ==================================================

              // MESSAGE

              // ==================================================



              if (message.isNotEmpty) ...[

                const SizedBox(height: 16),



                _buildMessageCard(),

              ],



              // ==================================================

              // SAFETY TIP

              // ==================================================



              const SizedBox(height: 16),



              _buildTipCard(),

            ],

          ),
    );

    return Container(
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: scrollable
            ? SingleChildScrollView(
                primary: false,
                child: analysisContent,
              )
            : analysisContent,
      ),
    );
  }


  // ============================================================

  // STATUS HEADER

  // ============================================================



  Widget _buildStatusHeader() {

    return Container(

      width: double.infinity,



      padding:

          const EdgeInsets.all(14),



      decoration:

          BoxDecoration(

        color:

            const Color(0xff0D1728),



        borderRadius:

            BorderRadius.circular(16),



        border: Border.all(

          color: borderColor,

        ),

      ),



      child: Row(

        children: [

          Expanded(

            child: _statusItem(

              Icons.smart_toy_outlined,

              "AI",

              "Connected",

              greenColor,

            ),

          ),



          Container(

            width: 1,

            height: 38,

            color: borderColor,

          ),



          Expanded(

            child: _statusItem(

              Icons.videocam_outlined,

              "Camera",

              _isReady

                  ? "Active"

                  : "Inactive",

              blueColor,

            ),

          ),



          Container(

            width: 1,

            height: 38,

            color: borderColor,

          ),



          Expanded(

            child: _statusItem(

              Icons.cloud_done_outlined,

              "Backend",

              "Online",

              greenColor,

            ),

          ),

        ],

      ),

    );

  }



  // ============================================================

  // STATUS ITEM

  // ============================================================



  Widget _statusItem(

    IconData icon,

    String title,

    String value,

    Color color,

  ) {

    return Column(

      children: [

        Icon(

          icon,

          color: color,

          size: 21,

        ),



        const SizedBox(

          height: 5,

        ),



        Text(

          title,

          style:

              const TextStyle(

            color: Colors.white54,

            fontSize: 11,

          ),

        ),



        const SizedBox(

          height: 2,

        ),



        Text(

          value,

          overflow:

              TextOverflow.ellipsis,



          style: TextStyle(

            color: color,

            fontSize: 11,

            fontWeight:

                FontWeight.bold,

          ),

        ),

      ],

    );

  }



  // ============================================================

  // ANALYSIS GRID

  // ============================================================



  Widget _buildAnalysisGrid() {

    return Column(

      children: [

        // ========================================================

        // FACE + EYES

        // ========================================================



        Row(

          children: [

            Expanded(

              child:

                  _analysisCard(

                icon:

                    Icons.face_outlined,

                title: "Face",

                value: faceStatus,

                color:

                    faceStatus ==

                            "Face Detected"

                        ? greenColor

                        : redColor,

              ),

            ),



            const SizedBox(

              width: 12,

            ),



            Expanded(

              child:

                  _analysisCard(

                icon:

                    Icons.remove_red_eye_outlined,

                title: "Eyes",

                value: eyes,

                color:

                    eyes.toLowerCase()

                            .contains("closed")

                        ? redColor

                        : greenColor,

              ),

            ),

          ],

        ),



        const SizedBox(

          height: 12,

        ),



        // ========================================================

        // YAWNING + FATIGUE

        // ========================================================



        Row(

          children: [

            Expanded(

              child:

                  _analysisCard(

                icon:

                    Icons.sentiment_dissatisfied_outlined,

                title: "Yawning",

                value: yawning,

                color:

                    yawning.toLowerCase()

                            .contains("yes")

                        ? orangeColor

                        : blueColor,

              ),

            ),



            const SizedBox(

              width: 12,

            ),



            Expanded(

              child:

                  _analysisCard(

                icon:

                    Icons.battery_alert_outlined,

                title: "Fatigue",

                value: fatigue,

                color:

                    _fatigueColor(),

              ),

            ),

          ],

        ),



        const SizedBox(

          height: 12,

        ),



        // ========================================================

        // ALERT + BLINK RATE

        // ========================================================



        Row(

          children: [

            Expanded(

              child:

                  _analysisCard(

                icon:

                    Icons.shield_outlined,

                title: "Alert",

                value: alert,

                color:

                    _alertColor(),

              ),

            ),



            const SizedBox(

              width: 12,

            ),



            Expanded(

              child:

                  _analysisCard(

                icon:

                    Icons.visibility_outlined,

                title: "Blink Rate",

                value:

                    "$blinkRate/min",

                color:

                    purpleColor,

              ),

            ),

          ],

        ),



        const SizedBox(

          height: 12,

        ),



        // ========================================================

        // HEAD + CLOSED DURATION

        // ========================================================



        Row(

          children: [

            Expanded(

              child:

                  _analysisCard(

                icon:

                    Icons.directions_car_outlined,

                title: "Head",

                value:

                    headPosition,

                color:

                    cyanColor,

              ),

            ),



            const SizedBox(

              width: 12,

            ),



            Expanded(

              child:

                  _analysisCard(

                icon:

                    Icons.timer_outlined,

                title:

                    "Closed Duration",

                value:

                    "$closedDuration sec",

                color:

                    orangeColor,

              ),

            ),

          ],

        ),



        const SizedBox(

          height: 12,

        ),



        // ========================================================

        // UPDATED + TOTAL BLINKS

        // ========================================================



        Row(

          children: [

            Expanded(

              child:

                  _analysisCard(

                icon:

                    Icons.access_time,

                title: "Updated",

                value:

                    lastAnalysis,

                color:

                    blueColor,

              ),

            ),



            const SizedBox(

              width: 12,

            ),



            Expanded(

              child:

                  _analysisCard(

                icon:

                    Icons.remove_red_eye,

                title:

                    "Total Blinks",

                value:

                    blinkCount,

                color:

                    purpleColor,

              ),

            ),

          ],

        ),

      ],

    );

  }



  // ============================================================

  // ANALYSIS CARD

  // ============================================================



  Widget _analysisCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool compact = constraints.maxWidth < 150;
        final double cardPadding = compact ? 10 : 14;
        return Container(
          constraints: const BoxConstraints(minHeight: 118),
          padding: EdgeInsets.all(cardPadding),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: compact ? 34 : 40,
                height: compact ? 34 : 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: color, size: compact ? 19 : 22),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                softWrap: true,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                softWrap: true,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontSize: compact ? 14 : 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

    Color _fatigueColor() {

    switch (fatigue.toLowerCase()) {

      case "high":

        return redColor;



      case "medium":

      case "moderate":

        return orangeColor;



      case "low":

        return greenColor;



      default:

        return Colors.white70;

    }

  }



  // ============================================================

  // ALERT COLOR

  // ============================================================



  Color _alertColor() {

    switch (_alertLevel) {

      case AlertLevel.critical:

        return redColor;



      case AlertLevel.warning:

        return orangeColor;



      case AlertLevel.safe:

        return greenColor;

    }

  }



  // ============================================================

  // MESSAGE CARD

  // ============================================================



  Widget _buildMessageCard() {

    final Color color =

        _alertLevel.color;



    return Container(

      width: double.infinity,



      padding:

          const EdgeInsets.all(14),



      decoration:

          BoxDecoration(

        color:

            color.withOpacity(0.08),



        borderRadius:

            BorderRadius.circular(14),



        border: Border.all(

          color:

              color.withOpacity(0.30),

        ),

      ),



      child: Row(

        crossAxisAlignment:

            CrossAxisAlignment.start,



        children: [

          Icon(

            _alertLevel.icon,

            color: color,

            size: 21,

          ),



          const SizedBox(

            width: 10,

          ),



          Expanded(

            child: Text(

              message,



              style:

                  const TextStyle(

                color: Colors.white70,

                fontSize: 12,

                height: 1.4,

              ),

            ),

          ),

        ],

      ),

    );

  }



  // ============================================================

  // TIP CARD

  // ============================================================



  Widget _buildTipCard() {

    return Container(

      width: double.infinity,



      padding:

          const EdgeInsets.all(14),



      decoration:

          BoxDecoration(

        color:

            const Color(0xff0D1728),



        borderRadius:

            BorderRadius.circular(14),



        border: Border.all(

          color: borderColor,

        ),

      ),



      child: Row(

        crossAxisAlignment:

            CrossAxisAlignment.start,



        children: [

          Container(

            width: 38,

            height: 38,



            decoration:

                BoxDecoration(

              color:

                  cyanColor.withOpacity(

                0.12,

              ),



              borderRadius:

                  BorderRadius.circular(

                10,

              ),

            ),



            child: const Icon(

              Icons.lightbulb_outline,

              color: cyanColor,

              size: 20,

            ),

          ),



          const SizedBox(

            width: 11,

          ),



          const Expanded(

            child: Column(

              crossAxisAlignment:

                  CrossAxisAlignment.start,



              children: [

                Text(

                  "Safety Tip",

                  style:

                      TextStyle(

                    color: Colors.white,

                    fontWeight:

                        FontWeight.bold,

                    fontSize: 13,

                  ),

                ),



                SizedBox(

                  height: 4,

                ),



                Text(

                  "Keep your eyes on the road and maintain a comfortable driving position.",

                  style:

                      TextStyle(

                    color: Colors.white54,

                    fontSize: 11,

                    height: 1.4,

                  ),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }



  // ============================================================

  // STOP BUTTON

  // ============================================================



  Widget _buildStopButton() {

    return SizedBox(

      width: double.infinity,

      height: 58,



      child:

          ElevatedButton.icon(

        onPressed:

            _isStopping

                ? null

                : _stopMonitoring,



        style:

            ElevatedButton.styleFrom(

          backgroundColor:

              redColor,



          foregroundColor:

              Colors.white,



          disabledBackgroundColor:

              redColor.withOpacity(

            0.45,

          ),



          elevation: 0,



          shape:

              RoundedRectangleBorder(

            borderRadius:

                BorderRadius.circular(

              16,

            ),

          ),

        ),



        icon: const Icon(

          Icons.stop_circle,

          size: 21,

        ),



        label: Text(

          _isStopping

              ? "Stopping..."

              : "Stop Monitoring",



          style:

              const TextStyle(

            fontSize: 16,

            fontWeight:

                FontWeight.bold,

          ),

        ),

      ),

    );

  }

}



// ============================================================================

// ALERT LEVEL

// ============================================================================



enum AlertLevel {

  safe,

  warning,

  critical,

}



// ============================================================================

// ALERT LEVEL EXTENSION

// ============================================================================



extension AlertLevelExtension on AlertLevel {

  Color get color {

    switch (this) {

      case AlertLevel.safe:

        return const Color(0xff4ADE80);



      case AlertLevel.warning:

        return const Color(0xffF59E0B);



      case AlertLevel.critical:

        return const Color(0xffEF4444);

    }

  }



  IconData get icon {

    switch (this) {

      case AlertLevel.safe:

        return Icons.check_circle_outline;



      case AlertLevel.warning:

        return Icons.warning_amber_rounded;



      case AlertLevel.critical:

        return Icons.error_outline;

    }

  }



  String get title {

    switch (this) {

      case AlertLevel.safe:

        return "SAFE";



      case AlertLevel.warning:

        return "WARNING";



      case AlertLevel.critical:

        return "CRITICAL ALERT";

    }

  }



  String get shortTitle {

    switch (this) {

      case AlertLevel.safe:

        return "SAFE";



      case AlertLevel.warning:

        return "WARNING";



      case AlertLevel.critical:

        return "CRITICAL";

    }

  }



  String subtitle({

    required String fatigue,

    required String eyes,

    required String headPosition,

  }) {

    switch (this) {

      case AlertLevel.safe:

        return "Driver condition appears normal.";



      case AlertLevel.warning:

        if (fatigue.toLowerCase()

            .contains("medium")) {

          return "Medium fatigue detected. Please stay alert.";

        }



        if (eyes.toLowerCase()

            .contains("closed")) {

          return "Eyes closed. Please maintain attention.";

        }



        return "Potential driver safety issue detected.";



      case AlertLevel.critical:

        if (eyes.toLowerCase()

            .contains("closed")) {

          return "Prolonged eye closure detected. Take immediate action.";

        }



        if (fatigue.toLowerCase()

            .contains("high")) {

          return "High fatigue detected. Please take a break.";

        }



        if (headPosition.toLowerCase()

            .contains("down")) {

          return "Driver attention appears diverted.";

        }



        return "Immediate driver attention required.";

    }

  }

}



// ============================================================================

// CAMERA CORNER PAINTER

// ============================================================================



class _CornerPainter extends CustomPainter {

  final bool top;

  final bool left;



  _CornerPainter({

    required this.top,

    required this.left,

  });



  @override

  void paint(

    Canvas canvas,

    Size size,

  ) {

    // IMPORTANT:

    // Keep the color directly here.

    // Do NOT use cyanColor from _MonitoringScreenState.

    // This prevents the previous compilation error.



    final Paint paint = Paint()

      ..color = const Color(0xff06B6D4)

      ..strokeWidth = 3

      ..style = PaintingStyle.stroke

      ..strokeCap = StrokeCap.square;



    final Path path = Path();



    if (top && left) {

      path.moveTo(

        0,

        size.height,

      );



      path.lineTo(

        0,

        0,

      );



      path.lineTo(

        size.width,

        0,

      );

    }



    if (top && !left) {

      path.moveTo(

        0,

        0,

      );



      path.lineTo(

        size.width,

        0,

      );



      path.lineTo(

        size.width,

        size.height,

      );

    }



    if (!top && left) {

      path.moveTo(

        0,

        0,

      );



      path.lineTo(

        0,

        size.height,

      );



      path.lineTo(

        size.width,

        size.height,

      );

    }



    if (!top && !left) {

      path.moveTo(

        0,

        size.height,

      );



      path.lineTo(

        size.width,

        size.height,

      );



      path.lineTo(

        size.width,

        0,

      );

    }



    canvas.drawPath(

      path,

      paint,

    );

  }



  @override

  bool shouldRepaint(

    CustomPainter oldDelegate,

  ) {

    return false;

  }

}
