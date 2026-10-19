import 'package:flutter/foundation.dart';

import '../alert_system/alert_engine.dart';
import '../alert_system/alert_rules.dart';


// ============================================================================
// MONITORING ANALYSIS
// ============================================================================

class MonitoringAnalysis {
  final DateTime time;

  final bool faceDetected;
  final String eyes;
  final String yawning;
  final String fatigue;
  final String alert;
  final String blinkCount;
  final String blinkRate;
  final String headPosition;
  final String closedDuration;
  final String message;

  MonitoringAnalysis({
    required this.time,
    required this.faceDetected,
    required this.eyes,
    required this.yawning,
    required this.fatigue,
    required this.alert,
    required this.blinkCount,
    required this.blinkRate,
    required this.headPosition,
    required this.closedDuration,
    required this.message,
  });
}


// ============================================================================
// MONITORING SESSION
// ============================================================================

class MonitoringSession {
  final DateTime startTime;
  DateTime? endTime;

  final List<MonitoringAnalysis> analyses;
  final List<DriverAlert> alerts;

  MonitoringSession({
    required this.startTime,
    this.endTime,
    List<MonitoringAnalysis>? analyses,
    List<DriverAlert>? alerts,
  })  : analyses = analyses ?? [],
        alerts = alerts ?? [];


  // --------------------------------------------------------------------------
  // SESSION DURATION
  // --------------------------------------------------------------------------

  Duration get duration {
    final end = endTime ?? DateTime.now();

    return end.difference(startTime);
  }


  // --------------------------------------------------------------------------
  // LATEST ANALYSIS
  // --------------------------------------------------------------------------

  MonitoringAnalysis? get latestAnalysis {
    if (analyses.isEmpty) {
      return null;
    }

    return analyses.last;
  }


  // --------------------------------------------------------------------------
  // TOTAL ANALYSES
  // --------------------------------------------------------------------------

  int get totalAnalyses {
    return analyses.length;
  }


  // --------------------------------------------------------------------------
  // WARNING COUNT
  // --------------------------------------------------------------------------

  int get warningCount {
    return analyses.where((analysis) {
      final fatigue = analysis.fatigue.toLowerCase();
      final alert = analysis.alert.toLowerCase();

      return fatigue.contains("medium") ||
          alert.contains("warning");
    }).length;
  }


  // --------------------------------------------------------------------------
  // CRITICAL COUNT
  // --------------------------------------------------------------------------

  int get criticalCount {
    return analyses.where((analysis) {
      final fatigue = analysis.fatigue.toLowerCase();
      final alert = analysis.alert.toLowerCase();

      return fatigue.contains("high") ||
          alert.contains("danger");
    }).length;
  }


  // --------------------------------------------------------------------------
  // WARNING STATUS
  // --------------------------------------------------------------------------

  bool get hasWarnings {
    return warningCount > 0;
  }


  // --------------------------------------------------------------------------
  // CRITICAL STATUS
  // --------------------------------------------------------------------------

  bool get hasCriticalAlerts {
    return criticalCount > 0;
  }


  // --------------------------------------------------------------------------
  // SAFE SESSION
  // --------------------------------------------------------------------------

  bool get isSafe {
    return analyses.isNotEmpty &&
        !hasWarnings &&
        !hasCriticalAlerts;
  }

  int get alertCount => alerts.length;

  int get warningAlertCount => alerts.where(
        (alert) => alert.severity == AlertSeverity.warning,
      ).length;

  int get highAlertCount => alerts.where(
        (alert) => alert.severity == AlertSeverity.high,
      ).length;

  int get criticalAlertCount => alerts.where(
        (alert) => alert.severity == AlertSeverity.critical,
      ).length;
}


// ============================================================================
// MONITORING SESSION SERVICE
// ============================================================================

class MonitoringSessionService {
  MonitoringSessionService._privateConstructor();

  static final MonitoringSessionService instance =
      MonitoringSessionService._privateConstructor();


  // ==========================================================================
  // STORAGE
  // ==========================================================================

  final List<MonitoringSession> _sessions = [];

  MonitoringSession? _currentSession;


  // ==========================================================================
  // GETTERS
  // ==========================================================================

  List<MonitoringSession> get sessions {
    return List.unmodifiable(_sessions);
  }


  MonitoringSession? get currentSession {
    return _currentSession;
  }

  List<DriverAlert> get currentAlerts {
    if (_currentSession == null) {
      return const <DriverAlert>[];
    }

    return List.unmodifiable(_currentSession!.alerts);
  }


  bool get isSessionActive {
    return _currentSession != null &&
        _currentSession!.endTime == null;
  }


  // ==========================================================================
  // START SESSION
  // ==========================================================================

  void startSession() {

    // Close any previous unfinished session.
    if (_currentSession != null &&
        _currentSession!.endTime == null) {

      _currentSession!.endTime = DateTime.now();

      if (_currentSession!.analyses.isNotEmpty) {
        _sessions.add(_currentSession!);
      }
    }


    _currentSession = MonitoringSession(
      startTime: DateTime.now(),
    );


    debugPrint(
      "==================================================",
    );

    debugPrint(
      "MONITORING SESSION STARTED",
    );

    debugPrint(
      "Start Time: ${_currentSession!.startTime}",
    );

    debugPrint(
      "==================================================",
    );
  }


  // ==========================================================================
  // ADD ANALYSIS
  // ==========================================================================

  void addAnalysis({
    required bool faceDetected,
    required String eyes,
    required String yawning,
    required String fatigue,
    required String alert,
    required String blinkCount,
    required String blinkRate,
    required String headPosition,
    required String closedDuration,
    required String message,
  }) {

    // Safety check.
    if (_currentSession == null) {
      startSession();
    }


    final analysis = MonitoringAnalysis(
      time: DateTime.now(),
      faceDetected: faceDetected,
      eyes: eyes,
      yawning: yawning,
      fatigue: fatigue,
      alert: alert,
      blinkCount: blinkCount,
      blinkRate: blinkRate,
      headPosition: headPosition,
      closedDuration: closedDuration,
      message: message,
    );


    _currentSession!.analyses.add(analysis);


    debugPrint(
      "Analysis saved | "
      "Eyes: $eyes | "
      "Yawning: $yawning | "
      "Fatigue: $fatigue | "
      "Alert: $alert | "
      "Blink Count: $blinkCount | "
      "Blink Rate: $blinkRate | "
      "Head: $headPosition",
    );
  }


  // ==========================================================================
  // ADD DRIVER ALERT
  // ==========================================================================

  void addAlert(DriverAlert alert) {
    if (_currentSession == null) {
      startSession();
    }

    _currentSession!.alerts.add(alert);

    debugPrint(
      "Driver alert saved | "
      "Severity: ${alert.severity.name} | "
      "Rule: ${alert.ruleName} | "
      "Message: ${alert.message}",
    );
  }


  // ==========================================================================
  // END SESSION
  // ==========================================================================

  MonitoringSession? endSession({
    DateTime? endTime,
  }) {

    if (_currentSession == null) {

      debugPrint(
        "No active monitoring session to end.",
      );

      return null;
    }


    _currentSession!.endTime =
        endTime ?? DateTime.now();


    final completedSession =
        _currentSession!;


    // Only save sessions that actually contain analysis data.
    if (completedSession.analyses.isNotEmpty) {

      _sessions.add(
        completedSession,
      );
    }


    debugPrint(
      "==================================================",
    );

    debugPrint(
      "MONITORING SESSION ENDED",
    );

    debugPrint(
      "Duration: "
      "${completedSession.duration.inSeconds}s",
    );

    debugPrint(
      "Analyses: "
      "${completedSession.totalAnalyses}",
    );

    debugPrint(
      "Warnings: "
      "${completedSession.warningCount}",
    );

    debugPrint(
      "Critical: "
      "${completedSession.criticalCount}",
    );

    debugPrint(
      "Total Sessions: "
      "${_sessions.length}",
    );

    debugPrint(
      "==================================================",
    );


    _currentSession = null;


    return completedSession;
  }


  // ==========================================================================
  // CLEAR ALL SESSIONS
  // ==========================================================================

  void clearSessions() {

    _sessions.clear();

    _currentSession = null;


    debugPrint(
      "All monitoring session data cleared.",
    );
  }


  // ==========================================================================
  // STATISTICS
  // ==========================================================================

  int get totalTrips {
    return _sessions.length;
  }


  int get safeTrips {

    return _sessions.where(
      (session) => session.isSafe,
    ).length;
  }


  int get warningTrips {

    return _sessions.where(
      (session) =>
          session.hasWarnings &&
          !session.hasCriticalAlerts,
    ).length;
  }


  int get criticalTrips {

    return _sessions.where(
      (session) =>
          session.hasCriticalAlerts,
    ).length;
  }


  int get totalWarnings {

    return _sessions.fold(
      0,
      (total, session) =>
          total + session.warningCount,
    );
  }


  int get totalCriticalAlerts {

    return _sessions.fold(
      0,
      (total, session) =>
          total + session.criticalCount,
    );
  }
}