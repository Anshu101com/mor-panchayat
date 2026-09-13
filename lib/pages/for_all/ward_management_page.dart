import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class WardManagementPage extends StatefulWidget {
  final bool isHindi;

  const WardManagementPage({super.key, required this.isHindi});

  @override
  State<WardManagementPage> createState() => _WardManagementPageState();
}

class _WardManagementPageState extends State<WardManagementPage>
    with SingleTickerProviderStateMixin {
  // ============================================================
  // CONSTANTS
  // ============================================================

  static const Color primaryGreen = Color(0xFF176B4D);
  static const Color secondaryGreen = Color(0xFF22815E);
  static const Color lightGreen = Color(0xFFEAF5F0);
  static const Color backgroundColor = Color(0xFFF4FAF7);
  static const Color softBackground = Color(0xFFF7FAF8);
  static const Color darkText = Color(0xFF18352B);
  static const Color mutedText = Color(0xFF718078);
  static const Color successGreen = Color(0xFF35A56A);

  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _searchController = TextEditingController();

  late AnimationController _bubbleController;

  // ============================================================
  // DATA
  // ============================================================

  List<Map<String, dynamic>> _members = [];

  bool _isLoading = true;
  bool _isSaving = false;

  String _searchQuery = '';

  RealtimeChannel? _profilesChannel;

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

    _loadMembers();
    _setupRealtime();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchController.dispose();
    _bubbleController.dispose();

    if (_profilesChannel != null) {
      _supabase.removeChannel(_profilesChannel!);
    }

    super.dispose();
  }

  // ============================================================
  // LOAD MEMBERS
  // ============================================================

  Future<void> _loadMembers() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _supabase
          .from('profiles')
          .select('id, name, email, mobile, role, ward_number, user_id')
          .eq('role', 'member')
          .order('ward_number', ascending: true);

      if (!mounted) return;

      setState(() {
        _members = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('WARD LOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        _t('Could not load ward members.', 'वार्ड सदस्य लोड नहीं हो सके।'),
        isError: true,
      );
    }
  }

  // ============================================================
  // REALTIME
  // ============================================================

  void _setupRealtime() {
    _profilesChannel = _supabase
        .channel('ward-management-realtime')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'profiles',
          callback: (payload) {
            debugPrint('Ward realtime update: ${payload.eventType}');

            _loadMembers();
          },
        )
        .subscribe();
  }

  // ============================================================
  // FILTER
  // ============================================================

  List<Map<String, dynamic>> get _filteredMembers {
    if (_searchQuery.trim().isEmpty) {
      return _members;
    }

    final query = _searchQuery.trim().toLowerCase();

    return _members.where((member) {
      final name = (member['name'] ?? '').toString().toLowerCase();

      final mobile = (member['mobile'] ?? '').toString().toLowerCase();

      final ward = (member['ward_number'] ?? '').toString().toLowerCase();

      return name.contains(query) ||
          mobile.contains(query) ||
          ward.contains(query);
    }).toList();
  }

  // ============================================================
  // STATS
  // ============================================================

  int get _assignedCount {
    return _members.where((member) {
      final ward = member['ward_number']?.toString().trim();

      return ward != null && ward.isNotEmpty;
    }).length;
  }

  int get _unassignedCount {
    return _members.length - _assignedCount;
  }

  // ============================================================
  // ASSIGN MEMBER
  // ============================================================

  Future<void> _assignWard(
    Map<String, dynamic> member,
    String wardNumber,
  ) async {
    if (_isSaving) return;

    final cleanWard = wardNumber.trim();

    if (cleanWard.isEmpty) {
      _showMessage(
        _t('Please enter a ward number.', 'कृपया वार्ड नंबर दर्ज करें।'),
        isError: true,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final memberId = member['id'];

      // --------------------------------------------------------
      // CHECK DUPLICATE WARD
      // --------------------------------------------------------

      final existing = await _supabase
          .from('profiles')
          .select('id, name')
          .eq('role', 'member')
          .eq('ward_number', cleanWard)
          .neq('id', memberId)
          .maybeSingle();

      if (existing != null) {
        if (!mounted) return;

        _showMessage(
          _t(
            'Ward $cleanWard is already assigned to ${existing['name']}.',
            'वार्ड $cleanWard पहले से ${existing['name']} को सौंपा गया है।',
          ),
          isError: true,
        );

        setState(() {
          _isSaving = false;
        });

        return;
      }

      // --------------------------------------------------------
      // UPDATE
      // --------------------------------------------------------

      await _supabase
          .from('profiles')
          .update({
            'ward_number': cleanWard,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', memberId);

      if (!mounted) return;

      Navigator.pop(context);

      _showMessage(
        _t('Ward assigned successfully.', 'वार्ड सफलतापूर्वक सौंपा गया।'),
      );

      await _loadMembers();
    } catch (e) {
      debugPrint('WARD ASSIGN ERROR: $e');

      if (!mounted) return;

      _showMessage(
        _t('Could not assign ward.', 'वार्ड असाइन नहीं किया जा सका।'),
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
  // REMOVE WARD
  // ============================================================

  Future<void> _removeWard(Map<String, dynamic> member) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _supabase
          .from('profiles')
          .update({
            'ward_number': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', member['id']);

      if (!mounted) return;

      _showMessage(
        _t('Ward assignment removed.', 'वार्ड असाइनमेंट हटा दिया गया।'),
      );

      await _loadMembers();
    } catch (e) {
      debugPrint('WARD REMOVE ERROR: $e');

      if (!mounted) return;

      _showMessage(
        _t(
          'Could not remove ward assignment.',
          'वार्ड असाइनमेंट हटाया नहीं जा सका।',
        ),
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
  // ASSIGN DIALOG
  // ============================================================

  void _showAssignDialog(Map<String, dynamic> member) {
    final controller = TextEditingController(
      text: member['ward_number']?.toString() ?? '',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentWard = member['ward_number']?.toString().trim();

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: primaryGreen.withOpacity(0.12),
                      blurRadius: 35,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ------------------------------------------------
                      // HEADER
                      // ------------------------------------------------
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: lightGreen,
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: const Icon(
                              Icons.location_city_rounded,
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
                                  currentWard == null || currentWard.isEmpty
                                      ? _t('Assign Ward', 'वार्ड सौंपें')
                                      : _t('Change Ward', 'वार्ड बदलें'),
                                  style: const TextStyle(
                                    color: darkText,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  member['name']?.toString() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: mutedText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Material(
                            color: softBackground,
                            borderRadius: BorderRadius.circular(13),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(13),
                              onTap: _isSaving
                                  ? null
                                  : () {
                                      Navigator.pop(dialogContext);
                                    },
                              child: const SizedBox(
                                width: 42,
                                height: 42,
                                child: Icon(
                                  Icons.close_rounded,
                                  color: mutedText,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // ------------------------------------------------
                      // MEMBER PREVIEW
                      // ------------------------------------------------
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: softBackground,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: primaryGreen.withOpacity(0.06),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                color: lightGreen,
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _memberInitial(member),
                                style: const TextStyle(
                                  color: primaryGreen,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member['name']?.toString() ??
                                        _t('Member', 'सदस्य'),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: darkText,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    currentWard == null || currentWard.isEmpty
                                        ? _t(
                                            'No ward assigned',
                                            'कोई वार्ड असाइन नहीं है',
                                          )
                                        : '${_t('Current Ward', 'वर्तमान वार्ड')}: $currentWard',
                                    style: const TextStyle(
                                      color: mutedText,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 22),

                      Text(
                        _t('Ward Number', 'वार्ड नंबर'),
                        style: const TextStyle(
                          color: darkText,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 8),

                      TextField(
                        controller: controller,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: _t(
                            'Enter ward number',
                            'वार्ड नंबर दर्ज करें',
                          ),
                          prefixIcon: const Icon(
                            Icons.pin_drop_outlined,
                            color: primaryGreen,
                          ),
                          filled: true,
                          fillColor: softBackground,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: primaryGreen,
                              width: 1.3,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      // ------------------------------------------------
                      // SAVE BUTTON
                      // ------------------------------------------------
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: _isSaving
                              ? null
                              : () async {
                                  setDialogState(() {});

                                  await _assignWard(member, controller.text);
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryGreen,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: primaryGreen.withOpacity(
                              0.6,
                            ),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
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
                              : Text(
                                  currentWard == null || currentWard.isEmpty
                                      ? _t('Assign Ward', 'वार्ड सौंपें')
                                      : _t('Update Ward', 'वार्ड अपडेट करें'),
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((_) {
      controller.dispose();
    });
  }

  // ============================================================
  // REMOVE CONFIRMATION
  // ============================================================

  void _confirmRemoveWard(Map<String, dynamic> member) {
    final name = member['name']?.toString() ?? _t('Member', 'सदस्य');

    final ward = member['ward_number']?.toString() ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            padding: const EdgeInsets.all(24),
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
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.location_off_outlined,
                    color: Colors.red.shade600,
                    size: 29,
                  ),
                ),

                const SizedBox(height: 17),

                Text(
                  _t('Remove Ward Assignment?', 'वार्ड असाइनमेंट हटाएँ?'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 9),

                Text(
                  _t(
                    '$name will no longer be assigned to Ward $ward.',
                    '$name अब वार्ड $ward को असाइन नहीं होंगे।',
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: mutedText,
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 23),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryGreen,
                          side: BorderSide(
                            color: primaryGreen.withOpacity(0.35),
                          ),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _t('Cancel', 'रद्द करें'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          _removeWard(member);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _t('Remove', 'हटाएँ'),
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
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final members = _filteredMembers;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _bubbleController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _WardBubblePainter(
                      animationValue: _bubbleController.value,
                    ),
                  );
                },
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildHeader(),

                Expanded(
                  child: RefreshIndicator(
                    color: primaryGreen,
                    backgroundColor: Colors.white,
                    onRefresh: _loadMembers,
                    child: _isLoading
                        ? _buildLoadingState()
                        : members.isEmpty
                        ? _buildEmptyState()
                        : ListView(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                            children: [
                              _buildOverviewCard(),

                              const SizedBox(height: 18),

                              if (_searchQuery.trim().isNotEmpty)
                                _buildSearchResultLabel(),

                              ...members.map(_buildMemberCard),
                            ],
                          ),
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
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              _buildBackButton(),

              const SizedBox(width: 13),

              // MOR PANCHAYAT BRAND
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
                child: Text(
                  'Mor Panchayat',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: darkText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              _buildRefreshButton(),
            ],
          ),

          const SizedBox(height: 15),

          _buildSearchField(),
        ],
      ),
    );
  }

  // ============================================================
  // BACK BUTTON
  // ============================================================

  Widget _buildBackButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.045),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.arrow_back_rounded,
            color: primaryGreen,
            size: 22,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // REFRESH BUTTON
  // ============================================================

  Widget _buildRefreshButton() {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: _isLoading ? null : _loadMembers,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.045),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(Icons.refresh_rounded, color: primaryGreen, size: 22),
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
      decoration: InputDecoration(
        hintText: _t('Search member or ward...', 'सदस्य या वार्ड खोजें...'),
        hintStyle: const TextStyle(color: mutedText, fontSize: 13),
        prefixIcon: const Icon(
          Icons.search_rounded,
          color: primaryGreen,
          size: 22,
        ),
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
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
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
      ),
    );
  }

  // ============================================================
  // OVERVIEW CARD
  // ============================================================

  Widget _buildOverviewCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryGreen, secondaryGreen],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
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
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_city_rounded,
                  color: Colors.white,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Ward Overview', 'वार्ड अवलोकन'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _t(
                        'Manage Panchayat member assignments',
                        'पंचायत सदस्यों के वार्ड प्रबंधित करें',
                      ),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _overviewStat(
                  Icons.groups_outlined,
                  _members.length.toString(),
                  _t('Members', 'सदस्य'),
                ),
              ),

              _verticalDivider(),

              Expanded(
                child: _overviewStat(
                  Icons.location_on_outlined,
                  _assignedCount.toString(),
                  _t('Assigned', 'असाइन'),
                ),
              ),

              _verticalDivider(),

              Expanded(
                child: _overviewStat(
                  Icons.location_off_outlined,
                  _unassignedCount.toString(),
                  _t('Pending', 'बाकी'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overviewStat(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 21),
        const SizedBox(height: 5),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(height: 45, width: 1, color: Colors.white24);
  }

  // ============================================================
  // SEARCH RESULT LABEL
  // ============================================================

  Widget _buildSearchResultLabel() {
    final count = _filteredMembers.length;

    return Padding(
      padding: const EdgeInsets.only(left: 3, right: 3, bottom: 12),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: primaryGreen, size: 17),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _t(
                '$count result${count == 1 ? '' : 's'} found',
                '$count परिणाम मिले',
              ),
              style: const TextStyle(
                color: mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MEMBER CARD
  // ============================================================

  Widget _buildMemberCard(Map<String, dynamic> member) {
    final name = member['name']?.toString().trim();

    final displayName = name == null || name.isEmpty
        ? _t('Unknown Member', 'अज्ञात सदस्य')
        : name;

    final mobile = member['mobile']?.toString().trim() ?? '';

    final ward = member['ward_number']?.toString().trim();

    final hasWard = ward != null && ward.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hasWard
              ? primaryGreen.withOpacity(0.07)
              : Colors.orange.withOpacity(0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ------------------------------------------------
                // AVATAR
                // ------------------------------------------------
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    color: lightGreen,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _memberInitial(member),
                    style: const TextStyle(
                      color: primaryGreen,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                const SizedBox(width: 13),

                // ------------------------------------------------
                // MEMBER INFO
                // ------------------------------------------------
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

                          const SizedBox(width: 8),

                          _statusBadge(hasWard),
                        ],
                      ),

                      const SizedBox(height: 8),

                      if (mobile.isNotEmpty)
                        Row(
                          children: [
                            Container(
                              width: 25,
                              height: 25,
                              decoration: BoxDecoration(
                                color: softBackground,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.phone_outlined,
                                color: primaryGreen,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                mobile,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: mutedText,
                                  fontSize: 11.5,
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

            const SizedBox(height: 14),

            // ----------------------------------------------------
            // WARD STATUS
            // ----------------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: hasWard ? lightGreen : const Color(0xFFFFF8EC),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: hasWard ? Colors.white : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      hasWard
                          ? Icons.location_on_rounded
                          : Icons.location_off_outlined,
                      color: hasWard ? primaryGreen : Colors.orange.shade700,
                      size: 18,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasWard
                              ? _t('Assigned Ward', 'असाइन किया गया वार्ड')
                              : _t('Ward not assigned', 'वार्ड असाइन नहीं है'),
                          style: TextStyle(
                            color: hasWard
                                ? primaryGreen
                                : Colors.orange.shade800,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          hasWard
                              ? '${_t('Ward', 'वार्ड')} $ward'
                              : _t('Needs assignment', 'असाइन करना बाकी है'),
                          style: TextStyle(
                            color: hasWard ? darkText : Colors.orange.shade900,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (hasWard)
                    const Icon(
                      Icons.check_circle_rounded,
                      color: successGreen,
                      size: 20,
                    ),
                ],
              ),
            ),

            const SizedBox(height: 13),

            // ----------------------------------------------------
            // ACTIONS
            // ----------------------------------------------------
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 45,
                    child: ElevatedButton.icon(
                      onPressed: () => _showAssignDialog(member),
                      icon: Icon(
                        hasWard
                            ? Icons.swap_horiz_rounded
                            : Icons.add_location_alt_outlined,
                        size: 18,
                      ),
                      label: Text(
                        hasWard
                            ? _t('Change Ward', 'वार्ड बदलें')
                            : _t('Assign Ward', 'वार्ड सौंपें'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),

                if (hasWard) ...[
                  const SizedBox(width: 9),

                  Material(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _confirmRemoveWard(member),
                      child: SizedBox(
                        width: 45,
                        height: 45,
                        child: Icon(
                          Icons.location_off_outlined,
                          color: Colors.red.shade600,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // STATUS BADGE
  // ============================================================

  Widget _statusBadge(bool hasWard) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: hasWard ? lightGreen : const Color(0xFFFFF4DF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: hasWard ? successGreen : Colors.orange.shade600,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            hasWard ? _t('Assigned', 'असाइन') : _t('Pending', 'बाकी'),
            style: TextStyle(
              color: hasWard ? primaryGreen : Colors.orange.shade800,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
        const SizedBox(height: 110),
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Padding(
              padding: EdgeInsets.all(19),
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: primaryGreen,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _t('Loading ward members...', 'वार्ड सदस्य लोड हो रहे हैं...'),
            style: const TextStyle(
              color: mutedText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    final searching = _searchQuery.trim().isNotEmpty;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
      children: [
        const SizedBox(height: 45),

        Center(
          child: Container(
            width: 94,
            height: 94,
            decoration: BoxDecoration(
              color: lightGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryGreen.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(
              searching
                  ? Icons.search_off_rounded
                  : Icons.location_city_outlined,
              size: 43,
              color: primaryGreen,
            ),
          ),
        ),

        const SizedBox(height: 20),

        Text(
          searching
              ? _t('No members found', 'कोई सदस्य नहीं मिला')
              : _t('No Panchayat members found', 'कोई पंचायत सदस्य नहीं मिला'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: darkText,
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          searching
              ? _t(
                  'Try searching with another name, mobile number or ward.',
                  'दूसरा नाम, मोबाइल नंबर या वार्ड खोजकर देखें।',
                )
              : _t(
                  'Add Panchayat members first, then assign them to their wards.',
                  'पहले पंचायत सदस्य जोड़ें, फिर उन्हें उनके वार्ड सौंपें।',
                ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: mutedText, fontSize: 13, height: 1.5),
        ),
      ],
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _memberInitial(Map<String, dynamic> member) {
    final name = member['name']?.toString().trim() ?? '';

    if (name.isEmpty) return 'M';

    return name.characters.first.toUpperCase();
  }
}

// ================================================================
// ANIMATED BUBBLE BACKGROUND
// ================================================================

class _WardBubblePainter extends CustomPainter {
  final double animationValue;

  _WardBubblePainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final random = Random(31);

    for (int i = 0; i < 15; i++) {
      final radius = 25 + random.nextDouble() * 75;

      final baseX = random.nextDouble() * size.width;

      final baseY = random.nextDouble() * size.height;

      final movement = sin(animationValue * 2 * pi + i * 0.7) * 14;

      final x = baseX + movement;

      final y = baseY + cos(animationValue * 2 * pi + i * 0.5) * 12;

      final opacity = 0.018 + random.nextDouble() * 0.028;

      final paint = Paint()
        ..color = const Color(0xFF176B4D).withOpacity(opacity);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WardBubblePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
