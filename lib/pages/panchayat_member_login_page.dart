import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mor_panchayat/services/animated_bubble_background.dart';
import 'package:mor_panchayat/pages/member_pages/panchayat_member_home_page.dart';
import 'package:mor_panchayat/pages/sarpanch_pages/sarpanch_home_page.dart';

class PanchayatMemberLoginPage extends StatefulWidget {
  final bool isHindi;

  const PanchayatMemberLoginPage({super.key, required this.isHindi});

  @override
  State<PanchayatMemberLoginPage> createState() =>
      _PanchayatMemberLoginPageState();
}

class _PanchayatMemberLoginPageState extends State<PanchayatMemberLoginPage> {
  // ==============================================================
  // CONTROLLERS
  // ==============================================================

  final TextEditingController _idController = TextEditingController();

  final TextEditingController _passwordController = TextEditingController();

  // ==============================================================
  // STATE
  // ==============================================================

  late bool isHindi;

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  String? _loginError;

  String _getLoginErrorMessage(AuthException error) {
    final message = error.message.toLowerCase();

    if (message.contains('invalid login credentials')) {
      return isHindi
          ? 'लॉगिन आईडी या पासवर्ड गलत है।'
          : 'Incorrect Login ID or password.';
    }

    if (message.contains('email not confirmed')) {
      return isHindi
          ? 'आपका खाता अभी सत्यापित नहीं हुआ है।'
          : 'Your account has not been confirmed yet.';
    }

    if (message.contains('too many requests')) {
      return isHindi
          ? 'बहुत अधिक प्रयास किए गए। थोड़ी देर बाद प्रयास करें।'
          : 'Too many attempts. Please try again later.';
    }

    return isHindi
        ? 'लॉगिन असफल हुआ। कृपया दोबारा प्रयास करें।'
        : 'Login failed. Please try again.';
  }

  // ==============================================================
  // INIT
  // ==============================================================

  @override
  void initState() {
    super.initState();
    isHindi = widget.isHindi;
  }

  // ==============================================================
  // DISPOSE
  // ==============================================================

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final title = isHindi ? 'पंचायत लॉगिन' : 'Panchayat Login';

    final subtitle = isHindi
        ? 'पंचायत प्रशासन और ग्राम विकास से जुड़ें'
        : 'Access Panchayat administration and village development';

    final memberIdLabel = isHindi ? 'लॉगिन आईडी' : 'Login ID';

    final memberIdHint = isHindi
        ? 'अपनी लॉगिन आईडी दर्ज करें'
        : 'Enter your login ID';

    final passwordLabel = isHindi ? 'पासवर्ड' : 'Password';

    final passwordHint = isHindi
        ? 'अपना पासवर्ड दर्ज करें'
        : 'Enter your password';

    final loginButton = isHindi ? 'लॉगिन करें' : 'Login';

    final rememberText = isHindi ? 'मुझे याद रखें' : 'Remember me';

    final forgotText = isHindi ? 'पासवर्ड भूल गए?' : 'Forgot password?';

    return Scaffold(
      body: AnimatedBubbleBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // ========================================================
              // BACK BUTTON
              // ========================================================
              Positioned(
                top: 12,
                left: 18,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.90),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDDE6E1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: Color(0xFF176B4D),
                      ),
                    ),
                  ),
                ),
              ),

              // ========================================================
              // LANGUAGE BUTTON
              // ========================================================
              Positioned(
                top: 12,
                right: 18,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _showLanguageSelector,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.90),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDDE6E1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.025),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.language_rounded,
                            size: 19,
                            color: Color(0xFF176B4D),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            isHindi ? 'हिन्दी' : 'English',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF24352F),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // ========================================================
              // MAIN CONTENT
              // ========================================================
              Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(28, 70, 28, 30),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      children: [
                        SizedBox(height: size.height * 0.025),

                        // ==================================================
                        // LOGIN ICON
                        // ==================================================
                        _loginIcon(),

                        const SizedBox(height: 28),

                        // ==================================================
                        // TITLE
                        // ==================================================
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            title,
                            key: ValueKey(title),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 29,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              letterSpacing: -0.5,
                              color: Color(0xFF17352B),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ==================================================
                        // SUBTITLE
                        // ==================================================
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: Text(
                            subtitle,
                            key: ValueKey(subtitle),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15.5,
                              height: 1.5,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),

                        // ==================================================
                        // LOGIN CARD
                        // ==================================================
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(21),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.97),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: const Color(0xFFDDE6E1)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.045),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ==========================================
                              // LOGIN ID
                              // ==========================================
                              Text(
                                memberIdLabel,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF53635D),
                                ),
                              ),

                              const SizedBox(height: 9),

                              TextField(
                                controller: _idController,
                                keyboardType: TextInputType.text,
                                textInputAction: TextInputAction.next,
                                textCapitalization: TextCapitalization.none,
                                onChanged: (_) {
                                  if (_loginError != null) {
                                    setState(() {
                                      _loginError = null;
                                    });
                                  }
                                },
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF24352F),
                                ),
                                decoration: _inputDecoration(
                                  hint: memberIdHint,
                                  icon: Icons.badge_outlined,
                                ),
                              ),

                              const SizedBox(height: 18),

                              // ==========================================
                              // PASSWORD
                              // ==========================================
                              Text(
                                passwordLabel,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF53635D),
                                ),
                              ),

                              const SizedBox(height: 9),

                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _login(),
                                onChanged: (_) {
                                  if (_loginError != null) {
                                    setState(() {
                                      _loginError = null;
                                    });
                                  }
                                },
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF24352F),
                                ),
                                decoration: _inputDecoration(
                                  hint: passwordHint,
                                  icon: Icons.lock_outline_rounded,
                                  suffix: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // ==========================================
                              // REMEMBER / FORGOT
                              // ==========================================
                              Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      activeColor: const Color(0xFF176B4D),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      onChanged: (value) {
                                        setState(() {
                                          _rememberMe = value ?? false;
                                        });
                                      },
                                    ),
                                  ),

                                  const SizedBox(width: 7),

                                  Expanded(
                                    child: Text(
                                      rememberText,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),

                                  GestureDetector(
                                    onTap: _forgotPassword,
                                    child: Text(
                                      forgotText,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF176B4D),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              // ==========================================
                              // LOGIN ERROR
                              // ==========================================
                              if (_loginError != null) ...[
                                const SizedBox(height: 14),

                                AnimatedSize(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOut,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 13,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF3F1),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0xFFF3C9C3),
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 29,
                                          height: 29,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFFFE1DC),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.error_outline_rounded,
                                            size: 18,
                                            color: Color(0xFFD94A3A),
                                          ),
                                        ),

                                        const SizedBox(width: 10),

                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                isHindi
                                                    ? 'लॉगिन असफल'
                                                    : 'Login unsuccessful',
                                                style: const TextStyle(
                                                  color: Color(0xFF9E3328),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),

                                              const SizedBox(height: 2),

                                              Text(
                                                _loginError!,
                                                style: const TextStyle(
                                                  color: Color(0xFFB24A3D),
                                                  fontSize: 11.5,
                                                  height: 1.35,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 20),

                              // ==========================================
                              // LOGIN BUTTON
                              // ==========================================
                              SizedBox(
                                width: double.infinity,
                                height: 57,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _login,
                                  style: ElevatedButton.styleFrom(
                                    elevation: 7,
                                    backgroundColor: const Color(0xFF176B4D),
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: const Color(
                                      0xFF176B4D,
                                    ).withOpacity(0.55),
                                    shadowColor: const Color(
                                      0xFF176B4D,
                                    ).withOpacity(0.25),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(17),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Icon(
                                              Icons.login_rounded,
                                              size: 21,
                                            ),
                                            const SizedBox(width: 9),
                                            Text(
                                              loginButton,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 22),

                        // ==================================================
                        // TRANSPARENCY NOTICE
                        // ==================================================
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF4EF).withOpacity(0.88),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFD4E8DE)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.visibility_rounded,
                                size: 21,
                                color: Color(0xFF176B4D),
                              ),

                              const SizedBox(width: 10),

                              Expanded(
                                child: Text(
                                  isHindi
                                      ? 'यह लॉगिन पंचायत के अधिकृत सरपंच और पंचायत सदस्यों के लिए है।'
                                      : 'This login is for authorized Sarpanch and Panchayat members.',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    height: 1.45,
                                    color: Color(0xFF315B4A),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ==================================================
                        // FOOTER
                        // ==================================================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_user_outlined,
                              size: 15,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isHindi
                                  ? 'सुरक्षित • पारदर्शी • जवाबदेह'
                                  : 'Secure • Transparent • Accountable',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // LOGIN ICON
  // ==============================================================

  Widget _loginIcon() {
    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.96),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF176B4D),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF176B4D).withOpacity(0.18),
                blurRadius: 18,
              ),
            ],
          ),
          child: const Icon(
            Icons.groups_rounded,
            color: Colors.white,
            size: 42,
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // INPUT DECORATION
  // ==============================================================

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 14,
        color: Colors.grey.shade400,
        fontWeight: FontWeight.w500,
      ),

      prefixIcon: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF4EF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF176B4D), size: 20),
      ),

      suffixIcon: suffix,

      filled: true,
      fillColor: const Color(0xFFF8FAF9),

      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 17),

      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDDE6E1)),
      ),

      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDDE6E1)),
      ),

      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF176B4D), width: 1.5),
      ),
    );
  }

  // ==============================================================
  // SUPABASE LOGIN
  // SARPANCH + PANCHAYAT MEMBER
  // ==============================================================

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    final loginId = _idController.text.trim();
    final password = _passwordController.text;

    // ============================================================
    // VALIDATION
    // ============================================================

    if (loginId.isEmpty || password.isEmpty) {
      setState(() {
        _loginError = isHindi
            ? 'कृपया लॉगिन आईडी और पासवर्ड दर्ज करें।'
            : 'Please enter your Login ID and password.';
      });
      return;
    }

    setState(() {
      _loginError = null;
      _isLoading = true;
    });

    try {
      // ============================================================
      // 1. SUPABASE AUTH LOGIN
      // ============================================================

      debugPrint('==========================================');
      debugPrint('MOR PANCHAYAT LOGIN');
      debugPrint('Login ID: $loginId');
      debugPrint('==========================================');

      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: loginId,
        password: password,
      );

      final user = response.user;

      if (user == null) {
        throw const AuthException('Unable to retrieve authenticated user.');
      }

      debugPrint('AUTH SUCCESS');
      debugPrint('User ID: ${user.id}');
      debugPrint('Email: ${user.email}');

      // ============================================================
      // 2. GET USER PROFILE
      // ============================================================

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('''
          id,
          user_id,
          email,
          name,
          role,
          mobile,
          ward_number,
          created_at
          ''')
          .eq('user_id', user.id)
          .maybeSingle();

      debugPrint('PROFILE: $profile');

      // ============================================================
      // 3. NO PROFILE FOUND
      // ============================================================

      if (profile == null) {
        await Supabase.instance.client.auth.signOut();

        throw const AuthException('Your Panchayat profile could not be found.');
      }

      // ============================================================
      // 4. GET ROLE
      // ============================================================

      final role = profile['role']?.toString().toLowerCase();

      final name = profile['name']?.toString() ?? '';
      final mobile = profile['mobile']?.toString() ?? '';
      final wardNumber = profile['ward_number']?.toString() ?? '';

      debugPrint('ROLE: $role');
      debugPrint('NAME: $name');

      // ============================================================
      // 5. SARPANCH
      // ============================================================

      if (role == 'sarpanch') {
        debugPrint('SARPANCH LOGIN SUCCESS');

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => SarpanchHomePage(
              isHindi: isHindi,
              sarpanchName: name.isNotEmpty ? name : 'Sarpanch',
              mobileNumber: mobile,
            ),
          ),
        );

        return;
      }

      // ============================================================
      // 6. PANCHAYAT MEMBER
      // ============================================================

      if (role == 'member') {
        debugPrint('MEMBER LOGIN SUCCESS');

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PanchayatMemberHomePage(
              isHindi: isHindi,
              memberName: name.isNotEmpty ? name : 'Member',
              wardNumber: wardNumber,
              mobileNumber: mobile,
            ),
          ),
        );

        return;
      }

      // ============================================================
      // 7. WRONG ROLE FOR THIS LOGIN PAGE
      // ============================================================

      await Supabase.instance.client.auth.signOut();

      throw AuthException(
        isHindi
            ? 'यह खाता सरपंच या पंचायत सदस्य का खाता नहीं है।'
            : 'This account is not a Sarpanch or Panchayat Member account.',
      );
    } on AuthException catch (e) {
      debugPrint('==========================================');
      debugPrint('SUPABASE AUTH ERROR');
      debugPrint('Message: ${e.message}');
      debugPrint('Status: ${e.statusCode}');
      debugPrint('Code: ${e.code}');
      debugPrint('Details: ${e.toString()}');
      debugPrint('==========================================');

      if (!mounted) return;

      setState(() {
        // TEMPORARY: show the actual Supabase error
        _loginError = '${e.message} (${e.statusCode ?? 'no status'})';
      });
    } catch (e, stackTrace) {
      debugPrint('==========================================');
      debugPrint('UNKNOWN LOGIN ERROR');
      debugPrint('Error: $e');
      debugPrint('Stack: $stackTrace');
      debugPrint('==========================================');

      if (!mounted) return;

      setState(() {
        _loginError = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ==============================================================
  // ENGLISH AUTH ERROR
  // ==============================================================

  String _getEnglishAuthError(String message) {
    final error = message.toLowerCase();

    if (error.contains('invalid login credentials')) {
      return 'Invalid Login ID or password.';
    }

    if (error.contains('email not confirmed')) {
      return 'Your account email has not been confirmed.';
    }

    if (error.contains('too many requests')) {
      return 'Too many login attempts. Please try again later.';
    }

    if (error.contains('network')) {
      return 'Network error. Please check your internet connection.';
    }

    return message.isNotEmpty ? message : 'Unable to login. Please try again.';
  }

  // ==============================================================
  // HINDI AUTH ERROR
  // ==============================================================

  String _getHindiAuthError(String message) {
    final error = message.toLowerCase();

    if (error.contains('invalid login credentials')) {
      return 'लॉगिन आईडी या पासवर्ड गलत है।';
    }

    if (error.contains('email not confirmed')) {
      return 'आपके खाते का ईमेल सत्यापित नहीं है।';
    }

    if (error.contains('too many requests')) {
      return 'बहुत अधिक लॉगिन प्रयास हुए हैं। कृपया बाद में प्रयास करें।';
    }

    if (error.contains('network')) {
      return 'इंटरनेट कनेक्शन की समस्या है।';
    }

    return message.isNotEmpty
        ? message
        : 'लॉगिन नहीं हो सका। कृपया दोबारा प्रयास करें।';
  }
  // ==============================================================
  // FORGOT PASSWORD
  // ==============================================================

  void _forgotPassword() {
    _showMessage(
      isHindi
          ? 'पासवर्ड रिकवरी जल्द उपलब्ध होगी'
          : 'Password recovery will be available soon',
    );
  }

  // ==============================================================
  // LANGUAGE SELECTOR
  // ==============================================================

  void _showLanguageSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 22),

                Text(
                  isHindi ? 'भाषा चुनें' : 'Choose Language',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17352B),
                  ),
                ),

                const SizedBox(height: 18),

                _languageOption(
                  flag: '🇮🇳',
                  title: 'हिन्दी',
                  selected: isHindi,
                  onTap: () {
                    setState(() {
                      isHindi = true;
                      _loginError = null;
                    });

                    Navigator.pop(context);
                  },
                ),

                const SizedBox(height: 10),

                _languageOption(
                  flag: '🇬🇧',
                  title: 'English',
                  selected: !isHindi,
                  onTap: () {
                    setState(() {
                      isHindi = false;
                      _loginError = null;
                    });

                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==============================================================
  // MESSAGE
  // ==============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF17352B),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(message),
      ),
    );
  }

  // ==============================================================
  // LANGUAGE OPTION
  // ==============================================================

  Widget _languageOption({
    required String flag,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEAF4EF) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? const Color(0xFF176B4D)
                  : const Color(0xFFE2E8E5),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 24)),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF24352F),
                  ),
                ),
              ),

              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF176B4D),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
