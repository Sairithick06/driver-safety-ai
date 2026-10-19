import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';



import '../../core/theme/app_colors.dart';

import '../../core/theme/app_spacing.dart';

import '../auth/login/login_screen.dart';



class SettingsScreen extends StatefulWidget {

  const SettingsScreen({super.key});



  @override

  State<SettingsScreen> createState() => _SettingsScreenState();

}



class _SettingsScreenState extends State<SettingsScreen> {

  // ============================================================

  // DEFAULT SETTINGS

  // ============================================================



  static const bool _defaultNotificationsEnabled = true;

  static const bool _defaultSoundEnabled = true;

  static const bool _defaultVibrationEnabled = true;

  static const bool _defaultAutoStartMonitoring = false;



  static const double _defaultAlertSensitivity = 0.5;



  static const bool _defaultEyeClosureEnabled = true;

  static const bool _defaultYawningEnabled = true;

  static const bool _defaultHeadPositionEnabled = true;

  static const bool _defaultCriticalAlertsEnabled = true;



  static const bool _defaultBreakReminderEnabled = true;

  static const double _defaultDailyDrivingGoal = 4.0;



  static const int _defaultDrivingTimeSeconds = 0;

  static const int _defaultMonitoringSessions = 0;

  static const int _defaultSafeDrivingStreak = 0;



  // ============================================================

  // SETTINGS VALUES

  // ============================================================



  bool notificationsEnabled = _defaultNotificationsEnabled;

  bool soundEnabled = _defaultSoundEnabled;

  bool vibrationEnabled = _defaultVibrationEnabled;



  bool autoStartMonitoring = _defaultAutoStartMonitoring;



  double alertSensitivity = _defaultAlertSensitivity;



  bool eyeClosureEnabled = _defaultEyeClosureEnabled;

  bool yawningEnabled = _defaultYawningEnabled;

  bool headPositionEnabled = _defaultHeadPositionEnabled;

  bool criticalAlertsEnabled = _defaultCriticalAlertsEnabled;



  bool breakReminderEnabled = _defaultBreakReminderEnabled;



  double dailyDrivingGoal = _defaultDailyDrivingGoal;



  int drivingTimeSeconds = _defaultDrivingTimeSeconds;

  int monitoringSessions = _defaultMonitoringSessions;

  int safeDrivingStreak = _defaultSafeDrivingStreak;



  bool _isLoadingSettings = true;



  // ============================================================

  // SHARED PREFERENCES KEYS

  // ============================================================



  static const String _notificationsKey =

      'settings_notifications_enabled';



  static const String _soundKey =

      'settings_sound_enabled';



  static const String _vibrationKey =

      'settings_vibration_enabled';



  static const String _autoStartKey =

      'settings_auto_start_monitoring';



  static const String _sensitivityKey =

      'settings_alert_sensitivity';



  static const String _eyeClosureKey =

      'settings_eye_closure_enabled';



  static const String _yawningKey =

      'settings_yawning_enabled';



  static const String _headPositionKey =

      'settings_head_position_enabled';



  static const String _criticalAlertsKey =

      'settings_critical_alerts_enabled';



  static const String _breakReminderKey =

      'settings_break_reminder_enabled';



  static const String _dailyGoalKey =

      'settings_daily_driving_goal';



  static const String _drivingTimeKey =

      'wellbeing_driving_time_seconds';



  static const String _sessionsKey =

      'wellbeing_monitoring_sessions';



  static const String _safeStreakKey =

      'wellbeing_safe_driving_streak';



  // ============================================================

  // INITIALIZATION

  // ============================================================



  @override

  void initState() {

    super.initState();

    _loadSettings();

  }



  // ============================================================

  // LOAD SETTINGS

  // ============================================================



  Future<void> _loadSettings() async {

    try {

      final prefs = await SharedPreferences.getInstance();



      final loadedNotifications =

          prefs.getBool(_notificationsKey) ??

              _defaultNotificationsEnabled;



      final loadedSound =

          prefs.getBool(_soundKey) ??

              _defaultSoundEnabled;



      final loadedVibration =

          prefs.getBool(_vibrationKey) ??

              _defaultVibrationEnabled;



      final loadedAutoStart =

          prefs.getBool(_autoStartKey) ??

              _defaultAutoStartMonitoring;



      final loadedSensitivity =

          prefs.getDouble(_sensitivityKey) ??

              _defaultAlertSensitivity;



      final loadedEyeClosure =

          prefs.getBool(_eyeClosureKey) ??

              _defaultEyeClosureEnabled;



      final loadedYawning =

          prefs.getBool(_yawningKey) ??

              _defaultYawningEnabled;



      final loadedHeadPosition =

          prefs.getBool(_headPositionKey) ??

              _defaultHeadPositionEnabled;



      final loadedCriticalAlerts =

          prefs.getBool(_criticalAlertsKey) ??

              _defaultCriticalAlertsEnabled;



      final loadedBreakReminder =

          prefs.getBool(_breakReminderKey) ??

              _defaultBreakReminderEnabled;



      final loadedDailyGoal =

          prefs.getDouble(_dailyGoalKey) ??

              _defaultDailyDrivingGoal;



      final loadedDrivingTime =

          prefs.getInt(_drivingTimeKey) ??

              _defaultDrivingTimeSeconds;



      final loadedSessions =

          prefs.getInt(_sessionsKey) ??

              _defaultMonitoringSessions;



      final loadedSafeStreak =

          prefs.getInt(_safeStreakKey) ??

              _defaultSafeDrivingStreak;



      if (!mounted) return;



      setState(() {

        notificationsEnabled = loadedNotifications;

        soundEnabled = loadedSound;

        vibrationEnabled = loadedVibration;



        autoStartMonitoring = loadedAutoStart;



        alertSensitivity =

            loadedSensitivity.clamp(0.0, 1.0).toDouble();



        eyeClosureEnabled = loadedEyeClosure;

        yawningEnabled = loadedYawning;

        headPositionEnabled = loadedHeadPosition;

        criticalAlertsEnabled = loadedCriticalAlerts;



        breakReminderEnabled = loadedBreakReminder;



        dailyDrivingGoal =

            loadedDailyGoal.clamp(1.0, 12.0).toDouble();



        drivingTimeSeconds =

            loadedDrivingTime < 0 ? 0 : loadedDrivingTime;



        monitoringSessions =

            loadedSessions < 0 ? 0 : loadedSessions;



        safeDrivingStreak =

            loadedSafeStreak < 0 ? 0 : loadedSafeStreak;



        _isLoadingSettings = false;

      });

    } catch (e) {

      if (!mounted) return;



      setState(() {

        _isLoadingSettings = false;

      });



      _showMessage(

        'Unable to load saved settings.',

      );

    }

  }



  // ============================================================

  // SAVE SETTINGS

  // ============================================================



  Future<void> _saveSettings() async {

    try {

      final prefs = await SharedPreferences.getInstance();



      await prefs.setBool(

        _notificationsKey,

        notificationsEnabled,

      );



      await prefs.setBool(

        _soundKey,

        soundEnabled,

      );



      await prefs.setBool(

        _vibrationKey,

        vibrationEnabled,

      );



      await prefs.setBool(

        _autoStartKey,

        autoStartMonitoring,

      );



      await prefs.setDouble(

        _sensitivityKey,

        alertSensitivity,

      );



      await prefs.setBool(

        _eyeClosureKey,

        eyeClosureEnabled,

      );



      await prefs.setBool(

        _yawningKey,

        yawningEnabled,

      );



      await prefs.setBool(

        _headPositionKey,

        headPositionEnabled,

      );



      await prefs.setBool(

        _criticalAlertsKey,

        criticalAlertsEnabled,

      );



      await prefs.setBool(

        _breakReminderKey,

        breakReminderEnabled,

      );



      await prefs.setDouble(

        _dailyGoalKey,

        dailyDrivingGoal,

      );



      await prefs.setInt(

        _drivingTimeKey,

        drivingTimeSeconds,

      );



      await prefs.setInt(

        _sessionsKey,

        monitoringSessions,

      );



      await prefs.setInt(

        _safeStreakKey,

        safeDrivingStreak,

      );

    } catch (e) {

      if (!mounted) return;



      _showMessage(

        'Unable to save settings.',

      );

    }

  }



  // ============================================================

  // RESET SETTINGS

  // ============================================================



  Future<void> _resetSettings() async {

    try {

      final prefs = await SharedPreferences.getInstance();



      await prefs.setBool(

        _notificationsKey,

        _defaultNotificationsEnabled,

      );



      await prefs.setBool(

        _soundKey,

        _defaultSoundEnabled,

      );



      await prefs.setBool(

        _vibrationKey,

        _defaultVibrationEnabled,

      );



      await prefs.setBool(

        _autoStartKey,

        _defaultAutoStartMonitoring,

      );



      await prefs.setDouble(

        _sensitivityKey,

        _defaultAlertSensitivity,

      );



      await prefs.setBool(

        _eyeClosureKey,

        _defaultEyeClosureEnabled,

      );



      await prefs.setBool(

        _yawningKey,

        _defaultYawningEnabled,

      );



      await prefs.setBool(

        _headPositionKey,

        _defaultHeadPositionEnabled,

      );



      await prefs.setBool(

        _criticalAlertsKey,

        _defaultCriticalAlertsEnabled,

      );



      await prefs.setBool(

        _breakReminderKey,

        _defaultBreakReminderEnabled,

      );



      await prefs.setDouble(

        _dailyGoalKey,

        _defaultDailyDrivingGoal,

      );



      await prefs.setInt(

        _drivingTimeKey,

        _defaultDrivingTimeSeconds,

      );



      await prefs.setInt(

        _sessionsKey,

        _defaultMonitoringSessions,

      );



      await prefs.setInt(

        _safeStreakKey,

        _defaultSafeDrivingStreak,

      );



      if (!mounted) return;



      setState(() {

        notificationsEnabled =

            _defaultNotificationsEnabled;



        soundEnabled =

            _defaultSoundEnabled;



        vibrationEnabled =

            _defaultVibrationEnabled;



        autoStartMonitoring =

            _defaultAutoStartMonitoring;



        alertSensitivity =

            _defaultAlertSensitivity;



        eyeClosureEnabled =

            _defaultEyeClosureEnabled;



        yawningEnabled =

            _defaultYawningEnabled;



        headPositionEnabled =

            _defaultHeadPositionEnabled;



        criticalAlertsEnabled =

            _defaultCriticalAlertsEnabled;



        breakReminderEnabled =

            _defaultBreakReminderEnabled;



        dailyDrivingGoal =

            _defaultDailyDrivingGoal;



        drivingTimeSeconds =

            _defaultDrivingTimeSeconds;



        monitoringSessions =

            _defaultMonitoringSessions;



        safeDrivingStreak =

            _defaultSafeDrivingStreak;

      });



      _showMessage(

        'All settings restored to defaults.',

      );

    } catch (e) {

      _showMessage(

        'Unable to reset settings.',

      );

    }

  }



  // ============================================================

  // MESSAGE

  // ============================================================



  void _showMessage(String message) {

    if (!mounted) return;



    ScaffoldMessenger.of(context).hideCurrentSnackBar();



    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(message),

        behavior: SnackBarBehavior.floating,

        duration: const Duration(seconds: 2),

      ),

    );

  }



  // ============================================================

  // SENSITIVITY TEXT

  // ============================================================



  String get sensitivityText {

    if (alertSensitivity >= 0.85) {

      return 'High';

    }



    if (alertSensitivity >= 0.55) {

      return 'Medium';

    }



    return 'Low';

  }



  // ============================================================

  // FORMAT DRIVING TIME

  // ============================================================



  String get formattedDrivingTime {

    final hours = drivingTimeSeconds ~/ 3600;



    final minutes =

        (drivingTimeSeconds % 3600) ~/ 60;



    if (hours > 0) {

      return '${hours}h ${minutes}m';

    }



    return '${minutes}m';

  }



  // ============================================================

  // WELLBEING PROGRESS

  // ============================================================



  double get wellbeingProgress {

    final goalSeconds =

        dailyDrivingGoal * 3600;



    if (goalSeconds <= 0) {

      return 0;

    }



    return (drivingTimeSeconds / goalSeconds)

        .clamp(0.0, 1.0)

        .toDouble();

  }



  // ============================================================

  // BUILD

  // ============================================================



  @override

  Widget build(BuildContext context) {

    if (_isLoadingSettings) {

      return Scaffold(

        backgroundColor: AppColors.background,

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

            'Settings',

            style: TextStyle(

              color: Colors.white,

              fontSize: 22,

              fontWeight: FontWeight.w600,

            ),

          ),

        ),

        body: const Center(

          child: CircularProgressIndicator(

            color: AppColors.primary,

          ),

        ),

      );

    }



    return Scaffold(

      backgroundColor: AppColors.background,



      // ========================================================

      // APP BAR

      // ========================================================



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

          'Settings',

          style: TextStyle(

            color: Colors.white,

            fontSize: 22,

            fontWeight: FontWeight.w600,

          ),

        ),

      ),



      // ========================================================

      // BODY

      // ========================================================



      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final horizontalPadding = screenWidth < 360
                ? 12.0
                : screenWidth < 600
                    ? 16.0
                    : screenWidth < 1000
                        ? 24.0
                        : 32.0;

            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: AppSpacing.md,
                  ),
                  child: Column(

            crossAxisAlignment:

                CrossAxisAlignment.start,

            children: [



              // ==================================================

              // INTRO

              // ==================================================



              const Text(

                'App Settings',

                style: TextStyle(

                  color: Colors.white,

                  fontSize: 24,

                  fontWeight: FontWeight.w600,

                ),

              ),



              const SizedBox(height: 6),



              const Text(

                'Configure your Driver Safety AI preferences.',

                style: TextStyle(

                  color: Colors.white60,

                  fontSize: 14,

                ),

              ),



              const SizedBox(

                height: AppSpacing.lg,

              ),



              // ==================================================

              // AI MONITORING

              // ==================================================



              const _SectionTitle(

                icon: Icons.psychology_outlined,

                title: 'AI Monitoring',

              ),



              const SizedBox(

                height: AppSpacing.md,

              ),



              _SettingsCard(

                children: [



                  _SwitchTile(

                    icon: Icons.play_circle_outline,

                    iconColor: AppColors.primary,

                    title: 'Auto Start Monitoring',

                    subtitle:

                        'Automatically start AI monitoring when available.',

                    value: autoStartMonitoring,

                    onChanged: (value) {

                      setState(() {

                        autoStartMonitoring = value;

                      });



                      _saveSettings();



                      _showMessage(

                        value

                            ? 'Auto Start Monitoring enabled.'

                            : 'Auto Start Monitoring disabled.',

                      );

                    },

                  ),



                  const _SettingsDivider(),



                  _SensitivityTile(

                    value: alertSensitivity,

                    sensitivityText: sensitivityText,

                    onChanged: (value) {

                      setState(() {

                        alertSensitivity = value;

                      });



                      _saveSettings();

                    },

                  ),

                ],

              ),



              const SizedBox(

                height: AppSpacing.lg,

              ),



              // ==================================================

              // NOTIFICATIONS

              // ==================================================



              const _SectionTitle(

                icon: Icons.notifications_none,

                title: 'Notifications',

              ),



              const SizedBox(

                height: AppSpacing.md,

              ),



              _SettingsCard(

                children: [



                  _SwitchTile(

                    icon:

                        Icons.notifications_active_outlined,

                    iconColor: AppColors.primary,

                    title: 'Safety Notifications',

                    subtitle:

                        'Receive notifications about driver safety events.',

                    value: notificationsEnabled,

                    onChanged: (value) {

                      setState(() {

                        notificationsEnabled = value;

                      });



                      _saveSettings();



                      _showMessage(

                        value

                            ? 'Safety notifications enabled.'

                            : 'Safety notifications disabled.',

                      );

                    },

                  ),



                  const _SettingsDivider(),



                  _SwitchTile(

                    icon: Icons.volume_up_outlined,

                    iconColor: AppColors.warning,

                    title: 'Alert Sound',

                    subtitle:

                        'Play a sound when a safety alert is detected.',

                    value: soundEnabled,

                    onChanged: notificationsEnabled

                        ? (value) {

                            setState(() {

                              soundEnabled = value;

                            });



                            _saveSettings();



                            _showMessage(

                              value

                                  ? 'Alert sound enabled.'

                                  : 'Alert sound disabled.',

                            );

                          }

                        : null,

                  ),



                  const _SettingsDivider(),



                  _SwitchTile(

                    icon: Icons.vibration,

                    iconColor: AppColors.success,

                    title: 'Vibration',

                    subtitle:

                        'Use vibration for important safety alerts.',

                    value: vibrationEnabled,

                    onChanged: notificationsEnabled

                        ? (value) {

                            setState(() {

                              vibrationEnabled = value;

                            });



                            _saveSettings();



                            _showMessage(

                              value

                                  ? 'Vibration enabled.'

                                  : 'Vibration disabled.',

                            );

                          }

                        : null,

                  ),

                ],

              ),



              const SizedBox(

                height: AppSpacing.lg,

              ),



              // ==================================================

              // SAFETY ALERTS

              // ==================================================



              const _SectionTitle(

                icon: Icons.shield_outlined,

                title: 'Safety Alerts',

              ),



              const SizedBox(

                height: AppSpacing.md,

              ),



              _SettingsCard(

                children: [



                  _SwitchTile(

                    icon:

                        Icons.remove_red_eye_outlined,

                    iconColor: AppColors.primary,

                    title: 'Eye Closure Detection',

                    subtitle:

                        'Detect prolonged eye closure and signs of fatigue.',

                    value: eyeClosureEnabled,

                    onChanged: (value) {

                      setState(() {

                        eyeClosureEnabled = value;

                      });



                      _saveSettings();



                      _showMessage(

                        value

                            ? 'Eye Closure Detection enabled.'

                            : 'Eye Closure Detection disabled.',

                      );

                    },

                  ),



                  const _SettingsDivider(),



                  _SwitchTile(

                    icon:

                        Icons.sentiment_dissatisfied_outlined,

                    iconColor: AppColors.warning,

                    title: 'Yawning Detection',

                    subtitle:

                        'Detect repeated yawning during monitoring.',

                    value: yawningEnabled,

                    onChanged: (value) {

                      setState(() {

                        yawningEnabled = value;

                      });



                      _saveSettings();



                      _showMessage(

                        value

                            ? 'Yawning Detection enabled.'

                            : 'Yawning Detection disabled.',

                      );

                    },

                  ),



                  const _SettingsDivider(),



                  _SwitchTile(

                    icon:

                        Icons.face_retouching_natural,

                    iconColor: AppColors.success,

                    title: 'Head Position Detection',

                    subtitle:

                        'Monitor driver head position and direction.',

                    value: headPositionEnabled,

                    onChanged: (value) {

                      setState(() {

                        headPositionEnabled = value;

                      });



                      _saveSettings();



                      _showMessage(

                        value

                            ? 'Head Position Detection enabled.'

                            : 'Head Position Detection disabled.',

                      );

                    },

                  ),



                  const _SettingsDivider(),



                  _SwitchTile(

                    icon:

                        Icons.warning_amber_outlined,

                    iconColor: AppColors.danger,

                    title: 'Critical Alerts',

                    subtitle:

                        'Enable alerts for high-risk driver safety events.',

                    value: criticalAlertsEnabled,

                    onChanged: (value) {

                      setState(() {

                        criticalAlertsEnabled = value;

                      });



                      _saveSettings();



                      _showMessage(

                        value

                            ? 'Critical Alerts enabled.'

                            : 'Critical Alerts disabled.',

                      );

                    },

                  ),

                ],

              ),



              const SizedBox(

                height: AppSpacing.lg,

              ),



              // ==================================================

              // DIGITAL WELLBEING

              // ==================================================



              const _SectionTitle(

                icon: Icons.self_improvement_outlined,

                title: 'Digital Wellbeing',

              ),



              const SizedBox(

                height: AppSpacing.md,

              ),



              _SettingsCard(

                children: [



                  _InfoTile(

                    icon: Icons.directions_car_outlined,

                    iconColor: AppColors.primary,

                    title: 'Driving Time',

                    subtitle:

                        "Today's monitored driving time.",

                    value: formattedDrivingTime,

                    valueColor: AppColors.primary,

                  ),



                  const _SettingsDivider(),



                  _InfoTile(

                    icon: Icons.analytics_outlined,

                    iconColor: Colors.blue,

                    title: 'Monitoring Sessions',

                    subtitle:

                        'Monitoring sessions recorded today.',

                    value:

                        monitoringSessions.toString(),

                    valueColor: Colors.blue,

                  ),



                  const _SettingsDivider(),



                  _InfoTile(

                    icon: Icons.local_fire_department_outlined,

                    iconColor: AppColors.warning,

                    title: 'Safe Driving Streak',

                    subtitle:

                        'Consecutive safe driving days.',

                    value:

                        '$safeDrivingStreak days',

                    valueColor: AppColors.warning,

                  ),



                  const _SettingsDivider(),



                  _SwitchTile(

                    icon:

                        Icons.notifications_active_outlined,

                    iconColor: AppColors.warning,

                    title: 'Break Reminder',

                    subtitle:

                        'Remind you to take a break after prolonged driving.',

                    value: breakReminderEnabled,

                    onChanged: (value) {

                      setState(() {

                        breakReminderEnabled = value;

                      });



                      _saveSettings();



                      _showMessage(

                        value

                            ? 'Break Reminder enabled.'

                            : 'Break Reminder disabled.',

                      );

                    },

                  ),



                  const _SettingsDivider(),



                  _GoalTile(

                    value: dailyDrivingGoal,

                    progress: wellbeingProgress,

                    onChanged: (value) {

                      setState(() {

                        dailyDrivingGoal = value;

                      });



                      _saveSettings();

                    },

                  ),



                  const _SettingsDivider(),



                  _ActionTile(

                    icon: Icons.insights_outlined,

                    iconColor: Colors.cyan,

                    title: 'Wellbeing Summary',

                    subtitle:

                        "View today's driving and monitoring summary.",

                    onTap: () {

                      _showWellbeingSummary();

                    },

                  ),

                ],

              ),



              const SizedBox(

                height: AppSpacing.lg,

              ),



              // ==================================================

              // PRIVACY

              // ==================================================



              const _SectionTitle(

                icon: Icons.lock_outline,

                title: 'Privacy',

              ),



              const SizedBox(

                height: AppSpacing.md,

              ),



              _SettingsCard(

                children: [



                  _ActionTile(

                    icon: Icons.camera_alt_outlined,

                    iconColor: AppColors.primary,

                    title: 'Camera Access',

                    subtitle:

                        'Camera is required for real-time driver monitoring.',

                    onTap: () {

                      _showCameraAccessDialog();

                    },

                  ),



                  const _SettingsDivider(),



                  _ActionTile(

                    icon: Icons.storage_outlined,

                    iconColor: AppColors.success,

                    title: 'Session Data',

                    subtitle:

                        'Learn how monitoring session data is handled.',

                    onTap: () {

                      _showSessionDataDialog();

                    },

                  ),

                ],

              ),



              const SizedBox(

                height: AppSpacing.lg,

              ),



              // ==================================================

              // ACCOUNT

              // ==================================================



              const _SectionTitle(

                icon: Icons.person_outline,

                title: 'Account',

              ),



              const SizedBox(

                height: AppSpacing.md,

              ),



              _SettingsCard(

                children: [



                  _ActionTile(

                    icon: Icons.logout_rounded,

                    iconColor: AppColors.danger,

                    title: 'Logout',

                    subtitle:

                        'Sign out of your Driver Safety AI account.',

                    onTap: () {

                      _showLogoutDialog();

                    },

                  ),

                ],

              ),



              const SizedBox(

                height: AppSpacing.lg,

              ),



              // ==================================================

              // ABOUT

              // ==================================================



              const _SectionTitle(

                icon: Icons.info_outline,

                title: 'About',

              ),



              const SizedBox(

                height: AppSpacing.md,

              ),



              _SettingsCard(

                children: [



                  _InfoTile(

                    icon: Icons.security_outlined,

                    iconColor: AppColors.primary,

                    title: 'Driver Safety AI',

                    subtitle:

                        'AI-powered driver monitoring and safety platform.',

                    value: 'v1.0',

                    valueColor: Colors.white70,

                  ),



                  const _SettingsDivider(),



                  _ActionTile(

                    icon: Icons.description_outlined,

                    iconColor: Colors.blue,

                    title: 'Safety Information',

                    subtitle:

                        'Learn how the AI monitoring system works.',

                    onTap: () {

                      _showInformationDialog();

                    },

                  ),



                  const _SettingsDivider(),



                  _ActionTile(

                    icon: Icons.restart_alt,

                    iconColor: AppColors.warning,

                    title: 'Reset Settings',

                    subtitle:

                        'Restore all settings to their default values.',

                    onTap: () {

                      _showResetDialog();

                    },

                  ),

                ],

              ),



              const SizedBox(

                height: AppSpacing.xl,

              ),

            ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================

  // SAFETY INFORMATION

  // ============================================================



  void _showInformationDialog() {

    showDialog(

      context: context,

      builder: (context) {

        return AlertDialog(

          backgroundColor: AppColors.card,



          title: const Text(

            'Driver Safety AI',

            style: TextStyle(

              color: Colors.white,

              fontWeight: FontWeight.bold,

            ),

          ),



          content: const SingleChildScrollView(

            child: Text(

              'Driver Safety AI uses camera-based AI monitoring '

              'to analyze driver awareness and safety conditions.\n\n'

              'The system can monitor:\n\n'

              '• Eye closure and prolonged eye closure\n'

              '• Blinking and signs of fatigue\n'

              '• Repeated yawning\n'

              '• Driver head position and direction\n'

              '• Driver presence in the camera view\n'

              '• Safety alerts based on detected conditions\n\n'

              'The system is designed as a driver safety and '

              'fatigue monitoring tool and should not be considered '

              'a medical diagnostic system.',

              style: TextStyle(

                color: Colors.white70,

                height: 1.5,

              ),

            ),

          ),



          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(context);

              },

              child: const Text(

                'Close',

                style: TextStyle(

                  color: AppColors.primary,

                ),

              ),

            ),

          ],

        );

      },

    );

  }



  // ============================================================

  // CAMERA ACCESS

  // ============================================================



  void _showCameraAccessDialog() {

    showDialog(

      context: context,

      builder: (context) {

        return AlertDialog(

          backgroundColor: AppColors.card,



          title: const Row(

            children: [

              Icon(

                Icons.camera_alt_outlined,

                color: AppColors.primary,

              ),



              SizedBox(width: 10),



              Text(

                'Camera Access',

                style: TextStyle(

                  color: Colors.white,

                  fontWeight: FontWeight.bold,

                ),

              ),

            ],

          ),



          content: const Text(

            'Camera access is required for real-time '

            'driver monitoring.\n\n'

            'The camera is used to analyze driver facial '

            'features such as eye closure, yawning and '

            'head position.',

            style: TextStyle(

              color: Colors.white70,

              height: 1.5,

            ),

          ),



          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(context);

              },

              child: const Text(

                'OK',

                style: TextStyle(

                  color: AppColors.primary,

                ),

              ),

            ),

          ],

        );

      },

    );

  }



  // ============================================================

  // SESSION DATA

  // ============================================================



  void _showSessionDataDialog() {

    showDialog(

      context: context,

      builder: (context) {

        return AlertDialog(

          backgroundColor: AppColors.card,



          title: const Row(

            children: [

              Icon(

                Icons.storage_outlined,

                color: AppColors.success,

              ),



              SizedBox(width: 10),



              Text(

                'Session Data',

                style: TextStyle(

                  color: Colors.white,

                  fontWeight: FontWeight.bold,

                ),

              ),

            ],

          ),



          content: const Text(

            'Monitoring session information is stored '

            'locally for application reports and history.\n\n'

            'The stored wellbeing information includes '

            'driving time, monitoring sessions and safe '

            'driving streak information.',

            style: TextStyle(

              color: Colors.white70,

              height: 1.5,

            ),

          ),



          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(context);

              },

              child: const Text(

                'OK',

                style: TextStyle(

                  color: AppColors.primary,

                ),

              ),

            ),

          ],

        );

      },

    );

  }



  // ============================================================

  // WELLBEING SUMMARY

  // ============================================================



  void _showWellbeingSummary() {

    final percentage =

        (wellbeingProgress * 100).round();



    showDialog(

      context: context,

      builder: (context) {

        return AlertDialog(

          backgroundColor: AppColors.card,



          title: const Row(

            children: [

              Icon(

                Icons.insights_outlined,

                color: Colors.cyan,

              ),



              SizedBox(width: 10),



              Text(

                'Wellbeing Summary',

                style: TextStyle(

                  color: Colors.white,

                  fontWeight: FontWeight.bold,

                ),

              ),

            ],

          ),



          content: SingleChildScrollView(

            child: Column(

              crossAxisAlignment:

                  CrossAxisAlignment.start,

              children: [



                _SummaryRow(

                  label: 'Driving Time',

                  value: formattedDrivingTime,

                ),



                _SummaryRow(

                  label: 'Monitoring Sessions',

                  value:

                      monitoringSessions.toString(),

                ),



                _SummaryRow(

                  label: 'Safe Driving Streak',

                  value:

                      '$safeDrivingStreak days',

                ),



                _SummaryRow(

                  label: 'Daily Goal',

                  value:

                      '${dailyDrivingGoal.toStringAsFixed(0)}h',

                ),



                const SizedBox(height: 14),



                const Text(

                  'Daily Goal Progress',

                  style: TextStyle(

                    color: Colors.white,

                    fontWeight: FontWeight.w600,

                  ),

                ),



                const SizedBox(height: 8),



                LinearProgressIndicator(

                  value: wellbeingProgress,

                  minHeight: 8,

                  borderRadius:

                      BorderRadius.circular(10),

                  backgroundColor: Colors.white12,

                  valueColor:

                      const AlwaysStoppedAnimation<Color>(

                    AppColors.primary,

                  ),

                ),



                const SizedBox(height: 8),



                Text(

                  '$percentage% of daily driving goal',

                  style: const TextStyle(

                    color: Colors.white60,

                    fontSize: 12,

                  ),

                ),

              ],

            ),

          ),



          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(context);

              },

              child: const Text(

                'Close',

                style: TextStyle(

                  color: AppColors.primary,

                ),

              ),

            ),

          ],

        );

      },

    );

  }



  // ============================================================

  // RESET DIALOG

  // ============================================================



  void _showResetDialog() {

    showDialog(

      context: context,

      builder: (context) {

        return AlertDialog(

          backgroundColor: AppColors.card,



          title: const Text(

            'Reset Settings?',

            style: TextStyle(

              color: Colors.white,

              fontWeight: FontWeight.bold,

            ),

          ),



          content: const Text(

            'This will restore all application settings '

            'and digital wellbeing values to their defaults.',

            style: TextStyle(

              color: Colors.white70,

              height: 1.5,

            ),

          ),



          actions: [



            TextButton(

              onPressed: () {

                Navigator.pop(context);

              },

              child: const Text(

                'Cancel',

                style: TextStyle(

                  color: Colors.white70,

                ),

              ),

            ),



            TextButton(

              onPressed: () async {

                Navigator.pop(context);



                await _resetSettings();

              },

              child: const Text(

                'Reset',

                style: TextStyle(

                  color: AppColors.danger,

                ),

              ),

            ),

          ],

        );

      },

    );

  }



  // ============================================================

  // LOGOUT DIALOG

  // ============================================================



  void _showLogoutDialog() {

    showDialog(

      context: context,

      builder: (dialogContext) {

        return AlertDialog(

          backgroundColor: AppColors.card,



          title: const Row(

            children: [



              Icon(

                Icons.logout_rounded,

                color: AppColors.danger,

                size: 24,

              ),



              SizedBox(width: 10),



              Text(

                'Logout?',

                style: TextStyle(

                  color: Colors.white,

                  fontWeight: FontWeight.bold,

                ),

              ),

            ],

          ),



          content: const Text(

            'Are you sure you want to logout from '

            'your Driver Safety AI account?',

            style: TextStyle(

              color: Colors.white70,

              height: 1.5,

            ),

          ),



          actions: [



            TextButton(

              onPressed: () {

                Navigator.pop(dialogContext);

              },

              child: const Text(

                'Cancel',

                style: TextStyle(

                  color: Colors.white70,

                ),

              ),

            ),



            TextButton(

              onPressed: () {

                Navigator.pop(dialogContext);



                Navigator.pushAndRemoveUntil(

                  context,

                  MaterialPageRoute(

                    builder: (_) =>

                        const LoginScreen(),

                  ),

                  (route) => false,

                );

              },

              child: const Text(

                'Logout',

                style: TextStyle(

                  color: AppColors.danger,

                  fontWeight: FontWeight.w600,

                ),

              ),

            ),

          ],

        );

      },

    );

  }

}



// ============================================================================

// SECTION TITLE

// ============================================================================



class _SectionTitle extends StatelessWidget {

  final IconData icon;

  final String title;



  const _SectionTitle({

    required this.icon,

    required this.title,

  });



  @override

  Widget build(BuildContext context) {

    return Row(

      children: [



        Icon(

          icon,

          color: AppColors.primary,

          size: 22,

        ),



        const SizedBox(width: 10),



        Text(

          title,

          style: const TextStyle(

            color: Colors.white,

            fontSize: 19,

            fontWeight: FontWeight.w600,

          ),

        ),

      ],

    );

  }

}



// ============================================================================

// SETTINGS CARD

// ============================================================================



class _SettingsCard extends StatelessWidget {

  final List<Widget> children;



  const _SettingsCard({

    required this.children,

  });



  @override

  Widget build(BuildContext context) {

    return Container(

      width: double.infinity,



      decoration: BoxDecoration(

        color: AppColors.card,



        borderRadius:

            BorderRadius.circular(18),



        border: Border.all(

          color: Colors.white.withOpacity(0.06),

        ),



        boxShadow: [

          BoxShadow(

            color: Colors.black.withOpacity(0.12),

            blurRadius: 12,

            offset: const Offset(0, 5),

          ),

        ],

      ),



      child: Padding(

        padding: const EdgeInsets.symmetric(

          horizontal: 18,

          vertical: 6,

        ),



        child: Column(

          children: children,

        ),

      ),

    );

  }

}



// ============================================================================

// SWITCH TILE

// ============================================================================



class _SwitchTile extends StatelessWidget {

  final IconData icon;

  final Color iconColor;

  final String title;

  final String subtitle;

  final bool value;

  final ValueChanged<bool>? onChanged;



  const _SwitchTile({

    required this.icon,

    required this.iconColor,

    required this.title,

    required this.subtitle,

    required this.value,

    required this.onChanged,

  });



  @override

  Widget build(BuildContext context) {

    final disabled = onChanged == null;



    return Padding(

      padding: const EdgeInsets.symmetric(

        vertical: 14,

      ),



      child: Row(

        children: [



          Container(

            width: 44,

            height: 44,



            decoration: BoxDecoration(

              color: iconColor.withOpacity(

                disabled ? 0.05 : 0.12,

              ),



              borderRadius:

                  BorderRadius.circular(12),

            ),



            child: Icon(

              icon,

              color: disabled

                  ? Colors.white30

                  : iconColor,

              size: 22,

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

                    color: disabled

                        ? Colors.white38

                        : Colors.white,

                    fontSize: 14,

                    fontWeight: FontWeight.w500,

                  ),

                ),



                const SizedBox(height: 4),



                Text(

                  subtitle,

                  style: TextStyle(

                    color: disabled

                        ? Colors.white24

                        : Colors.white54,

                    fontSize: 12,

                    height: 1.35,

                  ),

                ),

              ],

            ),

          ),



          const SizedBox(width: 10),



          Switch(

            value: value,

            onChanged: onChanged,

            activeThumbColor:

                AppColors.primary,

          ),

        ],

      ),

    );

  }

}



// ============================================================================

// SENSITIVITY TILE

// ============================================================================



class _SensitivityTile extends StatelessWidget {

  final double value;

  final String sensitivityText;

  final ValueChanged<double> onChanged;



  const _SensitivityTile({

    required this.value,

    required this.sensitivityText,

    required this.onChanged,

  });



  @override

  Widget build(BuildContext context) {

    return Padding(

      padding: const EdgeInsets.symmetric(

        vertical: 16,

      ),



      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,



        children: [



          Row(

            children: [



              Container(

                width: 44,

                height: 44,



                decoration: BoxDecoration(

                  color: AppColors.warning

                      .withOpacity(.12),



                  borderRadius:

                      BorderRadius.circular(12),

                ),



                child: const Icon(

                  Icons.tune,

                  color: AppColors.warning,

                  size: 22,

                ),

              ),



              const SizedBox(width: 14),



              const Expanded(

                child: Column(

                  crossAxisAlignment:

                      CrossAxisAlignment.start,



                  children: [



                    Text(

                      'Alert Sensitivity',

                      style: TextStyle(

                        color: Colors.white,

                        fontSize: 14,

                        fontWeight: FontWeight.w500,

                      ),

                    ),



                    SizedBox(height: 4),



                    Text(

                      'Adjust how sensitive safety alerts should be.',

                      style: TextStyle(

                        color: Colors.white54,

                        fontSize: 12,

                      ),

                    ),

                  ],

                ),

              ),



              Text(

                sensitivityText,

                style: const TextStyle(

                  color: AppColors.warning,

                  fontWeight: FontWeight.bold,

                ),

              ),

            ],

          ),



          const SizedBox(height: 8),



          Slider(

            value: value,

            min: 0,

            max: 1,

            divisions: 2,

            onChanged: onChanged,

            activeColor: AppColors.primary,

            inactiveColor: Colors.white12,

          ),



          const Row(

            mainAxisAlignment:

                MainAxisAlignment.spaceBetween,



            children: [



              Text(

                'Low',

                style: TextStyle(

                  color: Colors.white38,

                  fontSize: 11,

                ),

              ),



              Text(

                'Medium',

                style: TextStyle(

                  color: Colors.white38,

                  fontSize: 11,

                ),

              ),



              Text(

                'High',

                style: TextStyle(

                  color: Colors.white38,

                  fontSize: 11,

                ),

              ),

            ],

          ),

        ],

      ),

    );

  }

}



// ============================================================================

// DAILY DRIVING GOAL

// ============================================================================



class _GoalTile extends StatelessWidget {

  final double value;

  final double progress;

  final ValueChanged<double> onChanged;



  const _GoalTile({

    required this.value,

    required this.progress,

    required this.onChanged,

  });



  @override

  Widget build(BuildContext context) {

    return Padding(

      padding: const EdgeInsets.symmetric(

        vertical: 16,

      ),



      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,



        children: [



          Row(

            children: [



              Container(

                width: 44,

                height: 44,



                decoration: BoxDecoration(

                  color:

                      AppColors.success.withOpacity(.12),



                  borderRadius:

                      BorderRadius.circular(12),

                ),



                child: const Icon(

                  Icons.flag_outlined,

                  color: AppColors.success,

                  size: 22,

                ),

              ),



              const SizedBox(width: 14),



              const Expanded(

                child: Column(

                  crossAxisAlignment:

                      CrossAxisAlignment.start,



                  children: [



                    Text(

                      'Daily Driving Goal',

                      style: TextStyle(

                        color: Colors.white,

                        fontSize: 14,

                        fontWeight: FontWeight.w500,

                      ),

                    ),



                    SizedBox(height: 4),



                    Text(

                      'Set your daily recommended driving duration.',

                      style: TextStyle(

                        color: Colors.white54,

                        fontSize: 12,

                      ),

                    ),

                  ],

                ),

              ),



              Text(

                '${value.toStringAsFixed(0)}h',

                style: const TextStyle(

                  color: AppColors.success,

                  fontWeight: FontWeight.bold,

                ),

              ),

            ],

          ),



          const SizedBox(height: 8),



          Slider(

            value: value,

            min: 1,

            max: 12,

            divisions: 11,

            onChanged: onChanged,

            activeColor: AppColors.primary,

            inactiveColor: Colors.white12,

          ),



          const Row(

            mainAxisAlignment:

                MainAxisAlignment.spaceBetween,



            children: [



              Text(

                '1h',

                style: TextStyle(

                  color: Colors.white38,

                  fontSize: 11,

                ),

              ),



              Text(

                '6h',

                style: TextStyle(

                  color: Colors.white38,

                  fontSize: 11,

                ),

              ),



              Text(

                '12h',

                style: TextStyle(

                  color: Colors.white38,

                  fontSize: 11,

                ),

              ),

            ],

          ),



          const SizedBox(height: 10),



          LinearProgressIndicator(

            value: progress,

            minHeight: 5,

            borderRadius:

                BorderRadius.circular(10),

            backgroundColor: Colors.white10,

            valueColor:

                const AlwaysStoppedAnimation<Color>(

              AppColors.primary,

            ),

          ),

        ],

      ),

    );

  }

}



// ============================================================================

// INFO TILE

// ============================================================================



class _InfoTile extends StatelessWidget {

  final IconData icon;

  final Color iconColor;

  final String title;

  final String subtitle;

  final String value;

  final Color valueColor;



  const _InfoTile({

    required this.icon,

    required this.iconColor,

    required this.title,

    required this.subtitle,

    required this.value,

    required this.valueColor,

  });



  @override

  Widget build(BuildContext context) {

    return Padding(

      padding: const EdgeInsets.symmetric(

        vertical: 14,

      ),



      child: Row(

        children: [



          Container(

            width: 44,

            height: 44,



            decoration: BoxDecoration(

              color:

                  iconColor.withOpacity(.12),



              borderRadius:

                  BorderRadius.circular(12),

            ),



            child: Icon(

              icon,

              color: iconColor,

              size: 22,

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

                  style: const TextStyle(

                    color: Colors.white,

                    fontSize: 14,

                    fontWeight: FontWeight.w500,

                  ),

                ),



                const SizedBox(height: 4),



                Text(

                  subtitle,

                  style: const TextStyle(

                    color: Colors.white54,

                    fontSize: 12,

                    height: 1.35,

                  ),

                ),

              ],

            ),

          ),



          const SizedBox(width: 10),



          Text(

            value,

            style: TextStyle(

              color: valueColor,

              fontSize: 12,

              fontWeight: FontWeight.w600,

            ),

          ),

        ],

      ),

    );

  }

}



// ============================================================================

// SUMMARY ROW

// ============================================================================



class _SummaryRow extends StatelessWidget {

  final String label;

  final String value;



  const _SummaryRow({

    required this.label,

    required this.value,

  });



  @override

  Widget build(BuildContext context) {

    return Padding(

      padding: const EdgeInsets.symmetric(

        vertical: 7,

      ),



      child: Row(

        mainAxisAlignment:

            MainAxisAlignment.spaceBetween,



        children: [



          Text(

            label,

            style: const TextStyle(

              color: Colors.white60,

              fontSize: 13,

            ),

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

    );

  }

}



// ============================================================================

// ACTION TILE

// ============================================================================



class _ActionTile extends StatelessWidget {

  final IconData icon;

  final Color iconColor;

  final String title;

  final String subtitle;

  final VoidCallback onTap;



  const _ActionTile({

    required this.icon,

    required this.iconColor,

    required this.title,

    required this.subtitle,

    required this.onTap,

  });



  @override

  Widget build(BuildContext context) {

    return InkWell(

      onTap: onTap,



      borderRadius:

          BorderRadius.circular(12),



      child: Padding(

        padding: const EdgeInsets.symmetric(

          vertical: 14,

        ),



        child: Row(

          children: [



            Container(

              width: 44,

              height: 44,



              decoration: BoxDecoration(

                color:

                    iconColor.withOpacity(.12),



                borderRadius:

                    BorderRadius.circular(12),

              ),



              child: Icon(

                icon,

                color: iconColor,

                size: 22,

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

                    style: const TextStyle(

                      color: Colors.white,

                      fontSize: 14,

                      fontWeight: FontWeight.w500,

                    ),

                  ),



                  const SizedBox(height: 4),



                  Text(

                    subtitle,

                    style: const TextStyle(

                      color: Colors.white54,

                      fontSize: 12,

                      height: 1.35,

                    ),

                  ),

                ],

              ),

            ),



            const Icon(

              Icons.arrow_forward_ios,

              color: Colors.white38,

              size: 16,

            ),

          ],

        ),

      ),

    );

  }

}



// ============================================================================

// DIVIDER

// ============================================================================



class _SettingsDivider extends StatelessWidget {

  const _SettingsDivider();



  @override

  Widget build(BuildContext context) {

    return const Divider(

      color: Colors.white10,

      height: 1,

    );

  }

}