import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../home/home_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../register/register_screen.dart';
import '../forgot_password/forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _identifierController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _otpController =
      TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  // Password = true
  // OTP = false
  bool _loginWithPassword = true;

  // ============================================================
  // OTP STATE
  // ============================================================

  // True after OTP has been successfully sent
  bool _otpSent = false;

  // True after OTP has been successfully verified
  bool _otpVerified = false;

  // Data received after OTP verification
  String _otpAccountId = "";
  String _otpRole = "user";
  String _otpAdminStatus = "approved";

  // ============================================================
  // BACKEND
  // ============================================================

  static const String baseUrl = "http://192.168.31.55:8000";

  // ============================================================
  // SHARED PREFERENCES
  // ============================================================

  static const String _rememberMeKey = "remember_me";
  static const String _savedIdentifierKey = "saved_identifier";

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadRememberedLogin();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD REMEMBERED LOGIN
  // ============================================================

  Future<void> _loadRememberedLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final bool rememberMe =
          prefs.getBool(_rememberMeKey) ?? false;

      final String savedIdentifier =
          prefs.getString(_savedIdentifierKey) ?? "";

      if (!mounted) return;

      setState(() {
        _rememberMe = rememberMe;

        if (rememberMe && savedIdentifier.isNotEmpty) {
          _identifierController.text = savedIdentifier;
        }
      });

      debugPrint("Remember Me loaded: $rememberMe");
      debugPrint(
        "Saved identifier exists: ${savedIdentifier.isNotEmpty}",
      );
    } catch (e) {
      debugPrint("REMEMBER ME LOAD ERROR: $e");
    }
  }

  // ============================================================
  // SAVE REMEMBERED LOGIN
  // ============================================================

  Future<void> _saveRememberedLogin(
    String identifier,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_rememberMe) {
        await prefs.setBool(
          _rememberMeKey,
          true,
        );

        await prefs.setString(
          _savedIdentifierKey,
          identifier,
        );

        debugPrint("Remember Me: SAVED");
      } else {
        await prefs.setBool(
          _rememberMeKey,
          false,
        );

        await prefs.remove(
          _savedIdentifierKey,
        );

        debugPrint("Remember Me: CLEARED");
      }
    } catch (e) {
      debugPrint("REMEMBER ME SAVE ERROR: $e");
    }
  }

  // ============================================================
  // CLEAR REMEMBERED LOGIN
  // ============================================================

  Future<void> _clearRememberedLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool(
        _rememberMeKey,
        false,
      );

      await prefs.remove(
        _savedIdentifierKey,
      );

      debugPrint("Remember Me: CLEARED");
    } catch (e) {
      debugPrint("REMEMBER ME CLEAR ERROR: $e");
    }
  }

  // ============================================================
  // PASSWORD LOGIN
  // ============================================================

  Future<void> _login() async {
    final String identifier =
        _identifierController.text.trim();

    final String password =
        _passwordController.text;

    if (identifier.isEmpty) {
      _showError(
        "Please enter your User ID or phone number.",
      );
      return;
    }

    if (password.isEmpty) {
      _showError(
        "Please enter your password.",
      );
      return;
    }

    if (password.length < 8) {
      _showError(
        "Invalid login credentials.",
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "identifier": identifier,
          "password": password,
        }),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // A successful HTTP status alone does NOT mean authentication
      // succeeded. The backend can return HTTP 200 with success: false.
      final dynamic decodedResponse = jsonDecode(response.body);

      if (decodedResponse is! Map<String, dynamic>) {
        debugPrint("LOGIN ERROR: Unexpected response format");
        _showError("Unable to verify login credentials. Please try again.");
        return;
      }

      final Map<String, dynamic> data = decodedResponse;
      final bool loginSucceeded = data["success"] == true;

      debugPrint(
        "LOGIN RESPONSE | Status: ${response.statusCode} | "
        "Success: $loginSucceeded",
      );

      if (response.statusCode == 200 && loginSucceeded) {
        final String accountId =
            data["account_id"]?.toString() ??
                data["driver_id"]?.toString() ??
                data["user"]?["account_id"]?.toString() ??
                data["user"]?["driver_id"]?.toString() ??
                "";

        final String role =
            data["role"]?.toString() ??
                data["user"]?["role"]?.toString() ??
                "user";

        final String adminStatus =
            data["admin_status"]?.toString() ??
                data["user"]?["admin_status"]?.toString() ??
                "approved";

        debugPrint("Role: $role");
        debugPrint("Admin Status: $adminStatus");
        debugPrint("LOGIN SUCCESS");
        debugPrint("Account ID: $accountId");

        await _saveRememberedLogin(
          identifier,
        );

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              accountId.isNotEmpty
                  ? "Login successful. Account ID: $accountId"
                  : "Login successful.",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
              ),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.fixed,
          ),
        );

        await Future.delayed(
          const Duration(milliseconds: 500),
        );

        if (!mounted) return;

        _navigateToHome(
          accountId: accountId,
          role: role,
          adminStatus: adminStatus,
        );
      } else {
        final String message =
            data["message"]?.toString() ??
            "Invalid login credentials.";
        _showError(
          response.statusCode == 200
              ? message
              : "Invalid login credentials.",
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      debugPrint("LOGIN ERROR: $e");

      _showError(
        "Unable to connect to the server.",
      );
    }
  }

  // ============================================================
  // SEND OTP
  // ============================================================

  Future<void> _sendOtp() async {
    final String identifier =
        _identifierController.text.trim();

    if (identifier.isEmpty) {
      _showError(
        "Please enter your User ID or phone number.",
      );
      return;
    }

    // Reset OTP state when requesting a new OTP
    setState(() {
      _isLoading = true;
      _otpSent = false;
      _otpVerified = false;
      _otpController.clear();
    });

    try {
      debugPrint(
        "OTP REQUEST | Identifier: $identifier",
      );

      final response = await http.post(
        Uri.parse('$baseUrl/send-otp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "identifier": identifier,
        }),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      final Map<String, dynamic> data =
          jsonDecode(response.body);

      final bool success =
          data["success"] == true;

      final String message =
          data["message"]?.toString() ??
              "Unable to send OTP.";

      debugPrint(
        "SEND OTP RESPONSE | "
        "Status: ${response.statusCode} | "
        "Success: $success | "
        "Message: $message",
      );

      if (response.statusCode == 200 &&
          success) {
        setState(() {
          _otpSent = true;
          _otpVerified = false;
        });

        _showInfo(
          "OTP sent to your registered email address. "
          "Please check your email.",
        );
      } else {
        _showError(message);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      debugPrint(
        "SEND OTP ERROR: $e",
      );

      _showError(
        "Unable to connect to the OTP service.",
      );
    }
  }

  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<void> _verifyOtp() async {
    final String identifier =
        _identifierController.text.trim();

    final String otp =
        _otpController.text.trim();

    if (identifier.isEmpty) {
      _showError(
        "Please enter your User ID or phone number.",
      );
      return;
    }

    if (!_otpSent) {
      _showError(
        "Please click Send OTP first.",
      );
      return;
    }

    if (otp.isEmpty) {
      _showError(
        "Please enter the OTP.",
      );
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _showError(
        "Please enter a valid 6-digit OTP.",
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      debugPrint(
        "VERIFY OTP REQUEST | Identifier: $identifier",
      );

      final response = await http.post(
        Uri.parse('$baseUrl/verify-otp'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "identifier": identifier,
          "otp": otp,
        }),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      final Map<String, dynamic> data =
          jsonDecode(response.body);

      final bool success =
          data["success"] == true;

      final String message =
          data["message"]?.toString() ??
              "Unable to verify OTP.";

      debugPrint(
        "VERIFY OTP RESPONSE | "
        "Status: ${response.statusCode} | "
        "Success: $success | "
        "Message: $message",
      );

      if (response.statusCode != 200 ||
          !success) {
        _showError(message);
        return;
      }

      // ========================================================
      // OTP VERIFIED SUCCESSFULLY
      // ========================================================

      final String accountId =
          data["account_id"]?.toString() ??
              data["driver_id"]?.toString() ??
              data["user"]?["account_id"]?.toString() ??
              data["user"]?["driver_id"]?.toString() ??
              "";

      final String role =
          data["role"]?.toString() ??
              data["user"]?["role"]?.toString() ??
              "user";

      final String adminStatus =
          data["admin_status"]?.toString() ??
              data["user"]?["admin_status"]?.toString() ??
              "approved";

      debugPrint("OTP VERIFIED SUCCESSFULLY");
      debugPrint("Account ID: $accountId");
      debugPrint("Role: $role");
      debugPrint("Admin Status: $adminStatus");

      // Store the information temporarily.
      // Navigation will happen only when Login is clicked.
      setState(() {
        _otpVerified = true;

        _otpAccountId = accountId;
        _otpRole = role;
        _otpAdminStatus = adminStatus;
      });

      await _saveRememberedLogin(
        identifier,
      );

      if (!mounted) return;

      _showSuccess(
        "OTP verified successfully. You can now Login.",
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      debugPrint(
        "VERIFY OTP ERROR: $e",
      );

      _showError(
        "Unable to connect to the OTP verification service.",
      );
    }
  }

  // ============================================================
  // OTP LOGIN AFTER VERIFICATION
  // ============================================================

  Future<void> _loginAfterOtpVerification() async {
    if (!_otpVerified) {
      _showError(
        "Please verify the OTP first.",
      );
      return;
    }

    final String identifier =
        _identifierController.text.trim();

    if (identifier.isEmpty) {
      _showError(
        "Please enter your User ID or phone number.",
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    debugPrint("OTP LOGIN BUTTON CLICKED");
    debugPrint("Account ID: $_otpAccountId");
    debugPrint("Role: $_otpRole");
    debugPrint("Admin Status: $_otpAdminStatus");

    await _saveRememberedLogin(
      identifier,
    );

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _otpAccountId.isNotEmpty
              ? "Login successful. Account ID: $_otpAccountId"
              : "Login successful.",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.fixed,
      ),
    );

    await Future.delayed(
      const Duration(milliseconds: 500),
    );

    if (!mounted) return;

    _navigateToHome(
      accountId: _otpAccountId,
      role: _otpRole,
      adminStatus: _otpAdminStatus,
    );
  }

  // ============================================================
  // NAVIGATE TO HOME
  // ============================================================

  void _navigateToHome({
    required String accountId,
    required String role,
    required String adminStatus,
  }) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          accountId: accountId,
          role: role,
          adminStatus: adminStatus,
        ),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // MAIN OTP BUTTON ACTION
  // ============================================================

  void _handleOtpButton() {
    if (_otpVerified) {
      _loginAfterOtpVerification();
    } else {
      _sendOtp();
    }
  }

  // ============================================================
  // ERROR MESSAGE
  // ============================================================

  void _showError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  // ============================================================
  // INFO MESSAGE
  // ============================================================

  void _showInfo(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  // ============================================================
  // SUCCESS MESSAGE
  // ============================================================

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.fixed,
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 30,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 460,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),

                  const SizedBox(height: 35),

                  _buildLoginCard(size),

                  const SizedBox(height: 24),

                  _buildRegisterSection(),

                  const SizedBox(height: 20),

                  _buildFooter(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 78,
          height: 78,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.secondary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    AppColors.primary.withOpacity(0.25),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(
            Icons.directions_car_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),

        const SizedBox(height: 20),

        Text(
          "Driver Safety AI",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          "AI-powered driver monitoring system",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.white.withOpacity(0.60),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LOGIN CARD
  // ============================================================

  Widget _buildLoginCard(Size size) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.surface,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.stretch,
        children: [
          Text(
            "Welcome Back",
            style: GoogleFonts.poppins(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            "Sign in to continue to your dashboard",
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.white.withOpacity(0.55),
            ),
          ),

          const SizedBox(height: 28),

          // ======================================================
          // USER ID / PHONE NUMBER
          // ======================================================

          _buildLabel(
            "User ID / Phone Number",
          ),

          const SizedBox(height: 8),

          TextField(
            controller: _identifierController,
            keyboardType: TextInputType.text,
            enabled: !_otpVerified,
            textInputAction:
                _loginWithPassword
                    ? TextInputAction.next
                    : TextInputAction.done,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText:
                  "Account ID / phone number",
              hintStyle: GoogleFonts.poppins(
                color:
                    Colors.white.withOpacity(0.35),
                fontSize: 13,
              ),
              prefixIcon: const Icon(
                Icons.person_outline_rounded,
                color: AppColors.primary,
              ),
              filled: true,
              fillColor:
                  AppColors.background2,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: AppColors.surface
                      .withOpacity(0.7),
                ),
              ),
              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(14),
                borderSide:
                    const BorderSide(
                  color: AppColors.primary,
                  width: 1.2,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ======================================================
          // LOGIN METHOD
          // ======================================================

          _buildLabel(
            "Login Method *",
          ),

          const SizedBox(height: 8),

          _buildLoginMethodSelector(),

          const SizedBox(height: 20),

          // ======================================================
          // PASSWORD OR OTP
          // ======================================================

          if (_loginWithPassword)
            _buildPasswordSection()
          else
            _buildOtpSection(),

          // ======================================================
          // REMEMBER + FORGOT PASSWORD
          // ======================================================

          if (_loginWithPassword) ...[
            const SizedBox(height: 15),

            _buildRememberForgotRow(),
          ],

          const SizedBox(height: 24),

          // ======================================================
          // LOGIN / SEND OTP BUTTON
          // ======================================================

          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (_loginWithPassword
                      ? _login
                      : _handleOtpButton),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    _otpVerified
                        ? AppColors.success
                        : AppColors.primary,
                disabledBackgroundColor:
                    AppColors.primary
                        .withOpacity(0.45),
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 23,
                      height: 23,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor:
                            AlwaysStoppedAnimation<
                                Color>(
                          Colors.white,
                        ),
                      ),
                    )
                  : Text(
                      _loginWithPassword
                          ? "Login"
                          : (_otpVerified
                              ? "Login"
                              : "Send OTP"),
                      style:
                          GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 22),

          // ======================================================
          // OR
          // ======================================================

          Row(
            children: [
              Expanded(
                child: Divider(
                  color:
                      Colors.white.withOpacity(0.12),
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 14,
                ),
                child: Text(
                  "OR",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        Colors.white.withOpacity(
                      0.35,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: Divider(
                  color:
                      Colors.white.withOpacity(0.12),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ======================================================
          // SOCIAL LOGIN
          // ======================================================

          _buildSocialButton(
            icon: Icons.g_mobiledata_rounded,
            label: "Continue with Google",
          ),

          const SizedBox(height: 10),

          _buildSocialButton(
            icon: Icons.apple,
            label: "Continue with Apple",
          ),

          const SizedBox(height: 10),

          _buildSocialButton(
            icon: Icons.window_rounded,
            label: "Continue with Microsoft",
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOGIN METHOD SELECTOR
  // ============================================================

  Widget _buildLoginMethodSelector() {
    return Container(
      height: 66,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.background2,
        borderRadius:
            BorderRadius.circular(17),
        border: Border.all(
          color:
              AppColors.surface.withOpacity(0.8),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _loginWithPassword =
                            true;

                        _otpController.clear();

                        _otpSent = false;
                        _otpVerified = false;
                      });
                    },
              child: AnimatedContainer(
                duration:
                    const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: _loginWithPassword
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 21,
                      color:
                          _loginWithPassword
                              ? Colors.black
                              : Colors.white
                                  .withOpacity(
                                  0.65,
                                ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "By Password",
                      style:
                          GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            _loginWithPassword
                                ? Colors.black
                                : Colors.white
                                    .withOpacity(
                                    0.65,
                                  ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: GestureDetector(
              onTap: _isLoading
                  ? null
                  : () {
                      setState(() {
                        _loginWithPassword =
                            false;

                        _passwordController
                            .clear();

                        _otpSent = false;
                        _otpVerified = false;
                        _otpController.clear();
                      });
                    },
              child: AnimatedContainer(
                duration:
                    const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: !_loginWithPassword
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius:
                      BorderRadius.circular(13),
                ),
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.sms_outlined,
                      size: 21,
                      color:
                          !_loginWithPassword
                              ? Colors.black
                              : Colors.white
                                  .withOpacity(
                                  0.65,
                                ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "By OTP",
                      style:
                          GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w600,
                        color:
                            !_loginWithPassword
                                ? Colors.black
                                : Colors.white
                                    .withOpacity(
                                    0.65,
                                  ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PASSWORD SECTION
  // ============================================================

  Widget _buildPasswordSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        _buildLabel("Password"),

        const SizedBox(height: 8),

        TextField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          textInputAction:
              TextInputAction.done,
          onSubmitted: (_) => _login(),
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            hintText:
                "Enter your password",
            hintStyle: GoogleFonts.poppins(
              color:
                  Colors.white.withOpacity(
                0.35,
              ),
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.lock_outline_rounded,
              color: AppColors.primary,
            ),
            suffixIcon: IconButton(
              onPressed: () {
                setState(() {
                  _obscurePassword =
                      !_obscurePassword;
                });
              },
              icon: Icon(
                _obscurePassword
                    ? Icons
                        .visibility_off_outlined
                    : Icons
                        .visibility_outlined,
                color:
                    Colors.white.withOpacity(
                  0.55,
                ),
              ),
            ),
            filled: true,
            fillColor:
                AppColors.background2,
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.surface
                    .withOpacity(0.7),
              ),
            ),
            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide:
                  const BorderSide(
                color: AppColors.primary,
                width: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // OTP SECTION
  // ============================================================

  Widget _buildOtpSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.stretch,
      children: [
        _buildLabel("OTP"),

        const SizedBox(height: 8),

        TextField(
          controller: _otpController,
          keyboardType:
              TextInputType.number,
          maxLength: 6,
          enabled: !_otpVerified,
          textInputAction:
              TextInputAction.done,
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 14,
            letterSpacing: 3,
          ),
          decoration: InputDecoration(
            counterText: "",
            hintText:
                "Enter verification OTP",
            hintStyle: GoogleFonts.poppins(
              color:
                  Colors.white.withOpacity(
                0.35,
              ),
              fontSize: 13,
              letterSpacing: 0,
            ),
            prefixIcon: Icon(
              _otpVerified
                  ? Icons.verified_rounded
                  : Icons.sms_outlined,
              color: _otpVerified
                  ? AppColors.success
                  : AppColors.primary,
            ),
            filled: true,
            fillColor:
                AppColors.background2,
            border: OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide: BorderSide(
                color: _otpVerified
                    ? AppColors.success
                    : AppColors.surface
                        .withOpacity(0.7),
              ),
            ),
            disabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide: BorderSide(
                color: AppColors.success
                    .withOpacity(0.7),
              ),
            ),
            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(14),
              borderSide:
                  const BorderSide(
                color: AppColors.primary,
                width: 1.2,
              ),
            ),
          ),
        ),

        const SizedBox(height: 8),

        // ========================================================
        // OTP STATUS MESSAGE
        // ========================================================

        if (_otpVerified)
          Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "OTP verified successfully.",
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: AppColors.success,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          )
        else
          Text(
            "A 6-digit OTP will be sent to your registered email address.",
            style: GoogleFonts.poppins(
              fontSize: 11,
              color:
                  Colors.white.withOpacity(
                0.50,
              ),
            ),
          ),

        // ========================================================
        // VERIFY OTP
        // ========================================================

        const SizedBox(height: 10),

        if (!_otpVerified)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed:
                  _isLoading
                      ? null
                      : _verifyOtp,
              child: Text(
                "Verify OTP",
                style:
                    GoogleFonts.poppins(
                  color:
                      AppColors.primary,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // REMEMBER ME + FORGOT PASSWORD
  // ============================================================

  Widget _buildRememberForgotRow() {
    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: _rememberMe,
            onChanged: _isLoading
                ? null
                : (value) async {
                    final bool checked =
                        value ?? false;

                    setState(() {
                      _rememberMe = checked;
                    });

                    if (checked) {
                      final identifier =
                          _identifierController
                              .text
                              .trim();

                      if (identifier.isNotEmpty) {
                        await _saveRememberedLogin(
                          identifier,
                        );
                      } else {
                        final prefs =
                            await SharedPreferences
                                .getInstance();

                        await prefs.setBool(
                          _rememberMeKey,
                          true,
                        );
                      }
                    } else {
                      await _clearRememberedLogin();
                    }
                  },
            activeColor:
                AppColors.primary,
            checkColor: Colors.black,
            side: BorderSide(
              color:
                  Colors.white.withOpacity(
                0.4,
              ),
            ),
          ),
        ),

        const SizedBox(width: 8),

        GestureDetector(
          onTap: _isLoading
              ? null
              : () async {
                  final bool checked =
                      !_rememberMe;

                  setState(() {
                    _rememberMe = checked;
                  });

                  if (checked) {
                    final identifier =
                        _identifierController
                            .text
                            .trim();

                    if (identifier.isNotEmpty) {
                      await _saveRememberedLogin(
                        identifier,
                      );
                    } else {
                      final prefs =
                          await SharedPreferences
                              .getInstance();

                      await prefs.setBool(
                        _rememberMeKey,
                        true,
                      );
                    }
                  } else {
                    await _clearRememberedLogin();
                  }
                },
          child: Text(
            "Remember me",
            style: GoogleFonts.poppins(
              color:
                  Colors.white.withOpacity(
                0.65,
              ),
              fontSize: 12,
            ),
          ),
        ),

        const Spacer(),

        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const ForgotPasswordScreen(),
              ),
            );
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize:
                MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            "Forgot Password?",
            style: GoogleFonts.poppins(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LABEL
  // ============================================================

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color:
            Colors.white.withOpacity(0.75),
      ),
    );
  }

  // ============================================================
  // SOCIAL BUTTON
  // ============================================================

  Widget _buildSocialButton({
    required IconData icon,
    required String label,
  }) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: () {
          _showError(
            "Social login is not available yet.",
          );
        },
        icon: Icon(
          icon,
          color:
              Colors.white.withOpacity(0.8),
          size: 21,
        ),
        label: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color:
                Colors.white.withOpacity(
              0.75,
            ),
          ),
        ),
        style:
            OutlinedButton.styleFrom(
          side: BorderSide(
            color: AppColors.surface
                .withOpacity(0.8),
          ),
          backgroundColor:
              AppColors.background2,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Widget _buildRegisterSection() {
    return Column(
      children: [
        Text(
          "Don't have an account?",
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            color:
                Colors.white.withOpacity(
              0.55,
            ),
          ),
        ),

        const SizedBox(height: 8),

        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    const RegisterScreen(),
              ),
            );
          },
          child: Text(
            "Create an Account",
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight:
                  FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // FOOTER
  // ============================================================

  Widget _buildFooter() {
    return Column(
      children: [
        Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.security_rounded,
              size: 15,
              color: AppColors.success
                  .withOpacity(0.8),
            ),

            const SizedBox(width: 6),

            Text(
              "Your data is secure and protected",
              style: GoogleFonts.poppins(
                fontSize: 10.5,
                color:
                    Colors.white.withOpacity(
                  0.4,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Text(
          "Driver Safety AI • Secure Monitoring System",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 9.5,
            color:
                Colors.white.withOpacity(
              0.25,
            ),
          ),
        ),
      ],
    );
  }
}