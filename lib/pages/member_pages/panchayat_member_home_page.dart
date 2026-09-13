import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mor_panchayat/pages/welcome_page.dart';
import 'package:mor_panchayat/pages/sarpanch_pages/manage_member_page.dart';
import 'package:mor_panchayat/pages/for_all/announcement_page.dart';

class PanchayatMemberHomePage extends StatefulWidget {
  final bool isHindi;
  final String memberName;
  final String wardNumber;
  final String mobileNumber;

  const PanchayatMemberHomePage({
    super.key,
    required this.isHindi,
    required this.memberName,
    required this.wardNumber,
    required this.mobileNumber,
  });

  @override
  State<PanchayatMemberHomePage> createState() =>
      _PanchayatMemberHomePageState();
}

class _PanchayatMemberHomePageState extends State<PanchayatMemberHomePage>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // SUPABASE
  // ============================================================

  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // ANIMATION
  // ============================================================

  late final AnimationController _bubbleController;

  // ============================================================
  // REALTIME CHANNELS
  // ============================================================

  RealtimeChannel? _announcementChannel;
  RealtimeChannel? _profileChannel;

  // ============================================================
  // STATE
  // ============================================================

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isHindi = false;

  int _announcementCount = 0;
  int _memberCount = 0;

  List<Map<String, dynamic>> _latestAnnouncements = [];

  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  static const Color primaryGreen = Color(0xFF176B4D);
  static const Color secondaryGreen = Color(0xFF2E8B68);
  static const Color lightGreen = Color(0xFFEAF5F0);
  static const Color pageBackground = Color(0xFFF7FAF8);
  static const Color darkText = Color(0xFF18352B);
  static const Color mutedText = Color(0xFF718078);

  // ============================================================
  // TRANSLATION
  // ============================================================

  String _t(String english, String hindi) {
    return _isHindi ? hindi : english;
  }

  void _changeLanguage() {
    if (!mounted) return;

    setState(() {
      _isHindi = !_isHindi;
    });
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _isHindi = widget.isHindi;

    // ------------------------------------------------------------
    // System UI
    // ------------------------------------------------------------

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
        systemStatusBarContrastEnforced: false,
      ),
    );

    // ------------------------------------------------------------
    // Animated background
    // ------------------------------------------------------------

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    // ------------------------------------------------------------
    // Initial data loading
    // ------------------------------------------------------------

    unawaited(_loadDashboard());

    // ------------------------------------------------------------
    // Realtime
    // ------------------------------------------------------------

    _setupRealtime();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _bubbleController.dispose();

    if (_announcementChannel != null) {
      _supabase.removeChannel(_announcementChannel!);
    }

    if (_profileChannel != null) {
      _supabase.removeChannel(_profileChannel!);
    }

    super.dispose();
  }

  // ============================================================
  // LOAD DASHBOARD
  // ============================================================

  Future<void> _loadDashboard({bool showLoader = true}) async {
    if (!mounted) return;

    if (showLoader) {
      setState(() {
        _isLoading = true;
      });
    }

    bool announcementSuccess = false;
    bool profileSuccess = false;

    try {
      // ========================================================
      // ANNOUNCEMENTS
      // ========================================================

      try {
        final announcementResponse = await _supabase
            .from('announcements')
            .select()
            .order('created_at', ascending: false);

        final announcements = List<Map<String, dynamic>>.from(
          announcementResponse,
        );

        // ------------------------------------------------------
        // Find announcement creator IDs
        // ------------------------------------------------------

        final creatorIds = announcements
            .map((announcement) => announcement['created_by']?.toString())
            .whereType<String>()
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList();

        // ------------------------------------------------------
        // Load creator profiles
        // ------------------------------------------------------

        if (creatorIds.isNotEmpty) {
          try {
            final creatorResponse = await _supabase
                .from('profiles')
                .select('id, user_id, name, role, mobile, ward_number')
                .inFilter('user_id', creatorIds);

            final creatorProfiles = List<Map<String, dynamic>>.from(
              creatorResponse,
            );

            final Map<String, Map<String, dynamic>> creatorMap = {
              for (final profile in creatorProfiles)
                profile['user_id'].toString(): profile,
            };

            // --------------------------------------------------
            // Attach profile to each announcement
            // --------------------------------------------------

            for (final announcement in announcements) {
              final creatorId = announcement['created_by']?.toString();

              if (creatorId != null && creatorId.isNotEmpty) {
                announcement['creator_profile'] = creatorMap[creatorId];
              }
            }
          } catch (e) {
            debugPrint('CREATOR PROFILE LOAD ERROR: $e');
          }
        }

        // ------------------------------------------------------
        // Update announcement state
        // ------------------------------------------------------

        if (mounted) {
          setState(() {
            _latestAnnouncements = announcements.take(3).toList();
            _announcementCount = announcements.length;
          });
        }

        announcementSuccess = true;
      } catch (e) {
        debugPrint('====================================================');
        debugPrint('ANNOUNCEMENTS TABLE ERROR');
        debugPrint('Could not read announcements');
        debugPrint('$e');
        debugPrint('====================================================');
      }

      // ========================================================
      // PANCHAYAT MEMBERS
      // ========================================================

      try {
        final profileResponse = await _supabase
            .from('profiles')
            .select('id, user_id, name, role, mobile, ward_number, created_at')
            .eq('role', 'member');

        final profiles = List<Map<String, dynamic>>.from(profileResponse);

        if (mounted) {
          setState(() {
            _memberCount = profiles.length;
          });
        }

        profileSuccess = true;
      } catch (e) {
        debugPrint('====================================================');
        debugPrint('PROFILE TABLE ERROR');
        debugPrint('Could not read table: profiles');
        debugPrint('$e');
        debugPrint('====================================================');
      }

      // ========================================================
      // FINISHED
      // ========================================================

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });

      // ========================================================
      // ERROR MESSAGES
      // ========================================================

      if (!announcementSuccess && !profileSuccess) {
        _showMessage(
          _t('Could not load database data.', 'डेटाबेस डेटा लोड नहीं हो सका।'),
          isError: true,
        );
      } else if (!announcementSuccess) {
        _showMessage(
          _t('Announcements could not be loaded.', 'घोषणाएँ लोड नहीं हो सकीं।'),
          isError: true,
        );
      } else if (!profileSuccess) {
        _showMessage(
          _t('Member data could not be loaded.', 'सदस्य डेटा लोड नहीं हो सका।'),
          isError: true,
        );
      }
    } catch (e) {
      debugPrint('MEMBER HOME LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });

      _showMessage(
        _t('Could not load dashboard data.', 'डैशबोर्ड डेटा लोड नहीं हो सका।'),
        isError: true,
      );
    }
  }

  // ============================================================
  // REALTIME
  // ============================================================

  void _setupRealtime() {
    // ==========================================================
    // ANNOUNCEMENTS REALTIME
    // ==========================================================

    _announcementChannel = _supabase
        .channel('member-home-announcements-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'announcements',
          callback: (payload) {
            if (!mounted) return;

            debugPrint('ANNOUNCEMENT EVENT: ${payload.eventType}');

            unawaited(_loadDashboard(showLoader: false));
          },
        )
        .subscribe();

    // ==========================================================
    // PROFILES REALTIME
    // ==========================================================

    _profileChannel = _supabase
        .channel('member-home-profile-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            if (!mounted) return;

            debugPrint('PROFILE REALTIME EVENT: ${payload.eventType}');

            unawaited(_loadDashboard(showLoader: false));
          },
        )
        .subscribe();

    // ==========================================================
    // CHAT / COMMENT REALTIME REMOVED
    // ==========================================================
    //
    // Chat functionality has been removed from the app for now.
    //
    // No:
    // - chat channel
    // - chat messages listener
    // - chat rooms listener
    // - announcement_comments listener
    //
    // ==========================================================
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    if (_isRefreshing) return;

    if (!mounted) return;

    setState(() {
      _isRefreshing = true;
    });

    await _loadDashboard(showLoader: false);

    if (!mounted) return;

    setState(() {
      _isRefreshing = false;
    });
  }

  // ============================================================
  // OPEN ANNOUNCEMENTS
  // ============================================================

  void _openAnnouncements() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AnnouncementPage(isHindi: _isHindi)),
    ).then((_) {
      if (!mounted) return;

      unawaited(_loadDashboard(showLoader: false));
    });
  }

  // ============================================================
  // OPEN MANAGE MEMBERS
  // ============================================================

  void _openManageMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ManageMemberPage(isHindi: _isHindi)),
    ).then((_) {
      if (!mounted) return;

      unawaited(_loadDashboard(showLoader: false));
    });
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final screenWidth = MediaQuery.of(dialogContext).size.width;

        return AlertDialog(
          backgroundColor: Colors.white,
          elevation: 8,
          insetPadding: EdgeInsets.symmetric(
            horizontal: screenWidth < 360 ? 16 : 24,
            vertical: 24,
          ),
          contentPadding: const EdgeInsets.fromLTRB(22, 8, 22, 6),
          titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(25),
          ),
          title: Text(
            _t('Logout?', 'लॉगआउट करें?'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: darkText,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            _t(
              'Are you sure you want to logout?',
              'क्या आप वाकई लॉगआउट करना चाहते हैं?',
            ),
            style: const TextStyle(color: mutedText, fontSize: 14, height: 1.5),
          ),
          actions: [
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 6,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  child: Text(
                    _t('Cancel', 'रद्द करें'),
                    style: const TextStyle(
                      color: mutedText,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryGreen,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 11,
                    ),
                    minimumSize: const Size(0, 42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _t('Logout', 'लॉगआउट'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) return;

    try {
      await _supabase.auth.signOut();
    } catch (e) {
      debugPrint('LOGOUT ERROR: $e');
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? Colors.red.shade700 : primaryGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      backgroundColor: pageBackground,
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
                    painter: _MemberHomeBubblePainter(
                      animationValue: _bubbleController.value,
                      primaryGreen: primaryGreen,
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
            top: true,
            bottom: false,
            child: RefreshIndicator(
              color: primaryGreen,
              backgroundColor: Colors.white,
              onRefresh: _refresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildTopBar()),

                  SliverToBoxAdapter(child: _buildWelcomeCard()),

                  SliverToBoxAdapter(child: _buildQuickStats()),

                  SliverToBoxAdapter(
                    child: _buildSectionTitle(
                      _t('Panchayat Services', 'पंचायत सेवाएँ'),
                    ),
                  ),

                  SliverToBoxAdapter(child: _buildServicesGrid()),

                  SliverToBoxAdapter(
                    child: _buildSectionTitle(
                      _t('Latest Announcements', 'नवीनतम घोषणाएँ'),
                      actionText: _t('View All', 'सभी देखें'),
                      onAction: _openAnnouncements,
                    ),
                  ),

                  if (_isLoading)
                    SliverToBoxAdapter(child: _buildLoadingAnnouncements())
                  else if (_latestAnnouncements.isEmpty)
                    SliverToBoxAdapter(child: _buildNoAnnouncements())
                  else
                    SliverList(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        return _buildAnnouncementCard(
                          _latestAnnouncements[index],
                        );
                      }, childCount: _latestAnnouncements.length),
                    ),

                  SliverToBoxAdapter(child: _buildProfileCard()),

                  const SliverToBoxAdapter(child: SizedBox(height: 35)),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 10, 17, 8),
      child: Row(
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              color: primaryGreen,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: primaryGreen.withOpacity(0.18),
                  blurRadius: 13,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.account_balance_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),

          const SizedBox(width: 11),

          const Expanded(
            child: Text(
              'Mor Panchayat',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: darkText,
              ),
            ),
          ),

          Material(
            color: Colors.white.withOpacity(0.90),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _changeLanguage,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Text(
                    _isHindi ? 'अं' : 'अ',
                    style: const TextStyle(
                      color: primaryGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          Material(
            color: Colors.white.withOpacity(0.90),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _showProfileMenu,
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.person_outline_rounded, color: primaryGreen),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WELCOME CARD
  // ============================================================

  Widget _buildWelcomeCard() {
    final name = widget.memberName.trim().isEmpty
        ? _t('Panchayat Member', 'पंचायत सदस्य')
        : widget.memberName.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 10, 17, 15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: primaryGreen,
          borderRadius: BorderRadius.circular(27),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(0.22),
              blurRadius: 25,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -20,
              top: -35,
              child: Container(
                width: 125,
                height: 125,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.055),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            Positioned(
              right: 45,
              bottom: -65,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.045),
                  shape: BoxShape.circle,
                ),
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(17),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),

                    const SizedBox(width: 13),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t('Welcome back', 'स्वागत है'),
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 3),

                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 19),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Colors.white,
                        size: 16,
                      ),

                      const SizedBox(width: 6),

                      Text(
                        '${_t('Ward', 'वार्ड')} ${widget.wardNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                Text(
                  _t(
                    'Manage Panchayat activities and stay connected with your village.',
                    'पंचायत गतिविधियों को प्रबंधित करें और अपने गाँव से जुड़े रहें।',
                  ),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.80),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // QUICK STATS
  // ============================================================

  Widget _buildQuickStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 0, 17, 22),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              icon: Icons.campaign_rounded,
              title: _t('Announcements', 'घोषणाएँ'),
              value: _announcementCount.toString(),
              onTap: _openAnnouncements,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: _buildStatCard(
              icon: Icons.groups_rounded,
              title: _t('Members', 'सदस्य'),
              value: _memberCount.toString(),
              onTap: _openManageMembers,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STAT CARD
  // ============================================================

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.94),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE5EDE8)),
            boxShadow: [
              BoxShadow(
                color: primaryGreen.withOpacity(0.045),
                blurRadius: 15,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: primaryGreen, size: 22),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: darkText,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.8,
                        color: mutedText,
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
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(
    String title, {
    String? actionText,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(19, 0, 19, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: darkText,
              ),
            ),
          ),

          if (actionText != null && onAction != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                foregroundColor: primaryGreen,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: Text(
                actionText,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // SERVICES GRID
  // ============================================================

  Widget _buildServicesGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 0, 17, 23),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildServiceCard(
                  icon: Icons.campaign_rounded,
                  title: _t('Announcements', 'घोषणाएँ'),
                  subtitle: _t('Village information', 'गाँव की जानकारी'),
                  onTap: _openAnnouncements,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _buildServiceCard(
                  icon: Icons.groups_rounded,
                  title: _t('Members', 'सदस्य'),
                  subtitle: _t('Panchayat members', 'पंचायत सदस्य'),
                  onTap: _openManageMembers,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  // ============================================================
  // SERVICE CARD
  // ============================================================

  Widget _buildServiceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.94),
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(21),
        child: Container(
          constraints: const BoxConstraints(minHeight: 132),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: const Color(0xFFE5EDE8)),
            boxShadow: [
              BoxShadow(
                color: primaryGreen.withOpacity(0.045),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 47,
                height: 47,
                decoration: BoxDecoration(
                  color: lightGreen,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: primaryGreen, size: 24),
              ),

              const SizedBox(height: 13),

              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: darkText,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, color: mutedText),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ANNOUNCEMENT CARD
  // ============================================================

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final title = announcement['title']?.toString() ?? '';

    final content = announcement['content']?.toString() ?? '';

    final createdAt = announcement['created_at']?.toString();

    final updatedAt = announcement['updated_at']?.toString();

    final date = _formatDate(updatedAt ?? createdAt);

    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 0, 17, 12),
      child: Material(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(21),
        child: InkWell(
          onTap: _openAnnouncements,
          borderRadius: BorderRadius.circular(21),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(21),
              border: Border.all(color: const Color(0xFFE5EDE8)),
              boxShadow: [
                BoxShadow(
                  color: primaryGreen.withOpacity(0.045),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: lightGreen,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: primaryGreen,
                    size: 23,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? _t('Announcement', 'घोषणा') : title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: darkText,
                          height: 1.3,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: mutedText,
                          height: 1.4,
                        ),
                      ),

                      if (date.isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 12,
                              color: mutedText,
                            ),

                            const SizedBox(width: 4),

                            Text(
                              date,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: mutedText,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 5),

                const Icon(
                  Icons.chevron_right_rounded,
                  color: mutedText,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOADING ANNOUNCEMENTS
  // ============================================================

  Widget _buildLoadingAnnouncements() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 0, 17, 20),
      child: Container(
        height: 105,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: const Color(0xFFE5EDE8)),
        ),
        child: const Center(
          child: SizedBox(
            width: 25,
            height: 25,
            child: CircularProgressIndicator(
              strokeWidth: 2.3,
              color: primaryGreen,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // NO ANNOUNCEMENTS
  // ============================================================

  Widget _buildNoAnnouncements() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 0, 17, 20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: const Color(0xFFE5EDE8)),
        ),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: lightGreen,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.campaign_outlined,
                color: primaryGreen,
                size: 29,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              _t('No announcements yet', 'अभी कोई घोषणा नहीं है'),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: darkText,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              _t(
                'New village announcements will appear here.',
                'नई गाँव की घोषणाएँ यहाँ दिखाई देंगी।',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: mutedText,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE CARD
  // ============================================================

  Widget _buildProfileCard() {
    final displayName = widget.memberName.trim().isEmpty
        ? _t('Panchayat Member', 'पंचायत सदस्य')
        : widget.memberName.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(17, 10, 17, 0),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.94),
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: const Color(0xFFE5EDE8)),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: lightGreen,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: primaryGreen,
                size: 25,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: darkText,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    '${_t('Ward', 'वार्ड')} ${widget.wardNumber}',
                    style: const TextStyle(fontSize: 11.5, color: mutedText),
                  ),

                  if (widget.mobileNumber.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      widget.mobileNumber,
                      style: const TextStyle(fontSize: 11.5, color: mutedText),
                    ),
                  ],
                ],
              ),
            ),

            IconButton(
              onPressed: _showProfileMenu,
              icon: const Icon(Icons.more_vert_rounded, color: mutedText),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE MENU
  // ============================================================

  void _showProfileMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 25),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9E3DE),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 20),

              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: lightGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: primaryGreen,
                  size: 29,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                widget.memberName.trim().isEmpty
                    ? _t('Panchayat Member', 'पंचायत सदस्य')
                    : widget.memberName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: darkText,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                '${_t('Ward', 'वार्ड')} ${widget.wardNumber}',
                style: const TextStyle(fontSize: 12, color: mutedText),
              ),

              const SizedBox(height: 20),

              _buildBottomSheetItem(
                icon: Icons.groups_rounded,
                title: _t(
                  'Manage Panchayat Members',
                  'पंचायत सदस्य प्रबंधित करें',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);

                  _openManageMembers();
                },
              ),

              _buildBottomSheetItem(
                icon: Icons.campaign_rounded,
                title: _t('Announcements', 'घोषणाएँ'),
                onTap: () {
                  Navigator.pop(sheetContext);

                  _openAnnouncements();
                },
              ),

              _buildBottomSheetItem(
                icon: Icons.logout_rounded,
                title: _t('Logout', 'लॉगआउट'),
                danger: true,
                onTap: () {
                  Navigator.pop(sheetContext);

                  unawaited(_logout());
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // BOTTOM SHEET ITEM
  // ============================================================

  Widget _buildBottomSheetItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final color = danger ? Colors.red.shade600 : primaryGreen;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: danger ? Colors.red.shade50 : const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
            child: Row(
              children: [
                Icon(icon, color: color, size: 21),

                const SizedBox(width: 12),

                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: danger ? Colors.red.shade700 : darkText,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                Icon(
                  Icons.chevron_right_rounded,
                  color: danger ? Colors.red.shade300 : mutedText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }

    try {
      final date = DateTime.parse(value).toLocal();

      final day = date.day.toString().padLeft(2, '0');

      final month = date.month.toString().padLeft(2, '0');

      final year = date.year.toString();

      final hour = date.hour.toString().padLeft(2, '0');

      final minute = date.minute.toString().padLeft(2, '0');

      return '$day/$month/$year • $hour:$minute';
    } catch (_) {
      return value;
    }
  }
}

// ================================================================
// ANIMATED BACKGROUND
// ================================================================

class _MemberHomeBubblePainter extends CustomPainter {
  final double animationValue;
  final Color primaryGreen;

  static final List<_MemberBubbleData> _bubbles = _createBubbles();

  const _MemberHomeBubblePainter({
    required this.animationValue,
    required this.primaryGreen,
  });

  // --------------------------------------------------------------
  // CREATE BUBBLES
  // --------------------------------------------------------------

  static List<_MemberBubbleData> _createBubbles() {
    final random = Random(42);

    return List.generate(17, (index) {
      return _MemberBubbleData(
        radius: 25 + random.nextDouble() * 70,
        x: random.nextDouble(),
        y: random.nextDouble(),
        phase: random.nextDouble() * pi * 2,
        opacity: 0.014 + random.nextDouble() * 0.025,
      );
    });
  }

  // --------------------------------------------------------------
  // PAINT
  // --------------------------------------------------------------

  @override
  void paint(Canvas canvas, Size size) {
    final time = animationValue * 2 * pi;

    for (final bubble in _bubbles) {
      final movementX = sin(time + bubble.phase) * 14;

      final movementY = cos(time * 0.85 + bubble.phase) * 12;

      final x = bubble.x * size.width + movementX;

      final y = bubble.y * size.height + movementY;

      final paint = Paint()..color = primaryGreen.withOpacity(bubble.opacity);

      canvas.drawCircle(Offset(x, y), bubble.radius, paint);
    }
  }

  // --------------------------------------------------------------
  // REPAINT
  // --------------------------------------------------------------

  @override
  bool shouldRepaint(covariant _MemberHomeBubblePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

// ================================================================
// BUBBLE DATA
// ================================================================

class _MemberBubbleData {
  final double radius;
  final double x;
  final double y;
  final double phase;
  final double opacity;

  const _MemberBubbleData({
    required this.radius,
    required this.x,
    required this.y,
    required this.phase,
    required this.opacity,
  });
}
