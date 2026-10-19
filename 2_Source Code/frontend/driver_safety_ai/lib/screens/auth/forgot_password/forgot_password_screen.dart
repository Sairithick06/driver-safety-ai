import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/app_colors.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController =
      TextEditingController();

  static const String baseUrl = "http://192.168.31.55:8000";

  bool _isLoading = false;
  bool _emailSent = false;

  int _resendSeconds = 0;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // ==========================================================
  // SHOW MESSAGE
  // ==========================================================

  void _showMessage(
    String message, {
    bool success = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor:
            success ? Colors.green : Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ==========================================================
  // EMAIL VALIDATION
  // ==========================================================

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    return emailRegex.hasMatch(email);
  }

  // ==========================================================
  // SEND RESET LINK
  // ==========================================================

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim().toLowerCase();

    if (email.isEmpty) {
      _showMessage(
        "Please enter your registered email address.",
      );
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage(
        "Please enter a valid email address.",
      );
      return;
    }

    if (_resendSeconds > 0) {
      _showMessage(
        "Please wait $_resendSeconds seconds before requesting another link.",
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/forgot-password"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "email": email,
        }),
      );

      debugPrint(
        "FORGOT PASSWORD STATUS: ${response.statusCode}",
      );

      debugPrint(
        "FORGOT PASSWORD RESPONSE: ${response.body}",
      );

      Map<String, dynamic> data = {};

      try {
        data = jsonDecode(response.body);
      } catch (_) {
        data = {};
      }

      if (!mounted) return;

      if (response.statusCode == 200 &&
          data["success"] == true) {
        setState(() {
          _emailSent = true;
        });

        _startResendCooldown();

        _showMessage(
          "Reset link sent to your email.",
          success: true,
        );
      } else {
        _showMessage(
          data["message"]?.toString() ??
              "Unable to send reset link.",
        );
      }
    } catch (e) {
      debugPrint(
        "FORGOT PASSWORD ERROR: $e",
      );

      if (!mounted) return;

      _showMessage(
        "Unable to connect to the server.",
      );
    } finally {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  // ==========================================================
  // RESEND COOLDOWN
  // ==========================================================

  void _startResendCooldown() {
    setState(() {
      _resendSeconds = 60;
    });

    Future.doWhile(() async {
      await Future.delayed(
        const Duration(seconds: 1),
      );

      if (!mounted) return false;

      if (_resendSeconds <= 1) {
        setState(() {
          _resendSeconds = 0;
        });

        return false;
      }

      setState(() {
        _resendSeconds--;
      });

      return true;
    });
  }

  // ==========================================================
  // INPUT DECORATION
  // ==========================================================

  InputDecoration _inputDecoration() {
    return InputDecoration(
      hintText: "Enter your registered email",
      hintStyle: GoogleFonts.poppins(
        color: Colors.white54,
        fontSize: 14,
      ),
      prefixIcon: const Icon(
        Icons.email_outlined,
        color: Colors.cyanAccent,
      ),
      filled: true,
      fillColor: const Color(0xFF293A54),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 18,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Colors.cyanAccent,
          width: 1.5,
        ),
      ),
    );
  }

  // ==========================================================
  // BUILD
  // ==========================================================

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
                horizontal: 20,
                vertical: 30,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 500,
                ),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                    30,
                    25,
                    30,
                    30,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2A41),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.08),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 15),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      // ==================================================
                      // BACK BUTTON
                      // ==================================================

                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ==================================================
                      // ICON
                      // ==================================================

                      Center(
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF00C2FF),
                                Color(0xFF4F8CFF),
                              ],
                            ),
                          ),
                          child: const Icon(
                            Icons.lock_reset,
                            color: Colors.white,
                            size: 48,
                          ),
                        ),
                      ),

                      const SizedBox(height: 25),

                      // ==================================================
                      // TITLE
                      // ==================================================

                      Center(
                        child: Text(
                          "Forgot Password?",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ==================================================
                      // DESCRIPTION
                      // ==================================================

                      Center(
                        child: Text(
                          "Enter the email address associated with your account. We'll send you a secure link to reset your password.",
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            height: 1.6,
                            color: Colors.white60,
                          ),
                        ),
                      ),

                      const SizedBox(height: 35),

                      // ==================================================
                      // EMAIL LABEL
                      // ==================================================

                      Text(
                        "Registered Email Address",
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),

                      const SizedBox(height: 10),

                      // ==================================================
                      // EMAIL FIELD
                      // ==================================================

                      TextField(
                        controller: _emailController,
                        enabled: !_isLoading,
                        keyboardType:
                            TextInputType.emailAddress,
                        textInputAction:
                            TextInputAction.done,
                        autocorrect: false,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                        ),
                        onSubmitted: (_) {
                          if (!_isLoading) {
                            _sendResetLink();
                          }
                        },
                        decoration: _inputDecoration(),
                      ),

                      const SizedBox(height: 25),

                      // ==================================================
                      // SEND BUTTON
                      // ==================================================

                      SizedBox(
                        width: double.infinity,
                        height: 58,
                        child: ElevatedButton(
                          onPressed:
                              _isLoading
                                  ? null
                                  : _sendResetLink,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.cyanAccent,
                            foregroundColor: Colors.black,
                            disabledBackgroundColor:
                                Colors.cyanAccent
                                    .withOpacity(0.5),
                            shape:
                                RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(15),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 25,
                                  height: 25,
                                  child:
                                      CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.black,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Send Reset Link",
                                      style:
                                          GoogleFonts.poppins(
                                        fontSize: 16,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(
                                      Icons.send_outlined,
                                    ),
                                  ],
                                ),
                        ),
                      ),

                      // ==================================================
                      // EMAIL SENT MESSAGE
                      // ==================================================

                      if (_emailSent) ...[
                        const SizedBox(height: 20),

                        Container(
                          width: double.infinity,
                          padding:
                              const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green
                                .withOpacity(0.10),
                            borderRadius:
                                BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.green
                                  .withOpacity(0.30),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.mark_email_read_outlined,
                                color: Colors.greenAccent,
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Check your email",
                                      style:
                                          GoogleFonts.poppins(
                                        color:
                                            Colors.white,
                                        fontSize: 14,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "If an account exists with this email, a password reset link has been sent.",
                                      style:
                                          GoogleFonts.poppins(
                                        color:
                                            Colors.white60,
                                        fontSize: 12,
                                        height: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 15),

                        // RESEND
                        Center(
                          child: TextButton(
                            onPressed:
                                _resendSeconds > 0 ||
                                        _isLoading
                                    ? null
                                    : _sendResetLink,
                            child: Text(
                              _resendSeconds > 0
                                  ? "Resend link in $_resendSeconds seconds"
                                  : "Resend Reset Link",
                              style: GoogleFonts.poppins(
                                color: _resendSeconds > 0
                                    ? Colors.white38
                                    : Colors.cyanAccent,
                                fontSize: 13,
                                fontWeight:
                                    FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 15),

                      // ==================================================
                      // BACK TO LOGIN
                      // ==================================================

                      Center(
                        child: TextButton.icon(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  Navigator.pop(
                                    context,
                                  );
                                },
                          icon: Icon(
                            Icons.arrow_back,
                            color: _isLoading
                                ? Colors.white38
                                : Colors.cyanAccent,
                            size: 18,
                          ),
                          label: Text(
                            "Back to Login",
                            style: GoogleFonts.poppins(
                              color: _isLoading
                                  ? Colors.white38
                                  : Colors.cyanAccent,
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // ==================================================
                      // SECURITY INFORMATION
                      // ==================================================

                      Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: const Color(0xFF173650),
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.cyanAccent
                                .withOpacity(0.15),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.shield_outlined,
                              color: Colors.cyanAccent,
                              size: 21,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "For your security, we never send passwords by email. The reset link will expire and can only be used to create a new password.",
                                style:
                                    GoogleFonts.poppins(
                                  color: Colors.white60,
                                  fontSize: 12,
                                  height: 1.5,
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
}