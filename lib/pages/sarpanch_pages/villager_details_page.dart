import 'dart:math';

import 'package:flutter/material.dart';

class VillagerDetailsPage extends StatefulWidget {
  final bool isHindi;
  final Map<String, dynamic> villager;

  const VillagerDetailsPage({
    super.key,
    required this.isHindi,
    required this.villager,
  });

  @override
  State<VillagerDetailsPage> createState() => _VillagerDetailsPageState();
}

class _VillagerDetailsPageState extends State<VillagerDetailsPage>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryGreen = Color(0xFF176B4D);
  static const Color lightGreen = Color(0xFFEAF5F0);
  static const Color backgroundColor = Color(0xFFF7FAF8);
  static const Color darkText = Color(0xFF18352B);
  static const Color mutedText = Color(0xFF718078);

  // ============================================================
  // ANIMATION
  // ============================================================

  late AnimationController _bubbleController;
  late List<_Bubble> _bubbles;

  // ============================================================
  // TRANSLATION
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

    _createBubbles();

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  // ============================================================
  // CREATE BUBBLES
  // ============================================================

  void _createBubbles() {
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
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _bubbleController.dispose();
    super.dispose();
  }

  // ============================================================
  // SAFE VALUE
  // ============================================================

  String _value(String key) {
    final value = widget.villager[key];

    if (value == null) return '';

    return value.toString().trim();
  }

  // ============================================================
  // DISPLAY VALUE
  // ============================================================

  String _displayValue(
    String key, {
    String englishEmpty = 'Not available',
    String hindiEmpty = 'उपलब्ध नहीं',
  }) {
    final value = _value(key);

    if (value.isEmpty || value == 'null') {
      return _t(englishEmpty, hindiEmpty);
    }

    return value;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final name = _displayValue(
      'name',
      englishEmpty: 'Unknown Villager',
      hindiEmpty: 'अज्ञात ग्रामीण',
    );

    final fatherName = _displayValue(
      'father_name',
      englishEmpty: 'Father name not available',
      hindiEmpty: 'पिता का नाम उपलब्ध नहीं',
    );

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // ======================================================
          // ANIMATED BUBBLE BACKGROUND
          // ======================================================
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

          // ======================================================
          // MAIN CONTENT
          // ======================================================
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                // ==================================================
                // TOP BAR
                // ==================================================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: _buildTopBar(),
                  ),
                ),

                // ==================================================
                // PAGE HEADER
                // ==================================================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
                    child: _buildProfileHeader(
                      name: name,
                      fatherName: fatherName,
                    ),
                  ),
                ),

                // ==================================================
                // DETAILS TITLE
                // ==================================================
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                    child: Text(
                      _t('Villager Details', 'ग्रामीण का विवरण'),
                      style: const TextStyle(
                        color: darkText,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                // ==================================================
                // DETAILS
                // ==================================================
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 35),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _detailCard(
                        icon: Icons.person_outline_rounded,
                        title: _t('Full Name', 'पूरा नाम'),
                        value: _displayValue(
                          'name',
                          englishEmpty: 'Name not available',
                          hindiEmpty: 'नाम उपलब्ध नहीं',
                        ),
                      ),

                      _detailCard(
                        icon: Icons.man_rounded,
                        title: _t('Father Name', 'पिता का नाम'),
                        value: _displayValue(
                          'father_name',
                          englishEmpty: 'Father name not available',
                          hindiEmpty: 'पिता का नाम उपलब्ध नहीं',
                        ),
                      ),

                      _detailCard(
                        icon: Icons.woman_rounded,
                        title: _t('Mother Name', 'माता का नाम'),
                        value: _displayValue(
                          'mother_name',
                          englishEmpty: 'Mother name not available',
                          hindiEmpty: 'माता का नाम उपलब्ध नहीं',
                        ),
                      ),

                      _detailCard(
                        icon: Icons.phone_rounded,
                        title: _t('Mobile Number', 'मोबाइल नंबर'),
                        value: _displayValue(
                          'mobile',
                          englishEmpty: 'Mobile number not available',
                          hindiEmpty: 'मोबाइल नंबर उपलब्ध नहीं',
                        ),
                      ),

                      _detailCard(
                        icon: Icons.home_rounded,
                        title: _t('House Number', 'मकान नंबर'),
                        value: _displayValue(
                          'house_number',
                          englishEmpty: 'House number not available',
                          hindiEmpty: 'मकान नंबर उपलब्ध नहीं',
                        ),
                      ),

                      _detailCard(
                        icon: Icons.cake_rounded,
                        title: _t('Date of Birth', 'जन्म तिथि'),
                        value: _formatDateOfBirth(),
                      ),

                      const SizedBox(height: 8),

                      _buildInfoNote(),
                    ]),
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
    return Row(
      children: [
        // --------------------------------------------------------
        // BACK BUTTON
        // --------------------------------------------------------
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () {
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(14),
            child: const SizedBox(
              height: 44,
              width: 44,
              child: Icon(Icons.arrow_back_rounded, color: darkText, size: 21),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // --------------------------------------------------------
        // MOR PANCHAYAT ICONIC LOGO
        // --------------------------------------------------------
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

        // --------------------------------------------------------
        // TITLE
        // --------------------------------------------------------
        Expanded(
          child: Text(
            _t('Mor Panchayat', 'मोर पंचायत'),
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: darkText,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PROFILE HEADER
  // ============================================================

  Widget _buildProfileHeader({
    required String name,
    required String fatherName,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          // ------------------------------------------------------
          // PROFILE ICON
          // ------------------------------------------------------
          Container(
            height: 82,
            width: 82,
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(27),
            ),
            child: const Icon(
              Icons.person_rounded,
              color: primaryGreen,
              size: 43,
            ),
          ),

          const SizedBox(height: 16),

          // ------------------------------------------------------
          // NAME
          // ------------------------------------------------------
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: darkText,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 7),

          // ------------------------------------------------------
          // FATHER NAME
          // ------------------------------------------------------
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.man_rounded, color: mutedText, size: 16),

              const SizedBox(width: 5),

              Flexible(
                child: Text(
                  '${_t('Father', 'पिता')}: $fatherName',
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // ------------------------------------------------------
          // REGISTERED VILLAGER BADGE
          // ------------------------------------------------------
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_rounded,
                  color: primaryGreen,
                  size: 15,
                ),

                const SizedBox(width: 6),

                Text(
                  _t('Registered Villager', 'पंजीकृत ग्रामीण'),
                  style: const TextStyle(
                    color: primaryGreen,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
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
  // DETAIL CARD
  // ============================================================

  Widget _detailCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 13,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ------------------------------------------------------
          // ICON
          // ------------------------------------------------------
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: primaryGreen, size: 23),
          ),

          const SizedBox(width: 14),

          // ------------------------------------------------------
          // TEXT
          // ------------------------------------------------------
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
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
  // DATE OF BIRTH
  // ============================================================

  String _formatDateOfBirth() {
    final value = _value('date_of_birth');

    if (value.isEmpty) {
      return _t('Date of birth not available', 'जन्म तिथि उपलब्ध नहीं');
    }

    try {
      final date = DateTime.parse(value);

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      return '$day/$month/$year';
    } catch (_) {
      return value;
    }
  }

  // ============================================================
  // INFO NOTE
  // ============================================================

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightGreen.withOpacity(0.75),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: primaryGreen.withOpacity(0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: primaryGreen, size: 20),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              _t(
                'This information is retrieved from the registered villager profile.',
                'यह जानकारी पंजीकृत ग्रामीण की प्रोफ़ाइल से प्राप्त की गई है।',
              ),
              style: const TextStyle(
                color: darkText,
                fontSize: 11,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// BUBBLE MODEL
// ================================================================

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

// ================================================================
// BUBBLE PAINTER
// ================================================================

class _BubblePainter extends CustomPainter {
  final List<_Bubble> bubbles;
  final double animationValue;

  _BubblePainter({required this.bubbles, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (final bubble in bubbles) {
      final progress = (animationValue * bubble.speed + bubble.phase) % 1.0;

      final x = bubble.left * size.width + sin(progress * pi * 2) * 18;

      final y = bubble.top * size.height + cos(progress * pi * 2) * 18;

      final paint = Paint()
        ..color = const Color(0xFF176B4D).withOpacity(bubble.opacity);

      canvas.drawCircle(Offset(x, y), bubble.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
