import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../../core/theme/app_colors.dart';
import '../../../widgets/app_logo.dart';
import '../login/login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _fullNameController =
      TextEditingController();

  final TextEditingController _emailController =
      TextEditingController();

  final TextEditingController _phoneController =
      TextEditingController();

  final TextEditingController _passwordController =
      TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final TextEditingController _drivingLicenceController =
      TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  bool _termsAccepted = false;

  bool _isLoading = false;

  Timer? _adminApprovalTimer;
  bool _adminApprovalChecking = false;
  String? _pendingAdminEmail;

  // user / admin
  String _accountType = "user";

  // ============================================================
  // BACKEND URL
  // ============================================================

  static const String baseUrl = "http:/192.168.31.558000";

  // ============================================================
  // PASSWORD VALIDATION
  // ============================================================

  bool _isPasswordValid(String password) {
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[^A-Za-z0-9]').hasMatch(password);
  }

  // ============================================================
  // REGISTER
  // ============================================================

  Future<void> _register() async {
    FocusScope.of(context).unfocus();

    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final drivingLicence =
        _drivingLicenceController.text.trim();

    // ----------------------------------------------------------
    // FULL NAME
    // ----------------------------------------------------------

    if (fullName.isEmpty) {
      _showMessage(
        "Please enter your full name.",
        isError: true,
      );
      return;
    }

    // ----------------------------------------------------------
    // EMAIL
    // ----------------------------------------------------------

    if (email.isEmpty) {
      _showMessage(
        "Please enter your email address.",
        isError: true,
      );
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage(
        "Please enter a valid email address.",
        isError: true,
      );
      return;
    }

    // ----------------------------------------------------------
    // PHONE
    // ----------------------------------------------------------

    if (phone.isEmpty) {
      _showMessage(
        "Please enter your phone number.",
        isError: true,
      );
      return;
    }

    final cleanedPhone =
        phone.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    if (!RegExp(r'^(?:\+91)?[6-9]\d{9}$')
        .hasMatch(cleanedPhone)) {
      _showMessage(
        "Please enter a valid Indian phone number.",
        isError: true,
      );
      return;
    }

    // ----------------------------------------------------------
    // PASSWORD
    // ----------------------------------------------------------

    if (password.isEmpty) {
      _showMessage(
        "Please create a password.",
        isError: true,
      );
      return;
    }

    if (!_isPasswordValid(password)) {
      _showMessage(
        "Password must contain 8+ characters, uppercase, lowercase, number and special character.",
        isError: true,
      );
      return;
    }

    // ----------------------------------------------------------
    // CONFIRM PASSWORD
    // ----------------------------------------------------------

    if (confirmPassword.isEmpty) {
      _showMessage(
        "Please confirm your password.",
        isError: true,
      );
      return;
    }

    if (password != confirmPassword) {
      _showMessage(
        "Passwords do not match.",
        isError: true,
      );
      return;
    }

    // ----------------------------------------------------------
    // ACCOUNT TYPE
    // ----------------------------------------------------------

    if (_accountType != "user" &&
        _accountType != "admin") {
      _showMessage(
        "Please select an account type.",
        isError: true,
      );
      return;
    }

    // ----------------------------------------------------------
    // TERMS
    // ----------------------------------------------------------

    if (!_termsAccepted) {
      _showMessage(
        "Please agree to the Terms of Service and Privacy Policy.",
        isError: true,
      );
      return;
    }

    // ----------------------------------------------------------
    // START LOADING
    // ----------------------------------------------------------

    setState(() {
      _isLoading = true;
    });

    try {
      // --------------------------------------------------------
      // SEND DATA TO FASTAPI
      // --------------------------------------------------------

      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "full_name": fullName,
          "email": email,
          "phone": cleanedPhone,
          "password": password,
          "driving_licence":
              drivingLicence.isEmpty
                  ? null
                  : drivingLicence,

          "account_type": _accountType,

        }),
      );

      // --------------------------------------------------------
      // DECODE RESPONSE
      // --------------------------------------------------------

      final data = jsonDecode(response.body);

      if (!mounted) return;

      // --------------------------------------------------------
      // SUCCESS
      // --------------------------------------------------------

      if (response.statusCode == 200 &&
          data["success"] == true) {

        final String role =
            data["role"]?.toString() ??
                _accountType;

        // --------------------------------------------------------
        // ADMIN: WAIT FOR MAIN ADMIN APPROVAL
        // --------------------------------------------------------

        if (role.toLowerCase() == "admin" &&
            (data["admin_status"]?.toString().toLowerCase() == "pending" ||
                data["pending_approval"] == true)) {
          await _showAdminApprovalPending(
            email: email,
          );

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            ),
          );

          return;
        }

        // --------------------------------------------------------
        // USER: ACCOUNT ID IS GENERATED IMMEDIATELY
        // --------------------------------------------------------

        final String accountId =
            data["driver_id"]?.toString() ??
                data["account_id"]?.toString() ??
                "";

        if (accountId.isEmpty) {
          _showMessage(
            "Account created, but the Account ID was not received from the server.",
            isError: true,
          );
          return;
        }

        await _showRegistrationSuccess(
          accountId: accountId,
          role: role,
        );

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(),
          ),
        );
      }

      // --------------------------------------------------------
      // BACKEND ERROR
      // --------------------------------------------------------

      else {
        _showMessage(
          data["message"] ??
              "Registration failed.",
          isError: true,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        "Unable to connect to the backend. Make sure FastAPI is running.",
        isError: true,
      );

      debugPrint(
        "REGISTER CONNECTION ERROR: $e",
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // REGISTRATION SUCCESS DIALOG
  // ============================================================

  Future<void> _showAdminApprovalPending({
    required String email,
  }) async {
    _pendingAdminEmail = email;

    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            Future<void> checkApprovalStatus() async {
              if (_adminApprovalChecking) return;

              _adminApprovalChecking = true;

              try {
                final response = await http.get(
                  Uri.parse(
                    '$baseUrl/admin-approval-status?email=${Uri.encodeComponent(email)}',
                  ),
                );

                if (!mounted) return;

                if (response.statusCode != 200) {
                  return;
                }

                final data = jsonDecode(response.body);

                if (data["success"] != true) {
                  return;
                }

                final status =
                    data["admin_status"]?.toString().toLowerCase() ??
                        "pending";

                if (status == "approved") {
                  _adminApprovalTimer?.cancel();

                  final accountId =
                      data["account_id"]?.toString() ??
                          data["driver_id"]?.toString() ??
                          "";

                  setDialogState(() {
                    _adminApprovalChecking = false;
                  });

                  await _showAdminApprovalSuccessful(
                    dialogContext: dialogContext,
                    accountId: accountId,
                  );

                  return;
                }

                if (status == "rejected") {
                  _adminApprovalTimer?.cancel();

                  setDialogState(() {
                    _adminApprovalChecking = false;
                  });

                  await _showAdminApprovalRejected(
                    dialogContext: dialogContext,
                  );

                  return;
                }

                setDialogState(() {
                  _adminApprovalChecking = false;
                });
              } catch (e) {
                debugPrint(
                  "ADMIN APPROVAL STATUS CHECK ERROR: $e",
                );

                if (mounted) {
                  setDialogState(() {
                    _adminApprovalChecking = false;
                  });
                }
              }
            }

            // Start checking shortly after the dialog opens.
            if (_adminApprovalTimer == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                await checkApprovalStatus();

                if (!mounted) return;

                _adminApprovalTimer ??= Timer.periodic(
                  const Duration(seconds: 5),
                  (_) {
                    checkApprovalStatus();
                  },
                );
              });
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF1B2A41),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              titlePadding: const EdgeInsets.fromLTRB(
                24,
                20,
                10,
                0,
              ),
              title: Row(
                children: [
                  const Icon(
                    Icons.hourglass_top_rounded,
                    color: Colors.orangeAccent,
                    size: 30,
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "Approval Pending",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  // ------------------------------------------------
                  // CLOSE X BUTTON
                  // ------------------------------------------------

                  IconButton(
                    tooltip: "Close",
                    onPressed: () {
                      _adminApprovalTimer?.cancel();
                      _adminApprovalTimer = null;
                      _pendingAdminEmail = null;

                      Navigator.pop(dialogContext);
                    },
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white70,
                      size: 25,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Your Admin registration request has been submitted successfully.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "The Main Admin has been notified by email. "
                    "After approval, your official Admin Account ID will be generated "
                    "and sent to your registered email address.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "You cannot log in as Admin until the request is approved.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_adminApprovalChecking)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.cyanAccent,
                          ),
                        ),
                      if (_adminApprovalChecking)
                        const SizedBox(width: 10),
                      Text(
                        "Checking approval status...",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.55),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actionsPadding: const EdgeInsets.fromLTRB(
                24,
                0,
                24,
                20,
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _adminApprovalTimer?.cancel();
                      _adminApprovalTimer = null;
                      _pendingAdminEmail = null;

                      Navigator.pop(dialogContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyan,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Continue to Login",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      _adminApprovalTimer?.cancel();
      _adminApprovalTimer = null;
      _pendingAdminEmail = null;
    });
  }

  Future<void> _showAdminApprovalSuccessful({
    required BuildContext dialogContext,
    required String accountId,
  }) async {
    await showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (successContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B2A41),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(
            24,
            20,
            10,
            0,
          ),
          title: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.greenAccent,
                size: 30,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Approval Successful",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: "Close",
                onPressed: () {
                  Navigator.pop(successContext);
                },
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white70,
                  size: 25,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Your Admin registration has been approved successfully by the Main Admin.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              if (accountId.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  "Your Admin Account ID",
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF16354F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.greenAccent.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          accountId,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.cyanAccent,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: "Copy Admin Account ID",
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: accountId),
                          );

                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                "Admin Account ID copied!",
                              ),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.copy_rounded,
                          color: Colors.cyanAccent,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Text(
                "You can now log in using your Admin Account ID or registered phone number.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            24,
            0,
            24,
            20,
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(successContext);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Continue to Login",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (mounted) {
      Navigator.pop(dialogContext);
    }
  }

  Future<void> _showAdminApprovalRejected({
    required BuildContext dialogContext,
  }) async {
    await showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (rejectedContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B2A41),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.cancel_rounded,
                color: Colors.redAccent,
                size: 30,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "Admin Request Rejected",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: "Close",
                onPressed: () {
                  Navigator.pop(rejectedContext);
                },
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white70,
                  size: 25,
                ),
              ),
            ],
          ),
          content: const Text(
            "The Main Admin has rejected your Admin registration request. "
            "You can contact the Main Admin for more information.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(rejectedContext);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Continue to Login",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    if (mounted) {
      Navigator.pop(dialogContext);
    }
  }


  Future<void> _showRegistrationSuccess({
    required String accountId,
    required String role,
  }) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1B2A41),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.check_circle,
                color: Colors.greenAccent,
                size: 30,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Account Created",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                "Your account has been created successfully.",
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // ACCOUNT ID DISPLAY
              // ==================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF16354F),
                  borderRadius:
                      BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        Colors.cyan.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    const Text(
                      "YOUR ACCOUNT ID",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            accountId,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.cyanAccent,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: 'Copy Account ID',
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: accountId),
                            );

                            if (!context.mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Account ID copied!'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.copy_rounded,
                            color: Colors.cyanAccent,
                            size: 22,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Text(
                      "Account Type: ${role.toUpperCase()}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                "Please save your Account ID. You can use it or your registered phone number to log in.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.cyan,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "Continue to Login",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // EMAIL VALIDATION
  // ============================================================

  bool _isValidEmail(String email) {
    return RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    ).hasMatch(email);
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message, {
    required bool isError,
  }) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor:
            isError
                ? Colors.redAccent
                : Colors.green,
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _drivingLicenceController.dispose();

    _adminApprovalTimer?.cancel();
    _adminApprovalTimer = null;
    super.dispose();
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: AppColors.backgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 30,
              ),
              child: ConstrainedBox(
                constraints:
                    const BoxConstraints(
                  maxWidth: 500,
                ),
                child: Container(
                  padding:
                      const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFF1B2A41),
                    borderRadius:
                        BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white
                          .withOpacity(0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [

                      // ==================================================
                      // LOGO
                      // ==================================================

                      const Center(
                        child: AppLogo(
                          size: 85,
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ==================================================
                      // TITLE
                      // ==================================================

                      const Center(
                        child: Text(
                          "Create Account",
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight:
                                FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Center(
                        child: Text(
                          "Create your account to start your safe driving journey",
                          textAlign:
                              TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white60,
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ==================================================
                      // FULL NAME
                      // ==================================================

                      _buildLabel(
                        "Full Name",
                        true,
                      ),

                      const SizedBox(height: 8),

                      _buildTextField(
                        controller:
                            _fullNameController,
                        hintText:
                            "Enter your full name",
                        icon:
                            Icons.person_outline,
                        textInputType:
                            TextInputType.name,
                      ),

                      const SizedBox(height: 20),

                      // ==================================================
                      // EMAIL
                      // ==================================================

                      _buildLabel(
                        "Email Address",
                        true,
                      ),

                      const SizedBox(height: 8),

                      _buildTextField(
                        controller:
                            _emailController,
                        hintText:
                            "Enter your email",
                        icon:
                            Icons.email_outlined,
                        textInputType:
                            TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 20),

                      // ==================================================
                      // PHONE
                      // ==================================================

                      _buildLabel(
                        "Phone Number",
                        true,
                      ),

                      const SizedBox(height: 8),

                      _buildTextField(
                        controller:
                            _phoneController,
                        hintText:
                            "Enter your phone number",
                        icon:
                            Icons.phone_outlined,
                        textInputType:
                            TextInputType.phone,
                      ),

                      const SizedBox(height: 20),

                      // ==================================================
                      // DRIVING LICENCE
                      // ==================================================

                      Row(
                        children: const [
                          Text(
                            "Driving Licence",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 6),
                          Text(
                            "(Optional)",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      _buildTextField(
                        controller:
                            _drivingLicenceController,
                        hintText:
                            "Enter driving licence number",
                        icon:
                            Icons.badge_outlined,
                        textInputType:
                            TextInputType.text,
                      ),

                      const SizedBox(height: 20),

                      // ==================================================
                      // ACCOUNT TYPE
                      // ==================================================

                      _buildLabel(
                        "Account Type",
                        true,
                      ),

                      const SizedBox(height: 8),

                      _buildAccountTypeSelector(),

                      // ==================================================
                      // ADMIN APPROVAL INFORMATION
                      // ==================================================

                      if (_accountType ==
                          "admin") ...[
                        const SizedBox(height: 20),

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16354F),
                            borderRadius:
                                BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.orangeAccent
                                  .withOpacity(0.20),
                            ),
                          ),
                          child: const Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.admin_panel_settings_outlined,
                                color: Colors.orangeAccent,
                                size: 21,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "Admin registration requires approval from the Main Admin. "
                                  "Your Admin Account ID will be generated only after approval.",
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white70,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),

                      // ==================================================
                      // PASSWORD
                      // ==================================================

                      _buildLabel(
                        "Password",
                        true,
                      ),

                      const SizedBox(height: 8),

                      _buildTextField(
                        controller:
                            _passwordController,
                        hintText:
                            "Create a password",
                        icon:
                            Icons.lock_outline,
                        obscureText:
                            _obscurePassword,
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
                                    .visibility_outlined
                                : Icons
                                    .visibility_off_outlined,
                            color:
                                Colors.white54,
                          ),
                        ),
                        onChanged: (_) {
                          setState(() {});
                        },
                      ),

                      const SizedBox(height: 10),

                      // ==================================================
                      // PASSWORD REQUIREMENTS
                      // ==================================================

                      _buildPasswordRequirements(),

                      const SizedBox(height: 20),

                      // ==================================================
                      // CONFIRM PASSWORD
                      // ==================================================

                      _buildLabel(
                        "Confirm Password",
                        true,
                      ),

                      const SizedBox(height: 8),

                      _buildTextField(
                        controller:
                            _confirmPasswordController,
                        hintText:
                            "Confirm your password",
                        icon:
                            Icons.lock_reset_outlined,
                        obscureText:
                            _obscureConfirmPassword,
                        suffixIcon: IconButton(
                          onPressed: () {
                            setState(() {
                              _obscureConfirmPassword =
                                  !_obscureConfirmPassword;
                            });
                          },
                          icon: Icon(
                            _obscureConfirmPassword
                                ? Icons
                                    .visibility_outlined
                                : Icons
                                    .visibility_off_outlined,
                            color:
                                Colors.white54,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ==================================================
                      // TERMS
                      // ==================================================

                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value:
                                _termsAccepted,
                            onChanged: (value) {
                              setState(() {
                                _termsAccepted =
                                    value ?? false;
                              });
                            },
                            activeColor:
                                Colors.cyan,
                            checkColor:
                                Colors.black,
                            side:
                                const BorderSide(
                              color:
                                  Colors.white54,
                            ),
                          ),

                          const Expanded(
                            child: Padding(
                              padding:
                                  EdgeInsets.only(
                                top: 12,
                              ),
                              child: Text(
                                "I agree to the Terms of Service and Privacy Policy.",
                                style: TextStyle(
                                  fontSize: 13,
                                  color:
                                      Colors.white60,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ==================================================
                      // CREATE ACCOUNT BUTTON
                      // ==================================================

                      SizedBox(
                        width:
                            double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed:
                              _isLoading
                                  ? null
                                  : _register,
                          style:
                              ElevatedButton
                                  .styleFrom(
                            backgroundColor:
                                Colors.cyan,
                            foregroundColor:
                                Colors.black,
                            disabledBackgroundColor:
                                Colors.cyan
                                    .withOpacity(
                                  0.5,
                                ),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                14,
                              ),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth:
                                        2.5,
                                    color:
                                        Colors.black,
                                  ),
                                )
                              : const Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment
                                          .center,
                                  children: [
                                    Text(
                                      "Create Account",
                                      style:
                                          TextStyle(
                                        fontSize:
                                            16,
                                        fontWeight:
                                            FontWeight
                                                .w600,
                                      ),
                                    ),
                                    SizedBox(
                                      width: 10,
                                    ),
                                    Icon(
                                      Icons
                                          .arrow_forward,
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // ==================================================
                      // LOGIN
                      // ==================================================

                      Center(
                        child: Wrap(
                          alignment:
                              WrapAlignment.center,
                          children: [
                            const Text(
                              "Already have an account? ",
                              style: TextStyle(
                                color:
                                    Colors.white60,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator
                                    .pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const LoginScreen(),
                                  ),
                                );
                              },
                              child: const Text(
                                "Login",
                                style:
                                    TextStyle(
                                  color:
                                      Colors.cyan,
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ==================================================
                      // SECURITY MESSAGE
                      // ==================================================

                      Container(
                        width:
                            double.infinity,
                        padding:
                            const EdgeInsets.all(
                          14,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFF16354F,
                          ),
                          borderRadius:
                              BorderRadius.circular(
                            12,
                          ),
                          border: Border.all(
                            color: Colors.cyan
                                .withOpacity(0.15),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons
                                  .security_outlined,
                              color:
                                  Colors.cyan,
                              size: 20,
                            ),
                            SizedBox(
                              width: 10,
                            ),
                            Expanded(
                              child: Text(
                                "Your driving safety data is protected.",
                                style:
                                    TextStyle(
                                  fontSize: 12,
                                  color:
                                      Colors.white60,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ACCOUNT TYPE SELECTOR
  // ============================================================

  Widget _buildAccountTypeSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFF2A3A52),
        borderRadius:
            BorderRadius.circular(14),
        border: Border.all(
          color:
              Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildAccountTypeOption(
              title: "User",
              icon:
                  Icons.person_outline,
              value: "user",
            ),
          ),
          Expanded(
            child: _buildAccountTypeOption(
              title: "Admin",
              icon: Icons
                  .admin_panel_settings_outlined,
              value: "admin",
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACCOUNT TYPE OPTION
  // ============================================================

  Widget _buildAccountTypeOption({
    required String title,
    required IconData icon,
    required String value,
  }) {
    final bool selected =
        _accountType == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _accountType = value;
        });
      },
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(
          vertical: 13,
          horizontal: 10,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Colors.cyan
              : Colors.transparent,
          borderRadius:
              BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: selected
                  ? Colors.black
                  : Colors.white60,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: selected
                    ? Colors.black
                    : Colors.white70,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LABEL
  // ============================================================

  Widget _buildLabel(
    String text,
    bool required,
  ) {
    return Row(
      children: [
        Text(
          text,
          style: const TextStyle(
            fontSize: 15,
            fontWeight:
                FontWeight.w600,
            color: Colors.white,
          ),
        ),
        if (required)
          const Text(
            " *",
            style: TextStyle(
              color:
                  Colors.redAccent,
            ),
          ),
      ],
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType? textInputType,
    bool obscureText = false,
    Widget? suffixIcon,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: textInputType,
      obscureText: obscureText,
      onChanged: onChanged,
      style: const TextStyle(
        color: Colors.white,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: Colors.white54,
        ),
        prefixIcon: Icon(
          icon,
          color: Colors.cyan,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor:
            const Color(0xFF2A3A52),
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide:
              BorderSide.none,
        ),
        enabledBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide: BorderSide(
            color: Colors.white
                .withOpacity(0.08),
          ),
        ),
        focusedBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(14),
          borderSide:
              const BorderSide(
            color: Colors.cyan,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PASSWORD REQUIREMENTS UI
  // ============================================================

  Widget _buildPasswordRequirements() {
    final password =
        _passwordController.text;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          "Password must contain:",
          style: TextStyle(
            fontSize: 12,
            color: Colors.white54,
          ),
        ),

        const SizedBox(height: 6),

        _requirement(
          "At least 8 characters",
          password.length >= 8,
        ),

        _requirement(
          "One uppercase letter",
          RegExp(r'[A-Z]')
              .hasMatch(password),
        ),

        _requirement(
          "One lowercase letter",
          RegExp(r'[a-z]')
              .hasMatch(password),
        ),

        _requirement(
          "One number",
          RegExp(r'[0-9]')
              .hasMatch(password),
        ),

        _requirement(
          "One special character",
          RegExp(r'[^A-Za-z0-9]')
              .hasMatch(password),
        ),
      ],
    );
  }

  // ============================================================
  // PASSWORD REQUIREMENT ITEM
  // ============================================================

  Widget _requirement(
    String text,
    bool valid,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        top: 3,
      ),
      child: Row(
        children: [
          Icon(
            valid
                ? Icons.check_circle
                : Icons.circle_outlined,
            size: 15,
            color: valid
                ? Colors.greenAccent
                : Colors.white38,
          ),
          const SizedBox(width: 7),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: valid
                  ? Colors.greenAccent
                  : Colors.white54,
            ),
          ),
        ],
      ),
    );
  }
}