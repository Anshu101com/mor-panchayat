import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mor_panchayat/pages/sarpanch_pages/add_member_page.dart';

class ManageMemberPage extends StatefulWidget {
  final bool isHindi;

  const ManageMemberPage({super.key, required this.isHindi});

  @override
  State<ManageMemberPage> createState() => _ManageMemberPageState();
}

class _ManageMemberPageState extends State<ManageMemberPage>
    with TickerProviderStateMixin {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primaryGreen = Color(0xFF176B4D);
  static const Color secondaryGreen = Color(0xFF22815E);
  static const Color lightGreen = Color(0xFFEAF5F0);
  static const Color backgroundColor = Color(0xFFF7FAF8);
  static const Color darkText = Color(0xFF18352B);
  static const Color mutedText = Color(0xFF718078);

  // ============================================================
  // SUPABASE
  // ============================================================

  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // DATA
  // ============================================================

  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _filteredMembers = [];

  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _isSarpanch = false;

  String _searchQuery = '';

  RealtimeChannel? _realtimeChannel;
  StreamSubscription<AuthState>? _authSubscription;

  // ============================================================
  // BUBBLES
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

    _initializeBubbles();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadCurrentUserRole();
    await _loadMembers();

    _setupRealtime();
    _setupAuthListener();
  }

  // ============================================================
  // BUBBLE INITIALIZATION
  // ============================================================

  void _initializeBubbles() {
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
  }

  // ============================================================
  // AUTH LISTENER
  // ============================================================

  void _setupAuthListener() {
    _authSubscription = _supabase.auth.onAuthStateChange.listen((_) async {
      await _loadCurrentUserRole();
      await _loadMembers();
    });
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _bubbleController.dispose();

    if (_realtimeChannel != null) {
      _supabase.removeChannel(_realtimeChannel!);
    }

    _authSubscription?.cancel();

    super.dispose();
  }

  // ============================================================
  // CURRENT USER ROLE
  // ============================================================

  Future<void> _loadCurrentUserRole() async {
    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _isSarpanch = false;
        });

        return;
      }

      final response = await _supabase
          .from('profiles')
          .select('role')
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      final role = response?['role']?.toString();

      setState(() {
        _isSarpanch = _isSarpanchRole(role);
      });
    } catch (e) {
      debugPrint('Load current user role error: $e');

      if (!mounted) return;

      setState(() {
        _isSarpanch = false;
      });
    }
  }

  // ============================================================
  // ROLE HELPERS
  // ============================================================

  bool _isSarpanchRole(String? role) {
    if (role == null) return false;

    final normalized = role.trim().toLowerCase();

    return normalized == 'sarpanch' ||
        normalized == 'sarpanch_user' ||
        normalized == 'सरपंच';
  }

  bool _isMemberRole(String? role) {
    if (role == null) return false;

    return role.trim().toLowerCase() == 'member';
  }

  // ============================================================
  // LOAD MEMBERS
  // ============================================================

  Future<void> _loadMembers() async {
    if (_isRefreshing) return;

    try {
      if (mounted) {
        setState(() {
          _isRefreshing = true;

          if (_members.isEmpty) {
            _isLoading = true;
          }
        });
      }

      final selectFields = _isSarpanch
          ? 'id, user_id, email, name, role, mobile, ward_number, '
                'created_at, updated_at'
          : 'id, user_id, name, role, mobile, ward_number, '
                'created_at, updated_at';

      final response = await _supabase
          .from('profiles')
          .select(selectFields)
          .or('role.eq.member,role.eq.sarpanch')
          .order('name', ascending: true);

      final data = List<Map<String, dynamic>>.from(response);

      if (!mounted) return;

      setState(() {
        _members = data;
        _applySearch();
        _isLoading = false;
        _isRefreshing = false;
      });
    } catch (e) {
      debugPrint('Manage members load error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isRefreshing = false;
      });

      _showMessage(
        _t(
          'Could not load member data.',
          'सदस्यों का डेटा प्राप्त नहीं हो सका।',
        ),
        isError: true,
      );
    }
  }

  // ============================================================
  // REALTIME
  // ============================================================

  void _setupRealtime() {
    _realtimeChannel = _supabase
        .channel('manage-members-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            debugPrint('Profiles realtime update: ${payload.eventType}');

            _loadMembers();
          },
        )
        .subscribe();
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _applySearch() {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      _filteredMembers = List<Map<String, dynamic>>.from(_members);
    } else {
      _filteredMembers = _members.where((member) {
        final name = (member['name'] ?? '').toString().trim().toLowerCase();

        final mobile = (member['mobile'] ?? '').toString().trim().toLowerCase();

        final ward = (member['ward_number'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        final email = (member['email'] ?? '').toString().trim().toLowerCase();

        final role = (member['role'] ?? '').toString().trim().toLowerCase();

        return name.contains(query) ||
            mobile.contains(query) ||
            ward.contains(query) ||
            email.contains(query) ||
            role.contains(query);
      }).toList();
    }

    _sortByName(_filteredMembers);
  }

  // ============================================================
  // SARPANCH LIST
  // ============================================================

  List<Map<String, dynamic>> get _sarpanchList {
    final list = _filteredMembers.where((member) {
      return _isSarpanchRole(member['role']?.toString());
    }).toList();

    _sortByName(list);

    return list;
  }

  // ============================================================
  // MEMBER LIST
  // ============================================================

  List<Map<String, dynamic>> get _memberList {
    final list = _filteredMembers.where((member) {
      return _isMemberRole(member['role']?.toString());
    }).toList();

    _sortByName(list);

    return list;
  }

  // ============================================================
  // SORT
  // ============================================================

  void _sortByName(List<Map<String, dynamic>> list) {
    list.sort((a, b) {
      final nameA = (a['name'] ?? '').toString().trim().toLowerCase();

      final nameB = (b['name'] ?? '').toString().trim().toLowerCase();

      return nameA.compareTo(nameB);
    });
  }

  // ============================================================
  // DELETE MEMBER
  // ============================================================

  Future<void> _deleteMember(Map<String, dynamic> member) async {
    if (!_isSarpanch) {
      _showMessage(
        _t(
          'Only the Sarpanch can delete members.',
          'केवल सरपंच ही सदस्यों को हटा सकते हैं।',
        ),
        isError: true,
      );
      return;
    }

    final memberId = member['id'];

    if (memberId == null) {
      _showMessage(
        _t('Member ID is missing.', 'सदस्य की आईडी नहीं मिली।'),
        isError: true,
      );
      return;
    }

    final role = member['role']?.toString().trim().toLowerCase();

    if (_isSarpanchRole(role)) {
      _showMessage(
        _t('The Sarpanch cannot be deleted.', 'सरपंच को हटाया नहीं जा सकता।'),
        isError: true,
      );
      return;
    }

    final memberName = member['name']?.toString().trim().isNotEmpty == true
        ? member['name'].toString().trim()
        : _t('Member', 'सदस्य');

    final confirmed = await _showDeleteDialog(memberName);

    if (confirmed != true) return;

    try {
      final deletedRows = await _supabase
          .from('profiles')
          .delete()
          .eq('id', memberId)
          .select();

      if (deletedRows.isEmpty) {
        throw Exception(
          'No member was deleted. Check Supabase RLS DELETE policy.',
        );
      }

      if (!mounted) return;

      _showMessage(
        _t('Member deleted successfully.', 'सदस्य सफलतापूर्वक हटाया गया।'),
      );

      await _loadMembers();
    } catch (e) {
      debugPrint('Delete member error: $e');

      if (!mounted) return;

      _showMessage(
        _t('Could not delete member.', 'सदस्य हटाया नहीं जा सका।'),
        isError: true,
      );
    }
  }

  // ============================================================
  // DELETE DIALOG
  // ============================================================

  Future<bool?> _showDeleteDialog(String memberName) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 58,
                  width: 58,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 29,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  _t('Delete Member?', 'सदस्य हटाएं?'),
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  _t(
                    'Are you sure you want to remove $memberName?',
                    'क्या आप $memberName को हटाना चाहते हैं?',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: mutedText,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext, false);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: darkText,
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(
                            color: Colors.black.withOpacity(0.08),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(_t('Cancel', 'रद्द करें')),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          _t('Delete', 'हटाएं'),
                          style: const TextStyle(fontWeight: FontWeight.w800),
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
  // EDIT MEMBER
  // ============================================================

  void _editMember(Map<String, dynamic> member) {
    if (!_isSarpanch) {
      _showMessage(
        _t(
          'Only the Sarpanch can edit members.',
          'केवल सरपंच ही सदस्यों की जानकारी बदल सकते हैं।',
        ),
        isError: true,
      );

      return;
    }

    _showEditDialog(member);
  }

  // ============================================================
  // EDIT DIALOG
  // ============================================================

  Future<void> _showEditDialog(Map<String, dynamic> member) async {
    final nameController = TextEditingController(
      text: member['name']?.toString() ?? '',
    );

    final mobileController = TextEditingController(
      text: member['mobile']?.toString() ?? '',
    );

    final wardController = TextEditingController(
      text: member['ward_number']?.toString() ?? '',
    );

    final emailController = TextEditingController(
      text: member['email']?.toString() ?? '',
    );

    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 24,
              ),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 680),
                padding: const EdgeInsets.all(21),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(27),
                  boxShadow: [
                    BoxShadow(
                      color: primaryGreen.withOpacity(0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HEADER
                      Row(
                        children: [
                          Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: lightGreen,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
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
                                  _t('Edit Member', 'सदस्य संपादित करें'),
                                  style: const TextStyle(
                                    color: darkText,
                                    fontSize: 19,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _t(
                                    'Update member information',
                                    'सदस्य की जानकारी अपडेट करें',
                                  ),
                                  style: const TextStyle(
                                    color: mutedText,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          IconButton(
                            onPressed: saving
                                ? null
                                : () {
                                    Navigator.pop(dialogContext);
                                  },
                            icon: const Icon(
                              Icons.close_rounded,
                              color: mutedText,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 22),

                      // NAME
                      _dialogField(
                        controller: nameController,
                        label: _t('Member Name', 'सदस्य का नाम'),
                        icon: Icons.person_outline_rounded,
                      ),

                      const SizedBox(height: 12),

                      // MOBILE
                      _dialogField(
                        controller: mobileController,
                        label: _t('Mobile Number', 'मोबाइल नंबर'),
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),

                      const SizedBox(height: 12),

                      // WARD
                      _dialogField(
                        controller: wardController,
                        label: _t('Ward Number', 'वार्ड नंबर'),
                        icon: Icons.location_on_outlined,
                        keyboardType: TextInputType.number,
                      ),

                      const SizedBox(height: 12),

                      // EMAIL
                      _dialogField(
                        controller: emailController,
                        label: _t('Email / Login ID', 'ईमेल / लॉगिन ID'),
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),

                      const SizedBox(height: 20),

                      // BUTTONS
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: saving
                                  ? null
                                  : () {
                                      Navigator.pop(dialogContext);
                                    },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: darkText,
                                minimumSize: const Size.fromHeight(50),
                                side: BorderSide(
                                  color: Colors.black.withOpacity(0.08),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(_t('Cancel', 'रद्द करें')),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: ElevatedButton(
                              onPressed: saving
                                  ? null
                                  : () async {
                                      final name = nameController.text.trim();

                                      if (name.isEmpty) {
                                        _showMessage(
                                          _t(
                                            'Member name is required.',
                                            'सदस्य का नाम आवश्यक है।',
                                          ),
                                          isError: true,
                                        );
                                        return;
                                      }

                                      setDialogState(() {
                                        saving = true;
                                      });

                                      try {
                                        await _supabase
                                            .from('profiles')
                                            .update({
                                              'name': name,
                                              'mobile': mobileController.text
                                                  .trim(),
                                              'ward_number': wardController.text
                                                  .trim(),
                                              'email': emailController.text
                                                  .trim(),
                                              'updated_at': DateTime.now()
                                                  .toIso8601String(),
                                            })
                                            .eq('id', member['id']);

                                        if (!mounted) {
                                          return;
                                        }

                                        Navigator.pop(dialogContext);

                                        _showMessage(
                                          _t(
                                            'Member updated successfully.',
                                            'सदस्य की जानकारी अपडेट हो गई।',
                                          ),
                                        );

                                        await _loadMembers();
                                      } catch (e) {
                                        debugPrint('Update member error: $e');

                                        setDialogState(() {
                                          saving = false;
                                        });

                                        _showMessage(
                                          _t(
                                            'Could not update member.',
                                            'सदस्य की जानकारी अपडेट नहीं की जा सकी।',
                                          ),
                                          isError: true,
                                        );
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryGreen,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: saving
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.3,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.check_rounded,
                                          size: 19,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _t('Save Changes', 'बदलाव सेव करें'),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    mobileController.dispose();
    wardController.dispose();
    emailController.dispose();
  }

  // ============================================================
  // DIALOG FIELD
  // ============================================================

  Widget _dialogField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: primaryGreen, size: 21),
        filled: true,
        fillColor: backgroundColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 16,
        ),
        labelStyle: const TextStyle(color: mutedText, fontSize: 12.5),
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
      ),
    );
  }

  // ============================================================
  // ADD MEMBER
  // ============================================================

  void _addMember() {
    if (!_isSarpanch) {
      _showMessage(
        _t(
          'Only the Sarpanch can add members.',
          'केवल सरपंच ही नए सदस्य जोड़ सकते हैं।',
        ),
        isError: true,
      );

      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddMemberPage(isHindi: widget.isHindi)),
    ).then((_) {
      _loadMembers();
    });
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade700 : primaryGreen,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                Expanded(child: _buildBody()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _isSarpanch ? _buildAddButton() : null,
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          _backButton(),

          const SizedBox(width: 12),

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

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Mor Panchayat',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: darkText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),

          _roleChip(),
        ],
      ),
    );
  }

  // ============================================================
  // BACK BUTTON
  // ============================================================

  Widget _backButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: darkText,
            size: 21,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ROLE CHIP
  // ============================================================

  Widget _roleChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: _isSarpanch ? primaryGreen : lightGreen,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isSarpanch
                ? Icons.admin_panel_settings_outlined
                : Icons.person_outline_rounded,
            color: _isSarpanch ? Colors.white : primaryGreen,
            size: 15,
          ),
          const SizedBox(width: 5),
          Text(
            _isSarpanch ? _t('Sarpanch', 'सरपंच') : _t('Member', 'सदस्य'),
            style: TextStyle(
              color: _isSarpanch ? Colors.white : primaryGreen,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: primaryGreen, strokeWidth: 2.5),
      );
    }

    return RefreshIndicator(
      color: primaryGreen,
      onRefresh: _loadMembers,
      child: ListView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 115),
        children: [
          _buildHeroCard(),

          const SizedBox(height: 20),

          _buildSummaryCard(),

          const SizedBox(height: 18),

          _buildSearch(),

          const SizedBox(height: 24),

          if (_filteredMembers.isEmpty)
            _buildEmptyState()
          else ...[
            if (_sarpanchList.isNotEmpty) ...[
              _buildSectionTitle(_t('Sarpanch', 'सरपंच'), _sarpanchList.length),

              const SizedBox(height: 12),

              ..._sarpanchList.map(
                (member) => _buildMemberCard(member, isSarpanchCard: true),
              ),

              const SizedBox(height: 9),
            ],

            if (_memberList.isNotEmpty) ...[
              _buildSectionTitle(_t('Members', 'सदस्य'), _memberList.length),

              const SizedBox(height: 12),

              ..._memberList.map(
                (member) => _buildMemberCard(member, isSarpanchCard: false),
              ),
            ],
          ],
        ],
      ),
    );
  }

  // ============================================================
  // HERO CARD
  // ============================================================

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, secondaryGreen],
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
            ),
            child: const Icon(
              Icons.groups_rounded,
              color: Colors.white,
              size: 31,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _t('Panchayat Members', 'पंचायत सदस्य'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  _t(
                    'Manage and view all members of your Panchayat',
                    'अपने पंचायत के सभी सदस्यों को देखें और प्रबंधित करें',
                  ),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.82),
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
  // SUMMARY CARD
  // ============================================================

  Widget _buildSummaryCard() {
    final totalSarpanch = _members.where((member) {
      return _isSarpanchRole(member['role']?.toString());
    }).length;

    final totalMembers = _members.where((member) {
      return _isMemberRole(member['role']?.toString());
    }).length;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: primaryGreen.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryItem(
              Icons.admin_panel_settings_outlined,
              totalSarpanch.toString(),
              _t('Sarpanch', 'सरपंच'),
            ),
          ),

          _summaryDivider(),

          Expanded(
            child: _summaryItem(
              Icons.groups_outlined,
              totalMembers.toString(),
              _t('Members', 'सदस्य'),
            ),
          ),

          _summaryDivider(),

          Expanded(
            child: _summaryItem(
              Icons.people_alt_outlined,
              _members.length.toString(),
              _t('Total', 'कुल'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() {
    return Container(
      width: 1,
      height: 45,
      color: primaryGreen.withOpacity(0.08),
    );
  }

  Widget _summaryItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Container(
          height: 35,
          width: 35,
          decoration: BoxDecoration(
            color: lightGreen,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: primaryGreen, size: 18),
        ),

        const SizedBox(height: 5),

        Text(
          value,
          style: const TextStyle(
            color: darkText,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),

        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: mutedText,
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearch() {
    return TextField(
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
          _applySearch();
        });
      },
      decoration: InputDecoration(
        labelText: _t('Search Members', 'सदस्य खोजें'),
        hintText: _t(
          'Name, mobile, email or ward number',
          'नाम, मोबाइल, ईमेल या वार्ड नंबर',
        ),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: primaryGreen,
          size: 21,
        ),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(
                  Icons.clear_rounded,
                  color: mutedText,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _applySearch();
                  });
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        labelStyle: const TextStyle(color: mutedText, fontSize: 13),
        hintStyle: const TextStyle(color: Color(0xFFA1AAA5), fontSize: 12),
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
          borderSide: const BorderSide(color: primaryGreen, width: 1.5),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(String title, int count) {
    return Row(
      children: [
        Container(
          height: 7,
          width: 7,
          decoration: const BoxDecoration(
            color: primaryGreen,
            shape: BoxShape.circle,
          ),
        ),

        const SizedBox(width: 9),

        Text(
          title,
          style: const TextStyle(
            color: darkText,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),

        const Spacer(),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: lightGreen,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            count.toString(),
            style: const TextStyle(
              color: primaryGreen,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MEMBER CARD
  // ============================================================

  Widget _buildMemberCard(
    Map<String, dynamic> member, {
    required bool isSarpanchCard,
  }) {
    final rawName = member['name']?.toString().trim() ?? '';

    final displayName = rawName.isEmpty
        ? _t('Unknown Member', 'अज्ञात सदस्य')
        : rawName;

    final mobile = member['mobile']?.toString().trim() ?? '';

    final ward = member['ward_number']?.toString().trim() ?? '';

    final email = member['email']?.toString().trim() ?? '';

    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'M';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: isSarpanchCard
              ? primaryGreen.withOpacity(0.10)
              : Colors.black.withOpacity(0.035),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 13,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // AVATAR
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isSarpanchCard ? primaryGreen : lightGreen,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: isSarpanchCard
                ? const Icon(
                    Icons.account_balance_rounded,
                    color: Colors.white,
                    size: 25,
                  )
                : Text(
                    initial,
                    style: const TextStyle(
                      color: primaryGreen,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),

          const SizedBox(width: 13),

          // INFORMATION
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: darkText,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    const SizedBox(width: 5),

                    _roleBadge(
                      isSarpanchCard
                          ? _t('Sarpanch', 'सरपंच')
                          : _t('Member', 'सदस्य'),
                      isSarpanchCard,
                    ),

                    if (_isSarpanch && !isSarpanchCard) _memberMenu(member),
                  ],
                ),

                const SizedBox(height: 9),

                Row(
                  children: [
                    Expanded(
                      child: _smallInfo(
                        Icons.location_on_outlined,
                        ward.isEmpty ? '-' : '${_t('Ward', 'वार्ड')} $ward',
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: _smallInfo(
                        Icons.phone_outlined,
                        mobile.isEmpty ? '-' : mobile,
                      ),
                    ),
                  ],
                ),

                if (email.isNotEmpty) ...[
                  const SizedBox(height: 7),
                  _smallInfo(Icons.email_outlined, email),
                ],

                const SizedBox(height: 8),

                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF35A56A),
                        shape: BoxShape.circle,
                      ),
                    ),

                    const SizedBox(width: 6),

                    Text(
                      _t('Active', 'सक्रिय'),
                      style: const TextStyle(
                        color: Color(0xFF35A56A),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
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
  // ROLE BADGE
  // ============================================================

  Widget _roleBadge(String role, bool isSarpanch) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSarpanch ? 10 : 8,
        vertical: isSarpanch ? 5 : 4,
      ),
      decoration: BoxDecoration(
        color: isSarpanch ? primaryGreen.withOpacity(0.10) : lightGreen,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: primaryGreen,
          fontSize: 9,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  // ============================================================
  // SMALL INFO
  // ============================================================

  Widget _smallInfo(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: primaryGreen, size: 15),

        const SizedBox(width: 5),

        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // MEMBER MENU
  // ============================================================

  Widget _memberMenu(Map<String, dynamic> member) {
    return PopupMenuButton<String>(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      icon: const Icon(Icons.more_vert_rounded, color: mutedText, size: 21),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _editMember(member);
            break;

          case 'delete':
            _deleteMember(member);
            break;
        }
      },
      itemBuilder: (context) {
        return [
          PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                const Icon(Icons.edit_outlined, size: 20, color: primaryGreen),
                const SizedBox(width: 10),
                Text(_t('Edit', 'संपादित करें')),
              ],
            ),
          ),

          PopupMenuItem<String>(
            value: 'delete',
            child: Row(
              children: [
                const Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: Colors.red,
                ),
                const SizedBox(width: 10),
                Text(
                  _t('Delete', 'हटाएं'),
                  style: const TextStyle(color: Colors.red),
                ),
              ],
            ),
          ),
        ];
      },
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    final searching = _searchQuery.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 42),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: primaryGreen.withOpacity(0.06)),
      ),
      child: Column(
        children: [
          Container(
            height: 70,
            width: 70,
            decoration: const BoxDecoration(
              color: lightGreen,
              shape: BoxShape.circle,
            ),
            child: Icon(
              searching ? Icons.search_off_rounded : Icons.groups_outlined,
              size: 34,
              color: primaryGreen.withOpacity(0.60),
            ),
          ),

          const SizedBox(height: 15),

          Text(
            searching
                ? _t('No members found', 'कोई सदस्य नहीं मिला')
                : _t('No members yet', 'अभी कोई सदस्य नहीं है'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: darkText,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            searching
                ? _t(
                    'Try another name, mobile number, email or ward.',
                    'दूसरा नाम, मोबाइल नंबर, ईमेल या वार्ड खोजें।',
                  )
                : _t(
                    'Members added to the Panchayat will appear here.',
                    'पंचायत में जोड़े गए सदस्य यहां दिखाई देंगे।',
                  ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: mutedText,
              fontSize: 12.5,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ADD BUTTON
  // ============================================================

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, right: 4),
      child: FloatingActionButton.extended(
        onPressed: _addMember,
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
        label: Text(
          _t('Add Member', 'सदस्य जोड़ें'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

// ============================================================
// BUBBLE MODEL
// ============================================================

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

// ============================================================
// BUBBLE PAINTER
// ============================================================

class _BubblePainter extends CustomPainter {
  final List<_Bubble> bubbles;
  final double animationValue;

  _BubblePainter({required this.bubbles, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    for (final bubble in bubbles) {
      final wave = sin((animationValue * pi * 2 * bubble.speed) + bubble.phase);

      final dx = bubble.left * size.width + wave * 12;

      final dy = bubble.top * size.height + cos(wave + bubble.phase) * 10;

      final paint = Paint()
        ..color = const Color(0xFF176B4D).withOpacity(bubble.opacity);

      canvas.drawCircle(Offset(dx, dy), bubble.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
