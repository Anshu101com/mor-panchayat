import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mor_panchayat/pages/welcome_page.dart';

import 'package:mor_panchayat/pages/for_all/announcement_page.dart';
import 'package:mor_panchayat/pages/for_all/ward_management_page.dart';
import 'package:mor_panchayat/pages/for_all/show_announcement_page.dart';
import 'package:mor_panchayat/pages/sarpanch_pages/add_member_page.dart';
import 'package:mor_panchayat/pages/sarpanch_pages/manage_member_page.dart';
import 'package:mor_panchayat/pages/sarpanch_pages/village_management_page.dart';

class SarpanchHomePage extends StatefulWidget {
  final bool isHindi;
  final String sarpanchName;
  final String mobileNumber;

  const SarpanchHomePage({
    super.key,
    required this.isHindi,
    required this.sarpanchName,
    required this.mobileNumber,
  });

  @override
  State<SarpanchHomePage> createState() => _SarpanchHomePageState();
}

class _SarpanchHomePageState extends State<SarpanchHomePage>
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
  // ANIMATION
  // ============================================================

  late AnimationController _bubbleController;
  late List<_Bubble> _bubbles;

  // ============================================================
  // NAVIGATION
  // ============================================================

  int _selectedIndex = 0;

  // ============================================================
  // MEMBER COUNT
  // ============================================================

  int _memberCount = 0;
  bool _memberCountLoading = true;

  RealtimeChannel? _memberRealtimeChannel;

  final SupabaseClient _supabase = Supabase.instance.client;

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

    _loadMemberCount();
    _setupMemberRealtime();
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
    if (_memberRealtimeChannel != null) {
      _supabase.removeChannel(_memberRealtimeChannel!);
    }

    _bubbleController.dispose();

    super.dispose();
  }

  // ============================================================
  // TRANSLATION
  // ============================================================

  String _t(String english, String hindi) {
    return widget.isHindi ? hindi : english;
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
          // ANIMATED BACKGROUND
          // ======================================================
          Positioned.fill(
            child: IgnorePointer(
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
          ),

          // ======================================================
          // MAIN CONTENT
          // ======================================================
          SafeArea(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildDashboard(), // 0
                _buildMembersPage(), // 1
                _buildAnnouncementsPage(), // 2
                _buildProfilePage(), // 3
              ],
            ),
          ),
        ],
      ),

      // ==========================================================
      // BOTTOM NAVIGATION
      // ==========================================================
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _buildDashboard() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: _buildTopBar(),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
            child: _buildWelcomeCard(),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
            child: _sectionTitle(_t('Village Overview', 'गाँव का अवलोकन')),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _buildStatistics(),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
            child: _sectionTitle(_t('Quick Management', 'त्वरित प्रबंधन')),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
            child: _buildQuickManagement(),
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
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Row(
      children: [
        _roundButton(icon: Icons.menu_rounded, onTap: _showMenu),

        const SizedBox(width: 12),

        Expanded(
          child: Row(
            children: [
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

              const Flexible(
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
            ],
          ),
        ),

        _notificationButton(),
      ],
    );
  }

  // ============================================================
  // WELCOME CARD
  // ============================================================

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
              border: Border.all(color: Colors.white.withOpacity(0.20)),
            ),
            child: const Icon(
              Icons.emoji_people_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Welcome back', 'स्वागत है'),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  widget.sarpanchName.isEmpty
                      ? _t('Sarpanch', 'सरपंच')
                      : widget.sarpanchName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),

                const SizedBox(height: 6),

                Row(
                  children: [
                    const Icon(
                      Icons.emoji_people_rounded,
                      color: Colors.white70,
                      size: 14,
                    ),

                    const SizedBox(width: 4),

                    Expanded(
                      child: Text(
                        _t('Panchayat Sarpanch', 'ग्राम पंचायत सरपंच'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
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
        ],
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
            icon: Icons.groups_rounded,
            number: _memberCountLoading ? '...' : _memberCount.toString(),
            title: _t('Panchayat People', 'पंचायत सदस्य'),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _statCard(
            icon: Icons.location_on_rounded,
            number: '—',
            title: _t('Wards', 'वार्ड'),
          ),
        ),
      ],
    );
  }

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
                  maxLines: 2,
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
  // QUICK MANAGEMENT
  // ============================================================

  Widget _buildQuickManagement() {
    return Column(
      children: [
        _managementTile(
          icon: Icons.person_add_alt_1_rounded,
          title: _t('Add Panchayat Member', 'पंचायत सदस्य जोड़ें'),
          subtitle: _t('Create a new member account', 'नया सदस्य खाता बनाएँ'),
          onTap: _addMember,
        ),

        const SizedBox(height: 12),

        _managementTile(
          icon: Icons.groups_rounded,
          title: _t('Manage Members', 'सदस्यों का प्रबंधन'),
          subtitle: _t(
            'View and manage Panchayat members',
            'पंचायत सदस्यों को देखें और प्रबंधित करें',
          ),
          onTap: _goToMembersPage,
        ),

        const SizedBox(height: 12),

        _managementTile(
          icon: Icons.campaign_rounded,
          title: _t('Create Announcement', 'घोषणा बनाएँ'),
          subtitle: _t(
            'Share information with villagers',
            'ग्रामीणों के साथ जानकारी साझा करें',
          ),
          onTap: _createAnnouncement,
        ),

        const SizedBox(height: 12),

        _managementTile(
          icon: Icons.location_on_rounded,
          title: _t('Manage Wards', 'वार्ड प्रबंधन'),
          subtitle: _t(
            'Add and manage village wards',
            'गाँव के वार्ड जोड़ें और प्रबंधित करें',
          ),
          onTap: _manageWards,
        ),
      ],
    );
  }

  // ============================================================
  // MANAGEMENT TILE
  // ============================================================

  Widget _managementTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
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
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: primaryGreen, size: 25),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: darkText,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: mutedText,
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: primaryGreen,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ANNOUNCEMENTS
  // ============================================================

  Widget _buildAnnouncementsPage() {
    return ShowAnnouncementPage(isHindi: widget.isHindi);
  }

  // ============================================================
  // PROFILE
  // ============================================================

  Widget _buildProfilePage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _t('Sarpanch Profile', 'सरपंच प्रोफ़ाइल'),
            style: const TextStyle(
              color: darkText,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 22),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  height: 86,
                  width: 86,
                  decoration: const BoxDecoration(
                    color: lightGreen,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emoji_people_rounded,
                    color: primaryGreen,
                    size: 44,
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  widget.sarpanchName.isEmpty
                      ? _t('Sarpanch', 'सरपंच')
                      : widget.sarpanchName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  _t('Panchayat Sarpanch', 'ग्राम पंचायत सरपंच'),
                  style: const TextStyle(color: mutedText, fontSize: 13),
                ),

                const SizedBox(height: 24),

                _profileInfo(
                  Icons.phone_rounded,
                  _t('Mobile Number', 'मोबाइल नंबर'),
                  widget.mobileNumber,
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          GestureDetector(
            onTap: _logout,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.06),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout_rounded, color: Colors.redAccent),

                  const SizedBox(width: 9),

                  Text(
                    _t('Logout', 'लॉग आउट'),
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w800,
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
  // PROFILE INFO
  // ============================================================

  Widget _profileInfo(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              value.isEmpty ? '-' : value,
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
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigation() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(
                icon: Icons.home_rounded,
                label: _t('Home', 'होम'),
                index: 0,
              ),

              _navItem(
                icon: Icons.groups_rounded,
                label: _t('Members', 'सदस्य'),
                index: 1,
              ),

              _navItem(
                icon: Icons.campaign_rounded,
                label: _t('Announcements', 'घोषणाएँ'),
                index: 2,
              ),

              _navItem(
                icon: Icons.person_rounded,
                label: _t('Profile', 'प्रोफ़ाइल'),
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NAV ITEM
  // ============================================================

  Widget _navItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final bool selected = _selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (_selectedIndex == index) {
            return;
          }

          setState(() {
            _selectedIndex = index;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: selected ? lightGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  color: selected ? primaryGreen : const Color(0xFF9AA49F),
                  size: 21,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? primaryGreen : const Color(0xFF9AA49F),
                  fontSize: 9,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ROUND BUTTON
  // ============================================================

  Widget _roundButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 44,
          width: 44,
          child: Icon(icon, color: darkText, size: 21),
        ),
      ),
    );
  }

  // ============================================================
  // NOTIFICATION BUTTON
  // ============================================================

  Widget _notificationButton() {
    return GestureDetector(
      onTap: () {
        _showComingSoon(_t('Notifications', 'सूचनाएँ'));
      },
      child: Container(
        height: 44,
        width: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.notifications_none_rounded,
              color: darkText,
              size: 23,
            ),

            Positioned(
              right: 9,
              top: 8,
              child: Container(
                height: 8,
                width: 8,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOAD MEMBER COUNT
  // ============================================================

  Future<void> _loadMemberCount() async {
    try {
      final response = await _supabase
          .from('profiles')
          .select(
            'id, email, name, role, mobile, ward_number, '
            'created_at, updated_at, user_id',
          )
          .order('name', ascending: true);

      if (!mounted) return;

      setState(() {
        _memberCount = response.length;
        _memberCountLoading = false;
      });
    } catch (e) {
      debugPrint('Member count error: $e');

      if (!mounted) return;

      setState(() {
        _memberCountLoading = false;
      });
    }
  }

  // ============================================================
  // REALTIME MEMBER COUNT
  // ============================================================

  void _setupMemberRealtime() {
    _memberRealtimeChannel = _supabase
        .channel('sarpanch-member-count')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            debugPrint(
              'Realtime profile change detected: '
              '${payload.eventType}',
            );

            _loadMemberCount();
          },
        )
        .subscribe();
  }

  // ============================================================
  // ADD MEMBER
  // ============================================================

  void _addMember() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddMemberPage(isHindi: widget.isHindi)),
    ).then((_) {
      _loadMemberCount();
    });
  }

  // ============================================================
  // CREATE ANNOUNCEMENT
  // ============================================================

  void _createAnnouncement() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnnouncementPage(isHindi: widget.isHindi),
      ),
    );
  }

  // ============================================================
  // MANAGE VILLAGE
  // ============================================================

  void _openManageVillage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VillageManagementPage(isHindi: widget.isHindi),
      ),
    );
  }

  // ============================================================
  // MANAGE MEMBERS
  // ============================================================

  void _openManageMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManageMemberPage(isHindi: widget.isHindi),
      ),
    );
  }

  // ============================================================
  // GO TO MEMBERS
  // ============================================================

  void _goToMembersPage() {
    if (!mounted) return;

    setState(() {
      _selectedIndex = 1;
    });
  }

  // ============================================================
  // MEMBERS PAGE
  // ============================================================

  Widget _buildMembersPage() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
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

                const SizedBox(width: 12),

                GestureDetector(
                  onTap: _openManageMembers,
                  child: Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      borderRadius: BorderRadius.circular(13),
                      boxShadow: [
                        BoxShadow(
                          color: primaryGreen.withOpacity(0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.manage_accounts_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 14),
            child: Text(
              _t('Panchayat Members', 'पंचायत सदस्य'),
              style: const TextStyle(
                color: darkText,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
            child: _manageMembersCard(),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
            child: _manageVillageCard(),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MANAGE MEMBERS CARD
  // ============================================================

  Widget _manageMembersCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openManageMembers,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(20),
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
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: primaryGreen,
                  size: 30,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t(
                        'Manage Panchayat Members',
                        'पंचायत सदस्यों का प्रबंधन',
                      ),
                      style: const TextStyle(
                        color: darkText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      _t(
                        'View, edit and manage all Panchayat people',
                        'सभी पंचायत सदस्यों को देखें और प्रबंधित करें',
                      ),
                      style: const TextStyle(
                        color: mutedText,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: mutedText,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MANAGE VILLAGE CARD
  // ============================================================

  Widget _manageVillageCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openManageVillage,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(20),
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
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.location_city_rounded,
                  color: primaryGreen,
                  size: 30,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Manage Village', 'गाँव का प्रबंधन'),
                      style: const TextStyle(
                        color: darkText,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      _t(
                        'View villagers, wards and villagers in each ward',
                        'ग्रामीणों, वार्डों और प्रत्येक वार्ड के ग्रामीणों को देखें',
                      ),
                      style: const TextStyle(
                        color: mutedText,
                        fontSize: 11,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: mutedText,
                size: 17,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MANAGE WARDS
  // ============================================================

  void _manageWards() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WardManagementPage(isHindi: widget.isHindi),
      ),
    );
  }

  // ============================================================
  // MENU
  // ============================================================

  void _showMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 5,
                width: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9E2DD),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 20),

              _menuTile(
                Icons.notifications_rounded,
                _t('Notifications', 'सूचनाएँ'),
              ),

              _menuTile(
                Icons.help_outline_rounded,
                _t('Help & Support', 'सहायता'),
              ),

              _menuTile(Icons.settings_rounded, _t('Settings', 'सेटिंग्स')),

              _menuTile(
                Icons.logout_rounded,
                _t('Logout', 'लॉग आउट'),
                isLogout: true,
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // MENU TILE
  // ============================================================

  Widget _menuTile(IconData icon, String title, {bool isLogout = false}) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: isLogout ? Colors.red.withOpacity(0.07) : lightGreen,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          icon,
          color: isLogout ? Colors.redAccent : primaryGreen,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isLogout ? Colors.redAccent : darkText,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      onTap: () {
        Navigator.pop(context);

        if (isLogout) {
          _logout();
        } else {
          _showComingSoon(title);
        }
      },
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    try {
      await _supabase.auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => WelcomePage()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Logout error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Unable to logout. Please try again.',
              'लॉग आउट नहीं हो सका। कृपया पुनः प्रयास करें।',
            ),
          ),
        ),
      );
    }
  }

  // ============================================================
  // COMING SOON
  // ============================================================

  void _showComingSoon(String title) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 58,
                width: 58,
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.construction_rounded,
                  color: primaryGreen,
                  size: 28,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                title,
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
                  'This section will be connected to the Supabase backend next.',
                  'यह सेक्शन अगले चरण में Supabase बैकएंड से जोड़ा जाएगा।',
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: mutedText,
                  height: 1.4,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 20),

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
                    _t('Okay', 'ठीक है'),
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

  const _Bubble({
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
  static const Color bubbleColor = Color(0xFF176B4D);

  final List<_Bubble> bubbles;
  final double animationValue;

  const _BubblePainter({required this.bubbles, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (final bubble in bubbles) {
      final progress = (animationValue * bubble.speed + bubble.phase) % 1.0;

      final double x = bubble.left * size.width + sin(progress * pi * 2) * 18;

      final double y = bubble.top * size.height + cos(progress * pi * 2) * 18;

      final Paint paint = Paint()
        ..color = bubbleColor.withOpacity(bubble.opacity);

      canvas.drawCircle(Offset(x, y), bubble.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.bubbles != bubbles;
  }
}
