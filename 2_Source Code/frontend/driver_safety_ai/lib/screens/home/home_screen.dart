import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../monitoring/monitoring_screen.dart';
import '../analytics/reports_screen.dart';
import '../history/history_screen.dart';
import '../maps/maps_screen.dart';
import '../settings/settings_screen.dart';
import '../emergency/emergency_screen.dart';
import '../admin/admin_users_screen.dart';
import '../auth/login/login_screen.dart';

import '../../services/monitoring_session_service.dart';
import '../../services/api_service.dart';

import '../../widgets/app_logo.dart';
import '../../widgets/cards/dashboard_card.dart';
import '../../widgets/cards/status_card.dart';
import '../../widgets/buttons/gradient_button.dart';

class HomeScreen extends StatefulWidget {
  final String accountId;
  final String role;
  final String adminStatus;

  // Driver details come from the account/login data.
  final String driverName;
  final String email;
  final String vehicleInfo;
  final String licenseNumber;

  const HomeScreen({
    super.key,
    this.accountId = '',
    this.role = 'user',
    this.adminStatus = 'approved',
    this.driverName = '',
    this.email = '',
    this.vehicleInfo = '',
    this.licenseNumber = '',
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ============================================================
  // SERVICES
  // ============================================================

  final MonitoringSessionService _sessionService =
      MonitoringSessionService.instance;

  // ============================================================
  // PROFILE DATA
  // ============================================================

  String _profileDriverName = '';
  String _profileEmail = '';
  String _profileLicense = '';

  String _emergencyContactName = '';
  String _emergencyContactPhone = '';
  String _emergencyContactEmail = '';
  String _emergencyContactRelationship = '';

  bool _isLoadingProfile = false;

  // ============================================================
  // GREETING TIMER
  // ============================================================

  Timer? _greetingTimer;

  @override
  void initState() {
    super.initState();

    _loadProfileDetails();

    // Refresh greeting every minute.
    _greetingTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (mounted) {
          setState(() {});
        }
      },
    );
  }

  // ============================================================
  // LOAD PROFILE DETAILS FROM BACKEND
  // ============================================================

  Future<void> _loadProfileDetails() async {
    final accountId = widget.accountId.trim();
    if (accountId.isEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingProfile = true;
      });
    }

    try {
      debugPrint('Loading profile for account: $accountId');

      final response = await http.get(
        Uri.parse(
          'http://192.168.31.55:8000/profile/details'
          '?account_id=${Uri.encodeQueryComponent(accountId)}',
        ),
      );

      final dynamic decoded = jsonDecode(response.body);
      final Map<String, dynamic> result = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{
              'success': response.statusCode >= 200 &&
                  response.statusCode < 300,
              'data': decoded,
            };

      if (!mounted) return;

      if (result['success'] == true && result['profile'] is Map) {
        final profile = Map<String, dynamic>.from(result['profile']);

        setState(() {
          _profileDriverName =
              profile['driver_name']?.toString() ??
              profile['full_name']?.toString() ??
              widget.driverName;
          _profileEmail =
              profile['email']?.toString() ?? widget.email;
          _profileLicense =
              profile['driving_license']?.toString() ??
              widget.licenseNumber;

          _emergencyContactName =
              profile['emergency_contact_name']?.toString() ?? '';
          _emergencyContactPhone =
              profile['emergency_contact_phone']?.toString() ?? '';
          _emergencyContactEmail =
              profile['emergency_contact_email']?.toString() ?? '';
          _emergencyContactRelationship =
              profile['emergency_contact_relationship']?.toString() ?? '';
          _isLoadingProfile = false;
        });

        debugPrint('Profile loaded successfully.');
        debugPrint('Profile name: $_profileDriverName');
        debugPrint('Profile email: $_profileEmail');
      } else {
        setState(() {
          _isLoadingProfile = false;
          _profileDriverName = widget.driverName;
          _profileEmail = widget.email;
          _profileLicense = widget.licenseNumber;
        });

        debugPrint(
          'Profile load failed: ${result['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingProfile = false;
        _profileDriverName = widget.driverName;
        _profileEmail = widget.email;
        _profileLicense = widget.licenseNumber;
      });

      debugPrint('PROFILE LOAD ERROR: $e');
    }
  }

  @override
  void dispose() {
    _greetingTimer?.cancel();
    super.dispose();
  }

  // ============================================================
  // DYNAMIC GREETING
  // ============================================================

  String _getGreeting() {
    final hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return "Good Morning 👋";
    } else if (hour >= 12 && hour < 17) {
      return "Good Afternoon ☀️";
    } else if (hour >= 17 && hour < 21) {
      return "Good Evening 🌆";
    } else {
      return "Good Night 🌙";
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final bool isAdmin = widget.role.toLowerCase().trim() == 'admin' &&
        widget.adminStatus.toLowerCase().trim() == 'approved';
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final String displayName = (_profileDriverName.trim().isNotEmpty
            ? _profileDriverName
            : widget.driverName)
        .trim();
    return Scaffold(
      backgroundColor: const Color(0xff020D1B),
      drawer: MediaQuery.sizeOf(context).width < 1024
          ? _buildAppDrawer(context, isAdmin)
          : null,
      bottomNavigationBar: MediaQuery.sizeOf(context).width < 1024
          ? _buildBottomNavigationBar(context)
          : null,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool isDesktop = constraints.maxWidth >= 1024;
          if (isDesktop) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildDesktopSidebar(context, isAdmin),
                const VerticalDivider(width: 1, thickness: 1, color: Color(0xff18334A)),
                Expanded(child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(screenWidth >= 700 ? 28 : 16, 12,
              screenWidth >= 700 ? 28 : 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: screenWidth >= 1200
                    ? 1120
                    : screenWidth >= 700
                        ? 900
                        : 460,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (screenWidth < 1024) ...[
                        Builder(
                          builder: (context) => _dashboardIconButton(
                            icon: Icons.menu_rounded,
                            tooltip: 'Open menu',
                            onTap: () => Scaffold.of(context).openDrawer(),
                          ),
                        ),
                        const SizedBox(width: 10),
                      ],
                      const AppLogo(size: 46),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Driver Safety AI', style: TextStyle(
                              color: Colors.white, fontSize: 17,
                              fontWeight: FontWeight.w800)),
                            SizedBox(height: 2),
                            Text('Drive Safe. Live Better.', style: TextStyle(
                              color: Color(0xff9CB4D0), fontSize: 11)),
                          ],
                        ),
                      ),
                      _dashboardIconButton(
                        icon: Icons.notifications_none_rounded,
                        tooltip: 'Notifications',
                        onTap: () => _showNotificationMessage(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(_getGreeting().replaceAll(RegExp(r'\s*[👋☀️🌆🌙]'), ''),
                    style: const TextStyle(color: Color(0xffD6E5F7), fontSize: 15)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Expanded(child: Text(
                      displayName.isEmpty ? 'Welcome back 👋' : '$displayName 👋',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 25,
                        height: 1.15, fontWeight: FontWeight.w800))),
                  ]),
                  const SizedBox(height: 5),
                  const Text('Stay alert. Let AI support your journey.',
                    style: TextStyle(color: Color(0xffB8C9DD), fontSize: 12.5)),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xff08294A), Color(0xff06192D), Color(0xff10243B)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xff00D7D0).withOpacity(.32)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xff00D7D0).withOpacity(.14),
                            borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.shield_outlined, color: Color(0xff00E0CF), size: 25)),
                        const SizedBox(width: 10),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xff00D7D0).withOpacity(.12),
                            borderRadius: BorderRadius.circular(20)),
                          child: const Text('DRIVE MODE', style: TextStyle(color: Color(0xff00E0CF),
                            fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: .6))),
                      ]),
                      const SizedBox(height: 12),
                      const Text('Monitoring Off', style: TextStyle(color: Colors.white,
                        fontSize: 23, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text('Start a monitoring session to check driver attention and detect unsafe behaviour.',
                        style: TextStyle(color: Color(0xffD0DCEB), fontSize: 12.5, height: 1.45)),
                      const SizedBox(height: 16),
                      SizedBox(width: double.infinity, child: FilledButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const MonitoringScreen(),
                          )).then((_) {
                            if (!mounted) return;
                            setState(() {});
                            Future.delayed(const Duration(milliseconds: 250), () {
                              if (mounted) _showRatingDialog(context);
                            });
                          });
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 24),
                        label: const Padding(padding: EdgeInsets.symmetric(vertical: 13),
                          child: Text('Start Monitoring', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff00D9C7),
                          foregroundColor: const Color(0xff001522),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(builder: (context, constraints) {
                    final double gap = 10;
                    final double cardWidth = constraints.maxWidth >= 900
                        ? (constraints.maxWidth - gap * 3) / 4
                        : (constraints.maxWidth - gap) / 2;
                    return Wrap(spacing: gap, runSpacing: gap, children: [
                      _dashboardMetric(width: cardWidth, icon: Icons.speed_rounded,
                        color: const Color(0xff00D8C7), title: 'GPS Speed', value: '-- km/h', note: 'GPS not active'),
                      _dashboardMetric(width: cardWidth, icon: Icons.route_rounded,
                        color: const Color(0xff5DAAFF), title: 'Trip Duration', value: '00:00:00', note: 'Not started'),
                      _dashboardMetric(width: cardWidth, icon: Icons.alt_route_rounded,
                        color: const Color(0xff00D8C7), title: 'Distance Travelled', value: '-- km', note: 'Not started'),
                      _dashboardMetric(width: cardWidth, icon: Icons.graphic_eq_rounded,
                        color: const Color(0xffD77BFF), title: 'Alerts Detected', value: '0', note: 'No alerts yet'),
                    ]);
                  }),
                  const SizedBox(height: 12),
                  Material(
                    color: const Color(0xffA8172D),
                    borderRadius: BorderRadius.circular(17),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(17),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => EmergencyScreen(accountId: widget.accountId))),
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        child: Row(children: [
                          Container(width: 44, height: 44,
                            decoration: BoxDecoration(color: Colors.white.withOpacity(.13), shape: BoxShape.circle),
                            child: const Icon(Icons.sos_rounded, color: Colors.white, size: 27)),
                          const SizedBox(width: 12),
                          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Emergency Help', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                            SizedBox(height: 3),
                            Text('Get immediate assistance', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                          ])),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
                        ])),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(children: [
                    const Expanded(child: Text('Recent Trip', style: TextStyle(color: Colors.white,
                      fontSize: 19, fontWeight: FontWeight.w800))),
                    TextButton(onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen())),
                      child: const Text('View All', style: TextStyle(color: Color(0xff00D9D0), fontWeight: FontWeight.w700))),
                  ]),
                  _buildRecentActivity(),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
      )),
              ],
            );
          }
          return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(screenWidth >= 700 ? 28 : 16, 12,
              screenWidth >= 700 ? 28 : 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: screenWidth >= 1200
                    ? 1120
                    : screenWidth >= 700
                        ? 900
                        : 460,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Builder(
                        builder: (context) => _dashboardIconButton(
                          icon: Icons.menu_rounded,
                          tooltip: 'Open menu',
                          onTap: () => Scaffold.of(context).openDrawer(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const AppLogo(size: 46),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Driver Safety AI', style: TextStyle(
                              color: Colors.white, fontSize: 17,
                              fontWeight: FontWeight.w800)),
                            SizedBox(height: 2),
                            Text('Drive Safe. Live Better.', style: TextStyle(
                              color: Color(0xff9CB4D0), fontSize: 11)),
                          ],
                        ),
                      ),
                      _dashboardIconButton(
                        icon: Icons.notifications_none_rounded,
                        tooltip: 'Notifications',
                        onTap: () => _showNotificationMessage(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(_getGreeting().replaceAll(RegExp(r'\s*[👋☀️🌆🌙]'), ''),
                    style: const TextStyle(color: Color(0xffD6E5F7), fontSize: 15)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Expanded(child: Text(
                      displayName.isEmpty ? 'Welcome back 👋' : '$displayName 👋',
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 25,
                        height: 1.15, fontWeight: FontWeight.w800))),
                  ]),
                  const SizedBox(height: 5),
                  const Text('Stay alert. Let AI support your journey.',
                    style: TextStyle(color: Color(0xffB8C9DD), fontSize: 12.5)),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xff08294A), Color(0xff06192D), Color(0xff10243B)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xff00D7D0).withOpacity(.32)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xff00D7D0).withOpacity(.14),
                            borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.shield_outlined, color: Color(0xff00E0CF), size: 25)),
                        const SizedBox(width: 10),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xff00D7D0).withOpacity(.12),
                            borderRadius: BorderRadius.circular(20)),
                          child: const Text('DRIVE MODE', style: TextStyle(color: Color(0xff00E0CF),
                            fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: .6))),
                      ]),
                      const SizedBox(height: 12),
                      const Text('Monitoring Off', style: TextStyle(color: Colors.white,
                        fontSize: 23, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      const Text('Start a monitoring session to check driver attention and detect unsafe behaviour.',
                        style: TextStyle(color: Color(0xffD0DCEB), fontSize: 12.5, height: 1.45)),
                      const SizedBox(height: 16),
                      SizedBox(width: double.infinity, child: FilledButton.icon(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const MonitoringScreen(),
                          )).then((_) {
                            if (!mounted) return;
                            setState(() {});
                            Future.delayed(const Duration(milliseconds: 250), () {
                              if (mounted) _showRatingDialog(context);
                            });
                          });
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 24),
                        label: const Padding(padding: EdgeInsets.symmetric(vertical: 13),
                          child: Text('Start Monitoring', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xff00D9C7),
                          foregroundColor: const Color(0xff001522),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                      )),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(builder: (context, constraints) {
                    final double gap = 10;
                    final double cardWidth = constraints.maxWidth >= 900
                        ? (constraints.maxWidth - gap * 3) / 4
                        : (constraints.maxWidth - gap) / 2;
                    return Wrap(spacing: gap, runSpacing: gap, children: [
                      _dashboardMetric(width: cardWidth, icon: Icons.speed_rounded,
                        color: const Color(0xff00D8C7), title: 'GPS Speed', value: '-- km/h', note: 'GPS not active'),
                      _dashboardMetric(width: cardWidth, icon: Icons.route_rounded,
                        color: const Color(0xff5DAAFF), title: 'Trip Duration', value: '00:00:00', note: 'Not started'),
                      _dashboardMetric(width: cardWidth, icon: Icons.alt_route_rounded,
                        color: const Color(0xff00D8C7), title: 'Distance Travelled', value: '-- km', note: 'Not started'),
                      _dashboardMetric(width: cardWidth, icon: Icons.graphic_eq_rounded,
                        color: const Color(0xffD77BFF), title: 'Alerts Detected', value: '0', note: 'No alerts yet'),
                    ]);
                  }),
                  const SizedBox(height: 12),
                  Material(
                    color: const Color(0xffA8172D),
                    borderRadius: BorderRadius.circular(17),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(17),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => EmergencyScreen(accountId: widget.accountId))),
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        child: Row(children: [
                          Container(width: 44, height: 44,
                            decoration: BoxDecoration(color: Colors.white.withOpacity(.13), shape: BoxShape.circle),
                            child: const Icon(Icons.sos_rounded, color: Colors.white, size: 27)),
                          const SizedBox(width: 12),
                          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Emergency Help', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                            SizedBox(height: 3),
                            Text('Get immediate assistance', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
                          ])),
                          const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 28),
                        ])),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(children: [
                    const Expanded(child: Text('Recent Trip', style: TextStyle(color: Colors.white,
                      fontSize: 19, fontWeight: FontWeight.w800))),
                    TextButton(onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen())),
                      child: const Text('View All', style: TextStyle(color: Color(0xff00D9D0), fontWeight: FontWeight.w700))),
                  ]),
                  _buildRecentActivity(),
                  const SizedBox(height: 18),
                ],
              ),
            ),
          ),
        ),
      );
        },
      ),
    );
  }

  // Permanent navigation for laptop/desktop layouts. The mobile/tablet
  // drawer and bottom navigation remain available at narrower widths.
  Widget _buildDesktopSidebar(BuildContext context, bool isAdmin) {
    return Container(
      width: 252,
      color: const Color(0xff031222),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 16, 20),
              child: Row(
                children: [
                  const AppLogo(size: 44),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Driver Safety AI', maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Colors.white, fontSize: 16,
                            fontWeight: FontWeight.w800)),
                        SizedBox(height: 3),
                        Text('Drive Safe. Live Better.', maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Color(0xff9CB4D0), fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withOpacity(.08), height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 5, 18, 8),
                    child: Text('DRIVING', style: TextStyle(
                      color: Color(0xff00D9D0), fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: 1)),
                  ),
                  _drawerItem(icon: Icons.dashboard_rounded, title: 'Home',
                    color: const Color(0xff00D9D0), selected: true, onTap: () {}),
                  _drawerItem(icon: Icons.map_outlined, title: 'Map',
                    color: const Color(0xff8CCBFF), onTap: () => _openMapsLocation(context)),
                  _drawerItem(icon: Icons.videocam_rounded, title: 'Monitoring',
                    color: const Color(0xff00D9D0), onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const MonitoringScreen(),
                      )).then((_) { if (mounted) setState(() {}); });
                    }),
                  _drawerItem(icon: Icons.bar_chart_rounded, title: 'Reports',
                    color: const Color(0xffB6C8DF), onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const ReportsScreen(),
                      ));
                    }),
                  _drawerItem(icon: Icons.history_rounded, title: 'History',
                    color: const Color(0xffB6C8DF), onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const HistoryScreen(),
                      ));
                    }),
                  _drawerItem(icon: Icons.emergency_rounded, title: 'Emergency',
                    color: Colors.orangeAccent, onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => EmergencyScreen(accountId: widget.accountId),
                      ));
                    }),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Divider(color: Colors.white12),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 0, 18, 8),
                    child: Text('ACCOUNT & SUPPORT', style: TextStyle(
                      color: Color(0xff00D9D0), fontSize: 10,
                      fontWeight: FontWeight.w800, letterSpacing: .7)),
                  ),
                  _drawerItem(icon: Icons.person_outline_rounded, title: 'Profile',
                    color: const Color(0xffB6C8DF), onTap: () => _showProfileDialog(context)),
                  _drawerItem(icon: Icons.settings_rounded, title: 'Settings',
                    color: Colors.amberAccent, onTap: () {
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ));
                    }),
                  _drawerItem(icon: Icons.headset_mic_rounded, title: 'Customer Support',
                    color: Colors.deepPurpleAccent, onTap: () => _showCustomerSupport(context)),
                  _drawerItem(icon: Icons.description_outlined, title: 'Terms & Conditions',
                    color: Colors.cyanAccent, onTap: () => _showTermsAndConditions(context)),
                  _drawerItem(icon: Icons.star_rate_rounded, title: 'Rate the App',
                    color: Colors.amber, onTap: () => _showRatingDialog(context)),
                  _drawerItem(icon: Icons.info_outline_rounded, title: 'About',
                    color: Colors.lightBlueAccent, onTap: () => _showAboutApp(context)),
                  if (isAdmin)
                    _drawerItem(icon: Icons.manage_accounts_rounded, title: 'User Data',
                      color: Colors.cyanAccent, onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => AdminUsersScreen(adminAccountId: widget.accountId),
                        ));
                      }),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: _drawerItem(icon: Icons.logout_rounded, title: 'Logout',
                color: Colors.redAccent, onTap: () => _showLogoutConfirmation(context)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    const inactive = Color(0xffB7C8DB);
    const active = Color(0xff00D9D0);
    return SafeArea(
      top: false,
      child: Center(
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width >= 1200
                ? 1120
                : MediaQuery.sizeOf(context).width >= 700
                    ? 900
                    : 460,
          ),
          decoration: const BoxDecoration(
            color: Color(0xff031222),
            border: Border(top: BorderSide(color: Color(0xff18334A), width: 1)),
          ),
          child: SizedBox(
            height: 66,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _bottomNavItem(Icons.home_rounded, 'Home', active, () {}),
                _bottomNavItem(Icons.map_outlined, 'Map', inactive, () => _openMapsLocation(context)),
                Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Material(
                    color: active,
                    shape: const CircleBorder(),
                    elevation: 5,
                    shadowColor: active,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const MonitoringScreen(),
                      )).then((_) { if (mounted) setState(() {}); }),
                      child: const SizedBox(
                        width: 52, height: 52,
                        child: Icon(Icons.videocam_rounded, color: Color(0xff001522), size: 27),
                      ),
                    ),
                  ),
                ),
                _bottomNavItem(Icons.bar_chart_rounded, 'Reports', inactive, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ReportsScreen()));
                }),
                _bottomNavItem(Icons.person_outline_rounded, 'Profile', inactive, () => _showProfileDialog(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomNavItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 3),
              Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutApp(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Driver Safety AI',
      applicationVersion: '1.0.0',
      children: const [Text('AI-assisted driver monitoring and journey safety tools.')],
    );
  }

  Widget _dashboardIconButton({required IconData icon, required String tooltip, required VoidCallback onTap}) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xff0C2035), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(.07))),
      child: IconButton(tooltip: tooltip, onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 23)),
    );
  }

  Widget _dashboardMetric({required double width, required IconData icon, required Color color,
    required String title, required String value, required String note}) {
    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 96),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xff061A2C),
        borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xff23405A).withOpacity(.7))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 34, height: 34,
          decoration: BoxDecoration(color: color.withOpacity(.13), borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: color, size: 21)),
        const SizedBox(width: 9),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xffDCE8F6), fontSize: 11.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 7),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(note, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xff8EA7C1), fontSize: 10.5)),
        ])),
      ]),
    );
  }

  Widget _buildDriveCardCopy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xff00C2FF).withOpacity(.12),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xff00C2FF).withOpacity(.28)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shield_outlined, color: Color(0xff00C2FF), size: 16),
              SizedBox(width: 7),
              Text(
                'DRIVE MODE',
                style: TextStyle(color: Color(0xff70DFFF), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Your journey.\nA smarter safety companion.',
          style: TextStyle(color: Colors.white, fontSize: 25, height: 1.18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          'Start a monitoring session to check driver attention and receive AI-based alerts.',
          style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildStartMonitoringButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MonitoringScreen()),
          ).then((_) {
            if (!mounted) return;
            setState(() {});
            Future.delayed(const Duration(milliseconds: 250), () {
              if (mounted) _showRatingDialog(context);
            });
          });
        },
        icon: const Icon(Icons.play_arrow_rounded, size: 24),
        label: const Padding(
          padding: EdgeInsets.symmetric(vertical: 15),
          child: Text('Start AI Monitoring', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xff00C2FF),
          foregroundColor: const Color(0xff08111F),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xff18263F),
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: Colors.white.withOpacity(.055)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: color.withOpacity(.13), borderRadius: BorderRadius.circular(13)),
                child: Icon(icon, color: color, size: 23),
              ),
              const SizedBox(height: 13),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 11, height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RECENT ACTIVITY
  // ============================================================

  Widget _buildRecentActivity() {

    final sessions =
        _sessionService.sessions;

    // ------------------------------------------------------------
    // NO SESSION
    // ------------------------------------------------------------

    if (sessions.isEmpty) {

      return Container(
        width: double.infinity,

        padding:
            const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 30,
        ),

        decoration: BoxDecoration(
          color:
              const Color(0xff18263F),

          borderRadius:
              BorderRadius.circular(22),

          border: Border.all(
            color:
                Colors.white.withOpacity(.05),
          ),
        ),

        child: Column(
          children: [

            Container(
              padding:
                  const EdgeInsets.all(14),

              decoration: BoxDecoration(
                color:
                    const Color(0xff223047),

                borderRadius:
                    BorderRadius.circular(16),
              ),

              child: const Icon(
                Icons.history_rounded,

                color:
                    Colors.white38,

                size: 30,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            const Text(
              "No recent activity",

              style: TextStyle(
                color:
                    Colors.white,

                fontSize: 17,

                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            const Text(
              "Start an AI monitoring session to see your activity here.",

              textAlign:
                  TextAlign.center,

              style: TextStyle(
                color:
                    Colors.white54,

                fontSize: 14,

                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    // ------------------------------------------------------------
    // LATEST SESSION
    // ------------------------------------------------------------

    final session =
        sessions.last;

    final bool critical =
        session.hasCriticalAlerts;

    final bool warning =
        session.hasWarnings;

    String status;
    Color statusColor;
    IconData icon;

    // ------------------------------------------------------------
    // CRITICAL
    // ------------------------------------------------------------

    if (critical) {

      status =
          "Critical alerts detected";

      statusColor =
          Colors.redAccent;

      icon =
          Icons.error_outline;
    }

    // ------------------------------------------------------------
    // WARNING
    // ------------------------------------------------------------

    else if (warning) {

      status =
          "Warning detected";

      statusColor =
          Colors.orange;

      icon =
          Icons.warning_amber_rounded;
    }

    // ------------------------------------------------------------
    // SAFE
    // ------------------------------------------------------------

    else {

      status =
          "Safe monitoring session";

      statusColor =
          Colors.green;

      icon =
          Icons.check_circle_outline;
    }

    // ------------------------------------------------------------
    // SESSION CARD
    // ------------------------------------------------------------

    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color:
            const Color(0xff18263F),

        borderRadius:
            BorderRadius.circular(22),

        border: Border.all(
          color:
              Colors.white.withOpacity(.05),
        ),
      ),

      child: Row(
        children: [

          // ----------------------------------------------------------
          // ICON
          // ----------------------------------------------------------

          Container(
            width: 52,
            height: 52,

            decoration: BoxDecoration(
              color:
                  statusColor.withOpacity(.12),

              borderRadius:
                  BorderRadius.circular(15),
            ),

            child: Icon(
              icon,

              color:
                  statusColor,

              size: 28,
            ),
          ),

          const SizedBox(
            width: 16,
          ),

          // ----------------------------------------------------------
          // SESSION INFORMATION
          // ----------------------------------------------------------

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [

                Text(
                  status,

                  style: const TextStyle(
                    color:
                        Colors.white,

                    fontSize: 16,

                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(
                  height: 6,
                ),

                Text(
                  "${session.duration.inSeconds}s • "
                  "${session.totalAnalyses} AI analyses",

                  style: const TextStyle(
                    color:
                        Colors.white54,

                    fontSize: 13,
                  ),
                ),

                const SizedBox(
                  height: 4,
                ),

                Text(
                  "Warnings: ${session.warningCount} • "
                  "Critical: ${session.criticalCount}",

                  style: TextStyle(
                    color:
                        statusColor,

                    fontSize: 12,

                    fontWeight:
                        FontWeight.w600,
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
  // MAIN APPLICATION DRAWER
  // ============================================================

  Widget _buildAppDrawer(BuildContext context, bool isAdmin) {
    return Drawer(
      backgroundColor: const Color(0xff08111F),
      width: 330,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 12, 14),
              child: Row(
                children: [
                  const AppLogo(size: 56),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Driver Safety AI',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'AI Driver Monitoring',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close menu',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  ),
                ],
              ),
            ),
            Divider(color: Colors.white.withOpacity(.08), height: 1),

            InkWell(
              onTap: () {
                Navigator.pop(context);
                _showProfileDialog(context);
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 25,
                      backgroundColor: Color(0xff20385A),
                      child: Icon(Icons.person_rounded, color: Colors.white70, size: 28),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'My Profile',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.accountId.isNotEmpty ? widget.accountId : 'Account information',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.white38),
                  ],
                ),
              ),
            ),
            Divider(color: Colors.white.withOpacity(.08), height: 1),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 4, 18, 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('DRIVING', style: TextStyle(
                        color: Color(0xff00D9D0), fontSize: 11,
                        fontWeight: FontWeight.w800, letterSpacing: .8)),
                    ),
                  ),
                  _drawerItem(
                    icon: Icons.dashboard_rounded,
                    title: 'Home / Dashboard',
                    color: Colors.lightBlueAccent,
                    selected: true,
                    onTap: () => Navigator.pop(context),
                  ),
                  _drawerItem(
                    icon: Icons.map_rounded,
                    title: 'Live Map & Location',
                    color: Colors.cyanAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _openMapsLocation(context);
                    },
                  ),
                  _drawerItem(
                    icon: Icons.bar_chart_rounded,
                    title: 'Safety Insights',
                    color: Colors.cyanAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const ReportsScreen(),
                      ));
                    },
                  ),
                  _drawerItem(
                    icon: Icons.health_and_safety_rounded,
                    title: 'Roadside Assistance',
                    color: Colors.orangeAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => EmergencyScreen(accountId: widget.accountId),
                      ));
                    },
                  ),
                  _drawerItem(
                    icon: Icons.history_rounded,
                    title: 'Trips History',
                    color: Colors.cyanAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const HistoryScreen(),
                      ));
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Divider(color: Colors.white12),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(18, 0, 18, 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text('ACCOUNT & SUPPORT', style: TextStyle(
                        color: Color(0xff00D9D0), fontSize: 11,
                        fontWeight: FontWeight.w800, letterSpacing: .8)),
                    ),
                  ),
                  _drawerItem(
                    icon: Icons.settings_rounded,
                    title: 'Settings',
                    color: Colors.amberAccent,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => const SettingsScreen(),
                      ));
                    },
                  ),
                  _drawerItem(
                    icon: Icons.headset_mic_rounded,
                    title: 'Customer Support',
                    color: Colors.deepPurpleAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _showCustomerSupport(context);
                    },
                  ),
                  _drawerItem(
                    icon: Icons.description_outlined,
                    title: 'Terms & Conditions',
                    color: Colors.cyanAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _showTermsAndConditions(context);
                    },
                  ),
                  _drawerItem(
                    icon: Icons.star_rate_rounded,
                    title: 'Rate the App',
                    color: Colors.amber,
                    onTap: () {
                      Navigator.pop(context);
                      _showRatingDialog(context);
                    },
                  ),
                  _drawerItem(
                    icon: Icons.info_rounded,
                    title: 'About App',
                    color: Colors.lightBlueAccent,
                    onTap: () {
                      Navigator.pop(context);
                      _showAboutApp(context);
                    },
                  ),

                  // Admin-only User Data
                  if (isAdmin) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 18),
                      child: Divider(color: Colors.white12),
                    ),
                    _drawerItem(
                      icon: Icons.manage_accounts_rounded,
                      title: 'User Data',
                      color: Colors.cyanAccent,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AdminUsersScreen(
                              adminAccountId: widget.accountId,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),


              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Column(
                  children: [
                    Divider(color: Colors.white.withOpacity(.08)),
                    _drawerItem(
                      icon: Icons.logout_rounded,
                      title: 'Logout',
                      color: Colors.redAccent,
                      onTap: () {
                        Navigator.pop(context);
                        _showLogoutConfirmation(context);
                      },
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Drive Safe. Live Better.  •  v1.0.0',
                      style: TextStyle(color: Colors.white30, fontSize: 11),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        color: selected ? const Color(0xff193E73) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: color, size: 23),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 15,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (!selected)
                  const Icon(Icons.chevron_right_rounded, color: Colors.white24, size: 19),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showProfileDialog(BuildContext context) {
    final accountId =
        widget.accountId.isNotEmpty ? widget.accountId : 'Not available';
    final role = widget.role.isNotEmpty ? widget.role : 'User';
    final adminStatus =
        widget.adminStatus.isNotEmpty ? widget.adminStatus : 'Not available';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final name = _profileDriverName.trim().isNotEmpty
                ? _profileDriverName.trim()
                : 'Not available';
            final mail = _profileEmail.trim().isNotEmpty
                ? _profileEmail.trim()
                : 'Not available';
            final license = _profileLicense.trim().isNotEmpty
                ? _profileLicense.trim()
                : '';

            final hasEmergencyContact =
                _emergencyContactName.trim().isNotEmpty ||
                _emergencyContactPhone.trim().isNotEmpty ||
                _emergencyContactEmail.trim().isNotEmpty ||
                _emergencyContactRelationship.trim().isNotEmpty;

            return Dialog(
              backgroundColor: const Color(0xff18263F),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 22,
                vertical: 30,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withOpacity(.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.person_rounded,
                              color: Colors.orangeAccent,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'My Profile',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 3),
                                Text(
                                  'Account and driver information',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isLoadingProfile)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.cyanAccent,
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      _profileSection(
                        title: 'Account Information',
                        icon: Icons.badge_outlined,
                        children: [
                          _profileRow('Driver Name', name),
                          const SizedBox(height: 12),
                          _profileRow('Email', mail),
                          const SizedBox(height: 12),
                          _profileRow('Account ID', accountId),
                          const SizedBox(height: 12),
                          _profileRow('Role', role),
                          const SizedBox(height: 12),
                          _profileRow('Admin Status', adminStatus),
                        ],
                      ),

                      // Vehicle/license are optional and are shown only when
                      // information is available. Existing vehicle/license
                      // behavior is preserved.
                      if (widget.vehicleInfo.trim().isNotEmpty ||
                          license.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _profileSection(
                          title: 'Vehicle & License',
                          icon: Icons.directions_car_filled_outlined,
                          children: [
                            if (widget.vehicleInfo.trim().isNotEmpty)
                              _profileRow(
                                'Vehicle',
                                widget.vehicleInfo.trim(),
                              ),
                            if (widget.vehicleInfo.trim().isNotEmpty &&
                                license.isNotEmpty)
                              const SizedBox(height: 12),
                            if (license.isNotEmpty)
                              _profileRow(
                                'License',
                                license,
                              ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 14),

                      _profileSection(
                        title: 'Emergency Contact',
                        icon: Icons.contact_emergency_outlined,
                        children: [
                          _profileRow(
                            'Name',
                            _emergencyContactName.trim().isNotEmpty
                                ? _emergencyContactName.trim()
                                : 'Not added',
                          ),
                          const SizedBox(height: 12),
                          _profileRow(
                            'Phone',
                            _emergencyContactPhone.trim().isNotEmpty
                                ? _emergencyContactPhone.trim()
                                : 'Not added',
                          ),
                          const SizedBox(height: 12),
                          _profileRow(
                            'Email',
                            _emergencyContactEmail.trim().isNotEmpty
                                ? _emergencyContactEmail.trim()
                                : 'Not added',
                          ),
                          const SizedBox(height: 12),
                          _profileRow(
                            'Relationship',
                            _emergencyContactRelationship.trim().isNotEmpty
                                ? _emergencyContactRelationship.trim()
                                : 'Not added',
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: () {
                                _showEmergencyContactDialog(
                                  context,
                                  onSaved: () {
                                    setDialogState(() {});
                                  },
                                );
                              },
                              icon: Icon(
                                hasEmergencyContact
                                    ? Icons.edit_rounded
                                    : Icons.add_rounded,
                              ),
                              label: Text(
                                hasEmergencyContact
                                    ? 'EDIT EMERGENCY CONTACT'
                                    : 'ADD EMERGENCY CONTACT',
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.cyanAccent,
                                foregroundColor: const Color(0xff08111F),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Emergency contact is required for SOS alerts. Name and email are mandatory; phone number and relationship are optional.',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: const Text(
                            'Close',
                            style: TextStyle(color: Colors.cyanAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEmergencyContactDialog(
    BuildContext context, {
    VoidCallback? onSaved,
  }) async {
    final nameController =
        TextEditingController(text: _emergencyContactName);
    final phoneController =
        TextEditingController(text: _emergencyContactPhone);
    final emailController =
        TextEditingController(text: _emergencyContactEmail);
    final relationshipController =
        TextEditingController(text: _emergencyContactRelationship);

    bool saving = false;
    String? errorText;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
              final email = emailController.text.trim();
              final relationship = relationshipController.text.trim();

              if (name.isEmpty) {
                setDialogState(() {
                  errorText = 'Emergency contact name is required.';
                });
                return;
              }

              if (email.isEmpty) {
                setDialogState(() {
                  errorText = 'Emergency contact email is required.';
                });
                return;
              }

              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
                setDialogState(() {
                  errorText = 'Please enter a valid email address.';
                });
                return;
              }

              setDialogState(() {
                saving = true;
                errorText = null;
              });

              try {
                final response = await http.post(
                  Uri.parse('http://192.168.31.55:8000/emergency-contact'),
                  headers: {
                    'Content-Type': 'application/json',
                  },
                  body: jsonEncode({
                    'account_id': widget.accountId.trim(),
                    'emergency_contact_name': name,
                    'emergency_contact_phone': phone,
                    'emergency_contact_email': email,
                    'emergency_contact_relationship':
                        relationship.isEmpty ? null : relationship,
                  }),
                );

                final dynamic decoded = jsonDecode(response.body);
                final Map<String, dynamic> result =
                    decoded is Map<String, dynamic>
                        ? decoded
                        : <String, dynamic>{
                            'success': response.statusCode >= 200 &&
                                response.statusCode < 300,
                            'data': decoded,
                          };

                if (!mounted) return;

                if (result['success'] == true) {
                  setState(() {
                    _emergencyContactName = name;
                    _emergencyContactPhone = phone;
                    _emergencyContactEmail = email;
                    _emergencyContactRelationship = relationship;
                  });

                  Navigator.pop(dialogContext);
                  onSaved?.call();

                  _showSimpleMessage(
                    this.context,
                    'Emergency contact saved successfully.',
                  );
                } else {
                  setDialogState(() {
                    saving = false;
                    errorText = result['message']?.toString() ??
                        'Unable to save emergency contact.';
                  });
                }
              } catch (e) {
                if (!mounted) return;

                setDialogState(() {
                  saving = false;
                  errorText = 'Unable to save emergency contact: $e';
                });
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xff18263F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              title: const Row(
                children: [
                  Icon(
                    Icons.contact_emergency_outlined,
                    color: Colors.cyanAccent,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Emergency Contact',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Add the person who should receive emergency assistance information.',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _emergencyTextField(
                      controller: nameController,
                      label: 'Name *',
                      icon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    _emergencyTextField(
                      controller: phoneController,
                      label: 'Phone (Optional)',
                      icon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    _emergencyTextField(
                      controller: emailController,
                      label: 'Email *',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    _emergencyTextField(
                      controller: relationshipController,
                      label: 'Relationship (Optional)',
                      icon: Icons.people_outline,
                      textInputAction: TextInputAction.done,
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorText!,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xff08111F),
                          ),
                        )
                      : const Icon(Icons.save_rounded),
                  label: Text(saving ? 'Saving...' : 'Save'),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.cyanAccent,
                    foregroundColor: const Color(0xff08111F),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    relationshipController.dispose();
  }

  Widget _emergencyTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(
          icon,
          color: Colors.cyanAccent,
        ),
        filled: true,
        fillColor: const Color(0xff223047),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(
            color: Colors.cyanAccent,
          ),
        ),
      ),
    );
  }

  Widget _profileSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff223047),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 9),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _profileRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _openMapsLocation(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MapsScreen(),
      ),
    );
  }

  void _showTermsAndConditions(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xff18263F),
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: Colors.cyanAccent,
                      size: 28,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Terms & Conditions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please read these terms carefully before using Driver Safety AI.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 20),

                _termsSection(
                  '1. Acceptance of Terms',
                  'By accessing or using Driver Safety AI, you acknowledge that '
                      'you have read, understood and agree to these terms. If you '
                      'do not agree with any part of these terms, do not use the '
                      'application.',
                ),
                _termsSection(
                  '2. Purpose of the Application',
                  'Driver Safety AI is designed as a driver safety and fatigue '
                      'monitoring platform. It uses camera-based computer vision '
                      'and related application features to provide safety-related '
                      'information during a monitoring session. The application '
                      'is an assistance tool and is not a replacement for the '
                      'driver\'s own attention, judgement or responsibility.',
                ),
                _termsSection(
                  '3. Safe Driving Responsibility',
                  'The driver must remain attentive to the road, traffic, '
                      'surroundings and applicable driving laws at all times. '
                      'Do not operate the application in a way that distracts '
                      'you from driving. If the application displays a warning, '
                      'take appropriate and safe action only when it is safe to '
                      'do so.',
                ),
                _termsSection(
                  '4. AI Monitoring Limitations',
                  'AI-based detection can produce incorrect, delayed or incomplete '
                      'results because camera position, lighting, face visibility, '
                      'motion and environmental conditions can affect detection. '
                      'A status such as Safe, Low or Normal must not be treated '
                      'as a guarantee that a driver is safe to continue driving.',
                ),
                _termsSection(
                  '5. Camera and Session Data',
                  'Camera access may be required for real-time monitoring. Session '
                      'information may be used by the application for monitoring, '
                      'history and reports according to the configured data '
                      "handling rules. Users should review the application's "
                      'privacy and data settings before starting a session.',
                ),
                _termsSection(
                  '6. Location and Maps',
                  'Maps and location features may be used to display or support '
                      'journey-related information. Location availability depends '
                      'on device permissions, network availability and the '
                      'configured map service. Location information should not '
                      'be used as a substitute for normal navigation or safe '
                      'driving practices.',
                ),
                _termsSection(
                  '7. Emergency Features',
                  'Emergency features are provided to assist the user in accessing '
                      'configured safety options. The application cannot guarantee '
                      'that an emergency call, message, location update or other '
                      'communication will succeed. Network availability, device '
                      'permissions and third-party services may affect emergency '
                      'functionality.',
                ),
                _termsSection(
                  '8. Reports and History',
                  'Monitoring sessions may generate reports, summaries and history '
                      'records. These records are intended to help users understand '
                      'their monitoring activity. They should not be interpreted '
                      'as medical, legal or professional certification.',
                ),
                _termsSection(
                  '9. Account Security',
                  'Users are responsible for protecting their login credentials '
                      'and for using their own account. Do not share passwords or '
                      'other authentication information. If you believe your '
                      'account has been compromised, use the available account '
                      'security and support options.',
                ),
                _termsSection(
                  '10. Third-Party Services',
                  'Some application functions may depend on external services '
                      'such as maps, communication providers, device permissions '
                      'or cloud/API services. Availability of those services is '
                      'outside the direct control of the application.',
                ),
                _termsSection(
                  '11. Service Availability',
                  'Features may be updated, changed, temporarily unavailable or '
                      'disabled when maintenance, configuration or technical '
                      'conditions require it. The application should not be relied '
                      'upon as the sole safety mechanism during a journey.',
                ),
                _termsSection(
                  '12. Updates to These Terms',
                  'These terms may be updated when application features, security '
                      'requirements or data-handling practices change. Continued '
                      'use of the application after an update indicates that the '
                      'user has reviewed the updated terms.',
                ),
                _termsSection(
                  '13. Contact and Support',
                  'For questions, technical issues or account-related concerns, '
                      'use Customer Support from the application menu.',
                ),

                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'Close',
                      style: TextStyle(color: Colors.cyanAccent),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _termsSection(String title, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showRatingDialog(BuildContext context) {
    int selectedRating = -1;
    final feedbackController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: const Color(0xff18263F),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.star_rate_rounded,
                            color: Colors.amber,
                            size: 28,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Feedback',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'How likely are you to recommend Driver Safety AI to your friends and family?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // NPS-style 0–10 rating scale.
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 7,
                        runSpacing: 8,
                        children: List.generate(
                          11,
                          (index) {
                            final bool selected = selectedRating == index;

                            Color ratingColor;
                            if (index <= 6) {
                              ratingColor = Colors.redAccent;
                            } else if (index <= 8) {
                              ratingColor = Colors.orangeAccent;
                            } else {
                              ratingColor = Colors.green;
                            }

                            return InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                setDialogState(() {
                                  selectedRating = index;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? Colors.white
                                      : ratingColor.withOpacity(.18),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: selected
                                        ? Colors.white
                                        : ratingColor.withOpacity(.55),
                                  ),
                                ),
                                child: Text(
                                  '$index',
                                  style: TextStyle(
                                    color: selected
                                        ? const Color(0xff08111F)
                                        : ratingColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 10),

                      const Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Not likely',
                            style: TextStyle(color: Colors.white54),
                          ),
                          Text(
                            'Neutral',
                            style: TextStyle(color: Colors.white54),
                          ),
                          Text(
                            'Very likely',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      TextField(
                        controller: feedbackController,
                        maxLines: 3,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Tell us what we can improve (optional)',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xff223047),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              feedbackController.dispose();
                              Navigator.pop(dialogContext);
                            },
                            child: const Text(
                              'Later',
                              style: TextStyle(color: Colors.white60),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            onPressed: selectedRating < 0
                                ? null
                                : () {
                                    final rating = selectedRating;
                                    final feedback =
                                        feedbackController.text.trim();

                                    feedbackController.dispose();
                                    Navigator.pop(dialogContext);

                                    _showSimpleMessage(
                                      context,
                                      feedback.isEmpty
                                          ? 'Thank you for rating Driver Safety AI: $rating/10.'
                                          : 'Thank you for your feedback and $rating/10 rating.',
                                    );
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.cyanAccent,
                              foregroundColor: const Color(0xff08111F),
                            ),
                            child: const Text('Submit'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showCustomerSupport(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xff18263F),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.headset_mic_rounded, color: Colors.deepPurpleAccent),
                  SizedBox(width: 10),
                  Text(
                    'Customer Support',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Need help with Driver Safety AI? Choose an option below.',
                style: TextStyle(color: Colors.white60, height: 1.4),
              ),
              const SizedBox(height: 18),
              _supportAction(
                icon: Icons.help_outline_rounded,
                title: 'Help Center',
                subtitle: 'Learn how the application works',
                onTap: () => _showSimpleMessage(context, 'Help Center will be connected here.'),
              ),
              const SizedBox(height: 10),
              _supportAction(
                icon: Icons.email_outlined,
                title: 'Contact Us',
                subtitle: 'Send a support request',
                onTap: () => _showSimpleMessage(context, 'Contact support will be connected here.'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _supportAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xff223047),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Icon(icon, color: Colors.cyanAccent, size: 25),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xff18263F),
        title: const Text('Logout?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to logout from Driver Safety AI?',
          style: TextStyle(color: Colors.white70, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('Logout', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showSimpleMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        // Fixed SnackBars avoid the floating-SnackBar layout assertion
        // seen on the web dashboard with its bottom navigation bar.
        behavior: SnackBarBehavior.fixed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ============================================================
  // NOTIFICATION MESSAGE
  // ============================================================

  static void _showNotificationMessage(
    BuildContext context,
  ) {

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "No new safety notifications.",
        ),
        // Explicitly override any app-wide floating SnackBar theme.
        behavior: SnackBarBehavior.fixed,
        duration: Duration(seconds: 2),
      ),
    );
  }
}


// ============================================================================
// STATUS TILE
// ============================================================================

class StatusTile extends StatelessWidget {

  final IconData icon;
  final String title;
  final String status;
  final Color color;

  const StatusTile({
    super.key,

    required this.icon,
    required this.title,
    required this.status,
    required this.color,
  });

  @override
  Widget build(
    BuildContext context,
  ) {

    return Row(
      children: [

        // ----------------------------------------------------------
        // ICON
        // ----------------------------------------------------------

        CircleAvatar(
          radius: 22,

          backgroundColor:
              color.withOpacity(.15),

          child: Icon(
            icon,

            color:
                color,

            size: 22,
          ),
        ),

        const SizedBox(
          width: 16,
        ),

        // ----------------------------------------------------------
        // TITLE
        // ----------------------------------------------------------

        Expanded(
          child: Text(
            title,

            style: const TextStyle(
              color:
                  Colors.white,

              fontSize: 17,

              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),

        // ----------------------------------------------------------
        // STATUS
        // ----------------------------------------------------------

        Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),

          decoration: BoxDecoration(
            color:
                color.withOpacity(.15),

            borderRadius:
                BorderRadius.circular(30),
          ),

          child: Text(
            status,

            style: TextStyle(
              color:
                  color,

              fontWeight:
                  FontWeight.bold,

              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}
