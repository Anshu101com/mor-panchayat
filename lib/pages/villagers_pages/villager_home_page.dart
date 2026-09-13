import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mor_panchayat/pages/welcome_page.dart';

class VillagerHomePage extends StatefulWidget {
  final bool isHindi;

  const VillagerHomePage({super.key, this.isHindi = false});

  @override
  State<VillagerHomePage> createState() => _VillagerHomePageState();
}

class _VillagerHomePageState extends State<VillagerHomePage>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _wardPanch;

  List<Map<String, dynamic>> _announcements = [];

  bool _isLoading = true;

  int _selectedIndex = 0;

  RealtimeChannel? _announcementChannel;

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

    _loadData();
    _setupRealtime();
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        return;
      }

      // --------------------------------------------------------
      // LOAD PROFILE
      // --------------------------------------------------------

      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      // --------------------------------------------------------
      // LOAD WARD PANCH
      // --------------------------------------------------------

      Map<String, dynamic>? wardPanch;

      if (profile != null) {
        final wardNumber = profile['ward_number']?.toString().trim();

        if (wardNumber != null && wardNumber.isNotEmpty) {
          wardPanch = await _supabase
              .from('profiles')
              .select('name, role, mobile, ward_number')
              .eq('role', 'member')
              .eq('ward_number', wardNumber)
              .limit(1)
              .maybeSingle();
        }
      }

      // --------------------------------------------------------
      // LOAD ANNOUNCEMENTS
      // --------------------------------------------------------

      final announcementsResponse = await _supabase
          .from('announcements')
          .select()
          .eq('is_published', true)
          .order('created_at', ascending: false)
          .limit(10);

      final announcements = List<Map<String, dynamic>>.from(
        announcementsResponse,
      );

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _wardPanch = wardPanch;
        _announcements = announcements;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Villager Home load error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // REALTIME - ANNOUNCEMENTS ONLY
  // ============================================================

  void _setupRealtime() {
    _announcementChannel = _supabase
        .channel('villager-home-announcements-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'announcements',
          callback: (payload) {
            _loadAnnouncementsOnly();
          },
        )
        .subscribe();
  }

  Future<void> _loadAnnouncementsOnly() async {
    try {
      final response = await _supabase
          .from('announcements')
          .select()
          .eq('is_published', true)
          .order('created_at', ascending: false)
          .limit(10);

      if (!mounted) return;

      setState(() {
        _announcements = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Announcement realtime refresh error: $e');
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    await _loadData();
  }

  // ============================================================
  // PROFILE VALUES
  // ============================================================

  String get _villagerName {
    return _profile?['name']?.toString() ?? _t('Villager', 'ग्रामीण');
  }

  String get _wardPanchName {
    final name = _wardPanch?['name']?.toString().trim();

    if (name == null || name.isEmpty) {
      return _t('Ward Panch not assigned', 'वार्ड पंच निर्धारित नहीं है');
    }

    return name;
  }

  String get _wardNumber {
    return _profile?['ward_number']?.toString() ?? '-';
  }

  String get _houseNumber {
    return _profile?['house_number']?.toString() ??
        _t('Not added', 'दर्ज नहीं');
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            _t('Logout?', 'लॉगआउट करें?'),
            style: const TextStyle(
              color: Color(0xFF18352B),
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Text(
            _t(
              'Are you sure you want to logout?',
              'क्या आप लॉगआउट करना चाहते हैं?',
            ),
            style: const TextStyle(color: Color(0xFF718078)),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: Text(
                _t('Cancel', 'रद्द करें'),
                style: const TextStyle(color: Color(0xFF176B4D)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF176B4D),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(_t('Logout', 'लॉगआउट')),
            ),
          ],
        );
      },
    );

    if (shouldLogout != true) {
      return;
    }

    try {
      await _supabase.auth.signOut();

      debugPrint('==========================================');
      debugPrint('VILLAGER LOGGED OUT');
      debugPrint('Session: ${_supabase.auth.currentSession}');
      debugPrint('==========================================');

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomePage()),
        (route) => false,
      );
    } catch (e) {
      debugPrint('Villager logout error: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              'Logout failed. Please try again.',
              'लॉगआउट विफल हुआ। कृपया पुनः प्रयास करें।',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // ANNOUNCEMENT DETAIL
  // ============================================================

  void _openAnnouncement(Map<String, dynamic> announcement) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final title =
            announcement['title']?.toString() ?? _t('Announcement', 'घोषणा');

        final description =
            announcement['description']?.toString() ??
            announcement['content']?.toString() ??
            '';

        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.82,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 45,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDDE6E1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF5F0),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: const Icon(
                      Icons.campaign_outlined,
                      color: Color(0xFF176B4D),
                      size: 28,
                    ),
                  ),

                  const SizedBox(height: 18),

                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF18352B),
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    description,
                    style: const TextStyle(
                      color: Color(0xFF52645C),
                      fontSize: 15,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [_buildHome(), _buildUpdatesPage(), _buildProfilePage()],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // ============================================================
  // HOME
  // ============================================================

  Widget _buildHome() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF176B4D)),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF176B4D),
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
        children: [
          _buildHeader(),

          const SizedBox(height: 22),

          _buildWelcomeCard(),

          const SizedBox(height: 25),

          _buildSectionTitle(
            _t('Latest Updates', 'नवीनतम अपडेट'),
            actionText: _t('View All', 'सभी देखें'),
            onAction: () {
              setState(() {
                _selectedIndex = 1;
              });
            },
          ),

          const SizedBox(height: 12),

          _buildLatestAnnouncement(),

          const SizedBox(height: 26),

          _buildSectionTitle(_t('Quick Services', 'त्वरित सेवाएँ')),

          const SizedBox(height: 13),

          _buildQuickServices(),

          const SizedBox(height: 27),

          _buildSectionTitle(_t('Recent Notices', 'हाल की सूचनाएँ')),

          const SizedBox(height: 12),

          _buildRecentAnnouncements(),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF5F0),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.account_balance_rounded,
            color: Color(0xFF176B4D),
            size: 25,
          ),
        ),

        const SizedBox(width: 11),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'MOR PANCHAYAT',
                style: TextStyle(
                  color: Color(0xFF176B4D),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: .7,
                ),
              ),
              Text(
                _t(
                  'Your Panchayat, Your Community',
                  'आपकी पंचायत, आपका समुदाय',
                ),
                style: const TextStyle(
                  color: Color(0xFF718078),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),

        _buildHeaderIcon(
          Icons.notifications_none_rounded,
          onTap: () {
            _showComingSoon(_t('Notifications', 'सूचनाएँ'));
          },
        ),

        const SizedBox(width: 8),

        _buildHeaderIcon(
          Icons.person_outline_rounded,
          onTap: () {
            setState(() {
              _selectedIndex = 2;
            });
          },
        ),
      ],
    );
  }

  Widget _buildHeaderIcon(IconData icon, {required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 43,
          height: 43,
          child: Icon(icon, color: const Color(0xFF18352B), size: 22),
        ),
      ),
    );
  }

  // ============================================================
  // WELCOME CARD
  // ============================================================

  Widget _buildWelcomeCard() {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: const Color(0xFF176B4D),
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Welcome back', 'स्वागत है'),
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),

                const SizedBox(height: 3),

                Text(
                  _villagerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 13),

                Row(
                  children: [
                    _buildInfoChip(
                      Icons.location_city_outlined,
                      '${_t('Ward', 'वार्ड')} $_wardNumber',
                    ),

                    const SizedBox(width: 8),

                    _buildInfoChip(
                      Icons.home_outlined,
                      '${_t('House', 'मकान')} $_houseNumber',
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Container(
            width: 65,
            height: 65,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.13),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.waving_hand_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 14),

          const SizedBox(width: 5),

          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
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
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF18352B),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        if (actionText != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              actionText,
              style: const TextStyle(
                color: Color(0xFF176B4D),
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // LATEST ANNOUNCEMENT
  // ============================================================

  Widget _buildLatestAnnouncement() {
    if (_announcements.isEmpty) {
      return _buildEmptyCard(
        icon: Icons.campaign_outlined,
        title: _t('No announcements yet', 'अभी कोई घोषणा नहीं है'),
        subtitle: _t(
          'New Panchayat updates will appear here.',
          'नई पंचायत अपडेट यहाँ दिखाई देंगी।',
        ),
      );
    }

    final announcement = _announcements.first;

    final title =
        announcement['title']?.toString() ??
        _t('Panchayat Announcement', 'पंचायत घोषणा');

    final description =
        announcement['description']?.toString() ??
        announcement['content']?.toString() ??
        '';

    return GestureDetector(
      onTap: () {
        _openAnnouncement(announcement);
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(21),
          border: Border.all(color: const Color(0xFFE2EAE6)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5F0),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.campaign_outlined,
                color: Color(0xFF176B4D),
                size: 25,
              ),
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF18352B),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF718078),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ],

                  const SizedBox(height: 9),

                  Text(
                    _formatDate(announcement['created_at']),
                    style: const TextStyle(
                      color: Color(0xFF176B4D),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Color(0xFF9AA59F),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // QUICK SERVICES
  // ============================================================

  Widget _buildQuickServices() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        _buildServiceCard(
          icon: Icons.campaign_outlined,
          title: _t('Announcements', 'घोषणाएँ'),
          subtitle: _t('Panchayat updates', 'पंचायत अपडेट'),
          onTap: () {
            setState(() {
              _selectedIndex = 1;
            });
          },
        ),

        _buildServiceCard(
          icon: Icons.article_outlined,
          title: _t('Village News', 'गाँव की खबरें'),
          subtitle: _t('Latest village news', 'नवीनतम समाचार'),
          onTap: () {
            _showComingSoon(_t('Village News', 'गाँव की खबरें'));
          },
        ),

        _buildServiceCard(
          icon: Icons.account_balance_outlined,
          title: _t('Panchayat', 'पंचायत'),
          subtitle: _t('Panchayat information', 'पंचायत जानकारी'),
          onTap: () {
            _showComingSoon(_t('Panchayat Information', 'पंचायत जानकारी'));
          },
        ),

        _buildServiceCard(
          icon: Icons.people_outline_rounded,
          title: _t('My Ward', 'मेरा वार्ड'),
          subtitle: _t('Ward information', 'वार्ड की जानकारी'),
          onTap: () {
            _showComingSoon(_t('Ward Information', 'वार्ड जानकारी'));
          },
        ),
      ],
    );
  }

  Widget _buildServiceCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF176B4D), size: 25),

              const SizedBox(height: 8),

              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF18352B),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF718078),
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RECENT ANNOUNCEMENTS
  // ============================================================

  Widget _buildRecentAnnouncements() {
    if (_announcements.isEmpty) {
      return _buildEmptyCard(
        icon: Icons.notifications_none_rounded,
        title: _t('Nothing new', 'कोई नई सूचना नहीं'),
        subtitle: _t('You are all caught up.', 'आप सभी अपडेट देख चुके हैं।'),
      );
    }

    return Column(
      children: _announcements
          .take(4)
          .map((announcement) => _buildNoticeCard(announcement))
          .toList(),
    );
  }

  Widget _buildNoticeCard(Map<String, dynamic> announcement) {
    final title =
        announcement['title']?.toString() ?? _t('Announcement', 'घोषणा');

    return GestureDetector(
      onTap: () {
        _openAnnouncement(announcement);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFFE4EBE7)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF5F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Color(0xFF176B4D),
                size: 21,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF18352B),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    _formatDate(announcement['created_at']),
                    style: const TextStyle(
                      color: Color(0xFF718078),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9AA59F)),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // UPDATES PAGE
  // ============================================================

  Widget _buildUpdatesPage() {
    return RefreshIndicator(
      color: const Color(0xFF176B4D),
      onRefresh: _loadAnnouncementsOnly,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
        children: [
          Text(
            _t('Announcements', 'घोषणाएँ'),
            style: const TextStyle(
              color: Color(0xFF18352B),
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            _t(
              'Stay updated with your Panchayat.',
              'अपनी पंचायत की जानकारी से अपडेट रहें।',
            ),
            style: const TextStyle(color: Color(0xFF718078), fontSize: 13),
          ),

          const SizedBox(height: 22),

          if (_announcements.isEmpty)
            _buildEmptyCard(
              icon: Icons.campaign_outlined,
              title: _t('No announcements', 'कोई घोषणा नहीं'),
              subtitle: _t(
                'New updates will appear here.',
                'नई अपडेट यहाँ दिखाई देंगी।',
              ),
            )
          else
            ..._announcements.map(_buildLargeAnnouncement),
        ],
      ),
    );
  }

  Widget _buildLargeAnnouncement(Map<String, dynamic> announcement) {
    final title =
        announcement['title']?.toString() ?? _t('Announcement', 'घोषणा');

    final description =
        announcement['description']?.toString() ??
        announcement['content']?.toString() ??
        '';

    return GestureDetector(
      onTap: () {
        _openAnnouncement(announcement);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 13),
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2EAE6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5F0),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.campaign_outlined,
                    color: Color(0xFF176B4D),
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF18352B),
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            if (description.isNotEmpty) ...[
              const SizedBox(height: 12),

              Text(
                description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF64756D),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],

            const SizedBox(height: 12),

            Text(
              _formatDate(announcement['created_at']),
              style: const TextStyle(
                color: Color(0xFF176B4D),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE PAGE
  // ============================================================

  Widget _buildProfilePage() {
    final mobile = _profile?['mobile']?.toString().trim() ?? '';

    final name = _profile?['name']?.toString().trim() ?? '';

    final fatherName = _profile?['father_name']?.toString().trim() ?? '';

    final motherName = _profile?['mother_name']?.toString().trim() ?? '';

    final dob = _profile?['date_of_birth']?.toString().trim() ?? '';

    final ward = _profile?['ward_number']?.toString().trim() ?? '';

    final houseNumber = _profile?['house_number']?.toString().trim() ?? '';

    final displayName = name.isNotEmpty ? name : _t('Villager', 'ग्रामीण');

    final displayMobile = mobile.isNotEmpty ? mobile : '-';

    final displayFather = fatherName.isNotEmpty ? fatherName : '-';

    final displayMother = motherName.isNotEmpty ? motherName : '-';

    final displayDob = dob.isNotEmpty ? _formatDateOfBirth(dob) : '-';

    final displayWard = ward.isNotEmpty ? ward : '-';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      children: [
        Text(
          _t('My Profile', 'मेरी प्रोफ़ाइल'),
          style: const TextStyle(
            color: Color(0xFF18352B),
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          _t(
            'Your registered Panchayat information',
            'आपकी पंचायत में पंजीकृत जानकारी',
          ),
          style: const TextStyle(color: Color(0xFF718078), fontSize: 13),
        ),

        const SizedBox(height: 20),

        // --------------------------------------------------------
        // PROFILE HEADER
        // --------------------------------------------------------
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF176B4D),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),

                  const SizedBox(width: 15),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          _t(
                            'Villager • Ward $displayWard',
                            'ग्रामीण • वार्ड $displayWard',
                          ),
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // --------------------------------------------------
              // WARD PANCH
              // --------------------------------------------------
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.badge_outlined,
                        color: Colors.white,
                        size: 21,
                      ),
                    ),

                    const SizedBox(width: 11),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _t('Ward Panch', 'वार्ड पंच'),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 2),

                          Text(
                            _wardPanchName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: 3),

                          if (_wardPanch?['mobile'] != null &&
                              _wardPanch!['mobile']
                                  .toString()
                                  .trim()
                                  .isNotEmpty)
                            Row(
                              children: [
                                const Icon(
                                  Icons.phone_outlined,
                                  color: Colors.white70,
                                  size: 13,
                                ),

                                const SizedBox(width: 5),

                                Text(
                                  _wardPanch!['mobile'].toString(),
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // --------------------------------------------------------
        // PERSONAL INFORMATION
        // --------------------------------------------------------
        _buildProfileSectionTitle(
          _t('Personal Information', 'व्यक्तिगत जानकारी'),
        ),

        const SizedBox(height: 12),

        _buildProfileInfo(
          Icons.person_outline_rounded,
          _t('Name', 'नाम'),
          displayName,
        ),

        _buildProfileInfo(
          Icons.phone_android_outlined,
          _t('Mobile Number', 'मोबाइल नंबर'),
          displayMobile,
        ),

        _buildProfileInfo(
          Icons.man_outlined,
          _t("Father's Name", 'पिता का नाम'),
          displayFather,
        ),

        _buildProfileInfo(
          Icons.woman_outlined,
          _t("Mother's Name", 'माता का नाम'),
          displayMother,
        ),

        _buildProfileInfo(
          Icons.cake_outlined,
          _t('Date of Birth', 'जन्म तिथि'),
          displayDob,
        ),

        const SizedBox(height: 10),

        // --------------------------------------------------------
        // PANCHAYAT INFORMATION
        // --------------------------------------------------------
        _buildProfileSectionTitle(
          _t('Panchayat Information', 'पंचायत जानकारी'),
        ),

        const SizedBox(height: 12),

        _buildProfileInfo(
          Icons.location_city_outlined,
          _t('Ward Number', 'वार्ड नंबर'),
          displayWard,
        ),

        if (houseNumber.isNotEmpty)
          _buildProfileInfo(
            Icons.home_outlined,
            _t('House Number', 'मकान नंबर'),
            houseNumber,
          ),

        const SizedBox(height: 20),

        // --------------------------------------------------------
        // INFORMATION NOTICE
        // --------------------------------------------------------
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFFEAF5F0),
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFD6EAE1)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: Color(0xFF176B4D),
                size: 22,
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Text(
                  _t(
                    'This information is registered with your Panchayat. If any information is incorrect, please contact your Ward Panch or Sarpanch.',
                    'यह जानकारी आपकी पंचायत में पंजीकृत है। यदि कोई जानकारी गलत है, तो अपने वार्ड पंच या सरपंच से संपर्क करें।',
                  ),
                  style: const TextStyle(
                    color: Color(0xFF52645C),
                    fontSize: 11.5,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 22),

        // --------------------------------------------------------
        // LOGOUT
        // --------------------------------------------------------
        SizedBox(
          height: 53,
          child: OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            label: Text(_t('Logout', 'लॉगआउट')),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFB42318),
              side: const BorderSide(color: Color(0xFFE5B8B5)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFF18352B),
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  String _formatDateOfBirth(String value) {
    if (value.isEmpty || value == '-') {
      return '-';
    }

    try {
      final date = DateTime.parse(value);

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return value;
    }
  }

  Widget _buildProfileInfo(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE2EAE6)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF176B4D), size: 21),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF718078),
                    fontSize: 10.5,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  style: const TextStyle(
                    color: Color(0xFF18352B),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
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
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigation() {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      backgroundColor: Colors.white,
      elevation: 8,
      height: 70,
      indicatorColor: const Color(0xFFEAF5F0),
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        NavigationDestination(
          icon: const Icon(Icons.home_outlined),
          selectedIcon: const Icon(
            Icons.home_rounded,
            color: Color(0xFF176B4D),
          ),
          label: _t('Home', 'होम'),
        ),

        NavigationDestination(
          icon: const Icon(Icons.campaign_outlined),
          selectedIcon: const Icon(
            Icons.campaign_rounded,
            color: Color(0xFF176B4D),
          ),
          label: _t('Updates', 'अपडेट'),
        ),

        NavigationDestination(
          icon: const Icon(Icons.person_outline_rounded),
          selectedIcon: const Icon(
            Icons.person_rounded,
            color: Color(0xFF176B4D),
          ),
          label: _t('Profile', 'प्रोफ़ाइल'),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY CARD
  // ============================================================

  Widget _buildEmptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: const Color(0xFFE2EAE6)),
      ),
      child: Column(
        children: [
          Icon(icon, color: const Color(0xFF176B4D), size: 34),

          const SizedBox(height: 10),

          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF18352B),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF718078), fontSize: 11.5),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMING SOON
  // ============================================================

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_t('$title is coming soon.', '$title जल्द उपलब्ध होगा।')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(dynamic value) {
    if (value == null) {
      return _t('Recently', 'हाल ही में');
    }

    try {
      final date = DateTime.parse(value.toString());

      final now = DateTime.now();

      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return _t('Just now', 'अभी');
      }

      if (difference.inHours < 1) {
        return _t(
          '${difference.inMinutes} min ago',
          '${difference.inMinutes} मिनट पहले',
        );
      }

      if (difference.inDays == 1) {
        return _t('Yesterday', 'कल');
      }

      if (difference.inDays < 7) {
        return _t(
          '${difference.inDays} days ago',
          '${difference.inDays} दिन पहले',
        );
      }

      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return _t('Recently', 'हाल ही में');
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    if (_announcementChannel != null) {
      _supabase.removeChannel(_announcementChannel!);
    }

    super.dispose();
  }
}
