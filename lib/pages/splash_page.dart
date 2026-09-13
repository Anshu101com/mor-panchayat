import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'welcome_page.dart';
import 'package:mor_panchayat/pages/sarpanch_pages/sarpanch_home_page.dart';
import 'package:mor_panchayat/pages/villagers_pages/villager_home_page.dart';
import 'package:mor_panchayat/pages/member_pages/panchayat_member_home_page.dart';
import 'package:mor_panchayat/services/update_service.dart';

class SplashPage extends StatefulWidget {
  final bool isHindi;

  const SplashPage({super.key, this.isHindi = false});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  static const Color primaryGreen = Color(0xFF176B4D);

  static const MethodChannel _installerChannel = MethodChannel(
    'mor_panchayat/apk_installer',
  );

  bool _isDownloadingUpdate = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _startup();
  }

  // ==========================================================
  // STARTUP
  // ==========================================================

  Future<void> _startup() async {
    // Give Flutter a moment to display the splash screen.
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // ========================================================
    // CHECK FOR APP UPDATE FIRST
    // ========================================================

    final updateInfo = await UpdateService.checkForUpdate();

    if (!mounted) return;

    if (updateInfo != null) {
      final isRequired = UpdateService.isUpdateRequired(updateInfo);

      if (!mounted) return;

      // ========================================================
      // REQUIRED UPDATE
      // ========================================================

      if (isRequired) {
        await _showCriticalUpdateDialog(updateInfo);
        return;
      }

      // ========================================================
      // OPTIONAL UPDATE
      // ========================================================

      final shouldUpdate = await _showOptionalUpdateDialog(updateInfo);

      if (!mounted) return;

      if (shouldUpdate) {
        await _openUpdateLink(updateInfo.apkUrl, isRequired: false);

        return;
      }
    }

    // ========================================================
    // NO UPDATE / USER CHOSE LATER
    // ========================================================

    await _checkSession();
  }

  // ==========================================================
  // OPTIONAL UPDATE DIALOG
  // ==========================================================

  Future<bool> _showOptionalUpdateDialog(UpdateInfo updateInfo) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),

          title: const Row(
            children: [
              Icon(Icons.system_update_rounded, color: primaryGreen),

              SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Update Available',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A new version '
                '${updateInfo.latestVersion} '
                'of Mor Panchayat is available.',
              ),

              if (updateInfo.releaseNotes.isNotEmpty) ...[
                const SizedBox(height: 16),

                const Text(
                  'What\'s new:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),

                const SizedBox(height: 8),

                ...updateInfo.releaseNotes.map((note) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),

                        Expanded(child: Text(note)),
                      ],
                    ),
                  );
                }),
              ],
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Later'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              style: FilledButton.styleFrom(backgroundColor: primaryGreen),
              child: const Text('Update Now'),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ==========================================================
  // CRITICAL UPDATE DIALOG
  // ==========================================================

  Future<void> _showCriticalUpdateDialog(UpdateInfo updateInfo) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,

          child: AlertDialog(
            backgroundColor: Colors.white,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),

            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),

                SizedBox(width: 10),

                Expanded(
                  child: Text(
                    'Important Update',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),

            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mor Panchayat '
                  '${updateInfo.latestVersion} '
                  'is required to continue using the app.',
                ),

                if (updateInfo.releaseNotes.isNotEmpty) ...[
                  const SizedBox(height: 16),

                  const Text(
                    'What\'s new:',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),

                  const SizedBox(height: 8),

                  ...updateInfo.releaseNotes.map((note) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),

                          Expanded(child: Text(note)),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),

            actions: [
              TextButton(
                onPressed: () {
                  SystemNavigator.pop();
                },
                child: const Text('Exit App'),
              ),

              FilledButton(
                onPressed: () async {
                  await _openUpdateLink(updateInfo.apkUrl, isRequired: true);
                },
                style: FilledButton.styleFrom(backgroundColor: primaryGreen),
                child: const Text('Update Now'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================================
  // DOWNLOAD + INSTALL UPDATE
  // ==========================================================

  Future<void> _openUpdateLink(String url, {required bool isRequired}) async {
    if (_isDownloadingUpdate) {
      return;
    }

    if (url.trim().isEmpty) {
      debugPrint('Update URL is empty.');

      if (mounted) {
        await _showUpdateError(isRequired: isRequired);
      }

      return;
    }

    setState(() {
      _isDownloadingUpdate = true;
      _downloadProgress = 0.0;
    });

    bool downloadDialogOpen = false;

    try {
      debugPrint('==========================================');
      debugPrint('MOR PANCHAYAT UPDATE');
      debugPrint('APK URL: $url');
      debugPrint('==========================================');

      final directory = await getTemporaryDirectory();
      final apkPath = '${directory.path}/mor_panchayat_update.apk';
      final apkFile = File(apkPath);

      // ----------------------------------------------------------
      // DELETE PREVIOUS APK
      // ----------------------------------------------------------

      if (await apkFile.exists()) {
        await apkFile.delete();
      }

      if (!mounted) return;

      // ----------------------------------------------------------
      // DOWNLOAD DIALOG
      // ----------------------------------------------------------

      _showDownloadProgressDialog(isRequired: isRequired);
      downloadDialogOpen = true;

      // ----------------------------------------------------------
      // DOWNLOAD APK
      // ----------------------------------------------------------

      final dio = Dio();

      await dio.download(
        url,
        apkPath,
        onReceiveProgress: (received, total) {
          if (!mounted) return;

          if (total > 0) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 1),
          validateStatus: (status) {
            return status != null && status >= 200 && status < 400;
          },
        ),
      );

      // ----------------------------------------------------------
      // VERIFY APK
      // ----------------------------------------------------------

      if (!await apkFile.exists()) {
        throw Exception('APK file was not created.');
      }

      final fileSize = await apkFile.length();

      debugPrint('Downloaded APK size: $fileSize bytes');

      if (fileSize < 100 * 1024) {
        throw Exception('Downloaded file is too small to be a valid APK.');
      }

      debugPrint('APK downloaded successfully.');

      // ----------------------------------------------------------
      // COMPLETE DOWNLOAD
      // ----------------------------------------------------------

      if (mounted) {
        setState(() {
          _downloadProgress = 1.0;
        });
      }

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      // ----------------------------------------------------------
      // CLOSE DOWNLOAD DIALOG
      // ----------------------------------------------------------

      if (downloadDialogOpen && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        downloadDialogOpen = false;
      }

      // ----------------------------------------------------------
      // CHECK UNKNOWN APP INSTALL PERMISSION
      // ----------------------------------------------------------

      bool canInstall =
          await _installerChannel.invokeMethod<bool>('canInstallPackages') ??
          false;

      debugPrint('Can install unknown apps: $canInstall');

      // ----------------------------------------------------------
      // ASK FOR INSTALL PERMISSION
      // ----------------------------------------------------------

      if (!canInstall) {
        debugPrint('Opening Android install permission settings...');

        await _installerChannel.invokeMethod('openInstallSettings');

        if (!mounted) return;

        // --------------------------------------------------------
        // Tell the user what to do
        // --------------------------------------------------------

        await _showInstallPermissionDialog();

        if (!mounted) return;

        // --------------------------------------------------------
        // Check permission again after returning
        // --------------------------------------------------------

        canInstall =
            await _installerChannel.invokeMethod<bool>('canInstallPackages') ??
            false;

        debugPrint('Can install after permission screen: $canInstall');

        if (!canInstall) {
          debugPrint('Install permission was not granted.');

          if (isRequired) {
            await _showUpdateError(isRequired: true);
          }

          return;
        }
      }

      // ----------------------------------------------------------
      // OPEN ANDROID PACKAGE INSTALLER
      // ----------------------------------------------------------

      debugPrint('Opening Android package installer...');

      final installed = await _installerChannel.invokeMethod<bool>(
        'installApk',
        {'path': apkPath},
      );

      debugPrint('Installer launched: $installed');

      if (installed != true) {
        throw Exception('Android package installer could not be opened.');
      }

      // ----------------------------------------------------------
      // IMPORTANT
      //
      // Android now takes over the installation.
      // The user will see the normal Android installation screen.
      // ----------------------------------------------------------

      debugPrint('Android installer opened successfully.');
    } catch (e, stackTrace) {
      debugPrint('==========================================');
      debugPrint('UPDATE INSTALL ERROR');
      debugPrint('Error: $e');
      debugPrint('StackTrace: $stackTrace');
      debugPrint('==========================================');

      if (!mounted) return;

      if (downloadDialogOpen && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      await _showUpdateError(isRequired: isRequired);
    } finally {
      if (mounted) {
        setState(() {
          _isDownloadingUpdate = false;
        });
      }
    }
  }

  Future<void> _showInstallPermissionDialog() async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Installation Permission',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'Android requires permission to install '
            'updates from Mor Panchayat.\n\n'
            'Please enable "Allow from this source" '
            'for Mor Panchayat, then return to the app.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: FilledButton.styleFrom(backgroundColor: primaryGreen),
              child: const Text('Continue'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // DOWNLOAD PROGRESS DIALOG
  // ==========================================================

  Future<void> _showDownloadProgressDialog({required bool isRequired}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,

      builder: (context) {
        return PopScope(
          canPop: false,

          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                backgroundColor: Colors.white,

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),

                title: const Text(
                  'Downloading Update',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),

                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),

                    LinearProgressIndicator(
                      value: _downloadProgress > 0 ? _downloadProgress : null,

                      color: primaryGreen,
                    ),

                    const SizedBox(height: 14),

                    Text(
                      _downloadProgress > 0
                          ? '${(_downloadProgress * 100).toStringAsFixed(0)}%'
                          : 'Preparing download...',
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Please do not close the app.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ==========================================================
  // UPDATE ERROR
  // ==========================================================

  Future<void> _showUpdateError({required bool isRequired}) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,

      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),

          title: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.red),

              SizedBox(width: 10),

              Expanded(
                child: Text(
                  'Update Failed',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),

          content: Text(
            isRequired
                ? 'The required update could not be downloaded or installed. '
                      'Please check your internet connection and try again.'
                : 'We could not download or install the update. '
                      'Please check your internet connection and try again.',
          ),

          actions: [
            if (!isRequired)
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Continue'),
              ),

            FilledButton(
              onPressed: () {
                Navigator.pop(context);

                if (isRequired) {
                  // The critical update dialog will
                  // remain underneath.
                }
              },

              style: FilledButton.styleFrom(backgroundColor: primaryGreen),

              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // ==========================================================
  // SESSION CHECK
  // ==========================================================

  Future<void> _checkSession() async {
    // Give Flutter a moment to display the splash screen.
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    final supabase = Supabase.instance.client;

    // --------------------------------------------------------
    // CHECK CURRENT SESSION
    // --------------------------------------------------------

    final session = supabase.auth.currentSession;

    // --------------------------------------------------------
    // NO EXISTING LOGIN
    // --------------------------------------------------------

    if (session == null) {
      _goToWelcome();
      return;
    }

    // --------------------------------------------------------
    // EXISTING LOGIN
    // --------------------------------------------------------

    final user = session.user;

    try {
      // Get the complete Panchayat profile.
      final profile = await supabase
          .from('profiles')
          .select('role, name, mobile, ward_number')
          .eq('user_id', user.id)
          .maybeSingle();

      if (!mounted) return;

      // ------------------------------------------------------
      // PROFILE NOT FOUND
      // ------------------------------------------------------

      if (profile == null) {
        debugPrint(
          'No Panchayat profile found '
          'for user: ${user.id}',
        );

        await supabase.auth.signOut();

        if (!mounted) return;

        _goToWelcome();

        return;
      }

      // ------------------------------------------------------
      // READ PROFILE DATA
      // ------------------------------------------------------

      final role = profile['role']?.toString().trim().toLowerCase() ?? '';

      final name = profile['name']?.toString().trim() ?? '';

      final mobile = profile['mobile']?.toString().trim() ?? '';

      final wardNumber = profile['ward_number']?.toString().trim() ?? '';

      debugPrint('==========================================');

      debugPrint('SESSION RESTORED');

      debugPrint('User ID: ${user.id}');

      debugPrint('Email: ${user.email}');

      debugPrint('Role: $role');

      debugPrint('Name: $name');

      debugPrint('Mobile: $mobile');

      debugPrint('Ward: $wardNumber');

      debugPrint('==========================================');

      // ------------------------------------------------------
      // SARPANCH
      // ------------------------------------------------------

      if (role == 'sarpanch') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SarpanchHomePage(
              isHindi: widget.isHindi,

              sarpanchName: name.isNotEmpty ? name : 'Sarpanch',

              mobileNumber: mobile,
            ),
          ),
        );

        return;
      }

      // ------------------------------------------------------
      // MEMBER
      // ------------------------------------------------------

      if (role == 'member') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PanchayatMemberHomePage(
              isHindi: widget.isHindi,

              memberName: name.isNotEmpty ? name : 'Member',

              wardNumber: wardNumber,

              mobileNumber: mobile,
            ),
          ),
        );

        return;
      }

      // ------------------------------------------------------
      // VILLAGER
      // ------------------------------------------------------

      if (role == 'villager') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => VillagerHomePage(isHindi: widget.isHindi),
          ),
        );

        return;
      }

      // ------------------------------------------------------
      // UNKNOWN ROLE
      // ------------------------------------------------------

      debugPrint('Unknown role: $role');

      await supabase.auth.signOut();

      if (!mounted) return;

      _goToWelcome();
    } catch (e, stackTrace) {
      debugPrint('==========================================');

      debugPrint('SESSION CHECK ERROR');

      debugPrint('Error: $e');

      debugPrint('StackTrace: $stackTrace');

      debugPrint('==========================================');

      if (!mounted) return;

      _goToWelcome();
    }
  }

  // ==========================================================
  // GO TO WELCOME PAGE
  // ==========================================================

  void _goToWelcome() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => WelcomePage()));
  }

  // ==========================================================
  // BUILD SPLASH SCREEN
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),

      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,

          children: [
            Container(
              height: 72,
              width: 72,

              decoration: BoxDecoration(
                color: primaryGreen,

                borderRadius: BorderRadius.circular(22),
              ),

              child: const Icon(
                Icons.account_balance_rounded,

                color: Colors.white,

                size: 38,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'Mor Panchayat',

              style: TextStyle(
                color: Color(0xFF18352B),

                fontSize: 22,

                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 8),

            const SizedBox(
              width: 22,
              height: 22,

              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: primaryGreen,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
