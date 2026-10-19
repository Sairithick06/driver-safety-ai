import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'alert_engine.dart';
import 'alert_rules.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance =
      NotificationService._();

  // ============================================================
  // BACKEND
  // ============================================================

  static const String baseUrl = "http://192.168.31.55:8000";

  String? _accountId;

  // ============================================================
  // SETTINGS KEY
  // ============================================================

  static const String _notificationsEnabledKey =
      'settings_notifications_enabled';

  // ============================================================
  // ACCOUNT ID
  // ============================================================

  void setAccountId(String accountId) {
    _accountId = accountId;

    if (kDebugMode) {
      debugPrint(
        'NOTIFICATION SERVICE: Account ID configured: $_accountId',
      );
    }
  }

  // ============================================================
  // SAFETY NOTIFICATION SETTING
  // ============================================================

  Future<bool> areNotificationsEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      return prefs.getBool(_notificationsEnabledKey) ?? true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          'NOTIFICATION SETTINGS ERROR: '
          'Unable to read notification setting: $e',
        );
      }

      // Safety-first fallback:
      // if the setting cannot be read, keep notifications enabled.
      return true;
    }
  }

  // ============================================================
  // APP NOTIFICATION
  // ============================================================

  Future<void> sendAppNotification(
    DriverAlert alert,
  ) async {
    final bool enabled = await areNotificationsEnabled();

    if (!enabled) {
      if (kDebugMode) {
        debugPrint(
          'APP NOTIFICATION BLOCKED: '
          'Safety Notifications are OFF | '
          '${alert.severity.name.toUpperCase()} | '
          '${alert.ruleName}',
        );
      }

      return;
    }

    if (kDebugMode) {
      debugPrint(
        'APP NOTIFICATION ALLOWED: '
        '${alert.severity.name.toUpperCase()} | '
        '${alert.ruleName} | '
        '${alert.message}',
      );
    }

    // Actual visible local/in-app notification delivery will
    // be connected in the next notification implementation step.
  }

  // ============================================================
  // EMAIL
  // ============================================================

  Future<void> sendEmailAlert(
    DriverAlert alert,
  ) async {
    if (_accountId == null ||
        _accountId!.trim().isEmpty) {
      debugPrint(
        'EMAIL ALERT ERROR: Account ID is not configured.',
      );

      return;
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/alerts/email'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'account_id': _accountId,
          'rule_name': alert.ruleName,
          'severity': alert.severity.name,
          'message': alert.message,
          'timestamp': alert.timestamp.toIso8601String(),
        }),
      );

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        if (kDebugMode) {
          debugPrint(
            'EMAIL ALERT SENT: '
            '${alert.severity.name.toUpperCase()} | '
            '${alert.ruleName}',
          );
        }
      } else {
        debugPrint(
          'EMAIL ALERT ERROR: '
          'HTTP ${response.statusCode} | '
          '${response.body}',
        );
      }
    } catch (e) {
      debugPrint(
        'EMAIL ALERT ERROR: $e',
      );
    }
  }

  // ============================================================
  // SMS
  // ============================================================

  Future<void> sendSmsAlert(
    DriverAlert alert,
  ) async {
    if (kDebugMode) {
      debugPrint(
        'SMS ALERT: '
        '${alert.severity.name.toUpperCase()} | '
        '${alert.ruleName} | '
        '${alert.message}',
      );
    }

    // SMS is intentionally not active.
  }

  // ============================================================
  // EMERGENCY SMS
  // ============================================================

  Future<void> sendEmergencySms(
    DriverAlert alert,
  ) async {
    if (kDebugMode) {
      debugPrint(
        'EMERGENCY SMS: '
        '${alert.severity.name.toUpperCase()} | '
        '${alert.ruleName} | '
        '${alert.message}',
      );
    }

    // Emergency SMS is intentionally not active.
  }

  // ============================================================
  // EMERGENCY PHONE CALL
  // ============================================================

  Future<void> makeEmergencyCall(
    DriverAlert alert,
  ) async {
    if (kDebugMode) {
      debugPrint(
        'EMERGENCY PHONE CALL: '
        '${alert.severity.name.toUpperCase()} | '
        '${alert.ruleName} | '
        '${alert.message}',
      );
    }

    // Emergency phone calling is intentionally not active.
  }

  // ============================================================
  // ALERT DISPATCHER
  // ============================================================

  Future<void> dispatchAlert(
    DriverAlert alert,
  ) async {
    if (!alert.shouldNotify) {
      return;
    }

    for (final action in alert.actions) {
      switch (action) {
        case AlertAction.appNotification:
          await sendAppNotification(alert);
          break;

        case AlertAction.email:
          await sendEmailAlert(alert);
          break;

        case AlertAction.sms:
          await sendSmsAlert(alert);
          break;

        case AlertAction.emergencySms:
          await sendEmergencySms(alert);
          break;

        case AlertAction.phoneCall:
          await makeEmergencyCall(alert);
          break;

        case AlertAction.driverAcknowledgement:
          // Driver acknowledgement is handled by the
          // UI/AlertEngine.
          break;

        case AlertAction.emergencyContactEmail:
          // Emergency-contact email remains independent of
          // the normal Safety Notifications setting.
          await sendEmailAlert(alert);
          break;
      }
    }
  }

  // ============================================================
  // DISPATCH MULTIPLE ALERTS
  // ============================================================

  Future<void> dispatchAlerts(
    List<DriverAlert> alerts,
  ) async {
    for (final alert in alerts) {
      await dispatchAlert(alert);
    }
  }
}