import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mor_panchayat/pages/sarpanch_pages/villager_details_page.dart';

class WardVillagersPage extends StatefulWidget {
  final bool isHindi;
  final String wardNumber;

  const WardVillagersPage({
    super.key,
    required this.isHindi,
    required this.wardNumber,
  });

  @override
  State<WardVillagersPage> createState() => _WardVillagersPageState();
}

class _WardVillagersPageState extends State<WardVillagersPage>
    with TickerProviderStateMixin {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryGreen = Color(0xFF176B4D);
  static const Color lightGreen = Color(0xFFEAF5F0);
  static const Color backgroundColor = Color(0xFFF7FAF8);
  static const Color darkText = Color(0xFF18352B);
  static const Color mutedText = Color(0xFF718078);

  // ============================================================
  // SUPABASE
  // ============================================================

  final SupabaseClient _supabase = Supabase.instance.client;

  RealtimeChannel? _wardRealtimeChannel;

  // ============================================================
  // ANIMATION
  // ============================================================

  late AnimationController _bubbleController;
  late List<_Bubble> _bubbles;

  // ============================================================
  // DATA
  // ============================================================

  List<Map<String, dynamic>> _villagers = [];

  bool _isLoading = true;
  bool _isRefreshing = false;

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

    _loadVillagers();
    _setupRealtime();
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
    if (_wardRealtimeChannel != null) {
      _supabase.removeChannel(_wardRealtimeChannel!);
    }

    _bubbleController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD VILLAGERS
  // ============================================================

  Future<void> _loadVillagers() async {
    if (_isRefreshing) return;

    try {
      if (mounted) {
        setState(() {
          _isRefreshing = true;

          if (_villagers.isEmpty) {
            _isLoading = true;
          }
        });
      }

      final response = await _supabase
          .from('profiles')
          .select(
            'id, user_id, name, father_name, mother_name, gender, '
            'mobile, ward_number, house_number, date_of_birth, '
            'email, created_at, updated_at',
          )
          .eq('role', 'villager')
          .eq('ward_number', widget.wardNumber)
          .order('name', ascending: true);

      if (!mounted) return;

      setState(() {
        _villagers = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      debugPrint('Load ward villagers error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });

      _showMessage(
        _t(
          'Could not load villagers.',
          'ग्रामीणों का डेटा प्राप्त नहीं हो सका।',
        ),
        isError: true,
      );
    }
  }

  // ============================================================
  // REALTIME
  // ============================================================

  void _setupRealtime() {
    _wardRealtimeChannel = _supabase
        .channel('ward-villagers-${widget.wardNumber}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            debugPrint('Ward villagers profile change: ${payload.eventType}');

            _loadVillagers();
          },
        )
        .subscribe();
  }

  // ============================================================
  // OPEN VILLAGER DETAILS
  // ============================================================

  void _openVillagerDetails(Map<String, dynamic> villager) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            VillagerDetailsPage(isHindi: widget.isHindi, villager: villager),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
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
            child: RefreshIndicator(
              color: primaryGreen,
              onRefresh: _loadVillagers,
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
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
                      child: _buildPageHeader(),
                    ),
                  ),

                  // ==================================================
                  // VILLAGER COUNT
                  // ==================================================
                  if (!_isLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildVillagerSummary(),
                      ),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 22)),

                  // ==================================================
                  // LOADING
                  // ==================================================
                  if (_isLoading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(45),
                        child: Center(
                          child: CircularProgressIndicator(color: primaryGreen),
                        ),
                      ),
                    ),

                  // ==================================================
                  // EMPTY
                  // ==================================================
                  if (!_isLoading && _villagers.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyState()),

                  // ==================================================
                  // VILLAGERS
                  // ==================================================
                  if (!_isLoading && _villagers.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _villagerCard(_villagers[index]),
                          );
                        }, childCount: _villagers.length),
                      ),
                    ),
                ],
              ),
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

        // --------------------------------------------------------
        // REFRESH
        // --------------------------------------------------------
        GestureDetector(
          onTap: _isRefreshing ? null : _loadVillagers,
          child: Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: AnimatedRotation(
              turns: _isRefreshing ? 1 : 0,
              duration: const Duration(milliseconds: 500),
              child: const Icon(
                Icons.refresh_rounded,
                color: primaryGreen,
                size: 22,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PAGE HEADER
  // ============================================================

  Widget _buildPageHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('Ward ${widget.wardNumber}', 'वार्ड ${widget.wardNumber}'),
          style: const TextStyle(
            color: darkText,
            fontSize: 26,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          _t(
            'Villagers registered in this ward',
            'इस वार्ड में पंजीकृत ग्रामीण',
          ),
          style: const TextStyle(
            color: mutedText,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildVillagerSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: primaryGreen,
              size: 24,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _villagers.length.toString(),
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  _t('Total Villagers', 'कुल ग्रामीण'),
                  style: const TextStyle(
                    color: mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_t('Ward', 'वार्ड')} ${widget.wardNumber}',
              style: const TextStyle(
                color: primaryGreen,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VILLAGER CARD
  // ============================================================

  Widget _villagerCard(Map<String, dynamic> villager) {
    final name = villager['name']?.toString().trim().isNotEmpty == true
        ? villager['name'].toString().trim()
        : _t('Unknown Villager', 'अज्ञात ग्रामीण');

    final fatherName = villager['father_name']?.toString().trim() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openVillagerDetails(villager),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              // --------------------------------------------------
              // PERSON ICON
              // --------------------------------------------------
              Container(
                height: 54,
                width: 54,
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: primaryGreen,
                  size: 28,
                ),
              ),

              const SizedBox(width: 14),

              // --------------------------------------------------
              // NAME + FATHER
              // --------------------------------------------------
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: darkText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline_rounded,
                          color: mutedText,
                          size: 14,
                        ),

                        const SizedBox(width: 5),

                        Expanded(
                          child: Text(
                            fatherName.isEmpty
                                ? _t(
                                    'Father name not available',
                                    'पिता का नाम उपलब्ध नहीं है',
                                  )
                                : '${_t('Father', 'पिता')}: $fatherName',
                            maxLines: 1,
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
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // --------------------------------------------------
              // ARROW
              // --------------------------------------------------
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: primaryGreen,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 75,
            width: 75,
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(23),
            ),
            child: const Icon(
              Icons.groups_outlined,
              color: primaryGreen,
              size: 38,
            ),
          ),

          const SizedBox(height: 18),

          Text(
            _t('No Villagers Found', 'कोई ग्रामीण नहीं मिला'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: darkText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _t(
              'There are currently no villagers registered in Ward ${widget.wardNumber}.',
              'वार्ड ${widget.wardNumber} में अभी कोई ग्रामीण पंजीकृत नहीं है।',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: mutedText,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.redAccent : primaryGreen,
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
