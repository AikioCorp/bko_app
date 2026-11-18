import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/bko_api.dart';

class AppRemoteConfig {
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final String minSupportedVersion;
  final bool studioBooking;
  final bool creatorTips;
  final bool sponsoring;
  final bool giftPasses;
  final bool showSuggestions;
  final bool offlineDownloads;

  const AppRemoteConfig({
    this.maintenanceMode = false,
    this.maintenanceMessage,
    this.minSupportedVersion = '1.0.0',
    this.studioBooking = true,
    this.creatorTips = true,
    this.sponsoring = true,
    this.giftPasses = true,
    this.showSuggestions = true,
    this.offlineDownloads = true,
  });

  factory AppRemoteConfig.fromJson(Map<String, dynamic> json) {
    final features = json['features'] is Map ? Map<String, dynamic>.from(json['features']) : <String, dynamic>{};
    return AppRemoteConfig(
      maintenanceMode: json['maintenanceMode'] == true,
      maintenanceMessage: json['maintenanceMessage']?.toString(),
      minSupportedVersion: json['minSupportedVersion']?.toString() ?? '1.0.0',
      studioBooking: features['studioBooking'] != false,
      creatorTips: features['creatorTips'] != false,
      sponsoring: features['sponsoring'] != false,
      giftPasses: features['giftPasses'] != false,
      showSuggestions: features['showSuggestions'] != false,
      offlineDownloads: features['offlineDownloads'] != false,
    );
  }
}

final appRemoteConfigProvider = FutureProvider<AppRemoteConfig>((ref) async {
  try {
    final res = await BkoApi.get('/app/config');
    if (res is Map && res['data'] is Map) {
      return AppRemoteConfig.fromJson(Map<String, dynamic>.from(res['data']));
    }
  } catch (e) {
    debugPrint('[AppRemoteConfig] fallback to defaults: $e');
  }
  return const AppRemoteConfig();
});
