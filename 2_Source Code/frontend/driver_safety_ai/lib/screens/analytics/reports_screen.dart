import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../services/monitoring_session_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late MonitoringSessionService _sessionService;

  @override
  void initState() {
    super.initState();
    _sessionService = MonitoringSessionService.instance;
  }

  @override
  Widget build(BuildContext context) {
    final sessions = _sessionService.sessions;

    // Get the latest completed monitoring session.
    final session = sessions.isNotEmpty ? sessions.last : null;

    // No completed session available.
    if (session == null) {
      return _buildNoSessionScreen(context);
    }

    final analysis = session.latestAnalysis;

    final int warnings = session.warningCount;
    final int critical = session.criticalCount;
    final int totalAnalyses = session.totalAnalyses;

    // ------------------------------------------------------------
    // Calculate a simple safety score for this session.
    // ------------------------------------------------------------

    int safetyScore = 100;

    if (totalAnalyses > 0) {
      final double warningImpact =
          (warnings / totalAnalyses) * 35;

      final double criticalImpact =
          (critical / totalAnalyses) * 65;

      safetyScore =
          (100 - warningImpact - criticalImpact)
              .round()
              .clamp(0, 100);
    }

    return Scaffold(
      backgroundColor: AppColors.background,

      // ==========================================================
      // APP BAR
      // ==========================================================

      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          'Safety Reports',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ==========================================================
      // BODY
      // ==========================================================

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ==================================================
              // LATEST SESSION REPORT
              // ==================================================

              const Text(
                'Latest Session Report',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: AppSpacing.md,
              ),

              _ReportCard(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    // --------------------------------------------
                    // SAFETY SCORE
                    // --------------------------------------------

                    Row(
                      children: [

                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primary
                                .withOpacity(0.15),
                            borderRadius:
                                BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.shield_outlined,
                            color: AppColors.primary,
                            size: 26,
                          ),
                        ),

                        const SizedBox(
                          width: AppSpacing.md,
                        ),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [

                              const Text(
                                'Overall Safety Score',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 15,
                                ),
                              ),

                              const SizedBox(
                                height: 4,
                              ),

                              Text(
                                '$safetyScore / 100',
                                style: TextStyle(
                                  color:
                                      _scoreColor(
                                    safetyScore,
                                  ),
                                  fontSize: 32,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: AppSpacing.md,
                    ),

                    // --------------------------------------------
                    // SESSION INFORMATION
                    // --------------------------------------------

                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(
                        AppSpacing.md,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface
                            .withOpacity(0.7),
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [

                          _InfoLine(
                            label:
                                'Session Duration',
                            value:
                                '${session.duration.inSeconds}s',
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          _InfoLine(
                            label:
                                'AI Analyses',
                            value:
                                '$totalAnalyses',
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          _InfoLine(
                            label:
                                'Warnings',
                            value:
                                '$warnings',
                          ),

                          const SizedBox(
                            height: 8,
                          ),

                          _InfoLine(
                            label:
                                'Critical Alerts',
                            value:
                                '$critical',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: AppSpacing.lg,
              ),

              // ==================================================
              // SESSION STATISTICS
              // ==================================================

              const Text(
                'Session Statistics',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: AppSpacing.md,
              ),

              LayoutBuilder(
                builder: (
                  context,
                  constraints,
                ) {

                  final double cardWidth;

                  if (constraints.maxWidth >= 700) {
                    cardWidth =
                        (constraints.maxWidth -
                                AppSpacing.md) /
                            2;
                  } else {
                    cardWidth =
                        (constraints.maxWidth -
                                AppSpacing.sm) /
                            2;
                  }

                  return Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,

                    children: [

                      // Duration
                      SizedBox(
                        width: cardWidth,
                        child: _StatisticCard(
                          icon:
                              Icons.timer_outlined,
                          title:
                              'Duration',
                          value:
                              '${session.duration.inSeconds}s',
                          iconColor:
                              AppColors.primary,
                        ),
                      ),

                      // Analyses
                      SizedBox(
                        width: cardWidth,
                        child: _StatisticCard(
                          icon:
                              Icons.analytics_outlined,
                          title:
                              'Analyses',
                          value:
                              '$totalAnalyses',
                          iconColor:
                              AppColors.success,
                        ),
                      ),

                      // Warnings
                      SizedBox(
                        width: cardWidth,
                        child: _StatisticCard(
                          icon:
                              Icons.warning_amber_outlined,
                          title:
                              'Warnings',
                          value:
                              '$warnings',
                          iconColor:
                              AppColors.warning,
                        ),
                      ),

                      // Critical
                      SizedBox(
                        width: cardWidth,
                        child: _StatisticCard(
                          icon:
                              Icons.error_outline,
                          title:
                              'Critical',
                          value:
                              '$critical',
                          iconColor:
                              AppColors.danger,
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(
                height: AppSpacing.lg,
              ),

              // ==================================================
              // AI SAFETY ANALYSIS
              // ==================================================

              const Text(
                'AI Safety Analysis',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: AppSpacing.md,
              ),

              _ReportCard(
                child: Column(
                  children: [

                    // --------------------------------------------
                    // EYE / BLINK
                    // --------------------------------------------

                    _AnalysisRow(
                      icon:
                          Icons.remove_red_eye_outlined,
                      title:
                          'Eye / Blink Analysis',
                      value:
                          'Blink Count: ${analysis?.blinkCount ?? 0}  |  ${analysis?.blinkRate ?? 0}/min',
                      iconColor:
                          AppColors.primary,
                    ),

                    const Divider(
                      color: Colors.white10,
                      height: 24,
                    ),

                    // --------------------------------------------
                    // YAWNING
                    // --------------------------------------------

                    _AnalysisRow(
                      icon:
                          Icons.sentiment_dissatisfied_outlined,
                      title:
                          'Yawning Detection',
                      value:
                          analysis?.yawning ??
                              'No data',
                      iconColor:
                          AppColors.warning,
                    ),

                    const Divider(
                      color: Colors.white10,
                      height: 24,
                    ),

                    // --------------------------------------------
                    // FATIGUE
                    // --------------------------------------------

                    _AnalysisRow(
                      icon:
                          Icons.bedtime_outlined,
                      title:
                          'Fatigue Detection',
                      value:
                          analysis?.fatigue ??
                              'No data',
                      iconColor:
                          AppColors.danger,
                    ),

                    const Divider(
                      color: Colors.white10,
                      height: 24,
                    ),

                    // --------------------------------------------
                    // HEAD POSITION
                    // --------------------------------------------

                    _AnalysisRow(
                      icon:
                          Icons.face_retouching_natural,
                      title:
                          'Head Position',
                      value:
                          analysis?.headPosition ??
                              'No data',
                      iconColor:
                          AppColors.success,
                    ),

                    const Divider(
                      color: Colors.white10,
                      height: 24,
                    ),

                    // --------------------------------------------
                    // EYES STATUS
                    // --------------------------------------------

                    _AnalysisRow(
                      icon:
                          Icons.visibility_outlined,
                      title:
                          'Eyes Status',
                      value:
                          analysis?.eyes ??
                              'No data',
                      iconColor:
                          AppColors.primary,
                    ),

                    const Divider(
                      color: Colors.white10,
                      height: 24,
                    ),

                    // --------------------------------------------
                    // ALERT STATUS
                    // --------------------------------------------

                    _AnalysisRow(
                      icon:
                          Icons.notifications_active_outlined,
                      title:
                          'Alert Status',
                      value:
                          analysis?.alert ??
                              'No data',
                      iconColor:
                          _alertColor(
                        analysis?.alert ?? '',
                      ),
                    ),

                    const Divider(
                      color: Colors.white10,
                      height: 24,
                    ),

                    // --------------------------------------------
                    // CLOSED DURATION
                    // --------------------------------------------

                    _AnalysisRow(
                      icon:
                          Icons.timer_outlined,
                      title:
                          'Closed Duration',
                      value:
                          '${analysis?.closedDuration ?? '0.00'}s',
                      iconColor:
                          AppColors.warning,
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: AppSpacing.lg,
              ),

              // ==================================================
              // SESSION SUMMARY
              // ==================================================

              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.all(
                  AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color:
                      AppColors.primary
                          .withOpacity(0.08),
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color:
                        AppColors.primary
                            .withOpacity(0.20),
                  ),
                ),

                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [

                    const Icon(
                      Icons.auto_awesome_outlined,
                      color: AppColors.primary,
                      size: 24,
                    ),

                    const SizedBox(
                      width: AppSpacing.md,
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [

                          const Text(
                            'Session Summary',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),

                          const SizedBox(
                            height: 6,
                          ),

                          Text(
                            _buildSummary(
                              session,
                              safetyScore,
                            ),
                            style:
                                const TextStyle(
                              color:
                                  Colors.white70,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: AppSpacing.xl,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // NO SESSION SCREEN
  // ========================================================================

  Widget _buildNoSessionScreen(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          AppColors.background,

      appBar: AppBar(
        backgroundColor:
            AppColors.background,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          'Safety Reports',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      body: Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),

          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,

            children: [

              const Icon(
                Icons.analytics_outlined,
                color: AppColors.primary,
                size: 64,
              ),

              const SizedBox(
                height: 20,
              ),

              const Text(
                'No completed session yet',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),

              const SizedBox(
                height: 10,
              ),

              const Text(
                'Complete an AI monitoring session to view your safety report.',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// ============================================================================
// REPORT CARD
// ============================================================================

class _ReportCard extends StatelessWidget {
  final Widget child;

  const _ReportCard({
    required this.child,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(
        AppSpacing.md,
      ),

      decoration: BoxDecoration(
        color: AppColors.card,

        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(
          color:
              Colors.white.withOpacity(0.06),
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),

      child: child,
    );
  }
}


// ============================================================================
// STATISTIC CARD
// ============================================================================

class _StatisticCard
    extends StatelessWidget {

  final IconData icon;
  final String title;
  final String value;
  final Color iconColor;

  const _StatisticCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.all(
        AppSpacing.md,
      ),

      decoration: BoxDecoration(
        color:
            AppColors.card,

        borderRadius:
            BorderRadius.circular(18),

        border: Border.all(
          color:
              Colors.white.withOpacity(0.06),
        ),
      ),

      child: Row(
        children: [

          Container(
            width: 44,
            height: 44,

            decoration: BoxDecoration(
              color:
                  iconColor.withOpacity(0.12),
              borderRadius:
                  BorderRadius.circular(12),
            ),

            child: Icon(
              icon,
              color: iconColor,
              size: 23,
            ),
          ),

          const SizedBox(
            width: AppSpacing.md,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(
                  title,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    color:
                        Colors.white60,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  value,

                  style:
                      const TextStyle(
                    color:
                        Colors.white,
                    fontSize: 22,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


// ============================================================================
// ANALYSIS ROW
// ============================================================================

class _AnalysisRow
    extends StatelessWidget {

  final IconData icon;
  final String title;
  final String value;
  final Color iconColor;

  const _AnalysisRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [

        Container(
          width: 42,
          height: 42,

          decoration: BoxDecoration(
            color:
                iconColor.withOpacity(0.12),
            borderRadius:
                BorderRadius.circular(11),
          ),

          child: Icon(
            icon,
            color: iconColor,
            size: 22,
          ),
        ),

        const SizedBox(
          width: AppSpacing.md,
        ),

        Expanded(
          child: Text(
            title,

            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ),

        Flexible(
          child: Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 6,
            ),

            decoration: BoxDecoration(
              color:
                  Colors.white.withOpacity(0.06),
              borderRadius:
                  BorderRadius.circular(8),
            ),

            child: Text(
              value,

              textAlign:
                  TextAlign.right,

              style:
                  const TextStyle(
                color:
                    Colors.white70,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}


// ============================================================================
// INFO LINE
// ============================================================================

class _InfoLine
    extends StatelessWidget {

  final String label;
  final String value;

  const _InfoLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,

      children: [

        Text(
          label,

          style:
              const TextStyle(
            color:
                Colors.white70,
            fontSize: 13,
          ),
        ),

        Text(
          value,

          style:
              const TextStyle(
            color:
                Colors.white,
            fontSize: 13,
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }
}


// ============================================================================
// SCORE COLOR
// ============================================================================

Color _scoreColor(
  int score,
) {
  if (score >= 80) {
    return AppColors.success;
  }

  if (score >= 50) {
    return AppColors.warning;
  }

  return AppColors.danger;
}


// ============================================================================
// ALERT COLOR
// ============================================================================

Color _alertColor(
  String alert,
) {
  final value =
      alert.toLowerCase();

  if (value.contains('critical') ||
      value.contains('danger')) {
    return AppColors.danger;
  }

  if (value.contains('warning')) {
    return AppColors.warning;
  }

  return AppColors.success;
}


// ============================================================================
// SESSION SUMMARY
// ============================================================================

String _buildSummary(
  MonitoringSession session,
  int safetyScore,
) {
  if (session.hasCriticalAlerts) {
    return 'The session recorded critical safety events. '
        'The driver should pay close attention to fatigue '
        'and prolonged eye-closure conditions.';
  }

  if (session.hasWarnings) {
    return 'The session recorded warning-level safety events. '
        'The driver should remain attentive and monitor '
        'fatigue indicators.';
  }

  return 'The monitoring session completed without '
      'major safety concerns. The recorded AI analysis '
      'indicates generally safe driving behavior.';
}