/// Defines the severity levels used by the Driver Safety Alert System.
enum AlertSeverity {
  warning,
  high,
  critical,
}

/// Defines the actions that can be triggered by an alert.
///
/// IMPORTANT:
/// - Warning alerts use in-app notifications.
/// - High alerts use in-app notifications + email.
/// - Critical alerts use in-app notifications + email.
/// - Critical incidents can require driver acknowledgement.
/// - If a critical incident receives no response, the system can
///   escalate to the emergency contact by email.
/// - SMS and phone calls are NOT part of the current active
///   notification architecture.
/// - SMS and phoneCall remain reserved as future extension points
///   and are not used by any active rule.
enum AlertAction {
  /// Shows an alert inside the Driver Safety AI application.
  appNotification,

  /// Sends an email to the registered driver.
  email,

  /// Represents the driver's response/acknowledgement workflow.
  ///
  /// The actual UI and response handling will be implemented later
  /// in the Alert Engine / Monitoring Screen / Notification layer.
  driverAcknowledgement,

  /// Sends an escalation email to the configured emergency contact.
  emergencyContactEmail,

  /// Reserved for a possible future SMS integration.
  ///
  /// NOT USED by any active rule.
  sms,

  /// Reserved for a possible future emergency SMS integration.
  ///
  /// NOT USED by any active rule.
  emergencySms,

  /// Reserved for a possible future automated phone-call integration.
  ///
  /// NOT USED by any active rule.
  phoneCall,
}

/// Represents one alert rule in the Driver Safety Alert System.
class AlertRule {
  final String id;
  final String name;
  final String description;
  final AlertSeverity severity;
  final List<AlertAction> actions;
  final bool enabled;
  final String detectionSource;

  const AlertRule({
    required this.id,
    required this.name,
    required this.description,
    required this.severity,
    required this.actions,
    required this.enabled,
    required this.detectionSource,
  });
}

/// All alert rules used by the Driver Safety AI.
///
/// IMPORTANT ARCHITECTURE:
///
/// detector.py
///     ↓
/// measurements / temporal state / events
///     ↓
/// Flutter Alert Engine
///     ↓
/// Alert Rules
///     ↓
/// Notification / Response / Escalation
///
/// A camera frame is NOT an alert event.
///
/// The Alert Engine is responsible for temporal confirmation,
/// incident lifecycle, duplicate prevention, recovery,
/// driver acknowledgement and escalation.
///
/// These rules define what action belongs to each alert stage.
class AlertRules {
  AlertRules._();

  // ============================================================
  // DETECTOR-BASED THRESHOLDS
  // ============================================================

  /// detector.py considers bilateral eye closure >= 2.0 seconds
  /// to be a prolonged safety-relevant eye-closure condition.
  static const double longEyeClosureSeconds = 2.0;

  /// detector.py uses >= 0.5 seconds of bilateral closure as
  /// a moderate fatigue indicator.
  static const double mediumEyeClosureSeconds = 0.5;

  /// Repeated yawning must be based on actual yawn events reported
  /// by detector.py, not on the number of frames where yawning == Yes.
  static const int repeatedYawnCount = 3;

  /// Rolling period used by the Alert Engine when evaluating
  /// repeated yawning events.
  static const Duration repeatedYawnWindow = Duration(minutes: 5);

  /// Persistent critical conditions can enter the emergency
  /// escalation stage after approximately three minutes.
  static const Duration criticalEscalationDuration =
      Duration(minutes: 3);

  // ============================================================
  // RULE 1
  // DROWSINESS
  // ============================================================

  /// High fatigue becomes a critical safety incident after the
  /// Alert Engine confirms that it is persistent.
  ///
  /// Critical:
  ///   In-app notification
  ///   Driver email
  ///   Driver acknowledgement workflow
  static const AlertRule drowsiness = AlertRule(
    id: 'drowsiness',
    name: 'Drowsiness',
    description:
        'Detects persistent high fatigue reported by the AI, '
        'indicating possible driver drowsiness.',
    severity: AlertSeverity.critical,
    actions: [
      AlertAction.appNotification,
      AlertAction.email,
      AlertAction.driverAcknowledgement,
    ],
    enabled: true,
    detectionSource: 'fatigue',
  );

  // ============================================================
  // RULE 2
  // PROLONGED EYE CLOSURE
  // ============================================================

  /// Critical when both eyes remain closed for the detector-defined
  /// prolonged closure threshold.
  ///
  /// Critical:
  ///   In-app notification
  ///   Driver email
  ///   Driver acknowledgement workflow
  static const AlertRule prolongedEyeClosure = AlertRule(
    id: 'prolonged_eye_closure',
    name: 'Prolonged Eye Closure',
    description:
        'Triggers when both eyes remain closed for the '
        'prolonged eye-closure threshold.',
    severity: AlertSeverity.critical,
    actions: [
      AlertAction.appNotification,
      AlertAction.email,
      AlertAction.driverAcknowledgement,
    ],
    enabled: true,
    detectionSource: 'closed_duration',
  );

  // ============================================================
  // RULE 3
  // REPEATED YAWNING
  // ============================================================

  /// High severity when the Alert Engine confirms repeated
  /// actual yawn events within the configured rolling window.
  ///
  /// IMPORTANT:
  /// detector.py may report:
  ///
  ///   yawning = Yes
  ///   yawning = Yes
  ///   yawning = Yes
  ///
  /// across many frames for ONE yawn.
  ///
  /// The Alert Engine must therefore use yawn_count/event changes
  /// rather than treating every frame as a new yawn.
  ///
  /// High:
  ///   In-app notification
  ///   Driver email
  static const AlertRule repeatedYawning = AlertRule(
    id: 'repeated_yawning',
    name: 'Repeated Yawning',
    description:
        'Triggers when the detector reports the configured number '
        'of actual yawn events within the rolling evaluation window.',
    severity: AlertSeverity.high,
    actions: [
      AlertAction.appNotification,
      AlertAction.email,
    ],
    enabled: true,
    detectionSource: 'yawning',
  );

  // ============================================================
  // RULE 4
  // MOBILE PHONE USAGE
  // ============================================================

  /// Reserved for future mobile-phone detection.
  ///
  /// The current detector does not provide a mobile-phone signal,
  /// so this rule remains disabled.
  static const AlertRule mobilePhoneUsage = AlertRule(
    id: 'mobile_phone_usage',
    name: 'Mobile Phone Usage',
    description:
        'Reserved for continuous mobile-phone usage detection. '
        'The current AI detector does not provide a mobile-phone '
        'signal yet.',
    severity: AlertSeverity.critical,
    actions: [
      AlertAction.appNotification,
      AlertAction.email,
      AlertAction.driverAcknowledgement,
    ],
    enabled: false,
    detectionSource: 'mobile_phone',
  );

  // ============================================================
  // RULE 5
  // DRIVER NOT DETECTED
  // ============================================================

  /// High severity when the driver is not detected for the
  /// duration confirmed by the Alert Engine.
  ///
  /// High:
  ///   In-app notification
  ///   Driver email
  ///
  /// The Alert Engine is responsible for preventing an alert
  /// from being sent every frame while the face remains missing.
  static const AlertRule driverNotDetected = AlertRule(
    id: 'driver_not_detected',
    name: 'Driver Not Detected',
    description:
        'Detects when the driver face is not detected for a '
        'sustained period confirmed by the Alert Engine.',
    severity: AlertSeverity.high,
    actions: [
      AlertAction.appNotification,
      AlertAction.email,
    ],
    enabled: true,
    detectionSource: 'face_detected',
  );

  // ============================================================
  // RULE 6
  // REPEATED UNSAFE EVENTS
  // ============================================================

  /// This generic rule is disabled until the detector provides
  /// a dedicated event stream for independent unsafe events.
  ///
  /// IMPORTANT:
  /// A Warning or Danger value repeated across camera frames
  /// must NOT automatically become multiple unsafe events.
  static const AlertRule repeatedUnsafeEvents = AlertRule(
    id: 'repeated_unsafe_events',
    name: 'Repeated Unsafe Events',
    description:
        'Reserved for a future dedicated unsafe-event stream. '
        'Repeated safety states across frames are not counted as '
        'independent unsafe events.',
    severity: AlertSeverity.critical,
    actions: [
      AlertAction.appNotification,
      AlertAction.email,
      AlertAction.driverAcknowledgement,
    ],
    enabled: false,
    detectionSource: 'alert_events',
  );

  // ============================================================
  // RULE 7
  // EMERGENCY ESCALATION
  // ============================================================

  /// Represents the emergency-contact escalation stage of an
  /// already active critical incident.
  ///
  /// This rule is NOT intended to fire immediately when a critical
  /// alert first occurs.
  ///
  /// The Alert Engine must first determine that:
  ///
  /// 1. The same critical incident is still active.
  /// 2. The driver has not acknowledged the incident.
  /// 3. The configured response/escalation conditions are met.
  ///
  /// Current escalation:
  ///   Emergency-contact email
  ///
  /// SMS and phone calls are intentionally not used.
  static const AlertRule alertEscalation = AlertRule(
    id: 'alert_escalation',
    name: 'Emergency Escalation',
    description:
        'Escalates an unresolved critical incident to the '
        'configured emergency contact by email after the '
        'required escalation conditions are satisfied.',
    severity: AlertSeverity.critical,
    actions: [
      AlertAction.emergencyContactEmail,
    ],
    enabled: true,
    detectionSource: 'alert_events',
  );

  // ============================================================
  // RULE 8
  // ALERT COOLDOWN / DUPLICATE PREVENTION
  // ============================================================

  /// Internal duplicate-prevention rule.
  ///
  /// This is not a new safety event.
  ///
  /// The Alert State / Alert Engine will later use incident state
  /// to ensure that one active incident does not repeatedly send
  /// the same notification every 250 ms.
  static const AlertRule alertCooldown = AlertRule(
    id: 'alert_cooldown',
    name: 'Alert Cooldown',
    description:
        'Prevents duplicate notifications while the same incident '
        'remains active.',
    severity: AlertSeverity.warning,
    actions: [
      AlertAction.appNotification,
    ],
    enabled: true,
    detectionSource: 'alert_events',
  );

  // ============================================================
  // ALL RULES
  // ============================================================

  static const List<AlertRule> all = [
    drowsiness,
    prolongedEyeClosure,
    repeatedYawning,
    mobilePhoneUsage,
    driverNotDetected,
    repeatedUnsafeEvents,
    alertEscalation,
    alertCooldown,
  ];
}