import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mor_panchayat/pages/sarpanch_pages/ward_villagers_page.dart';

class VillageManagementPage extends StatefulWidget {
  final bool isHindi;

  const VillageManagementPage({super.key, required this.isHindi});

  @override
  State<VillageManagementPage> createState() => _VillageManagementPageState();
}

class _VillageManagementPageState extends State<VillageManagementPage>
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

  RealtimeChannel? _villageRealtimeChannel;

  // ============================================================
  // ANIMATION
  // ============================================================

  late AnimationController _bubbleController;
  late List<_Bubble> _bubbles;

  // ============================================================
  // DATA
  // ============================================================

  bool _isLoading = true;
  bool _isRefreshing = false;

  int _totalVillagers = 0;
  int _totalWards = 0;

  List<_WardData> _wards = [];

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

    _loadVillageData();
    _setupRealtime();
  }

  // ============================================================
  // TRANSLATION
  // ============================================================

  String _t(String english, String hindi) {
    return widget.isHindi ? hindi : english;
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
    if (_villageRealtimeChannel != null) {
      _supabase.removeChannel(_villageRealtimeChannel!);
    }

    _bubbleController.dispose();

    super.dispose();
  }

  // ============================================================
  // LOAD VILLAGE DATA
  // ============================================================

  Future<void> _loadVillageData() async {
    if (_isRefreshing) return;

    try {
      if (mounted) {
        setState(() {
          _isRefreshing = true;

          if (_wards.isEmpty) {
            _isLoading = true;
          }
        });
      }

      // ----------------------------------------------------------
      // LOAD ALL PROFILES
      // ----------------------------------------------------------

      final response = await _supabase
          .from('profiles')
          .select('id, user_id, name, email, role, mobile, ward_number');

      final data = List<Map<String, dynamic>>.from(response);

      // ----------------------------------------------------------
      // FIND VILLAGERS
      // ----------------------------------------------------------

      final villagers = data.where((user) {
        final role = user['role']?.toString().trim().toLowerCase();

        return role == 'villager';
      }).toList();

      // ----------------------------------------------------------
      // FIND WARD NUMBERS
      // ----------------------------------------------------------

      final Set<int> wardNumbers = {};

      for (final villager in villagers) {
        final wardValue = villager['ward_number'];

        if (wardValue == null) continue;

        final wardNumber = int.tryParse(wardValue.toString().trim());

        if (wardNumber != null && wardNumber > 0) {
          wardNumbers.add(wardNumber);
        }
      }

      // ----------------------------------------------------------
      // ALSO INCLUDE WARD NUMBERS FROM OTHER PROFILES
      // ----------------------------------------------------------

      for (final user in data) {
        final wardValue = user['ward_number'];

        if (wardValue == null) continue;

        final wardNumber = int.tryParse(wardValue.toString().trim());

        if (wardNumber != null && wardNumber > 0) {
          wardNumbers.add(wardNumber);
        }
      }

      final sortedWards = wardNumbers.toList()..sort();

      // ----------------------------------------------------------
      // BUILD WARD DATA
      // ----------------------------------------------------------

      final List<_WardData> wardData = [];

      for (final wardNumber in sortedWards) {
        // --------------------------------------------------------
        // VILLAGERS IN THIS WARD
        // --------------------------------------------------------

        final wardVillagers = villagers.where((villager) {
          final value = villager['ward_number'];

          if (value == null) return false;

          return value.toString().trim() == wardNumber.toString();
        }).toList();

        // --------------------------------------------------------
        // FIND WARD HEAD
        // --------------------------------------------------------
        //
        // Currently this searches for a member/sarpanch assigned
        // to the same ward.
        //
        // Later, if you add a dedicated ward_head field, this can
        // be changed easily.
        // --------------------------------------------------------

        String wardHeadName = _t('Not Assigned', 'नियुक्त नहीं');

        final wardHeadCandidates = data.where((user) {
          final role = user['role']?.toString().trim().toLowerCase();

          final userWard = user['ward_number'];

          if (userWard == null) return false;

          final sameWard = userWard.toString().trim() == wardNumber.toString();

          final isPanchayatMember =
              role == 'member' || role == 'sarpanch' || role == 'sarpanch_user';

          return sameWard && isPanchayatMember;
        }).toList();

        if (wardHeadCandidates.isNotEmpty) {
          final name = wardHeadCandidates.first['name']?.toString().trim();

          if (name != null && name.isNotEmpty) {
            wardHeadName = name;
          }
        }

        wardData.add(
          _WardData(
            wardNumber: wardNumber,
            wardHeadName: wardHeadName,
            villagerCount: wardVillagers.length,
          ),
        );
      }

      // ----------------------------------------------------------
      // UPDATE UI
      // ----------------------------------------------------------

      if (!mounted) return;

      setState(() {
        _wards = wardData;
        _totalVillagers = villagers.length;
        _totalWards = wardData.length;

        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      debugPrint('Village management load error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });

      _showMessage(
        _t('Could not load village data.', 'गाँव का डेटा प्राप्त नहीं हो सका।'),
        isError: true,
      );
    }
  }

  // ============================================================
  // REALTIME
  // ============================================================

  void _setupRealtime() {
    _villageRealtimeChannel = _supabase
        .channel('village-management-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            debugPrint('Village profile change: ${payload.eventType}');

            _loadVillageData();
          },
        )
        .subscribe();
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
              onRefresh: _loadVillageData,
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
                  // PAGE TITLE
                  // ==================================================
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 18),
                      child: Text(
                        _t('Village Management', 'गाँव प्रबंधन'),
                        style: const TextStyle(
                          color: darkText,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  // ==================================================
                  // VILLAGE OVERVIEW
                  // ==================================================
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _sectionTitle(
                        _t('Village Overview', 'गाँव का अवलोकन'),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(child: SizedBox(height: 14)),

                  // ==================================================
                  // STATISTICS
                  // ==================================================
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _buildStatistics(),
                    ),
                  ),

                  // ==================================================
                  // WARD TITLE
                  // ==================================================
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
                      child: _sectionTitle(
                        _t('Village Wards', 'गाँव के वार्ड'),
                      ),
                    ),
                  ),

                  // ==================================================
                  // LOADING
                  // ==================================================
                  if (_isLoading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(
                          child: CircularProgressIndicator(color: primaryGreen),
                        ),
                      ),
                    ),

                  // ==================================================
                  // EMPTY
                  // ==================================================
                  if (!_isLoading && _wards.isEmpty)
                    SliverToBoxAdapter(child: _buildEmptyState()),

                  // ==================================================
                  // WARDS
                  // ==================================================
                  if (!_isLoading && _wards.isNotEmpty)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final ward = _wards[index];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildWardCard(ward),
                          );
                        }, childCount: _wards.length),
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
        // MOR PANCHAYAT LOGO
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
        const Expanded(
          child: Text(
            'Mor Panchayat',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
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
          onTap: _isRefreshing ? null : _loadVillageData,
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
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: darkText,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildStatistics() {
    return Row(
      children: [
        Expanded(
          child: _statCard(
            icon: Icons.location_on_rounded,
            number: _totalWards.toString(),
            title: _t('Wards', 'वार्ड'),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _statCard(
            icon: Icons.groups_rounded,
            number: _totalVillagers.toString(),
            title: _t('Villagers', 'ग्रामीण'),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _statCard({
    required IconData icon,
    required String number,
    required String title,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
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
            height: 45,
            width: 45,
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: primaryGreen, size: 22),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  number,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
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
  // WARD CARD
  // ============================================================

  Widget _buildWardCard(_WardData ward) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => WardVillagersPage(
                isHindi: widget.isHindi,
                wardNumber: ward.wardNumber.toString(),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
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
              // WARD NUMBER
              // --------------------------------------------------
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      ward.wardNumber.toString(),
                      style: const TextStyle(
                        color: primaryGreen,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    Text(
                      _t('WARD', 'वार्ड'),
                      style: const TextStyle(
                        color: primaryGreen,
                        fontSize: 7,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 15),

              // --------------------------------------------------
              // WARD INFORMATION
              // --------------------------------------------------
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_t('Ward', 'वार्ड')} ${ward.wardNumber}',
                      style: const TextStyle(
                        color: darkText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Row(
                      children: [
                        const Icon(
                          Icons.person_rounded,
                          color: mutedText,
                          size: 15,
                        ),

                        const SizedBox(width: 5),

                        Expanded(
                          child: Text(
                            ward.wardHeadName,
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

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        const Icon(
                          Icons.groups_rounded,
                          color: mutedText,
                          size: 15,
                        ),

                        const SizedBox(width: 5),

                        Text(
                          '${ward.villagerCount} ${_t('Villagers', 'ग्रामीण')}',
                          style: const TextStyle(
                            color: mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: mutedText,
                size: 16,
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
      ),
      child: Column(
        children: [
          Container(
            height: 65,
            width: 65,
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.location_city_rounded,
              color: primaryGreen,
              size: 32,
            ),
          ),

          const SizedBox(height: 15),

          Text(
            _t('No ward data available', 'वार्ड का डेटा उपलब्ध नहीं है'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: darkText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            _t(
              'Add ward numbers to villagers or Panchayat members to see them here.',
              'ग्रामीणों या पंचायत सदस्यों में वार्ड नंबर जोड़ें।',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: mutedText, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WARD DETAILS
  // ============================================================

  void _showWardDetails(_WardData ward) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // HANDLE
              Container(
                height: 5,
                width: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9E2DD),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 20),

              // ICON
              Container(
                height: 65,
                width: 65,
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: primaryGreen,
                  size: 32,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                '${_t('Ward', 'वार्ड')} ${ward.wardNumber}',
                style: const TextStyle(
                  color: darkText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 18),

              _detailRow(
                Icons.person_rounded,
                _t('Ward Head', 'वार्ड प्रमुख'),
                ward.wardHeadName,
              ),

              _detailRow(
                Icons.groups_rounded,
                _t('Villagers', 'ग्रामीण'),
                ward.villagerCount.toString(),
              ),

              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    _t('Close', 'बंद करें'),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // DETAIL ROW
  // ============================================================

  Widget _detailRow(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryGreen, size: 19),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(width: 10),

          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: darkText,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
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
// WARD DATA MODEL
// ================================================================

class _WardData {
  final int wardNumber;
  final String wardHeadName;
  final int villagerCount;

  const _WardData({
    required this.wardNumber,
    required this.wardHeadName,
    required this.villagerCount,
  });
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
