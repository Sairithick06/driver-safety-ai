import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../services/monitoring_session_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  MonitoringSessionService get sessionService =>
      MonitoringSessionService.instance;

  @override
  Widget build(BuildContext context) {
    final completedSessions = sessionService.sessions.reversed.toList();
    final currentSession = sessionService.currentSession;

    final bool hasHistory =
        currentSession != null || completedSessions.isNotEmpty;

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
          'Monitoring History',
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
        child: !hasHistory
            ? _buildEmptyState()
            : RefreshIndicator(
                color: AppColors.primary,
                backgroundColor: AppColors.card,
                onRefresh: _refreshHistory,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ==================================================
                      // HEADER
                      // ==================================================

                      _buildHeader(
                        currentSession: currentSession,
                        completedCount: completedSessions.length,
                      ),

                      const SizedBox(
                        height: AppSpacing.lg,
                      ),

                      // ==================================================
                      // CURRENT SESSION
                      // ==================================================

                      if (currentSession != null) ...[
                        const _SectionTitle(
                          title: 'Current Session',
                          icon: Icons.radio_button_checked,
                        ),

                        const SizedBox(
                          height: AppSpacing.sm,
                        ),

                        _CurrentSessionCard(
                          session: currentSession,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    HistoryDetailScreen(
                                  session: currentSession,
                                  isCurrentSession: true,
                                ),
                              ),
                            ).then((_) {
                              if (mounted) {
                                setState(() {});
                              }
                            });
                          },
                        ),

                        const SizedBox(
                          height: AppSpacing.xl,
                        ),
                      ],

                      // ==================================================
                      // PAST SESSIONS
                      // ==================================================

                      if (completedSessions.isNotEmpty) ...[
                        const _SectionTitle(
                          title: 'Past Sessions',
                          icon: Icons.history,
                        ),

                        const SizedBox(
                          height: AppSpacing.sm,
                        ),

                        ...completedSessions.map(
                          (session) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AppSpacing.md,
                            ),
                            child: _HistorySessionCard(
                              session: session,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        HistoryDetailScreen(
                                      session: session,
                                      isCurrentSession: false,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(
                        height: AppSpacing.lg,
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ==============================================================
  // HEADER
  // ==============================================================

  Widget _buildHeader({
    required MonitoringSession? currentSession,
    required int completedCount,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.timeline,
              color: AppColors.primary,
              size: 25,
            ),
          ),

          const SizedBox(
            width: AppSpacing.md,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Monitoring Timeline',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  currentSession != null
                      ? '$completedCount completed • 1 in progress'
                      : '$completedCount completed session${completedCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // EMPTY STATE
  // ==============================================================

  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.history_outlined,
                color: AppColors.primary,
                size: 42,
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              'No Monitoring History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(
              height: 8,
            ),

            const Text(
              'Completed monitoring sessions will appear here.',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ==============================================================
  // REFRESH
  // ==============================================================

  Future<void> _refreshHistory() async {
    setState(() {});

    await Future.delayed(
      const Duration(milliseconds: 300),
    );
  }
}

// ================================================================
// SECTION TITLE
// ================================================================

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionTitle({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 19,
        ),

        const SizedBox(
          width: 8,
        ),

        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// CURRENT SESSION CARD
// ================================================================

class _CurrentSessionCard extends StatelessWidget {
  final MonitoringSession session;
  final VoidCallback onTap;

  const _CurrentSessionCard({
    required this.session,
    required this.onTap,
  });

  // IMPORTANT:
  // This fixes the original _formatDuration error.
  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }

    return '${seconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final latest = session.latestAnalysis;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.40),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --------------------------------------------------------
            // STATUS
            // --------------------------------------------------------

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),

                      const SizedBox(
                        width: 7,
                      ),

                      const Text(
                        'IN PROGRESS',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                const Icon(
                  Icons.chevron_right,
                  color: AppColors.primary,
                ),
              ],
            ),

            const SizedBox(
              height: AppSpacing.md,
            ),

            // --------------------------------------------------------
            // DATE
            // --------------------------------------------------------

            Text(
              _formatDate(session.startTime),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              'Started at ${_formatTime(session.startTime)}',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
              ),
            ),

            const SizedBox(
              height: AppSpacing.md,
            ),

            // --------------------------------------------------------
            // STATS
            // --------------------------------------------------------

            Row(
              children: [
                Expanded(
                  child: _CompactStat(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: _formatDuration(session.duration),
                  ),
                ),
                Expanded(
                  child: _CompactStat(
                    icon: Icons.analytics_outlined,
                    label: 'Analyses',
                    value: '${session.totalAnalyses}',
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: AppSpacing.sm,
            ),

            Row(
              children: [
                Expanded(
                  child: _CompactStat(
                    icon: Icons.warning_amber_rounded,
                    label: 'Warnings',
                    value: '${session.warningCount}',
                  ),
                ),
                Expanded(
                  child: _CompactStat(
                    icon: Icons.error_outline,
                    label: 'Critical',
                    value: '${session.criticalCount}',
                  ),
                ),
              ],
            ),

            // --------------------------------------------------------
            // LATEST STATUS
            // --------------------------------------------------------

            if (latest != null) ...[
              const SizedBox(
                height: AppSpacing.md,
              ),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.background.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.insights_outlined,
                      color: AppColors.primary,
                      size: 18,
                    ),

                    const SizedBox(
                      width: 8,
                    ),

                    Expanded(
                      child: Text(
                        'Latest status: ${latest.fatigue}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ================================================================
// PAST SESSION CARD
// ================================================================

class _HistorySessionCard extends StatelessWidget {
  final MonitoringSession session;
  final VoidCallback onTap;

  const _HistorySessionCard({
    required this.session,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final status = _getStatus(session);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.white.withOpacity(0.06),
          ),
        ),
        child: Column(
          children: [
            // --------------------------------------------------------
            // TOP ROW
            // --------------------------------------------------------

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: status.backgroundColor,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    status.icon,
                    color: status.color,
                    size: 23,
                  ),
                ),

                const SizedBox(
                  width: AppSpacing.md,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatDate(session.startTime),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(
                        height: 4,
                      ),

                      Text(
                        '${_formatTime(session.startTime)} • ${_formatDuration(session.duration)}',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                _StatusBadge(
                  text: status.label,
                  color: status.color,
                ),
              ],
            ),

            const SizedBox(
              height: AppSpacing.md,
            ),

            // --------------------------------------------------------
            // QUICK METRICS
            // --------------------------------------------------------

            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: AppColors.background.withOpacity(0.32),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _MiniMetric(
                      icon: Icons.timer_outlined,
                      value: _formatDuration(session.duration),
                      label: 'Duration',
                    ),
                  ),

                  const _VerticalDivider(),

                  Expanded(
                    child: _MiniMetric(
                      icon: Icons.analytics_outlined,
                      value: '${session.totalAnalyses}',
                      label: 'Analyses',
                    ),
                  ),

                  const _VerticalDivider(),

                  Expanded(
                    child: _MiniMetric(
                      icon: Icons.warning_amber_rounded,
                      value: '${session.warningCount}',
                      label: 'Warnings',
                    ),
                  ),

                  const _VerticalDivider(),

                  Expanded(
                    child: _MiniMetric(
                      icon: Icons.error_outline,
                      value: '${session.criticalCount}',
                      label: 'Critical',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              height: AppSpacing.sm,
            ),

            // --------------------------------------------------------
            // VIEW BUTTON
            // --------------------------------------------------------

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text(
                  'View session',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  width: 5,
                ),

                const Icon(
                  Icons.arrow_forward_ios,
                  size: 11,
                  color: AppColors.primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// HISTORY DETAIL SCREEN
// ================================================================

class HistoryDetailScreen extends StatelessWidget {
  final MonitoringSession session;
  final bool isCurrentSession;

  const HistoryDetailScreen({
    super.key,
    required this.session,
    this.isCurrentSession = false,
  });

  @override
  Widget build(BuildContext context) {
    final status = _getStatus(session);

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
          'Session Details',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
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
              // ======================================================
              // SESSION STATUS
              // ======================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: status.backgroundColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: status.color.withOpacity(0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: status.color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        status.icon,
                        color: status.color,
                        size: 25,
                      ),
                    ),

                    const SizedBox(
                      width: AppSpacing.md,
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isCurrentSession
                                ? 'Session In Progress'
                                : status.label,
                            style: TextStyle(
                              color: status.color,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          Text(
                            _formatDateTime(session.startTime),
                            style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                            ),
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

              // ======================================================
              // SESSION INFORMATION
              // ======================================================

              const _DetailSectionTitle(
                title: 'Session Information',
                icon: Icons.info_outline,
              ),

              const SizedBox(
                height: AppSpacing.sm,
              ),

              _InfoCard(
                children: [
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: 'Date',
                    value: _formatDate(session.startTime),
                  ),

                  _InfoRow(
                    icon: Icons.access_time,
                    label: 'Start Time',
                    value: _formatTime(session.startTime),
                  ),

                  _InfoRow(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: _formatDuration(session.duration),
                  ),

                  _InfoRow(
                    icon: Icons.analytics_outlined,
                    label: 'AI Analyses',
                    value: '${session.totalAnalyses}',
                  ),

                  _InfoRow(
                    icon: Icons.warning_amber_rounded,
                    label: 'Warnings',
                    value: '${session.warningCount}',
                  ),

                  _InfoRow(
                    icon: Icons.error_outline,
                    label: 'Critical Alerts',
                    value: '${session.criticalCount}',
                  ),
                ],
              ),

              const SizedBox(
                height: AppSpacing.lg,
              ),

              // ======================================================
              // ACTIVITY
              // ======================================================

              const _DetailSectionTitle(
                title: 'Session Activity',
                icon: Icons.timeline,
              ),

              const SizedBox(
                height: AppSpacing.sm,
              ),

              _ActivitySummaryCard(
                session: session,
              ),

              const SizedBox(
                height: AppSpacing.lg,
              ),

              // ======================================================
              // LATEST STATUS
              // ======================================================

              if (session.latestAnalysis != null) ...[
                const _DetailSectionTitle(
                  title: 'Latest Status',
                  icon: Icons.insights_outlined,
                ),

                const SizedBox(
                  height: AppSpacing.sm,
                ),

                _LatestStatusCard(
                  analysis: session.latestAnalysis!,
                ),

                const SizedBox(
                  height: AppSpacing.lg,
                ),
              ],

              // ======================================================
              // REPORT REDIRECTION
              // ======================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.12),
                  ),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 20,
                    ),

                    SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child: Text(
                        'History shows session activity and timeline information. Open Reports for the complete detailed safety report.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                height: AppSpacing.lg,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// ACTIVITY SUMMARY CARD
// ================================================================

class _ActivitySummaryCard extends StatelessWidget {
  final MonitoringSession session;

  const _ActivitySummaryCard({
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final total = session.totalAnalyses;

    String message;

    if (total == 0) {
      message = 'No AI analysis has been recorded yet.';
    } else if (session.hasCriticalAlerts) {
      message =
          '${session.criticalCount} critical alert records were detected during this session.';
    } else if (session.hasWarnings) {
      message =
          '${session.warningCount} warning records were detected during this session.';
    } else {
      message =
          'No warning or critical records were detected during this session.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                color: AppColors.primary,
                size: 21,
              ),

              const SizedBox(
                width: 9,
              ),

              const Text(
                'Monitoring Activity',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          Row(
            children: [
              Expanded(
                child: _ActivityStat(
                  label: 'Analyses',
                  value: '$total',
                ),
              ),

              Expanded(
                child: _ActivityStat(
                  label: 'Warnings',
                  value: '${session.warningCount}',
                ),
              ),

              Expanded(
                child: _ActivityStat(
                  label: 'Critical',
                  value: '${session.criticalCount}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ================================================================
// LATEST STATUS CARD
// ================================================================

class _LatestStatusCard extends StatelessWidget {
  final MonitoringAnalysis analysis;

  const _LatestStatusCard({
    required this.analysis,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.06),
        ),
      ),
      child: Column(
        children: [
          _LatestRow(
            label: 'Eyes',
            value: analysis.eyes,
          ),

          _LatestRow(
            label: 'Yawning',
            value: analysis.yawning,
          ),

          _LatestRow(
            label: 'Fatigue',
            value: analysis.fatigue,
          ),

          _LatestRow(
            label: 'Head Position',
            value: analysis.headPosition,
          ),

          _LatestRow(
            label: 'Alert',
            value: analysis.alert,
          ),

          _LatestRow(
            label: 'Blink Count',
            value: analysis.blinkCount,
          ),

          _LatestRow(
            label: 'Closed Duration',
            value: '${analysis.closedDuration}s',
          ),
        ],
      ),
    );
  }
}

// ================================================================
// COMPACT STAT
// ================================================================

class _CompactStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CompactStat({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: AppColors.primary,
        ),

        const SizedBox(
          width: 8,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 11,
                ),
              ),

              const SizedBox(
                height: 2,
              ),

              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ================================================================
// MINI METRIC
// ================================================================

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _MiniMetric({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 17,
          color: AppColors.primary,
        ),

        const SizedBox(
          height: 5,
        ),

        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(
          height: 2,
        ),

        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 9,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ================================================================
// ACTIVITY STAT
// ================================================================

class _ActivityStat extends StatelessWidget {
  final String label;
  final String value;

  const _ActivityStat({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),

        const SizedBox(
          height: 3,
        ),

        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// INFO CARD
// ================================================================

class _InfoCard extends StatelessWidget {
  final List<Widget> children;

  const _InfoCard({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

// ================================================================
// INFO ROW
// ================================================================

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 11,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.primary,
          ),

          const SizedBox(
            width: 12,
          ),

          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ),

          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// LATEST ROW
// ================================================================

class _LatestRow extends StatelessWidget {
  final String label;
  final String value;

  const _LatestRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 9,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// STATUS BADGE
// ================================================================

class _StatusBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _StatusBadge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ================================================================
// VERTICAL DIVIDER
// ================================================================

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 38,
      margin: const EdgeInsets.symmetric(
        horizontal: 3,
      ),
      color: Colors.white.withOpacity(0.08),
    );
  }
}

// ================================================================
// DETAIL SECTION TITLE
// ================================================================

class _DetailSectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;

  const _DetailSectionTitle({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 19,
          color: AppColors.primary,
        ),

        const SizedBox(
          width: 8,
        ),

        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ================================================================
// SESSION STATUS
// ================================================================

class _SessionStatus {
  final String label;
  final IconData icon;
  final Color color;
  final Color backgroundColor;

  const _SessionStatus({
    required this.label,
    required this.icon,
    required this.color,
    required this.backgroundColor,
  });
}

_SessionStatus _getStatus(MonitoringSession session) {
  if (session.hasCriticalAlerts) {
    return _SessionStatus(
      label: 'CRITICAL',
      icon: Icons.error_outline,
      color: AppColors.danger,
      backgroundColor: AppColors.danger.withOpacity(0.08),
    );
  }

  if (session.hasWarnings) {
    return _SessionStatus(
      label: 'WARNING',
      icon: Icons.warning_amber_rounded,
      color: AppColors.warning,
      backgroundColor: AppColors.warning.withOpacity(0.08),
    );
  }

  return _SessionStatus(
    label: 'SAFE',
    icon: Icons.check_circle_outline,
    color: AppColors.success,
    backgroundColor: AppColors.success.withOpacity(0.08),
  );
}

// ================================================================
// DATE
// ================================================================

String _formatDate(DateTime dateTime) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  return '${months[dateTime.month - 1]} ${dateTime.day}, ${dateTime.year}';
}

// ================================================================
// TIME
// ================================================================

String _formatTime(DateTime dateTime) {
  final hour = dateTime.hour;
  final minute = dateTime.minute;

  final period = hour >= 12 ? 'PM' : 'AM';

  final displayHour =
      hour % 12 == 0 ? 12 : hour % 12;

  return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
}

// ================================================================
// DATE + TIME
// ================================================================

String _formatDateTime(DateTime dateTime) {
  return '${_formatDate(dateTime)} • ${_formatTime(dateTime)}';
}

// ================================================================
// DURATION
// ==============================================================

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);

  if (hours > 0) {
    return '${hours}h ${minutes}m';
  }

  if (minutes > 0) {
    return '${minutes}m ${seconds}s';
  }

  return '${seconds}s';
}