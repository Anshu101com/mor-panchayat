import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddMemberPage extends StatefulWidget {
  final bool isHindi;

  const AddMemberPage({super.key, required this.isHindi});

  @override
  State<AddMemberPage> createState() => _AddMemberPageState();
}

class _AddMemberPageState extends State<AddMemberPage>
    with TickerProviderStateMixin {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryGreen = Color(0xFF176B4D);
  static const Color lightGreen = Color(0xFFEAF5F0);
  static const Color darkText = Color(0xFF18352B);
  static const Color mutedText = Color(0xFF718078);

  // ============================================================
  // FORM
  // ============================================================

  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _wardController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  // ============================================================
  // BUBBLES
  // ============================================================

  late AnimationController _bubbleController;
  late List<_Bubble> _bubbles;

  // ============================================================
  // LANGUAGE
  // ============================================================

  String _t(String english, String hindi) {
    return widget.isHindi ? hindi : english;
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    final random = Random();

    _bubbles = List.generate(
      20,
      (_) => _Bubble(
        size: 40 + random.nextDouble() * 110,
        left: random.nextDouble(),
        top: random.nextDouble(),
        opacity: 0.02 + random.nextDouble() * 0.045,
        speed: 0.6 + random.nextDouble() * 1.5,
        phase: random.nextDouble() * pi * 2,
      ),
    );

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _bubbleController.dispose();

    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _wardController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: Stack(
        children: [
          // ------------------------------------------------------
          // ANIMATED BUBBLE BACKGROUND
          // ------------------------------------------------------
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bubbleController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _BubblePainter(
                    bubbles: _bubbles,
                    animationValue: _bubbleController.value,
                  ),
                );
              },
            ),
          ),

          // ------------------------------------------------------
          // PAGE CONTENT
          // ------------------------------------------------------
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 35),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeaderCard(),

                          const SizedBox(height: 28),

                          _buildSectionTitle(
                            _t('Member Information', 'सदस्य की जानकारी'),
                          ),

                          const SizedBox(height: 12),

                          _buildTextField(
                            controller: _nameController,
                            label: _t('Member Name', 'सदस्य का नाम'),
                            hint: _t('Enter full name', 'पूरा नाम दर्ज करें'),
                            icon: Icons.person_outline_rounded,
                            textCapitalization: TextCapitalization.words,
                          ),

                          _buildTextField(
                            controller: _mobileController,
                            label: _t('Mobile Number', 'मोबाइल नंबर'),
                            hint: _t(
                              'Enter 10-digit mobile number',
                              '10 अंकों का मोबाइल नंबर दर्ज करें',
                            ),
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            maxLength: 10,
                          ),

                          _buildTextField(
                            controller: _wardController,
                            label: _t('Ward Number', 'वार्ड नंबर'),
                            hint: _t(
                              'Enter ward number',
                              'वार्ड नंबर दर्ज करें',
                            ),
                            icon: Icons.location_on_outlined,
                            keyboardType: TextInputType.number,
                          ),

                          const SizedBox(height: 10),

                          _buildSectionTitle(
                            _t('Login Information', 'लॉगिन जानकारी'),
                          ),

                          const SizedBox(height: 12),

                          _buildTextField(
                            controller: _emailController,
                            label: _t('Email / Login ID', 'ईमेल / लॉगिन ID'),
                            hint: _t(
                              'Enter login email',
                              'लॉगिन ईमेल दर्ज करें',
                            ),
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),

                          _buildTextField(
                            controller: _passwordController,
                            label: _t('Password', 'पासवर्ड'),
                            hint: _t('Create a password', 'पासवर्ड बनाएँ'),
                            icon: Icons.lock_outline_rounded,
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
                                color: mutedText,
                              ),
                            ),
                          ),

                          const SizedBox(height: 2),

                          _buildInfoCard(),

                          const SizedBox(height: 25),

                          _buildCreateButton(),

                          const SizedBox(height: 14),

                          Center(
                            child: Text(
                              _t(
                                'The member will be added to your Panchayat automatically.',
                                'सदस्य आपके पंचायत में स्वतः जोड़ दिया जाएगा।',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: mutedText,
                                fontSize: 11.5,
                                height: 1.4,
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
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          // BACK BUTTON
          _backButton(),

          const SizedBox(width: 12),

          // MOR PANCHAYAT BRAND
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: primaryGreen,
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: primaryGreen.withOpacity(0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'Mor Panchayat',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: darkText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BACK BUTTON
  // ============================================================

  Widget _backButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: darkText,
            size: 21,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER CARD
  // ============================================================

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF176B4D), Color(0xFF22815E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.20),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: Colors.white,
              size: 31,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Add New Member', 'नया सदस्य जोड़ें'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  _t(
                    'Create a Panchayat member account',
                    'पंचायत सदस्य का खाता बनाएँ',
                  ),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
                    fontSize: 12.5,
                    height: 1.35,
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
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(String title) {
    return Row(
      children: [
        Container(
          height: 7,
          width: 7,
          decoration: const BoxDecoration(
            color: primaryGreen,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 9),

        Text(
          title,
          style: const TextStyle(
            color: darkText,
            fontSize: 16,
            fontWeight: FontWeight.w800,
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
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    int? maxLength,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        maxLength: maxLength,
        textCapitalization: textCapitalization,

        validator: (value) {
          final text = value?.trim() ?? '';

          if (text.isEmpty) {
            return _t('This field is required', 'यह जानकारी आवश्यक है');
          }

          if (controller == _mobileController && text.length != 10) {
            return _t(
              'Enter a valid 10-digit mobile number',
              '10 अंकों का सही मोबाइल नंबर दर्ज करें',
            );
          }

          if (controller == _emailController && !text.contains('@')) {
            return _t('Enter a valid email address', 'सही ईमेल दर्ज करें');
          }

          if (controller == _passwordController && text.length < 6) {
            return _t(
              'Password must be at least 6 characters',
              'पासवर्ड कम से कम 6 अक्षरों का होना चाहिए',
            );
          }

          return null;
        },

        decoration: InputDecoration(
          labelText: label,
          hintText: hint,

          prefixIcon: Icon(icon, color: primaryGreen, size: 21),

          suffixIcon: suffixIcon,

          filled: true,
          fillColor: Colors.white,

          counterText: maxLength != null ? '' : null,

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),

          labelStyle: const TextStyle(color: mutedText, fontSize: 13),

          hintStyle: const TextStyle(color: Color(0xFFA1AAA5), fontSize: 12),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: primaryGreen, width: 1.5),
          ),

          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.red.shade400),
          ),

          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // INFO CARD
  // ============================================================

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryGreen.withOpacity(0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 38,
            width: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: primaryGreen,
              size: 21,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Member Account', 'सदस्य खाता'),
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  _t(
                    'The member will receive these login details and will be connected to your Panchayat automatically.',
                    'सदस्य को ये लॉगिन जानकारी दी जाएगी और उसे आपके पंचायत से स्वतः जोड़ दिया जाएगा।',
                  ),
                  style: const TextStyle(
                    color: mutedText,
                    fontSize: 11.5,
                    height: 1.45,
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
  // CREATE BUTTON
  // ============================================================

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createMember,

        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,

          disabledBackgroundColor: primaryGreen.withOpacity(0.55),

          elevation: 3,

          shadowColor: primaryGreen.withOpacity(0.25),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),

        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.person_add_alt_1_rounded, size: 21),

                  const SizedBox(width: 9),

                  Text(
                    _t('Create Member', 'सदस्य जोड़ें'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ============================================================
  // CREATE MEMBER
  // ============================================================

  Future<void> _createMember() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'create-member',
        body: {
          'name': _nameController.text.trim(),
          'mobile': _mobileController.text.trim(),
          'email': _emailController.text.trim(),
          'ward_number': _wardController.text.trim(),
          'password': _passwordController.text,
        },
      );

      final data = response.data;

      if (data is Map && data['success'] == true) {
        if (!mounted) return;

        _showMessage(
          _t('Member created successfully', 'सदस्य सफलतापूर्वक जोड़ा गया'),
          success: true,
        );

        Navigator.pop(context, true);
        return;
      }

      String message = _t('Could not create member', 'सदस्य नहीं जोड़ा जा सका');

      if (data is Map && data['message'] != null) {
        message = data['message'].toString();
      }

      if (!mounted) return;

      _showMessage(message);
    } on FunctionException catch (e) {
      if (!mounted) return;

      _showMessage(
        e.details?.toString() ?? _t('Something went wrong', 'कुछ गलत हो गया'),
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        _t(
          'Something went wrong. Please try again.',
          'कुछ गलत हो गया। कृपया पुनः प्रयास करें।',
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
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
            ),

            const SizedBox(width: 10),

            Expanded(child: Text(message)),
          ],
        ),

        backgroundColor: success ? primaryGreen : Colors.red.shade700,

        behavior: SnackBarBehavior.floating,

        margin: const EdgeInsets.all(16),

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

// ============================================================
// BUBBLE MODEL
// ============================================================

class _Bubble {
  final double size;
  final double left;
  final double top;
  final double opacity;
  final double speed;
  final double phase;

  _Bubble({
    required this.size,
    required this.left,
    required this.top,
    required this.opacity,
    required this.speed,
    required this.phase,
  });
}

// ============================================================
// BUBBLE PAINTER
// ============================================================

class _BubblePainter extends CustomPainter {
  final List<_Bubble> bubbles;
  final double animationValue;

  _BubblePainter({required this.bubbles, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (final bubble in bubbles) {
      final wave = sin((animationValue * pi * 2 * bubble.speed) + bubble.phase);

      final dx = bubble.left * size.width + wave * 12;

      final dy = bubble.top * size.height + cos(wave + bubble.phase) * 10;

      final paint = Paint()
        ..color = const Color(0xFF176B4D).withOpacity(bubble.opacity);
      canvas.drawCircle(Offset(dx, dy), bubble.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
