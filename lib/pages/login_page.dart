import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'panchayat_member_login_page.dart';
import 'package:mor_panchayat/services/animated_bubble_background.dart';
import 'package:mor_panchayat/pages/villagers_pages/villager_personal_info_page.dart';
import 'package:mor_panchayat/pages/villagers_pages/villager_login_page.dart';

class LoginPage extends StatefulWidget {
  final bool isHindi;

  const LoginPage({super.key, required this.isHindi});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late bool isHindi;

  final TextEditingController mobileController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    isHindi = widget.isHindi;
  }

  @override
  void dispose() {
    mobileController.dispose();
    super.dispose();
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final title = isHindi
        ? 'Mor Panchayat में लॉगिन करें'
        : 'Login to Mor Panchayat';

    final subtitle = isHindi
        ? 'अपने पंचायत की सेवाओं से जुड़े रहने के लिए लॉगिन करें'
        : 'Login to stay connected with your Panchayat services';

    final mobileLabel = isHindi ? 'मोबाइल नंबर' : 'Mobile Number';

    final mobileHint = isHindi
        ? 'अपना 10 अंकों का मोबाइल नंबर दर्ज करें'
        : 'Enter your 10-digit mobile number';

    final buttonText = isHindi ? 'आगे बढ़ें' : 'Continue';

    final adminText = isHindi ? 'पंचायत सदस्य? ' : 'Panchayat Member? ';

    final adminButton = isHindi ? 'यहाँ क्लिक करें' : 'Press Here';

    return Scaffold(
      body: AnimatedBubbleBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // ======================================================
              // BACK BUTTON
              // ======================================================
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
                        color: Colors.white.withOpacity(0.88),
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

              // ======================================================
              // LANGUAGE BUTTON
              // ======================================================
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
                        color: Colors.white.withOpacity(0.88),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDDE6E1)),
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

              // ======================================================
              // MAIN CONTENT
              // ======================================================
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(28, 70, 28, 30),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      children: [
                        SizedBox(height: size.height * 0.025),

                        // ==================================================
                        // LOGO
                        // ==================================================
                        Container(
                          width: 94,
                          height: 94,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.94),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.07),
                                blurRadius: 28,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 68,
                              height: 68,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF176B4D),
                              ),
                              child: const Icon(
                                Icons.account_balance_rounded,
                                color: Colors.white,
                                size: 36,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ==================================================
                        // TITLE
                        // ==================================================
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            title,
                            key: ValueKey(title),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              letterSpacing: -0.4,
                              color: Color(0xFF17352B),
                            ),
                          ),
                        ),

                        const SizedBox(height: 13),

                        // ==================================================
                        // SUBTITLE
                        // ==================================================
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
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

                        const SizedBox(height: 35),

                        // ==================================================
                        // LOGIN CARD
                        // ==================================================
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.94),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: const Color(0xFFDDE6E1)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.045),
                                blurRadius: 25,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ==========================================
                              // MOBILE LABEL
                              // ==========================================
                              Text(
                                mobileLabel,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF53635D),
                                ),
                              ),

                              const SizedBox(height: 9),

                              // ==========================================
                              // MOBILE INPUT
                              // ==========================================
                              TextField(
                                controller: mobileController,
                                keyboardType: TextInputType.phone,
                                maxLength: 10,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF24352F),
                                ),
                                decoration: InputDecoration(
                                  counterText: '',
                                  hintText: mobileHint,
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
                                    child: const Icon(
                                      Icons.phone_rounded,
                                      color: Color(0xFF176B4D),
                                      size: 20,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF8FAF9),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 17,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFDDE6E1),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFDDE6E1),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF176B4D),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 18),

                              // ==========================================
                              // CONTINUE BUTTON
                              // ==========================================
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _continue,
                                  style: ElevatedButton.styleFrom(
                                    elevation: 7,
                                    shadowColor: const Color(
                                      0xFF176B4D,
                                    ).withOpacity(0.25),
                                    backgroundColor: const Color(0xFF176B4D),
                                    disabledBackgroundColor: const Color(
                                      0xFF176B4D,
                                    ).withOpacity(0.55),
                                    foregroundColor: Colors.white,
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
                                            Text(
                                              buttonText,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(width: 9),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 21,
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ==================================================
                        // PANCHAYAT MEMBER
                        // ==================================================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              adminText,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            GestureDetector(
                              onTap: _presshere,
                              child: Text(
                                adminButton,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF176B4D),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 28),

                        // ==================================================
                        // SECURITY FOOTER
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
                                  ? 'आपकी जानकारी सुरक्षित है'
                                  : 'Your information is secure',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 18),
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

  // ================================================================
  // CONTINUE
  // ================================================================

  Future<void> _continue() async {
    FocusScope.of(context).unfocus();

    final mobile = mobileController.text.trim();

    // ============================================================
    // VALIDATE NUMBER
    // ============================================================

    if (mobile.length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF17352B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            isHindi
                ? 'कृपया सही 10 अंकों का मोबाइल नंबर दर्ज करें'
                : 'Please enter a valid 10-digit mobile number',
          ),
        ),
      );

      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ==========================================================
      // CHECK SUPABASE
      // ==========================================================

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('id, role, mobile')
          .eq('mobile', mobile)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      // ==========================================================
      // EXISTING VILLAGER
      // ==========================================================

      if (profile != null) {
        final role = profile['role']?.toString().toLowerCase().trim();

        if (role == 'villager') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  VillagerLoginPage(isHindi: isHindi, mobileNumber: mobile),
            ),
          );

          return;
        }

        // Number belongs to another account type
        _showError(
          isHindi
              ? 'यह नंबर किसी अन्य खाते से जुड़ा है।'
              : 'This number belongs to another account type.',
        );

        return;
      }

      // ==========================================================
      // NEW VILLAGER
      // ==========================================================

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              VillagerPersonalInfoPage(isHindi: isHindi, mobileNumber: mobile),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('======================================');
      debugPrint('VILLAGER MOBILE CHECK ERROR');
      debugPrint('ERROR: $e');
      debugPrint('STACK TRACE: $stackTrace');
      debugPrint('======================================');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF17352B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text('$e', maxLines: 4, overflow: TextOverflow.ellipsis),
        ),
      );
    }
  }

  // ================================================================
  // PANCHAYAT MEMBER LOGIN
  // ================================================================

  void _presshere() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PanchayatMemberLoginPage(isHindi: isHindi),
      ),
    );
  }

  // ================================================================
  // LANGUAGE SELECTOR
  // ================================================================

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

  // ================================================================
  // LANGUAGE OPTION
  // ================================================================

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
