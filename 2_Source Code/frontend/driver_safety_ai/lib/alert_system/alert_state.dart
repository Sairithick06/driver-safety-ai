import 'alert_rules.dart';

/// Stores the current state of one alert condition during a ride.
///
/// IMPORTANT ARCHITECTURE:
///
/// A camera frame is NOT an event.
///
/// This class distinguishes:
/// - detections      -> repeated observations from AI frames
/// - events          -> one meaningful occurrence
/// - incidents       -> a currently active continuous condition
/// - notifications   -> actions already sent for the incident
/// - acknowledgement -> explicit driver response
/// - escalation      -> emergency-contact escalation for unresolved incidents
///
/// This class does not send notifications and does not evaluate AI data.
/// It only stores state so the Alert Engine can make safe decisions.
class AlertState {
  final String ruleId;

  // ============================================================
  // ACTIVE INCIDENT STATE
  // ============================================================

  /// Whether this alert condition is currently active.
  bool isActive;

  /// When the current continuous incident started.
  DateTime? startedAt;

  /// When the condition was most recently observed.
  DateTime? lastDetectedAt;

  /// Number of consecutive AI detections while the condition
  /// remains continuously active.
  ///
  /// This is a detection/frame count, NOT an event count.
  int consecutiveCount;

  /// Number of AI detections received while this condition was
  /// active during the ride.
  ///
  /// This is intentionally separate from [occurrenceCount].
  int detectionCount;

  // ============================================================
  // EVENT STATE
  // ============================================================

  /// Number of meaningful events recorded for this rule during
  /// the current ride.
  ///
  /// IMPORTANT:
  /// This must be incremented by [recordEvent], not once for
  /// every camera frame.
  int occurrenceCount;

  /// When the most recent meaningful event occurred.
  DateTime? lastEventAt;

  /// Number of meaningful events currently represented by the
  /// active incident.
  ///
  /// Normally this is 1 for a continuous condition such as
  /// prolonged eye closure.
  int activeEventCount;

  // ============================================================
  // NOTIFICATION STATE
  // ============================================================

  /// Whether the normal notification for this incident has
  /// already been sent.
  ///
  /// The Alert Engine uses this to prevent duplicate notification
  /// delivery while the same incident remains active.
  bool notificationSent;

  /// When the normal notification was last sent.
  DateTime? lastNotificationAt;

  /// Number of email stages already sent for the current incident.
  ///
  /// The current architecture uses email as the external
  /// notification channel.
  ///
  /// This is a stage counter, NOT a frame/detection counter.
  int emailNotificationCount;

  /// Time when email stage 1 was sent.
  DateTime? firstEmailAt;

  /// Time when email stage 2 was sent.
  DateTime? secondEmailAt;

  /// Whether the emergency-contact email escalation has already
  /// been sent for this incident.
  ///
  /// This is the active emergency escalation mechanism in the
  /// new architecture.
  bool emergencyContactEmailSent;

  /// When the emergency-contact email was sent.
  DateTime? emergencyContactEmailAt;

  /// Whether the critical notification stage has already been sent.
  ///
  /// This remains as a compatibility field for the existing
  /// Alert Engine during the migration.
  ///
  /// It no longer means "Email + SMS".
  bool criticalNotificationSent;

  /// When the critical notification stage was sent.
  DateTime? criticalNotificationAt;

  // ============================================================
  // DRIVER RESPONSE
  // ============================================================

  /// Whether the driver has explicitly acknowledged the incident
  /// by selecting "I'M SAFE".
  ///
  /// This is never inferred from incident recovery or elapsed time.
  bool acknowledged;

  /// When the driver acknowledged the incident.
  DateTime? acknowledgedAt;

  /// Whether the driver explicitly selected "NEED HELP".
  ///
  /// This is different from [acknowledged].
  ///
  /// "I'M SAFE" means the driver has acknowledged the alert.
  /// "NEED HELP" means the driver has explicitly requested
  /// emergency assistance.
  bool driverRequestedHelp;

  /// When the driver requested help.
  DateTime? driverRequestedHelpAt;

  /// Deadline by which the driver should respond to a critical
  /// alert.
  ///
  /// If the deadline passes while neither acknowledgement nor
  /// help request has been recorded, the Alert Engine can treat
  /// the incident as NO RESPONSE.
  DateTime? driverResponseDeadline;

  /// Whether the driver response window has expired without an
  /// explicit response.
  ///
  /// This is derived/stored by the Alert Engine rather than being
  /// assumed immediately when the incident starts.
  bool driverResponseTimedOut;

  /// When the driver response window was determined to have expired.
  DateTime? driverResponseTimedOutAt;

  // ============================================================
  // LEGACY PHONE-CALL STATE
  // ============================================================
  //
  // These fields are temporarily retained for compatibility with
  // the current Alert Engine during the architecture migration.
  //
  // They are NOT used by any active rule in the new architecture.
  // They will be removed/retired when alert_engine.dart and the
  // remaining notification code are migrated.

  /// Legacy phone-call escalation state.
  ///
  /// NOT USED by the new active alert rules.
  bool phoneCallSent;

  /// Legacy phone-call timestamp.
  ///
  /// NOT USED by the new active alert rules.
  DateTime? phoneCallAt;

  /// Legacy phone-call response deadline.
  ///
  /// NOT USED by the new active alert rules.
  DateTime? phoneCallResponseDeadline;

  /// Legacy phone-call response state.
  ///
  /// NOT USED by the new active alert rules.
  bool driverRespondedAfterPhoneCall;

  // ============================================================
  // EMERGENCY-CONTACT ESCALATION
  // ============================================================

  /// Whether escalation to the emergency contact has already
  /// occurred for the current incident.
  ///
  /// The current architecture uses emergency-contact email.
  bool emergencyContactEscalated;

  /// When emergency-contact escalation occurred.
  DateTime? emergencyContactEscalatedAt;

  // ============================================================
  // GENERAL ESCALATION STATE
  // ============================================================

  /// Whether the current incident has entered its escalation stage.
  ///
  /// This does not automatically mean that an emergency email
  /// was sent. [emergencyContactEscalated] tracks that actual
  /// escalation separately.
  bool escalated;

  /// When the incident entered the escalation stage.
  DateTime? lastEscalationAt;

  AlertState({
    required this.ruleId,
    this.isActive = false,
    this.startedAt,
    this.lastDetectedAt,
    this.consecutiveCount = 0,
    this.detectionCount = 0,
    this.occurrenceCount = 0,
    this.lastEventAt,
    this.activeEventCount = 0,
    this.notificationSent = false,
    this.lastNotificationAt,
    this.emailNotificationCount = 0,
    this.firstEmailAt,
    this.secondEmailAt,
    this.emergencyContactEmailSent = false,
    this.emergencyContactEmailAt,
    this.criticalNotificationSent = false,
    this.criticalNotificationAt,
    this.acknowledged = false,
    this.acknowledgedAt,
    this.driverRequestedHelp = false,
    this.driverRequestedHelpAt,
    this.driverResponseDeadline,
    this.driverResponseTimedOut = false,
    this.driverResponseTimedOutAt,
    this.phoneCallSent = false,
    this.phoneCallAt,
    this.phoneCallResponseDeadline,
    this.driverRespondedAfterPhoneCall = false,
    this.emergencyContactEscalated = false,
    this.emergencyContactEscalatedAt,
    this.escalated = false,
    this.lastEscalationAt,
  });

  /// Creates a fresh state for an alert rule.
  factory AlertState.forRule(AlertRule rule) {
    return AlertState(
      ruleId: rule.id,
    );
  }

  // ============================================================
  // DETECTION / FRAME STATE
  // ============================================================

  /// Records one AI detection of the current condition.
  ///
  /// IMPORTANT:
  /// This method does NOT increase [occurrenceCount].
  ///
  /// A detection can happen every 250 ms while the same condition
  /// remains active. Those detections must not become separate
  /// safety events.
  void recordDetection(DateTime timestamp) {
    if (!isActive) {
      isActive = true;
      startedAt = timestamp;
      consecutiveCount = 1;
      activeEventCount = 0;
    } else {
      consecutiveCount++;
    }

    detectionCount++;
    lastDetectedAt = timestamp;
  }

  // ============================================================
  // EVENT STATE
  // ============================================================

  /// Records ONE meaningful safety event.
  ///
  /// This should be called only when the Alert Engine has confirmed
  /// that a real event occurred.
  ///
  /// Examples:
  /// - one completed blink
  /// - one completed yawn
  /// - one independent safety event
  ///
  /// It must NOT be called for every frame.
  void recordEvent(DateTime timestamp) {
    occurrenceCount++;
    lastEventAt = timestamp;
    activeEventCount++;
  }

  /// Records one meaningful event and activates its incident state
  /// when necessary.
  ///
  /// Useful for discrete events such as a completed yawn.
  void recordEventAndActivate(DateTime timestamp) {
    if (!isActive) {
      isActive = true;
      startedAt = timestamp;
      consecutiveCount = 0;
      activeEventCount = 0;
    }

    recordEvent(timestamp);
    lastDetectedAt = timestamp;
  }

  /// Returns the number of meaningful events recorded during
  /// the current ride.
  int get eventCount => occurrenceCount;

  // ============================================================
  // INCIDENT LIFECYCLE
  // ============================================================

  /// Marks the alert condition as no longer active.
  ///
  /// The historical event count is preserved for the ride.
  ///
  /// Notification and escalation history is also preserved so the
  /// completed incident remains auditable.
  void clearActiveCondition() {
    isActive = false;
    consecutiveCount = 0;
    startedAt = null;
    activeEventCount = 0;
  }

  /// Starts a fresh incident without deleting historical event data.
  ///
  /// This is useful when an old incident has recovered and a new
  /// independent incident begins later in the same ride.
  void startNewIncident(DateTime timestamp) {
    isActive = true;
    startedAt = timestamp;
    lastDetectedAt = timestamp;
    consecutiveCount = 1;
    activeEventCount = 0;

    notificationSent = false;
    lastNotificationAt = null;
    emailNotificationCount = 0;
    firstEmailAt = null;
    secondEmailAt = null;

    emergencyContactEmailSent = false;
    emergencyContactEmailAt = null;

    criticalNotificationSent = false;
    criticalNotificationAt = null;

    acknowledged = false;
    acknowledgedAt = null;

    driverRequestedHelp = false;
    driverRequestedHelpAt = null;
    driverResponseDeadline = null;
    driverResponseTimedOut = false;
    driverResponseTimedOutAt = null;

    // Legacy compatibility state.
    phoneCallSent = false;
    phoneCallAt = null;
    phoneCallResponseDeadline = null;
    driverRespondedAfterPhoneCall = false;

    emergencyContactEscalated = false;
    emergencyContactEscalatedAt = null;

    escalated = false;
    lastEscalationAt = null;
  }

  /// Returns how long the current continuous incident has lasted.
  Duration get activeDuration {
    return activeDurationAt(DateTime.now());
  }

  /// Returns how long the current continuous incident has lasted
  /// at [timestamp].
  ///
  /// This version is useful for deterministic Alert Engine testing.
  Duration activeDurationAt(DateTime timestamp) {
    if (!isActive || startedAt == null) {
      return Duration.zero;
    }

    final duration = timestamp.difference(startedAt!);

    if (duration.isNegative) {
      return Duration.zero;
    }

    return duration;
  }

  /// Returns true when the current incident has remained active
  /// for at least [duration].
  bool hasBeenActiveFor(Duration duration) {
    return isActive && activeDuration >= duration;
  }

  /// Returns true when the current incident has remained active
  /// for at least [duration] at [timestamp].
  bool hasBeenActiveForAt(
    Duration duration,
    DateTime timestamp,
  ) {
    return isActive && activeDurationAt(timestamp) >= duration;
  }

  // ============================================================
  // NORMAL NOTIFICATION
  // ============================================================

  /// Marks the normal notification as sent.
  void markNotificationSent(DateTime timestamp) {
    notificationSent = true;
    lastNotificationAt = timestamp;
  }

  /// Records one email stage for the current incident.
  ///
  /// Returns false when the maximum two email stages have already
  /// been used.
  bool recordEmailStage(DateTime timestamp) {
    if (emailNotificationCount >= 2) {
      return false;
    }

    emailNotificationCount++;

    if (emailNotificationCount == 1) {
      firstEmailAt = timestamp;
    } else {
      secondEmailAt = timestamp;
    }

    lastNotificationAt = timestamp;
    notificationSent = true;
    return true;
  }

  /// Returns true when both allowed email stages have been used.
  bool get emailLimitReached => emailNotificationCount >= 2;

  // ============================================================
  // CRITICAL NOTIFICATION
  // ============================================================

  /// Marks the critical notification stage as sent.
  ///
  /// In the new architecture this represents the critical
  /// in-app/email notification stage, not an SMS stage.
  void markCriticalNotificationSent(DateTime timestamp) {
    criticalNotificationSent = true;
    criticalNotificationAt = timestamp;
  }

  // ============================================================
  // DRIVER RESPONSE
  // ============================================================

  /// Starts the driver's response window.
  ///
  /// The Alert Engine supplies the deadline.
  void startDriverResponseWindow(DateTime deadline) {
    driverResponseDeadline = deadline;
    driverResponseTimedOut = false;
    driverResponseTimedOutAt = null;
  }

  /// Records that the driver selected "I'M SAFE".
  ///
  /// This is an explicit response and is never inferred automatically.
  void markAcknowledged(DateTime timestamp) {
    acknowledged = true;
    acknowledgedAt = timestamp;

    // Acknowledgement means the driver responded.
    // Therefore the response window can no longer time out.
    driverResponseTimedOut = false;
    driverResponseTimedOutAt = null;
  }

  /// Records that the driver selected "NEED HELP".
  ///
  /// This is intentionally different from [markAcknowledged].
  /// The driver has responded, but has explicitly requested
  /// emergency assistance.
  void markDriverRequestedHelp(DateTime timestamp) {
    driverRequestedHelp = true;
    driverRequestedHelpAt = timestamp;

    // The driver has responded, so this is not a no-response timeout.
    driverResponseTimedOut = false;
    driverResponseTimedOutAt = null;
  }

  /// Records that the driver's response window expired without
  /// an explicit response.
  ///
  /// The Alert Engine must call this only after the actual deadline
  /// has passed.
  void markDriverResponseTimedOut(DateTime timestamp) {
    if (acknowledged || driverRequestedHelp) {
      return;
    }

    if (driverResponseDeadline == null) {
      return;
    }

    if (timestamp.isBefore(driverResponseDeadline!)) {
      return;
    }

    driverResponseTimedOut = true;
    driverResponseTimedOutAt = timestamp;
  }

  /// Returns true when the driver has explicitly responded.
  ///
  /// A response means either:
  /// - I'M SAFE
  /// - NEED HELP
  bool get hasDriverResponded =>
      acknowledged || driverRequestedHelp;

  /// Returns true when the driver has not responded and the
  /// response deadline has expired.
  bool get hasNoDriverResponse =>
      driverResponseTimedOut &&
      !acknowledged &&
      !driverRequestedHelp;

  /// Returns true when a driver response deadline exists and has
  /// passed at [timestamp], without modifying state.
  bool responseDeadlineExpiredAt(DateTime timestamp) {
    if (driverResponseDeadline == null) {
      return false;
    }

    if (acknowledged || driverRequestedHelp) {
      return false;
    }

    return !timestamp.isBefore(driverResponseDeadline!);
  }

  /// Clears the driver's acknowledgement and response state.
  void clearDriverResponse() {
    acknowledged = false;
    acknowledgedAt = null;

    driverRequestedHelp = false;
    driverRequestedHelpAt = null;

    driverResponseDeadline = null;
    driverResponseTimedOut = false;
    driverResponseTimedOutAt = null;
  }

  // ============================================================
  // LEGACY PHONE-CALL COMPATIBILITY
  // ============================================================

  /// Legacy method retained temporarily while the Alert Engine is
  /// migrated away from phone-call escalation.
  ///
  /// This does not belong to any active rule in the new architecture.
  void markPhoneCallSent(
    DateTime timestamp, {
    DateTime? responseDeadline,
  }) {
    phoneCallSent = true;
    phoneCallAt = timestamp;
    phoneCallResponseDeadline = responseDeadline;
    driverRespondedAfterPhoneCall = false;
  }

  /// Legacy response method retained temporarily for compatibility.
  ///
  /// New driver acknowledgement should use [markAcknowledged] or
  /// [markDriverRequestedHelp].
  void markDriverResponse(DateTime timestamp) {
    if (!phoneCallSent || phoneCallAt == null) {
      return;
    }

    if (timestamp.isBefore(phoneCallAt!)) {
      return;
    }

    driverRespondedAfterPhoneCall = true;
    markAcknowledged(timestamp);
  }

  /// Legacy compatibility getter.
  bool get hasDriverRespondedAfterPhoneCall =>
      phoneCallSent && driverRespondedAfterPhoneCall;

  /// Legacy compatibility method.
  bool responseWindowExpiredAt(DateTime timestamp) {
    if (!phoneCallSent || driverRespondedAfterPhoneCall) {
      return false;
    }

    final deadline = phoneCallResponseDeadline;
    if (deadline == null) {
      return false;
    }

    return !timestamp.isBefore(deadline);
  }

  // ============================================================
  // EMERGENCY-CONTACT ESCALATION
  // ============================================================

  /// Marks emergency-contact email escalation as completed.
  void markEmergencyContactEmailSent(DateTime timestamp) {
    emergencyContactEmailSent = true;
    emergencyContactEmailAt = timestamp;

    // Keep the generic escalation state synchronized.
    markEscalated(timestamp);
  }

  /// Marks emergency-contact escalation as completed.
  ///
  /// Retained as the generic state method used by the current
  /// Alert State Manager.
  void markEmergencyContactEscalated(DateTime timestamp) {
    emergencyContactEscalated = true;
    emergencyContactEscalatedAt = timestamp;
    markEscalated(timestamp);
  }

  // ============================================================
  // GENERAL ESCALATION
  // ============================================================

  /// Marks the incident as escalated.
  void markEscalated(DateTime timestamp) {
    escalated = true;
    lastEscalationAt = timestamp;
  }

  // ============================================================
  // NOTIFICATION / ESCALATION RESET
  // ============================================================

  /// Resets notification and escalation state while preserving
  /// historical event information.
  ///
  /// Normally a completely new incident should use
  /// [startNewIncident] instead.
  ///
  /// This method is retained for compatibility with the existing
  /// Alert State Manager.
  void resetNotificationState() {
    notificationSent = false;
    lastNotificationAt = null;

    emailNotificationCount = 0;
    firstEmailAt = null;
    secondEmailAt = null;

    emergencyContactEmailSent = false;
    emergencyContactEmailAt = null;

    criticalNotificationSent = false;
    criticalNotificationAt = null;

    acknowledged = false;
    acknowledgedAt = null;

    driverRequestedHelp = false;
    driverRequestedHelpAt = null;
    driverResponseDeadline = null;
    driverResponseTimedOut = false;
    driverResponseTimedOutAt = null;

    // Legacy compatibility state.
    phoneCallSent = false;
    phoneCallAt = null;
    phoneCallResponseDeadline = null;
    driverRespondedAfterPhoneCall = false;

    emergencyContactEscalated = false;
    emergencyContactEscalatedAt = null;

    escalated = false;
    lastEscalationAt = null;
  }

  // ============================================================
  // COMPLETE RESET
  // ============================================================

  /// Completely resets this alert state.
  void reset() {
    isActive = false;
    startedAt = null;
    lastDetectedAt = null;

    consecutiveCount = 0;
    detectionCount = 0;

    occurrenceCount = 0;
    lastEventAt = null;
    activeEventCount = 0;

    notificationSent = false;
    lastNotificationAt = null;

    emailNotificationCount = 0;
    firstEmailAt = null;
    secondEmailAt = null;

    emergencyContactEmailSent = false;
    emergencyContactEmailAt = null;

    criticalNotificationSent = false;
    criticalNotificationAt = null;

    acknowledged = false;
    acknowledgedAt = null;

    driverRequestedHelp = false;
    driverRequestedHelpAt = null;
    driverResponseDeadline = null;
    driverResponseTimedOut = false;
    driverResponseTimedOutAt = null;

    // Legacy compatibility state.
    phoneCallSent = false;
    phoneCallAt = null;
    phoneCallResponseDeadline = null;
    driverRespondedAfterPhoneCall = false;

    emergencyContactEscalated = false;
    emergencyContactEscalatedAt = null;

    escalated = false;
    lastEscalationAt = null;
  }

  // ============================================================
  // COPY
  // ============================================================

  /// Creates a copy of the current alert state.
  AlertState copy() {
    return AlertState(
      ruleId: ruleId,
      isActive: isActive,
      startedAt: startedAt,
      lastDetectedAt: lastDetectedAt,
      consecutiveCount: consecutiveCount,
      detectionCount: detectionCount,
      occurrenceCount: occurrenceCount,
      lastEventAt: lastEventAt,
      activeEventCount: activeEventCount,
      notificationSent: notificationSent,
      lastNotificationAt: lastNotificationAt,
      emailNotificationCount: emailNotificationCount,
      firstEmailAt: firstEmailAt,
      secondEmailAt: secondEmailAt,
      emergencyContactEmailSent: emergencyContactEmailSent,
      emergencyContactEmailAt: emergencyContactEmailAt,
      criticalNotificationSent: criticalNotificationSent,
      criticalNotificationAt: criticalNotificationAt,
      acknowledged: acknowledged,
      acknowledgedAt: acknowledgedAt,
      driverRequestedHelp: driverRequestedHelp,
      driverRequestedHelpAt: driverRequestedHelpAt,
      driverResponseDeadline: driverResponseDeadline,
      driverResponseTimedOut: driverResponseTimedOut,
      driverResponseTimedOutAt: driverResponseTimedOutAt,
      phoneCallSent: phoneCallSent,
      phoneCallAt: phoneCallAt,
      phoneCallResponseDeadline: phoneCallResponseDeadline,
      driverRespondedAfterPhoneCall: driverRespondedAfterPhoneCall,
      emergencyContactEscalated: emergencyContactEscalated,
      emergencyContactEscalatedAt: emergencyContactEscalatedAt,
      escalated: escalated,
      lastEscalationAt: lastEscalationAt,
    );
  }
}

/// Manages the state of all alert rules for the current ride.
///
/// This class does not send notifications and does not evaluate AI data.
/// It only maintains the state required by the Alert Engine.
class AlertStateManager {
  final Map<String, AlertState> _states = {};

  /// Returns the state for a particular rule.
  ///
  /// If the rule does not have a state yet, a new state is created.
  AlertState stateFor(AlertRule rule) {
    return _states.putIfAbsent(
      rule.id,
      () => AlertState.forRule(rule),
    );
  }

  /// Returns a state by its rule ID.
  AlertState? stateForId(String ruleId) {
    return _states[ruleId];
  }

  /// Returns all current alert states.
  List<AlertState> get states {
    return _states.values.toList();
  }

  // ============================================================
  // DETECTION
  // ============================================================

  /// Records one AI detection for a rule.
  ///
  /// This tracks frame/detection continuity only.
  /// It does NOT increment the meaningful event count.
  void recordDetection(
    AlertRule rule, {
    DateTime? timestamp,
  }) {
    final state = stateFor(rule);

    state.recordDetection(
      timestamp ?? DateTime.now(),
    );
  }

  // ============================================================
  // EVENTS
  // ============================================================

  /// Records ONE confirmed meaningful event.
  ///
  /// This must be used for event counters such as completed yawns,
  /// rather than calling [recordDetection] repeatedly for every frame.
  void recordEvent(
    AlertRule rule, {
    DateTime? timestamp,
  }) {
    final state = stateFor(rule);

    state.recordEvent(
      timestamp ?? DateTime.now(),
    );
  }

  /// Records one meaningful event and starts an incident if needed.
  void recordEventAndActivate(
    AlertRule rule, {
    DateTime? timestamp,
  }) {
    final state = stateFor(rule);

    state.recordEventAndActivate(
      timestamp ?? DateTime.now(),
    );
  }

  // ============================================================
  // INCIDENT
  // ============================================================

  /// Clears the currently active condition for a rule.
  void clearCondition(AlertRule rule) {
    final state = stateFor(rule);
    state.clearActiveCondition();
  }

  /// Starts a fresh incident for a rule.
  void startNewIncident(
    AlertRule rule, {
    DateTime? timestamp,
  }) {
    final state = stateFor(rule);

    state.startNewIncident(
      timestamp ?? DateTime.now(),
    );
  }

  /// Checks whether a rule is currently active.
  bool isActive(String ruleId) {
    return _states[ruleId]?.isActive ?? false;
  }

  /// Returns the number of meaningful events for a rule.
  int occurrenceCount(String ruleId) {
    return _states[ruleId]?.occurrenceCount ?? 0;
  }

  /// Returns the number of meaningful events for a rule.
  int eventCount(String ruleId) {
    return _states[ruleId]?.eventCount ?? 0;
  }

  /// Returns the number of consecutive AI detections for a rule.
  ///
  /// This is a frame/detection count, not an event count.
  int consecutiveCount(String ruleId) {
    return _states[ruleId]?.consecutiveCount ?? 0;
  }

  /// Returns the total number of AI detections for a rule.
  int detectionCount(String ruleId) {
    return _states[ruleId]?.detectionCount ?? 0;
  }

  // ============================================================
  // NORMAL NOTIFICATION
  // ============================================================

  /// Marks the normal notification for a rule as sent.
  void markNotificationSent(
    String ruleId, {
    DateTime? timestamp,
  }) {
    final state = _states[ruleId];

    if (state == null) {
      return;
    }

    state.markNotificationSent(
      timestamp ?? DateTime.now(),
    );
  }

  // ============================================================
  // CRITICAL NOTIFICATION
  // ============================================================

  /// Marks the critical notification stage as sent.
  void markCriticalNotificationSent(
    String ruleId, {
    DateTime? timestamp,
  }) {
    final state = _states[ruleId];

    if (state == null) {
      return;
    }

    state.markCriticalNotificationSent(
      timestamp ?? DateTime.now(),
    );
  }

  // ============================================================
  // DRIVER RESPONSE
  // ============================================================

  /// Starts the response window for a driver.
  void startDriverResponseWindow(
    String ruleId, {
    required DateTime deadline,
  }) {
    final state = _states[ruleId];

    if (state == null) {
      return;
    }

    state.startDriverResponseWindow(deadline);
  }

  /// Records the driver's "I'M SAFE" response.
  void markAcknowledged(
    String ruleId, {
    DateTime? timestamp,
  }) {
    final state = _states[ruleId];

    if (state == null) {
      return;
    }

    state.markAcknowledged(
      timestamp ?? DateTime.now(),
    );
  }

  /// Records the driver's "NEED HELP" response.
  void markDriverRequestedHelp(
    String ruleId, {
    DateTime? timestamp,
  }) {
    final state = _states[ruleId];

    if (state == null) {
      return;
    }

    state.markDriverRequestedHelp(
      timestamp ?? DateTime.now(),
    );
  }

  /// Records that the driver's response window expired.
  void markDriverResponseTimedOut(
    String ruleId, {
    DateTime? timestamp,
  }) {
    final state = _states[ruleId];

    if (state == null) {
      return;
    }

    state.markDriverResponseTimedOut(
      timestamp ?? DateTime.now(),
    );
  }

  /// Returns whether the driver has explicitly responded.
  bool hasDriverResponded(String ruleId) {
    return _states[ruleId]?.hasDriverResponded ?? false;
  }

  /// Returns whether the driver explicitly requested help.
  bool driverRequestedHelp(String ruleId) {
    return _states[ruleId]?.driverRequestedHelp ?? false;
  }

  /// Returns whether the response window expired without a response.
  bool hasNoDriverResponse(String ruleId) {
    return _states[ruleId]?.hasNoDriverResponse ?? false;
  }

  /// Returns whether the response deadline has expired at [timestamp].
  bool responseDeadlineExpiredAt(
    String ruleId,
    DateTime timestamp,
  ) {
    return _states[ruleId]?.responseDeadlineExpiredAt(timestamp) ?? false;
  }

  /// Clears the driver's response state.
  void clearDriverResponse(String ruleId) {
    final state = _states[ruleId];

    if (state == null) {
      return;
    }

    state.clearDriverResponse();
  }

  // ============================================================
  // LEGACY PHONE-CALL COMPATIBILITY
  // ============================================================

  /// Legacy phone-call state method.
  ///
  /// Retained temporarily while the Alert Engine is migrated.
  void markPhoneCallSent(
    String ruleId, {
    DateTime? timestamp,
    DateTime? responseDeadline,
  }) {
    final state = _states[ruleId];

    if (state == null) {
      return;
    }

    state.markPhoneCallSent(
      timestamp ?? DateTime.now(),
      responseDeadline: responseDeadline,
    );
  }

  /// Legacy phone-call response method.
  void markDriverResponse(
    String ruleId, {
    DateTime? timestamp,
  }) {
    final state = _states[ruleId];

    if (state == null) {
      return;
    }

    state.markDriverResponse(
      timestamp ?? DateTime.now(),
    );
  }

  /// Legacy compatibility getter.
  bool hasDriverRespondedAfterPhoneCall(String ruleId) {
    return _states[ruleId]?.hasDriverRespondedAfterPhoneCall ?? false;
  }

  /// Legacy compatibility method.
  bool responseWindowExpiredForPhoneCall(
    String ruleId,
    DateTime timestamp,
  ) {
    return _states[ruleId]?.responseWindowExpiredAt(timestamp) ?? false;
  }

  // ============================================================
  // EMERGENCY CONTACT
  // ============================================================

  /// Marks emergency-contact email as sent.
  void markEmergencyContactEmailSent(
    String ruleId, {
    DateTime? timestamp,
  }) {
    final state = _states[ruleId];

    if (state == null) {
      return;
    }

    state.markEmergencyContactEmailSent(
      timestamp ?? DateTime.now(),
    );
  }

  /// Marks emergency-contact escalation as completed.
  void markEmergencyContactEscalated(
    String ruleId, {
    DateTime? timestamp,
  }) {
    final state = _states[ruleId];

    if (state == null) {
      return;
    }

    state.markEmergencyContactEscalated(
      timestamp ?? DateTime.now(),
    );
  }

  // ============================================================
  // GENERAL ESCALATION
  // ============================================================

  /// Marks a rule as escalated.
  void markEscalated(
    String ruleId, {
    DateTime? timestamp,
  }) {
    final state = _states[ruleId];

    if (state == null) {
      return;
    }

    state.markEscalated(
      timestamp ?? DateTime.now(),
    );
  }

  // ============================================================
  // RIDE RESET
  // ============================================================

  /// Resets all alert states for a new ride.
  void resetForNewRide() {
    _states.clear();
  }

  /// Resets notification and escalation status for all rules.
  ///
  /// Historical event/detection information is preserved.
  void resetNotificationStates() {
    for (final state in _states.values) {
      state.resetNotificationState();
    }
  }

  // ============================================================
  // SNAPSHOT
  // ============================================================

  /// Returns a copy of all current states.
  Map<String, AlertState> snapshot() {
    return {
      for (final entry in _states.entries)
        entry.key: entry.value.copy(),
    };
  }
}