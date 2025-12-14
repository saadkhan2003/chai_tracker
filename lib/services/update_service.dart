import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';

class UpdateService {
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
