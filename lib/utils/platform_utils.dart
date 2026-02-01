import 'dart:io';
import 'package:flutter/foundation.dart';

/// Platform detection utilities to avoid repetitive checks
class PlatformUtils {
  /// Check if running on mobile platforms (Android or iOS)
  static bool get isMobile => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  /// Check if running on desktop platforms (Windows, macOS, or Linux)
  static bool get isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  /// Check if running on Android
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;

  /// Check if running on iOS
  static bool get isIOS => !kIsWeb && Platform.isIOS;

  /// Check if running on Windows
  static bool get isWindows => !kIsWeb && Platform.isWindows;
}
