import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UpdateService {
  static const String _lastUpdateCheckKey = 'last_update_check';
  
  static Future<Map<String, dynamic>> checkForUpdates() async {
    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));
      
      await remoteConfig.fetchAndActivate();
      
      final latestVersion = remoteConfig.getString('latest_version');
      final updateUrl = remoteConfig.getString('update_url');
      final forceUpdate = remoteConfig.getBool('force_update');
      
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      
      return {
        'hasUpdate': _compareVersions(currentVersion, latestVersion) < 0,
        'currentVersion': currentVersion,
        'latestVersion': latestVersion,
        'updateUrl': updateUrl,
        'forceUpdate': forceUpdate,
      };
    } catch (e) {
      debugPrint('Error checking for updates: $e');
      return {
        'hasUpdate': false,
        'currentVersion': '1.0.0',
        'latestVersion': '1.0.0',
        'updateUrl': '',
        'forceUpdate': false,
      };
    }
  }
  
  // Check if we should show the update dialog (once per 24 hours)
  static Future<bool> shouldShowUpdateDialog(bool forceUpdate) async {
    // Always show if it's a forced update
    if (forceUpdate) return true;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_lastUpdateCheckKey) ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final dayInMs = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
      
      // Show if more than 24 hours have passed
      if (now - lastCheck > dayInMs) {
        await prefs.setInt(_lastUpdateCheckKey, now);
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking update dialog timing: $e');
      return true; // Show on error to be safe
    }
  }
  
  static int _compareVersions(String v1, String v2) {
    try {
      final v1Parts = v1.split('.').map(int.parse).toList();
      final v2Parts = v2.split('.').map(int.parse).toList();
      
      for (int i = 0; i < 3; i++) {
        if (v1Parts[i] < v2Parts[i]) return -1;
        if (v1Parts[i] > v2Parts[i]) return 1;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }
  
  static Future<void> downloadUpdate(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Error downloading update: $e');
    }
  }
}
