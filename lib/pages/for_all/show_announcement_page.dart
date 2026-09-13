import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mor_panchayat/pages/for_all/announcement_page.dart';
import 'package:mor_panchayat/pages/welcome_page.dart';

class ShowAnnouncementPage extends StatefulWidget {
  final bool isHindi;

  const ShowAnnouncementPage({super.key, required this.isHindi});

  @override
  State<ShowAnnouncementPage> createState() => _ShowAnnouncementPageState();
}

class _ShowAnnouncementPageState extends State<ShowAnnouncementPage>
    with TickerProviderStateMixin {
  static const Color primaryGreen = Color(0xFF176B4D);
  static const Color lightGreen = Color(0xFFEAF5F0);
  static const Color darkText = Color(0xFF18352B);
  static const Color mutedText = Color(0xFF718078);

  final SupabaseClient _supabase = Supabase.instance.client;

  late AnimationController _bubbleController;
  late List<_Bubble> _bubbles;

  RealtimeChannel? _announcementChannel;

  List<Map<String, dynamic>> _announcements = [];
  bool _loading = true;
  bool _refreshing = false;

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

    _loadAnnouncements();
    _setupRealtime();
  }

  @override
  void dispose() {
    if (_announcementChannel != null) {
      _supabase.removeChannel(_announcementChannel!);
    }

    _bubbleController.dispose();

    super.dispose();
  }

  String _t(String english, String hindi) {
    return widget.isHindi ? hindi : english;
  }

  // ============================================================
  // LOAD ANNOUNCEMENTS
  // ============================================================

  Future<void> _loadAnnouncements() async {
    try {
      final response = await _supabase
          .from('announcements')
          .select()
          .eq('is_published', true)
          .order('created_at', ascending: false);

      final announcements = List<Map<String, dynamic>>.from(response);

      // Get all creator IDs
      final creatorIds = announcements
          .map((announcement) => announcement['created_by'])
          .where((id) => id != null)
          .map((id) => id.toString())
          .toSet()
          .toList();

      // Get creator names from profiles
      if (creatorIds.isNotEmpty) {
        final profiles = await _supabase
            .from('profiles')
            .select('user_id, name, role')
            .inFilter('user_id', creatorIds);

        final profileList = List<Map<String, dynamic>>.from(profiles);

        final Map<String, Map<String, dynamic>> profileMap = {
          for (final profile in profileList)
            profile['user_id'].toString(): profile,
        };

        // Attach profile information to every announcement
        for (final announcement in announcements) {
          final createdBy = announcement['created_by']?.toString();

          if (createdBy != null && profileMap.containsKey(createdBy)) {
            announcement['creator_profile'] = profileMap[createdBy];
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _announcements = announcements;
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      debugPrint('Announcement loading error: $e');

      if (!mounted) return;

      setState(() {
        _loading = false;
        _refreshing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t('Unable to load announcements.', 'घोषणाएँ लोड नहीं हो सकीं।'),
          ),
        ),
      );
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refreshAnnouncements() async {
    if (_refreshing) return;

    setState(() {
      _refreshing = true;
    });

    await _loadAnnouncements();
  }

  // ============================================================
  // REALTIME
  // ============================================================

  void _setupRealtime() {
    _announcementChannel = _supabase
        .channel('show-announcements')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'announcements',
          callback: (payload) {
            debugPrint('Announcement realtime change: ${payload.eventType}');

            _loadAnnouncements();
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
      backgroundColor: const Color(0xFFF7FAF8),
      body: Stack(
        children: [
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

          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),

                Expanded(
                  child: RefreshIndicator(
                    color: primaryGreen,
                    onRefresh: _refreshAnnouncements,
                    child: _buildContent(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ==========================================================
      // CREATE ANNOUNCEMENT BUTTON
      // ==========================================================
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createAnnouncement,
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 5,
        icon: const Icon(Icons.add_rounded),
        label: Text(
          _t('Create Announcement', 'घोषणा बनाएँ'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: _showMenu,
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.035),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const Icon(Icons.menu_rounded, color: darkText, size: 22),
            ),
          ),

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

          GestureDetector(
            onTap: _refreshAnnouncements,
            child: Container(
              height: 44,
              width: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.035),
                    blurRadius: 12,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: _refreshing
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: primaryGreen,
                      ),
                    )
                  : const Icon(
                      Icons.refresh_rounded,
                      color: darkText,
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement) {
    final title = announcement['title']?.toString() ?? '';
    final description = announcement['description']?.toString() ?? '';
    final createdBy =
        announcement['created_by_name']?.toString() ??
        announcement['created_by']?.toString() ??
        'Panchayat';

    return GestureDetector(
      onTap: () {
        _showAnnouncementDetails(announcement);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: lightGreen,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.campaign_rounded,
                color: primaryGreen,
                size: 24,
              ),
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TITLE
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 5),

                  // SHORT DESCRIPTION
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: mutedText,
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),

                  const SizedBox(height: 7),

                  // CREATED BY
                  Row(
                    children: [
                      const Icon(
                        Icons.person_outline_rounded,
                        color: primaryGreen,
                        size: 13,
                      ),

                      const SizedBox(width: 4),

                      Expanded(
                        child: Text(
                          _t('By $createdBy', '$createdBy द्वारा'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF8A9690),
                            fontSize: 10,
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

            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: primaryGreen,
                size: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryGreen),
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      children: [
        _buildHeroCard(),

        const SizedBox(height: 24),

        if (_announcements.isEmpty)
          _buildEmptyState()
        else
          ..._announcements.map(
            (announcement) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _announcementCard(announcement),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // HERO CARD
  // ============================================================

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(22),
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
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Announcement', 'घोषणा'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  _t(
                    'Important information from your Panchayat',
                    'आपकी पंचायत की महत्वपूर्ण जानकारी',
                  ),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.78),
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
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
  // ANNOUNCEMENT CARD
  // ============================================================

  Widget _announcementCard(Map<String, dynamic> announcement) {
    final String title = _getString(announcement, 'title');
    final String content = _getString(announcement, 'content');
    final String createdAt = _getString(announcement, 'created_at');

    String creatorName = '';
    String creatorRole = '';

    final creatorProfile = announcement['creator_profile'];

    if (creatorProfile is Map) {
      creatorName = creatorProfile['name']?.toString().trim() ?? '';
      creatorRole = creatorProfile['role']?.toString().trim() ?? '';
    }

    final String roleText = _formatRole(creatorRole);

    String postedByText;

    if (creatorName.isNotEmpty) {
      postedByText = widget.isHindi
          ? '$roleText · $creatorName'
          : '$roleText · $creatorName';
    } else {
      postedByText = roleText;
    }

    return GestureDetector(
      onTap: () {
        _showAnnouncementDetails(announcement);
      },
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 46,
                  width: 46,
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
                  child: Text(
                    title.isEmpty ? _t('Announcement', 'घोषणा') : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: darkText,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Color(0xFF9AA49F),
                  size: 15,
                ),
              ],
            ),

            const SizedBox(height: 10),

            if (content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 58),
                child: Text(
                  content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: mutedText,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            const SizedBox(height: 15),

            // =====================================================
            // POSTED BY
            // =====================================================
            Row(
              children: [
                Container(
                  height: 28,
                  width: 28,
                  decoration: BoxDecoration(
                    color: lightGreen,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: primaryGreen,
                    size: 15,
                  ),
                ),

                const SizedBox(width: 7),

                Expanded(
                  child: RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: _t('Posted by ', 'द्वारा '),
                          style: const TextStyle(
                            color: mutedText,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        TextSpan(
                          text: postedByText,
                          style: const TextStyle(
                            color: primaryGreen,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                const Icon(
                  Icons.access_time_rounded,
                  color: Color(0xFF9AA49F),
                  size: 14,
                ),

                const SizedBox(width: 4),

                Text(
                  _formatDate(createdAt),
                  style: const TextStyle(
                    color: Color(0xFF9AA49F),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAnnouncementDetails(Map<String, dynamic> announcement) {
    final String title = _getString(announcement, 'title');
    final String content = _getString(announcement, 'content');
    final String createdAt = _getString(announcement, 'created_at');

    String creatorName = '';
    String creatorRole = '';

    final creatorProfile = announcement['creator_profile'];

    if (creatorProfile is Map) {
      creatorName = creatorProfile['name']?.toString().trim() ?? '';
      creatorRole = creatorProfile['role']?.toString().trim() ?? '';
    }

    final String roleText = _formatRole(creatorRole);

    final String postedBy = creatorName.isNotEmpty
        ? '$roleText · $creatorName'
        : roleText;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HANDLE
                Center(
                  child: Container(
                    height: 5,
                    width: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD9E2DD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                const SizedBox(height: 22),

                // TITLE
                Row(
                  children: [
                    Container(
                      height: 56,
                      width: 56,
                      decoration: BoxDecoration(
                        color: lightGreen,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: primaryGreen,
                        size: 29,
                      ),
                    ),

                    const SizedBox(width: 14),

                    Expanded(
                      child: Text(
                        title.isEmpty ? _t('Announcement', 'घोषणा') : title,
                        style: const TextStyle(
                          color: darkText,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                // FULL CONTENT
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAF8),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    content.isEmpty
                        ? _t(
                            'No information available.',
                            'कोई जानकारी उपलब्ध नहीं है।',
                          )
                        : content,
                    style: const TextStyle(
                      color: darkText,
                      fontSize: 14,
                      height: 1.55,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // =====================================================
                // POSTED BY
                // =====================================================
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: lightGreen,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: primaryGreen,
                          size: 20,
                        ),
                      ),

                      const SizedBox(width: 11),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _t('Posted by', 'द्वारा'),
                              style: const TextStyle(
                                color: mutedText,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 3),

                            Text(
                              postedBy,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: darkText,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // DATE
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7FAF8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        color: primaryGreen,
                        size: 20,
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          _formatDate(createdAt),
                          style: const TextStyle(
                            color: mutedText,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // CLOSE
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
          ),
        );
      },
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(28),
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
      child: Column(
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.campaign_outlined,
              color: primaryGreen,
              size: 32,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            _t('No announcements yet', 'अभी कोई घोषणा नहीं है'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: darkText,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            _t(
              'New Panchayat announcements will appear here.',
              'नई पंचायत घोषणाएँ यहाँ दिखाई देंगी।',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(color: mutedText, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SAFE STRING
  // ============================================================

  String _getString(Map<String, dynamic> data, String key) {
    final value = data[key];

    if (value == null) {
      return '';
    }

    return value.toString();
  }

  String _formatRole(String role) {
    final normalized = role.trim().toLowerCase();

    switch (normalized) {
      case 'sarpanch':
        return _t('Sarpanch', 'सरपंच');

      case 'panchayat_member':
      case 'panchayat member':
      case 'member':
        return _t('Panchayat Member', 'पंचायत सदस्य');

      case 'admin':
        return _t('Admin', 'प्रशासक');

      case 'secretary':
        return _t('Secretary', 'सचिव');

      default:
        if (role.trim().isEmpty) {
          return _t('Panchayat', 'पंचायत');
        }

        return role.trim();
    }
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(String value) {
    if (value.isEmpty) {
      return '';
    }

    try {
      final date = DateTime.parse(value).toLocal();

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();

      final hour12 = date.hour == 0
          ? 12
          : date.hour > 12
          ? date.hour - 12
          : date.hour;

      final minute = date.minute.toString().padLeft(2, '0');

      final period = date.hour >= 12 ? 'PM' : 'AM';

      return '$day/$month/$year • $hour12:$minute $period';
    } catch (_) {
      return value;
    }
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
  // SAME MENU AS SARPANCH HOME
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
