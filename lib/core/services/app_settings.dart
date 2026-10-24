import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens this app's own page in the phone's Settings (owner, 2026-10-24):
/// on iOS the page with the Microphone and Speech Recognition switches; on
/// Android the app's info page, whose Permissions list holds the microphone
/// (MainActivity's `vocab/app_settings` channel). False when it could not.
Future<bool> openAppSettings() async {
  try {
    if (Platform.isIOS) return await launchUrl(Uri.parse('app-settings:'));
    if (Platform.isAndroid) {
      return await const MethodChannel('vocab/app_settings').invokeMethod<bool>('open') ?? false;
    }
  } catch (_) {}
  return false;
}
