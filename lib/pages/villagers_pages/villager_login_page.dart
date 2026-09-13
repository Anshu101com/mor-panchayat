import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'villager_home_page.dart';
import 'villager_forgot_password_page.dart';

class VillagerLoginPage extends StatefulWidget {
  final bool isHindi;
  final String mobileNumber;

  const VillagerLoginPage({
    super.key,
    this.isHindi = false,
    required this.mobileNumber,
  });

  @override
  State<VillagerLoginPage> createState() => _VillagerLoginPageState();
}

class _VillagerLoginPageState extends State<VillagerLoginPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _passwordController = TextEditingController();

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // ============================================================
  // TRANSLATION
  // ============================================================

  String _t(String english, String hindi) {
    return widget.isHindi ? hindi : english;
  }

  // ============================================================
  // LOGIN
  // ============================================================

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final mobile = widget.mobileNumber.trim();

      // ========================================================
      // GET VILLAGER PROFILE
      // ========================================================

      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('mobile', mobile)
          .eq('role', 'villager')
          .maybeSingle();

      if (profile == null) {
        throw Exception('Villager profile not found.');
      }

      // ========================================================
      // GET AUTH EMAIL
      // ========================================================

      final email = profile['email']?.toString().trim();

      if (email == null || email.isEmpty) {
        throw Exception('Authentication account is not configured.');
      }

      // ========================================================
      // SUPABASE AUTH LOGIN
      // ========================================================

      final AuthResponse response = await _supabase.auth.signInWithPassword(
        email: email,
        password: _passwordController.text,
      );

      if (response.user == null) {
        throw Exception('Login failed.');
      }

      // ========================================================
      // VERIFY PROFILE AFTER LOGIN
      // ========================================================

      final loggedInProfile = await _supabase
          .from('profiles')
          .select('id, role, mobile, name')
          .eq('user_id', response.user!.id)
          .maybeSingle();

      if (loggedInProfile == null) {
        await _supabase.auth.signOut();

        throw Exception('Profile not found for this account.');
      }

      final role = loggedInProfile['role']?.toString().toLowerCase().trim();

      // ========================================================
      // VERIFY VILLAGER ROLE
      // ========================================================

      if (role != 'villager') {
        await _supabase.auth.signOut();

        throw Exception('This account is not a villager account.');
      }

      // ========================================================
      // SUCCESS
      // ========================================================

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => VillagerHomePage(isHindi: widget.isHindi),
        ),
        (route) => false,
      );
    } on AuthException catch (e) {
      debugPrint('Villager authentication error: ${e.message}');

      if (!mounted) {
        return;
      }

      _showError(
        _t(
          'Incorrect password. Please try again.',
          'पासवर्ड गलत है। कृपया दोबारा प्रयास करें।',
        ),
      );
    } catch (e) {
      debugPrint('Villager login error: $e');

      if (!mounted) {
        return;
      }

      _showError(
        _t(
          'Login failed. Please try again.',
          'लॉगिन विफल हुआ। कृपया दोबारा प्रयास करें।',
        ),
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
  // FORGOT PASSWORD
  // ============================================================

  void _forgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VillagerForgotPasswordPage(isHindi: widget.isHindi),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF17352B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        margin: const EdgeInsets.all(16),
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 21,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF176B4D);
    const darkText = Color(0xFF18352B);
    const mutedText = Color(0xFF718078);

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 25, 24, 35),
            children: [
              // ==================================================
              // BACK BUTTON
              // ==================================================
              Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(15),
                    onTap: _isLoading
                        ? null
                        : () {
                            Navigator.pop(context);
                          },
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: const Color(0xFFE1E9E5)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: green,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // ==================================================
              // LOGO
              // ==================================================
              Center(
                child: Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5F0),
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: green,
                    size: 43,
                  ),
                ),
              ),

              const SizedBox(height: 17),

              // ==================================================
              // APP NAME
              // ==================================================
              const Center(
                child: Text(
                  'MOR PANCHAYAT',
                  style: TextStyle(
                    color: green,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              const SizedBox(height: 5),

              Center(
                child: Text(
                  _t(
                    'Your Panchayat, Your Community',
                    'आपकी पंचायत, आपका समुदाय',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: mutedText, fontSize: 12.5),
                ),
              ),

              const SizedBox(height: 42),

              // ==================================================
              // TITLE
              // ==================================================
              Text(
                _t('Villager Login', 'ग्रामीण लॉगिन'),
                style: const TextStyle(
                  color: darkText,
                  fontSize: 29,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                _t(
                  'Enter your password to continue.',
                  'जारी रखने के लिए अपना पासवर्ड दर्ज करें।',
                ),
                style: const TextStyle(
                  color: mutedText,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 28),

              // ==================================================
              // MOBILE NUMBER LABEL
              // ==================================================
              Text(
                _t('Mobile Number', 'मोबाइल नंबर'),
                style: const TextStyle(
                  color: darkText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              // ==================================================
              // LOCKED MOBILE NUMBER
              // ==================================================
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 17,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F3),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: const Color(0xFFE1E9E5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF5F0),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.phone_android_rounded,
                        color: green,
                        size: 20,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        widget.mobileNumber,
                        style: const TextStyle(
                          color: darkText,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: .4,
                        ),
                      ),
                    ),

                    const Icon(Icons.verified_rounded, color: green, size: 21),
                  ],
                ),
              ),

              const SizedBox(height: 23),

              // ==================================================
              // PASSWORD LABEL
              // ==================================================
              Text(
                _t('Password', 'पासवर्ड'),
                style: const TextStyle(
                  color: darkText,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 8),

              // ==================================================
              // PASSWORD
              // ==================================================
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) {
                  if (!_isLoading) {
                    _login();
                  }
                },
                style: const TextStyle(
                  color: darkText,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  hintText: _t('Enter your password', 'अपना पासवर्ड दर्ज करें'),
                  hintStyle: const TextStyle(
                    color: Color(0xFF9AA59F),
                    fontSize: 13.5,
                  ),

                  // Prefix
                  prefixIcon: const Icon(
                    Icons.lock_outline_rounded,
                    color: mutedText,
                  ),

                  // Visibility
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: mutedText,
                    ),
                  ),

                  filled: true,
                  fillColor: Colors.white,

                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 17,
                  ),

                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: BorderSide.none,
                  ),

                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: const BorderSide(color: Color(0xFFE1E9E5)),
                  ),

                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: const BorderSide(color: green, width: 1.5),
                  ),

                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: const BorderSide(color: Colors.redAccent),
                  ),

                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: const BorderSide(
                      color: Colors.redAccent,
                      width: 1.5,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return _t('Password is required.', 'पासवर्ड आवश्यक है।');
                  }

                  return null;
                },
              ),

              const SizedBox(height: 12),

              // ==================================================
              // FORGOT PASSWORD
              // ==================================================
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _isLoading ? null : _forgotPassword,
                  child: Text(
                    _t('Forgot Password?', 'पासवर्ड भूल गए?'),
                    style: const TextStyle(
                      color: green,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 27),

              // ==================================================
              // LOGIN BUTTON
              // ==================================================
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: green,
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
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _t('LOGIN', 'लॉगिन'),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .4,
                              ),
                            ),

                            const SizedBox(width: 9),

                            const Icon(Icons.arrow_forward_rounded, size: 21),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 23),

              // ==================================================
              // SECURITY INFORMATION
              // ==================================================
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF5F0),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: green,
                      size: 21,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        _t(
                          'Your account information is protected by secure authentication.',
                          'आपके खाते की जानकारी सुरक्षित प्रमाणीकरण द्वारा सुरक्षित है।',
                        ),
                        style: const TextStyle(
                          color: darkText,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ==================================================
              // FOOTER
              // ==================================================
              Center(
                child: Text(
                  _t(
                    'Secure access to your Panchayat',
                    'आपकी पंचायत तक सुरक्षित पहुँच',
                  ),
                  style: const TextStyle(color: mutedText, fontSize: 11.5),
                ),
              ),

              const SizedBox(height: 5),

              const Center(
                child: Text(
                  'MOR PANCHAYAT',
                  style: TextStyle(
                    color: green,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .7,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }
}
