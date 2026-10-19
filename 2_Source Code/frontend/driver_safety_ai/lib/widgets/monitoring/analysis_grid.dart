import 'package:flutter/material.dart';
import 'analysis_card.dart';

class AnalysisGrid extends StatelessWidget {
  final String eyes;
  final String yawning;
  final String fatigue;
  final String alert;
  final String blinkCount;
  final String blinkRate;
  final String faceStatus;

  const AnalysisGrid({
    super.key,
    required this.eyes,
    required this.yawning,
    required this.fatigue,
    required this.alert,
    required this.blinkCount,
    required this.blinkRate,
    required this.faceStatus,
  });

  // ============================================================
  // FACE STATUS
  // ============================================================

  bool get _faceDetected => faceStatus == "Face Detected";

  // ============================================================
  // EYES COLOR
  // ============================================================

  Color _eyeColor() {
    if (!_faceDetected) {
      return Colors.blue;
    }

    switch (eyes.toLowerCase()) {
      case "open":
        return Colors.green;

      case "closed":
        return Colors.red;

      default:
        return Colors.blue;
    }
  }

  // ============================================================
  // YAWNING COLOR
  // ============================================================

  Color _yawnColor() {
    if (!_faceDetected) {
      return Colors.blue;
    }

    return yawning.toLowerCase() == "yes"
        ? Colors.orange
        : Colors.blue;
  }

  // ============================================================
  // FATIGUE COLOR
  // ============================================================

  Color _fatigueColor() {
    if (!_faceDetected) {
      return Colors.blue;
    }

    switch (fatigue.toLowerCase()) {
      case "high":
        return Colors.red;

      case "medium":
        return Colors.orange;

      case "low":
        return Colors.green;

      default:
        return Colors.blue;
    }
  }

  // ============================================================
  // ALERT COLOR
  // ============================================================

  Color _alertColor() {
    if (!_faceDetected) {
      return Colors.red;
    }

    final alertValue = alert.toLowerCase();

    if (alertValue == "safe") {
      return Colors.green;
    }

    if (alertValue == "warning") {
      return Colors.orange;
    }

    if (alertValue == "danger") {
      return Colors.red;
    }

    if (alertValue == "drowsy") {
      return Colors.red;
    }

    if (alertValue.contains("focus")) {
      return Colors.red;
    }

    if (alertValue.contains("waiting")) {
      return Colors.blue;
    }

    return Colors.blue;
  }

  // ============================================================
  // CURRENT TIME
  // ============================================================

  String _time() {
    final now = DateTime.now();

    int hour = now.hour % 12;

    if (hour == 0) {
      hour = 12;
    }

    final minute = now.minute.toString().padLeft(2, '0');

    final period = now.hour >= 12 ? "PM" : "AM";

    return "$hour:$minute $period";
  }

  // ============================================================
  // BUILD UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,

      physics: const NeverScrollableScrollPhysics(),

      crossAxisCount: 2,

      crossAxisSpacing: 16,

      mainAxisSpacing: 16,

      childAspectRatio: 0.62,

      children: [

        // ========================================================
        // 1. FACE
        // ========================================================

        AnalysisCard(
          icon: _faceDetected
              ? Icons.face
              : Icons.face_retouching_off,

          iconColor: _faceDetected
              ? Colors.green
              : Colors.red,

          title: "Face",

          value: _faceDetected
              ? "Face Detected"
              : "No Face Detected",

          valueColor: _faceDetected
              ? Colors.green
              : Colors.red,

          time: _time(),
        ),

        // ========================================================
        // 2. EYES
        // ========================================================

        AnalysisCard(
          icon: Icons.remove_red_eye,

          iconColor: const Color(0xff2196F3),

          title: "Eyes",

          value: _faceDetected
              ? eyes
              : "Please look at the camera",

          valueColor: _eyeColor(),

          time: _time(),
        ),

        // ========================================================
        // 3. YAWNING
        // ========================================================

        AnalysisCard(
          icon: Icons.sentiment_dissatisfied_outlined,

          iconColor: const Color(0xffF59E0B),

          title: "Yawning",

          value: _faceDetected
              ? yawning
              : "Please look at the camera",

          valueColor: _yawnColor(),

          time: _time(),
        ),

        // ========================================================
        // 4. FATIGUE
        // ========================================================

        AnalysisCard(
          icon: Icons.battery_alert,

          iconColor: const Color(0xffEF4444),

          title: "Fatigue",

          value: _faceDetected
              ? fatigue
              : "Waiting",

          valueColor: _fatigueColor(),

          time: _time(),
        ),

        // ========================================================
        // 5. ALERT
        // ========================================================

        AnalysisCard(
          icon: Icons.shield,

          iconColor: const Color(0xff22C55E),

          title: "Alert",

          value: _faceDetected
              ? alert
              : "Please focus on the road",

          valueColor: _alertColor(),

          time: _time(),
        ),

        // ========================================================
        // 6. BLINK COUNT
        // ========================================================

        AnalysisCard(
          icon: Icons.visibility,

          iconColor: Colors.deepPurple,

          title: "Blink Count",

          value: _faceDetected
              ? blinkCount
              : "0",

          valueColor: Colors.deepPurpleAccent,

          time: _time(),
        ),

        // ========================================================
        // 7. BLINK RATE
        // ========================================================

        AnalysisCard(
          icon: Icons.remove_red_eye_outlined,

          iconColor: Colors.purple,

          title: "Blink Rate",

          value: _faceDetected
              ? "$blinkRate/min"
              : "0/min",

          valueColor: Colors.purpleAccent,

          time: _time(),
        ),
      ],
    );
  }
}