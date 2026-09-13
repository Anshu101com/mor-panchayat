import 'package:flutter/material.dart';

import 'login_page.dart';
import 'package:mor_panchayat/services/animated_bubble_background.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool isHindi = true;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    final String title = isHindi
        ? 'Mor Panchayat में आपका स्वागत है'
        : 'Welcome to Mor Panchayat';

    final String subtitle = isHindi
        ? 'अपने पंचायत से जुड़े रहें'
        : 'Stay connected with your Panchayat';

    final String languageText = isHindi ? 'हिन्दी' : 'English';

    final String buttonText = isHindi ? 'शुरू करें' : "Let's Get Started";

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: AnimatedBubbleBackground(
        child: SafeArea(
          child: Stack(
            children: [
              // ==========================================================
              // MAIN CONTENT
              // ==========================================================
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Column(
                      children: [
                        SizedBox(height: size.height * 0.035),

                        // ==================================================
                        // PANCHAYAT ICON
                        // ==================================================
                        Container(
                          width: 105,
                          height: 105,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.92),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 30,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 76,
                              height: 76,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF176B4D),
                              ),
                              child: const Icon(
                                Icons.account_balance_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 36),

                        // ==================================================
                        // WELCOME TITLE
                        // ==================================================
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, 0.08),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: Text(
                            title,
                            key: ValueKey(title),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              letterSpacing: -0.5,
                              color: Color(0xFF17352B),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

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
                              fontSize: 17,
                              height: 1.5,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        SizedBox(height: size.height * 0.065),

                        // ==================================================
                        // LANGUAGE LABEL
                        // ==================================================
                        Align(
                          alignment: Alignment.centerLeft,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              isHindi ? 'भाषा चुनें' : 'Choose Language',
                              key: ValueKey(isHindi),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF53635D),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 9),

                        // ==================================================
                        // LANGUAGE SELECTOR
                        // ==================================================
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: _showLanguageSelector,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 17,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.94),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: const Color(0xFFDDE6E1),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.035),
                                    blurRadius: 15,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF4EF),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.language_rounded,
                                      color: Color(0xFF176B4D),
                                      size: 23,
                                    ),
                                  ),

                                  const SizedBox(width: 14),

                                  Expanded(
                                    child: AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: Text(
                                        languageText,
                                        key: ValueKey(languageText),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF24352F),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: Color(0xFF687871),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // ==================================================
                        // GET STARTED BUTTON
                        // ==================================================
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: _getStarted,
                            style: ElevatedButton.styleFrom(
                              elevation: 8,
                              shadowColor: const Color(
                                0xFF176B4D,
                              ).withOpacity(0.25),
                              backgroundColor: const Color(0xFF176B4D),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Row(
                                key: ValueKey(buttonText),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    buttonText,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Icon(
                                    Icons.arrow_forward_rounded,
                                    size: 21,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ==================================================
                        // FOOTER
                        // ==================================================
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shield_outlined,
                              size: 15,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 6),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Text(
                                isHindi
                                    ? 'सरल • सुरक्षित • जुड़े रहें'
                                    : 'Simple • Secure • Connected',
                                key: ValueKey(isHindi),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
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
                // Drag handle
                Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 22),

                // Title
                Text(
                  isHindi ? 'भाषा चुनें' : 'Choose Language',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF17352B),
                  ),
                ),

                const SizedBox(height: 18),

                // Hindi
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

                // English
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

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: selected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        key: ValueKey('selected'),
                        color: Color(0xFF176B4D),
                      )
                    : const SizedBox(
                        key: ValueKey('not_selected'),
                        width: 24,
                        height: 24,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // GET STARTED
  // ================================================================

  void _getStarted() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LoginPage(isHindi: isHindi)),
    );
  }
}
