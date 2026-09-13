import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'villager_home_page.dart';

class VillagerPersonalInfoPage extends StatefulWidget {
  final bool isHindi;
  final String mobileNumber;

  const VillagerPersonalInfoPage({
    super.key,
    required this.isHindi,
    required this.mobileNumber,
  });

  @override
  State<VillagerPersonalInfoPage> createState() =>
      _VillagerPersonalInfoPageState();
}

class _VillagerPersonalInfoPageState extends State<VillagerPersonalInfoPage> {
  // ============================================================
  // SUPABASE
  // ============================================================

  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // FORM
  // ============================================================

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _fatherNameController = TextEditingController();
  final _motherNameController = TextEditingController();
  final _dobController = TextEditingController();
  final _wardController = TextEditingController();
  final _houseController = TextEditingController();

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  String? _selectedGender;

  // ============================================================
  // COLORS
  // ============================================================

  static const Color green = Color(0xFF176B4D);
  static const Color darkGreen = Color(0xFF18352B);
  static const Color muted = Color(0xFF718078);
  static const Color background = Color(0xFFF7FAF8);
  static const Color lightGreen = Color(0xFFEAF5F0);
  static const Color border = Color(0xFFE1E9E5);

  // ============================================================
  // TRANSLATION
  // ============================================================

  String _t(String english, String hindi) {
    return widget.isHindi ? hindi : english;
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _selectDateOfBirth() async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: _t('SELECT DATE OF BIRTH', 'जन्म तिथि चुनें'),
      cancelText: _t('CANCEL', 'रद्द करें'),
      confirmText: _t('SELECT', 'चुनें'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: green,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: darkGreen,
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
          '${picked.day.toString().padLeft(2, '0')}/'
          '${picked.month.toString().padLeft(2, '0')}/'
          '${picked.year}';
    });
  }

  // ============================================================
  // CONVERT DD/MM/YYYY -> YYYY-MM-DD
  // ============================================================

  String? _getDatabaseDate() {
    final value = _dobController.text.trim();

    if (value.isEmpty) {
      return null;
    }

    try {
      final parts = value.split('/');

      if (parts.length != 3) {
        return null;
      }

      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);

      final date = DateTime(year, month, day);

      if (date.year != year || date.month != month || date.day != day) {
        return null;
      }

      return '${year.toString().padLeft(4, '0')}-'
          '${month.toString().padLeft(2, '0')}-'
          '${day.toString().padLeft(2, '0')}';
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // CREATE ACCOUNT
  // ============================================================

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (password != confirmPassword) {
      _showError(_t('Passwords do not match.', 'पासवर्ड मेल नहीं खाते हैं।'));
      return;
    }

    final databaseDob = _getDatabaseDate();

    if (databaseDob == null) {
      _showError(
        _t(
          'Please select a valid date of birth.',
          'कृपया सही जन्म तिथि चुनें।',
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final mobile = widget.mobileNumber.trim();

      // ========================================================
      // CHECK EXISTING MOBILE
      // ========================================================

      debugPrint('==========================================');
      debugPrint('CHECKING EXISTING VILLAGER');
      debugPrint('Mobile: $mobile');
      debugPrint('==========================================');

      final existing = await _supabase
          .from('profiles')
          .select('id, mobile, role, user_id')
          .eq('mobile', mobile)
          .maybeSingle();

      if (existing != null) {
        if (!mounted) return;

        _showError(
          _t(
            'An account with this mobile number already exists.',
            'इस मोबाइल नंबर से पहले से एक खाता मौजूद है।',
          ),
        );

        return;
      }

      // ========================================================
      // CREATE SUPABASE AUTH ACCOUNT
      // ========================================================

      final email = '$mobile@villager.morpanchayat.app';

      debugPrint('==========================================');
      debugPrint('CREATING VILLAGER AUTH ACCOUNT');
      debugPrint('Email: $email');
      debugPrint('==========================================');

      final authResponse = await _supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = authResponse.user;
      final session = authResponse.session;

      if (user == null) {
        throw Exception('Unable to create authentication account.');
      }

      debugPrint('Auth user created: ${user.id}');
      debugPrint('Session exists: ${session != null}');

      // ========================================================
      // SESSION REQUIRED
      // ========================================================

      if (session == null) {
        throw Exception(
          'Account created but no active session was returned. '
          'Please disable email confirmation in Supabase.',
        );
      }

      // ========================================================
      // PREPARE PROFILE DATA
      // ========================================================

      final profileData = <String, dynamic>{
        'user_id': user.id,
        'email': email,
        'name': _nameController.text.trim(),
        'role': 'villager',
        'mobile': mobile,

        // PERSONAL DETAILS
        'father_name': _fatherNameController.text.trim(),
        'mother_name': _motherNameController.text.trim(),
        'gender': _selectedGender,
        'date_of_birth': databaseDob,

        // PANCHAYAT DETAILS
        'ward_number': _wardController.text.trim(),

        'house_number': _houseController.text.trim().isEmpty
            ? null
            : _houseController.text.trim(),

        'created_at': DateTime.now().toIso8601String(),

        'updated_at': DateTime.now().toIso8601String(),
      };

      debugPrint('==========================================');
      debugPrint('INSERTING VILLAGER PROFILE');
      debugPrint('Profile: $profileData');
      debugPrint('==========================================');

      // ========================================================
      // INSERT PROFILE
      // ========================================================

      await _supabase.from('profiles').insert(profileData);

      debugPrint('==========================================');
      debugPrint('VILLAGER PROFILE CREATED SUCCESSFULLY');
      debugPrint('User ID: ${user.id}');
      debugPrint('Name: ${_nameController.text.trim()}');
      debugPrint('Father: ${_fatherNameController.text.trim()}');
      debugPrint('Mother: ${_motherNameController.text.trim()}');
      debugPrint('Gender: $_selectedGender');
      debugPrint('DOB: $databaseDob');
      debugPrint('Ward: ${_wardController.text.trim()}');
      debugPrint('House: ${_houseController.text.trim()}');
      debugPrint('==========================================');

      if (!mounted) return;

      // ========================================================
      // SUCCESS
      // ========================================================

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Account created successfully.', 'खाता सफलतापूर्वक बनाया गया।'),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: green,
        ),
      );

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // ========================================================
      // GO TO VILLAGER HOME
      // ========================================================

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => VillagerHomePage(isHindi: widget.isHindi),
        ),
        (route) => false,
      );
    } on AuthException catch (e) {
      debugPrint('==========================================');
      debugPrint('SUPABASE AUTH ERROR');
      debugPrint('Message: ${e.message}');
      debugPrint('Status: ${e.statusCode}');
      debugPrint('Code: ${e.code}');
      debugPrint('==========================================');

      if (!mounted) return;

      _showError(_friendlyAuthError(e));
    } on PostgrestException catch (e) {
      debugPrint('==========================================');
      debugPrint('SUPABASE DATABASE ERROR');
      debugPrint('Message: ${e.message}');
      debugPrint('Code: ${e.code}');
      debugPrint('Details: ${e.details}');
      debugPrint('Hint: ${e.hint}');
      debugPrint('==========================================');

      if (!mounted) return;

      _showError(_friendlyDatabaseError(e));
    } catch (e) {
      debugPrint('==========================================');
      debugPrint('UNEXPECTED ERROR');
      debugPrint('$e');
      debugPrint('==========================================');

      if (!mounted) return;

      _showError(
        _t(
          'Unable to create your account. Please try again.',
          'खाता बनाने में समस्या हुई। कृपया पुनः प्रयास करें।',
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
  // AUTH ERROR
  // ============================================================

  String _friendlyAuthError(AuthException e) {
    final message = e.message.toLowerCase();

    if (message.contains('already registered') ||
        message.contains('already exists')) {
      return _t(
        'An account with this mobile number already exists.',
        'इस मोबाइल नंबर से पहले से एक खाता मौजूद है।',
      );
    }

    if (message.contains('password')) {
      return _t(
        'Please choose a stronger password.',
        'कृपया एक मजबूत पासवर्ड चुनें।',
      );
    }

    if (message.contains('email')) {
      return _t(
        'Unable to create the account email.',
        'खाता ईमेल बनाने में समस्या हुई।',
      );
    }

    return e.message;
  }

  // ============================================================
  // DATABASE ERROR
  // ============================================================

  String _friendlyDatabaseError(PostgrestException e) {
    debugPrint('Database error code: ${e.code}');

    if (e.message.contains('mother_name')) {
      return _t(
        'The mother name field is missing from the profiles table.',
        'profiles तालिका में माता के नाम का कॉलम मौजूद नहीं है।',
      );
    }

    if (e.message.contains('house_number')) {
      return _t(
        'The house number field is missing from the profiles table.',
        'profiles तालिका में मकान नंबर का कॉलम मौजूद नहीं है।',
      );
    }

    if (e.code == '23505') {
      return _t('This account already exists.', 'यह खाता पहले से मौजूद है।');
    }

    if (e.code == '42501') {
      return _t(
        'You do not have permission to create this profile.',
        'आपको यह प्रोफ़ाइल बनाने की अनुमति नहीं है।',
      );
    }

    return _t(
      'Unable to save your profile information.',
      'आपकी प्रोफ़ाइल जानकारी सेव नहीं हो सकी।',
    );
  }

  // ============================================================
  // ERROR SNACKBAR
  // ============================================================

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFB42318),
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // VALIDATOR
  // ============================================================

  String? _requiredValidator(String? value, String english, String hindi) {
    if (value == null || value.trim().isEmpty) {
      return _t(english, hindi);
    }

    return null;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _nameController.dispose();
    _fatherNameController.dispose();
    _motherNameController.dispose();
    _dobController.dispose();
    _wardController.dispose();
    _houseController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: darkGreen,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 18),
            child: Center(
              child: Text(
                widget.isHindi ? 'English' : 'हिन्दी',
                style: const TextStyle(
                  color: green,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
            children: [
              // ==================================================
              // HEADER
              // ==================================================
              _buildHeader(),

              const SizedBox(height: 28),

              // ==================================================
              // TITLE
              // ==================================================
              Text(
                _t('Create Your Account', 'अपना खाता बनाएँ'),
                style: const TextStyle(
                  color: darkGreen,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.4,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                _t(
                  'Enter your personal information to create your Villager account.',
                  'अपना पंचायत खाता बनाने के लिए अपनी व्यक्तिगत जानकारी दर्ज करें।',
                ),
                style: const TextStyle(
                  color: muted,
                  fontSize: 13.5,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 26),

              // ==================================================
              // ACCOUNT INFORMATION CARD
              // ==================================================
              _buildSectionHeader(
                icon: Icons.person_outline_rounded,
                title: _t('Personal Information', 'व्यक्तिगत जानकारी'),
              ),

              const SizedBox(height: 14),

              // MOBILE
              _buildLabel(_t('Mobile Number', 'मोबाइल नंबर')),

              _buildInput(
                controller: TextEditingController(
                  text: '+91 ${widget.mobileNumber}',
                ),
                prefixIcon: Icons.phone_android_rounded,
                enabled: false,
              ),

              const SizedBox(height: 17),

              // NAME
              _buildLabel(_t('Full Name *', 'पूरा नाम *')),

              _buildInput(
                controller: _nameController,
                hint: _t('Enter your full name', 'अपना पूरा नाम दर्ज करें'),
                prefixIcon: Icons.person_outline_rounded,
                validator: (value) => _requiredValidator(
                  value,
                  'Name is required',
                  'नाम आवश्यक है',
                ),
              ),

              const SizedBox(height: 17),

              // FATHER NAME
              _buildLabel(_t("Father's Name *", 'पिता का नाम *')),

              _buildInput(
                controller: _fatherNameController,
                hint: _t("Enter father's name", 'पिता का नाम दर्ज करें'),
                prefixIcon: Icons.person_outline_rounded,
                validator: (value) => _requiredValidator(
                  value,
                  "Father's name is required",
                  'पिता का नाम आवश्यक है',
                ),
              ),

              const SizedBox(height: 17),

              // MOTHER NAME
              _buildLabel(_t("Mother's Name *", 'माता का नाम *')),

              _buildInput(
                controller: _motherNameController,
                hint: _t("Enter mother's name", 'माता का नाम दर्ज करें'),
                prefixIcon: Icons.person_outline_rounded,
                validator: (value) => _requiredValidator(
                  value,
                  "Mother's name is required",
                  'माता का नाम आवश्यक है',
                ),
              ),

              const SizedBox(height: 17),

              // GENDER
              _buildLabel(_t('Gender *', 'लिंग *')),
              _buildGenderSelector(),

              const SizedBox(height: 17),

              // DOB
              _buildLabel(_t('Date of Birth *', 'जन्म तिथि *')),

              _buildInput(
                controller: _dobController,
                hint: _t('DD / MM / YYYY', 'DD / MM / YYYY'),
                prefixIcon: Icons.calendar_month_rounded,
                readOnly: true,
                onTap: _selectDateOfBirth,
                validator: (value) => _requiredValidator(
                  value,
                  'Date of birth is required',
                  'जन्म तिथि आवश्यक है',
                ),
              ),

              const SizedBox(height: 25),

              // ==================================================
              // PANCHAYAT INFORMATION
              // ==================================================
              _buildSectionHeader(
                icon: Icons.location_on_outlined,
                title: _t('Panchayat Information', 'पंचायत जानकारी'),
              ),

              const SizedBox(height: 14),

              // WARD
              _buildLabel(_t('Ward Number *', 'वार्ड नंबर *')),

              _buildInput(
                controller: _wardController,
                hint: _t('Enter your ward number', 'अपना वार्ड नंबर दर्ज करें'),
                prefixIcon: Icons.location_city_outlined,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return _t(
                      'Ward number is required',
                      'वार्ड नंबर आवश्यक है',
                    );
                  }

                  final ward = int.tryParse(value.trim());

                  if (ward == null || ward <= 0) {
                    return _t(
                      'Enter a valid ward number',
                      'सही वार्ड नंबर दर्ज करें',
                    );
                  }

                  return null;
                },
              ),

              const SizedBox(height: 17),

              // HOUSE
              _buildLabel(_t('House Number', 'मकान नंबर')),

              _buildInput(
                controller: _houseController,
                hint: _t(
                  'Enter house number (optional)',
                  'मकान नंबर दर्ज करें (वैकल्पिक)',
                ),
                prefixIcon: Icons.home_outlined,
              ),

              const SizedBox(height: 25),

              // ==================================================
              // PASSWORD
              // ==================================================
              _buildSectionHeader(
                icon: Icons.lock_outline_rounded,
                title: _t('Account Password', 'खाता पासवर्ड'),
              ),

              const SizedBox(height: 14),

              Text(
                _t(
                  'Create a password that you will use to login to Mor Panchayat.',
                  'ऐसा पासवर्ड बनाएँ जिसका उपयोग आप Mor Panchayat में लॉगिन करने के लिए करेंगे।',
                ),
                style: const TextStyle(
                  color: muted,
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 16),

              // PASSWORD
              _buildLabel(_t('Password *', 'पासवर्ड *')),

              _buildInput(
                controller: _passwordController,
                hint: _t('Create a password', 'पासवर्ड बनाएँ'),
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscurePassword,
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
                    color: muted,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return _t('Password is required', 'पासवर्ड आवश्यक है');
                  }

                  if (value.length < 6) {
                    return _t(
                      'Password must be at least 6 characters',
                      'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए',
                    );
                  }

                  return null;
                },
              ),

              const SizedBox(height: 17),

              // CONFIRM PASSWORD
              _buildLabel(_t('Confirm Password *', 'पासवर्ड की पुष्टि करें *')),

              _buildInput(
                controller: _confirmPasswordController,
                hint: _t(
                  'Confirm your password',
                  'अपना पासवर्ड दोबारा दर्ज करें',
                ),
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: _obscureConfirmPassword,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                  icon: Icon(
                    _obscureConfirmPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: muted,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return _t(
                      'Please confirm your password',
                      'कृपया अपना पासवर्ड दोबारा दर्ज करें',
                    );
                  }

                  if (value != _passwordController.text) {
                    return _t(
                      'Passwords do not match',
                      'पासवर्ड मेल नहीं खाते',
                    );
                  }

                  return null;
                },
              ),

              const SizedBox(height: 25),

              // ==================================================
              // SECURITY CARD
              // ==================================================
              _buildSecurityCard(),

              const SizedBox(height: 25),

              // ==================================================
              // CREATE ACCOUNT
              // ==================================================
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createAccount,
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
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 21,
                            ),
                            const SizedBox(width: 9),
                            Text(
                              _t('CREATE ACCOUNT', 'खाता बनाएँ'),
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: .4,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 14),

              Center(
                child: Text(
                  _t(
                    'By creating an account, you agree to use Mor Panchayat responsibly.',
                    'खाता बनाकर आप Mor Panchayat का जिम्मेदारी से उपयोग करने के लिए सहमत होते हैं।',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: muted,
                    fontSize: 10.5,
                    height: 1.4,
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
  // GENDER SELECTOR
  // ============================================================

  Widget _genderCard({
    required String value,
    required String title,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? lightGreen : Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? green : border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: selected ? Colors.white : lightGreen,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, color: green, size: 21),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: darkGreen,
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ),

              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 20,
                width: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? green : Colors.transparent,
                  border: Border.all(
                    color: selected ? green : const Color(0xFFB7C4BE),
                    width: 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 14,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _genderCard(
                value: 'male',
                title: _t('Male', 'पुरुष'),
                icon: Icons.male_rounded,
                selected: _selectedGender == 'male',
                onTap: () {
                  setState(() {
                    _selectedGender = 'male';
                  });
                },
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: _genderCard(
                value: 'female',
                title: _t('Female', 'महिला'),
                icon: Icons.female_rounded,
                selected: _selectedGender == 'female',
                onTap: () {
                  setState(() {
                    _selectedGender = 'female';
                  });
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // NOT SELECTED
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedGender = null;
              });
            },
            borderRadius: BorderRadius.circular(17),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: _selectedGender == null ? lightGreen : Colors.white,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: _selectedGender == null ? green : border,
                  width: _selectedGender == null ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    height: 34,
                    width: 34,
                    decoration: BoxDecoration(
                      color: _selectedGender == null
                          ? Colors.white
                          : lightGreen,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.remove_rounded,
                      color: green,
                      size: 20,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      _t('Not selected', 'चयन नहीं किया गया'),
                      style: TextStyle(
                        color: darkGreen,
                        fontSize: 13,
                        fontWeight: _selectedGender == null
                            ? FontWeight.w800
                            : FontWeight.w600,
                      ),
                    ),
                  ),

                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: 20,
                    width: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _selectedGender == null
                          ? green
                          : Colors.transparent,
                      border: Border.all(
                        color: _selectedGender == null
                            ? green
                            : const Color(0xFFB7C4BE),
                        width: 1.5,
                      ),
                    ),
                    child: _selectedGender == null
                        ? const Icon(
                            Icons.check_rounded,
                            color: Colors.white,
                            size: 14,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 74,
          height: 74,
          decoration: BoxDecoration(
            color: lightGreen,
            borderRadius: BorderRadius.circular(23),
          ),
          child: const Icon(
            Icons.account_balance_rounded,
            color: green,
            size: 40,
          ),
        ),

        const SizedBox(height: 13),

        const Text(
          'MOR PANCHAYAT',
          style: TextStyle(
            color: green,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.3,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          _t('Your Panchayat, Your Community', 'आपकी पंचायत, आपका समुदाय'),
          style: const TextStyle(color: muted, fontSize: 12.5),
        ),
      ],
    );
  }

  // ============================================================
  // SECTION HEADER
  // ============================================================

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: lightGreen,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: green, size: 20),
        ),

        const SizedBox(width: 11),

        Text(
          title,
          style: const TextStyle(
            color: darkGreen,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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
          color: darkGreen,
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  // ============================================================
  // INPUT
  // ============================================================

  Widget _buildInput({
    required TextEditingController controller,
    String? hint,
    IconData? prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
    bool enabled = true,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      readOnly: readOnly,
      onTap: onTap,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,

      style: const TextStyle(
        color: darkGreen,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),

      decoration: InputDecoration(
        hintText: hint,

        hintStyle: const TextStyle(
          color: Color(0xFF9AA59F),
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
        ),

        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: muted, size: 21)
            : null,

        suffixIcon: suffixIcon,

        filled: true,

        fillColor: enabled ? Colors.white : const Color(0xFFEFF3F1),

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
          borderSide: const BorderSide(color: border),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: green, width: 1.5),
        ),

        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: border),
        ),

        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),

        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
        ),
      ),
    );
  }

  // ============================================================
  // SECURITY CARD
  // ============================================================

  Widget _buildSecurityCard() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFD2E8DE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: green,
              size: 21,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Your information is secure', 'आपकी जानकारी सुरक्षित है'),
                  style: const TextStyle(
                    color: darkGreen,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  _t(
                    'Your personal details are stored securely and are used only for your Panchayat account.',
                    'आपकी व्यक्तिगत जानकारी सुरक्षित रूप से संग्रहीत की जाती है और केवल आपके पंचायत खाते के लिए उपयोग की जाती है।',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF52645C),
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
