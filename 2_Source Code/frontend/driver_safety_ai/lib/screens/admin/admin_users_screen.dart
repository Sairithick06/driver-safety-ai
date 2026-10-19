import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AdminUsersScreen extends StatefulWidget {
  final String adminAccountId;

  const AdminUsersScreen({
    super.key,
    required this.adminAccountId,
  });

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen>
    with SingleTickerProviderStateMixin {
  static const String baseUrl = "http://192.168.31.55:8000";

  late TabController _tabController;

  final TextEditingController _searchController =
      TextEditingController();

  bool _isLoadingSql = true;
  bool _isLoadingExcel = true;

  String? _sqlError;
  String? _excelError;

  List<Map<String, dynamic>> _sqlUsers = [];
  List<Map<String, dynamic>> _excelAdmins = [];

  String _searchText = "";

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
      length: 2,
      vsync: this,
    );

    _searchController.addListener(() {
      if (mounted) {
        setState(() {
          _searchText =
              _searchController.text.trim().toLowerCase();
        });
      }
    });

    _loadSqlUsers();
    _loadExcelAdmins();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD USERS FROM SQL DATABASE
  // ============================================================

  Future<void> _loadSqlUsers() async {
    if (mounted) {
      setState(() {
        _isLoadingSql = true;
        _sqlError = null;
      });
    }

    try {
      final uri = Uri.parse(
        '$baseUrl/admin/users?admin_account_id=${Uri.encodeQueryComponent(widget.adminAccountId)}',
      );

      final response = await http.get(uri);

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          data['success'] == true) {
        setState(() {
          _sqlUsers =
              (data['users'] as List? ?? [])
                  .map(
                    (e) =>
                        Map<String, dynamic>.from(e),
                  )
                  .toList();

          _isLoadingSql = false;
        });
      } else {
        setState(() {
          _sqlError =
              data['message']?.toString() ??
                  'Unable to load SQL users.';

          _isLoadingSql = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sqlError =
              'Unable to connect to the backend.';

          _isLoadingSql = false;
        });
      }
    }
  }

  // ============================================================
  // LOAD USERS FROM EXCEL
  // ============================================================

  Future<void> _loadExcelAdmins() async {
    if (mounted) {
      setState(() {
        _isLoadingExcel = true;
        _excelError = null;
      });
    }

    try {
      final uri = Uri.parse(
        '$baseUrl/admin/excel-admins?admin_account_id=${Uri.encodeQueryComponent(widget.adminAccountId)}',
      );

      final response = await http.get(uri);

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          data['success'] == true) {
        setState(() {
          _excelAdmins =
              (data['admins'] as List? ?? [])
                  .map(
                    (e) =>
                        Map<String, dynamic>.from(e),
                  )
                  .toList();

          _isLoadingExcel = false;
        });
      } else {
        setState(() {
          _excelError =
              data['message']?.toString() ??
                  'Unable to load Excel records.';

          _isLoadingExcel = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _excelError =
              'Unable to connect to the backend.';

          _isLoadingExcel = false;
        });
      }
    }
  }

  // ============================================================
  // SEARCH FILTER
  // ============================================================

  List<Map<String, dynamic>> _filter(
    List<Map<String, dynamic>> data,
  ) {
    if (_searchText.isEmpty) {
      return data;
    }

    return data.where((item) {
      return [
        item['db_id'],
        item['account_id'],
        item['full_name'],
        item['email'],
        item['phone'],
        item['role'],
        item['admin_status'],
      ]
          .map(
            (v) =>
                v?.toString().toLowerCase() ?? '',
          )
          .join(' ')
          .contains(_searchText);
    }).toList();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff08111F),

      appBar: AppBar(
        backgroundColor: const Color(0xff10233D),
        foregroundColor: Colors.white,
        elevation: 0,

        title: const Text(
          'Registered Users',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.cyanAccent,
          labelColor: Colors.cyanAccent,
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(
              icon: Icon(Icons.storage_rounded),
              text: 'SQL Database',
            ),
            Tab(
              icon: Icon(Icons.table_chart_rounded),
              text: 'Excel',
            ),
          ],
        ),
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              18,
              18,
              18,
              10,
            ),

            child: TextField(
              controller: _searchController,
              style: const TextStyle(
                color: Colors.white,
              ),

              decoration: InputDecoration(
                hintText:
                    'Search name, Account ID, email, phone...',

                hintStyle: const TextStyle(
                  color: Colors.white38,
                ),

                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.cyanAccent,
                ),

                suffixIcon:
                    _searchText.isNotEmpty
                        ? IconButton(
                          onPressed:
                              _searchController.clear,
                          icon: const Icon(
                            Icons.clear_rounded,
                            color: Colors.white54,
                          ),
                        )
                        : null,

                filled: true,
                fillColor: const Color(0xff18263F),

                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSql(),
                _buildExcel(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SQL TAB
  // ============================================================

  Widget _buildSql() {
    if (_isLoadingSql) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.cyanAccent,
        ),
      );
    }

    if (_sqlError != null) {
      return _error(
        _sqlError!,
        _loadSqlUsers,
      );
    }

    final users = _filter(_sqlUsers);

    if (users.isEmpty) {
      return _empty(
        'No users found',
        'No registered accounts match your search.',
        _loadSqlUsers,
      );
    }

    return RefreshIndicator(
      color: Colors.cyanAccent,
      backgroundColor: const Color(0xff1B2A41),
      onRefresh: _loadSqlUsers,

      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          18,
          8,
          18,
          30,
        ),

        itemCount: users.length,

        itemBuilder: (_, i) {
          return _UserCard(
            user: users[i],
            source: 'SQL Database',
          );
        },
      ),
    );
  }

  // ============================================================
  // EXCEL TAB
  // ============================================================

  Widget _buildExcel() {
    if (_isLoadingExcel) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.cyanAccent,
        ),
      );
    }

    if (_excelError != null) {
      return _error(
        _excelError!,
        _loadExcelAdmins,
      );
    }

    final admins = _filter(_excelAdmins);

    if (admins.isEmpty) {
      return _empty(
        'No Excel records found',
        'No approved Admin records are stored in Excel.',
        _loadExcelAdmins,
      );
    }

    return RefreshIndicator(
      color: Colors.cyanAccent,
      backgroundColor: const Color(0xff1B2A41),
      onRefresh: _loadExcelAdmins,

      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          18,
          8,
          18,
          30,
        ),

        itemCount: admins.length,

        itemBuilder: (_, i) {
          return _UserCard(
            user: admins[i],
            source: 'Excel',
          );
        },
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _empty(
    String title,
    String subtitle,
    Future<void> Function() refresh,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.people_outline_rounded,
              color: Colors.white30,
              size: 58,
            ),

            const SizedBox(height: 16),

            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 18),

            OutlinedButton.icon(
              onPressed: refresh,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text('Refresh'),

              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.cyanAccent,
                side: const BorderSide(
                  color: Colors.cyanAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _error(
    String message,
    Future<void> Function() retry,
  ) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 52,
            ),

            const SizedBox(height: 14),

            const Text(
              'Unable to load data',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white54,
                height: 1.5,
              ),
            ),

            const SizedBox(height: 18),

            ElevatedButton.icon(
              onPressed: retry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text('Try Again'),

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.cyanAccent,
                foregroundColor: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// USER CARD
// ================================================================

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final String source;

  const _UserCard({
    required this.user,
    required this.source,
  });

  String v(String key) {
    final x = user[key];

    if (x == null ||
        x.toString().trim().isEmpty) {
      return 'Not provided';
    }

    return x.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin =
        user['role']
                ?.toString()
                .toLowerCase() ==
            'admin';

    final roleColor =
        isAdmin
            ? Colors.orangeAccent
            : Colors.cyanAccent;

    final status =
        user['admin_status']
                ?.toString()
                .toLowerCase() ??
            'approved';

    final statusColor =
        status == 'approved'
            ? Colors.greenAccent
            : status == 'pending'
                ? Colors.orangeAccent
                : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.only(
        bottom: 14,
      ),

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: const Color(0xff18263F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withOpacity(.06),
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,

                backgroundColor:
                    roleColor.withOpacity(.13),

                child: Icon(
                  isAdmin
                      ? Icons.admin_panel_settings_rounded
                      : Icons.person_rounded,
                  color: roleColor,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      v('full_name'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      v('account_id'),
                      style: const TextStyle(
                        color: Colors.cyanAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),

                decoration: BoxDecoration(
                  color:
                      roleColor.withOpacity(.12),
                  borderRadius:
                      BorderRadius.circular(30),
                ),

                child: Text(
                  v('role').toUpperCase(),
                  style: TextStyle(
                    color: roleColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          const Divider(
            color: Colors.white10,
          ),

          const SizedBox(height: 10),

          _row(
            Icons.badge_outlined,
            'DB ID',
            v('db_id'),
          ),

          _row(
            Icons.email_outlined,
            'Email',
            v('email'),
          ),

          _row(
            Icons.phone_outlined,
            'Phone',
            v('phone'),
          ),

          _row(
            Icons.credit_card_outlined,
            'Driving Licence',
            v('driving_license'),
          ),

          _row(
            Icons.verified_user_outlined,
            'Admin Status',
            v('admin_status'),
            statusColor,
          ),

          _row(
            Icons.calendar_today_outlined,
            'Registered',
            v('registered_date'),
          ),

          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'Source: $source',
              style: const TextStyle(
                color: Colors.white30,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(
    IconData icon,
    String label,
    String value, [
    Color? color,
  ]) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 7,
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          SizedBox(
            width: 28,
            child: Icon(
              icon,
              color: Colors.white38,
              size: 18,
            ),
          ),

          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color:
                    color ?? Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}