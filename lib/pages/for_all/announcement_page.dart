import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnouncementPage extends StatefulWidget {
  final bool isHindi;

  const AnnouncementPage({super.key, required this.isHindi});

  @override
  State<AnnouncementPage> createState() => _AnnouncementPageState();
}

class _AnnouncementPageState extends State<AnnouncementPage>
    with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _announcements = [];

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _reloadRunning = false;
  bool _reloadRequested = false;

  String _searchQuery = '';

  RealtimeChannel? _announcementChannel;

  late final AnimationController _bubbleController;

  // ============================================================
  // DESIGN SYSTEM
  // ============================================================

  static const Color primaryGreen = Color(0xFF176B4D);
  static const Color secondaryGreen = Color(0xFF2E8B68);
  static const Color lightGreen = Color(0xFFEAF5F0);
  static const Color pageBackground = Color(0xFFF7FAF8);
  static const Color darkText = Color(0xFF18352B);
  static const Color mutedText = Color(0xFF718078);
  static const Color inputBackground = Color(0xFFF4F8F6);

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

    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();

    _loadAnnouncements();
    _setupRealtime();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchController.dispose();
    _bubbleController.dispose();

    if (_announcementChannel != null) {
      _supabase.removeChannel(_announcementChannel!);
    }

    super.dispose();
  }

  // ============================================================
  // LOAD
  // ============================================================

  Future<void> _loadAnnouncements({bool showLoader = true}) async {
    if (!mounted) return;

    if (_reloadRunning) {
      _reloadRequested = true;
      return;
    }

    _reloadRunning = true;

    if (showLoader) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final response = await _supabase
          .from('announcements')
          .select()
          .order('created_at', ascending: false);

      if (!mounted) return;

      final data = List<Map<String, dynamic>>.from(response);

      setState(() {
        _announcements
          ..clear()
          ..addAll(data);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('ANNOUNCEMENT LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        _t('Could not load announcements.', 'घोषणाएँ लोड नहीं हो सकीं।'),
        isError: true,
      );
    } finally {
      _reloadRunning = false;

      if (_reloadRequested) {
        _reloadRequested = false;

        if (mounted) {
          unawaited(_loadAnnouncements(showLoader: false));
        }
      }
    }
  }

  // ============================================================
  // REALTIME
  // ============================================================

  void _setupRealtime() {
    _announcementChannel = _supabase
        .channel('announcement-page-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'announcements',
          callback: (payload) {
            if (!mounted) return;

            unawaited(_loadAnnouncements(showLoader: false));
          },
        )
        .subscribe();
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<Map<String, dynamic>> get _filteredAnnouncements {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return List<Map<String, dynamic>>.from(_announcements);
    }

    return _announcements.where((announcement) {
      final title = (announcement['title'] ?? '').toString().toLowerCase();

      final content = (announcement['content'] ?? '').toString().toLowerCase();

      return title.contains(query) || content.contains(query);
    }).toList();
  }

  // ============================================================
  // ADD
  // ============================================================

  Future<void> _addAnnouncement({
    required String title,
    required String content,
  }) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final user = _supabase.auth.currentUser;

      await _supabase.from('announcements').insert({
        'title': title.trim(),
        'content': content.trim(),
        'created_by': user?.id,
        'is_published': true,
      });

      if (!mounted) return;

      Navigator.of(context).pop();

      _showMessage(
        _t(
          'Announcement published successfully.',
          'घोषणा सफलतापूर्वक प्रकाशित की गई।',
        ),
      );

      unawaited(_loadAnnouncements(showLoader: false));
    } catch (e) {
      debugPrint('ANNOUNCEMENT INSERT ERROR: $e');

      if (!mounted) return;

      _showMessage(
        _t('Could not publish announcement.', 'घोषणा प्रकाशित नहीं हो सकी।'),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // EDIT
  // ============================================================

  Future<void> _editAnnouncement({
    required String id,
    required String title,
    required String content,
  }) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _supabase
          .from('announcements')
          .update({
            'title': title.trim(),
            'content': content.trim(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', id);

      if (!mounted) return;

      Navigator.of(context).pop();

      _showMessage(
        _t(
          'Announcement updated successfully.',
          'घोषणा सफलतापूर्वक अपडेट की गई।',
        ),
      );

      unawaited(_loadAnnouncements(showLoader: false));
    } catch (e) {
      debugPrint('ANNOUNCEMENT UPDATE ERROR: $e');

      if (!mounted) return;

      _showMessage(
        _t('Could not update announcement.', 'घोषणा अपडेट नहीं हो सकी।'),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<void> _deleteAnnouncement(Map<String, dynamic> announcement) async {
    if (_isDeleting) return;

    final id = announcement['id']?.toString();

    if (id == null || id.isEmpty) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      await _supabase.from('announcements').delete().eq('id', id);

      if (!mounted) return;

      _showMessage(_t('Announcement deleted.', 'घोषणा हटा दी गई।'));

      unawaited(_loadAnnouncements(showLoader: false));
    } catch (e) {
      debugPrint('ANNOUNCEMENT DELETE ERROR: $e');

      if (!mounted) return;

      _showMessage(
        _t('Could not delete announcement.', 'घोषणा हटाई नहीं जा सकी।'),
        isError: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  // ============================================================
  // ADD DIALOG
  // ============================================================

  void _showAddAnnouncementDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    _showAnnouncementDialog(
      titleController: titleController,
      contentController: contentController,
      isEditing: false,
      onSave: () async {
        final title = titleController.text.trim();
        final content = contentController.text.trim();

        if (title.isEmpty || content.isEmpty) {
          _showMessage(
            _t('Please fill in all fields.', 'कृपया सभी फ़ील्ड भरें।'),
            isError: true,
          );
          return;
        }

        await _addAnnouncement(title: title, content: content);
      },
    );
  }

  // ============================================================
  // EDIT DIALOG
  // ============================================================

  void _showEditAnnouncementDialog(Map<String, dynamic> announcement) {
    final titleController = TextEditingController(
      text: announcement['title']?.toString() ?? '',
    );

    final contentController = TextEditingController(
      text: announcement['content']?.toString() ?? '',
    );

    _showAnnouncementDialog(
      titleController: titleController,
      contentController: contentController,
      isEditing: true,
      onSave: () async {
        final title = titleController.text.trim();
        final content = contentController.text.trim();

        if (title.isEmpty || content.isEmpty) {
          _showMessage(
            _t('Please fill in all fields.', 'कृपया सभी फ़ील्ड भरें।'),
            isError: true,
          );
          return;
        }

        await _editAnnouncement(
          id: announcement['id'].toString(),
          title: title,
          content: content,
        );
      },
    );
  }

  // ============================================================
  // DIALOG
  // ============================================================

  void _showAnnouncementDialog({
    required TextEditingController titleController,
    required TextEditingController contentController,
    required bool isEditing,
    required Future<void> Function() onSave,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 24,
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: primaryGreen.withOpacity(0.14),
                  blurRadius: 35,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: lightGreen,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.campaign_rounded,
                          color: primaryGreen,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing
                                  ? _t(
                                      'Edit Announcement',
                                      'घोषणा संपादित करें',
                                    )
                                  : _t('New Announcement', 'नई घोषणा'),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: darkText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isEditing
                                  ? _t(
                                      'Update announcement details',
                                      'घोषणा की जानकारी अपडेट करें',
                                    )
                                  : _t(
                                      'Share information with villagers',
                                      'ग्रामीणों के साथ जानकारी साझा करें',
                                    ),
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: mutedText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _isSaving
                            ? null
                            : () => Navigator.pop(dialogContext),
                        icon: const Icon(Icons.close_rounded, color: mutedText),
                      ),
                    ],
                  ),

                  const SizedBox(height: 26),

                  _buildFieldLabel(_t('Announcement Title', 'घोषणा का शीर्षक')),

                  const SizedBox(height: 8),

                  TextField(
                    controller: titleController,
                    maxLength: 120,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDecoration(
                      _t(
                        'Enter announcement title',
                        'घोषणा का शीर्षक दर्ज करें',
                      ),
                      Icons.title_rounded,
                    ).copyWith(counterText: ''),
                  ),

                  const SizedBox(height: 20),

                  _buildFieldLabel(_t('Announcement Message', 'घोषणा संदेश')),

                  const SizedBox(height: 8),

                  TextField(
                    controller: contentController,
                    maxLength: 2000,
                    minLines: 5,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: _inputDecoration(
                      _t(
                        'Write your announcement here...',
                        'अपनी घोषणा यहाँ लिखें...',
                      ),
                      Icons.notes_rounded,
                    ).copyWith(counterText: ''),
                  ),

                  const SizedBox(height: 25),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : () => onSave(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        disabledBackgroundColor: primaryGreen.withOpacity(0.55),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isEditing
                                      ? Icons.check_rounded
                                      : Icons.campaign_rounded,
                                  size: 20,
                                ),
                                const SizedBox(width: 9),
                                Text(
                                  isEditing
                                      ? _t('Save Changes', 'परिवर्तन सहेजें')
                                      : _t(
                                          'Publish Announcement',
                                          'घोषणा प्रकाशित करें',
                                        ),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ).then((_) {
      titleController.dispose();
      contentController.dispose();
    });
  }

  // ============================================================
  // FIELD LABEL
  // ============================================================

  Widget _buildFieldLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: darkText,
      ),
    );
  }

  // ============================================================
  // INPUT
  // ============================================================

  InputDecoration _inputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9AA59F), fontSize: 13.5),
      prefixIcon: Icon(icon, color: primaryGreen, size: 21),
      filled: true,
      fillColor: inputBackground,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: primaryGreen, width: 1.4),
      ),
    );
  }

  // ============================================================
  // DELETE CONFIRMATION
  // ============================================================

  void _confirmDelete(Map<String, dynamic> announcement) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(27),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red.shade600,
                    size: 29,
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  _t('Delete Announcement?', 'घोषणा हटाएँ?'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: darkText,
                  ),
                ),

                const SizedBox(height: 9),

                Text(
                  _t(
                    'This announcement will be permanently deleted.',
                    'यह घोषणा स्थायी रूप से हटा दी जाएगी।',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: mutedText,
                  ),
                ),

                const SizedBox(height: 23),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: darkText,
                          side: const BorderSide(color: Color(0xFFDDE5E0)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          _t('Cancel', 'रद्द करें'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),

                    const SizedBox(width: 11),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isDeleting
                            ? null
                            : () {
                                Navigator.pop(dialogContext);

                                unawaited(_deleteAnnouncement(announcement));
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          _t('Delete', 'हटाएँ'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
    final announcements = _filteredAnnouncements;

    return Scaffold(
      backgroundColor: pageBackground,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _bubbleController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _AnnouncementBubblePainter(
                      animationValue: _bubbleController.value,
                      primaryGreen: primaryGreen,
                    ),
                  );
                },
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopSection(),

                Expanded(
                  child: RefreshIndicator(
                    color: primaryGreen,
                    backgroundColor: Colors.white,
                    onRefresh: () => _loadAnnouncements(showLoader: false),
                    child: _isLoading
                        ? _buildLoadingState()
                        : announcements.isEmpty
                        ? _buildEmptyState()
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(18, 8, 18, 115),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: announcements.length,
                            itemBuilder: (context, index) {
                              return _buildAnnouncementCard(
                                announcements[index],
                                index,
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(left: 18, right: 18, bottom: 17, child: _buildAddButton()),
        ],
      ),
    );
  }

  // ============================================================
  // TOP SECTION
  // ============================================================

  Widget _buildTopSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              _buildBackButton(),

              const SizedBox(width: 11),

              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: primaryGreen,
                  borderRadius: BorderRadius.circular(14),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Mor Panchayat',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: darkText,
                      ),
                    ),
                  ],
                ),
              ),

              _buildRefreshButton(),
            ],
          ),

          const SizedBox(height: 14),

          _buildAnnouncementHero(),

          const SizedBox(height: 14),

          _buildSearchField(),
        ],
      ),
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _buildAnnouncementHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: primaryGreen,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.20),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 57,
            height: 57,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: const Icon(
              Icons.campaign_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Panchayat Announcements', 'पंचायत घोषणाएँ'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _t(
                    'Share important information with villagers',
                    'ग्रामीणों के साथ महत्वपूर्ण जानकारी साझा करें',
                  ),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.80),
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
  // SEARCH
  // ============================================================

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EEE9)),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        decoration: InputDecoration(
          hintText: _t('Search announcements...', 'घोषणाएँ खोजें...'),
          hintStyle: const TextStyle(color: mutedText, fontSize: 13.5),
          prefixIcon: const Icon(Icons.search_rounded, color: primaryGreen),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();

                    setState(() {
                      _searchQuery = '';
                    });
                  },
                  icon: const Icon(Icons.close_rounded, color: mutedText),
                )
              : null,
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
            borderSide: const BorderSide(color: primaryGreen, width: 1.2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  // ============================================================
  // BUTTONS
  // ============================================================

  Widget _buildBackButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => Navigator.pop(context),
        child: const SizedBox(
          width: 46,
          height: 46,
          child: Icon(Icons.arrow_back_rounded, color: primaryGreen),
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _loadAnnouncements(showLoader: false),
        child: const SizedBox(
          width: 46,
          height: 46,
          child: Icon(Icons.refresh_rounded, color: primaryGreen),
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _showAddAnnouncementDialog,
        icon: const Icon(Icons.add_rounded, size: 23),
        label: Text(
          _t('New Announcement', 'नई घोषणा'),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: primaryGreen.withOpacity(0.30),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoadingState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 130),
        Center(
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(19),
              boxShadow: [
                BoxShadow(
                  color: primaryGreen.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: const CircularProgressIndicator(
              strokeWidth: 2.5,
              color: primaryGreen,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    final searching = _searchQuery.trim().isNotEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 25),
      children: [
        const SizedBox(height: 65),

        Center(
          child: Container(
            width: 94,
            height: 94,
            decoration: const BoxDecoration(
              color: lightGreen,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.campaign_outlined,
              size: 45,
              color: primaryGreen,
            ),
          ),
        ),

        const SizedBox(height: 21),

        Text(
          searching
              ? _t('No announcements found', 'कोई घोषणा नहीं मिली')
              : _t('No announcements yet', 'अभी कोई घोषणा नहीं है'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: darkText,
          ),
        ),

        const SizedBox(height: 9),

        Text(
          searching
              ? _t(
                  'Try searching with another keyword.',
                  'कोई दूसरा शब्द खोजकर देखें।',
                )
              : _t(
                  'Create an announcement to share important information with villagers.',
                  'ग्रामीणों के साथ महत्वपूर्ण जानकारी साझा करने के लिए घोषणा बनाएँ।',
                ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, height: 1.55, color: mutedText),
        ),
      ],
    );
  }

  // ============================================================
  // CARD
  // ============================================================

  Widget _buildAnnouncementCard(Map<String, dynamic> announcement, int index) {
    final title = announcement['title']?.toString() ?? '';

    final content = announcement['content']?.toString() ?? '';

    final createdAt = announcement['created_at']?.toString();

    final updatedAt = announcement['updated_at']?.toString();

    final dateText = _formatDate(updatedAt ?? createdAt);

    final wasUpdated = _wasUpdated(createdAt, updatedAt);

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + min(index * 45, 250)),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE5EDE8), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: primaryGreen.withOpacity(0.055),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
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

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: darkText,
                            height: 1.25,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Row(
                          children: [
                            const Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: mutedText,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                dateText,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: mutedText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 5),

                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F8F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: mutedText,
                        size: 21,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditAnnouncementDialog(announcement);
                        }

                        if (value == 'delete') {
                          _confirmDelete(announcement);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.edit_rounded,
                                size: 19,
                                color: primaryGreen,
                              ),
                              const SizedBox(width: 10),
                              Text(_t('Edit', 'संपादित करें')),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline_rounded,
                                size: 19,
                                color: Colors.red.shade600,
                              ),
                              const SizedBox(width: 10),
                              Text(_t('Delete', 'हटाएँ')),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 15),

              Container(height: 1, color: const Color(0xFFEDF1EF)),

              const SizedBox(height: 13),

              Text(
                content,
                style: const TextStyle(
                  fontSize: 14.2,
                  height: 1.6,
                  color: Color(0xFF425049),
                ),
              ),

              if (wasUpdated) ...[
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: lightGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.edit_note_rounded,
                        size: 14,
                        color: primaryGreen,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _t('Updated', 'अपडेट किया गया'),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: primaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // UPDATED CHECK
  // ============================================================

  bool _wasUpdated(String? createdAt, String? updatedAt) {
    if (createdAt == null || updatedAt == null) {
      return false;
    }

    try {
      final created = DateTime.parse(createdAt).toUtc();

      final updated = DateTime.parse(updatedAt).toUtc();

      return updated.difference(created).inSeconds > 2;
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // DATE
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

// ============================================================
// OPTIMIZED ANIMATED BACKGROUND
// ============================================================

class _AnnouncementBubblePainter extends CustomPainter {
  final double animationValue;
  final Color primaryGreen;

  static final List<_BubbleData> _bubbles = _createBubbles();

  _AnnouncementBubblePainter({
    required this.animationValue,
    required this.primaryGreen,
  });

  static List<_BubbleData> _createBubbles() {
    final random = Random(24);

    return List.generate(15, (index) {
      return _BubbleData(
        radius: 25 + random.nextDouble() * 70,
        x: random.nextDouble(),
        y: random.nextDouble(),
        phase: random.nextDouble() * pi * 2,
        opacity: 0.014 + random.nextDouble() * 0.025,
      );
    });
  }

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

  @override
  bool shouldRepaint(covariant _AnnouncementBubblePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

class _BubbleData {
  final double radius;
  final double x;
  final double y;
  final double phase;
  final double opacity;

  const _BubbleData({
    required this.radius,
    required this.x,
    required this.y,
    required this.phase,
    required this.opacity,
  });
}
