import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Over-the-air updates from public GitHub Releases.
///
/// Releases are tagged vX.Y.Z and carry the signed APK as an asset. The app
/// compares the latest tag against its own version and, when newer, downloads
/// the APK and hands it to the Android package installer. Because every
/// release is signed with the same key, the installer treats it as an update.
class Updater {
  static const repo = 'Billibukun/ranse';
  static const _latestUrl =
      'https://api.github.com/repos/$repo/releases/latest';

  /// Returns info about a newer release, or null when up to date.
  static Future<UpdateInfo?> check() async {
    final response = await http.get(
      Uri.parse(_latestUrl),
      headers: {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'ranse-app',
      },
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = (data['tag_name'] as String? ?? '').replaceFirst('v', '');
    if (tag.isEmpty) return null;

    final info = await PackageInfo.fromPlatform();
    if (!isNewer(tag, info.version)) return null;

    final assets = (data['assets'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final apk = assets.firstWhere(
      (a) => (a['name'] as String? ?? '').endsWith('.apk'),
      orElse: () => {},
    );
    final url = apk['browser_download_url'] as String?;
    if (url == null) return null;

    return UpdateInfo(
      version: tag,
      apkUrl: url,
      notes: data['body'] as String? ?? '',
      sizeBytes: apk['size'] as int? ?? 0,
    );
  }

  @visibleForTesting
  static bool isNewer(String candidate, String current) {
    List<int> parse(String v) => v
        .split('+')
        .first
        .split('.')
        .map((p) => int.tryParse(p) ?? 0)
        .toList();
    final a = parse(candidate);
    final b = parse(current);
    for (var i = 0; i < 3; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x > y;
    }
    return false;
  }

  /// Downloads the APK and opens the system installer.
  static Future<void> downloadAndInstall(
    UpdateInfo update, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getExternalStorageDirectory() ??
        await getApplicationSupportDirectory();
    final file = File('${dir.path}/ranse-${update.version}.apk');

    final request = http.Request('GET', Uri.parse(update.apkUrl))
      ..headers['User-Agent'] = 'ranse-app';
    final response = await http.Client().send(request);
    if (response.statusCode != 200) {
      throw Exception('Download failed (HTTP ${response.statusCode})');
    }

    final total = response.contentLength ?? update.sizeBytes;
    var received = 0;
    final sink = file.openWrite();
    await for (final chunk in response.stream) {
      sink.add(chunk);
      received += chunk.length;
      if (total > 0) onProgress?.call(received / total);
    }
    await sink.close();

    final result = await OpenFilex.open(file.path);
    if (result.type != ResultType.done) {
      throw Exception('Could not launch installer: ${result.message}');
    }
  }
}

class UpdateInfo {
  UpdateInfo({
    required this.version,
    required this.apkUrl,
    required this.notes,
    required this.sizeBytes,
  });

  final String version;
  final String apkUrl;
  final String notes;
  final int sizeBytes;
}
