import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String minimumVersion;
  final String apkUrl;
  final bool critical;
  final List<String> releaseNotes;

  const UpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.minimumVersion,
    required this.apkUrl,
    required this.critical,
    required this.releaseNotes,
  });

  /// True when the installed app is older than the latest release.
  bool get updateAvailable {
    return UpdateService.compareVersions(currentVersion, latestVersion) < 0;
  }

  /// True when the installed app is below the minimum supported version.
  bool get forceUpdate {
    return UpdateService.compareVersions(currentVersion, minimumVersion) < 0;
  }
}

class UpdateService {
  // ============================================================
  // UPDATE JSON
  // ============================================================

  static const String updateUrl =
      'https://raw.githubusercontent.com/Anshu101com/mor_panchayat/main/update.json';

  // ============================================================
  // CHECK FOR UPDATE
  // ============================================================

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      // ----------------------------------------------------------
      // Get installed app version
      // ----------------------------------------------------------

      final packageInfo = await PackageInfo.fromPlatform();

      final currentVersion = _cleanVersion(packageInfo.version);

      // ----------------------------------------------------------
      // Download update.json
      // ----------------------------------------------------------

      final response = await http
          .get(
            Uri.parse(updateUrl),
            headers: {'Cache-Control': 'no-cache', 'Pragma': 'no-cache'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        print('Update check failed: HTTP ${response.statusCode}');
        return null;
      }

      // ----------------------------------------------------------
      // Decode JSON
      // ----------------------------------------------------------

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        print('Update check failed: Invalid update.json format');
        return null;
      }

      final data = decoded;

      // ----------------------------------------------------------
      // Read latest version
      // ----------------------------------------------------------

      final latestVersion = _cleanVersion(
        data['latestVersion']?.toString() ?? currentVersion,
      );

      // ----------------------------------------------------------
      // Read minimum supported version
      // ----------------------------------------------------------

      final minimumVersion = _cleanVersion(
        data['minimumVersion']?.toString() ?? latestVersion,
      );

      // ----------------------------------------------------------
      // Read APK URL
      // ----------------------------------------------------------

      final apkUrl = data['apkUrl']?.toString().trim() ?? '';

      // ----------------------------------------------------------
      // Read critical flag
      // ----------------------------------------------------------

      final critical =
          data['critical'] == true ||
          data['critical']?.toString().toLowerCase() == 'true';

      // ----------------------------------------------------------
      // Read release notes
      // ----------------------------------------------------------

      final releaseNotes = <String>[];

      final rawNotes = data['releaseNotes'];

      if (rawNotes is List) {
        for (final note in rawNotes) {
          final text = note.toString().trim();

          if (text.isNotEmpty) {
            releaseNotes.add(text);
          }
        }
      }

      // ----------------------------------------------------------
      // Create update information
      // ----------------------------------------------------------

      final updateInfo = UpdateInfo(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        minimumVersion: minimumVersion,
        apkUrl: apkUrl,
        critical: critical,
        releaseNotes: releaseNotes,
      );

      // ----------------------------------------------------------
      // No update available
      // ----------------------------------------------------------

      if (!updateInfo.updateAvailable) {
        print('App is up to date: $currentVersion');

        return null;
      }

      // ----------------------------------------------------------
      // Update available
      // ----------------------------------------------------------

      print(
        'Update available: '
        '$currentVersion → $latestVersion',
      );

      print('Minimum supported version: $minimumVersion');

      print('Force update: ${updateInfo.forceUpdate}');

      return updateInfo;
    } catch (e) {
      print('Update check failed: $e');
      return null;
    }
  }

  // ============================================================
  // CHECK IF UPDATE IS REQUIRED
  // ============================================================

  static bool isUpdateRequired(UpdateInfo updateInfo) {
    return compareVersions(
          updateInfo.currentVersion,
          updateInfo.minimumVersion,
        ) <
        0;
  }

  // ============================================================
  // VERSION COMPARISON
  //
  // Examples:
  //
  // 1.0.9  < 1.0.10
  // 1.0.10 > 1.0.9
  // 1.0.8  == 1.0.8+1
  // 1.0.8+1 == 1.0.8+2
  //
  // Build number (+1, +2...) is intentionally ignored.
  // ============================================================

  static int compareVersions(String a, String b) {
    final versionA = _parseVersion(a);
    final versionB = _parseVersion(b);

    final length = versionA.length > versionB.length
        ? versionA.length
        : versionB.length;

    for (int i = 0; i < length; i++) {
      final partA = i < versionA.length ? versionA[i] : 0;
      final partB = i < versionB.length ? versionB[i] : 0;

      if (partA < partB) {
        return -1;
      }

      if (partA > partB) {
        return 1;
      }
    }

    return 0;
  }

  // ============================================================
  // PARSE VERSION
  // ============================================================

  static List<int> _parseVersion(String version) {
    final cleaned = _cleanVersion(version);

    if (cleaned.isEmpty) {
      return [0];
    }

    return cleaned.split('.').map((part) {
      return int.tryParse(part) ?? 0;
    }).toList();
  }

  // ============================================================
  // CLEAN VERSION
  //
  // Handles:
  //
  // v1.0.9
  // 1.0.9
  // 1.0.9+2
  // v1.0.9+2
  //
  // Result:
  // 1.0.9
  // ============================================================

  static String _cleanVersion(String version) {
    var cleaned = version.trim();

    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1);
    }

    // Remove build number.
    cleaned = cleaned.split('+').first;

    // Remove accidental whitespace.
    cleaned = cleaned.trim();

    return cleaned;
  }
}
