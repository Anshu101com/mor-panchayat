import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class VillagerForgotPasswordPage extends StatefulWidget {
  final bool isHindi;

  const VillagerForgotPasswordPage({super.key, this.isHindi = false});

  @override
  State<VillagerForgotPasswordPage> createState() =>
      _VillagerForgotPasswordPageState();
}

class _VillagerForgotPasswordPageState
    extends State<VillagerForgotPasswordPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _mobileController = TextEditingController();

  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _fatherNameController = TextEditingController();

  final TextEditingController _dobController = TextEditingController();

  final TextEditingController _otpController = TextEditingController();

  final TextEditingController _newPasswordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  Timer? _resendTimer;

  bool _isLoading = false;
  bool _detailsVerified = false;
  bool _otpVerified = false;

  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  int _currentStep = 0;
  int _resendSeconds = 0;

  String? _challengeId;

  // ============================================================
  // TRANSLATION
  // ============================================================

  String _t(String english, String hindi) {
    return widget.isHindi ? hindi : english;
  }

  // ============================================================
  // VERIFY VILLAGER DETAILS
  // ============================================================

  Future<void> _verifyDetails() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final mobile = _mobileController.text.trim();
    final name = _nameController.text.trim();
    final fatherName = _fatherNameController.text.trim();
    final dateOfBirth = _dobController.text.trim();

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase.functions.invoke(
        'villager-forgot-password',
        body: {
          'action': 'verify_details',
          'mobile': mobile,
          'name': name,
          'father_name': fatherName,
          'date_of_birth': dateOfBirth,
        },
      );

      final data = _normalizeResponse(response.data);

      debugPrint('==========================================');
      debugPrint('FORGOT PASSWORD VERIFY RESPONSE');
      debugPrint('$data');
      debugPrint('==========================================');

      if (data['success'] != true) {
        throw Exception(data['message']?.toString() ?? 'Details do not match.');
      }

      final challengeId = data['challenge_id']?.toString();

      if (challengeId == null || challengeId.isEmpty) {
        throw Exception('Recovery challenge was not created.');
      }

      _challengeId = challengeId;

      if (!mounted) return;

      setState(() {
        _detailsVerified = true;
        _currentStep = 1;
        _resendSeconds = 30;
      });

      _startResendTimer();

      // In-app OTP
      final otp = data['otp']?.toString() ?? '';

      if (otp.isNotEmpty) {
        await _showOtpNotification(otp);
      } else {
        _showSuccess(
          _t('OTP generated successfully.', 'OTP सफलतापूर्वक बनाया गया।'),
        );
      }
    } on FunctionException catch (e) {
      debugPrint('FunctionException: ${e.status} ${e.details}');

      if (!mounted) return;

      String message = _t(
        'Unable to verify your details.',
        'आपकी जानकारी सत्यापित नहीं हो सकी।',
      );

      final details = e.details;

      if (details is Map) {
        final serverMessage = details['message']?.toString();

        if (serverMessage != null && serverMessage.isNotEmpty) {
          message = _friendlyServerMessage(serverMessage);
        }
      }

      _showError(message);
    } catch (e) {
      debugPrint('Forgot password verification error: $e');

      if (!mounted) return;

      _showError(_friendlyServerMessage(e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDateOfBirth() async {
    FocusScope.of(context).unfocus();

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2008, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime(2008, 12, 31),
      helpText: _t('SELECT DATE OF BIRTH', 'जन्म तिथि चुनें'),
      cancelText: _t('CANCEL', 'रद्द करें'),
      confirmText: _t('SELECT', 'चुनें'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF176B4D),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF18352B),
            ),
            dialogTheme: const DialogThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(24)),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) {
      return;
    }

    setState(() {
      _dobController.text =
          '${picked.year.toString().padLeft(4, '0')}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';
    });
  }

  // ============================================================
  // VERIFY OTP
  // ============================================================

  Future<void> _verifyOtp() async {
    FocusScope.of(context).unfocus();

    final otp = _otpController.text.trim();

    if (otp.length != 6) {
      _showError(_t('Enter the 6-digit OTP.', '6 अंकों का OTP दर्ज करें।'));
      return;
    }

    if (_challengeId == null || _challengeId!.isEmpty) {
      _showError(
        _t(
          'Your recovery session has expired. Please start again.',
          'आपका रिकवरी सत्र समाप्त हो गया है। कृपया फिर से शुरू करें।',
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase.functions.invoke(
        'villager-forgot-password',
        body: {
          'action': 'verify_otp',
          'challenge_id': _challengeId,
          'otp': otp,
        },
      );

      final data = _normalizeResponse(response.data);

      debugPrint('==========================================');
      debugPrint('OTP VERIFY RESPONSE');
      debugPrint('$data');
      debugPrint('==========================================');

      if (data['success'] != true) {
        throw Exception(
          data['message']?.toString() ?? 'Invalid or expired OTP.',
        );
      }

      if (!mounted) return;

      setState(() {
        _otpVerified = true;
        _currentStep = 2;
      });

      _showSuccess(
        _t('OTP verified successfully.', 'OTP सफलतापूर्वक सत्यापित हो गया।'),
      );
    } on FunctionException catch (e) {
      debugPrint('OTP FunctionException: ${e.status} ${e.details}');

      if (!mounted) return;

      _showError(
        _friendlyServerMessage(
          e.details is Map
              ? e.details['message']?.toString() ?? 'Invalid or expired OTP.'
              : 'Invalid or expired OTP.',
        ),
      );
    } catch (e) {
      debugPrint('OTP verification error: $e');

      if (!mounted) return;

      _showError(_t('Invalid or expired OTP.', 'OTP गलत या समाप्त हो गया है।'));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // RESEND OTP
  // ============================================================

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0 || _isLoading) {
      return;
    }

    if (_challengeId == null || _challengeId!.isEmpty) {
      _showError(
        _t(
          'Please start the recovery process again.',
          'कृपया रिकवरी प्रक्रिया फिर से शुरू करें।',
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase.functions.invoke(
        'villager-forgot-password',
        body: {'action': 'resend_otp', 'challenge_id': _challengeId},
      );

      final data = _normalizeResponse(response.data);

      if (data['success'] != true) {
        throw Exception(data['message'] ?? 'Unable to generate a new OTP.');
      }

      final newChallengeId = data['challenge_id']?.toString();

      if (newChallengeId != null && newChallengeId.isNotEmpty) {
        _challengeId = newChallengeId;
      }

      final otp = data['otp']?.toString() ?? '';

      if (!mounted) return;

      setState(() {
        _resendSeconds = 30;
      });

      _startResendTimer();

      if (otp.isNotEmpty) {
        await _showOtpNotification(otp);
      } else {
        _showSuccess(
          _t('A new OTP has been generated.', 'नया OTP बनाया गया है।'),
        );
      }
    } catch (e) {
      debugPrint('Resend OTP error: $e');

      if (!mounted) return;

      _showError(
        _t('Unable to generate a new OTP.', 'नया OTP नहीं बनाया जा सका।'),
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
  // OTP APP NOTIFICATION
  // ============================================================

  Future<void> _showOtpNotification(String otp) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 10),
          contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          title: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5F0),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.notifications_active_rounded,
                  color: Color(0xFF176B4D),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _t('Verification OTP', 'सत्यापन OTP'),
                  style: const TextStyle(
                    color: Color(0xFF18352B),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _t(
                  'Your password recovery code is',
                  'आपका पासवर्ड रिकवरी कोड है',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF718078), fontSize: 13),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5F0),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFD1E7DD)),
                ),
                child: Text(
                  otp,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF176B4D),
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    size: 16,
                    color: Color(0xFF718078),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _t('Valid for 5 minutes', '5 मिनट के लिए मान्य'),
                    style: const TextStyle(
                      color: Color(0xFF718078),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF176B4D),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _t('CONTINUE', 'जारी रखें'),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: .4,
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
  // UPDATE PASSWORD
  // ============================================================

  Future<void> _updatePassword() async {
    FocusScope.of(context).unfocus();

    final password = _newPasswordController.text;

    final confirmPassword = _confirmPasswordController.text;

    if (!_otpVerified) {
      _showError(
        _t('Please verify the OTP first.', 'कृपया पहले OTP सत्यापित करें।'),
      );
      return;
    }

    if (_challengeId == null || _challengeId!.isEmpty) {
      _showError(
        _t(
          'Recovery session expired. Start again.',
          'रिकवरी सत्र समाप्त हो गया है। फिर से शुरू करें।',
        ),
      );
      return;
    }

    if (password.length < 6) {
      _showError(
        _t(
          'Password must be at least 6 characters.',
          'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए।',
        ),
      );
      return;
    }

    if (password != confirmPassword) {
      _showError(_t('Passwords do not match.', 'पासवर्ड मेल नहीं खाते हैं।'));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase.functions.invoke(
        'villager-forgot-password',
        body: {
          'action': 'update_password',
          'challenge_id': _challengeId,
          'new_password': password,
        },
      );

      final data = _normalizeResponse(response.data);

      debugPrint('==========================================');
      debugPrint('PASSWORD UPDATE RESPONSE');
      debugPrint('$data');
      debugPrint('==========================================');

      if (data['success'] != true) {
        throw Exception(data['message'] ?? 'Password update failed.');
      }

      // Make absolutely sure the current device is
      // logged out after recovery.
      try {
        await _supabase.auth.signOut();
      } catch (_) {}

      if (!mounted) return;

      await _showPasswordSuccessDialog();

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } on FunctionException catch (e) {
      debugPrint(
        'Password FunctionException: '
        '${e.status} ${e.details}',
      );

      if (!mounted) return;

      _showError(
        _friendlyServerMessage(
          e.details is Map
              ? e.details['message']?.toString() ?? 'Unable to update password.'
              : 'Unable to update password.',
        ),
      );
    } catch (e) {
      debugPrint('Password update error: $e');

      if (!mounted) return;

      _showError(_friendlyServerMessage(e.toString()));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // SUCCESS DIALOG
  // ============================================================

  Future<void> _showPasswordSuccessDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          contentPadding: const EdgeInsets.fromLTRB(25, 28, 25, 10),
          actionsPadding: const EdgeInsets.fromLTRB(18, 5, 18, 18),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xFFEAF5F0),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF176B4D),
                  size: 42,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                _t('Password Updated', 'पासवर्ड अपडेट हो गया'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF18352B),
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _t(
                  'Your password has been changed successfully. Please login using your new password.',
                  'आपका पासवर्ड सफलतापूर्वक बदल दिया गया है। कृपया नए पासवर्ड से लॉगिन करें।',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF718078),
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF176B4D),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  _t('GO TO LOGIN', 'लॉगिन पर जाएँ'),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // RESPONSE NORMALIZER
  // ============================================================

  Map<String, dynamic> _normalizeResponse(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return <String, dynamic>{
      'success': false,
      'message': 'Invalid server response.',
    };
  }

  // ============================================================
  // SERVER ERROR TRANSLATION
  // ============================================================

  String _friendlyServerMessage(String message) {
    final lower = message.toLowerCase();

    if (lower.contains('details do not match')) {
      return _t(
        'The mobile number and name do not match our records.',
        'मोबाइल नंबर और नाम हमारे रिकॉर्ड से मेल नहीं खाते।',
      );
    }

    if (lower.contains('invalid or expired otp')) {
      return _t(
        'The OTP is incorrect or has expired.',
        'OTP गलत है या समाप्त हो गया है।',
      );
    }

    if (lower.contains('challenge')) {
      return _t(
        'Your recovery session has expired. Please start again.',
        'आपका रिकवरी सत्र समाप्त हो गया है। कृपया फिर से शुरू करें।',
      );
    }

    if (lower.contains('password')) {
      return _t('Unable to update the password.', 'पासवर्ड अपडेट नहीं हो सका।');
    }

    return _t(
      'Something went wrong. Please try again.',
      'कुछ गलत हो गया। कृपया फिर से प्रयास करें।',
    );
  }

  // ============================================================
  // RESEND TIMER
  // ============================================================

  void _startResendTimer() {
    _resendTimer?.cancel();

    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendSeconds <= 1) {
        timer.cancel();

        setState(() {
          _resendSeconds = 0;
        });
      } else {
        setState(() {
          _resendSeconds--;
        });
      }
    });
  }

  // ============================================================
  // SNACKBARS
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFB3261E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF176B4D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFF18352B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _isLoading
              ? null
              : () {
                  Navigator.pop(context);
                },
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildProgress(),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildCurrentStep(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PROGRESS
  // ============================================================

  Widget _buildProgress() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 5, 24, 8),
      child: Row(
        children: [
          _buildProgressItem(
            number: '1',
            title: _t('Verify', 'सत्यापन'),
            active: _currentStep >= 0,
            completed: _currentStep > 0,
          ),
          _buildProgressLine(active: _currentStep >= 1),
          _buildProgressItem(
            number: '2',
            title: 'OTP',
            active: _currentStep >= 1,
            completed: _currentStep > 1,
          ),
          _buildProgressLine(active: _currentStep >= 2),
          _buildProgressItem(
            number: '3',
            title: _t('Password', 'पासवर्ड'),
            active: _currentStep >= 2,
            completed: false,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem({
    required String number,
    required String title,
    required bool active,
    required bool completed,
  }) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF176B4D) : const Color(0xFFE0E8E4),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: completed
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                : Text(
                    number,
                    style: TextStyle(
                      color: active ? Colors.white : const Color(0xFF718078),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            color: active ? const Color(0xFF176B4D) : const Color(0xFF718078),
            fontSize: 9.5,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressLine({required bool active}) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 2,
        margin: const EdgeInsets.only(bottom: 18, left: 5, right: 5),
        color: active ? const Color(0xFF176B4D) : const Color(0xFFE0E8E4),
      ),
    );
  }

  // ============================================================
  // CURRENT STEP
  // ============================================================

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0:
        return _buildDetailsStep();

      case 1:
        return _buildOtpStep();

      default:
        return _buildPasswordStep();
    }
  }

  // ============================================================
  // STEP 1
  // ============================================================

  Widget _buildDetailsStep() {
    return Form(
      key: _formKey,
      child: ListView(
        key: const ValueKey('details'),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 35),
        children: [
          _buildHeroIcon(Icons.lock_reset_rounded),
          const SizedBox(height: 20),
          Text(
            _t('Forgot Password?', 'पासवर्ड भूल गए?'),
            style: const TextStyle(
              color: Color(0xFF18352B),
              fontSize: 29,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            _t(
              'Verify your registered villager details to recover your account.',
              'अपना खाता रिकवर करने के लिए पंजीकृत जानकारी सत्यापित करें।',
            ),
            style: const TextStyle(
              color: Color(0xFF718078),
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          _buildLabel(_t('Mobile Number', 'मोबाइल नंबर')),
          _buildInput(
            controller: _mobileController,
            hint: _t(
              'Enter 10-digit mobile number',
              '10 अंकों का मोबाइल नंबर दर्ज करें',
            ),
            icon: Icons.phone_android_outlined,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            validator: (value) {
              final mobile = value?.trim() ?? '';

              if (mobile.length != 10) {
                return _t(
                  'Enter a valid 10-digit number.',
                  'सही 10 अंकों का नंबर दर्ज करें।',
                );
              }

              return null;
            },
          ),
          const SizedBox(height: 18),
          _buildLabel(_t('Name', 'नाम')),
          _buildInput(
            controller: _nameController,
            hint: _t(
              'Enter your registered name',
              'अपना पंजीकृत नाम दर्ज करें',
            ),
            icon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 18),
          _buildLabel(_t("Father's Name", "पिता का नाम")),
          _buildInput(
            controller: _fatherNameController,
            hint: _t("Enter your father's name", 'अपने पिता का नाम दर्ज करें'),
            icon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            validator: _requiredValidator,
          ),
          const SizedBox(height: 18),
          _buildLabel(_t('Date of Birth', 'जन्म तिथि')),
          TextFormField(
            controller: _dobController,
            readOnly: true,
            onTap: _selectDateOfBirth,
            validator: _requiredValidator,
            style: const TextStyle(
              color: Color(0xFF18352B),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: _t('Select your date of birth', 'अपनी जन्म तिथि चुनें'),
              hintStyle: const TextStyle(
                color: Color(0xFF9AA59F),
                fontSize: 13.5,
              ),
              prefixIcon: const Icon(
                Icons.calendar_month_outlined,
                color: Color(0xFF718078),
                size: 21,
              ),
              suffixIcon: const Icon(
                Icons.arrow_drop_down_rounded,
                color: Color(0xFF718078),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 17,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE1E9E5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: Color(0xFF176B4D),
                  width: 1.5,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Colors.redAccent),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(
                  color: Colors.redAccent,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 26),
          _buildInfoCard(
            icon: Icons.verified_user_outlined,
            text: _t(
              'Your mobile number and name must match the details registered by your Panchayat.',
              'आपका मोबाइल नंबर और नाम पंचायत में पंजीकृत जानकारी से मेल खाना चाहिए।',
            ),
          ),
          const SizedBox(height: 22),
          _buildPrimaryButton(
            text: _t('VERIFY DETAILS', 'जानकारी सत्यापित करें'),
            onPressed: _isLoading ? null : _verifyDetails,
          ),
          const SizedBox(height: 20),
          _buildHelpCard(),
        ],
      ),
    );
  }

  // ============================================================
  // STEP 2
  // ============================================================

  Widget _buildOtpStep() {
    return ListView(
      key: const ValueKey('otp'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 35),
      children: [
        _buildHeroIcon(Icons.mark_email_read_outlined),
        const SizedBox(height: 20),
        Text(
          _t('Verify OTP', 'OTP सत्यापित करें'),
          style: const TextStyle(
            color: Color(0xFF18352B),
            fontSize: 29,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          _t(
            'Enter the 6-digit verification code shown in the Mor Panchayat notification.',
            'Mor Panchayat नोटिफिकेशन में दिखाया गया 6 अंकों का सत्यापन कोड दर्ज करें।',
          ),
          style: const TextStyle(
            color: Color(0xFF718078),
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        _buildInfoCard(
          icon: Icons.notifications_active_outlined,
          text: _t(
            'The OTP is valid for 5 minutes. Never share your OTP with anyone.',
            'OTP 5 मिनट के लिए मान्य है। अपना OTP किसी के साथ साझा न करें।',
          ),
        ),
        const SizedBox(height: 25),
        _buildLabel(_t('6-Digit OTP', '6 अंकों का OTP')),
        TextFormField(
          controller: _otpController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF18352B),
            fontSize: 25,
            fontWeight: FontWeight.w900,
            letterSpacing: 8,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: '••••••',
            hintStyle: const TextStyle(
              color: Color(0xFFB7C1BC),
              letterSpacing: 8,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(color: Color(0xFFE1E9E5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: const BorderSide(
                color: Color(0xFF176B4D),
                width: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildPrimaryButton(
          text: _t('VERIFY OTP', 'OTP सत्यापित करें'),
          onPressed: _isLoading ? null : _verifyOtp,
        ),
        const SizedBox(height: 14),
        Center(
          child: _resendSeconds > 0
              ? Text(
                  _t(
                    'Generate new OTP in $_resendSeconds seconds',
                    '$_resendSeconds सेकंड में नया OTP बनाएँ',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF718078),
                    fontSize: 12,
                  ),
                )
              : TextButton(
                  onPressed: _isLoading ? null : _resendOtp,
                  child: Text(
                    _t('GENERATE NEW OTP', 'नया OTP बनाएँ'),
                    style: const TextStyle(
                      color: Color(0xFF176B4D),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
        ),
        const SizedBox(height: 20),
        _buildHelpCard(),
      ],
    );
  }

  // ============================================================
  // STEP 3
  // ============================================================

  Widget _buildPasswordStep() {
    return ListView(
      key: const ValueKey('password'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 35),
      children: [
        _buildHeroIcon(Icons.password_rounded),
        const SizedBox(height: 20),
        Text(
          _t('Create New Password', 'नया पासवर्ड बनाएँ'),
          style: const TextStyle(
            color: Color(0xFF18352B),
            fontSize: 29,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          _t(
            'Your identity has been verified. Choose a strong new password.',
            'आपकी पहचान सत्यापित हो गई है। एक मजबूत नया पासवर्ड बनाएँ।',
          ),
          style: const TextStyle(
            color: Color(0xFF718078),
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 28),
        _buildLabel(_t('New Password', 'नया पासवर्ड')),
        _buildPasswordInput(
          controller: _newPasswordController,
          hint: _t('Create new password', 'नया पासवर्ड बनाएँ'),
          obscure: _obscureNewPassword,
          onToggle: () {
            setState(() {
              _obscureNewPassword = !_obscureNewPassword;
            });
          },
        ),
        const SizedBox(height: 18),
        _buildLabel(_t('Confirm Password', 'पासवर्ड की पुष्टि करें')),
        _buildPasswordInput(
          controller: _confirmPasswordController,
          hint: _t('Confirm your password', 'पासवर्ड दोबारा दर्ज करें'),
          obscure: _obscureConfirmPassword,
          onToggle: () {
            setState(() {
              _obscureConfirmPassword = !_obscureConfirmPassword;
            });
          },
        ),
        const SizedBox(height: 17),
        _buildInfoCard(
          icon: Icons.security_outlined,
          text: _t(
            'Use at least 6 characters. A longer password is recommended.',
            'कम से कम 6 अक्षरों का पासवर्ड रखें। लंबा पासवर्ड अधिक सुरक्षित है।',
          ),
        ),
        const SizedBox(height: 25),
        _buildPrimaryButton(
          text: _t('UPDATE PASSWORD', 'पासवर्ड अपडेट करें'),
          onPressed: _isLoading ? null : _updatePassword,
        ),
      ],
    );
  }

  // ============================================================
  // HERO ICON
  // ============================================================

  Widget _buildHeroIcon(IconData icon) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5F0),
        borderRadius: BorderRadius.circular(23),
      ),
      child: Icon(icon, color: const Color(0xFF176B4D), size: 37),
    );
  }

  // ============================================================
  // LABEL
  // ============================================================

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 3, bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF18352B),
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ============================================================
  // INPUT
  // ============================================================

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLength: maxLength,
      validator: validator,
      style: const TextStyle(
        color: Color(0xFF18352B),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9AA59F), fontSize: 13.5),
        prefixIcon: Icon(icon, color: const Color(0xFF718078), size: 21),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE1E9E5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF176B4D), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }

  // ============================================================
  // PASSWORD INPUT
  // ============================================================

  Widget _buildPasswordInput({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(
        color: Color(0xFF18352B),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF9AA59F), fontSize: 13.5),
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: Color(0xFF718078),
        ),
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: const Color(0xFF718078),
          ),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFE1E9E5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF176B4D), width: 1.5),
        ),
      ),
    );
  }

  // ============================================================
  // PRIMARY BUTTON
  // ============================================================

  Widget _buildPrimaryButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF176B4D),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFF8BB4A4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 23,
                height: 23,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .4,
                ),
              ),
      ),
    );
  }

  // ============================================================
  // INFO CARD
  // ============================================================

  Widget _buildInfoCard({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5F0),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFD6EAE1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF176B4D), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF18352B),
                fontSize: 11.8,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HELP CARD
  // ============================================================

  Widget _buildHelpCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE2EAE6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.support_agent_outlined,
            color: Color(0xFF176B4D),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _t(
                'If your registered details are incorrect, contact your Ward Panch or Sarpanch.',
                'यदि आपकी पंजीकृत जानकारी गलत है, तो अपने वार्ड पंच या सरपंच से संपर्क करें।',
              ),
              style: const TextStyle(
                color: Color(0xFF52645C),
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VALIDATOR
  // ============================================================

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return _t('This field is required.', 'यह जानकारी आवश्यक है।');
    }

    return null;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _resendTimer?.cancel();

    _mobileController.dispose();
    _nameController.dispose();
    _fatherNameController.dispose();
    _dobController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }
}
